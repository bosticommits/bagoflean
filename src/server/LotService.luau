--!strict
-- Builds the 6 studio lots, lets players claim one, runs the cinema collect pad, and keeps each
-- lot's show-off parts in sync with its owner: marquee name, sound stages (one per owned stage),
-- trophies (Masterpieces), and a billboard of the owner's rarest actor that the whole server sees.
-- Still simple parts (no meshes or uploaded art), but laid out as a real studio lot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local Config = require(ReplicatedStorage.Shared.Config)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)

local LOT_SIZE = 56
local LOT_SPACING = 80
local COLUMNS = 3
local ROW_OFFSET_Z = 70
local MAX_TROPHIES_SHOWN = 5

-- One accent color per lot so neighbors are easy to tell apart.
local LOT_COLORS = {
	Color3.fromRGB(200, 70, 70),
	Color3.fromRGB(70, 130, 210),
	Color3.fromRGB(90, 170, 90),
	Color3.fromRGB(200, 140, 50),
	Color3.fromRGB(150, 90, 200),
	Color3.fromRGB(50, 170, 170),
}

local GOLD = Color3.fromRGB(255, 205, 70)

type Lot = {
	index: number,
	model: Model,
	dynamic: Model, -- rebuilt on every refresh
	claimPad: BasePart,
	collectPad: BasePart,
	marquee: TextLabel,
	billboard: Frame,
	at: (dx: number, dy: number, dz: number) -> Vector3, -- lot-local position; +dz faces the street
	front: Enum.NormalId, -- the face of an unrotated part that points at the street
	color: Color3,
	owner: Player?,
}

local lots: { Lot } = {}
local lotOf: { [Player]: Lot } = {}

local celebrate = Remotes.get("Celebrate")

local LotService = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, background: Color3): (SurfaceGui, TextLabel)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
	return gui, label
end

