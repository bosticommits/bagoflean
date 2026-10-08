--!strict
-- Grants rewards (daily login track, Studio Requests, codes and developer products all share one
-- reward shape, Shop.Reward) and handles the claim remotes. The client names what it is claiming;
-- whether it is claimable, and what it gives, is decided here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Rewards = require(ReplicatedStorage.Shared.Rewards)
local Analytics = require(script.Parent.Analytics)
local CastingService = require(script.Parent.CastingService)
local Codes = require(script.Parent.Codes)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LiveConfig = require(script.Parent.LiveConfig)
local MovieService = require(script.Parent.MovieService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local claimDaily = Remotes.get("ClaimDaily")
local claimRequest = Remotes.get("ClaimRequest")
local redeemCode = Remotes.get("RedeemCode")
local claimStayGift = Remotes.get("ClaimStayGift")
local rewardResult = Remotes.get("RewardResult")

local lastAction: { [Player]: { [string]: number } } = {}
local lastSync: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}

local RewardService = {}

-- Applies a reward to the player's data and returns what it gave, as text. Never yields, so
-- ShopService can run it inside a receipt grant. Call afterGrant once the grant is settled.
function RewardService.apply(player: Player, data: DataService.PlayerData, reward: Rewards.Reward, tx: string, sku: string): string
	local text = Rewards.describe(reward, EconomyService.rate(data))
	local cash = Rewards.cashAmount(reward, EconomyService.rate(data))
	if cash > 0 then
		EconomyService.addCash(player, cash, tx, sku)
	end
	local scripts = reward.script
	if scripts ~= nil and Movies.isGenre(scripts.genre) and Movies.getLength(scripts.length) ~= nil then
		local key = Movies.scriptKey(scripts.genre, scripts.length)
		data.scripts[key] = (data.scripts[key] or 0) + scripts.count
	end
	if reward.luckMinutes ~= nil then
		data.luckBoostUntil = math.max(data.luckBoostUntil, os.time()) + reward.luckMinutes * 60
	end
	if reward.skips ~= nil then
		data.skips += reward.skips
	end
	DataService.markDirty(player)
	return text
end

-- Pushes every screen that can show a reward (Cash, Luck, scripts, skips, rewards panel).
function RewardService.afterGrant(player: Player, message: string?)
	EconomyService.refresh(player)
	CastingService.refresh(player)
	MovieService.sync(player)
	QuestTracker.sync(player)
	if message ~= nil then
		rewardResult:FireClient(player, true, message)
	end
end

local function fail(player: Player, text: string)
	rewardResult:FireClient(player, false, text)
end

-- Rate limit per kind of claim, so claiming the daily reward and then a request right after both
-- work. A rejected tap is told "Slow down!" rather than ignored, so the button never seems dead.
local function allow(player: Player, action: string, cooldown: number): boolean
	local now = os.clock()
	local perPlayer = lastAction[player]
	if perPlayer == nil then
		perPlayer = {}
		lastAction[player] = perPlayer
	end
	local last = perPlayer[action]
	if last ~= nil and now - last < cooldown then
		fail(player, "Slow down!")
		return false
	end
	perPlayer[action] = now
	return true
end

local function onClaimDaily(player: Player)
	if not allow(player, "daily", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	local today = Rewards.today(os.time())
	local canClaim, streak = Rewards.dailyStatus(data.daily, today)
	if not canClaim then
		return fail(player, "Already claimed today. Come back tomorrow!")
	end
	data.daily = { day = today, streak = streak }
	local text = RewardService.apply(player, data, Rewards.dailyReward(streak), "TimedReward", "Daily")
	Analytics.event(player, "DailyClaim", streak)
	RewardService.afterGrant(player, `Day {streak}: {text}`)
end

-- Claims a finished Studio Request (today's) or weekly quest. `scope` is "weekly" for the latter;
-- anything else means the daily list, as before the Goals screen showed both.
local function onClaimRequest(player: Player, index: any, scope: any)
	if not allow(player, "request", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	QuestTracker.ensure(data)
	local weekly = scope == "weekly"
	local list = if weekly then data.weekly.list else data.requests.list
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #list then
		return fail(player, "That didn't work")
	end
	local entry = list[index]
	local request = Rewards.getRequest(entry.id)
	if request == nil or entry.claimed then
		return fail(player, "Already claimed")
	end
	if entry.progress < request.target then
		return fail(player, "Not done yet")
	end
	entry.claimed = true
	local text = RewardService.apply(player, data, request.reward, "TimedReward", if weekly then "WeeklyQuest" else "Request")
	Analytics.event(player, if weekly then "WeeklyQuestClaim" else "RequestClaim", 1, request.id)
	RewardService.afterGrant(player, `{if weekly then "Weekly quest" else "Request"} done: {text}`)
end

local function onRedeemCode(player: Player, raw: any)
	-- Codes keep the longer cooldown: it is what stops guessing codes by brute force.
	if not allow(player, "code", Config.RewardCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	if type(raw) ~= "string" or #raw < 1 or #raw > 40 then
		return fail(player, "Invalid code")
	end
	local code = string.upper((string.gsub(raw, "%s", "")))
	local entry = Codes[code]
	if entry == nil then
		return fail(player, "Invalid code")
	end
	if (entry.expires ~= nil and os.time() >= entry.expires) or LiveConfig.codeDisabled(code) then
		return fail(player, "That code has expired")
	end
	if data.codes[code] then
		return fail(player, "You already used that code")
	end
	data.codes[code] = true
	local text = RewardService.apply(player, data, entry.reward, "TimedReward", "Code")
	Analytics.event(player, "CodeRedeemed", 1, code)
	RewardService.afterGrant(player, `Code redeemed: {text}`)
end

-- "Don't leave yet!" gift. Once per UTC day and only after StayGiftMinSeconds of play this
-- session, so opening the menu over and over, or joining just to claim it, gets nothing.
local function onClaimStayGift(player: Player)
	if not allow(player, "stayGift", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	local started = joinedAt[player]
	if data == nil or started == nil then
		return fail(player, "Still loading your data")
	end
	local today = Rewards.today(os.time())
	if data.stayGiftDay >= today then
		return fail(player, "Already claimed today")
	end
	local left = Config.StayGiftMinSeconds - (os.clock() - started)
	if left > 0 then
		return fail(player, `Play {math.ceil(left / 60)} more min to unlock this gift`)
	end
	data.stayGiftDay = today
	local text = RewardService.apply(player, data, Rewards.StayGift, "TimedReward", "StayGift")
	Analytics.event(player, "StayGiftClaim")
	RewardService.afterGrant(player, `Gift: {text}`)
end

-- Call once the player's data has loaded: starts the session clock for the stay gift.
function RewardService.joined(player: Player)
	joinedAt[player] = os.clock()
end

function RewardService.start()
	claimDaily.OnServerEvent:Connect(onClaimDaily)
	claimRequest.OnServerEvent:Connect(onClaimRequest)
	redeemCode.OnServerEvent:Connect(onRedeemCode)
	claimStayGift.OnServerEvent:Connect(onClaimStayGift)
	Remotes.get("RewardsRequest").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastSync[player] == nil or now - lastSync[player] >= 1 then
			lastSync[player] = now
			QuestTracker.sync(player)
		end
	end)
end

function RewardService.forget(player: Player)
	lastAction[player] = nil
	lastSync[player] = nil
	joinedAt[player] = nil
end

return RewardService
