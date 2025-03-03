local LrTasks = import 'LrTasks'

local Exporter = require 'Exporter'

LrTasks.startAsyncTask(function()
    Exporter.processLightroomFolders()
end)
