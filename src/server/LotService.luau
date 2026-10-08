--!strict
-- Builds the 6 studio lots, lets players claim one, runs the cinema collect pad, and keeps each
-- lot's show-off pieces in sync with its owner: sound stages (one per owned stage, lit ON AIR while
-- filming), a cinema that grows with Cinema Size, an office that grows with Offline Earnings,
-- trophies (Masterpieces), the owner's top star on a pedestal, and a billboard of that star that
-- the whole server sees. The models live in ReplicatedStorage.Shared.Models (built from parts,
-- swapped for Blender meshes once those are imported; see art/README.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Actors = require(ReplicatedStorage.Shared.Actors)
local ActorModels = require(ReplicatedStorage.Shared.Models.ActorModels)
local Config = require(ReplicatedStorage.Shared.Config)
local LotLook = require(ReplicatedStorage.Shared.Models.LotLook)
local LotModels = require(ReplicatedStorage.Shared.Models.LotModels)
local MapModels = require(ReplicatedStorage.Shared.Models.MapModels)
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)
local TopStudios = require(ReplicatedStorage.Shared.TopStudios)
local TopStudiosModels = require(ReplicatedStorage.Shared.Models.TopStudiosModels)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Visits = require(ReplicatedStorage.Shared.Visits)
local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local QuestTracker = require(script.Parent.QuestTracker)
local Remotes = require(script.Parent.Remotes)
local StudioAvatar = require(script.Parent.StudioAvatar)
local WorldLabel = require(ReplicatedStorage.Shared.WorldLabel)

-- One accent color per lot (sound stage roofs, cinema canopy) so neighbors are easy to tell apart.
local LOT_COLORS = {
	Color3.fromRGB(200, 32, 47),
	Color3.fromRGB(46, 134, 222),
	Color3.fromRGB(70, 175, 80),
	Color3.fromRGB(235, 140, 40),
	Color3.fromRGB(150, 80, 210),
	Color3.fromRGB(30, 170, 170),
}

local GOLD = Color3.fromRGB(245, 184, 46)

-- The pieces that change with the owner. Each is rebuilt only when its key changes, so a casting
-- spree doesn't rebuild the whole lot.
local SECTIONS = { "Stages", "CinemaBuilding", "Office", "Trophies", "Star", "Avatar", "RareWall" }

type Lot = {
	index: number,
	model: Model,
	base: CFrame, -- lot space: origin at the ground centre, -Z toward the boulevard
	claimPad: BasePart,
	collectPad: BasePart,
	billboard: Frame,
	applause: TextLabel, -- the studio's applause count over its gate
	marquee: TextLabel?,
	color: Color3,
	owner: Player?,
	keys: { [string]: string }, -- section name -> what it was last built for
}

local lots: { Lot } = {}
local lotOf: { [Player]: Lot } = {}

local celebrate = Remotes.get("Celebrate")

local LotService = {}

-- Outlined text floating over a pad (no dark box behind it), sized in studs.
local function floatingLabel(target: BasePart, text: string, color: Color3?, height: number?): TextLabel
	return WorldLabel.new(target, text, 14, 2.6, {
		color = color,
		offset = Vector3.new(0, height or 4, 0),
		maxDistance = 70,
	})
end

-- The owner's best actor copy: highest tier, then best variant.
local function rarestOwned(data: DataService.PlayerData): (Actors.Actor?, Actors.Variant?)
	local best = TopStudios.rarest(data.roster, 1)[1]
	if best == nil then
		return nil, nil
	end
	return best.actor, best.variant
end

local function buildLot(index: number, folder: Folder): Lot
	-- Lots face the boulevard in the middle of the map (MapModels builds the town around them).
	local base = MapModels.lotBase(index)
	local color = LOT_COLORS[index] or LOT_COLORS[1]

	local model = Instance.new("Model")
	model.Name = "Lot" .. index
	model:SetAttribute("LotIndex", index)
	model.Parent = folder

	local static = LotLook.static(model, base, index, color)
	floatingLabel(static.claimPad, "Claim this lot", Color3.fromRGB(120, 255, 140))
	floatingLabel(static.collectPad, "Collect Box Office", GOLD)
	static.cinemaAnchor:SetAttribute("LotIndex", index)

	-- Billboard content (filled in by refresh).
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 40
	boardGui.LightInfluence = 0
	boardGui.Parent = static.billboard
	local billboard = Instance.new("Frame")
	billboard.Size = UDim2.fromScale(1, 1)
	billboard.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	billboard.Parent = boardGui

	for _, name in SECTIONS do
		local section = Instance.new("Model")
		section.Name = name
		section.Parent = model
	end

	-- Applause count between the gate posts, readable from the boulevard (studio visits).
	local sign = Instance.new("Part")
	sign.Name = "ApplauseSign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanQuery = false
	sign.CanTouch = false
	sign.Transparency = 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.CFrame = base * CFrame.new(0, 9.6, LotModels.Layout.gateZ)
	sign.Parent = model
	local applause = WorldLabel.new(sign, "", 11, 2.6, { color = GOLD, offset = Vector3.zero, maxDistance = 110 })
	local applauseGui = applause.Parent :: BillboardGui
	applauseGui.Enabled = false

	return {
		index = index,
		model = model,
		base = base,
		claimPad = static.claimPad,
		collectPad = static.collectPad,
		billboard = billboard,
		applause = applause,
		marquee = nil,
		color = color,
		owner = nil,
		keys = {},
	}
