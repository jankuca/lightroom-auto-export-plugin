local LrDialogs = import 'LrDialogs'

local ExportSettings = require 'ExportSettings'

local exportSettings = ExportSettings.loadExportSettings()
if exportSettings then
    LrDialogs.showBezel("Auto import/export plugin loaded with export settings", 2)
else
    LrDialogs.showBezel("Auto import/export plugin loaded without export settings", 2)
end

-- local LrCatalog = LrApplication.activeCatalog()
-- local processAll = true

-- processLightroomFolders(LrCatalog, processAll, exportSettings)
