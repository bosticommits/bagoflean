--!strict
-- The studio lot's buildings and props, built from parts in the chunky toy style of
-- ART_STYLE.md (sections 2, 3, 7 and 8). Each function builds one piece into a Builder whose
-- origin is the piece's bottom centre with its front facing -Z (toward the boulevard).
-- Pieces that grow with upgrades take a level and look bigger and fancier as it rises.
local Build = require(script.Parent.Build)

type Builder = Build.Builder

local P = Build.Palette
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal

local LotModels = {}

-- Where everything sits on a lot, in lot space: origin at the lot's ground centre, -Z toward the
-- boulevard. The lot floor's top is at y = 1. Shared by LotService and the preview tool.
LotModels.Layout = table.freeze({
	size = 56,
	gateGap = 12,
	gateZ = -27.1,
	claimPad = Vector3.new(0, 0, -19),
	collectPad = Vector3.new(-8.5, 0, -3),
	kiosk = Vector3.new(-8.5, 0, 2.4),
	pedestal = Vector3.new(8.5, 0, -3),
	trophyCase = Vector3.new(9, 0, -12),
	office = Vector3.new(-19, 0, -19),
	billboard = Vector3.new(19, 0, -20),
	cinemaFront = 4.5,
	stages = {
		Vector3.new(-20, 0, -2),
		Vector3.new(20, 0, -2),
		Vector3.new(-20, 0, 13),
		Vector3.new(20, 0, 13),
	},
	lamps = { Vector3.new(-11, 0, -24.5), Vector3.new(11, 0, -24.5), Vector3.new(-12.5, 0, -9), Vector3.new(12.5, 0, -9) },
	palms = { Vector3.new(-24.5, 0, 24.5), Vector3.new(24.5, 0, 24.5), Vector3.new(-14, 0, 24), Vector3.new(14, 0, 24) },
	stanchionX = 3.8,
	stanchionFromZ = -13,
	stanchionToZ = 2,
})

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function lightRow(b: Builder, name: string, from: Vector3, to: Vector3, count: number, size: number, color: Color3)
	for i = 0, count - 1 do
		local t = if count == 1 then 0.5 else i / (count - 1)
		b:ball(name, size, from:Lerp(to, t), color, NEON)
	end
end

-- Ground ----------------------------------------------------------------------------------------

-- Grass plot with a paved yard and the red carpet up the middle. Top surface is at y = 1.
function LotModels.ground(b: Builder, size: number, carpetLength: number)
	b:block("Floor", v(size, 1, size), v(0, 0.5, 0), P.Green, Enum.Material.Grass)
	b:block("Yard", v(size - 6, 0.1, size - 6), v(0, 1.05, 0), P.Paving)
	-- Red carpet from the gate to the cinema door, with a gold edge.
	local z0 = -size / 2
	b:block("RedCarpet", v(6, 0.1, carpetLength), v(0, 1.15, z0 + carpetLength / 2), P.Carpet, Enum.Material.Fabric)
	for _, x in { -3.2, 3.2 } do
		b:block("CarpetEdge", v(0.4, 0.12, carpetLength), v(x, 1.15, z0 + carpetLength / 2), P.Gold)
	end
end

-- Hedges around the sides and back, with cream pillars, leaving a gap at the front for the gate.
function LotModels.hedges(b: Builder, size: number, gateGap: number)
	local half = size / 2 - 0.9
	local h = 2.6
	local function hedge(cx: number, cz: number, lx: number, lz: number)
		b:block("Hedge", v(lx, h, lz), v(cx, 1 + h / 2, cz), P.DarkGreen, Enum.Material.Grass)
		b:block("HedgeTop", v(lx + 0.2, 0.5, lz + 0.2), v(cx, 1 + h + 0.25, cz), P.Green, Enum.Material.Grass)
	end
	hedge(-half, 0, 1.8, size - 1.8)
	hedge(half, 0, 1.8, size - 1.8)
	hedge(0, half, size - 1.8, 1.8)
	local frontLength = half - gateGap / 2
	hedge(-(gateGap / 2 + frontLength / 2), -half, frontLength, 1.8)
	hedge(gateGap / 2 + frontLength / 2, -half, frontLength, 1.8)
	for _, x in { -half, half } do
		for _, z in { -half, 0, half } do
			b:block("Pillar", v(2.4, 4.2, 2.4), v(x, 3.1, z), P.Cream)
			b:block("PillarCap", v(2.8, 0.6, 2.8), v(x, 5.5, z), P.Burgundy)
		end
	end
