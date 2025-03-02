-- Access the Lightroom SDK namespaces.
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'

local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrTasks = import 'LrTasks'

local ExportSettings = require 'ExportSettings'

-- Load saved export settings on plugin initialization
local function loadPropsForContext(context)
    local props = LrBinding.makePropertyTable(context)

    props.exportSettings = ExportSettings.loadExportSettings()

    if props.exportSettings then
        props.outputFolderPath = props.exportSettings["LR_export_destinationPathPrefix"]
    else
        props.outputFolderPath = homePath .. seperator .. "Downloads"
        props.exportSettings = {
            LR_collisionHandling = "rename",
            LR_export_bitDepth = "8",
            LR_export_colorSpace = "sRGB",
            LR_export_destinationPathPrefix = props.outputFolderPath,
            LR_export_destinationType = "specificFolder",
            LR_export_useSubfolder = false,
            LR_format = "JPEG",
            LR_jpeg_quality = 1,
            LR_minimizeEmbeddedMetadata = true,
            LR_outputSharpeningOn = false,
            LR_reimportExportedPhoto = false,
            LR_renamingTokensOn = true,
            LR_size_doNotEnlarge = true,
            LR_size_units = "pixels",
            LR_tokens = "{{image_name}}",
            LR_useWatermark = false
        }
    end

    return props
end

