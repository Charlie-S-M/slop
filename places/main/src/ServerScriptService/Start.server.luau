--!strict

const ModuleLoader = require("@game/ReplicatedStorage/Packages/ModuleLoader")

-- Every server system lives under Modules/Server. Passing the folder directly keeps the loader from
-- picking up client modules that also sit in places the server can see.
ModuleLoader.ChangeSettings({ VERBOSE_LOADING = false })
ModuleLoader.Start(script.Parent:WaitForChild("Modules"):WaitForChild("Server"))
