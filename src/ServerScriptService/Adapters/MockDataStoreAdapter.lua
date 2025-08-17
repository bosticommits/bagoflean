--!strict
-- MockDataStoreAdapter: In-memory adapter for tests/simulations.
local MockDataStoreAdapter = {}

export type Inventory = {
	capacity: number,
	pets: { any },
}

type LockEntry = {
	txnId: string,
	lockedAt: number,
}

function MockDataStoreAdapter.new(seedInventories: { [number]: Inventory }?)
	local self = {} :: any
	local inventories = seedInventories and table.clone(seedInventories) or {}
	local petLocks: { [number]: { [string]: LockEntry } } = {}

	local function getLocks(userId: number): { [string]: LockEntry }
		petLocks[userId] = petLocks[userId] or {}
		return petLocks[userId]
	end

	function self:getPlayerInventory(userId: number): Inventory
		if inventories[userId] == nil then
			inventories[userId] = { capacity = 100, pets = {} }
		end
		return inventories[userId]
	end

	function self:savePlayerInventory(userId: number, inv: Inventory, txnId: string): boolean
		inventories[userId] = { capacity = inv.capacity, pets = table.clone(inv.pets) }
		return true
	end

	function self:lockPetsForTxn(userId: number, petIds: { string }, txnId: string): boolean
		local locks = getLocks(userId)
		for _, id in ipairs(petIds) do
			local entry = locks[id]
			if entry ~= nil and entry.txnId ~= txnId then
				return false
			end
		end
		for _, id in ipairs(petIds) do
			locks[id] = { txnId = txnId, lockedAt = os.time() }
		end
		return true
	end

	function self:unlockPetsForTxn(userId: number, petIds: { string }, txnId: string)
		local locks = getLocks(userId)
		for _, id in ipairs(petIds) do
			local entry = locks[id]
			if entry and entry.txnId == txnId then
				locks[id] = nil
			end
		end
	end

	return self
end

return MockDataStoreAdapter