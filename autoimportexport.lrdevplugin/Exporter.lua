local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'

local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

-- Process pictures and save them as JPEG
local function processPhotos(photos, exportSettings)
    LrFunctionContext.callWithContext("export", function(exportContext)
        local props = LrBinding.makePropertyTable(exportContext)
        props.caption = "Starting export..."
        props.portionComplete = 0
        props.stopRequested = false
        local f = LrView.osFactory()
        local contents = f:column{
            spacing = f:dialog_spacing(),
            fill_horizontal = 1,
            bind_to_object = props,
            f:row{
                fill_horizontal = 1,
                f:static_text{
                    title = LrView.bind("caption"),
                    fill_horizontal = 1
                }
            },
            f:row{
                fill_horizontal = 1,
                f:static_text{
                    title = "Progress",
                    alignment = "right",
                    width = LrView.share "label_width"
                },
                f:slider{
                    value = LrView.bind("portionComplete"),
                    min = 0,
                    max = 1,
                    fill_horizontal = 1,
                    enabled = false
                }
            },
            f:row{
                fill_horizontal = 1,
                f:push_button{
                    title = "Stop",
                    visible = LrView.bind {
                        keys = {"stopRequested", "portionComplete"},
                        transform = function(_, props)
                            return not props.stopRequested and props.portionComplete < 1
                        end
                    },
                    action = function()
                        props.stopRequested = true
                        LrDialogs.stopModalWithResult(props)
                    end
                }
            }
        }

        local paddedContents = f:column{
            spacing = f:dialog_spacing(),
            f:row{
                margin_horizontal = 10,
                margin_vertical = 10,
                contents
            }
        }

        local progressScope = LrDialogs.presentFloatingDialog(_PLUGIN, {
            title = "Auto-exporting",
            contents = paddedContents,
            cannotCancel = false,
            functionContext = exportContext,
            blockTask = false
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
            if props.stopRequested then
                props.caption = "Processing stopped"
                break
            end

            local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos ..
                                        ")"
            props.caption = "Processing " .. progressCaption
            props.portionComplete = (i - 1) / numPhotos

            rendition:waitForRender()
        end

        if not props.stopRequested then
            props.caption = "Processing complete"
            props.portionComplete = 1
        end
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
