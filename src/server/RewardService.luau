--!strict
-- Grants rewards (daily login track, Studio Requests, codes and developer products all share one
-- reward shape, Shop.Reward) and handles the claim remotes. The client names what it is claiming;
-- whether it is claimable, and what it gives, is decided here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local PlaytimeGifts = require(ReplicatedStorage.Shared.PlaytimeGifts)
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
local claimGift = Remotes.get("ClaimGift")
local giftsSync = Remotes.get("GiftsSync")
local testGifts = if RunService:IsStudio() then Remotes.get("TestGifts") else nil

local lastAction: { [Player]: { [string]: number } } = {}
local lastSync: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}
local lastCooldownReply: { [Player]: number } = {}
local COOLDOWN_REPLY_INTERVAL = 1 -- a spammer gets at most one "Slow down!" per second

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
		local lastReply = lastCooldownReply[player]
		if lastReply == nil or now - lastReply >= COOLDOWN_REPLY_INTERVAL then
			lastCooldownReply[player] = now
			fail(player, "Slow down!")
		end
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

-- What each quest list is called in analytics and in the "done" message.
local SKUS = { daily = "Request", weekly = "WeeklyQuest", festival = "FestivalGoal" }
local CLAIM_EVENTS = { daily = "RequestClaim", weekly = "WeeklyQuestClaim", festival = "FestivalGoalClaim" }
local NAMES = { daily = "Request", weekly = "Weekly quest", festival = "Festival goal" }

-- Claims a finished Studio Request (today's), weekly quest, Film Festival goal, or one that
-- finished before its day or week ended and waits in `carried`. `scope` is "weekly", "festival" or
-- "carried" for those; anything else means
-- the daily list, as before the Goals screen showed all three. A carried quest is named by its key
-- (not a position) and removed before it pays out, so it is claimed exactly once.
local function onClaimRequest(player: Player, index: any, scope: any)
	if not allow(player, "request", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	QuestTracker.ensure(data)
	if scope == "carried" then
		local waiting = Rewards.takeCarried(data.carried, index)
		if waiting == nil then
			return fail(player, "Already claimed")
		end
		local request = Rewards.getRequest(waiting.id)
		if request == nil then
			DataService.markDirty(player)
			QuestTracker.sync(player)
			return fail(player, "That quest is gone")
		end
		local text = RewardService.apply(player, data, request.reward, "TimedReward", SKUS[waiting.scope] or "Request")
		Analytics.event(player, CLAIM_EVENTS[waiting.scope] or "RequestClaim", 1, request.id)
		if waiting.scope == "daily" then
			QuestTracker.track(player, "request") -- festival goal: finish Studio Requests
		end
		return RewardService.afterGrant(player, `{NAMES[waiting.scope] or "Request"} done: {text}`)
	end
	local kind = if scope == "weekly" or scope == "festival" then scope else "daily"
	local list = if kind == "weekly" then data.weekly.list elseif kind == "festival" then data.festival.list else data.requests.list
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
	local text = RewardService.apply(player, data, request.reward, "TimedReward", SKUS[kind])
	Analytics.event(player, CLAIM_EVENTS[kind], 1, request.id)
	if kind == "daily" then
		QuestTracker.track(player, "request") -- festival goal: finish Studio Requests
	end
	RewardService.afterGrant(player, `{NAMES[kind]} done: {text}`)
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

-- Playtime gift ladder (PlaytimeGifts.luau). The server clock decides; the client only names
-- which present it tapped. `opened`/`text` tell the row which present just popped and what it gave.
local function syncGifts(player: Player, opened: number?, text: string?)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	PlaytimeGifts.tick(data.gifts, os.time())
	local claimed = {}
	for k = 1, #PlaytimeGifts.Ladder do
		claimed[k] = PlaytimeGifts.isClaimed(data.gifts, k)
	end
	giftsSync:FireClient(player, { played = data.gifts.played, claimed = claimed, opened = opened, text = text })
end

local function onClaimGift(player: Player, k: any)
	if not allow(player, "gift", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return fail(player, "Still loading your data")
	end
	PlaytimeGifts.tick(data.gifts, os.time())
	local ok, why = PlaytimeGifts.check(data.gifts, k)
	if not ok then
		syncGifts(player) -- puts the row right if it was ahead of the server
		return fail(player, why or "That didn't work")
	end
	PlaytimeGifts.claim(data.gifts, k)
	local text = RewardService.apply(player, data, PlaytimeGifts.Ladder[k].reward, "TimedReward", "PlaytimeGift")
	Analytics.event(player, "PlaytimeGiftClaim", k)
	RewardService.afterGrant(player)
	syncGifts(player, k, text)
end

-- Studio only: "skip" adds `minutes` of play, "reset" starts a fresh ladder (as after a long break).
local function onTestGifts(player: Player, action: any, minutes: any)
	local data = DataService.getData(player)
	if not RunService:IsStudio() or data == nil then
		return
	end
	PlaytimeGifts.tick(data.gifts, os.time())
	if action == "skip" and type(minutes) == "number" then
		data.gifts.played += math.clamp(minutes, 0, 120) * 60
	elseif action == "reset" then
		data.gifts = PlaytimeGifts.fresh(nil)
		PlaytimeGifts.begin(data.gifts, os.time())
	end
	syncGifts(player)
end

-- Call once the player's data has loaded: starts the session clock for the stay gift, and starts
-- or carries on the gift ladder.
function RewardService.joined(player: Player)
	joinedAt[player] = os.clock()
	local data = DataService.getData(player)
	if data ~= nil then
		PlaytimeGifts.begin(data.gifts, os.time())
		DataService.markDirty(player)
	end
	syncGifts(player)
end

function RewardService.start()
	claimDaily.OnServerEvent:Connect(onClaimDaily)
	claimRequest.OnServerEvent:Connect(onClaimRequest)
	redeemCode.OnServerEvent:Connect(onRedeemCode)
	claimStayGift.OnServerEvent:Connect(onClaimStayGift)
	claimGift.OnServerEvent:Connect(onClaimGift)
	Remotes.get("GiftsRequest").OnServerEvent:Connect(function(player)
		if allow(player, "giftsSync", 1) then
			syncGifts(player)
		end
	end)
	if testGifts ~= nil then
		testGifts.OnServerEvent:Connect(onTestGifts)
	end
	Remotes.get("RewardsRequest").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastSync[player] == nil or now - lastSync[player] >= 1 then
			lastSync[player] = now
			QuestTracker.sync(player)
		end
	end)
end

function RewardService.forget(player: Player)
	-- Bank the session's play time (and when they left) before the final save.
	local data = DataService.getData(player)
	if data ~= nil then
		PlaytimeGifts.tick(data.gifts, os.time())
	end
	lastAction[player] = nil
	lastSync[player] = nil
	joinedAt[player] = nil
	lastCooldownReply[player] = nil
end

return RewardService