end

-- Studio gate: two tall pillars with lamps and the lot number. No arch, so the cinema stays in
-- full view from the boulevard.
function LotModels.gate(b: Builder, gap: number, lotNumber: number)
	local x = gap / 2 + 1.2
	for _, side in { -1, 1 } do
		b:block("GateBase", v(3.4, 2, 3.4), v(side * x, 1, 0), P.Burgundy)
		b:block("GatePost", v(2.6, 7, 2.6), v(side * x, 5.5, 0), P.Cream)
		b:block("GateCap", v(3.2, 0.8, 3.2), v(side * x, 9.4, 0), P.Burgundy)
		b:ball("GateLamp", 1.8, v(side * x, 10.6, 0), P.Light, NEON)
		local badge = b:block("GateBadge", v(2, 2, 0.4), v(side * x, 6, -1.4), P.Gold)
		Build.sign(badge, Enum.NormalId.Front, tostring(lotNumber), P.Burgundy)
	end
end

-- Props -----------------------------------------------------------------------------------------

function LotModels.palm(b: Builder, height: number, lean: number?)
	if Build.mesh(b, "PalmTree", CFrame.Angles(0, math.rad(height * 37 % 360), 0), height) then
		return
	end
	local tilt = math.rad(lean or 6)
	local segments = 5
	local segment = height / segments
	local top = Vector3.zero
	for i = 0, segments - 1 do
		-- Each trunk chunk leans a little more, so the trunk curves.
		local angle = tilt * (i + 1) / segments
		local dir = Vector3.new(math.sin(angle), math.cos(angle), 0)
		local center = top + dir * (segment / 2)
		local width = 1.6 - i * 0.12
		b:block("Trunk", v(width, segment + 0.1, width), CFrame.new(center) * CFrame.Angles(0, 0, -angle), if i % 2 == 0 then P.Bark else P.Wood)
		top += dir * segment
	end
	local crown = b:sub(top)
	crown:block("Crown", v(2, 1.2, 2), v(0, 0.3, 0), P.DarkGreen, Enum.Material.Grass)
	for i = 0, 6 do
		local yaw = math.rad(i * 360 / 7 + 10)
		local leaf = CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0.2, -3.2) * CFrame.Angles(math.rad(-22), 0, 0)
		crown:block("Leaf", v(1.8, 0.4, 6.5), leaf, if i % 2 == 0 then P.Green else P.DarkGreen, Enum.Material.Grass)
	end
	for i = 0, 2 do
		local yaw = math.rad(i * 120)
		crown:ball("Coconut", 0.8, CFrame.Angles(0, yaw, 0) * CFrame.new(0, -0.6, -0.8), P.Bark)
	end
end

function LotModels.lamp(b: Builder, height: number?): BasePart
	local h = height or 9
	b:block("LampBase", v(1.4, 1, 1.4), v(0, 0.5, 0), P.Charcoal, METAL)
	b:cylinder("LampPole", h, 0.5, v(0, h / 2, 0), P.Charcoal, METAL)
	b:block("LampCap", v(1.6, 0.4, 1.6), v(0, h + 2.1, 0), P.Charcoal, METAL)
	local head = b:block("LampHead", v(1.2, 1.6, 1.2), v(0, h + 1.1, 0), P.Light, NEON)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = head
	return head
end

