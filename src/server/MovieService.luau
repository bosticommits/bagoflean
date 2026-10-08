--!strict
-- Script shop, filming, clapperboard, and premiere. The server owns every number: prices come from
-- Movies, timers are os.time() stamps in the profile, and the premiere is rolled here when claimed.
-- Every remote argument is untrusted: types, ranges, ownership and cooldowns are checked first.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(ReplicatedStorage.Shared.Events)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local LotService = require(script.Parent.LotService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local random = Random.new()

local studioRequest = Remotes.get("StudioRequest")
local buyScript = Remotes.get("BuyScript")
local startFilm = Remotes.get("StartFilm")
local clapRemote = Remotes.get("Clap")
local premiereRemote = Remotes.get("Premiere")
local studioSync = Remotes.get("StudioSync")
local premiereResult = Remotes.get("PremiereResult")
local studioError = Remotes.get("StudioError")
local tutorialDone = Remotes.get("TutorialDone")
local useSkip = Remotes.get("UseSkip")

local lastAction: { [Player]: { [string]: number } } = {}
local lastCooldownReply: { [Player]: number } = {}
local COOLDOWN_REPLY_INTERVAL = 1 -- a spammer gets at most one "slow down" per second

local MovieService = {}

-- Returns true if the player may act now; records the attempt. A rejection gets a reply, but at
-- most one per COOLDOWN_REPLY_INTERVAL, and `silent` actions (background syncs) get none.
local function allow(player: Player, action: string, cooldown: number, silent: boolean?): boolean
	local now = os.clock()
	local perPlayer = lastAction[player]
	if perPlayer == nil then
		perPlayer = {}
		lastAction[player] = perPlayer
	end
	local last = perPlayer[action]
	if last ~= nil and now - last < cooldown then
		local lastReply = lastCooldownReply[player]
		if not silent and (lastReply == nil or now - lastReply >= COOLDOWN_REPLY_INTERVAL) then
			lastCooldownReply[player] = now
			studioError:FireClient(player, "cooldown")
		end
		return false
	end
	perPlayer[action] = now
	return true
end

local function isString(value: any, maxLength: number): boolean
	return type(value) == "string" and #value >= 1 and #value <= maxLength
end

-- Whole number in [min, max]. Rejects NaN, infinity and fractions.
local function isInt(value: any, min: number, max: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= min and value <= max
end

local function snapshot(player: Player): { [string]: any }?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	return {
		serverNow = os.time(),
		stageCount = data.stageCount, -- bought stages (the Sound Stage upgrade level)
		stages = Upgrades.stages(data), -- stages usable now, with the +1 Sound Stage pass
		passes = data.passes,
		skips = data.skips,
		luckBoostUntil = data.luckBoostUntil,
		fame = data.fame,
		rate = EconomyService.rate(data),
		scripts = data.scripts,
		films = data.films,
		cinema = data.cinema,
		upgrades = data.upgrades,
		rewards = data.rewards,
		trophies = data.trophies,
		tutorialDone = data.tutorialDone,
		rebirths = data.rebirths,
	}
end

function MovieService.sync(player: Player)
	local state = snapshot(player)
	if state ~= nil then
		studioSync:FireClient(player, state)
	end
end

local function findFilm(data: DataService.PlayerData, stage: number): (DataService.Film?, number?)
	for index, film in data.films do
		if film.stage == stage then
			return film, index
		end
	end
	return nil, nil
end

local function copiesInUse(data: DataService.PlayerData): { [string]: number }
	local used: { [string]: number } = {}
	for _, film in data.films do
		for _, key in film.cast do
			used[key] = (used[key] or 0) + 1
		end
	end
	return used
end

-- Validates a client-supplied cast list against the roster. Returns nil if anything is off.
local function parseCast(raw: any, data: DataService.PlayerData): { string }?
	if type(raw) ~= "table" then
		return nil
	end
	local count = 0
	for key, value in raw do
		if type(key) ~= "number" or not isString(value, 64) then
			return nil
		end
		count += 1
		if count > Config.MaxCast then
			return nil -- stop early: never walk a huge client-built table
		end
	end
	if count < 1 then
		return nil
	end

	local busy = copiesInUse(data)
	local need: { [string]: number } = {}
	local cast: { string } = {}
	for index = 1, count do
		local key = raw[index]
		if not isString(key, 64) then
			return nil -- gap in the array
		end
		local parts = string.split(key, ":")
		if #parts ~= 2 or Actors.getActor(parts[1]) == nil or Actors.getVariant(parts[2]) == nil then
			return nil
		end
		need[key] = (need[key] or 0) + 1
		if need[key] > (data.roster[key] or 0) - (busy[key] or 0) then
			return nil -- not enough free copies
		end
		cast[index] = key
	end
	return cast
end

local function onBuyScript(player: Player, genre: any, lengthId: any)
	if not allow(player, "buy", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	if not isString(genre, 16) or not isString(lengthId, 16) or not Movies.isGenre(genre) then
		studioError:FireClient(player, "invalid")
		return
	end
	local length = Movies.getLength(lengthId)
	if length == nil then
		studioError:FireClient(player, "invalid")
		return
	end
	-- Fame unlocks script lengths and genres (plan section 6).
	if data.fame < length.fame or data.fame < (Movies.GenreFame[genre] or 0) then
		studioError:FireClient(player, "fame")
		return
	end
	if not EconomyService.spendCash(player, length.cost, "Script:" .. length.id) then
		studioError:FireClient(player, "cash")
		return
	end
	local key = Movies.scriptKey(genre, lengthId)
	data.scripts[key] = (data.scripts[key] or 0) + 1
	DataService.markDirty(player)
	MovieService.sync(player)
	Analytics.onboarding(player, Analytics.Steps.FirstScript)
	QuestTracker.track(player, "script")
end

local function onStartFilm(player: Player, stage: any, genre: any, lengthId: any, rawCast: any)
	if not allow(player, "start", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	if not isInt(stage, 1, Config.StageLimit) or stage > Upgrades.stages(data) then
		studioError:FireClient(player, "invalid")
		return
	end
	if not isString(genre, 16) or not isString(lengthId, 16) or not Movies.isGenre(genre) then
		studioError:FireClient(player, "invalid")
		return
	end
	local length = Movies.getLength(lengthId)
	if length == nil then
		studioError:FireClient(player, "invalid")
		return
	end
	if findFilm(data, stage) ~= nil then
		studioError:FireClient(player, "busy")
		return
	end
	local scriptKey = Movies.scriptKey(genre, lengthId)
	if (data.scripts[scriptKey] or 0) < 1 then
		studioError:FireClient(player, "noscript")
		return
	end
	local cast = parseCast(rawCast, data)
	if cast == nil then
		studioError:FireClient(player, "nocast")
		return
	end

	-- Everything validated: consume the script and start the clock, with no yield in between.
	data.scripts[scriptKey] -= 1
	if data.scripts[scriptKey] <= 0 then
		data.scripts[scriptKey] = nil
	end
	-- A player's very first movie, if it is a Short Film, finishes fast so the tutorial fits in a
	-- minute. Only ever the first one: nothing in the cinema and nothing else filming.
	local seconds = length.seconds
	if lengthId == "Short" and #data.cinema == 0 and #data.films == 0 and data.trophies == 0 then
		seconds = math.min(seconds, Config.FirstFilmSeconds)
	end
	if data.passes.FastFilming then
		seconds = math.max(1, math.floor(seconds * Config.FastFilmingMultiplier))
	end
	local now = os.time()
	table.insert(data.films, {
		stage = stage,
		title = Movies.randomTitle(random, genre),
		genre = genre,
		length = lengthId,
		cast = cast,
		startTime = now,
		endTime = now + seconds,
	})
	DataService.markDirty(player)
	MovieService.sync(player)
	LotService.refresh(player) -- the stage's ON AIR light comes on
	Analytics.onboarding(player, Analytics.Steps.FirstFilm)
end

local function onClap(player: Player, stage: any)
	if not allow(player, "clap", Config.ClapCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	if not isInt(stage, 1, Config.StageLimit) then
		studioError:FireClient(player, "invalid")
		return
	end
	local film = findFilm(data, stage)
	local now = os.time()
	if film == nil or film.endTime <= now then
		MovieService.sync(player) -- nothing to speed up; resync so the client catches up
		return
	end
	film.endTime = math.max(now, film.endTime - Upgrades.clapSeconds(data))
	DataService.markDirty(player)
	MovieService.sync(player)
	QuestTracker.track(player, "clap")
end

local function onPremiere(player: Player, stage: any)
	if not allow(player, "premiere", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	if not isInt(stage, 1, Config.StageLimit) then
		studioError:FireClient(player, "invalid")
		return
	end
	local film, filmIndex = findFilm(data, stage)
	if film == nil or filmIndex == nil then
		studioError:FireClient(player, "none")
		return
	end
	if film.endTime > os.time() then
		studioError:FireClient(player, "notready")
		return
	end
	local length = Movies.getLength(film.length)
	if length == nil then
		studioError:FireClient(player, "invalid")
		return
	end

	-- Roll and settle with no yield, so the film cannot be premiered twice.
	local power = Movies.castPower(film.cast, film.genre)
	local result = Movies.rollResult(random, CastingService.getLuck(player))
	local genreBonus = Upgrades.genreBonus(data, film.genre)
	local payout = Movies.payout(length, power, result, genreBonus)
	-- Award Night doubles premiere payouts (plan section 5).
	local awardNight = Events.awardNight(os.time())
	if awardNight then
		payout *= Config.AwardNightPayoutMultiplier
	end
	local fame = Movies.fame(payout)
	-- Rebirths multiply the Cash, not the Fame, so Fame unlocks stay where ECONOMY.md puts them.
	-- The cinema keeps the boosted payout, so the box office grows with it.
	local rebirthBonus = Rebirth.cashMultiplier(data.rebirths)
	payout = math.floor(payout * rebirthBonus)

	table.remove(data.films, filmIndex) -- frees the stage and the cast copies
	EconomyService.accrue(data) -- bank royalties at the old rate before the rate changes
	table.insert(data.cinema, {
		title = film.title,
		genre = film.genre,
		result = result.id,
		payout = payout,
		time = os.time(),
	})
	-- Over capacity: drop the lowest-earning movie (the oldest of equals), never a big earner.
	while #data.cinema > Config.CinemaCapacity do
		local weakest = 1
		for index, movie in data.cinema do
			if movie.payout < data.cinema[weakest].payout then
				weakest = index
			end
		end
		table.remove(data.cinema, weakest)
	end
	data.fame += fame
	EconomyService.addCash(player, payout, "Gameplay", "Premiere")

	premiereResult:FireClient(player, {
		title = film.title,
		genre = film.genre,
		length = film.length,
		cast = film.cast,
		result = result.id,
		payout = payout,
		fame = fame,
		power = power,
		genreBonus = genreBonus,
		awardNight = awardNight,
		rebirthBonus = rebirthBonus,
	})
	if result.id == "Masterpiece" then
		data.trophies += 1
	end
	MovieService.sync(player)
	LotService.refresh(player)
	Analytics.onboarding(player, Analytics.Steps.FirstPremiere)
	Analytics.event(player, "Premiere", 1, result.id, film.length)
	QuestTracker.track(player, "premiere")
	QuestTracker.track(player, "premiere:" .. film.genre) -- weekly genre quests
	if result.multiplier >= 3 then
		QuestTracker.track(player, "hit")
	end
	if result.id == "Masterpiece" then
		Remotes.announce(`{player.DisplayName}'s "{film.title}" is a MASTERPIECE!`)
		LotService.celebrate(player, "masterpiece")
	end
end

-- The client finished or skipped the tutorial. No arguments, idempotent.
local function onTutorialDone(player: Player)
	if not allow(player, "tutorial", 1, true) then
		return
	end
	local data = DataService.getData(player)
	if data == nil or data.tutorialDone then
		return
	end
	data.tutorialDone = true
	DataService.markDirty(player)
	MovieService.sync(player)
	Analytics.onboarding(player, Analytics.Steps.TutorialDone)
end

-- Spends a Skip Filming token to finish the film on `stage` now. Tokens come from the Skip Filming
-- product, daily rewards and codes; the client prompts the purchase when it has none.
local function onUseSkip(player: Player, stage: any)
	if not allow(player, "skip", Config.ActionCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		studioError:FireClient(player, "loading")
		return
	end
	if not isInt(stage, 1, Config.StageLimit) then
		studioError:FireClient(player, "invalid")
		return
	end
	local film = findFilm(data, stage)
	local now = os.time()
	if film == nil or film.endTime <= now then
		MovieService.sync(player)
		return
	end
	if data.skips < 1 then
		studioError:FireClient(player, "noskip")
		return
	end
	data.skips -= 1
	film.endTime = now
	DataService.markDirty(player)
	MovieService.sync(player)
	Analytics.event(player, "SkipUsed", 1, film.length)
end

-- Takes `seconds` off every film still shooting (Golden Hour runs this every second), never
-- past now, and shows the new times.
function MovieService.fastForward(player: Player, seconds: number)
	local data = DataService.getData(player)
	if data == nil or not (seconds > 0) then
		return
	end
	local now = os.time()
	local changed = false
	for _, film in data.films do
		if film.endTime > now then
			film.endTime = math.max(now, film.endTime - seconds)
			changed = true
		end
	end
	if changed then
		DataService.markDirty(player)
		MovieService.sync(player)
	end
end

function MovieService.start()
	studioRequest.OnServerEvent:Connect(function(player)
		if allow(player, "request", 1, true) then
			MovieService.sync(player)
		end
	end)
	buyScript.OnServerEvent:Connect(onBuyScript)
	startFilm.OnServerEvent:Connect(onStartFilm)
	clapRemote.OnServerEvent:Connect(onClap)
	premiereRemote.OnServerEvent:Connect(onPremiere)
	tutorialDone.OnServerEvent:Connect(onTutorialDone)
	useSkip.OnServerEvent:Connect(onUseSkip)
end

function MovieService.forget(player: Player)
	lastAction[player] = nil
	lastCooldownReply[player] = nil
end

return MovieService