local function floatingLabel(target: BasePart, text: string, offset: Vector3, maxDistance: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = offset
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "TextLabel"
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

-- The owner's best actor copy: highest tier, then best variant.
local function rarestOwned(data: DataService.PlayerData): (Actors.Actor?, Actors.Variant?)
	local bestScore, bestActor, bestVariant = -1, nil, nil
	local tierRank: { [string]: number } = {}
	for rank, tier in Actors.Tiers do
		tierRank[tier.id] = rank
	end
	local variantRank: { [string]: number } = {}
	for rank, variant in Actors.Variants do
		variantRank[variant.id] = rank
	end
	for key, count in data.roster do
		if count > 0 then
			local parts = string.split(key, ":")
			local actor = Actors.getActor(parts[1] or "")
			local variant = Actors.getVariant(parts[2] or "")
			if actor ~= nil and variant ~= nil then
				local score = tierRank[actor.tier] * 10 + variantRank[variant.id]
				if score > bestScore then
					bestScore, bestActor, bestVariant = score, actor, variant
				end
			end
		end
	end
	return bestActor, bestVariant
end

local function buildLot(index: number, folder: Folder): Lot
	local col = (index - 1) % COLUMNS
	local row = (index - 1) // COLUMNS
	local center = Vector3.new((col - 1) * LOT_SPACING, 0, if row == 0 then -ROW_OFFSET_Z else ROW_OFFSET_Z)
	-- Lots face the middle of the map. +dz in lot space always points at the street.
	local facing = if row == 0 then 1 else -1
	local function at(dx: number, dy: number, dz: number): Vector3
		return center + Vector3.new(dx * facing, dy, dz * facing)
	end
	-- An unrotated part's Front face points along -Z, so the street-facing face depends on the row.
	local front = if facing == 1 then Enum.NormalId.Back else Enum.NormalId.Front
	local color = LOT_COLORS[index] or LOT_COLORS[1]

	local model = Instance.new("Model")
	model.Name = "Lot" .. index
	model:SetAttribute("LotIndex", index)
	model.Parent = folder

	-- Ground: lot, sidewalk at the street edge.
	part(model, "Floor", Vector3.new(LOT_SIZE, 1, LOT_SIZE), at(0, 0.5, 0), Color3.fromRGB(70, 72, 82), Enum.Material.Concrete)
	part(model, "Sidewalk", Vector3.new(LOT_SIZE, 0.2, 5), at(0, 1.1, 25.5), Color3.fromRGB(165, 165, 170), Enum.Material.Concrete)

	-- Cinema building with a marquee and door.
	local cinema = part(model, "Cinema", Vector3.new(28, 16, 14), at(0, 9, -19), color:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.Brick)
	part(model, "Roofline", Vector3.new(29, 1, 15), at(0, 17.5, -19), color, Enum.Material.SmoothPlastic)
	part(model, "Door", Vector3.new(6, 7, 0.4), at(0, 4.5, -11.9), Color3.fromRGB(25, 20, 20))
	part(model, "Awning", Vector3.new(30, 1, 4), at(0, 9.5, -10), Color3.fromRGB(35, 30, 35))
	part(model, "MarqueeLights", Vector3.new(30.4, 0.4, 4.4), at(0, 8.9, -10), GOLD, Enum.Material.Neon)
	local sign = part(model, "MarqueeSign", Vector3.new(22, 4, 0.6), at(0, 12.5, -11.8), Color3.fromRGB(20, 20, 25))
	local _, marquee = surfaceText(sign, front, Color3.fromRGB(20, 20, 25))
	marquee.TextColor3 = GOLD

	-- Red carpet from the street to the door, with gold posts.
	part(model, "RedCarpet", Vector3.new(6, 0.15, 21), at(0, 1.08, -1), Color3.fromRGB(170, 20, 30), Enum.Material.Fabric)
	for i = 0, 3 do
		for _, side in { -3.6, 3.6 } do
			part(model, "CarpetPost", Vector3.new(2.4, 0.4, 0.4), at(side, 2.2, -8 + i * 5), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder).Orientation = Vector3.new(0, 0, 90)
		end
	end

	-- Pads (gameplay). Claim at the street, collect beside the cinema.
	local claimPad = part(model, "ClaimPad", Vector3.new(10, 0.4, 8), at(0, 1.2, 17), Color3.fromRGB(60, 200, 90), Enum.Material.Neon)
	floatingLabel(claimPad, "Claim this lot", Vector3.new(0, 4, 0), 70)
	local collectPad = part(model, "CollectPad", Vector3.new(8, 0.4, 8), at(-10, 1.2, -5), GOLD, Enum.Material.Neon)
	floatingLabel(collectPad, "Collect Box Office", Vector3.new(0, 4, 0), 90)
	part(model, "BoxOfficeBooth", Vector3.new(4, 6, 3), at(-10, 4, -10.5), Color3.fromRGB(230, 225, 210))

	-- Billboard frame (content is filled in by refresh).
	for _, dx in { 16.5, 25.5 } do
		part(model, "BillboardPost", Vector3.new(0.8, 14, 0.8), at(dx, 8, -22), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
	end
	local board = part(model, "Billboard", Vector3.new(11, 7, 0.6), at(21, 17, -22), Color3.fromRGB(20, 20, 25))
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 40
	boardGui.LightInfluence = 0
	boardGui.Parent = board
	local billboard = Instance.new("Frame")
	billboard.Size = UDim2.fromScale(1, 1)
	billboard.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	billboard.Parent = boardGui

	-- Lamp posts at the street corners.
	for _, dx in { -25, 25 } do
		part(model, "LampPole", Vector3.new(0.6, 10, 0.6), at(dx, 6, 23), Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
		local head = part(model, "LampHead", Vector3.new(1.6, 1.6, 1.6), at(dx, 11.6, 23), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 230, 180)
		light.Parent = head
	end

	local dynamic = Instance.new("Model")
	dynamic.Name = "Dynamic"
	dynamic.Parent = model

	local lot: Lot = {
		index = index,
		model = model,
		dynamic = dynamic,
		claimPad = claimPad,
		collectPad = collectPad,
		marquee = marquee,
		billboard = billboard,
		at = at,
		front = front,
		color = color,
		owner = nil,
	}
	-- Keep a reference for celebrations on clients.
	cinema:SetAttribute("LotIndex", index)
	return lot
end

local function setBillboard(lot: Lot, title: string, line1: string, line2: string, color: Color3)
	for _, child in lot.billboard:GetChildren() do
		child:Destroy()
	end
	lot.billboard.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	local function text(y: number, h: number, value: string, textColor: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.9, h)
		label.Text = value
		label.TextColor3 = textColor
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = lot.billboard
	end
	text(0.06, 0.2, title, GOLD)
	text(0.3, 0.38, line1, Color3.new(1, 1, 1))
	text(0.72, 0.22, line2, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = color
	stroke.Parent = lot.billboard
end

-- Rebuild everything on the lot that depends on its owner.
local function render(lot: Lot)
	lot.dynamic:ClearAllChildren()
	local owner = lot.owner
	local data = if owner ~= nil then DataService.getData(owner) else nil

	-- Claim pad and marquee.
	local claimLabel = (lot.claimPad:FindFirstChildOfClass("BillboardGui") :: BillboardGui):FindFirstChild("TextLabel") :: TextLabel
	if owner ~= nil then
		lot.model:SetAttribute("OwnerUserId", owner.UserId)
		local vip = data ~= nil and data.passes.VIP == true
		lot.marquee.Text = (if vip then "★ " else "") .. string.upper(owner.DisplayName) .. " PICTURES" .. (if vip then " ★" else "")
		lot.claimPad.Color = Color3.fromRGB(110, 110, 115)
		lot.claimPad.Material = Enum.Material.SmoothPlastic
		claimLabel.Text = owner.DisplayName .. "'s Studio"
	else
		lot.model:SetAttribute("OwnerUserId", nil)
		lot.marquee.Text = "STUDIO FOR LEASE"
		lot.claimPad.Color = Color3.fromRGB(60, 200, 90)
		lot.claimPad.Material = Enum.Material.Neon
		claimLabel.Text = "Claim this lot"
	end

	-- Sound stages: one hangar per stage the owner has (an empty lot shows one, dimmed).
	-- The fifth slot is for the +1 Sound Stage pass (Config.StageLimit).
	local stageSlots = { { 20, -3 }, { 20, 10 }, { -20, 10 }, { -20, -2 }, { -20, -14 } }
	local stages = if data ~= nil then Upgrades.stages(data) else 1
	for i = 1, math.min(stages, #stageSlots) do
		local slot = stageSlots[i]
		local hangar = part(lot.dynamic, "SoundStage", Vector3.new(11, 9, 11), lot.at(slot[1], 5.5, slot[2]), if owner ~= nil then Color3.fromRGB(205, 200, 185) else Color3.fromRGB(120, 120, 125), Enum.Material.Concrete)
		part(lot.dynamic, "StageRoof", Vector3.new(11.6, 1, 11.6), lot.at(slot[1], 10.5, slot[2]), lot.color, Enum.Material.Metal)
		local _, number = surfaceText(hangar, lot.front, Color3.fromRGB(40, 40, 45))
		number.Text = "STAGE " .. i
		number.TextColor3 = Color3.new(1, 1, 1)
	end

	-- Trophy shelf: one gold statuette per Masterpiece (up to MAX_TROPHIES_SHOWN, then a count).
	local trophies = if data ~= nil then data.trophies else 0
	if trophies > 0 then
		local shelf = part(lot.dynamic, "TrophyShelf", Vector3.new(8, 1.4, 2.4), lot.at(9.5, 1.7, -10), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
		for i = 1, math.min(trophies, MAX_TROPHIES_SHOWN) do
			local x = 9.5 - 3 + (i - 1) * 1.5
			part(lot.dynamic, "TrophyBase", Vector3.new(0.9, 0.5, 0.9), lot.at(x, 2.65, -10), Color3.fromRGB(30, 30, 30))
			part(lot.dynamic, "Trophy", Vector3.new(0.6, 1.8, 0.6), lot.at(x, 3.8, -10), GOLD, Enum.Material.Metal)
			part(lot.dynamic, "TrophyStar", Vector3.new(0.9, 0.9, 0.9), lot.at(x, 5, -10), GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		end
		floatingLabel(shelf, `{trophies} Masterpiece{if trophies == 1 then "" else "s"}`, Vector3.new(0, 5, 0), 60)
	end

	-- Billboard: the owner's rarest actor, visible to everyone on the server.
	local actor, variant = nil, nil
	if data ~= nil then
		actor, variant = rarestOwned(data)
	end
	if owner == nil then
		setBillboard(lot, "YOUR STAR HERE", "Claim this lot", "and cast actors", Color3.fromRGB(120, 120, 130))
	elseif actor == nil or variant == nil then
		setBillboard(lot, owner.DisplayName, "No stars yet", "Casting Call!", Color3.fromRGB(120, 120, 130))
	else
		local tier = Actors.getTier(actor.tier)
		local tierColor = if tier ~= nil then tier.color else Color3.new(1, 1, 1)
		local variantText = if variant.id == "Normal" then "" else variant.name .. " "
		setBillboard(lot, owner.DisplayName .. "'s top star", actor.name, `{variantText}{actor.tier}`, tierColor)
	end
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
	lot.owner = player
	player:SetAttribute("LotIndex", lot.index)
	render(lot)
	Analytics.onboarding(player, Analytics.Steps.ClaimedLot)
end

-- Re-render the player's lot after anything it shows changed (cast, premiere, stage upgrade).
function LotService.refresh(player: Player)
	local lot = lotOf[player]
	if lot ~= nil then
		render(lot)
	end
end

-- Tell every client to play a celebration on this player's lot ("masterpiece" or "pull").
function LotService.celebrate(player: Player, kind: string)
	local lot = lotOf[player]
	if lot ~= nil then
		celebrate:FireAllClients(lot.index, kind)
	end
end

function LotService.release(player: Player)
	local lot = lotOf[player]
	if lot == nil then
		return
	end
	lotOf[player] = nil
	lot.owner = nil
	render(lot)
end

function LotService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Lots"
	folder.Parent = workspace

	for index = 1, Config.LotCount do
		local lot = buildLot(index, folder)
		lots[index] = lot
		render(lot)

		lot.claimPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if player ~= nil then
				claim(player, lot)
			end
		end)

		lot.collectPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			-- Only the lot's owner earns from its cinema.
			if player ~= nil and lot.owner == player and EconomyService.collect(player) > 0 then
				QuestTracker.track(player, "collect")
			end
		end)
	end
end

return LotService
