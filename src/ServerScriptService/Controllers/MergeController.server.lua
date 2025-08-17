--!strict
-- MergeController: Server-authoritative merge handling, ownership & capacity validation.
-- Server trusts nothing from the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Logger = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Logger"))
local PetsConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetsConfig"))
local MergeService = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MergeService"))

-- Adapter injection: replace Mock with your production adapter in init/bootstrap.
local MockDataStoreAdapter = require(game:GetService("ServerScriptService"):WaitForChild("Adapters"):WaitForChild("MockDataStoreAdapter"))
local dataStoreAdapter = MockDataStoreAdapter.new()

-- Remote endpoint
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
RemotesFolder.Name = "Remotes"
RemotesFolder.Parent = ReplicatedStorage

local MergeRequest = Instance.new("RemoteFunction")
MergeRequest.Name = "MergeRequest"
MergeRequest.Parent = RemotesFolder

type Inventory = { capacity: number, pets: { PetsConfig.Pet } }

local function findPet(inv: Inventory, petId: string): number?
	for i, p in ipairs(inv.pets) do
		if p.id == petId then
			return i
		end
	end
	return nil
end

local function generateTxnId(userId: number, a: string, b: string): string
	local ids = { a, b }
	table.sort(ids)
	return string.format("merge:%d:%s:%s:%s", userId, ids[1], ids[2], string.sub(HttpService:GenerateGUID(false), 1, 8))
end

-- Server-side handler. Trust nothing from client.
MergeRequest.OnServerInvoke = function(player: Player, petIdA: string, petIdB: string)
	local userId = player.UserId
	local txnId = generateTxnId(userId, petIdA, petIdB)

	local ok, result = pcall(function()
		local inv: Inventory = dataStoreAdapter:getPlayerInventory(userId)

		-- Ownership and capacity checks
		if #inv.pets < 2 then
			return { ok = false, reason = "Not enough pets to merge." }
		end
		local idxA = findPet(inv, petIdA)
		local idxB = findPet(inv, petIdB)
		if not idxA or not idxB then
			return { ok = false, reason = "You do not own both pets." }
		end
		if idxA == idxB then
			return { ok = false, reason = "Cannot merge the same pet." }
		end
		local petA = inv.pets[idxA]
		local petB = inv.pets[idxB]

		-- Duplicate protection: lock both pets for this txn
		local locked = dataStoreAdapter:lockPetsForTxn(userId, { petA.id, petB.id }, txnId)
		if not locked then
			return { ok = false, reason = "Another merge is in progress for these pets. Please try again." }
		end

		-- Validate merge rules
		local can = MergeService.canMerge(petA, petB)
		if not can.ok then
			dataStoreAdapter:unlockPetsForTxn(userId, { petA.id, petB.id }, txnId)
			return { ok = false, reason = can.reason or "Cannot merge these pets." }
		end

		-- Capacity: merging 2 -> 1 reduces count; still assert capacity non-negative
		if #inv.pets > inv.capacity then
			dataStoreAdapter:unlockPetsForTxn(userId, { petA.id, petB.id }, txnId)
			return { ok = false, reason = "Inventory over capacity. Free space before merging." }
		end

		-- Perform merge
		local outcome = MergeService.merge(userId, petA, petB)
		if not outcome.ok then
			dataStoreAdapter:unlockPetsForTxn(userId, { petA.id, petB.id }, txnId)
			return { ok = false, reason = outcome.reason }
		end

		-- Apply changes: remove parents, add child
		local newPet = outcome.pet

		-- Remove higher index first to keep indices valid
		local i1, i2 = idxA, idxB
		if i1 < i2 then
			table.remove(inv.pets, i2)
			table.remove(inv.pets, i1)
		else
			table.remove(inv.pets, i1)
			table.remove(inv.pets, i2)
		end
		table.insert(inv.pets, newPet)

		-- Persist
		local saved = dataStoreAdapter:savePlayerInventory(userId, inv, txnId)
		-- Unlock regardless
		dataStoreAdapter:unlockPetsForTxn(userId, { petA.id, petB.id }, txnId)

		if not saved then
			return { ok = false, reason = "Failed to save inventory. Please try again." }
		end

		Logger.info("merge.success", nil, {
			userId = userId,
			txnId = txnId,
			parentA = petA.id,
			parentB = petB.id,
			resultPetId = newPet.id,
			resultRarity = newPet.rarity,
			inventoryCount = #inv.pets,
		})

		return {
			ok = true,
			pet = newPet,
			message = string.format("Merged into %s %s!", newPet.rarity, newPet.species),
		}
	end)

	if not ok then
		Logger.error("merge.exception", tostring(result), { userId = player.UserId, petA = petIdA, petB = petIdB })
		return { ok = false, reason = "Unexpected error. Please try again." }
	end

	return result
end

Players.PlayerRemoving:Connect(function(player: Player)
	Logger.debug("player.removed", nil, { userId = player.UserId })
end)