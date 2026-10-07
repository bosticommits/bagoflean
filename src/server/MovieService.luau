--!strict
-- Script shop, filming, clapperboard, and premiere. The server owns every number: prices come from
-- Movies, timers are os.time() stamps in the profile, and the premiere is rolled here when claimed.
-- Every remote argument is untrusted: types, ranges, ownership and cooldowns are checked first.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Movies = require(ReplicatedStorage.Shared.Movies)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local CastingService = require(script.Parent.CastingService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
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

local lastAction: { [Player]: { [string]: number } } = {}

local MovieService = {}

-- Returns true if the player may act now; records the attempt. Rejections get a reply.
local function allow(player: Player, action: string, cooldown: number): boolean
	local now = os.clock()
	local perPlayer = lastAction[player]
	if perPlayer == nil then
		perPlayer = {}
		lastAction[player] = perPlayer
	end
	local last = perPlayer[action]
	if last ~= nil and now - last < cooldown then
		studioError:FireClient(player, "cooldown")
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
		stageCount = data.stageCount,
		fame = data.fame,
		rate = EconomyService.rate(data),
		scripts = data.scripts,
		films = data.films,
		cinema = data.cinema,
		upgrades = data.upgrades,
		rewards = data.rewards,
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
	end
	if count < 1 or count > Config.MaxCast then
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
	if not EconomyService.spendCash(player, length.cost) then
		studioError:FireClient(player, "cash")
		return
	end
	local key = Movies.scriptKey(genre, lengthId)
	data.scripts[key] = (data.scripts[key] or 0) + 1
	DataService.markDirty(player)
	MovieService.sync(player)
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
	if not isInt(stage, 1, Config.MaxStages) or stage > data.stageCount then
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
	local now = os.time()
	table.insert(data.films, {
		stage = stage,
		title = Movies.randomTitle(random, genre),
		genre = genre,
		length = lengthId,
		cast = cast,
		startTime = now,
		endTime = now + length.seconds,
	})
	DataService.markDirty(player)
	MovieService.sync(player)
end

local function onClap(player: Player, stage: any)
	if not allow(player, "clap", Config.ClapCooldown) then
		return
	end
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	if not isInt(stage, 1, Config.MaxStages) then
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
	if not isInt(stage, 1, Config.MaxStages) then
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
	local fame = Movies.fame(payout)

	table.remove(data.films, filmIndex) -- frees the stage and the cast copies
	EconomyService.accrue(data) -- bank royalties at the old rate before the rate changes
	table.insert(data.cinema, {
		title = film.title,
		genre = film.genre,
		result = result.id,
		payout = payout,
		time = os.time(),
	})
	while #data.cinema > Config.CinemaCapacity do
		table.remove(data.cinema, 1)
	end
	data.fame += fame
	EconomyService.addCash(player, payout)

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
	})
	MovieService.sync(player)
	if result.id == "Masterpiece" then
		Remotes.announce(`{player.DisplayName}'s "{film.title}" is a MASTERPIECE!`)
	end
end

function MovieService.start()
	studioRequest.OnServerEvent:Connect(function(player)
		if allow(player, "request", 1) then
			MovieService.sync(player)
		end
	end)
	buyScript.OnServerEvent:Connect(onBuyScript)
	startFilm.OnServerEvent:Connect(onStartFilm)
	clapRemote.OnServerEvent:Connect(onClap)
	premiereRemote.OnServerEvent:Connect(onPremiere)
end

function MovieService.forget(player: Player)
	lastAction[player] = nil
end

return MovieService
