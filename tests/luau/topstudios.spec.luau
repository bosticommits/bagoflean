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
		local lo, hi = math.huge, -math.huge
		for _, part in figure:GetDescendants() do
			if part:IsA("BasePart") then
				local cf = frame:ToObjectSpace(part.CFrame)
				local half = part.Size / 2
				local reach = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
				lo, hi = math.min(lo, cf.Position.X - reach), math.max(hi, cf.Position.X + reach)
			end
		end
		expect(hi - lo <= gap + 0.01, `{figure.Name} is wider than its plinth ({hi - lo})`)
	end
end)
