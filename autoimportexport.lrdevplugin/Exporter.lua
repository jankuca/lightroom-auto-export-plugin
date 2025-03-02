local LrProgressScope = import 'LrProgressScope'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'
-- Process pictures and save them as JPEG
local function processPhotos(folderPath, photos, exportSettings)
    LrFunctionContext.callWithContext("export", function(exportContext)

        local progressScope = LrProgressScope({
            title = "Auto-exporting: " .. folderPath,
            caption = "Starting…",
            functionContext = exportContext
        })

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

            local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos ..
                                        ")"
            progressScope:setCaption("Exporting photo " .. progressCaption)
            progressScope:setPortionComplete(i - 1, numPhotos)

            rendition:waitForRender()
        end

        if progressScope:isCanceled() then
            progressScope:setCaption("Exporting stopped")
        else
            progressScope:setCaption("Exporting complete")
        end

        -- Close the dialog
        progressScope:done()
    end)
end

-- Import pictures from folder where the rating is not 3 stars and the photo is flagged.
local function processLightroomFolders(LrCatalog, processAll, exportSettings)
    LrTasks.startAsyncTask(function()
        LrFunctionContext.callWithContext("listFoldersAndFiles", function(context)
            local function processFolder(folder, processedPhotos)
                LrFunctionContext.callWithContext("processFolder", function(folderContext)
                    local progressScope = LrProgressScope({
                        title = "Listing files for auto-export",
                        caption = "Starting…",
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

                            local progressCaption = string.format("Listing %s: %d/%d", folder:getPath(), photoIndex,
                                totalPhotos)
                            progressScope:setCaption(progressCaption)
                            progressScope:setPortionComplete(photoIndex, totalPhotos)

                            if progressScope:isCanceled() then
                                break
                            end
                        end
                    end

                    LrTasks.sleep(1)

                    if #export > 0 then
                        processPhotos(export, exportSettings)
                    end

                    if progressScope:isCanceled() then
                        return
                    end

                    progressScope:done()
                end)
            end

            local function processFoldersRecursively(folder, processedPhotos)
                for _, subFolder in pairs(folder:getChildren()) do
                    processFoldersRecursively(subFolder, processedPhotos)
                end
                processFolder(folder, processedPhotos)
            end

            local folders = LrCatalog:getFolders()
            local processedPhotos = {}
            for _, folder in pairs(folders) do
                processFoldersRecursively(folder, processedPhotos)
            end
        end)
    end)
end

return {
    processLightroomFolders = processLightroomFolders
}
