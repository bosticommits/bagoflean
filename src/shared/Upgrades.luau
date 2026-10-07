--!strict
-- Cash upgrades, Index rewards, and the stats derived from them. Pure functions of the player's
-- saved fields, so the UI shows exactly what the server applies. Only the server changes the data.
local Actors = require(script.Parent.Actors)
local Config = require(script.Parent.Config)

-- The slice of player data these functions read.
export type Stats = {
	upgrades: { [string]: number },
	stageCount: number,
	rewards: { [string]: boolean },
	passes: { [string]: boolean }?, -- owned game passes (see Shop)
}

export type Upgrade = {
	id: string,
	name: string,
	maxLevel: number,
	costs: { number }, -- price of level n+1 is costs[n+1]
	fame: { number }, -- Fame needed for level n+1
	effect: (level: number) -> string, -- what you have at `level`
}

local Upgrades = {}

-- Prices and Fame gates are tuned with tools/economy_sim.py (see ECONOMY.md and plan section 4).
Upgrades.List = {
	{
		id = "Stages",
		name = "Sound Stage",
		maxLevel = Config.MaxStages - Config.StartingStages,
		costs = { 600, 25000, 400000 },
		fame = { 50, 2800, 16000 },
		effect = function(level)
			local stages = Config.StartingStages + level
			return `{stages} stage{if stages == 1 then "" else "s"} filming at once`
		end,
	},
	{
		id = "Cinema",
		name = "Cinema Size",
		maxLevel = 6,
		costs = { 300, 2000, 12000, 80000, 500000, 3000000 },
		fame = { 0, 0, 0, 0, 0, 0 },
		effect = function(level)
			return `Royalties x{1 + Config.CinemaStep * level}`
		end,
	},
	{
		id = "Offline",
		name = "Offline Earnings",
		maxLevel = 5,
		costs = { 500, 4000, 30000, 250000, 2000000 },
		fame = { 0, 0, 0, 0, 0 },
		effect = function(level)
			local hours = (Config.OfflineCapSeconds + Config.OfflineCapStepSeconds * level) / 3600
			return `Earn up to {hours}h while away`
		end,
	},
	{
		id = "Luck",
		name = "Luck",
		maxLevel = 10,
		costs = { 100, 500, 2000, 8000, 30000, 100000, 400000, 1500000, 6000000, 25000000 },
		fame = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
		effect = function(level)
			return `+{string.format("%.1f", Config.LuckStep * level)} Luck`
		end,
	},
	{
		id = "Clap",
		name = "Clapperboard",
		maxLevel = 4,
		costs = { 200, 3000, 40000, 500000 },
		fame = { 0, 0, 0, 0 },
		effect = function(level)
			return `Each tap takes {Config.ClapSeconds + Config.ClapStep * level}s off`
		end,
	},
} :: { Upgrade }

local upgradeById: { [string]: Upgrade } = {}
for _, upgrade in Upgrades.List do
	upgradeById[upgrade.id] = upgrade
end

function Upgrades.get(id: string): Upgrade?
	return upgradeById[id]
end

function Upgrades.level(stats: Stats, id: string): number
	if id == "Stages" then
		return math.max(0, stats.stageCount - Config.StartingStages)
	end
	return stats.upgrades[id] or 0
end

-- Derived stats ---------------------------------------------------------------------------------

function Upgrades.luck(stats: Stats): number
	local tierRewards = 0
	for id, claimed in stats.rewards do
		if claimed and string.sub(id, 1, 5) == "tier:" then
			tierRewards += 1
		end
	end
	return Config.BaseLuck + Config.LuckStep * Upgrades.level(stats, "Luck") + Config.TierRewardLuck * tierRewards
end

-- Sound stages the player can film on: bought stages plus the +1 Sound Stage pass.
function Upgrades.stages(stats: Stats): number
	local passes = stats.passes
	local bonus = if passes ~= nil and passes.ExtraStage then Config.PassStages else 0
	return math.min(stats.stageCount + bonus, Config.StageLimit)
end

function Upgrades.clapSeconds(stats: Stats): number
	return Config.ClapSeconds + Config.ClapStep * Upgrades.level(stats, "Clap")
end

function Upgrades.offlineCap(stats: Stats): number
	return Config.OfflineCapSeconds + Config.OfflineCapStepSeconds * Upgrades.level(stats, "Offline")
end

function Upgrades.royaltyMultiplier(stats: Stats): number
	return 1 + Config.CinemaStep * Upgrades.level(stats, "Cinema")
end

function Upgrades.genreBonus(stats: Stats, genre: string): number
	return 1 + (if stats.rewards["genre:" .. genre] then Config.GenreBonus else 0)
end

-- Index rewards ---------------------------------------------------------------------------------

local function actorDiscovered(index: { [string]: boolean }, actorId: string): boolean
	for _, variant in Actors.Variants do
		if index[Actors.key(actorId, variant.id)] then
			return true
		end
	end
	return false
end
Upgrades.actorDiscovered = actorDiscovered

-- (discovered, total) actors for a tier row.
function Upgrades.tierProgress(index: { [string]: boolean }, tierId: string): (number, number)
	local found, total = 0, 0
	for _, actor in Actors.actorsInTier(tierId) do
		total += 1
		if actorDiscovered(index, actor.id) then
			found += 1
		end
	end
	return found, total
end

-- (discovered, total) actors of a genre.
function Upgrades.genreProgress(index: { [string]: boolean }, genre: string): (number, number)
	local found, total = 0, 0
	for _, actor in Actors.List do
		if actor.genre == genre then
			total += 1
			if actorDiscovered(index, actor.id) then
				found += 1
			end
		end
	end
	return found, total
end

-- Reward ids are "tier:<TierId>" or "genre:<Genre>". True when the condition is met (claimed or not).
function Upgrades.rewardEarned(index: { [string]: boolean }, rewardId: string): boolean
	local kind, name = string.match(rewardId, "^(%a+):(.+)$")
	if kind == "tier" and name ~= nil and Actors.getTier(name) ~= nil then
		local found, total = Upgrades.tierProgress(index, name)
		return total > 0 and found == total
	elseif kind == "genre" and name ~= nil then
		local found, total = Upgrades.genreProgress(index, name)
		return total > 0 and found == total
	end
	return false
end

return Upgrades