end

-- Billboard: title, the star's portrait, their name and rarity. `actorId` nil shows text only.
local function setBillboard(lot: Lot, title: string, line1: string, line2: string, color: Color3, actorId: string?, variantId: string?)
	for _, child in lot.billboard:GetChildren() do
		child:Destroy()
	end
	lot.billboard.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	local textLeft = if actorId ~= nil then 0.4 else 0.05
	local function text(y: number, h: number, value: string, textColor: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(textLeft, y)
		label.Size = UDim2.fromScale(0.95 - textLeft, h)
		label.Text = value
		label.TextColor3 = textColor
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Parent = lot.billboard
	end
	text(0.06, 0.2, title, GOLD)
	text(0.3, 0.38, line1, Color3.new(1, 1, 1))
	text(0.72, 0.22, line2, color)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 10
	stroke.Color = color
	stroke.Parent = lot.billboard
	if actorId ~= nil then
		-- Portrait: the actor's figure rendered live in a ViewportFrame.
		local viewport = Instance.new("ViewportFrame")
		viewport.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.2)
		viewport.Position = UDim2.fromScale(0.03, 0.06)
		viewport.Size = UDim2.fromScale(0.34, 0.88)
		viewport.Ambient = Color3.fromRGB(190, 190, 190)
		viewport.LightColor = Color3.new(1, 1, 1)
		viewport.LightDirection = Vector3.new(-1, -1, 1)
		viewport.Parent = lot.billboard
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.08, 0)
		corner.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(-3, 3.6, -13), Vector3.new(0, 2.8, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		ActorModels.build(viewport, CFrame.identity, actorId, variantId)
	end
end

-- Rebuild a section if what it shows changed. `build` fills the (emptied) section model.
local function section(lot: Lot, name: string, key: string, build: (Model) -> ())
	if lot.keys[name] == key then
		return
	end
	lot.keys[name] = key
	local model = lot.model:FindFirstChild(name) :: Model
	model:ClearAllChildren()
	build(model)
end

-- Bring everything on the lot that depends on its owner up to date.
local function render(lot: Lot)
	local owner = lot.owner
	local data = if owner ~= nil then DataService.getData(owner) else nil

	-- Claim pad: its label only while the lot is free (the owner's name is over their avatar).
	local claimGui = lot.claimPad:FindFirstChildOfClass("BillboardGui") :: BillboardGui
	claimGui.Enabled = owner == nil
	if owner ~= nil then
		lot.model:SetAttribute("OwnerUserId", owner.UserId)
		lot.claimPad.Color = Color3.fromRGB(110, 110, 115)
		lot.claimPad.Material = Enum.Material.SmoothPlastic
	else
		lot.model:SetAttribute("OwnerUserId", nil)
		lot.claimPad.Color = Color3.fromRGB(60, 200, 90)
		lot.claimPad.Material = Enum.Material.Neon
	end

	-- The owner's giant avatar and name over the back of the lot.
	local avatarKey = if owner ~= nil then tostring(owner.UserId) else "free"
	section(lot, "Avatar", avatarKey, function(model)
		if owner ~= nil then
			task.spawn(StudioAvatar.build, model, lot.base, owner, function()
				return lot.owner == owner and lot.keys.Avatar == avatarKey
			end)
		end
	end)

	-- Sound stages: one per stage the owner has (an empty lot shows one, grey). ON AIR while filming.
	local progress: LotLook.Progress? = nil
	if data ~= nil then
		local filming: { [number]: boolean } = {}
		local lastFilming = 0
		for _, film in data.films do
			filming[film.stage] = true
			lastFilming = math.max(lastFilming, film.stage)
		end
		progress = {
			-- Includes the +1 Sound Stage pass, and a stage a rebirth closed while a film was on it.
			stages = math.max(Upgrades.stages(data), lastFilming),
			cinema = data.upgrades.Cinema or 0,
			office = data.upgrades.Offline or 0,
			trophies = data.trophies,
			filming = filming,
		}
	end
	local stagesKey = "free"
	if progress ~= nil then
		stagesKey = tostring(progress.stages)
		for i = 1, progress.stages do
			stagesKey ..= if progress.filming[i] then "F" else "-"
		end
	end
	section(lot, "Stages", stagesKey, function(model)
		LotLook.stages(model, lot.base, progress, lot.color)
	end)

	local cinemaLevel = if progress ~= nil then progress.cinema else 0
	section(lot, "CinemaBuilding", tostring(LotLook.cinemaTier(cinemaLevel)), function(model)
		lot.marquee = LotLook.cinema(model, lot.base, cinemaLevel, lot.color)
	end)
	local marquee = lot.marquee
	if marquee ~= nil then
		local vip = data ~= nil and data.passes.VIP == true
		-- After a rebirth the studio's name gets its sequel number: "BOSTI PICTURES 2".
		local sequel = Rebirth.sequelSuffix(if data ~= nil then data.rebirths else 0)
		marquee.Text = if owner ~= nil
			then (if vip then "★ " else "") .. string.upper(owner.DisplayName) .. " PICTURES" .. sequel .. (if vip then " ★" else "")
			else "STUDIO FOR LEASE"
	end

	-- Studio visits: the applause count over the gate (from the first applause on), and what the
	-- Visit menu lists about this studio.
	local likes = if data ~= nil then data.likes else 0
	local applauseGui = lot.applause.Parent :: BillboardGui
	applauseGui.Enabled = owner ~= nil and likes > 0
	lot.applause.Text = Visits.applauseText(likes)
	lot.model:SetAttribute("Likes", if owner ~= nil then likes else nil)
	lot.model:SetAttribute("Trophies", if data ~= nil then data.trophies else nil)
	lot.model:SetAttribute(
		"StudioName",
		if owner ~= nil then string.upper(owner.DisplayName) .. " PICTURES" .. Rebirth.sequelSuffix(if data ~= nil then data.rebirths else 0) else nil
	)

	local officeLevel = if progress ~= nil then progress.office else 0
	section(lot, "Office", tostring(officeLevel), function(model)
		LotLook.office(model, lot.base, officeLevel, lot.color)
	end)

	-- Trophy case: one gold trophy per Masterpiece (up to the shelf size, then a count).
	local trophies = if progress ~= nil then progress.trophies else 0
	section(lot, "Trophies", tostring(trophies), function(model)
		local case = LotLook.trophies(model, lot.base, trophies)
		if case ~= nil then
			floatingLabel(case, `{trophies} Masterpiece{if trophies == 1 then "" else "s"}`, GOLD, 5)
		end
	end)

	-- Top star: on the pedestal by the red carpet and on the billboard, for everyone to see.
	local actor, variant = nil, nil
	if data ~= nil then
		actor, variant = rarestOwned(data)
	end
	local starKey = (if owner ~= nil then tostring(owner.UserId) else "free")
		.. ":"
		.. (if actor ~= nil then actor.id else "")
		.. ":"
		.. (if variant ~= nil then variant.id else "")
	lot.model:SetAttribute("TopStar", if actor ~= nil then actor.name else nil)
	lot.model:SetAttribute("TopStarTier", if actor ~= nil then actor.tier else nil)
	section(lot, "Star", starKey, function(model)
		LotLook.star(model, lot.base, if actor ~= nil then actor.id else nil, if variant ~= nil then variant.id else nil)
		if owner == nil then
			setBillboard(lot, "YOUR STAR HERE", "Claim this lot", "and cast actors", Color3.fromRGB(120, 120, 130))
		elseif actor == nil or variant == nil then
			setBillboard(lot, owner.DisplayName, "No stars yet", "Casting Call!", Color3.fromRGB(120, 120, 130))
		else
			local tier = Actors.getTier(actor.tier)
			local tierColor = if tier ~= nil then tier.color else Color3.new(1, 1, 1)
			local variantText = if variant.id == "Normal" then "" else variant.name .. " "
			setBillboard(lot, owner.DisplayName .. "'s top star", actor.name, `{variantText}{actor.tier}`, tierColor, actor.id, variant.id)
		end
	end)

	-- Rare Wall: the owner's rarest actors by the gate, for visitors to see.
	local wall: { { actorId: string, variantId: string } } = {}
	if data ~= nil then
		for _, owned in TopStudios.rarest(data.roster, TopStudios.WallSize) do
			table.insert(wall, { actorId = owned.actor.id, variantId = owned.variant.id })
		end
	end
	local wallKey = (if owner ~= nil then tostring(owner.UserId) else "free")
	for _, entry in wall do
		wallKey ..= ":" .. entry.actorId .. "/" .. entry.variantId
	end
	section(lot, "RareWall", wallKey, function(model)
		TopStudiosModels.rareWall(model, lot.base, wall, TopStudios.WallSize)
	end)
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

-- Claimed lots and their owners, in lot order.
function LotService.owners(): { { index: number, owner: Player } }
	local list = {}
	for _, lot in lots do
		local owner = lot.owner
		if owner ~= nil then
			table.insert(list, { index = lot.index, owner = owner })
		end
	end
	return list
end

-- Lot `index`'s owner, or nil for a free lot or a bad index.
function LotService.ownerOf(index: number): Player?
	local lot = lots[index]
	return if lot ~= nil then lot.owner else nil
end

-- The index of the lot `player` owns, or nil.
function LotService.indexOf(player: Player): number?
	local lot = lotOf[player]
	return if lot ~= nil then lot.index else nil
end

-- Lot `index`'s model in the workspace (its attributes feed the Visit menu).
function LotService.model(index: number): Model?
	local lot = lots[index]
	return if lot ~= nil then lot.model else nil
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
