--!strict
-- Rare-pull announcements (plan section 22). Superstar and up: a banner and chat line for this
-- server (the RarePull remote; clients build the text from ids). Legend and Icon also go to every
-- other server through MessagingService.
-- Trust: the message is built here from server values (UserId, actor/variant/tier ids, JobId), never
-- free text. Receivers validate every field (PullNews.validate), drop unknown ids and their own
-- JobId, and look the name up themselves with GetNameFromUserIdAsync. That name is a Roblox
-- username, which Roblox already moderates, and no player-typed text is ever shown, so no
-- TextService filtering is needed (filtering is for text a player wrote).
-- Limits: publish at most 1 per 10 s per server with a 3-deep queue; show at most 6 global banners
-- a minute. "GlobalPulls" in LiveConfig's DisabledEvents switches the cross-server part off live.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PullNews = require(ReplicatedStorage.Shared.PullNews)
local LiveConfig = require(script.Parent.LiveConfig)
local Remotes = require(script.Parent.Remotes)

local TOPIC = "RarePulls"
local PUBLISH_EVERY = 10
local QUEUE_MAX = 3
local SHOW_PER_MINUTE = 6

local rarePull = Remotes.get("RarePull")
local queue: { PullNews.Message } = {}
local canShow = PullNews.limiter(SHOW_PER_MINUTE, 60)
local names: { [number]: string } = {}

local PullNewsService = {}

-- Retries a yielding call with backoff (1, 2, 4 s). Returns whether it worked.
local function retry(label: string, fn: () -> ()): boolean
	for attempt = 1, 4 do
		local ok, err = pcall(fn :: () -> any)
		if ok then
			return true
		end
		warn(`[PullNews] {label} failed (try {attempt}): {err}`)
		if attempt < 4 then
			task.wait(2 ^ (attempt - 1))
		end
	end
	return false
end

local function nameOf(userId: number): string?
	if names[userId] == nil then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		if ok and type(name) == "string" then
			names[userId] = name
		end
	end
	return names[userId]
end

-- A Superstar-or-better pull in this server. Called by CastingService.
function PullNewsService.onPull(player: Player, actorId: string, variantId: string, tierId: string)
	if not PullNews.isBig(tierId) then
		return
	end
	rarePull:FireAllClients(player.UserId, player.DisplayName, actorId, variantId, false)
	if PullNews.Global[tierId] and not LiveConfig.switchedOff("GlobalPulls") then
		if #queue >= QUEUE_MAX then
			table.remove(queue, 1) -- a burst keeps the newest
		end
		table.insert(queue, PullNews.message(player.UserId, actorId, variantId, tierId, game.JobId))
	end
end

-- A message from MessagingService (or a fake one in Studio: { Data = {...} }).
function PullNewsService.onMessage(message: any)
	if LiveConfig.switchedOff("GlobalPulls") or type(message) ~= "table" then
		return
	end
	local msg = PullNews.validate(message.Data, game.JobId)
	if msg == nil or not canShow(os.clock()) then
		return
	end
	local name = nameOf(msg.u)
	if name ~= nil then
		rarePull:FireAllClients(msg.u, name, msg.a, msg.v, true)
	end
end

function PullNewsService.start()
	task.spawn(function()
		retry("subscribe", function()
			MessagingService:SubscribeAsync(TOPIC, PullNewsService.onMessage)
		end)
	end)
	task.spawn(function()
		while true do
			local msg = table.remove(queue, 1)
			if msg ~= nil and not LiveConfig.switchedOff("GlobalPulls") then
				retry("publish", function()
					MessagingService:PublishAsync(TOPIC, msg)
				end)
				task.wait(PUBLISH_EVERY)
			else
				task.wait(1)
			end
		end
	end)
end

return PullNewsService
