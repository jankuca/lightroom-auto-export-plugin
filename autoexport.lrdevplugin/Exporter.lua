local LrApplication = import 'LrApplication'
local LrDate = import 'LrDate'
local LrProgressScope = import 'LrProgressScope'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'
local LrFileUtils = import 'LrFileUtils'

local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local prefs = LrPrefs.prefsForPlugin()

-- Process pictures and save them as JPEG
local function processPhotos(folderPath, photos, progressScope)
    local exportSettings = prefs.exportSettings

    return LrFunctionContext.callWithContext("export", function(exportContext)
        progressScope:setCaption("Exporting… 0/" .. #photos)

        local photosByDate = {}
        local photoCounter = 0

        -- Group photos by capture date
        for _, photo in ipairs(photos) do
            local captureDate = photo:getRawMetadata("dateTime")
            if captureDate then
                local year, month, day, hour, minute, second = LrDate.timestampToComponents(captureDate)
                local datePath = string.format("%04d/%04d-%02d/%04d-%02d-%02d", year, year, month, year, month, day)
                if not photosByDate[datePath] then
                    photosByDate[datePath] = {}
                end
                table.insert(photosByDate[datePath], photo)
            end
        end

        -- Export each group of photos
        for datePath, datePhotos in pairs(photosByDate) do
            local exportPath = LrPathUtils.child(exportSettings['LR_export_destinationPathPrefix'], datePath)
            LrFileUtils.createAllDirectories(exportPath)

            local dateExportSettings = {}
            for k, v in pairs(exportSettings) do
                dateExportSettings[k] = v
            end
            dateExportSettings['LR_export_destinationPathPrefix'] = exportPath

            local exportSession = LrExportSession({
                photosToExport = datePhotos,
                exportSettings = dateExportSettings
            })

            local numPhotos = exportSession:countRenditions()

            local renditionParams = {
                progressScope = progressScope,
                renderProgressPortion = 1,
                stopIfCanceled = true
            }

            for i, rendition in exportSession:renditions(renditionParams) do
                if progressScope:isCanceled() then
                    break
                end

                photoCounter = photoCounter + 1
                local fileName = rendition.photo:getFormattedMetadata("fileName")
                local progressCaption = photoCounter .. "/" .. #photos .. " (" .. fileName .. ")"
                progressScope:setCaption("Exporting… " .. progressCaption)
                progressScope:setPortionComplete(photoCounter, #photos)

                rendition:waitForRender()
            end
        end

        if progressScope:isCanceled() then
            progressScope:setCaption("Stopped")
        else
            progressScope:setCaption("Done")
        end
    end)
end

-- Import pictures from folder where the rating is not 3 stars and the photo is flagged.
local function processLightroomFolders()
    if not prefs.exportSettings then
        LrDialogs.showBezel("Auto-export not set up", 2)
        return
    end

    LrTasks.startAsyncTask(function()
        LrFunctionContext.callWithContext("listFoldersAndFiles", function(context)
            local function processFolder(folder, processedPhotos)
                return LrFunctionContext.callWithContext("processFolder", function(folderContext)
                    if not LrFileUtils.exists(folder:getPath()) then
                        -- LrDialogs.showBezel("Folder " .. folder:getPath() .. " is not available.")
                        return {
                            canceled = false,
                            unavailable = true
                        }
                    end

                    local folderPathParts = {}
                    for part in string.gmatch(folder:getPath(), "[^/\\]+") do
                        table.insert(folderPathParts, part)
                    end

                    local folderNameWithParent = folderPathParts[#folderPathParts - 1] .. "/" ..
                                                     folderPathParts[#folderPathParts]

                    local progressScope = LrProgressScope({
                        title = "Auto-exporting: " .. folderNameWithParent,
                        caption = "Listing files…",
                        functionContext = folderContext
                    })

                    local export = {}
                    local photos = folder:getPhotos()
                    local totalPhotos = #photos

                    for photoIndex, photo in pairs(photos) do
                        if not processedPhotos[photo.localIdentifier] then
                            if (not prefs.onlyProcessPicked or photo:getRawMetadata("pickStatus") == 1) and
                                photo:getRawMetadata("pickStatus") ~= -1 then
                                table.insert(export, photo)
                                processedPhotos[photo.localIdentifier] = true
                            end

                            local progressCaption = string.format("Listing files… %d/%d", photoIndex, totalPhotos)
                            progressScope:setCaption(progressCaption)
                            progressScope:setPortionComplete(photoIndex, totalPhotos)

                            if progressScope:isCanceled() then
                                break
                            end
                        end
                    end

                    if #export > 0 then
                        LrTasks.sleep(1)
                        processPhotos(folder:getPath(), export, progressScope)
                    end

                    local becameUnavailableDuringExport = not LrFileUtils.exists(folder:getPath())

                    local canceled = progressScope:isCanceled()
                    if not canceled and not becameUnavailableDuringExport then
                        LrTasks.sleep(1)
                        -- Mark folder as processed
                        prefs.processedFolders[folder:getPath()] = true
                        prefs.processedFolders = prefs.processedFolders
                    end

                    progressScope:done()

                    return {
                        canceled = canceled,
                        unavailable = becameUnavailableDuringExport
                    }
                end)
            end

            local function processFoldersRecursively(folder, processedPhotos)
                if not LrFileUtils.exists(folder:getPath()) then
                    return {
                        canceled = false,
                        unavailable = true
                    }
                end

                for _, subFolder in pairs(folder:getChildren()) do
                    local recursiveResult = processFoldersRecursively(subFolder, processedPhotos)
                    if recursiveResult['canceled'] then
                        return recursiveResult
                    end
                end

                if prefs.processedFolders[folder:getPath()] then
                    return {
                        canceled = false,
                        unavailable = false
                    }
                end

                return processFolder(folder, processedPhotos)
            end

            -- Initialize processed folders list if not present
            if not prefs.processedFolders then
                prefs.processedFolders = {}
            end

            local LrCatalog = LrApplication.activeCatalog()
            local folders = LrCatalog:getFolders()
            local processedPhotos = {}
            for _, folder in pairs(folders) do
                local result = processFoldersRecursively(folder, processedPhotos)
                if result['canceled'] then
                    LrDialogs.showBezel('Processing canceled', 0.5)
                    break
                end
            end
        end)
    end)
end

return {
    processLightroomFolders = processLightroomFolders
}
