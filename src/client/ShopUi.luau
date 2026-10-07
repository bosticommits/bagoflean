--!strict
-- Robux shop: game passes and developer products (Shared/Shop). The client only opens Roblox's
-- purchase prompt; the server grants (ShopService) and tells us through RewardResult and syncs.
-- Prices are read from Roblox, so they always match what the prompt charges.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Shop = require(ReplicatedStorage.Shared.Shop)
local ClientState = require(script.Parent.ClientState)
local Hud = require(script.Parent.Hud)
local UiKit = require(script.Parent.UiKit)

local makeLabel, makeButton = UiKit.makeLabel, UiKit.makeButton

local ShopUi = {}

local prices: { [string]: number } = {} -- "pass:<key>" / "product:<key>" -> Robux
local fetching: { [string]: boolean } = {}

-- Fetches a price once in the background and calls `onPrice` when it arrives.
local function fetchPrice(kind: string, id: number, key: string, onPrice: () -> ())
	local cacheKey = kind .. ":" .. key
	if prices[cacheKey] ~= nil or fetching[cacheKey] or id == 0 then
		return
	end
	fetching[cacheKey] = true
	task.spawn(function()
		local infoType = if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		fetching[cacheKey] = nil
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			prices[cacheKey] = info.PriceInRobux
			onPrice()
		end
	end)
end

-- Opens Roblox's purchase prompt for a developer product. Returns false if it is not set up yet.
function ShopUi.promptProduct(key: string): boolean
	local product = Shop.getProduct(key)
	if product == nil or product.id == 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.id)
	return true
end

function ShopUi.start(gui: ScreenGui, shopButton: TextButton)
	local player = Players.LocalPlayer
	local panel, list = UiKit.makePanel(gui, "ShopPanel", "Shop", nil, nil, nil, UiKit.RED)

	local build: () -> ()
	local function rebuildIfOpen()
		if panel.Visible then
			build()
		end
	end

	local function priceText(kind: string, id: number, key: string): string
		if id == 0 then
			return "Soon"
		end
		local price = prices[kind .. ":" .. key]
		fetchPrice(kind, id, key, rebuildIfOpen)
		return if price ~= nil then "R$ " .. Hud.comma(price) else "Buy"
	end

	build = function()
		UiKit.clear(list)
		local order = 0
		local function section(text: string)
			order += 1
			local row = UiKit.addRow(list, order, 36)
			UiKit.plainRow(row)
			UiKit.makeTitle(row, text, UiKit.GOLD, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
		end
		local function itemRow(name: string, description: string): Frame
			order += 1
			local row = UiKit.addRow(list, order, 72)
			local title = UiKit.makeTitle(row, name, UiKit.WHITE, UDim2.new(0.62, 0, 0, 30), UDim2.fromOffset(10, 6))
			title.TextXAlignment = Enum.TextXAlignment.Left
			local sub = makeLabel(row, description, UiKit.MUTED, UDim2.new(0.62, 0, 0, 22), UDim2.fromOffset(10, 40))
			sub.TextXAlignment = Enum.TextXAlignment.Left
			return row
		end

		section("Game passes (forever)")
		for _, pass in Shop.Passes do
			local row = itemRow(pass.name, pass.description)
			local owned = player:GetAttribute("Pass" .. pass.key) == true
			if owned then
				UiKit.makeTitle(row, "OWNED", UiKit.GOLD, UDim2.new(0.32, 0, 0, 44), UDim2.new(0.66, 0, 0.5, -22))
				continue
			end
			local button = makeButton(row, priceText("pass", pass.id, pass.key), if pass.id == 0 then UiKit.DISABLED else UiKit.GREEN, UDim2.new(0.32, 0, 0, 44), UDim2.new(0.66, 0, 0.5, -22))
			button.Activated:Connect(function()
				if pass.id == 0 then
					UiKit.toast(gui, "Coming soon!")
				else
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end)
		end

		section("Boosts and Cash")
		local rate = player:GetAttribute("Rate") or 0
		local skips = if ClientState.studio ~= nil then ClientState.studio.skips or 0 else 0
		for _, product in Shop.Products do
			local description = product.description
			if product.reward.cashMinutes ~= nil then
				description = `{description}: ${Hud.comma(Rewards.cashAmount(product.reward, rate))} now`
			elseif product.reward.skips ~= nil then
				description = `{description} (you have {skips})`
			end
			local row = itemRow(product.name, description)
			local button = makeButton(row, priceText("product", product.id, product.key), if product.id == 0 then UiKit.DISABLED else UiKit.GREEN, UDim2.new(0.32, 0, 0, 44), UDim2.new(0.66, 0, 0.5, -22))
			button.Activated:Connect(function()
				if not ShopUi.promptProduct(product.key) then
					UiKit.toast(gui, "Coming soon!")
				end
			end)
		end

		order += 1
		local note = UiKit.addRow(list, order, 30)
		UiKit.plainRow(note)
		makeLabel(note, "Everything in the game can also be earned for free.", UiKit.MUTED, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0))
	end

	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Pass" or name == "Rate" then
			rebuildIfOpen()
		end
	end)
	ClientState.changed:Connect(function(kind)
		if kind == "studio" then
			rebuildIfOpen()
		end
	end)
	shopButton.Activated:Connect(function()
		UiKit.togglePanel(panel, build)
	end)
end

return ShopUi
