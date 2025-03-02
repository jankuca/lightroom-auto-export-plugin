local LrProgressScope = import 'LrProgressScope'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

-- Process pictures and save them as JPEG
local function processPhotos(photos, exportSettings)
    LrFunctionContext.callWithContext("export", function(exportContext)

        local progressScope = LrProgressScope({
            title = "Auto-exporting",
            caption = "Starting export...",
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
        local folders = {}
        for _, folder in pairs(LrCatalog:getFolders()) do
            if string.find(folder:getName(), "Autoexport") then
                table.insert(folders, folder)
            end
        end

        local export = {}

        for _, folder in pairs(folders) do
            local photos = folder:getPhotos()

            for _, photo in pairs(photos) do
                local keywords = photo:getRawMetadata("keywords")
                local skipPhoto = false
                for _, keyword in pairs(keywords) do
                    if keyword:getName() == "Auto-exported" then
                        skipPhoto = true
                        break
                    end
                end

                if not skipPhoto and (processAll or photo:getRawMetadata("pickStatus") == 1) then
                    LrCatalog:withWriteAccessDo("Add Keyword", (function(context)
                        local keywords = LrCatalog:getKeywords()
                        local autoExportedKeyword = nil
                        for _, keyword in pairs(keywords) do
                            if keyword:getName() == "Auto-exported" then
                                autoExportedKeyword = keyword
                                break
                            end
                        end
                        if not autoExportedKeyword then
                            autoExportedKeyword = LrCatalog:createKeyword("Auto-exported", {}, false, nil, true)
                        end
                        -- photo:addKeyword(autoExportedKeyword)
                        table.insert(export, photo)
                    end), {
                        timeout = 30
                    })
                end
            end
        end

        LrTasks.sleep(1)

        if #export > 0 then
            processPhotos(export, exportSettings)
        end
    end)
end

return {
    processLightroomFolders = processLightroomFolders
}
