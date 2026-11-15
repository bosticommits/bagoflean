--!strict
-- Connects the loading screen (ReplicatedFirst/LoadingScreen.client.luau, which cannot require client
-- modules) to the game: tells it when the client UI is ready and what to show a returning player,
-- and plays the hand-off sounds through Sfx so they respect the volume and mute settings.
-- Player attributes used: LoadingScreen ("loading" / "handoff" / nil, set by the screen), ClientReady,
-- LoadingNew (true for a player who still has the tutorial ahead), LoadingWelcome, LoadingLive.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientState = require(script.Parent.ClientState)
local Events = require(ReplicatedStorage.Shared.Events)
local LoadingLines = require(ReplicatedStorage.Shared.LoadingLines)
local Sfx = require(script.Parent.Sfx)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local SpecialEventsUi = require(script.Parent.SpecialEventsUi)

local LoadingBridge = {}

local function festivalGenre(): string?
	local raw = ReplicatedStorage:GetAttribute("Festival")
	if type(raw) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if ok and type(data) == "table" and type(data.genre) == "string" then
		return data.genre
	end
	return nil
end

local function liveLine(): string?
	local now = workspace:GetServerTimeNow()
	local awardNight = Events.awardNight(now)
	local weekend = ReplicatedStorage:GetAttribute("LiveConfig_CastingLuckMultiplier")
	local surprise = SpecialEventsUi.readLive()
	return LoadingLines.liveLine({
		awardNight = awardNight,
		luckMultiplier = if typeof(weekend) == "number" then weekend else 1,
		surpriseName = if surprise ~= nil and surprise.ends > now then surprise.event.name else nil,
		festivalGenre = festivalGenre(),
	})
end

-- Plays the clapper snap and "Quiet on set!" when the screen starts its fade (once).
function LoadingBridge.startSounds()
	local player = Players.LocalPlayer
	local played = false
	local function onChanged()
		if played or player:GetAttribute("LoadingScreen") ~= "handoff" then
			return
		end
		played = true
		Sfx.play("LoadClapper")
		local quiet = Sounds.Slots.lucienQuietOnSet
		if quiet ~= nil and quiet.id ~= 0 then -- silent until the clip's asset id is pasted in Sounds
			Sfx.play("lucienQuietOnSet")
		end
	end
	player:GetAttributeChangedSignal("LoadingScreen"):Connect(onChanged)
	onChanged()
end

-- Call once the studio snapshot has arrived. Returns true when it announced.
function LoadingBridge.announce(): boolean
	local studio = ClientState.studio
	if studio == nil then
		return false
	end
	local player = Players.LocalPlayer
	local isNew = studio.tutorialDone ~= true
	player:SetAttribute("LoadingNew", isNew)
	if not isNew then
		player:SetAttribute("LoadingWelcome", LoadingLines.welcomeBack(player.DisplayName))
		player:SetAttribute("LoadingLive", liveLine())
	end
	player:SetAttribute("ClientReady", true)
	return true
end

return LoadingBridge
