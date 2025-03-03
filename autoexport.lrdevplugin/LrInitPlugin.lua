local LrPrefs = import 'LrPrefs'
local LrTasks = import 'LrTasks'

local ExportSettings = require 'ExportSettings'
local Exporter = require 'Exporter'

LrTasks.startAsyncTask(function()
    LrTasks.sleep(5)

    local prefs = LrPrefs.prefsForPlugin()
    if not prefs.runOnStartup then
        return
    end

    Exporter.processLightroomFolders()
end)
