local LrPrefs = import 'LrPrefs'

local allowedExportSettings = {
    collisionHandling = "LR_collisionHandling",
    contentCredentials_include_connectedAccounts = "LR_contentCredentials_include_connectedAccounts",
    contentCredentials_include_editsAndActivity = "LR_contentCredentials_include_editsAndActivity",
    contentCredentials_include_producer = "LR_contentCredentials_include_producer",
    contentCredentials_include_status = "LR_contentCredentials_include_status",
    embeddedMetadataOption = "LR_embeddedMetadataOption",
    enableHDRDisplay = "LR_enableHDRDisplay",
    exportServiceProvider = "LR_exportServiceProvider",
    exportServiceProviderTitle = "LR_exportServiceProviderTitle",
    export_bitDepth = "LR_export_bitDepth",
    export_colorSpace = "LR_export_colorSpace",
    export_destinationPathPrefix = "LR_export_destinationPathPrefix",
    export_destinationPathSuffix = "LR_export_destinationPathSuffix",
    export_destinationType = "LR_export_destinationType",
    export_postProcessing = "LR_export_postProcessing",
    export_useParentFolder = "LR_export_useParentFolder",
    export_useSubfolder = "LR_export_useSubfolder",
    export_videoFileHandling = "LR_export_videoFileHandling",
    export_videoFormat = "LR_export_videoFormat",
    export_videoPreset = "LR_export_videoPreset",
    extensionCase = "LR_extensionCase",
    format = "LR_format",
    includeFaceTagsAsKeywords = "LR_includeFaceTagsAsKeywords",
    includeFaceTagsInIptc = "LR_includeFaceTagsInIptc",
    includeVideoFiles = "LR_includeVideoFiles",
    initialSequenceNumber = "LR_initialSequenceNumber",
    jpeg_limitSize = "LR_jpeg_limitSize",
    jpeg_quality = "LR_jpeg_quality",
    jpeg_useLimitSize = "LR_jpeg_useLimitSize",
    markedPresets = "LR_markedPresets",
    maximumCompatibility = "LR_maximumCompatibility",
    metadata_keywordOptions = "LR_metadata_keywordOptions",
    outputSharpeningLevel = "LR_outputSharpeningLevel",
    outputSharpeningMedia = "LR_outputSharpeningMedia",
    outputSharpeningOn = "LR_outputSharpeningOn",
    reimportExportedPhoto = "LR_reimportExportedPhoto",
    reimport_stackWithOriginal = "LR_reimport_stackWithOriginal",
    reimport_stackWithOriginal_position = "LR_reimport_stackWithOriginal_position",
    removeFaceMetadata = "LR_removeFaceMetadata",
    removeLocationMetadata = "LR_removeLocationMetadata",
    renamingTokensOn = "LR_renamingTokensOn",
    selectedTextFontFamily = "LR_selectedTextFontFamily",
    selectedTextFontSize = "LR_selectedTextFontSize",
    size_doConstrain = "LR_size_doConstrain",
    size_doNotEnlarge = "LR_size_doNotEnlarge",
    size_maxHeight = "LR_size_maxHeight",
    size_maxWidth = "LR_size_maxWidth",
    size_percentage = "LR_size_percentage",
    size_resizeType = "LR_size_resizeType",
    size_resolution = "LR_size_resolution",
    size_resolutionUnits = "LR_size_resolutionUnits",
    size_units = "LR_size_units",
    size_userWantsConstrain = "LR_size_userWantsConstrain",
    tokenCustomString = "LR_tokenCustomString",
    tokens = "LR_tokens",
    tokensArchivedToString2 = "LR_tokensArchivedToString2",
    useWatermark = "LR_useWatermark",
    watermarking_id = "LR_watermarking_id"
}

local prefs = LrPrefs.prefsForPlugin()

-- local function tableContains(table, element)
--     for _, value in pairs(table) do
--         if value == element then
--             return true
--         end
--     end
--     return false
-- end

local function loadExportSettings()
    if not prefs.exportSettings then
        return nil
    end

    -- return prefs.exportSettings

    local filteredSettings = {}
    for key, value in pairs(prefs.exportSettings) do
        -- if tableContains(allowedExportSettings, key) then
        filteredSettings[key] = value
        -- end
    end

    return filteredSettings
end

local function saveExportSettings(exportSettings)
    prefs.exportSettings = exportSettings
end

local function parsePreset(exportPreset)
    -- After this operation the variable s exists with the presets
    (loadfile(exportPreset[1]))()

    local exportSettings = {}
    for key, value in pairs(s.value) do
        if allowedExportSettings[key] then
            exportSettings[allowedExportSettings[key]] = value
        end
    end

    return exportSettings
end

return {
    loadExportSettings = loadExportSettings,
    saveExportSettings = saveExportSettings,
    parsePreset = parsePreset
}
