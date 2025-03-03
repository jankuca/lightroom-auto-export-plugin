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

-- GUI specification
local function customPicker()
    LrFunctionContext.callWithContext("showCustomDialogWithObserver", function(context)
        local f = LrView.osFactory()

        local seperator = "/"
        local homePath = LrPathUtils.getStandardFilePath("home")
        if string.find(homePath, "\\") then
            seperator = "\\"
        end

        local numCharacters = 40

        local prefs = LrPrefs.prefsForPlugin()

        -- copy values from prefs to props
        local props = LrBinding.makePropertyTable(context)
        props.exportSettings = prefs.exportSettings
        props.onlyExportPicked = prefs.onlyExportPicked or false
        props.runOnStartup = prefs.runOnStartup or false

        local c = f:column{
            bind_to_object = props,
            spacing = f:dialog_spacing(),
            f:row{
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Select export preset:"
                },
                f:column{
                    spacing = f:control_spacing(),
                    f:push_button{
                        title = "Select export preset file",
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
                            end
                        end
                    },
                    f:static_text{
                        fill_horizontal = 1,
                        title = "Define an export preset in the Export dialog first and export it to disk."
                    }
                }
            },

            f:row{
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Export folder: "
                },
                f:push_button{
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
                            props.exportSettings["LR_export_destinationPathPrefix"] = exportFolder[1]
                        end
                    end
                },
                f:static_text{
                    fill_horizontal = 1,
                    title = LrView.bind({
                        key = "exportSettings",
                        transform = function(exportSettings)
                            if not exportSettings or not exportSettings["LR_export_destinationPathPrefix"] then
                                return "(Choose)"
                            end

                            local prefix = exportSettings["LR_export_destinationPathPrefix"]
                            local suffix = exportSettings["LR_export_destinationPathSuffix"]

                            if suffix and suffix ~= "" then
                                return LrPathUtils.child(prefix, suffix)
                            else
                                return prefix
                            end
                        end
                    })
                }
            },

            f:row{
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = ""
                },
                f:checkbox{
                    title = "Only export picked items",
                    value = LrView.bind "onlyExportPicked",
                    checked_value = true,
                    unchecked_value = false
                }
            },

            f:row{
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = ""
                },
                f:checkbox{
                    title = "Run auto-export automatically on Lightroom startup",
                    value = LrView.bind "runOnStartup",
                    checked_value = true,
                    unchecked_value = false
                }
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
                    title = "Export settings:"
                },
                f:column{
                    fill_horizontal = 1,
                    spacing = f:control_spacing(),
                    f:scrolled_view{
                        fill_horizontal = 1,
                        height = 100,
                        view = f:static_text{
                            fill_horizontal = 1,
                            width = 400,
                            height_in_lines = 60,
                            title = LrView.bind({
                                key = "exportSettings",
                                transform = function(exportSettings)
                                    if not exportSettings then
                                        return ""
                                    end

                                    local elements = {}
                                    for key, value in pairs(exportSettings) do
                                        table.insert(elements, key .. ": " .. tostring(value))
                                    end
                                    return table.concat(elements, "\n")
                                end
                            })
                        }
                    },
                    f:row{
                        fill_horizontal = 1,
                        spacing = f:control_spacing(),
                        f:push_button{
                            title = "Clear export settings",
                            action = function()
                                props.exportSettings = nil
                            end
                        },
                        f:static_text{
                            fill_horizontal = 1,
                            title = "Use this to prevent further auto-export runs"
                        }
                    }
                }
            },

            f:row{
                fill_horizontal = 1,
                f:separator{
                    fill_horizontal = 1
                }
            },

            f:row{
                fill_horizontal = 1,
                spacing = f:control_spacing(),
                f:static_text{
                    alignment = "right",
                    width = LrView.share "label_width",
                    title = "Processed folders: "
                },
                f:column{
                    fill_horizontal = 1,
                    spacing = f:control_spacing(),
                    f:static_text{
                        fill_horizontal = 1,
                        title = LrView.bind({
                            bind_to_object = prefs,
                            key = "processedFolders",
                            transform = function(processedFolders)
                                local count = 0
                                for _ in pairs(processedFolders) do
                                    count = count + 1
                                end
                                return tostring(count)
                            end
                        })
                    },
                    f:push_button{
                        title = "Clear processed folders",
                        action = function()
                            prefs.processedFolders = {}
                            LrDialogs.showBezel("List of processed folders cleared", 2)
                        end
                    }
                }
            }
        }

        local result = LrDialogs.presentModalDialog {
            title = "Auto-export settings",
            contents = c,
            actionVerb = "Save settings"
        }

        if result == 'ok' then
            prefs.exportSettings = props.exportSettings
            prefs.onlyExportPicked = props.onlyExportPicked
            prefs.runOnStartup = props.runOnStartup
        end
    end)
end

customPicker()