-- Process pictures and save them as JPEG
local function processPhotos(photos, exportSettings)
    LrFunctionContext.callWithContext("export", function(exportContext)

        local progressScope = LrDialogs.showModalProgressDialog({
            title = "Auto applying presets",
            caption = "",
            cannotCancel = false,
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

            -- Stop processing if the cancel button has been pressed
            if progressScope:isCanceled() then
                break
            end

            -- Common caption for progress bar
            local progressCaption = rendition.photo:getFormattedMetadata("fileName") .. " (" .. i .. "/" .. numPhotos ..
                                        ")"

            progressScope:setPortionComplete(i - 1, numPhotos)
            progressScope:setCaption("Processing " .. progressCaption)

            rendition:waitForRender()
        end
    end)
end

-- Import pictures from folder where the rating is not 3 stars and the photo is flagged.
local function importFolder(LrCatalog, folder, processAll, exportSettings)
    LrTasks.startAsyncTask(function()
        local photos = folder:getPhotos()
        local export = {}

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
                        photo:addKeyword(autoExportedKeyword)
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

-- GUI specification
local function customPicker()
    LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)
        local props = loadPropsForContext(context)
        local f = LrView.osFactory()

        local seperator = "/"
        local homePath = LrPathUtils.getStandardFilePath("home")
        if string.find(homePath, "\\") then
            seperator = "\\"
        end

        props.watcherStatus = "Not started"

        local numCharacters = 40
        local watcherRunning = false

        LrTasks.startAsyncTask(function()

            local LrCatalog = LrApplication.activeCatalog()
            local catalogFolders = LrCatalog:getFolders()
            local folderCombo = {}
            local folderIndex = {}
            for i, folder in pairs(catalogFolders) do
                folderCombo[i] = folder:getName()
                folderIndex[folder:getName()] = i
            end

            -- Watcher, executes function and then sleeps 60 seconds using PowerShell
            local function watch(processAll)
                local index = 0
                LrTasks.startAsyncTask(function()
                    while watcherRunning do
                        props.watcherStatus = "Running - # runs: " .. index
                        LrDialogs.showBezel("Processing images.")
                        if catalogFolders[folderIndex[props.folderField.value]] then
                            importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], processAll,
                                props.exportSettings)
                        else
                            watcherRunning = false
                            LrDialogs.message("No folder selected",
                                "No folder selected, please select a folder in the dropdown and then click inside of the 'Output folder' field.")
                        end
                        if LrTasks.canYield() then
                            LrTasks.yield()
                        end
                        LrTasks.sleep(3)
                    end
                end)
            end

            local c = f:column{
                bind_to_object = props,
                spacing = f:dialog_spacing(),
                f:row{
                    fill_horizontal = 1,
                    f:static_text{
                        alignment = "right",
                        width = LrView.share "label_width",
                        title = "Watcher running: "
                    },
                    f:static_text{
                        width_in_chars = numCharacters,
                        title = LrView.bind("watcherStatus")
                    }
                },
                f:row{f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Lightroom folder: "
                }, props.folderField},
                f:row{f:static_text{
                    title = "Please press 'Tab' after selecting the Lightroom folder"
                }},
                f:row{
                    fill_horizontal = 1,
                    f:static_text{
                        alignment = "right",
                        width = LrView.share "label_width",
                        title = "Select export preset:"
                    },
                    f:push_button{
                        title = "Select",
                        action = function()
                            local exportPreset = LrDialogs.runOpenPanel {
                                title = "Select Export Settings",
                                canChooseFiles = true,
                                canChooseDirectories = false,
                                canCreateDirectories = false,
                                allowedFileTypes = {'lrtemplate', 'xmp'},
                                multipleSelection = false
                            }
                            if exportPreset then
                                local filename = exportPreset[1]
                                local filenameLength = #filename
                                props.exportSettings = ExportSettings.parsePreset(exportPreset)
                                ExportSettings.saveExportSettings(props.exportSettings)
                            end
                            if props.exportSettings["LR_export_destinationPathPrefix"] then
                                props.outputFolderPath = props.exportSettings["LR_export_destinationPathPrefix"]
                            end
                        end
                    }
                },
                f:row{f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Preset selected:"
                }, f:static_text{
                    width_in_chars = numCharacters,
                    title = LrView.bind("presetSelected")
                }},
                f:row{f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Export folder: "
                }, f:push_button{
                    title = "Select export Folder",
                    action = function()
                        exportFolder = LrDialogs.runOpenPanel {
                            title = "Select Export Settings",
                            canChooseFiles = false,
                            canChooseDirectories = true,
                            canCreateDirectories = true,
                            multipleSelection = false
                        }
                        if exportFolder then
                            props.outputFolderPath = exportFolder[1]
                            props.exportSettings["LR_export_destinationPathPrefix"] = props.outputFolderPath
                            ExportSettings.saveExportSettings(props.exportSettings)
                        end
                    end
                }},
                f:row{f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Export folder selected:"
                }, f:static_text{
                    width_in_chars = numCharacters,
                    title = LrView.bind({
                        keys = {"outputFolderPath", "exportSettings"},
                        transform = function()
                            props.exportSettings["LR_export_destinationPathPrefix"] = props.outputFolderPath
                            if props.exportSettings["LR_export_destinationPathSuffix"] then
                                return props.exportSettings["LR_export_destinationPathPrefix"] .. seperator ..
                                           props.exportSettings["LR_export_destinationPathSuffix"]
                            else
                                return props.exportSettings["LR_export_destinationPathPrefix"]
                            end
                        end
                    })
                }},
                f:row{f:column{
                    spacing = f:dialog_spacing(),
                    f:push_button{
                        title = "Process flagged",

                        action = function()
                            if props.folderField.value ~= "" then
                                props.watcherStatus = "Working"
                                importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], false,
                                    props.exportSettings)
                                props.watcherStatus = "Processed once"
                            else
                                LrDialogs.message("Please select an input folder")
                            end
                        end
                    },
                    f:push_button{
                        title = "Process all",

                        action = function()
                            if props.folderField.value ~= "" then
                                props.watcherStatus = "Working"
                                importFolder(LrCatalog, catalogFolders[folderIndex[props.folderField.value]], true,
                                    props.exportSettings)
                                props.watcherStatus = "Processed once"
                            else
                                LrDialogs.message("Please select an input folder")
                            end
                        end
                    }
                }, f:column{
                    spacing = f:dialog_spacing(),
                    f:push_button{
                        title = "Watch flagged",

                        action = function()
                            watcherRunning = true
                            if props.folderField.value ~= "" then
                                watch(false)
                            else
                                LrDialogs.message("Please select an input folder")
                            end
                        end
                    },
                    f:push_button{
                        title = "Watch all",

                        action = function()
                            watcherRunning = true
                            if props.folderField.value ~= "" then
                                props.watcherStatus = "Running"
                                watch(true)
                            else
                                LrDialogs.message("Please select an input folder")
                            end
                        end
                    }
                }, f:push_button{
                    title = "Pause watcher",

                    action = function()
                        watcherRunning = false
                        props.watcherStatus = "Stopped after running"
                    end
                }}
            }

            LrDialogs.presentModalDialog {
                title = "Auto Edit Watcher",
                contents = c,
                buttons = {{
                    title = "Cancel",
                    action = function()
                        watcherRunning = false
                    end
                }, {
                    title = "Run in background"
                }}
            }

        end)

    end)
end

customPicker()
