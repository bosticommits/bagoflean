--!strict
-- The film crews at work on the film sets (rules in Shared/FilmSets), shot over and over, take
-- after take:
--   Dusty Gulch  two scenes that take turns:
--                1 The showdown: the sheriff and the outlaw walk out, draw, and the outlaw falls.
--                2 The stunt: the outlaw fires at the stunt double on the hotel balcony, who flips
--                  off it onto the hay bales below and gets up to a thumbs up.
--   Moon Base    The first step: an astronaut climbs down from the lander, hops across the moon
--                and plants a flag, and an alien sneaks up behind for a surprise hello.
--   Jungle       The idol: an explorer climbs the temple steps and grabs the golden idol, a boulder
--                rolls out after him, and he dives clear just in time.
-- Each take: the clapper loader slates it ("Scene 1, take 3!") and snaps the clapperboard, the
-- director calls "ACTION!" through the megaphone, the actors play the scene, the director calls
-- "CUT!" and the crew claps. The Gulch's actors then walk to their marks for the other scene; on
-- the other sets the take rewinds, everyone running backwards to their first marks.
--
-- FilmScenes.frame(id, t) says where everyone is at time t (seconds; the game passes the server
-- clock, so every player sees the same take). It is pure numbers, so tests can play it outside
-- Roblox; src/client/FilmSetWorld.luau puts the Blender crew (CrewRig) in each pose. Positions are
-- in the set's own space (MapModels.FilmSets[...].frame): the way in from the gate runs along +Z
-- and the set's ground is at y = 0.2. Facings are degrees about Y: 0 faces -Z, 90 faces -X, -90
-- faces +X, 180 faces +Z.
local FilmScenes = {}

FilmScenes.TakeLength = 24 -- seconds per take
FilmScenes.Takes = 9 -- the take number counts up to this, then starts again at 1

export type Arm = { number } -- { swing forward (radians; pi/2 points ahead, pi straight up), out to the side }

