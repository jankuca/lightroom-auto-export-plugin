local LrTasks = import 'LrTasks'

local ExportSettings = require 'ExportSettings'
local Exporter = require 'Exporter'

LrTasks.startAsyncTask(function()
    LrTasks.sleep(5)

    Exporter.processLightroomFolders()
end)
