local LrProgressScope = import 'LrProgressScope'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'

local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local prefs = LrPrefs.prefsForPlugin()

-- Process pictures and save them as JPEG
local function processPhotos(folderPath, photos, exportSettings, progressScope)
    return LrFunctionContext.callWithContext("export", function(exportContext)
        progressScope:setCaption("Exporting… 0/" .. #photos)

        local exportSession = LrExportSession({
            photosToExport = photos,
            exportSettings = exportSettings
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

            local fileName = rendition.photo:getFormattedMetadata("fileName")
            local progressCaption = i .. "/" .. numPhotos .. " (" .. fileName .. ")"
            progressScope:setCaption("Exporting… " .. progressCaption)
            progressScope:setPortionComplete(i - 1, numPhotos)

            rendition:waitForRender()
        end

        if progressScope:isCanceled() then
            progressScope:setCaption("Stopped")
        else
            progressScope:setCaption("Done")
        end
    end)
end

-- Import pictures from folder where the rating is not 3 stars and the photo is flagged.
local function processLightroomFolders(LrCatalog, processAll, exportSettings)
    LrTasks.startAsyncTask(function()
        LrFunctionContext.callWithContext("listFoldersAndFiles", function(context)
            local function processFolder(folder, processedPhotos)
                return LrFunctionContext.callWithContext("processFolder", function(folderContext)
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
                            if (processAll or photo:getRawMetadata("pickStatus") == 1) and
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
                        processPhotos(folder:getPath(), export, exportSettings, progressScope)
                    end

                    local canceled = progressScope:isCanceled()
                    if not canceled then
                        LrTasks.sleep(1)
                        -- Mark folder as processed
                        prefs.processedFolders[folder:getPath()] = true
                        prefs.processedFolders = prefs.processedFolders
                    end

                    progressScope:done()

                    return {
                        canceled = canceled
                    }
                end)
            end

            local function processFoldersRecursively(folder, processedPhotos)
                for _, subFolder in pairs(folder:getChildren()) do
                    local recursiveResult = processFoldersRecursively(subFolder, processedPhotos)
                    if recursiveResult['canceled'] then
                        return recursiveResult
                    end
                end

                if prefs.processedFolders[folder:getPath()] then
                    return {
                        canceled = false
                    }
                end

                return processFolder(folder, processedPhotos)
            end

            -- Initialize processed folders list if not present
            if not prefs.processedFolders then
                prefs.processedFolders = {}
            end

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
