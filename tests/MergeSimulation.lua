--!strict
-- Merge simulation: runs multiple merges and prints structured logs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Logger"))
local PetsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetsConfig"))
local MergeService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MergeService"))
local MockDataStoreAdapter = require(ServerScriptService:WaitForChild("Adapters"):WaitForChild("MockDataStoreAdapter"))

local function randomPet(id: string, species: string, rarity: PetsConfig.Rarity)
	local function r()
		return math.random(5, 100)
	end
	return {
		id = id,
		species = species,
		rarity = rarity,
		stats = { power = r(), speed = r(), luck = r() },
		level = 1,
	}
end

local function run()
	Logger.setBatchInterval(0.1)
	local adapter = MockDataStoreAdapter.new({
		[999] = {
			capacity = 100,
			pets = {
				randomPet("a1", "Dog", "Common"),
				randomPet("a2", "Dog", "Common"),
				randomPet("b1", "Cat", "Rare"),
				randomPet("b2", "Cat", "Rare"),
			},
		},
	})

	local inv = adapter:getPlayerInventory(999)
	print("[Simulation] Starting count:", #inv.pets)

	local cases = {
		{ "a1", "a2" }, -- ok
		{ "b1", "b2" }, -- ok
		{ "a1", "a1" }, -- same pet
		{ "a1", "b1" }, -- mismatch
	}

	for _, pair in ipairs(cases) do
		local petIdA, petIdB = pair[1], pair[2]
		local petA, petB
		for _, p in ipairs(inv.pets) do
			if p.id == petIdA then
				petA = p
			elseif p.id == petIdB then
				petB = p
			end
		end
		if petA and petB then
			local outcome = MergeService.canMerge(petA, petB)
			if outcome.ok then
				local merged = MergeService.merge(999, petA, petB)
				if merged.ok then
					print(string.format("[Simulation] Merged %s + %s -> %s (%s)", petIdA, petIdB, merged.pet.id, merged.pet.rarity))
				else
					print("[Simulation] Merge failed:", merged.reason)
				end
			else
				print("[Simulation] Not mergeable:", outcome.reason)
			end
		else
			print("[Simulation] Missing pets for case", petIdA, petIdB)
		end
	end

	print("[Simulation] Done.")
end

return run