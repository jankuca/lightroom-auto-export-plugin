return {
    VERSION = {
        major = 1,
        minor = 0,
        revision = 0,
        build = 0
    },

    LrToolkitIdentifier = "com.jankuca.lightroom.autoexport",
    LrPluginName = "Auto-export",

    LrSdkVersion = 3.0,
    LrSdkMinimumVersion = 1.3, -- minimum SDK version required by this plug-in

    LrExportMenuItems = {
        title = "Auto-export settings",
        file = "ExportMenuItem.lua"
    },

    LrMetadataProvider = "LrMetadataProvider.lua",

    LrInitPlugin = "LrInitPlugin.lua",
    LrForceInitPlugin = true
}
