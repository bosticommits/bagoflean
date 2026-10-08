--!strict
-- Studio mascots (rules in Shared/Mascots). Cosmetic: the server only decides which mascots a
-- player has earned and which one they show. Every client draws every player's mascot from two
-- attributes on the player:
--   "Mascot"          the equipped mascot's id ("" when they hid it)
--   "MascotsUnlocked" the ids they have earned, comma separated
--   "MascotProgress"  how far they are towards each mascot, in list order, comma separated
-- The choice is saved as `mascot` in the profile. Like `soundSettings` it is not in DataService's
-- template, so this feature stays in its own file; a missing choice means the Popcorn Pup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mascots = require(ReplicatedStorage.Shared.Mascots)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local MIN_GAP = 0.3 -- seconds between equips per player

local MascotService = {}

local lastEquip: { [Player]: number } = {}

-- Publishes what the player has earned and shows. Cheap; Main calls it every second, so a mascot
-- unlocks the moment its milestone is reached.
function MascotService.refresh(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local unlocked = table.concat(Mascots.unlocked(data), ",")
	if player:GetAttribute("MascotsUnlocked") ~= unlocked then
		player:SetAttribute("MascotsUnlocked", unlocked)
	end
	local progress = {}
	for _, mascot in Mascots.List do
		table.insert(progress, tostring(math.floor(math.min(Mascots.progress(mascot, data), 1e9))))
	end
	local progressText = table.concat(progress, ",")
	if player:GetAttribute("MascotProgress") ~= progressText then
		player:SetAttribute("MascotProgress", progressText)
	end
	local equipped = Mascots.equipped(data)
	if player:GetAttribute("Mascot") ~= equipped then
		player:SetAttribute("Mascot", equipped)
	end
end

function MascotService.start()
	Remotes.get("EquipMascot").OnServerEvent:Connect(function(player: Player, id: any)
		if type(id) ~= "string" or #id > 40 then
			return
		end
		local now = os.clock()
		if now - (lastEquip[player] or -math.huge) < MIN_GAP then
			return
		end
		lastEquip[player] = now
		local data: any = DataService.getData(player)
		if data == nil then
			return
		end
		if id ~= "" then
			local mascot = Mascots.get(id)
			if mascot == nil or not Mascots.isUnlocked(mascot, data) then
				return
			end
		end
		data.mascot = id
		MascotService.refresh(player)
	end)
end

function MascotService.forget(player: Player)
	lastEquip[player] = nil
end

return MascotService
