--!strict
-- BadgeAwards: wrapper around Roblox's BadgeService to award official Roblox badges safely.
-- Handles pcalls, session caching, and prevents redundant web API calls.
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Badges = require(ReplicatedStorage.Shared.Badges)

local BadgeAwards = {}

-- In-memory cache of badges awarded during this server session: [UserId]: { [badgeId]: true }
local awardedCache: { [number]: { [number]: boolean } } = {}

function BadgeAwards.init(player: Player)
	awardedCache[player.UserId] = {}
end

function BadgeAwards.cleanup(player: Player)
	awardedCache[player.UserId] = nil
end

-- Awards a badge by key if defined and not yet awarded
function BadgeAwards.award(player: Player, badgeKey: string)
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

	-- Marked before the async calls so two quick triggers make one web call; cleared only if the award itself fails.
	awardedCache[userId][badgeId] = true
	local function giveUp()
		if awardedCache[userId] ~= nil then
			awardedCache[userId][badgeId] = nil
		end
	end

	-- In Studio, BadgeService:AwardBadge can fail if security permissions or testing modes aren't enabled; protect with pcall
	task.spawn(function()
		local hasBadge = false
		local checkOk, checkErr = pcall(function()
			hasBadge = BadgeService:UserHasBadgeAsync(userId, badgeId)
		end)

		if not checkOk then
			warn(`[BadgeAwards] UserHasBadgeAsync failed for {player.Name}: {checkErr}`) -- stays cached: not retried on every trigger
			return
		end

		if hasBadge then
			return
		end

		local awardOk, awardErr = pcall(function()
			BadgeService:AwardBadge(userId, badgeId)
		end)

		if not awardOk then
			giveUp()
			warn(`[BadgeAwards] Failed to award badge '{badgeDef.name}' ({badgeId}) to {player.Name}: {awardErr}`)
		end
	end)
end

return BadgeAwards
