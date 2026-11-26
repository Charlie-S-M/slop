--!strict

-- Opens Roblox's purchase prompt for a product or pass from Products.luau. When the product isn't
-- set up in this experience yet, it says so instead.

const MarketplaceService = game:GetService("MarketplaceService")
const Players = game:GetService("Players")

const Products = require("@game/ReplicatedStorage/Shared/Products")
const Effects = require("../Effects")
const Kit = require("./Kit")

local Purchases = {}

function Purchases.prompt(key: string)
	local def = Products.get(key)
	local id = def and Products.id(def)
	if not def or not id then
		Kit.sound(Kit.Sounds.Error, 0.2)
		Effects.toast("That isn't for sale yet. Check back soon!", Color3.fromRGB(255, 200, 60))
		return
	end
	if def.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
	else
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	end
end

return Purchases