export type Pose = {
	at: Vector3, -- the feet (in the set's space)
	yaw: number, -- degrees about Y: 0 faces -Z, 90 faces -X, -90 faces +X, 180 faces +Z
	tilt: number, -- leaning back (radians) about a point `pivot` studs above the feet; pi/2 lies flat
	pivot: number,
	legs: { number }, -- left, right: swing forward (radians)
	arms: { Arm }, -- left, right
	head: number, -- turn to the left (radians)
	hold: string?, -- the kit prop in the right hand (PropMegaphone, PropRevolver, PropClapper, ...)
	level: boolean?, -- hold the prop pointing straight ahead, whatever the arm does
	hidden: boolean?, -- off set (walked indoors)
}

export type Frame = {
	scene: number, -- the Gulch: 1 the showdown, 2 the stunt; 1 on the other sets
	take: number,
	time: number, -- seconds into the take
	poses: { [string]: Pose },
	stick: number, -- how far the clapperboard's top is open (radians)
	say: { [string]: string }, -- speech bubbles, by who says them
	shot: string?, -- who fires a shot this moment (a flash at their revolver's muzzle)
	things: { [string]: CFrame }, -- loose props standing on set (kit name: where), like a planted flag
}

-- A film set's crew, actors and gear.
-- `label` letters a director's chair's back, or any other kit model's Sign spot. `solid` says
-- whether players bump into it when the list is placed `loose` (TownSets.filmSetGear).
export type Gear = { kit: string, at: Vector3, yaw: number, label: string?, light: boolean?, solid: boolean? }

export type SetScenes = {
	cast: { string }, -- everyone on set, in the order CrewRig builds them
	things: { string }, -- loose props the scene may show (Frame.things)
	gear: { Gear }, -- what stands on set all the time (MapModels places it)
	centre: Vector3, -- the middle of the action
	frame: (t: number) -> Frame,
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

-- Where the crew stands on a set, and which ways the camera and the shot face.
type CrewMarks = {
	director: Vector3,
	clapperHome: Vector3,
	slate: Vector3,
	operator: Vector3,
	shotSide: number, -- facing the action (the way the camera points)
	cameraSide: number, -- facing the camera
	rewind: boolean?, -- the director calls a rewind after the cut
}

-- Dusty Gulch: the camera stands on the east side of the street (+X) and films across it, toward
-- the hotel (-X).
local CAMERA_SIDE = -90 -- facing the camera (+X)
local SHOT_SIDE = 90 -- facing the shot (-X)

local GULCH_CREW: CrewMarks = {
	director = v(10.6, GROUND, 106.8),
	clapperHome = v(10.4, GROUND, 118.6),
	slate = v(3, GROUND, 114),
	operator = v(10, GROUND, 111.4),
	shotSide = SHOT_SIDE,
	cameraSide = CAMERA_SIDE,
}

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

local function crew(marks: CrewMarks, cut: number, s: number, frame: Frame)
	local poses, say = frame.poses, frame.say
	local scene, take = frame.scene, frame.take
	local CLAPPER_HOME, SLATE_MARK, SHOT_SIDE, CAMERA_SIDE = marks.clapperHome, marks.slate, marks.shotSide, marks.cameraSide

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

	local director = pose(marks.director, SHOT_SIDE)
	breathe(director, s, 2)
	director.hold = "PropMegaphone"
	director.level = true
	local rewind = marks.rewind and s >= cut + 3.2 and s < cut + 4.8
	if (s >= 4.2 and s < 5.8) or (s >= cut and s < cut + 1.6) or rewind then
		director.arms[2] = { 1.55, 0.05 }
		say.Director = if rewind then "Rewind! From the top!" elseif s < cut then "ACTION!" else "CUT! Print it!"
	else
		director.arms[2] = { 0.5, 0.15 }
	end

	local operator = pose(marks.operator, SHOT_SIDE)
	operator.arms = { { 1.2, -0.25 }, { 1.2, -0.25 } } -- hands on the camera
	operator.head = math.sin(s * 0.4) * 0.1

	for _, p in { clapper, operator } do
		if s >= cut + 1 and s < cut + 3 then
			clap(p, s)
		end
	end
	if s >= cut + 1.6 and s < cut + 3 and not rewind then
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

-- Dusty Gulch's frame.
local function gulch(t: number): Frame
	local n = math.floor(t / FilmScenes.TakeLength)
	local s = t - n * FilmScenes.TakeLength
	local scene = n % 2 + 1
	local take = (n // 2) % FilmScenes.Takes + 1
	local frame: Frame = { scene = scene, take = take, time = s, poses = {}, stick = 0, say = {}, things = {} }
	crew(GULCH_CREW, CUT[scene], s, frame)
	if scene == 1 then
		showdown(s, frame)
	else
		stuntScene(s, frame)
	end
	return frame
end

-- Moon Base: The first step --------------------------------------------------------------------
-- The camera stands near the gate and films toward the painted space backdrop at the far end
-- (+Z), so players walking in see the crew from behind and the scene beyond them.

local MOON_GEAR: { Gear } = {
	{ kit = "SpaceBackdrop", at = v(0, 0.2, 104), yaw = 0 },
	{ kit = "MoonRocket", at = v(38, 0, 86), yaw = 0 },
	{ kit = "MoonLander", at = v(-8, 0.2, 76), yaw = 0 },
	{ kit = "MoonDome", at = v(-34, 0, 88), yaw = 0 },
	{ kit = "MoonBuggy", at = v(26, 0.2, 68), yaw = -30 },
	{ kit = "MoonCrater", at = v(32, 0.2, 34), yaw = 0 },
	{ kit = "MoonCrater", at = v(-24, 0.2, 58), yaw = 40 },
	{ kit = "MoonRock", at = v(16, 0.2, 80), yaw = 20 },
	{ kit = "MoonRock", at = v(-44, 0.2, 66), yaw = 140 },
	{ kit = "MoonRock", at = v(36, 0.2, 50), yaw = 260 },
	{ kit = "CameraCrane", at = v(0, 0.2, 40), yaw = 180 },
	{ kit = "DirectorChair", at = v(-9, 0.2, 37), yaw = 180, label = "DIRECTOR" },
	{ kit = "LightStand", at = v(-13, 0.2, 47), yaw = 200 },
	{ kit = "LightStand", at = v(13, 0.2, 47), yaw = 160 },
}

local MOON_CREW: CrewMarks = {
	director = v(-6.5, GROUND, 40),
	clapperHome = v(7.5, GROUND, 40),
	slate = v(0, GROUND, 53),
	operator = v(2.6, GROUND, 37),
	shotSide = 180,
	cameraSide = 0,
	rewind = true,
}

local MOON_CUT = 18.6
local PORCH = v(-8, 6.25, 72.6) -- the lander's porch, where the astronaut waits
local LADDER_TOP = v(-8, 6.25, 71.4)
local LADDER_FOOT = v(-8, GROUND, 71.4)
local FLAG_SPOT = v(-0.5, GROUND, 62)
local FLAG_PLANTED = CFrame.new(0.9, GROUND, 61) * CFrame.Angles(math.pi, 0, 0)
local ALIEN_HIDE = v(16, GROUND, 83.5)
local ALIEN_BEHIND = v(0.2, GROUND, 64.4)

-- The action's own clock: plays forward until the cut, holds, then runs backwards to the start
-- in the last seconds of the take (the rewind), so the next take starts from the first marks.
local function rewound(s: number, cut: number, from: number): number
	local back = cut + 3.2
	if s < back then
		return math.min(s, cut)
	end
	return cut - (s - back) / (FilmScenes.TakeLength - back) * (cut - from)
end

local function moonActors(a: number, s: number, frame: Frame)
	local poses, say = frame.poses, frame.say

	-- The astronaut.
	local astro: Pose
	if a < 5 then
		astro = pose(PORCH, turn(0, 180, smooth(span(a, 4.6, 5))))
		breathe(astro, s, 6)
	elseif a < 7.4 then
		-- Down the ladder, facing it, hand over hand.
		local u = span(a, 5, 7.4)
		local from = if u < 0.1 then PORCH:Lerp(LADDER_TOP, u / 0.1) else LADDER_TOP:Lerp(LADDER_FOOT, (u - 0.1) / 0.9)
		astro = pose(from, 180)
		local rung = math.sin(u * math.pi * 6)
		astro.arms = { { 2.5 + rung * 0.3, 0 }, { 2.5 - rung * 0.3, 0 } }
		astro.legs = { 0.6 * math.max(rung, 0), 0.6 * math.max(-rung, 0) }
	elseif a < 7.9 then
		astro = pose(LADDER_FOOT, turn(180, 0, smooth(span(a, 7.4, 7.9))))
	elseif a < 11 then
		-- Three slow, floaty moon hops.
		local u = span(a, 7.9, 11)
		local hop = math.abs(math.sin(u * math.pi * 3))
		astro = pose(LADDER_FOOT:Lerp(FLAG_SPOT, u) + v(0, 1.8 * hop, 0), facing(LADDER_FOOT, FLAG_SPOT))
		astro.arms = { { 0.5, 0.7 }, { 0.5, 0.7 } }
		astro.legs = { 0.5 * hop, 0.3 * hop }
	else
		astro = pose(FLAG_SPOT, if a < 16.2 then 0 else turn(0, 180, smooth(span(a, 16.2, 16.6))))
		if a < 11.6 then
			astro.hold = "PropFlag"
			astro.arms[2] = { 3.0 * smooth(span(a, 11, 11.3)), 0.1 }
		elseif a < 12 then
			astro.hold = if a < 11.8 then "PropFlag" else nil
			astro.arms[2] = { 3.0 - 1.8 * smooth(span(a, 11.6, 11.8)), 0.1 }
		elseif a < 13.4 then
			astro.arms[2] = { 2.6, -0.5 } -- a salute
		elseif a < 16.6 then
			breathe(astro, s, 6)
			astro.head = -0.4 -- admiring the flag
		elseif a < 17.6 then
			local u = span(a, 16.6, 17.6)
			astro.at += v(0, 3 * math.sin(u * math.pi), 0)
			astro.arms = { { 3.0, 0.5 }, { 3.0, 0.5 } }
			astro.legs = { 0.4, 0.2 }
		else
			astro.arms[2] = { 2.9, 0.4 + math.sin(a * 9) * 0.3 }
		end
	end
	if a >= 7.6 and a < 9.4 then
		say.Astronaut = "One small step..."
	elseif a >= 16.6 and a < 17.8 then
		say.Astronaut = "AAH!"
	end
	if a >= 11.8 then
		frame.things.PropFlag = FLAG_PLANTED
	end

	-- The alien: hiding behind a moon rock, peeking, then sneaking up for a hello.
	local alien = follow({
		{ t = 0, at = ALIEN_HIDE, yaw = 0 },
		{ t = 12.4, at = ALIEN_HIDE, yaw = 0 },
		{ t = 15.4, at = ALIEN_BEHIND, yaw = 0 },
	}, a)
	if a < 12.4 then
		alien.head = if a > 9 then math.sin(a * 2) * 0.6 else 0
		breathe(alien, s, 7)
	elseif a < 15.4 then
		alien.arms = { { 1.0, 0.5 }, { 1.0, 0.5 } } -- tiptoe
	elseif a < 16.6 then
		alien.arms[2] = { 1.5, 0.1 } -- tap, tap
		say.Alien = "Hello!"
	elseif a < 17.6 then
		local u = span(a, 16.6, 17.6)
		alien.at += v(0, 2.5 * math.sin(u * math.pi), 0)
		alien.arms = { { 2.9, 0.6 }, { 2.9, 0.6 } }
	else
		local wave = math.sin(a * 9) * 0.3
		alien.arms = { { 2.9, 0.4 - wave }, { 2.9, 0.4 + wave } }
	end

	if s >= MOON_CUT + 1 and s < MOON_CUT + 3 then
		clap(astro, s)
		clap(alien, s)
		astro.hold = nil
	end
	poses.Astronaut, poses.Alien = astro, alien
end

local function moon(t: number): Frame
	local n = math.floor(t / FilmScenes.TakeLength)
	local s = t - n * FilmScenes.TakeLength
	local frame: Frame = { scene = 1, take = n % FilmScenes.Takes + 1, time = s, poses = {}, stick = 0, say = {}, things = {} }
	crew(MOON_CREW, MOON_CUT, s, frame)
	moonActors(rewound(s, MOON_CUT, 4.6), s, frame)
	return frame
end

-- Jungle Temple: The idol --------------------------------------------------------------------------
-- The camera stands in the clearing and films the temple steps (+Z). The temple's steps run from
-- z = 79 on the ground up to z = 89.5 at the top platform, 16 up (art/blender/jungle_kit.py).

local JUNGLE_GEAR: { Gear } = {
	{ kit = "JungleTemple", at = v(24, 0.2, 96), yaw = 0 },
	{ kit = "IdolPedestal", at = v(24, 16.2, 92.5), yaw = 0 },
	{ kit = "JungleTorch", at = v(18.5, 0.2, 77.5), yaw = 0, light = true },
	{ kit = "JungleTorch", at = v(29.5, 0.2, 77.5), yaw = 0, light = true },
	{ kit = "JungleTree", at = v(-14, 0.2, 92), yaw = 0 },
	{ kit = "JungleTree", at = v(62, 0.2, 96), yaw = 120 },
	{ kit = "JungleTree", at = v(-24, 0.2, 38), yaw = 60 },
	{ kit = "JungleTree", at = v(72, 0.2, 40), yaw = 200 },
	{ kit = "JunglePalm", at = v(0, 0.2, 72), yaw = 40 },
	{ kit = "JunglePalm", at = v(48, 0.2, 72), yaw = 200 },
	{ kit = "JunglePalm", at = v(-28, 0.2, 66), yaw = 100 },
	{ kit = "JunglePalm", at = v(74, 0.2, 66), yaw = 300 },
	{ kit = "JungleFern", at = v(8, 0.2, 82), yaw = 0 },
	{ kit = "JungleFern", at = v(40, 0.2, 84), yaw = 70 },
	{ kit = "JungleFern", at = v(-6, 0.2, 58), yaw = 30 },
	{ kit = "JungleFern", at = v(54, 0.2, 56), yaw = 150 },
	{ kit = "JungleFern", at = v(10, 0.2, 30), yaw = 90 },
	{ kit = "JungleFern", at = v(38, 0.2, 28), yaw = 10 },
	{ kit = "JungleRuin", at = v(-4, 0.2, 80), yaw = 15 },
	{ kit = "JungleRuin", at = v(52, 0.2, 86), yaw = -20 },
	{ kit = "CameraCrane", at = v(24, 0.2, 50), yaw = 180 },
	{ kit = "DirectorChair", at = v(14, 0.2, 47), yaw = 180, label = "DIRECTOR" },
	{ kit = "LightStand", at = v(11, 0.2, 57), yaw = 200 },
	{ kit = "LightStand", at = v(37, 0.2, 57), yaw = 160 },
}

local JUNGLE_CREW: CrewMarks = {
	director = v(16.5, GROUND, 50),
	clapperHome = v(31, GROUND, 50),
	slate = v(24, GROUND, 62),
	operator = v(26.6, GROUND, 47),
	shotSide = 180,
	cameraSide = 0,
	rewind = true,
}

local JUNGLE_CUT = 17
local STEPS_FOOT, STEPS_TOP, TOP_Y = 79, 89.5, 16.2
local IDOL_ON_PEDESTAL = CFrame.new(24, TOP_Y + 1.6, 92.5) * CFrame.Angles(math.pi, 0, 0)
local BOULDER_R = 3.2
local DOOR_Z = 97.5 -- the boulder's middle when it shows in the doorway
local BOULDER_STOP = 66

-- The ground height on the temple steps at `z` (the ramp under them).
local function stepY(z: number): number
	return GROUND + (TOP_Y - GROUND) * math.clamp((z - STEPS_FOOT) / (STEPS_TOP - STEPS_FOOT), 0, 1)
end

local function onSteps(p: Pose)
	p.at = v(p.at.X, stepY(p.at.Z), p.at.Z)
end

-- The boulder's middle along its path: out of the doorway, over the edge, down the steps and
-- across the clearing, slowing to a stop just short of the camera.
local function boulderZ(a: number): number
	if a < 12.2 then
		return DOOR_Z + (STEPS_TOP - DOOR_Z) * span(a, 11, 12.2)
	elseif a < 13.2 then
		return STEPS_TOP + (STEPS_FOOT - STEPS_TOP) * span(a, 12.2, 13.2)
	end
	local u = span(a, 13.2, 14.8)
	return STEPS_FOOT + (BOULDER_STOP - STEPS_FOOT) * (1 - (1 - u) * (1 - u))
end

local function jungleActors(a: number, s: number, frame: Frame)
	local poses, say = frame.poses, frame.say

	-- The explorer.
	local explorer: Pose
	if a < 11.4 then
		explorer = follow({
			{ t = 0, at = v(22, GROUND, 75), yaw = 180 },
			{ t = 4.6, at = v(22, GROUND, 75), yaw = 180 },
			{ t = 5.4, at = v(24, GROUND, 77.5), yaw = 180 },
			{ t = 8.6, at = v(24, GROUND, 90.6), yaw = 180 },
		}, a)
		onSteps(explorer)
		if a < 4.6 then
			breathe(explorer, s, 8)
		elseif a >= 9.4 and a < 10 then
			explorer.arms[2] = { 1.3, 0 } -- reaching for the idol
		elseif a >= 10 then
			explorer.hold = "PropIdol"
			explorer.arms[2] = { 2.9, 0.2 }
		end
	elseif a < 13 then
		-- Turn and run down the steps, the boulder right behind.
		local u = span(a, 11.6, 13)
		explorer = pose(v(24, GROUND, 90.6):Lerp(v(24, GROUND, 78.2), u), turn(180, 0, smooth(span(a, 11.4, 11.7))))
		onSteps(explorer)
		local pump = math.sin(u * math.pi * 7) * 0.8
		explorer.legs = { pump, -pump }
		explorer.arms = { { -pump, 0.1 }, { 2.4, 0.2 } }
		explorer.hold = "PropIdol"
	else
		-- A dive to the side, face down, then up again with the idol held high.
		local u = span(a, 13, 13.6)
		explorer = pose(v(24, GROUND, 78.2):Lerp(v(31, GROUND, 74.5), u), -20)
		local down = if a < 15 then smooth(u) else 1 - smooth(span(a, 15, 15.8))
		explorer.tilt = -down * math.pi / 2
		explorer.at += v(0, 0.5 * math.sin(down * math.pi / 2) + (if a < 13.6 then 1.2 * math.sin(u * math.pi) else 0), 0)
		explorer.arms = { { 2.6 * down, 0.3 }, { 2.6 * down + (1 - down) * 2.9, 0.3 } }
		explorer.hold = "PropIdol"
		if a >= 15.8 then
			explorer.arms[2] = { 2.9, 0.2 }
		end
	end
	if a >= 10.2 and a < 11.4 then
		say.Explorer = "Got it!"
	elseif a >= 15.8 and a < 17 then
		say.Explorer = "Ta-da!"
	end
	if a < 10 then
		frame.things.PropIdol = IDOL_ON_PEDESTAL
	end

	-- The boulder.
	if a >= 11 then
		local z = boulderZ(a)
		local rolled = (DOOR_Z - z) / BOULDER_R
		frame.things.PropBoulder = CFrame.new(24, stepY(z) + BOULDER_R, z) * CFrame.Angles(-rolled, 0, 0)
	end

	-- The guide: holds the torch, worries, shouts and runs for cover.
	local guide = follow({
		{ t = 0, at = v(27.5, GROUND, 74), yaw = 180 },
		{ t = 11.4, at = v(27.5, GROUND, 74), yaw = 180 },
		{ t = 13.2, at = v(8, GROUND, 66), yaw = facing(v(27.5, 0, 74), v(8, 0, 66)) },
		{ t = 13.6, at = v(8, GROUND, 66), yaw = 160 },
	}, a)
	if a < 11.4 then
		guide.hold = "PropTorch"
		guide.arms[2] = { 1.9, 0 }
		guide.head = if a > 6 then math.sin(a * 3) * 0.4 else 0
	elseif a < 13.2 then
		guide.hold = "PropTorch"
		guide.arms[2] = { 2.4, 0.3 }
	elseif a < 16 then
		guide.arms = { { 2.9, -0.3 }, { 2.9, -0.3 } } -- cowering
		guide.tilt = -0.25
	else
		guide.arms = { { 2.8, 0.5 }, { 2.8, 0.5 } } -- cheering
	end
	if a >= 6 and a < 8 then
		say.Guide = "Careful, boss..."
	elseif a >= 11.2 and a < 12.6 then
		say.Guide = "RUN!!!"
	end

	if s >= JUNGLE_CUT + 1 and s < JUNGLE_CUT + 3 then
		clap(guide, s)
		guide.hold = nil
	end
	poses.Explorer, poses.Guide = explorer, guide
end

local function jungle(t: number): Frame
	local n = math.floor(t / FilmScenes.TakeLength)
	local s = t - n * FilmScenes.TakeLength
	local frame: Frame = { scene = 1, take = n % FilmScenes.Takes + 1, time = s, poses = {}, stick = 0, say = {}, things = {} }
	crew(JUNGLE_CREW, JUNGLE_CUT, s, frame)
	jungleActors(rewound(s, JUNGLE_CUT, 4.6), s, frame)
	return frame
end

-- The sets -------------------------------------------------------------------------------------

FilmScenes.Sets = table.freeze({
	Gulch = {
		cast = { "Director", "Clapper", "Operator", "Sheriff", "Outlaw", "Stunt" },
		things = {},
		gear = {
			{ kit = "CameraCrane", at = v(10, 0.2, 114), yaw = 90 },
			{ kit = "DirectorChair", at = v(13, 0.2, 106), yaw = 90, label = "DIRECTOR" },
			{ kit = "LightStand", at = v(9, 0.2, 122.5), yaw = 70 },
			-- The stunt double's landing, under the hotel balcony.
			{ kit = "HayBale", at = v(-7.7, 0.2, 114), yaw = 90 },
			{ kit = "HayBale", at = v(-10.3, 0.2, 114), yaw = 90 },
		},
		centre = v(0, 0, 114),
		frame = gulch,
	},
	MoonBase = {
		cast = { "Director", "Clapper", "Operator", "Astronaut", "Alien" },
		things = { "PropFlag" },
		gear = MOON_GEAR,
		centre = v(0, 0, 66),
		frame = moon,
	},
	Jungle = {
		cast = { "Director", "Clapper", "Operator", "Explorer", "Guide" },
		things = { "PropIdol", "PropBoulder" },
		gear = JUNGLE_GEAR,
		centre = v(24, 0, 76),
		frame = jungle,
	},
}) :: { [string]: SetScenes }

-- Where everyone is on set `id` at time `t`.
function FilmScenes.frame(id: string, t: number): Frame
	local set = FilmScenes.Sets[id]
	assert(set ~= nil, `no film set scenes called {id}`)
	return set.frame(t)
end

return FilmScenes
