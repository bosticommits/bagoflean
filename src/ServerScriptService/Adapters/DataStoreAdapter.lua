--!strict
-- DataStoreAdapter: Interface and default no-op for dependency injection.
-- Replace with your production adapter (e.g., ProfileService or DataStoreService).
local DataStoreAdapter = {}

export type Inventory = {
	capacity: number,
	pets: { any },
}

export type Adapter = {
	getPlayerInventory: (self: Adapter, userId: number) -> Inventory,
	savePlayerInventory: (self: Adapter, userId: number, inv: Inventory, txnId: string) -> boolean,
	lockPetsForTxn: (self: Adapter, userId: number, petIds: { string }, txnId: string) -> boolean,
	unlockPetsForTxn: (self: Adapter, userId: number, petIds: { string }, txnId: string) -> (),
}

function DataStoreAdapter.new(): Adapter
	local self = {} :: any
	function self:getPlayerInventory(userId: number): Inventory
		error("Not implemented DataStoreAdapter:getPlayerInventory for userId " .. tostring(userId))
	end
	function self:savePlayerInventory(userId: number, inv: Inventory, txnId: string): boolean
		error("Not implemented DataStoreAdapter:savePlayerInventory for userId " .. tostring(userId))
	end
	function self:lockPetsForTxn(userId: number, petIds: { string }, txnId: string): boolean
		error("Not implemented DataStoreAdapter:lockPetsForTxn for userId " .. tostring(userId))
	end
	function self:unlockPetsForTxn(userId: number, petIds: { string }, txnId: string)
		error("Not implemented DataStoreAdapter:unlockPetsForTxn for userId " .. tostring(userId))
	end
	return self
end

return DataStoreAdapter