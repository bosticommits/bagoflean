--!strict
-- Studio mascots (rules in Shared/Mascots). The server sells mascots for Cash, records which ones a
-- player owns and which one they show; CastingService, MovieService and EconomyService read the
-- equipped mascot's buff from the save through Mascots.boost. Every client draws every player's
-- mascot from attributes on the player:
--   "Mascot"          the equipped mascot's id ("" when they hid it)
--   "MascotSince"     when it was equipped (os.time()); its buff works Mascots.WarmUp seconds later
--   "MascotsUnlocked" the ids they own (bought or free), comma separated
-- The save keeps `mascot`, `mascotSince` and `mascotsOwned` (a set of bought ids). Like
-- `soundSettings` they are not in DataService's template, so this feature stays in its own file;
-- a missing choice means the Popcorn Pup and a missing set means only the free mascot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mascots = require(ReplicatedStorage.Shared.Mascots)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes = require(script.Parent.Remotes)

local MIN_GAP = 0.3 -- seconds between equips or purchases per player

local MascotService = {}

local lastEquip: { [Player]: number } = {}

-- Publishes what the player owns and shows. Cheap; Main calls it every second.
function MascotService.refresh(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local owned = table.concat(Mascots.owned(data), ",")
	if player:GetAttribute("MascotsUnlocked") ~= owned then
		player:SetAttribute("MascotsUnlocked", owned)
	end
	local equipped = Mascots.equipped(data)
	if player:GetAttribute("Mascot") ~= equipped then
		player:SetAttribute("Mascot", equipped)
	end
	local saved: any = data -- `mascotSince` lives outside the save template, like `mascot`
	local since = if type(saved.mascotSince) == "number" then saved.mascotSince else 0
	if player:GetAttribute("MascotSince") ~= since then
		player:SetAttribute("MascotSince", since)
	end
end

-- Puts `id` out ("" hides it). Banks the box office at the old rate first (Camera Bot changes the
-- rate), then restarts the warm-up so a swap never carries one mascot's buff over to the next.
local function equip(player: Player, data: any, id: string)
	if data.mascot == id then
		return -- already out; keep its warm-up
	end
	EconomyService.accrue(data)
	data.mascot = id
	data.mascotSince = os.time()
	DataService.markDirty(player)
	MascotService.refresh(player)
end

local function allow(player: Player): boolean
	local now = os.clock()
	if now - (lastEquip[player] or -math.huge) < MIN_GAP then
		return false
	end
	lastEquip[player] = now
	return true
end

function MascotService.start()
	Remotes.get("EquipMascot").OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or #id > 40 or not allow(player) then
			return
		end
		local data: any = DataService.getData(player)
		if data == nil then
			return
		end
		if id ~= "" then
			local mascot = Mascots.get(id)
			if mascot == nil or not Mascots.owns(mascot, data) then
				return
			end
		end
		equip(player, data, id)
	end)

	-- Buying a mascot spends its price once and puts it straight out.
	Remotes.get("BuyMascot").OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or #id > 40 or not allow(player) then
			return
		end
		local data: any = DataService.getData(player)
		local mascot = Mascots.get(id)
		if data == nil or mascot == nil or Mascots.owns(mascot, data) then
			return
		end
		if not EconomyService.spendCash(player, mascot.price, "Mascot:" .. mascot.id) then
			return
		end
		if type(data.mascotsOwned) ~= "table" then
			data.mascotsOwned = {}
		end
		data.mascotsOwned[mascot.id] = true
		equip(player, data, mascot.id)
		MascotService.refresh(player)
	end)
end

function MascotService.forget(player: Player)
	lastEquip[player] = nil
end

return MascotService
