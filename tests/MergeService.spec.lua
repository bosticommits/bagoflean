--!strict
-- Basic tests for MergeService (run with TestEZ or your runner).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetsConfig"))
local MergeService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MergeService"))

local function pet(id: string, species: string, rarity: PetsConfig.Rarity, power: number, speed: number, luck: number)
	return {
		id = id,
		species = species,
		rarity = rarity,
		stats = { power = power, speed = speed, luck = luck },
		level = 1,
	}
end

local function expect(cond: boolean, msg: string)
	if not cond then
	  error("Test failed: " .. msg)
	end
end

local function run()
	-- cannot merge same id
	do
		local a = pet("1", "Dog", "Common", 10, 10, 10)
		local b = pet("1", "Dog", "Common", 20, 20, 20)
		local res = MergeService.canMerge(a, b)
		expect(res.ok == false, "should not allow same pet merge")
	end

	-- species mismatch
	do
		local a = pet("1", "Dog", "Common", 10, 10, 10)
		local b = pet("2", "Cat", "Common", 20, 20, 20)
		local res = MergeService.canMerge(a, b)
		expect(res.ok == false, "should not allow different species")
	end

	-- rarity mismatch
	do
		local a = pet("1", "Dog", "Common", 10, 10, 10)
		local b = pet("2", "Dog", "Uncommon", 20, 20, 20)
		local res = MergeService.canMerge(a, b)
		expect(res.ok == false, "should not allow different rarity")
	end

	-- top rarity blocked
	do
		local a = pet("1", "Dog", "Legendary", 10, 10, 10)
		local b = pet("2", "Dog", "Legendary", 20, 20, 20)
		local res = MergeService.canMerge(a, b)
		expect(res.ok == false, "should not allow Legendary merge")
	end

	-- happy path merge
	do
		local a = pet("1", "Dog", "Common", 10, 30, 50)
		local b = pet("2", "Dog", "Common", 30, 10, 70)
		local out = MergeService.merge(123, a, b)
		expect(out.ok == true, "merge should succeed")
		if out.ok then
			expect(out.pet.rarity == "Uncommon", "rarity should upgrade to Uncommon")
			expect(math.abs(out.pet.stats.power - 20) < 1e-6, "power avg mismatch")
			expect(math.abs(out.pet.stats.speed - 20) < 1e-6, "speed avg mismatch")
			expect(math.abs(out.pet.stats.luck - 60) < 1e-6, "luck avg mismatch")
			expect(out.pet.id ~= a.id and out.pet.id ~= b.id, "new pet id must differ from parents")
		end
	end

	print("[MergeService.spec] All tests passed.")
end

return run