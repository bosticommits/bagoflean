--!strict
-- BadgeService wrapper to award official Roblox badges safely.
-- Handles pcalls, session caching, and prevents redundant web API calls.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Badges = require(ReplicatedStorage.Shared.Badges)

local PlayerBadgeService = {}

-- In-memory cache of badges awarded during this server session: [UserId]: { [badgeId]: true }
local awardedCache: { [number]: { [number]: boolean } } = {}

function PlayerBadgeService.init(player: Player)
	awardedCache[player.UserId] = {}
end

function PlayerBadgeService.cleanup(player: Player)
	awardedCache[player.UserId] = nil
end

-- Awards a badge by key if defined and not yet awarded
function PlayerBadgeService.award(player: Player, badgeKey: string)
	local badgeDef = Badges.List[badgeKey]
	if badgeDef == nil or badgeDef.id == 0 then
		return
	end

	local badgeId = badgeDef.id
	local userId = player.UserId

	if awardedCache[userId] == nil then
		awardedCache[userId] = {}
	end

	if awardedCache[userId][badgeId] then
		return
	end

	-- In Studio, BadgeService:AwardBadge can fail if security permissions or testing modes aren't enabled; protect with pcall
	task.spawn(function()
		local hasBadge = false
		local checkOk, checkErr = pcall(function()
			hasBadge = BadgeService:UserHasBadgeAsync(userId, badgeId)
		end)

		if not checkOk then
			warn(`[BadgeService] UserHasBadgeAsync failed for {player.Name}: {checkErr}`)
			return
		end

		if hasBadge then
			if awardedCache[userId] ~= nil then
				awardedCache[userId][badgeId] = true
			end
			return
		end

		local awardOk, awardErr = pcall(function()
			BadgeService:AwardBadge(userId, badgeId)
		end)

		if awardOk then
			if awardedCache[userId] ~= nil then
				awardedCache[userId][badgeId] = true
			end
		else
			warn(`[BadgeService] Failed to award badge '{badgeDef.name}' ({badgeId}) to {player.Name}: {awardErr}`)
		end
	end)
end

return PlayerBadgeService
