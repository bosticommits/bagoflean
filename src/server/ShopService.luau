--!strict
-- Game passes and developer products (plan section 7). The client only prompts purchases; every
-- grant happens here.
--
-- Passes: ownership is checked with UserOwnsGamePassAsync when the player joins and granted from
-- the server-side PromptGamePassPurchaseFinished when bought in game. Confirmed ownership is saved
-- in data.passes, so a Roblox API outage later never takes a pass away.
-- Products: the single ProcessReceipt callback grants each purchase exactly once, through
-- DataService.grantPurchaseOnce, and acknowledges it only after the grant is saved.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)
local Analytics = require(script.Parent.Analytics)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local LotService = require(script.Parent.LotService)
local MovieService = require(script.Parent.MovieService)
local RewardService = require(script.Parent.RewardService)

local DATA_WAIT_SECONDS = 20
local VIP_GOLD = Color3.fromRGB(255, 205, 70)

local ShopService = {}

local function addVipTag(character: Model)
	local head = character:WaitForChild("Head", 10)
	if head == nil or not head:IsA("BasePart") or head:FindFirstChild("VipTag") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VipTag"
	gui.Size = UDim2.fromOffset(80, 28)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 80
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(30, 25, 10)
	label.BackgroundTransparency = 0.2
	label.Text = "★ VIP"
	label.TextColor3 = VIP_GOLD
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

-- Makes owned passes take effect: attributes for the UI and chat tag, the VIP head tag, and every
-- stat that a pass changes (casting Luck, stage count, lot visuals).
local function applyPasses(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	for _, pass in Shop.Passes do
		player:SetAttribute("Pass" .. pass.key, data.passes[pass.key] == true)
	end
	if data.passes.VIP and player.Character ~= nil then
		task.spawn(addVipTag, player.Character)
	end
	CastingService.refresh(player)
	MovieService.sync(player)
	LotService.refresh(player)
end

local function grantPass(player: Player, pass: Shop.Pass, announce: boolean)
	local data = DataService.getData(player)
	if data == nil or data.passes[pass.key] then
		return
	end
	data.passes[pass.key] = true
	DataService.markDirty(player)
	applyPasses(player)
	if announce then
		Analytics.event(player, "PassBought", 1, pass.key)
		RewardService.afterGrant(player, `{pass.name} is now active. Thank you!`)
	end
end

-- Called once the player's data has loaded. Yields (ownership checks), so call it in a task.
function ShopService.load(player: Player)
	applyPasses(player)
	player.CharacterAdded:Connect(function(character)
		if player:GetAttribute("PassVIP") then
			addVipTag(character)
		end
	end)
	for _, pass in Shop.Passes do
		local data = DataService.getData(player)
		if data == nil then
			return
		end
		if pass.id ~= 0 and not data.passes[pass.key] then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			-- A failed check is "not confirmed yet", never a denial: it is retried on the next join.
			if ok and owns == true then
				grantPass(player, pass, false)
			end
		end
	end
end

-- Roblox calls this for every developer product purchase, possibly more than once for the same
-- purchase, and again on a later join if we do not answer PurchaseGranted.
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local product = Shop.productById(receipt.ProductId)
	if product == nil then
		warn(`[ShopService] receipt for unknown product {receipt.ProductId}; add its id to Shop.luau`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- redelivered when they next join
	end
	local waited = 0
	while DataService.getData(player) == nil and player.Parent == Players and waited < DATA_WAIT_SECONDS do
		task.wait(0.25)
		waited += 0.25
	end
	if DataService.getData(player) == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local granted: string? = nil
	local saved = DataService.grantPurchaseOnce(player, tostring(receipt.PurchaseId), function(data)
		granted = RewardService.apply(player, data, product.reward, "IAP", product.key)
	end)
	if not saved then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= nil then -- nil when this purchase was already granted earlier
		Analytics.event(player, "ProductBought", 1, product.key)
		RewardService.afterGrant(player, `{product.name}: {granted}`)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local pass = Shop.passById(passId)
		if pass ~= nil then
			grantPass(player, pass, true)
		end
	end)
end

return ShopService
