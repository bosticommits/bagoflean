--!strict
-- PetsConfig: Shared configuration and types for Pet Merging System.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type PetStats = {
	power: number,
	speed: number,
	luck: number,
}

export type Pet = {
	id: string,
	species: string,
	rarity: Rarity,
	level: number?,
	stats: PetStats,
	createdAtUnixMs: number?,
	parentIds: { string }?,
}

export type Inventory = {
	capacity: number,
	pets: { Pet },
}

local PetsConfig = {}

PetsConfig.RARITY_LADDER: { Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local rarityIndex: { [Rarity]: number } = {}
for i, r in ipairs(PetsConfig.RARITY_LADDER) do
	rarityIndex[r] = i
end

function PetsConfig.getRarityIndex(rarity: Rarity): number
	return rarityIndex[rarity]
end

function PetsConfig.nextRarity(rarity: Rarity): Rarity?
	local idx = rarityIndex[rarity]
	if idx == nil then
		return nil
	end
	local nextIdx = idx + 1
	local nextR = PetsConfig.RARITY_LADDER[nextIdx]
	return nextR
end

-- Optional: base constraints per species (extend as needed)
PetsConfig.ALLOWED_SPECIES: { [string]: true } = {
	["Dog"] = true,
	["Cat"] = true,
	["Dragon"] = true,
	["Phoenix"] = true,
}

-- Validate stats schema bounds
PetsConfig.STAT_BOUNDS = {
	power = { min = 0, max = 1_000_000 },
	speed = { min = 0, max = 1_000_000 },
	luck = { min = 0, max = 1_000_000 },
}

-- Clamp and validate helper
function PetsConfig.clampStats(stats: PetStats): PetStats
	local b = PetsConfig.STAT_BOUNDS
	local function clamp(v: number, minV: number, maxV: number): number
		if v < minV then
			return minV
		elseif v > maxV then
			return maxV
		end
		return v
	end
	return {
		power = clamp(stats.power, b.power.min, b.power.max),
		speed = clamp(stats.speed, b.speed.min, b.speed.max),
		luck = clamp(stats.luck, b.luck.min, b.luck.max),
	}
end

return PetsConfig