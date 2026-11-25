--!strict

const ModuleLoader = require("@game/ReplicatedStorage/Packages/ModuleLoader")

-- Load this player's own copy of the controllers. Searching by tag would also find the template
-- copy left in StarterPlayerScripts and load every controller twice.
ModuleLoader.ChangeSettings({ VERBOSE_LOADING = false })
ModuleLoader.Start(script.Parent:WaitForChild("Controllers"))
