--!strict
-- MergeService: Shared merge rules and pure functions (no side effects).
local HttpService = game:GetService("HttpService")

local PetsConfig = require(script.Parent:WaitForChild("PetsConfig"))
local Logger = require(script.Parent:WaitForChild("Logger"))

export type Rarity = PetsConfig.Rarity
export type PetStats = PetsConfig.PetStats
export type Pet = PetsConfig.Pet

export type CanMergeResult = {
	ok: boolean,
	reason: string?,
}

export type MergeOutcome =
	| { ok: true, pet: Pet, warnings: { string }? }
	| { ok: false, reason: string }

local MergeService = {}

local TOP_RARITY: Rarity = "Legendary"

local function average(a: number, b: number): number
	return (a + b) / 2
end

local function averageStats(a: PetStats, b: PetStats): PetStats
	return PetsConfig.clampStats({
		power = average(a.power, b.power),
		speed = average(a.speed, b.speed),
		luck = average(a.luck, b.luck),
	})
end

-- Pure validation: does not check ownership; only pet-to-pet rules.
function MergeService.canMerge(petA: Pet, petB: Pet): CanMergeResult
	if petA.id == petB.id then
		return { ok = false, reason = "Cannot merge the same pet." }
	end
	if petA.species ~= petB.species then
		return { ok = false, reason = "Pets must be the same species." }
	end
	if petA.rarity ~= petB.rarity then
		return { ok = false, reason = "Pets must share the same rarity." }
	end
	if petA.rarity == TOP_RARITY then
		return { ok = false, reason = "Top rarity cannot be merged further." }
	end
	if PetsConfig.getRarityIndex(petA.rarity) == nil then
		return { ok = false, reason = "Unknown rarity on pet A." }
	end
	if PetsConfig.getRarityIndex(petB.rarity) == nil then
		return { ok = false, reason = "Unknown rarity on pet B." }
	end
	return { ok = true }
end

-- Deterministic pet ID to support duplicate protection and idempotency.
local function generatePetId(userId: number, parentAId: string, parentBId: string): string
	-- Sorted parent IDs ensure order-independence.
	local p1, p2 = parentAId, parentBId
	if p2 < p1 then
		p1, p2 = p2, p1
	end
	-- Use a stable GUID namespace string to avoid collisions across environments.
	local seed = string.format("%d:%s:%s:%d", userId, p1, p2, os.time())
	local hash = HttpService:GenerateGUID(false) .. "-" .. HttpService:GenerateGUID(false)
	-- Include seed for traceability even if hash is random.
	return string.sub(string.gsub(seed, ":", "-"), 1, 24) .. "-" .. string.sub(hash, 1, 12)
end

-- Merge two pets to create a new pet. Assumes ownership/capacity checks elsewhere.
function MergeService.merge(userId: number, petA: Pet, petB: Pet): MergeOutcome
	local can = MergeService.canMerge(petA, petB)
	if not can.ok then
		return { ok = false, reason = can.reason :: string }
	end
	local nextRarity = PetsConfig.nextRarity(petA.rarity)
	if not nextRarity then
		return { ok = false, reason = "No next rarity available." }
	end
	local newStats = averageStats(petA.stats, petB.stats)

	local newPet: Pet = {
		id = generatePetId(userId, petA.id, petB.id),
		species = petA.species,
		rarity = nextRarity :: Rarity,
		level = math.max(petA.level or 1, petB.level or 1),
		stats = newStats,
		createdAtUnixMs = math.floor(os.clock() * 1000),
		parentIds = { petA.id, petB.id },
	}

	Logger.info("merge.result", nil, {
		userId = userId,
		parents = { petAId = petA.id, petBId = petB.id },
		resultPetId = newPet.id,
		rarity = newPet.rarity,
	})

	return { ok = true, pet = newPet, warnings = nil }
end

return MergeService