-- Searchlight that sweeps the sky (the beam is a faint neon cylinder).
function LotModels.searchlight(b: Builder, yaw: number, color: Color3?)
	-- Drum pivot 2.6 studs up, aimed 65 degrees above the horizon (matches the Blender mesh).
	local aim = CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-25), 0, 0)
	if not Build.mesh(b, "Searchlight", CFrame.Angles(0, math.rad(yaw), 0)) then
		b:block("SearchlightBase", v(2.6, 0.5, 2.6), v(0, 0.25, 0), P.Carpet)
		b:cylinder("SearchlightTurntable", 0.4, 2, v(0, 0.7, 0), P.Steel, METAL)
		for _, side in { -1, 1 } do
			b:block("SearchlightYoke", v(0.3, 2, 0.7), CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(side * 1.05, 2, 0), P.Charcoal, METAL)
		end
		b:cylinder("SearchlightDrum", 2.4, 1.7, aim * CFrame.new(0, 0.3, 0), P.Steel, METAL)
		b:cylinder("SearchlightRim", 0.3, 1.9, aim * CFrame.new(0, 1.45, 0), P.Gold, METAL)
		b:cylinder("SearchlightLens", 0.1, 1.5, aim * CFrame.new(0, 1.62, 0), P.Light, NEON)
	end
	local beam = b:cylinder("SearchlightBeam", 40, 1.6, aim * CFrame.new(0, 21.7, 0), color or P.Light, NEON)
	beam.Transparency = 0.8
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
end

