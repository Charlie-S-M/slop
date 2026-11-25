--!strict

-- The index: every ore and gun in the game, with the ones you haven't found shown as silhouettes.

const Biomes = require("@game/ReplicatedStorage/Shared/Biomes")
const Guns = require("@game/ReplicatedStorage/Shared/Guns")
const Ores = require("@game/ReplicatedStorage/Shared/Ores")
const Rarity = require("@game/ReplicatedStorage/Shared/Rarity")
const ClientState = require("../ClientState")
const Kit = require("../UI/Kit")
const Menus = require("../Menus")
const Preview = require("../UI/Preview")

local IndexMenu = {}

local tab = "Guns"
local grid: ScrollingFrame
local counter: TextLabel
local tabButtons: { [string]: TextButton } = {}
local built = false

local function entry(
	order: number,
	rarityTier: number,
	found: boolean,
	name: string,
	fill: (ViewportFrame) -> (),
	note: string?
)
	local rarity = Rarity.get(rarityTier)
	local card = Kit.new("Frame", {
		BackgroundColor3 = Kit.Colors.Card,
		LayoutOrder = order,
		Parent = grid,
	})
	Kit.corner(12).Parent = card
	Kit.stroke(3, if found then rarity.color else Kit.Colors.Ink, Enum.ApplyStrokeMode.Border).Parent =
		card
	if found then
		Kit.gradient(rarity.color:Lerp(Kit.Colors.Card, 0.5), Kit.Colors.Card).Parent = card
	end
	local viewport = Preview.viewport({
		Size = UDim2.fromScale(0.9, 0.62),
		Position = UDim2.fromScale(0.05, 0.03),
		Parent = card,
	})
	fill(viewport)
	if not found then
		-- A dark silhouette for things not yet discovered.
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.ImageTransparency = 0.2
	end
	Kit.text({
		Text = if found then name else "???",
		Size = UDim2.fromScale(0.92, 0.18),
		Position = UDim2.fromScale(0.04, 0.64),
		TextColor3 = if found then rarity.color:Lerp(Color3.new(1, 1, 1), 0.3) else Kit.Colors.Grey,
		Stroke = 2,
		Parent = card,
	})
	Kit.text({
		-- Where to get it is shown even before it's found, so the Index doubles as a drop guide.
		Text = if note then `{rarity.name} · {note}` else rarity.name,
		Size = UDim2.fromScale(0.92, 0.13),
		Position = UDim2.fromScale(0.04, 0.83),
		TextColor3 = rarity.color,
		Stroke = 1.5,
		Parent = card,
	})
end

local function refresh()
	local profile = ClientState.profile
	if not profile or not built then
		return
	end
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local found = 0
	if tab == "Guns" then
		for order, def in Guns.List do
			local has = profile.gunIndex[def.id] == true
			found += if has then 1 else 0
			local base = if def.evolvesFrom then Guns.get(def.evolvesFrom) else nil
			entry(order, def.rarity, has, def.name, function(viewport)
				Preview.gun(viewport, def.id)
			end, if base then `Evolve {base.name}` else nil)
		end
		counter.Text = `Found {found} / {#Guns.List} guns`
	else
		for order, ore in Ores.List do
			local has = profile.oreIndex[ore.id] == true
			found += if has then 1 else 0
			local biome = Biomes.List[ore.biome]
			entry(order, ore.rarity, has, ore.name, function(viewport)
				Preview.ore(viewport, ore.id)
			end, if biome then biome.name else nil)
		end
		counter.Text = `Found {found} / {#Ores.List} ores`
	end
	for name, button in tabButtons do
		if name == tab then
			Kit.setButtonColor(button, Color3.fromRGB(150, 100, 70), Color3.fromRGB(100, 65, 45))
		else
			Kit.setButtonColor(button, Kit.Colors.GreyDark, Kit.Colors.Ink)
		end
	end
end

local function build(content: Frame)
	built = true
	for index, name in { "Guns", "Ores" } do
		tabButtons[name] = Kit.button({
			name = name,
			color = Kit.Colors.GreyDark,
			dark = Kit.Colors.Ink,
			size = UDim2.fromScale(0.16, 0.1),
			position = UDim2.fromScale((index - 1) * 0.17, 0),
			text = if name == "Guns" then "🔫 Guns" else "💎 Ores",
			parent = content,
			onClick = function()
				tab = name
				refresh()
			end,
		})
	end
	counter = Kit.text({
		Text = "",
		Size = UDim2.fromScale(0.4, 0.08),
		Position = UDim2.fromScale(1, 0.01),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Stroke = 2.5,
		Parent = content,
	})
	grid = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.86),
		Position = UDim2.fromScale(0, 0.13),
		BackgroundColor3 = Kit.Colors.Ink,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	Kit.corner(12).Parent = grid
	Kit.padding(10).Parent = grid
	Kit.new("UIGridLayout", {
		CellSize = UDim2.new(0.155, 0, 0, 140),
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	refresh()
end

function IndexMenu:Init()
	Menus.register({
		name = "Index",
		title = "Index",
		color = Color3.fromRGB(150, 100, 70),
		size = Vector2.new(0.66, 0.72),
		build = build,
		onOpen = refresh,
	})
end

return IndexMenu
