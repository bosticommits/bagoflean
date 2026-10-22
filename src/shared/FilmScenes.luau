--!strict
-- The film crew's day on the Dusty Gulch film set: two scenes, shot over and over, take after take.
--   1 The showdown  the sheriff and the outlaw walk out, draw, and the outlaw falls.
--   2 The stunt     the outlaw fires at the stunt double on the hotel balcony, who flips off it
--                   onto the hay bales below and gets up to a thumbs up.
-- Each take: the clapper loader slates it ("Scene 1, take 3!") and snaps the clapperboard, the
-- director calls "ACTION!" through the megaphone, the actors play the scene, the director calls
-- "CUT!" and the crew claps; then the actors walk to their marks for the other scene.
--
-- FilmScenes.frame(t) says where everyone is at time t (seconds; the game passes the server clock,
-- so every player sees the same take). It is pure numbers, so tests can play it outside Roblox;
-- src/client/FilmSetWorld.luau puts the Blender crew (CrewRig) in each pose. Positions are in
-- Dusty Gulch's own space (MapModels.GulchFrame): the street runs along +Z from the welcome arch,
-- its ground is at y = 0.2 and the boardwalks at y = 0.8. The camera stands on the east side of
-- the street (+X) and films across it, toward the hotel (-X).
local FilmScenes = {}

-- The six people on set, in the order CrewRig builds them (each is a set of Blender pieces,
-- Crew<Who><Part>, from art/blender/crew_kit.py).
FilmScenes.Cast = { "Director", "Clapper", "Operator", "Sheriff", "Outlaw", "Stunt" }

FilmScenes.TakeLength = 24 -- seconds per take; the two scenes take turns
FilmScenes.Takes = 9 -- the take number counts up to this, then starts again at 1

-- Where the crew's gear stands (TownSets.westernTown places it): kit model, feet, facing (degrees
-- about Y: 0 faces -Z, 90 faces -X, -90 faces +X).
FilmScenes.Gear = {
	{ kit = "CameraCrane", at = Vector3.new(10, 0.2, 114), yaw = 90 },
	{ kit = "DirectorChair", at = Vector3.new(13, 0.2, 106), yaw = 90, label = "DIRECTOR" },
	{ kit = "LightStand", at = Vector3.new(9, 0.2, 122.5), yaw = 70 },
	-- The stunt double's landing, under the hotel balcony.
	{ kit = "HayBale", at = Vector3.new(-7.7, 0.2, 114), yaw = 90 },
	{ kit = "HayBale", at = Vector3.new(-10.3, 0.2, 114), yaw = 90 },
} :: { { kit: string, at: Vector3, yaw: number, label: string? } }

-- The middle of the action, and how far the set's area reaches round it (for tests and for when
-- FilmSetWorld starts animating).
FilmScenes.Centre = Vector3.new(0, 0, 114)

export type Arm = { number } -- { swing forward (radians; pi/2 points ahead, pi straight up), out to the side }

export type Pose = {
	at: Vector3, -- the feet (in Gulch space)
	yaw: number, -- degrees about Y: 0 faces -Z, 90 faces -X, -90 faces +X, 180 faces +Z
	tilt: number, -- leaning back (radians) about a point `pivot` studs above the feet; pi/2 lies flat
	pivot: number,
	legs: { number }, -- left, right: swing forward (radians)
	arms: { Arm }, -- left, right
	head: number, -- turn to the left (radians)
	hold: string?, -- the kit prop in the right hand (PropMegaphone, PropRevolver, PropClapper)
	level: boolean?, -- hold the prop pointing straight ahead, whatever the arm does
	hidden: boolean?, -- off set (walked indoors)
}