-- Vintage movie camera on a tripod, lens to the front.
function LotModels.filmCamera(b: Builder)
	if Build.mesh(b, "FilmCamera", CFrame.identity) then
		return
	end
	for i = 0, 2 do
		local a = math.rad(i * 120 + 90)
		local foot = v(1.4 * math.cos(a), 0, 1.4 * math.sin(a))
		local top = v(0.2 * math.cos(a), 3.6, 0.2 * math.sin(a))
		b:block("TripodLeg", v(0.3, (top - foot).Magnitude, 0.3), CFrame.lookAt((foot + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0), P.Wood)
	end
	b:block("CameraBody", v(1.4, 1.6, 2.4), v(0, 4.5, -0.1), P.Charcoal)
	b:block("CameraTrim", v(1.5, 0.2, 2.5), v(0, 4, -0.1), P.Gold, METAL)
	b:cylinder("CameraLens", 0.9, 0.9, CFrame.new(0, 4.6, -1.5) * CFrame.Angles(math.rad(90), 0, 0), P.Steel, METAL)
	b:cylinder("CameraGlass", 0.1, 0.8, CFrame.new(0, 4.6, -2) * CFrame.Angles(math.rad(90), 0, 0), P.Blue, GLASS)
	for _, z in { 0.55, -0.95 } do
		b:cylinder("CameraReel", 0.3, 2.1, CFrame.new(0, 6.4, z) * CFrame.Angles(0, 0, math.rad(90)), P.Gold, METAL)
	end
end

-- Small booth beside the collect pad.
function LotModels.ticketKiosk(b: Builder)
	b:block("KioskBase", v(3.6, 1, 3), v(0, 0.5, 0), P.Burgundy)
	b:block("KioskBody", v(3.2, 3, 2.6), v(0, 2.5, 0), P.Cream)
	b:block("KioskWindow", v(2.2, 1.4, 0.2), v(0, 2.8, -1.3), P.Glass, GLASS)
	b:block("KioskCounter", v(2.6, 0.2, 0.6), v(0, 2.1, -1.5), P.Wood)
	b:wedge("KioskRoof", v(4, 1.2, 1.8), CFrame.new(0, 4.6, -0.9), P.Carpet)
	b:wedge("KioskRoofBack", v(4, 1.2, 1.8), CFrame.new(0, 4.6, 0.9) * CFrame.Angles(0, math.pi, 0), P.Carpet)
	b:ball("KioskTopper", 0.9, v(0, 5.5, 0), P.Gold, NEON)
	local plate = b:block("KioskSign", v(3, 0.8, 0.2), v(0, 3.65, -1.35), P.Navy)
	Build.sign(plate, Enum.NormalId.Front, "BOX OFFICE", P.Gold)
end

-- Gold stanchions with velvet ropes along the carpet.
function LotModels.stanchions(b: Builder, fromZ: number, toZ: number, x: number)
	local count = math.max(2, math.floor((toZ - fromZ) / 5) + 1)
	for _, side in { -x, x } do
		local prev: Vector3? = nil
		for i = 0, count - 1 do
			local z = fromZ + (toZ - fromZ) * i / (count - 1)
			b:cylinder("Stanchion", 2.2, 0.35, v(side, 1.1, z), P.Gold, METAL)
			b:ball("StanchionTop", 0.6, v(side, 2.3, z), P.Gold, METAL)
			local here = v(side, 1.9, z)
			if prev ~= nil then
				local mid = (prev + here) / 2
				b:block("Rope", v(0.25, 0.25, (here - prev).Magnitude), CFrame.lookAt(mid - v(0, 0.25, 0), here - v(0, 0.25, 0)), P.Burgundy, Enum.Material.Fabric)
			end
			prev = here
		end
	end
end

-- Sound stage -----------------------------------------------------------------------------------

export type StageLook = {
	owned: boolean,
	accent: Color3,
	filming: boolean,
}

-- A film hangar: thick walls, barrel roof, big sliding door and a number. Footprint 12 x 14.
function LotModels.soundStage(b: Builder, number: number, look: StageLook)
	local wall = if look.owned then P.Cream else P.Grey
	local trim = if look.owned then P.Burgundy else P.Steel
	local roof = if look.owned then look.accent else P.Steel
	local w, d, h = 11, 13, 7
	b:block("StagePlinth", v(w + 1, 0.6, d + 1), v(0, 0.3, 0), P.Paving)
	b:block("SoundStage", v(w, h, d), v(0, 0.6 + h / 2, 0), wall)
	b:block("StageBase", v(w + 0.3, 1, d + 0.3), v(0, 1.1, 0), trim)
	b:block("StageTrim", v(w + 0.4, 0.8, d + 0.4), v(0, 0.6 + h - 0.4, 0), trim)
	b:cylinder("StageRoof", d + 0.4, w + 0.4, CFrame.new(0, 0.6 + h, 0) * CFrame.Angles(math.rad(90), 0, 0), roof)
	-- Roof ribs.
	for _, z in { -d / 2 + 0.2, 0, d / 2 - 0.2 } do
		b:cylinder("StageRib", 0.5, w + 0.8, CFrame.new(0, 0.6 + h, z) * CFrame.Angles(math.rad(90), 0, 0), trim)
	end
	-- Big sliding door with stripes.
	local front = -d / 2
	b:block("StageDoorFrame", v(7.2, 6.4, 0.3), v(0, 0.6 + 3.2, front - 0.1), trim)
	b:block("StageDoor", v(6.4, 5.8, 0.3), v(0, 0.6 + 2.9, front - 0.25), if look.owned then P.Navy else P.Steel)
	for i = 1, 3 do
		b:block("DoorStripe", v(6.4, 0.25, 0.1), v(0, 0.6 + i * 1.45, front - 0.45), if look.owned then P.Gold else P.Grey)
	end
	-- Number plate on the roof front.
	local plate = b:block("StageNumber", v(3.6, 3.6, 0.4), v(0, 0.6 + h + 2.3, front - 0.4), if look.owned then P.Gold else P.Grey)
	Build.sign(plate, Enum.NormalId.Front, tostring(number), if look.owned then P.Burgundy else P.Charcoal)
	-- Same number on the boulevard-facing side wall, big.
	for _, side in { -1, 1 } do
		local sidePlate = b:block("StageSideNumber", v(0.2, 4, 4), v(side * (w / 2 + 0.1), 0.6 + h / 2 + 0.6, -1), wall)
		Build.sign(sidePlate, if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, tostring(number), trim)
	end
	-- ON AIR light over the door: lit while a movie is filming here.
	local onAir = b:block("OnAir", v(3.4, 1, 0.3), v(0, 0.6 + h - 0.2, front - 0.45), if look.filming then P.Carpet else P.Charcoal, if look.filming then NEON else nil)
	Build.sign(onAir, Enum.NormalId.Front, "ON AIR", if look.filming then P.OffWhite else P.Steel)
	if look.owned then
		-- Rooftop lights and a side door with a little canopy.
		lightRow(b, "RoofLight", v(-w / 2 + 1, 0.6 + h + 0.3, front - 0.3), v(w / 2 - 1, 0.6 + h + 0.3, front - 0.3), 5, 0.6, P.Light)
		b:block("SideDoor", v(0.3, 3.4, 2), v(w / 2 + 0.15, 2.3, 3), P.Navy)
		b:block("SideCanopy", v(1.4, 0.3, 2.8), v(w / 2 + 0.7, 4.2, 3), look.accent)
		b:block("VentUnit", v(2, 1.2, 2), v(-2.5, 0.6 + h + 4.6, 2), P.Steel, METAL)
	end
end

-- Cinema ----------------------------------------------------------------------------------------

-- Cinema Size upgrade level (0-6) -> look tier 1-4.
function LotModels.cinemaTier(level: number): number
	if level >= 6 then
		return 4
	elseif level >= 4 then
		return 3
	elseif level >= 2 then
		return 2
	end
	return 1
end

local CINEMA_SIZE = {
	{ w = 16, h = 9, d = 12 },
	{ w = 20, h = 12, d = 14 },
	{ w = 24, h = 15, d = 16 },
	{ w = 24, h = 15, d = 16 },
}

-- The cinema. Origin is the bottom centre of its FRONT wall, so it grows backward (+Z).
-- Returns the marquee label (shows the studio name).
function LotModels.cinema(b: Builder, tier: number, accent: Color3): TextLabel
	local size = CINEMA_SIZE[math.clamp(tier, 1, 4)]
	local w, h, d = size.w, size.h, size.d
	local zc = d / 2
	b:block("CinemaBody", v(w, h, d), v(0, h / 2, zc), P.Cream)
	b:block("CinemaBase", v(w + 0.4, 1.4, d + 0.4), v(0, 0.7, zc), P.Burgundy)
	b:block("Cornice", v(w + 1, 1, d + 1), v(0, h + 0.5, zc), P.Burgundy)
	b:block("Parapet", v(w + 0.4, 0.8, d + 0.4), v(0, h + 1.4, zc), P.Cream)

	-- Burgundy pilasters on the front corners and a stepped headboard over the roofline.
	for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
		b:block("Pilaster", v(1.4, h, 0.5), v(x, h / 2, -0.2), P.Burgundy)
	end
	local steps = if tier >= 2 then 3 else 2
	for i = 1, steps do
		local stepW = w * (0.75 - (i - 1) * 0.2)
		b:block("Headboard", v(stepW, 1.8, 1), v(0, h + 1 + (i - 0.5) * 1.8, 0.4), if i % 2 == 1 then P.Burgundy else P.Cream)
		lightRow(b, "HeadboardBulb", v(-stepW / 2 + 0.5, h + 1 + i * 1.8 - 0.2, -0.15), v(stepW / 2 - 0.5, h + 1 + i * 1.8 - 0.2, -0.15), math.max(2, math.floor(stepW / 2.4)), 0.4, P.Gold)
	end
	local starY = h + 1 + steps * 1.8 + 1.4
	b:block("HeadboardStar", v(2.2, 2.2, 0.6), CFrame.new(0, starY, 0.4) * CFrame.Angles(0, 0, math.rad(45)), P.Gold, NEON)

	-- Entrance: glass doors in a burgundy frame.
	local doorW = if tier >= 3 then 8 else 6
	b:block("DoorFrame", v(doorW + 1.2, 6.4, 0.4), v(0, 3.2, -0.15), P.Burgundy)
	b:block("Doors", v(doorW, 5.6, 0.3), v(0, 2.8 + 0.2, -0.3), P.Navy, GLASS)
	b:block("DoorSplit", v(0.25, 5.6, 0.1), v(0, 3, -0.5), P.Gold)

	-- Poster light boxes either side of the doors.
	local posterColors = { P.Blue, P.Carpet, accent, P.Gold }
	local posterCount = if tier >= 3 then 2 else 1
	for side = -1, 1, 2 do
		for i = 1, posterCount do
			local x = side * (doorW / 2 + 1.6 + (i - 1) * 3.2)
			b:block("PosterFrame", v(2.6, 3.8, 0.3), v(x, 3.4, -0.2), P.Burgundy)
			b:block("Poster", v(2.1, 3.2, 0.1), v(x, 3.4, -0.4), posterColors[(i + (side + 1)) % #posterColors + 1], NEON)
		end
	end

	-- Marquee canopy with bulbs, and the name board above it.
	local canopyW = math.min(w - 2, doorW + 8)
	local canopyY = 6.8
	b:block("Canopy", v(canopyW, 1, 4), v(0, canopyY, -2), accent)
	b:block("CanopyEdge", v(canopyW + 0.4, 0.4, 4.4), v(0, canopyY - 0.6, -2), P.Burgundy)
	lightRow(b, "CanopyBulb", v(-canopyW / 2, canopyY - 0.9, -4.1), v(canopyW / 2, canopyY - 0.9, -4.1), math.floor(canopyW / 1.6), 0.5, P.Gold)
	local boardH = if tier >= 2 then 3 else 2.4
	local board = b:block("MarqueeSign", v(canopyW - 1, boardH, 0.6), v(0, canopyY + 0.5 + boardH / 2, -3.6), P.Navy)
	b:block("MarqueeFrame", v(canopyW - 0.4, boardH + 0.6, 0.4), v(0, canopyY + 0.5 + boardH / 2, -3.3), P.Gold)
	local marquee = Build.sign(board, Enum.NormalId.Front, "", P.Gold)

	-- Windows on the upper front.
	if tier >= 2 then
		local rowY = canopyY + boardH + 2.2
		if rowY + 1 < h then
			for i = -1, 1 do
				b:block("Window", v(2.4, 2, 0.2), v(i * 4.5, rowY, -0.05), P.Glass, GLASS)
			end
		end
	end

	-- Tier 2+: tall blade sign on the front corner.
	if tier >= 2 then
		local bladeH = h + 6
		local bx = w / 2 - 2
		b:block("BladeSign", v(1, bladeH, 3), v(bx, h - 2 + bladeH / 2 - 4, -1.6), P.Burgundy)
		local face = b:block("BladeFace", v(1.2, bladeH - 1.5, 2.2), v(bx, h - 2 + bladeH / 2 - 4, -1.6), P.Navy)
		lightRow(b, "BladeBulb", v(bx, h - 5, -3.2), v(bx, h + bladeH - 6.5, -3.2), math.floor(bladeH / 2), 0.45, P.Gold)
		Build.sign(face, Enum.NormalId.Left, "CINEMA", P.Gold)
		Build.sign(face, Enum.NormalId.Right, "CINEMA", P.Gold)
		b:ball("BladeTop", 1.6, v(bx, h - 2 + bladeH - 4 + 0.6, -1.6), P.Gold, NEON)
	end

	-- Tier 3+: columns either side of the entrance.
	if tier >= 3 then
		for _, x in { -w / 2 + 1.5, w / 2 - 1.5 } do
			b:cylinder("Column", h - 1, 1.6, v(x, (h - 1) / 2 + 1, -0.9), P.OffWhite)
			b:block("ColumnCap", v(2.2, 0.6, 2.2), v(x, h + 0.2, -0.9), P.Gold)
		end
		-- Side wings.
		for side = -1, 1, 2 do
			b:block("Wing", v(2, h - 4, d - 4), v(side * (w / 2 + 1), (h - 4) / 2, d / 2 + 1), P.Cream)
			b:block("WingTrim", v(2.4, 0.8, d - 3.6), v(side * (w / 2 + 1), h - 4, d / 2 + 1), P.Burgundy)
		end
	end

	-- Tier 4: grand premiere theatre with a gold dome and rooftop searchlights.
	if tier >= 4 then
		b:cylinder("DomeBase", 1.4, 8, v(0, h + 2.6, d / 2 + 2), P.Burgundy)
		b:ball("Dome", 7, v(0, h + 3.3, d / 2 + 2), P.Gold, METAL)
		b:cylinder("DomeSpire", 3, 0.5, v(0, h + 8, d / 2 + 2), P.Gold, METAL)
		b:ball("DomeTop", 1.2, v(0, h + 9.8, d / 2 + 2), P.Gold, NEON)
		for i, x in { -w / 2 + 2, w / 2 - 2 } do
			LotModels.searchlight(b:sub(v(x, h + 1.8, d - 2)), if i == 1 then -25 else 25)
		end
		lightRow(b, "RoofBulb", v(-w / 2, h + 1.9, -0.3), v(w / 2, h + 1.9, -0.3), 13, 0.5, P.Gold)
	end
	return marquee
end

-- Office ----------------------------------------------------------------------------------------

-- Producer's office, grown by the Offline Earnings upgrade (level 0-5). Footprint about 10 x 10.
function LotModels.office(b: Builder, level: number, accent: Color3)
	if level <= 0 then
		-- Star trailer on blocks.
		b:block("TrailerBody", v(9, 4, 5), v(0, 3.2, 0), P.OffWhite)
		b:block("TrailerStripe", v(9.1, 0.7, 5.1), v(0, 2.6, 0), accent)
		b:block("TrailerRoof", v(9.4, 0.5, 5.4), v(0, 5.45, 0), P.Steel, METAL)
		b:block("TrailerDoor", v(1.8, 3.2, 0.2), v(-2.2, 2.9, -2.55), P.Burgundy)
		b:block("TrailerStar", v(0.9, 0.9, 0.1), CFrame.new(-2.2, 3.9, -2.7) * CFrame.Angles(0, 0, math.rad(45)), P.Gold, NEON)
		b:block("TrailerWindow", v(3, 1.4, 0.2), v(1.8, 3.8, -2.55), P.Glass, GLASS)
		b:block("TrailerSteps", v(2, 0.6, 1.2), v(-2.2, 0.9, -3.2), P.Steel, METAL)
		for _, x in { -3, 3 } do
			b:block("TrailerBlock", v(1.2, 1.2, 4), v(x, 0.6, 0), P.Charcoal)
		end
		b:block("TrailerAwning", v(3, 0.2, 1.8), v(-2.2, 5, -3.2), accent)
		return
	end
	local floors = if level <= 2 then 2 else level
	local glass = level >= 3
	local floorH = 4.2
	local w, d = 9, 9
	b:block("OfficeBase", v(w + 0.6, 1, d + 0.6), v(0, 0.5, 0), P.Burgundy)
	for f = 0, floors - 1 do
		local y = 1 + f * floorH
		if glass then
			b:block("OfficeFloor", v(w, floorH - 0.6, d), v(0, y + (floorH - 0.6) / 2, 0), P.Glass, GLASS)
			b:block("OfficeSlab", v(w + 0.4, 0.6, d + 0.4), v(0, y + floorH - 0.3, 0), P.Cream)
			for _, x in { -w / 2, w / 2 } do
				for _, z in { -d / 2, d / 2 } do
					b:block("OfficeMullion", v(0.6, floorH - 0.6, 0.6), v(x, y + (floorH - 0.6) / 2, z), P.Cream)
				end
			end
		else
			b:block("OfficeFloor", v(w, floorH, d), v(0, y + floorH / 2, 0), P.Cream)
			for i = -1, 1 do
				b:block("OfficeWindow", v(2, 1.8, 0.2), v(i * 2.8, y + floorH / 2 + 0.3, -d / 2 - 0.05), P.Glass, GLASS)
			end
			b:block("OfficeBand", v(w + 0.2, 0.4, d + 0.2), v(0, y + floorH, 0), P.Burgundy)
		end
	end
	local top = 1 + floors * floorH
	b:block("OfficeRoof", v(w + 0.8, 0.8, d + 0.8), v(0, top + 0.4, 0), P.Burgundy)
	-- Entrance canopy and doors.
	b:block("OfficeDoor", v(2.6, 3.2, 0.3), v(0, 2.6, -d / 2 - 0.25), P.Navy, GLASS)
	b:block("OfficeCanopy", v(4.4, 0.4, 2), v(0, 4.4, -d / 2 - 1), accent)
	if level >= 5 then
		-- Rooftop logo: a gold film reel on a stand.
		local logo = b:sub(v(0, top + 0.8, 0))
		if Build.mesh(logo, "FilmReelLogo", CFrame.identity) then
			return
		end
		logo:block("LogoStand", v(1, 2, 1), v(0, 1, 0), P.Charcoal, METAL)
		logo:cylinder("Reel", 0.8, 6, CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(90), 0, 0), P.Gold, METAL)
		logo:cylinder("ReelHub", 1, 1.4, CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(90), 0, 0), P.Burgundy)
		for i = 0, 4 do
			local a = math.rad(i * 72 + 90)
			logo:cylinder("ReelHole", 1, 1.3, CFrame.new(1.8 * math.cos(a), 5 + 1.8 * math.sin(a), 0) * CFrame.Angles(math.rad(90), 0, 0), P.Navy)
		end
	elseif level >= 2 then
		b:block("RoofUnit", v(2.4, 1.4, 2.4), v(2, top + 1.5, 2), P.Steel, METAL)
		b:cylinder("Antenna", 4, 0.3, v(-2.5, top + 2.8, 2.5), P.Steel, METAL)
		b:ball("AntennaLight", 0.6, v(-2.5, top + 4.9, 2.5), P.Carpet, NEON)
	end
end

-- Billboard -------------------------------------------------------------------------------------

-- Tall billboard on two posts. Returns the board (put a SurfaceGui on its Front face).
function LotModels.billboard(b: Builder): BasePart
	for _, x in { -4.5, 4.5 } do
		b:block("BillboardFoot", v(1.8, 1, 1.8), v(x, 0.5, 0.4), P.Charcoal)
		b:block("BillboardPost", v(0.9, 12, 0.9), v(x, 7, 0.4), P.Steel, METAL)
	end
	b:block("Catwalk", v(13, 0.3, 1.6), v(0, 10.9, -0.6), P.Steel, METAL)
	b:block("BillboardBack", v(14, 9, 0.6), v(0, 15.5, 0.4), P.Burgundy)
	local board = b:block("Billboard", v(13, 8, 0.4), v(0, 15.5, 0), P.Navy)
	for _, x in { -4, 4 } do
		b:block("SpotArm", v(0.3, 0.3, 2), v(x, 20.3, -0.8), P.Charcoal, METAL)
		b:block("Spot", v(1.2, 0.8, 0.8), v(x, 20.3, -1.9), P.Light, NEON)
	end
	return board
end

-- Trophies and star pedestal --------------------------------------------------------------------

-- A gold trophy about 2.2 studs tall.
function LotModels.trophy(b: Builder)
	if Build.mesh(b, "TrophyGold", CFrame.identity, 2.2) then
		return
	end
	b:block("TrophyBase", v(1.2, 0.5, 1.2), v(0, 0.25, 0), P.Burgundy)
	b:cylinder("TrophyStem", 0.8, 0.35, v(0, 0.9, 0), P.Gold, METAL)
	b:cylinder("TrophyCup", 0.9, 1.1, v(0, 1.75, 0), P.Gold, METAL)
	b:cylinder("TrophyLip", 0.15, 1.3, v(0, 2.25, 0), P.Gold, METAL)
	for _, x in { -0.75, 0.75 } do
		b:block("TrophyHandle", v(0.2, 0.6, 0.2), v(x, 1.85, 0), P.Gold, METAL)
	end
end

-- Glass-topped trophy cabinet. Shows up to `shown` trophies.
function LotModels.trophyCase(b: Builder, shown: number)
	local w = 2 + shown * 1.6
	b:block("CaseBase", v(w, 1.6, 2.4), v(0, 0.8, 0), P.Wood)
	b:block("CaseTrim", v(w + 0.2, 0.3, 2.6), v(0, 1.65, 0), P.Burgundy)
	for i = 1, shown do
		LotModels.trophy(b:sub(v(-w / 2 + 1 + (i - 1) * 1.6 + 0.8, 1.8, 0)))
	end
end

-- Round pedestal for the lot's top star. `glow` is the rarity color. Top surface at y = 1.6.
function LotModels.pedestal(b: Builder, glow: Color3, rare: boolean): BasePart
	b:cylinder("PedestalBase", 0.6, 6, v(0, 0.3, 0), P.Burgundy)
	local ring = b:cylinder("PedestalRing", 0.4, 5.6, v(0, 0.8, 0), glow, NEON)
	b:cylinder("PedestalTop", 0.6, 5, v(0, 1.3, 0), P.Cream)
	if rare then
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 14
		light.Brightness = 2
		light.Parent = ring
	end
	return ring
end

return LotModels
