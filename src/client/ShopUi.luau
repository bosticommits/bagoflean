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
local Icon3D = require(script.Parent.Icon3D)
local Screens = require(script.Parent.Screens)
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

-- False for items that lead to random actors when this player's region restricts paid random
-- items (the attribute is nil until the server has checked, which also counts as restricted).
function ShopUi.offered(item: { randomItems: boolean? }): boolean
	return not item.randomItems or Players.LocalPlayer:GetAttribute("PaidRandomRestricted") == false
end

-- Opens Roblox's purchase prompt for a developer product. Returns false if it is not set up yet.
function ShopUi.promptProduct(key: string): boolean
	local product = Shop.getProduct(key)
	if product == nil or product.id == 0 or not ShopUi.offered(product) then
		return false
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.id)
	return true
end

-- 3D icon and card color for each pass and product (by key).
local LOOKS: { [string]: { icon: string, color: Color3 } } = {
	Luck2x = { icon = "clover", color = Color3.fromRGB(52, 168, 76) },
	AutoCollect = { icon = "magnet", color = Color3.fromRGB(196, 52, 66) },
	ExtraStage = { icon = "stage", color = Color3.fromRGB(46, 120, 210) },
	FastFilming = { icon = "bolt", color = Color3.fromRGB(226, 150, 30) },
	VIP = { icon = "crown", color = Color3.fromRGB(140, 70, 230) },
	LuckyCasting = { icon = "potion", color = Color3.fromRGB(30, 160, 150) },
	SkipFilming = { icon = "skip", color = Color3.fromRGB(120, 60, 200) },
	CashSmall = { icon = "moneybag", color = Color3.fromRGB(60, 150, 70) },
	CashLarge = { icon = "vault", color = Color3.fromRGB(205, 150, 30) },
}
local FEATURED = "Luck2x" -- the big banner at the top

