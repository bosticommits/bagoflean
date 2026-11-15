local roblox = require("@lune/roblox")

local H = require("./harness")
local Actors = H.require("Actors")
local TopStudios = H.require("TopStudios")
local TopStudiosModels = H.require("Models/TopStudiosModels")
local MapModels = H.require("Models/MapModels")
local LotLook = H.require("Models/LotLook")
local test, expect, equal = H.test, H.expect, H.equal

local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

-- A part's world-space bounding box (corners min, max), including any turn.
local function bounds(part: any): (any, any)
	local cf, size = part.CFrame, part.Size / 2
	local extent = Vector3.new(
		math.abs(cf.RightVector.X) * size.X + math.abs(cf.UpVector.X) * size.Y + math.abs(cf.LookVector.X) * size.Z,
		math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z,
		math.abs(cf.RightVector.Z) * size.X + math.abs(cf.UpVector.Z) * size.Y + math.abs(cf.LookVector.Z) * size.Z
	)
	return cf.Position - extent, cf.Position + extent
end

local function box(root: any): (any, any)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local a, b = bounds(part)
			lo, hi = lo:Min(a), hi:Max(b)
		end
	end
	return lo, hi
end

local function overlaps(alo: any, ahi: any, blo: any, bhi: any): boolean
	return alo.X < bhi.X and ahi.X > blo.X and alo.Z < bhi.Z and ahi.Z > blo.Z
end

local function actorOfTier(tier: string): string
	for _, actor in Actors.List do
		if actor.tier == tier then
			return actor.id
		end
	end
	error("no actor of tier " .. tier)
end

