local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'

local ExportSettings = require 'ExportSettings'
local Exporter = require 'Exporter'

local exportSettings = ExportSettings.loadExportSettings()
if exportSettings then
    LrDialogs.showBezel("Auto import/export plugin loaded with export settings", 2)
else
    LrDialogs.showBezel("Auto import/export plugin loaded without export settings", 2)
end

LrTasks.startAsyncTask(function()
    LrTasks.sleep(5)

    local LrCatalog = LrApplication.activeCatalog()
    Exporter.processLightroomFolders(LrCatalog, exportSettings)
end)
