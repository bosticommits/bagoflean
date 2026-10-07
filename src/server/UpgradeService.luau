--!strict
-- Cash upgrades and Index rewards. The client names an upgrade or reward id; price, Fame gate,
-- level cap and the Index condition are all decided here. Replies go through StudioError/StudioSync.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LotService = require(script.Parent.LotService)
local MovieService = require(script.Parent.MovieService)
local Remotes = require(script.Parent.Remotes)

local buyUpgrade = Remotes.get("BuyUpgrade")
local claimReward = Remotes.get("ClaimReward")
local studioError = Remotes.get("StudioError")

local lastAction: { [Player]: number } = {}

local UpgradeService = {}

local lastCooldownReply: { [Player]: number } = {}

-- Rate limit. A rejection is answered at most once per second, so spam cannot make us spam back.
local function allow(player: Player): boolean
	local now = os.clock()
	local last = lastAction[player]
	if last ~= nil and now - last < Config.ActionCooldown then
		local lastReply = lastCooldownReply[player]
		if lastReply == nil or now - lastReply >= 1 then
			lastCooldownReply[player] = now
			studioError:FireClient(player, "cooldown")
		end
		return false
	end
	lastAction[player] = now
	return true
end

local function isId(value: any): boolean
	return type(value) == "string" and #value >= 1 and #value <= 32
end

-- Stats that other systems read (Luck attribute, royalty rate) change with every purchase or claim.
local function refreshStats(player: Player)
	CastingService.refresh(player)
	EconomyService.refresh(player)
	MovieService.sync(player)
end

local function onBuyUpgrade(player: Player, id: any)
	if not allow(player) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	local upgrade = if isId(id) then Upgrades.get(id) else nil
	if upgrade == nil then
		studioError:FireClient(player, "invalid")
		return
	end
	local level = Upgrades.level(data, upgrade.id)
	if level >= upgrade.maxLevel then
		studioError:FireClient(player, "maxed")
		return
	end
	if data.fame < upgrade.fame[level + 1] then
		studioError:FireClient(player, "fame")
		return
	end
	-- Bank royalties at the current rate and cap first: Cinema and Offline change both.
	EconomyService.accrue(data)
	if not EconomyService.spendCash(player, upgrade.costs[level + 1], "Upgrade:" .. upgrade.id) then
		studioError:FireClient(player, "cash")
		return
	end
	if upgrade.id == "Stages" then
		data.stageCount += 1
	else
		data.upgrades[upgrade.id] = level + 1
	end
	DataService.markDirty(player)
	refreshStats(player)
	if upgrade.id == "Stages" then
		LotService.refresh(player) -- a new sound stage appears on the lot
	end
end

local function onClaimReward(player: Player, id: any)
	if not allow(player) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	if not isId(id) then
		studioError:FireClient(player, "invalid")
		return
	end
	if data.rewards[id] then
		studioError:FireClient(player, "claimed")
		return
	end
	if not Upgrades.rewardEarned(data.index, id) then
		studioError:FireClient(player, "unavailable")
		return
	end
	data.rewards[id] = true
	DataService.markDirty(player)
	refreshStats(player)
end

function UpgradeService.start()
	buyUpgrade.OnServerEvent:Connect(onBuyUpgrade)
	claimReward.OnServerEvent:Connect(onClaimReward)
end

function UpgradeService.forget(player: Player)
	lastAction[player] = nil
	lastCooldownReply[player] = nil
end

return UpgradeService