test("the rarest actors come first: tier, then variant", function()
	local newcomer, pro, star = actorOfTier("Newcomer"), actorOfTier("Pro"), actorOfTier("Star")
	local roster = {
		[newcomer .. ":Award"] = 1,
		[pro .. ":Normal"] = 3,
		[star .. ":Normal"] = 1,
		[star .. ":Shiny"] = 1,
		[pro .. ":Shiny"] = 0, -- sold or used up: not shown
		["NotAnActor:Normal"] = 2,
	}
	local top = TopStudios.rarest(roster, 5)
	equal(#top, 4, "owned copies")
	equal(top[1].key, star .. ":Shiny", "first")
	equal(top[2].key, star .. ":Normal", "second")
	equal(top[3].key, pro .. ":Normal", "third")
	equal(top[4].key, newcomer .. ":Award", "a Newcomer is below a Pro even when Award-Winning")
	equal(#TopStudios.rarest(roster, 2), 2, "the wall only takes as many as it has room for")
	equal(#TopStudios.rarest({}, 5), 0, "a new studio has none")
end)

test("the board keeps each studio once, at its best Fame, best first", function()
	local saved = { { userId = 1, fame = 500 }, { userId = 2, fame = 900 }, { userId = 3, fame = 100 } }
	local live = { { userId = 1, fame = 1200 }, { userId = 4, fame = 0 }, { userId = 5, fame = 300 } }
	local rows = TopStudios.merge(saved, live, 3)
	equal(#rows, 3, "rows")
	equal(rows[1].userId, 1, "a player here who just earned Fame moves up at once")
	equal(rows[1].fame, 1200, "their fresher Fame is shown")
	equal(rows[2].userId, 2, "second")
	equal(rows[3].userId, 5, "third")
	for _, row in TopStudios.merge(saved, live, 10) do
		expect(row.userId ~= 4, "players with no Fame are left off")
	end
	equal(#TopStudios.merge({}, {}, 10), 0, "an empty board")
end)

test("board numbers are short", function()
	equal(TopStudios.short(0), "0", "zero")
	equal(TopStudios.short(950), "950", "hundreds")
	equal(TopStudios.short(1000), "1K", "a thousand")
	equal(TopStudios.short(12549), "12.5K", "rounds down, never up")
	equal(TopStudios.short(3400000), "3.4M", "millions")
	equal(TopStudios.short(250000000), "250M", "no decimals past 100")
	equal(TopStudios.short(1.2e9), "1.2B", "billions")
end)

test("the Top Studios board stands clear of the plaza, stands and lots, with room to walk under", function()
	local town = roblox.Instance.new("Folder")
	local built = MapModels.build(town)
	local folder = roblox.Instance.new("Folder")
	local screen = TopStudiosModels.board(folder, TopStudiosModels.Layout.board)
	local lo, hi = box(folder)
	local Lay = MapModels.Layout
	expect(math.min(math.abs(lo.Z), math.abs(hi.Z)) > Lay.plazaRadius, "off the plaza")
	expect(math.max(math.abs(lo.Z), math.abs(hi.Z)) < Lay.sidewalkTo, "in front of the lots")
	for _, stand in built.stands do
		local slo, shi = box(town:FindFirstChild("Stand_" .. stand.info.screen))
		expect(not overlaps(lo, hi, slo, shi), `board ({lo.X}..{hi.X}, {lo.Z}..{hi.Z}) overlaps the {stand.info.screen} stand ({slo.X}..{shi.X}, {slo.Z}..{shi.Z})`)
	end
	local sLo = bounds(screen)
	expect(sLo.Y > 8, "players walk under the screen")
	-- Its front faces the spawn.
	local toSpawn = (Lay.spawn.Position - TopStudiosModels.Layout.board.Position).Unit
	expect(screen.CFrame.LookVector:Dot(toSpawn) > 0.9, "the board faces the spawn")
end)

test("the Rare Wall fits on a lot without touching anything else", function()
	local base = CFrame.new()
	local lot = roblox.Instance.new("Folder")
	LotLook.build(lot, base, 1, {
		stages = 5,
		cinema = 10,
		office = 6,
		trophies = 5,
		filming = {},
		star = actorOfTier("Icon"),
		variant = "Award",
	})
	local wall = roblox.Instance.new("Model")
	local owned = {}
	for _, tier in { "Icon", "Legend", "Superstar", "Star", "Pro" } do
		table.insert(owned, { actorId = actorOfTier(tier), variantId = "Award" })
	end
	table.insert(owned, 1, { actorId = "ComedyDuo", variantId = "Shiny" })
	TopStudiosModels.rareWall(wall, base, owned, TopStudios.WallSize)
	local wlo, whi = box(wall)
	local floor = 28
	expect(wlo.X > -floor and whi.X < floor and wlo.Z > -floor and whi.Z < floor, "inside the lot")
	-- Fixed scenery that is meant to run under everything.
	local under = { Floor = true, Yard = true, RedCarpet = true, CarpetEdge = true }
	for _, part in lot:GetDescendants() do
		if part:IsA("BasePart") and not under[part.Name] and part.Transparency < 1 then
			local plo, phi = bounds(part)
			for _, piece in wall:GetDescendants() do
				if piece:IsA("BasePart") then
					local alo, ahi = bounds(piece)
					expect(not overlaps(alo, ahi, plo, phi), `Rare Wall {piece.Name} overlaps {part.Name} at {part.CFrame.Position}`)
				end
			end
		end
	end
	-- It faces the red carpet (lot-space x = 0) and leans toward the gate (-Z).
	local Lay = TopStudiosModels.Layout
	local frame = base * CFrame.new(Lay.rareWall) * CFrame.Angles(0, Lay.rareWallYaw, 0)
	expect(frame.LookVector.X * -Lay.rareWall.X > 0, "the wall faces the carpet")
	expect(frame.LookVector.Z < 0, "the wall leans toward the gate")
	-- Each figure stays on its own plinth.
	local figures = {}
	for _, child in wall:GetChildren() do
		if child:IsA("Model") then
			table.insert(figures, child)
		end
	end
	equal(#figures, TopStudios.WallSize, "one figure per slot")
	local gap = TopStudiosModels.Layout.wallWidth / TopStudios.WallSize
	for _, figure in figures do
		local lo, hi, top = math.huge, -math.huge, -math.huge
		for _, part in figure:GetDescendants() do
			if part:IsA("BasePart") then
				local cf = frame:ToObjectSpace(part.CFrame)
				local half = part.Size / 2
				local reach = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
				lo, hi = math.min(lo, cf.Position.X - reach), math.max(hi, cf.Position.X + reach)
				local up = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
				top = math.max(top, cf.Position.Y + up)
			end
		end
		expect(hi - lo <= gap + 0.01, `{figure.Name} is wider than its plinth ({hi - lo})`)
		expect(top - 1 <= TopStudiosModels.NameplateBottom - 0.2 + 0.01, `{figure.Name} covers its nameplate (top {top - 1})`)
	end
end)

test("figure fit: shrinks by width or height, never grows, leaves normal actors alone", function()
	local Fit = H.require("Models/ActorFit")
	equal(Fit.shrink(2, 4, 3, 4), 1, "fits already")
	equal(Fit.shrink(6, 2, 3, 4), 0.5, "width limits")
	equal(Fit.shrink(2, 8, 3, 4), 0.5, "height limits")
	equal(Fit.shrink(6, 8, 3, 2), 0.25, "the tighter of the two")
	equal(Fit.shrink(1, 1, nil, nil), 1, "no limits")
end)

test("wall cap: the figure top stays at or under the nameplate's bottom edge", function()
	local Fit = H.require("Models/ActorFit")
	expect(math.abs(Fit.wallCap(1.8, 5.2) - 3.4) < 1e-9, "gap above the plinth")
	equal(Fit.wallCap(5, 4), 0, "never negative")
	expect(math.abs(Fit.shrink(1, 6.8, nil, Fit.wallCap(1.8, 5.2)) - 0.5) < 1e-9, "a 6.8-tall figure halves")
end)

test("mesh truth: only the Witch, Astronaut and Tourist exceed the Rare Wall height cap (from rig piece bounds)", function()
	local Fit = H.require("Models/ActorFit")
	local Shapes = H.require("Models/ActorShapes")
	local tall = {}
	for _, actor in Actors.List do
		local rig = Shapes.Actors[actor.id]
		local top = -math.huge
		for name, piece in rig.pieces do
			if name ~= "Base" then
				top = math.max(top, piece.center.Y + piece.size.Y / 2)
			end
		end
		if top * TopStudiosModels.FigureScale > TopStudiosModels.MaxFigureHeight then
			table.insert(tall, actor.id)
		end
	end
	table.sort(tall)
	equal(table.concat(tall, ","), "CardboardAstronaut,TimeTourist,WobblyWitch", "clamped actors")
end)

test("height counts a hover: a floating figure is measured from its feet, not its lowest part", function()
	local Fit = H.require("Models/ActorFit")
	local frame = CFrame.new(0, 0, 0)
	local folder = roblox.Instance.new("Folder")
	local model = roblox.Instance.new("Model")
	local part = roblox.Instance.new("Part")
	part.Size = Vector3.new(1, 2, 1)
	part.CFrame = CFrame.new(0, 3, 0) -- hovers: spans y 2 to 4
	part.Parent = model
	model.Parent = folder
	equal(Fit.heightOf(model, frame), 4, "top above the feet, hover included")
end)

test("lot portrait camera: normal figures keep the original framing, tall ones back off, and it is stored for clients", function()
	local Portrait = H.require("PortraitCamera")
	local y, d = Portrait.fit(5.2, 0, 3)
	equal(y, 2.8, "normal target height")
	equal(d, Portrait.MinDistance, "normal distance")
	local ty, td = Portrait.fit(11, 0.4, 3.4)
	expect(math.abs(ty - 5.7) < 1e-9, "tall figures aim at their middle")
	expect(td > Portrait.MinDistance, "and stand further back")
	local tanHalf = math.tan(math.rad(Portrait.FieldOfView / 2))
	expect(td * tanHalf >= (11 - 5.7) * 1.08 - 1e-6, "the whole height fits")
	local wide = select(2, Portrait.fit(5, 0, 9))
	expect(wide * tanHalf * Portrait.Aspect >= 9 / 2 * 1.08 - 1e-6, "the whole width fits the 0.63 aspect")
	local viewport = roblox.Instance.new("ViewportFrame")
	Portrait.store(viewport, ty, td)
	equal(viewport:GetAttribute("PortraitDistance"), td, "distance stored")
	equal(viewport:GetAttribute("PortraitTargetY"), ty, "target stored")
end)
