--!strict
-- Builds the 6 placeholder lots, lets players claim one, and runs the cinema collect pad.
-- Lots are plain parts for now; visuals come in M5.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local EconomyService = require(script.Parent.EconomyService)

local LOT_SIZE = 56
local LOT_SPACING = 80
local COLUMNS = 3
local ROW_OFFSET_Z = 70

type Lot = {
	model: Model,
	spawn: BasePart,
	claimPad: BasePart,
	collectPad: BasePart,
	sign: TextLabel,
	owner: Player?,
}

local lots: { Lot } = {}
local lotOf: { [Player]: Lot } = {}

local LotService = {}

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addLabel(part: BasePart, text: string, studsOffset: Vector3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = studsOffset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return label
end

local function setOwner(lot: Lot, owner: Player?)
	lot.owner = owner
	if owner ~= nil then
		lot.model:SetAttribute("OwnerUserId", owner.UserId)
		lot.sign.Text = owner.DisplayName .. "'s Studio"
		lot.claimPad.Color = Color3.fromRGB(120, 120, 120)
		lot.claimPad:FindFirstChildOfClass("BillboardGui").TextLabel.Text = "Claimed"
	else
		lot.model:SetAttribute("OwnerUserId", nil)
		lot.sign.Text = "Unclaimed Lot"
		lot.claimPad.Color = Color3.fromRGB(60, 200, 90)
		lot.claimPad:FindFirstChildOfClass("BillboardGui").TextLabel.Text = "Claim this lot"
	end
end

local function buildLot(index: number, folder: Folder): Lot
	local col = (index - 1) % COLUMNS
	local row = (index - 1) // COLUMNS
	local x = (col - 1) * LOT_SPACING
	local z = if row == 0 then -ROW_OFFSET_Z else ROW_OFFSET_Z
	local center = Vector3.new(x, 0, z)
	-- Face the lot toward the middle of the map.
	local facing = if row == 0 then 1 else -1

	local model = Instance.new("Model")
	model.Name = "Lot" .. index
	model:SetAttribute("LotIndex", index)
	model.Parent = folder

	makePart(model, "Floor", Vector3.new(LOT_SIZE, 1, LOT_SIZE), center + Vector3.new(0, 0.5, 0), Color3.fromRGB(90, 90, 100))
	local cinema = makePart(model, "Cinema", Vector3.new(24, 14, 14), center + Vector3.new(0, 8, -facing * 18), Color3.fromRGB(180, 60, 60))
	local sign = addLabel(cinema, "Unclaimed Lot", Vector3.new(0, 11, 0))

	local claimPad = makePart(model, "ClaimPad", Vector3.new(10, 0.4, 10), center + Vector3.new(0, 1.2, facing * 16), Color3.fromRGB(60, 200, 90))
	local claimGui = Instance.new("BillboardGui")
	claimGui.Size = UDim2.fromOffset(200, 40)
	claimGui.StudsOffset = Vector3.new(0, 4, 0)
	claimGui.AlwaysOnTop = true
	claimGui.MaxDistance = 70
	claimGui.Parent = claimPad
	local claimLabel = Instance.new("TextLabel")
	claimLabel.Name = "TextLabel"
	claimLabel.Size = UDim2.fromScale(1, 1)
	claimLabel.BackgroundTransparency = 0.3
	claimLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	claimLabel.TextColor3 = Color3.new(1, 1, 1)
	claimLabel.TextScaled = true
	claimLabel.Font = Enum.Font.GothamBold
	claimLabel.Parent = claimGui

	local collectPad = makePart(model, "CollectPad", Vector3.new(10, 0.4, 10), center + Vector3.new(0, 1.2, -facing * 4), Color3.fromRGB(240, 200, 40))
	addLabel(collectPad, "Collect Box Office", Vector3.new(0, 4, 0))

	local lot: Lot = {
		model = model,
		spawn = claimPad,
		claimPad = claimPad,
		collectPad = collectPad,
		sign = sign,
		owner = nil,
	}
	setOwner(lot, nil)
	return lot
end

-- Resolve a touching part to a player, ignoring non-character parts.
local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if character == nil then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function claim(player: Player, lot: Lot)
	if lot.owner ~= nil or lotOf[player] ~= nil then
		return
	end
	lotOf[player] = lot
	setOwner(lot, player)
	player:SetAttribute("LotIndex", lot.model:GetAttribute("LotIndex"))
end

function LotService.release(player: Player)
	local lot = lotOf[player]
	if lot == nil then
		return
	end
	lotOf[player] = nil
	setOwner(lot, nil)
end

function LotService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Lots"
	folder.Parent = workspace

	for index = 1, Config.LotCount do
		local lot = buildLot(index, folder)
		lots[index] = lot

		lot.claimPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player ~= nil then
				claim(player, lot)
			end
		end)

		lot.collectPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			-- Only the lot's owner earns from its cinema.
			if player ~= nil and lot.owner == player then
				EconomyService.collect(player)
			end
		end)
	end
end

return LotService
