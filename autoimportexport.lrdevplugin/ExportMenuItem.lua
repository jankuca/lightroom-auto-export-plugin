local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrPrefs = import 'LrPrefs'

local LrTasks = import 'LrTasks'

local ExportSettings = require 'ExportSettings'
local Exporter = require 'Exporter'

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

        local numCharacters = 40

        local c = f:column{
            bind_to_object = props,
            spacing = f:dialog_spacing(),
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
                        Exporter.processLightroomFolders(LrCatalog, false, props.exportSettings)
                    end
                },
                f:push_button{
                    title = "Process all",

                    action = function()
                        Exporter.processLightroomFolders(LrCatalog, true, props.exportSettings)
                    end
                }
            }},

            f:row{
                fill_horizontal = 1,
                f:separator{
                    fill_horizontal = 1
                }
            },

            f:push_button{
                title = "Clear processed folders",
                action = function()
                    local prefs = LrPrefs.prefsForPlugin()
                    prefs.processedFolders = {}
                    LrDialogs.showBezel("List of processed folders cleared", 2)
                end
            },

            f:row{
                fill_horizontal = 1,
                f:separator{
                    fill_horizontal = 1
                }
            },

            f:row{
                fill_horizontal = 1,
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Current export settings:"
                },
                f:edit_field{
                    width_in_chars = numCharacters,
                    height_in_lines = 60,
                    font = "<system/small/monospace>",
                    value = LrView.bind({
                        keys = {"exportSettings"},
                        transform = function()
                            local settings = ""
                            for key, value in pairs(props.exportSettings) do
                                settings = settings .. key .. ": " .. tostring(value) .. "\n"
                            end
                            return settings
                        end
                    }),
                    enabled = false
                }
            }
        }

        LrDialogs.presentModalDialog {
            title = "Auto-export settings",
            contents = c,
            buttons = {{
                title = "Done"
            }}
        }

    end)
end

customPicker()
