--!strict

-- Gives each character its equipped gun and sets health and speed from the profile.

const Players = game:GetService("Players")

const Balance = require("@game/ReplicatedStorage/Shared/Balance")
const GunBuilder = require("@game/ReplicatedStorage/Shared/GunBuilder")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Upgrades = require("@game/ReplicatedStorage/Shared/Upgrades")
const Boosts = require("./Boosts")
const PlayerData = require("./PlayerData")

local Loadout = {}

local function removeGuns(player: Player)
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("GunUid") ~= nil then
					child:Destroy()
				end
			end
		end
	end
end

-- Puts the equipped gun in the character's hands, replacing any gun it already holds.
function Loadout.refreshGun(player: Player)
	local profile = PlayerData.get(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not character or not backpack then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local item = PlayerData.equippedGun(profile)
	local def = Guns.get(item.id) or Guns.get(Guns.STARTER_ID)
	if not def then
		return
	end
	removeGuns(player)
	local tool = GunBuilder.buildTool(def, item.uid, item.power, item.parts)
	tool:SetAttribute("Power", item.power)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

-- Applies max health and walk speed. Health keeps its share of the maximum when the max changes.
function Loadout.refreshStats(player: Player)
	local profile = PlayerData.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local share = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	local maxHealth =
		Balance.maxHealth(profile.level, profile.rebirths, profile.upgrades.Toughness or 0)
	humanoid.MaxHealth = maxHealth
	humanoid.Health = math.clamp(maxHealth * share, 1, maxHealth)
	humanoid.WalkSpeed = Upgrades.value("WalkSpeed", profile.upgrades.WalkSpeed or 0)
		* Boosts.walkSpeed(player)
	humanoid.JumpPower = 55
	humanoid.UseJumpPower = true
end

-- Armor no longer shows on the avatar (the hotbar shows it instead); this only clears pieces an
-- older server welded on. Worn armor still blocks damage through the profile.
function Loadout.refreshArmor(player: Player)
	local character = player.Character
	local old = character and character:FindFirstChild("Armor")
	if old then
		old:Destroy()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.BreakJointsOnDeath = false
	-- Wait until the default scripts settle so the max health sticks.
	task.wait(0.1)
	local profile = PlayerData.get(player)
	if profile then
		humanoid.MaxHealth =
			Balance.maxHealth(profile.level, profile.rebirths, profile.upgrades.Toughness or 0)
		humanoid.Health = humanoid.MaxHealth
	end
	Loadout.refreshStats(player)
	Loadout.refreshGun(player)
	Loadout.refreshArmor(player)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function Loadout:Start()
	PlayerData.Loaded:Connect(function(player)
		watchPlayer(player)
	end)
	-- Profiles that finished loading before this module started.
	for _, player in PlayerData.players() do
		watchPlayer(player)
	end
	PlayerData.LoadoutChanged:Connect(function(player)
		Loadout.refreshStats(player)
	end)
	Players.CharacterAutoLoads = true
end

return Loadout