-- `cashButton` (the green "+" by Cash) opens the shop at Boosts and Cash.
function ShopUi.start(gui: ScreenGui, shopButton: TextButton, cashButton: TextButton?)
	local player = Players.LocalPlayer
	local panel, list, header = UiKit.makePanel(gui, "ShopPanel", "Shop", nil, nil, nil, UiKit.AWARD_GOLD)
	UiKit.panelIcon(panel, header, "popcorn")

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

	local cashSection: Frame? = nil

	build = function()
		UiKit.clear(list)
		cashSection = nil
		local order = 0
		local function section(text: string): Frame
			order += 1
			local row = UiKit.addRow(list, order, 36)
			UiKit.plainRow(row)
			UiKit.makeTitle(row, text, UiKit.GOLD, UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0)).TextXAlignment = Enum.TextXAlignment.Left
			return row
		end
		local function grid(): Frame
			order += 1
			local g = Instance.new("Frame")
			g.LayoutOrder = order
			g.BackgroundTransparency = 1
			g.Size = UDim2.new(1, -8, 0, 0)
			g.AutomaticSize = Enum.AutomaticSize.Y
			g.Parent = list
			local layout = Instance.new("UIGridLayout")
			layout.CellSize = UDim2.new(0.5, -8, 0, if UiKit.isCompact() then 172 else 196)
			layout.CellPadding = UDim2.fromOffset(10, 10)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = g
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 3)
			pad.PaddingTop = UDim.new(0, 3)
			pad.Parent = g
			return g
		end
		-- A picture card: colored tile, outlined 3D icon, name, one line of text, and a slot at the
		-- bottom for the price button (returned) or an OWNED / not available label.
		local function card(parent: Instance, key: string, name: string, description: string, slot: number): Frame
			local look = LOOKS[key] or { icon = "coin", color = UiKit.BLUE }
			local c = Instance.new("Frame")
			c.Name = key
			c.LayoutOrder = slot
			c.BackgroundColor3 = look.color
			c.Parent = parent
			UiKit.corner(c, 14)
			UiKit.border(c, 3)
			local shade = Instance.new("UIGradient")
			shade.Rotation = 90
			shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))
			shade.Parent = c
			local art = Instance.new("Frame")
			art.Name = "Art"
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.03)
			art.Size = UDim2.fromScale(0.5, 0.42)
			art.Parent = c
			Icon3D.glow(Icon3D.outlined(art, look.icon))
			local title = UiKit.makeTitle(c, name, UiKit.WHITE, UDim2.fromScale(0.94, 0.15), UDim2.fromScale(0.03, 0.44), 2.5)
			title.Name = "Title"
			title.ZIndex = 3
			UiKit.textConstraint(title, 24)
			local sub = makeLabel(c, description, UiKit.WHITE, UDim2.fromScale(0.9, 0.14), UDim2.fromScale(0.05, 0.6))
			sub.Name = "Description"
			sub.ZIndex = 3
			UiKit.outline(sub, 1.5)
			UiKit.textConstraint(sub, 15)
			return c
		end
		local BUTTON_SIZE = UDim2.fromScale(0.86, 0.2)
		local BUTTON_POS = UDim2.fromScale(0.07, 0.77)
		local function ownedLabel(c: Frame, text: string, color: Color3)
			local label = UiKit.makeTitle(c, text, color, BUTTON_SIZE, BUTTON_POS, 2.5)
			label.Name = "Action"
			label.ZIndex = 3
		end
		local function priceButton(c: Frame, text: string, ready: boolean): TextButton
			local button = makeButton(c, text, if ready then UiKit.GREEN else UiKit.DISABLED, BUTTON_SIZE, BUTTON_POS)
			button.Name = "Action"
			button.ZIndex = 3
			UiKit.textConstraint(button, 24)
			return button
		end

		local function passCard(parent: Instance, pass: Shop.Pass, slot: number): Frame
			local c = card(parent, pass.key, pass.name, pass.description, slot)
			if player:GetAttribute("Pass" .. pass.key) == true then
				ownedLabel(c, "OWNED", UiKit.GOLD)
			elseif not ShopUi.offered(pass) then
				ownedLabel(c, "Not available", UiKit.MUTED)
			else
				priceButton(c, priceText("pass", pass.id, pass.key), pass.id ~= 0).Activated:Connect(function()
					if pass.id == 0 then
						UiKit.toast(gui, "Coming soon!")
					else
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end)
			end
			return c
		end

		-- Featured banner: the best pass, big, with a gold frame and a ribbon; it then stays out of
		-- the grid below.
		local featured = Shop.getPass(FEATURED)
		local featuredShown = false
		if featured ~= nil and player:GetAttribute("Pass" .. featured.key) ~= true and ShopUi.offered(featured) then
			featuredShown = true
			order += 1
			local holder = Instance.new("Frame")
			holder.Name = "Featured"
			holder.LayoutOrder = order
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, -8, 0, if UiKit.isCompact() then 136 else 160)
			holder.Parent = list
			local banner = passCard(holder, featured, 1)
			banner.Size = UDim2.new(1, -6, 1, -6)
			banner.Position = UDim2.fromOffset(3, 3)
			local outline = banner:FindFirstChild("Outline") :: UIStroke
			outline.Color = UiKit.GOLD
			outline.Thickness = 4
			-- Icon on the left; name, text and button on the right.
			local art = banner:FindFirstChild("Art") :: Frame
			art.AnchorPoint = Vector2.new(0, 0.5)
			art.Position = UDim2.fromScale(0.03, 0.5)
			art.Size = UDim2.fromScale(0.32, 0.92)
			local function place(name: string, y: number, h: number)
				local child = banner:FindFirstChild(name)
				if child ~= nil and child:IsA("GuiObject") then
					child.Position = UDim2.fromScale(0.38, y)
					child.Size = UDim2.fromScale(0.58, h)
				end
			end
			place("Title", 0.1, 0.26)
			place("Description", 0.38, 0.16)
			place("Action", 0.6, 0.3)
			local titleLabel = banner:FindFirstChild("Title") :: TextLabel
			UiKit.textConstraint(titleLabel, 36)
			local ribbon = UiKit.makeTitle(banner, "BEST VALUE", UiKit.WHITE, UDim2.fromOffset(118, 26), UDim2.fromOffset(8, 8), 2)
			ribbon.BackgroundTransparency = 0
			ribbon.BackgroundColor3 = UiKit.CLOSE_RED
			ribbon.Rotation = -6
			ribbon.ZIndex = 5
			UiKit.corner(ribbon, 8)
			UiKit.border(ribbon, 2)
			UiKit.textConstraint(ribbon, 18)
		end

		section("Game passes (forever)")
		local passGrid = grid()
		local slot = 0
		for _, pass in Shop.Passes do
			if featuredShown and pass.key == FEATURED then
				continue
			end
			slot += 1
			passCard(passGrid, pass, slot)
		end

		cashSection = section("Boosts and Cash")
		local productGrid = grid()
		local rate = player:GetAttribute("Rate") or 0
		local skips = if ClientState.studio ~= nil then ClientState.studio.skips or 0 else 0
		for index, product in Shop.Products do
			local description = product.description
			if product.reward.cashMinutes ~= nil then
				description = `${Hud.comma(Rewards.cashAmount(product.reward, rate))} now`
			elseif product.reward.skips ~= nil then
				description = `{description} (you have {skips})`
			end
			local c = card(productGrid, product.key, product.name, description, index)
			if not ShopUi.offered(product) then
				ownedLabel(c, "Not available", UiKit.MUTED)
				continue
			end
			priceButton(c, priceText("product", product.id, product.key), product.id ~= 0).Activated:Connect(function()
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
		if string.sub(name, 1, 4) == "Pass" or name == "Rate" or name == "PaidRandomRestricted" then
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
	if cashButton ~= nil then
		cashButton.Activated:Connect(function()
			if not panel.Visible then
				UiKit.togglePanel(panel, build)
			end
			-- Scroll to Boosts and Cash once the layout has placed it and sized the canvas.
			task.spawn(function()
				task.wait()
				local target = cashSection
				if target ~= nil and panel.Visible then
					list.CanvasPosition = Vector2.new(0, target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y)
				end
			end)
		end)
	end
	Screens.register("Shop", function()
		if not panel.Visible then
			UiKit.togglePanel(panel, build)
		end
	end)
end

return ShopUi