export type Frame = {
	scene: number, -- 1 the showdown, 2 the stunt
	take: number,
	time: number, -- seconds into the take
	poses: { [string]: Pose },
	stick: number, -- how far the clapperboard's top is open (radians)
	say: { [string]: string }, -- speech bubbles, by who says them
	shot: string?, -- who fires a shot this moment (a flash at their revolver's muzzle)
}

-- Helpers --------------------------------------------------------------------------------------

local function span(s: number, t0: number, t1: number): number
	return math.clamp((s - t0) / (t1 - t0), 0, 1)
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

local function turn(a: number, b: number, u: number): number
	local d = (b - a + 180) % 360 - 180
	return a + d * u
end

-- Facing from `from` toward `to` (degrees, as Pose.yaw).
local function facing(from: Vector3, to: Vector3): number
	local d = to - from
	return math.deg(math.atan2(-d.X, -d.Z))
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local REST: { Arm } = { { 0, 0.08 }, { 0, 0.08 } }

local function pose(at: Vector3, yaw: number): Pose
	return {
		at = at,
		yaw = yaw,
		tilt = 0,
		pivot = 0,
		legs = { 0, 0 },
		arms = { { REST[1][1], REST[1][2] }, { REST[2][1], REST[2][2] } },
		head = 0,
	}
end

-- A path of marks: at time `t` the person stands at `at` facing `yaw`. Between two marks in
-- different places they walk (turning to face the way they go, then to the next mark's facing);
-- between two marks in the same place they turn on the spot.
type Mark = { t: number, at: Vector3, yaw: number }

local STRIDE = 1.9 -- leg swing phase per stud walked

local function follow(marks: { Mark }, s: number): Pose
	if s <= marks[1].t then
		return pose(marks[1].at, marks[1].yaw)
	end
	for i = 1, #marks - 1 do
		local a, b = marks[i], marks[i + 1]
		if s < b.t then
			local u = span(s, a.t, b.t)
			if (b.at - a.at).Magnitude < 0.01 then
				return pose(a.at, turn(a.yaw, b.yaw, smooth(u)))
			end
			local at = a.at:Lerp(b.at, u)
			local dir = facing(a.at, b.at)
			local length = b.t - a.t
			local yaw = dir
			local into, outOf = s - a.t, b.t - s
			if into < 0.3 then
				yaw = turn(a.yaw, dir, smooth(math.min(1, into / math.min(0.3, length / 2))))
			elseif outOf < 0.3 then
				yaw = turn(b.yaw, dir, smooth(math.min(1, outOf / math.min(0.3, length / 2))))
			end
			local p = pose(at, yaw)
			local phase = (at - a.at).Magnitude * STRIDE
			local swing = math.sin(phase) * 0.6
			p.legs = { swing, -swing }
			p.arms = { { -swing * 0.8, 0.1 }, { swing * 0.8, 0.1 } }
			return p
		end
	end
	local last = marks[#marks]
	return pose(last.at, last.yaw)
end

-- Gentle breathing so nobody stands frozen: arms sway a little.
local function breathe(p: Pose, s: number, seed: number)
	local sway = math.sin(s * 1.7 + seed) * 0.05
	p.arms[1][1] += sway
	p.arms[2][1] -= sway
	p.head += math.sin(s * 0.6 + seed * 2) * 0.15
end

-- Hands together, apart, together: applause.
local function clap(p: Pose, s: number)
	local beat = math.abs(math.sin(s * 11))
	p.arms[1] = { 1.25, -0.15 + beat * 0.45 }
	p.arms[2] = { 1.25, -0.15 + beat * 0.45 }
end

local function thumbsUp(p: Pose)
	p.arms[2] = { 2.75, 0.2 }
end

-- Marks ------------------------------------------------------------------------------------------

local GROUND, BOARDWALK, BALCONY = 0.2, 0.8, 10 -- feet heights: the street, boardwalks, the hotel balcony

local CAMERA_SIDE = -90 -- facing the camera (+X)
local SHOT_SIDE = 90 -- facing the shot (-X)

local DIRECTOR_MARK = v(10.6, GROUND, 106.8)
local CLAPPER_HOME = v(10.4, GROUND, 118.6)
local SLATE_MARK = v(3, GROUND, 114)
local OPERATOR_MARK = v(10, GROUND, 111.4)

-- Where the actors stand when each scene starts.
local SHERIFF_START = { v(-5, GROUND, 102), v(3, GROUND, 128) }
local SHERIFF_START_YAW = { 180, SHOT_SIDE }
local OUTLAW_START = { v(-5, GROUND, 126), v(-2, GROUND, 108) }
local STUNT_BALCONY = v(-18, BALCONY, 114)
local STUNT_HIP_AIR = 2.8 -- the stunt double flips about his hips, 2.8 studs above his feet
local STUNT_JUMP_FROM = v(-16.5, BALCONY, 114)
local STUNT_LAND_HIPS = v(-8.5, 2.8, 114) -- lying on the hay, his hips over the bales' middle
local STUNT_FEET_LYING = v(-5.7, 2.8, 114) -- where his feet are then
local STUNT_HOP_DOWN = v(-4.5, GROUND, 114)
local HOTEL_DOOR = v(-18.8, BOARDWALK, 114)

local OUTLAW_AIM_AT = v(-16.5, BALCONY + 4, 114)

-- When each scene's director calls cut.
local CUT = { 14.5, 11.5 }

-- The crew -------------------------------------------------------------------------------------

local function crew(scene: number, take: number, s: number, frame: Frame)
	local poses, say = frame.poses, frame.say
	local cut = CUT[scene]

	-- The clapper loader: out to the slate mark, slates the take and snaps it, back again.
	local clapper = follow({
		{ t = 0, at = CLAPPER_HOME, yaw = SHOT_SIDE },
		{ t = 2, at = SLATE_MARK, yaw = CAMERA_SIDE },
		{ t = 3.8, at = SLATE_MARK, yaw = CAMERA_SIDE },
		{ t = 6, at = CLAPPER_HOME, yaw = SHOT_SIDE },
	}, s)
	if s >= 1.6 and s < 3.9 then
		clapper.hold = "PropClapper"
		clapper.arms[2] = { 1.5, 0.1 }
		clapper.arms[1] = { 1.2, -0.35 } -- the other hand on the stick
		frame.stick = if s < 3.6 then 0.55 else 0.55 * (1 - span(s, 3.6, 3.68))
		if s >= 2.1 and s < 3.6 then
			say.Clapper = `Scene {scene}, take {take}!`
		end
	else
		breathe(clapper, s, 1)
	end

	local director = pose(DIRECTOR_MARK, SHOT_SIDE)
	breathe(director, s, 2)
	director.hold = "PropMegaphone"
	director.level = true
	if (s >= 4.2 and s < 5.8) or (s >= cut and s < cut + 1.6) then
		director.arms[2] = { 1.55, 0.05 }
		say.Director = if s < cut then "ACTION!" else "CUT! Print it!"
	else
		director.arms[2] = { 0.5, 0.15 }
	end

	local operator = pose(OPERATOR_MARK, SHOT_SIDE)
	operator.arms = { { 1.2, -0.25 }, { 1.2, -0.25 } } -- hands on the camera
	operator.head = math.sin(s * 0.4) * 0.1

	for _, p in { clapper, operator } do
		if s >= cut + 1 and s < cut + 3 then
			clap(p, s)
		end
	end
	if s >= cut + 1.6 and s < cut + 3 then
		director.hold = nil
		clap(director, s)
	end

	poses.Clapper, poses.Director, poses.Operator = clapper, director, operator
end

-- Scene 1: the showdown ----------------------------------------------------------------------------

local function showdown(s: number, frame: Frame)
	local poses, say = frame.poses, frame.say
	local cut = CUT[1]

	local sheriff = follow({
		{ t = 0, at = SHERIFF_START[1], yaw = SHERIFF_START_YAW[1] },
		{ t = 4.8, at = SHERIFF_START[1], yaw = 180 },
		{ t = 8.6, at = v(-5, GROUND, 108), yaw = 180 },
		{ t = 19, at = v(-5, GROUND, 108), yaw = 180 },
		{ t = 23, at = SHERIFF_START[2], yaw = SHERIFF_START_YAW[2] },
	}, s)
	local outlaw = follow({
		{ t = 0, at = OUTLAW_START[1], yaw = 0 },
		{ t = 4.8, at = OUTLAW_START[1], yaw = 0 },
		{ t = 8.6, at = v(-5, GROUND, 120), yaw = 0 },
		{ t = 19.4, at = v(-5, GROUND, 120), yaw = 0 },
		{ t = 23.2, at = OUTLAW_START[2], yaw = facing(OUTLAW_START[2], OUTLAW_AIM_AT) },
	}, s)

	-- Hands hover over the holsters, then the draw: the sheriff is quicker.
	if s >= 8.6 and s < 10 then
		sheriff.arms[2] = { -0.15, 0.35 }
		outlaw.arms[2] = { -0.15, 0.35 }
	end
	if s >= 10 and s < 12.6 then
		sheriff.hold = "PropRevolver"
		sheriff.arms[2] = { 1.57 * smooth(span(s, 10, 10.2)), 0 }
	end
	if s >= 10.15 and s < 10.6 then
		outlaw.hold = "PropRevolver"
		outlaw.arms[2] = { 1.2 * smooth(span(s, 10.15, 10.4)), 0 }
	end
	if s >= 10.5 and s < 10.65 then
		frame.shot = "Sheriff"
	end
	if s >= 10.5 and s < 11.6 then
		say.Sheriff = "BANG!"
	end

	-- The outlaw falls flat on his back, lies still, then gets up for the cut.
	if s >= 10.6 and s < 17.6 then
		local down = if s < 16.6 then span(s, 10.6, 11.3) ^ 2 else 1 - smooth(span(s, 16.6, 17.6))
		outlaw.tilt = down * math.pi / 2
		outlaw.at += v(0, 0.5 * math.sin(outlaw.tilt), 0)
		outlaw.arms = { { 0.4 * down, 0.9 * down }, { 0.4 * down, 0.9 * down } }
		outlaw.legs = { 0.15 * down, -0.1 * down }
	end
	if s >= 17.6 and s < 19.2 then
		thumbsUp(outlaw)
		say.Outlaw = "How was that?"
	end
	if s >= 12.6 and s < 13.6 then
		sheriff.arms[1] = { 2.9, 0.3 } -- tips his hat
	end
	if s >= cut + 1 and s < cut + 3 then
		clap(sheriff, s)
	end
	if s < 4.8 or s >= 19 then
		breathe(sheriff, s, 3)
	end

	-- The stunt double waits on the balcony for his scene, watching.
	local stunt = pose(STUNT_BALCONY, CAMERA_SIDE)
	breathe(stunt, s, 5)

	poses.Sheriff, poses.Outlaw, poses.Stunt = sheriff, outlaw, stunt
end

-- Scene 2: the stunt -------------------------------------------------------------------------------

local function stuntScene(s: number, frame: Frame)
	local poses, say = frame.poses, frame.say
	local cut = CUT[2]
	local aim = facing(OUTLAW_START[2], OUTLAW_AIM_AT)

	local sheriff = follow({
		{ t = 0, at = SHERIFF_START[2], yaw = SHERIFF_START_YAW[2] },
		{ t = 18.5, at = SHERIFF_START[2], yaw = SHERIFF_START_YAW[2] },
		{ t = 23, at = SHERIFF_START[1], yaw = SHERIFF_START_YAW[1] },
	}, s)
	if s < 18.5 then
		breathe(sheriff, s, 3)
	end
	local outlaw = follow({
		{ t = 0, at = OUTLAW_START[2], yaw = aim },
		{ t = 17.8, at = OUTLAW_START[2], yaw = aim },
		{ t = 23.2, at = OUTLAW_START[1], yaw = 0 },
	}, s)
	if s >= 4.9 and s < 7.6 then
		outlaw.hold = "PropRevolver"
		outlaw.arms[2] = { 2.1 * smooth(span(s, 4.9, 5.2)), 0 } -- aimed up at the balcony
	elseif s < 4.9 then
		breathe(outlaw, s, 4)
	end
	if s >= 6 and s < 6.15 then
		frame.shot = "Outlaw"
	end
	if s >= 6 and s < 7 then
		say.Outlaw = "BANG!"
	end
	for _, p in { sheriff, outlaw } do
		if s >= cut + 1 and s < cut + 3 then
			clap(p, s)
		end
	end

	-- The stunt double: two steps to the rail, the hit, a flip off the balcony onto the hay, a
	-- moment lying still, then up, down off the bales, a thumbs up, and off indoors.
	local stunt: Pose
	if s < 6.2 then
		stunt = follow({
			{ t = 0, at = STUNT_BALCONY, yaw = CAMERA_SIDE },
			{ t = 4.6, at = STUNT_BALCONY, yaw = CAMERA_SIDE },
			{ t = 5.4, at = STUNT_JUMP_FROM, yaw = CAMERA_SIDE },
		}, s)
		if s < 4.6 then
			breathe(stunt, s, 5)
		end
		if s >= 6 then
			stunt.arms = { { 0.6, 1.2 }, { 0.6, 1.2 } } -- hit!
		end
	elseif s < 7.3 then
		-- In the air: his hips fly a curve over the rail and down to the bales while he turns a
		-- back flip and a quarter, landing on his back.
		local u = span(s, 6.2, 7.3)
		local fromHips = STUNT_JUMP_FROM + v(0, STUNT_HIP_AIR, 0)
		local hips = fromHips:Lerp(STUNT_LAND_HIPS, u) + v(0, 34 * u * (1 - u), 0)
		stunt = pose(hips - v(0, STUNT_HIP_AIR, 0), CAMERA_SIDE)
		stunt.pivot = STUNT_HIP_AIR
		stunt.tilt = (2.5 * math.pi) * smooth(u)
		local flail = math.sin(s * 18) * 0.5
		stunt.arms = { { 1.4 + flail, 1.1 }, { 1.4 - flail, 1.1 } }
		stunt.legs = { 0.8 * math.sin(u * math.pi), 0.5 * math.sin(u * math.pi) }
	elseif s < 9.8 then
		-- Lying on the hay, then sitting up and standing on the bales' edge.
		stunt = pose(STUNT_FEET_LYING, CAMERA_SIDE)
		stunt.tilt = (math.pi / 2) * (1 - smooth(span(s, 9, 9.8)))
		stunt.arms = { { 0.3, 0.8 }, { 0.3, 0.8 } }
	elseif s < 10.2 then
		-- A hop down to the street.
		local u = span(s, 9.8, 10.2)
		stunt = pose(STUNT_FEET_LYING:Lerp(STUNT_HOP_DOWN, u) + v(0, 2.4 * u * (1 - u), 0), CAMERA_SIDE)
		stunt.arms = { { 0.3, 0.5 }, { 0.3, 0.5 } }
	else
		stunt = follow({
			{ t = 10.2, at = STUNT_HOP_DOWN, yaw = CAMERA_SIDE },
			{ t = 14.4, at = STUNT_HOP_DOWN, yaw = CAMERA_SIDE },
			{ t = 15, at = STUNT_HOP_DOWN, yaw = SHOT_SIDE },
			{ t = 15.8, at = v(-6, GROUND, 116.5), yaw = SHOT_SIDE },
			{ t = 18.4, at = v(-13.8, GROUND, 116.5), yaw = SHOT_SIDE },
			{ t = 19.2, at = HOTEL_DOOR, yaw = SHOT_SIDE },
		}, s)
		if stunt.at.X < -14 then
			stunt.at = v(stunt.at.X, BOARDWALK, stunt.at.Z) -- up on the hotel's boardwalk
		end
		if s < 11.6 then
			thumbsUp(stunt)
			say.Stunt = "Nailed it!"
		elseif s >= cut + 1 and s < cut + 3 then
			clap(stunt, s)
		end
		stunt.hidden = s >= 19.2
	end

	poses.Sheriff, poses.Outlaw, poses.Stunt = sheriff, outlaw, stunt
end

-- The frame ------------------------------------------------------------------------------------

function FilmScenes.frame(t: number): Frame
	local n = math.floor(t / FilmScenes.TakeLength)
	local s = t - n * FilmScenes.TakeLength
	local scene = n % 2 + 1
	local take = (n // 2) % FilmScenes.Takes + 1
	local frame: Frame = { scene = scene, take = take, time = s, poses = {}, stick = 0, say = {} }
	crew(scene, take, s, frame)
	if scene == 1 then
		showdown(s, frame)
	else
		stuntScene(s, frame)
	end
	return frame
end

return FilmScenes
