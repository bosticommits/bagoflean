--!strict
-- The show-off pieces: the Top Studios board on the spawn plaza (a big double-sided sign on two
-- posts that players walk under on the way to the middle lot) and the Rare Wall on every lot (a
-- display wall by the gate with the owner's rarest actors standing on rarity-colored plinths).
-- The board's rows are drawn by LeaderboardService; the wall is built by LotService.
local Actors = require(script.Parent.Parent.Actors)
local ActorModels = require(script.Parent.ActorModels)
local Build = require(script.Parent.Build)

local P = Build.Palette
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local INK = Color3.fromRGB(11, 15, 31) -- the menus' outline color (UiKit.INK)

local TopStudiosModels = {}

TopStudiosModels.Layout = table.freeze({
	-- World space: behind the spawn star, over the path to lot 2 between the Upgrades and Odds
	-- stands, its front toward the fountain (players turn round from spawn to read it, and see its
	-- back walking out of lot 2).
	board = CFrame.new(0, 0.2, -33) * CFrame.Angles(0, math.pi, 0),
	boardWidth = 21,
	boardHeight = 13,
	boardLift = 9, -- bottom edge of the screen: room to walk under
	-- Lot space (see LotModels.Layout): left of the red carpet, opposite the trophy case.
	rareWall = Vector3.new(-9.55, 0, -15),
	wallWidth = 8.2,
})

local L = TopStudiosModels.Layout

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local FIGURE_SCALE = 0.5

-- How wide a model is along the X axis of `frame`.
local function widthOf(model: Model, frame: CFrame): number
	local lo, hi = math.huge, -math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = frame:ToObjectSpace(part.CFrame)
			local half = part.Size / 2
			local reach = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
			lo = math.min(lo, cf.Position.X - reach)
			hi = math.max(hi, cf.Position.X + reach)
		end
	end
	return if hi > lo then hi - lo else 0
end

local function outline(label: TextLabel, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
end

-- The plaza board. Returns the screen part; its Front and Back faces carry the rows.
function TopStudiosModels.board(parent: Instance, base: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "TopStudiosBoard"
	model.Parent = parent
	local b = Build.new(model, base)
	local w, h, lift = L.boardWidth, L.boardHeight, L.boardLift
	local postX = w / 2 + 1.2
	local top = lift + h

	for _, side in { -1, 1 } do
		b:block("BoardFoot", v(3.4, 1.2, 3.4), v(side * postX, 0.6, 0), P.Burgundy)
		b:block("BoardPost", v(2.4, top + 1, 2.4), v(side * postX, (top + 1) / 2 + 0.6, 0), P.Cream)
		b:block("BoardPostBand", v(2.7, 0.6, 2.7), v(side * postX, lift - 0.3, 0), P.Gold, METAL)
		b:block("BoardPostCap", v(3, 0.8, 3), v(side * postX, top + 2, 0), P.Burgundy)
		b:ball("BoardLamp", 1.8, v(side * postX, top + 3.2, 0), P.Light, NEON)
	end
	b:block("BoardFrame", v(w + 1.2, h + 1.2, 1.2), v(0, lift + h / 2, 0), P.Gold, METAL)
	local screen = b:block("BoardScreen", v(w, h, 1.3), v(0, lift + h / 2, 0), P.Navy)

	-- Header: a burgundy plate with the title on both sides and a gold star over it.
	b:block("BoardHeaderTrim", v(w * 0.7 + 0.6, 3.6, 1.5), v(0, top + 2.2, 0), P.Gold, METAL)
	local header = b:block("BoardHeader", v(w * 0.7, 3, 1.6), v(0, top + 2.2, 0), P.Burgundy)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = Build.sign(header, face, "TOP STUDIOS", P.Gold)
		outline(label, 4)
	end
	local star = b:sub(v(0, top + 5.2, 0))
	star:block("BoardStar", v(2.4, 2.4, 0.5), CFrame.Angles(0, 0, math.rad(45)), P.Gold, NEON)
	star:block("BoardStar", v(2.4, 2.4, 0.5), CFrame.identity, P.Gold, NEON)

	-- Lights along the bottom edge, like a marquee.
	for i = 0, 11 do
		b:ball("BoardBulb", 0.5, v(-w / 2 + 1 + i * (w - 2) / 11, lift - 0.15, 0), P.Light, NEON)
	end

	Build.decorative(model)
	for _, name in { "BoardPost", "BoardFoot" } do
		for _, part in model:GetChildren() do
			if part.Name == name and part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
	return screen
end

-- The Rare Wall for the lot at `base`, with `owned` (rarest first) on its plinths. An empty list (a free lot, or a new
-- studio) shows the wall with bare grey plinths.
function TopStudiosModels.rareWall(parent: Instance, base: CFrame, owned: { { actorId: string, variantId: string } }, slots: number)
	local b = Build.new(parent, base * CFrame.new(L.rareWall + v(0, 1, 0)))
	local w = L.wallWidth
	b:block("RareWallBase", v(w + 0.6, 0.8, 3), v(0, 0.4, 0), P.Burgundy)
	b:block("RareWall", v(w, 6, 0.6), v(0, 3.8, 1.2), P.Navy)
	b:block("RareWallTrim", v(w + 0.4, 0.4, 0.8), v(0, 6.9, 1.2), P.Gold, METAL)
	local sign = b:block("RareWallSign", v(w * 0.6, 1.4, 0.3), v(0, 6.2, 0.75), P.Burgundy)
	outline(Build.sign(sign, Enum.NormalId.Front, "RARE WALL", P.Gold), 3)

	local gap = w / slots
	for i = 1, slots do
		local x = -w / 2 + gap * (i - 0.5)
		local entry = owned[i]
		local actor = if entry ~= nil then Actors.getActor(entry.actorId) else nil
		local tier = if actor ~= nil then Actors.getTier(actor.tier) else nil
		local variant = if entry ~= nil then Actors.getVariant(entry.variantId) else nil
		local color = if tier ~= nil then tier.color else P.Grey
		b:block("RarePlinth", v(gap - 0.3, 0.8, 1.8), v(x, 1.2, -0.2), P.Cream)
		b:block("RarePlinthGlow", v(gap - 0.2, 0.25, 1.9), v(x, 1.65, -0.2), color, if tier ~= nil then NEON else nil)
		if actor ~= nil and tier ~= nil then
			-- Built at one size, then shrunk if its hat, wings or sidekick would hang off the plinth.
			local spot = b:at(v(x, 1.8, -0.2))
			local figure = ActorModels.build(parent, spot, actor.id, entry.variantId, FIGURE_SCALE)
			local wide = widthOf(figure, spot)
			if wide > gap - 0.15 then
				figure:Destroy()
				ActorModels.build(parent, spot, actor.id, entry.variantId, FIGURE_SCALE * (gap - 0.15) / wide)
			end
			-- Name and rarity on the wall behind the figure.
			local plate = b:block("RareNameplate", v(gap - 0.4, 1.2, 0.1), v(x, 4.7, 0.85), color:Lerp(P.Navy, 0.55))
			local variantText = if variant ~= nil and variant.id ~= "Normal" then variant.name .. " " else ""
			local label = Build.sign(plate, Enum.NormalId.Front, `{actor.name}\n{variantText}{tier.name}`, P.OffWhite)
			label.TextYAlignment = Enum.TextYAlignment.Center
			outline(label, 2)
		end
	end
	Build.decorative(parent)
	for _, part in parent:GetChildren() do
		if (part.Name == "RareWallBase" or part.Name == "RareWall") and part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

return TopStudiosModels
