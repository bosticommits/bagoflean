--!strict
-- The film crews at work on the film sets (rules in Shared/FilmSets), shooting take after take.
-- Every set has the same crew: the director (megaphone), the camera operator riding the camera
-- dolly (a cart on a short track carrying a crane arm with the camera at its tip), the clapper
-- loader, the boom operator (the mic on a long pole held over the actors), the lighting tech
-- (tweaks a lamp) and the make-up artist (touches up an actor between takes), plus the actors:
--   Dusty Gulch  two scenes, three takes each:
--                1 The showdown: the sheriff and the outlaw walk out, draw, and the outlaw falls.
--                2 The stunt: the outlaw fires at the stunt double on the hotel balcony, who flips
--                  off it onto the hay bales below and gets up to a thumbs up.
--   Moon Base    The first step: an astronaut climbs down from the lander, waves to the camera,
--                bounds across the moon in slow low-gravity leaps and plants the flag two-handed;
--                an alien peeks from behind a foam rock and tiptoes up in stages (freezing when he
--                half turns), taps his shoulder, they both jump, then shake hands and wave.
--   Jungle       The idol: an explorer creeps up the temple steps, ducks a trap's dart, swaps the
--                golden idol for a bag of sand, and in the silence after, the temple rumbles: a
--                boulder rolls out, chases him down the steps and across the clearing, and he
--                dives clear, dusts himself off and holds the idol high.
--
-- The loop. Each set plays a fixed cycle of slots: for each scene a rehearsal (the actors walk
-- their marks at half pace while the director explains), then three takes. A take slot:
--   0.3   the director calls "Quiet on set!" ("Places everyone!" and a wave for the set's owner)
--   ~3    the clapper loader walks out in front of the camera and slates "Scene X, take Y!"
--   5.0   the clapperboard snaps shut, and the loader walks back
--   5.6   the director calls "ACTION!" through the megaphone; the actors start at 6.2
--         the take plays, the dolly rolls and the crane rises, the boom follows the actors
--   cut   "CUT! Print it!", the crew claps and confetti pops. Take 2, 5 and 8 is a blooper
--         instead: an actor stumbles, forgets the line or gets the giggles, and the director
--         calls "CUT!" early
--         then notes (the director walks over to the actors and explains), and the reset: the
--         actors walk back to their marks, carrying props back (the flag, the idol, the
--         boulder), the dolly rolls back, the make-up artist touches up an actor and the
--         lighting tech tweaks the lamp. When everyone stands on their marks, the next slot
--         starts. Nothing ever jumps: every move is a walk, a turn or an eased gesture.
-- Everyone walks with planted feet (the stride matches the speed, so a foot that bears weight
-- stays put), turns on the spot before walking off, sways and bobs with each step and breathes
-- while standing.
--
-- FilmScenes.frame(id, t, cue) says where everyone is at time t (seconds; the game passes the
-- server clock, so every player sees the same take). It is pure numbers, so tests can play it
-- outside Roblox; src/client/FilmSetWorld.luau puts the Blender crew (CrewRig) in each pose.
-- `cue` (FilmScenes.cue) is how the set's owner steers the crew: walking in, or calling "Action!"
-- at the clapper. A cue never jumps the clock: it ends the current take early at the next moment
-- where everyone stands still (or waits for the current slot to end), and the timeline carries on
-- from there with the next take, greeting the owner. FilmSetService works the cue out on the
-- server and publishes it, so every client plays the same.
--
-- Positions are in the set's own space (MapModels.FilmSets[...].frame): the way in from the gate
-- runs along +Z and the set's ground is at y = 0.2. Facings are degrees about Y: 0 faces -Z, 90
-- faces -X, -90 faces +X, 180 faces +Z. Each set's crew marks are in one table (GULCH, MOON,
-- JUNGLE below), easy to move when a set is rearranged.
local FilmScenes = {}

-- Body sizes in studs (CrewRig builds the puppets to them, art/blender/crew_kit.py draws them):
-- the hips 2 up and the legs 2 long, the shoulders 1.75 above the hips and 1.2 out, the neck 2.1
-- above the hips; a held prop's grip is 1.6 down the arm.
FilmScenes.Body = table.freeze({
	hips = 2,
	hipOut = 0.45,
	leg = 2,
	shoulder = Vector3.new(1.2, 1.75, 0),
	neck = 2.1,
	grip = 1.6,
})
local HIPS, LEG, GRIP = 2, 2, 1.6
local SHOULDER_X, SHOULDER_Y = 1.2, 1.75

-- The sound slot (Shared/Sounds) each moment plays.
FilmScenes.BeatSounds = table.freeze({
	places = "FilmPlaces", -- "Places everyone!" for the set's owner
	snap = "FilmClapper", -- the clapperboard snaps shut
	action = "FilmAction", -- "ACTION!"
	cut = "FilmCut", -- "CUT!"
	cheer = "FilmApplause", -- a clean take: the crew claps and confetti pops
})

export type Arm = { number } -- { swing forward (radians; pi/2 points ahead, pi straight up), out to the side }

export type Pose = {
	at: Vector3, -- the feet (in the set's space)
	yaw: number, -- degrees about Y: 0 faces -Z, 90 faces -X, -90 faces +X, 180 faces +Z
	tilt: number, -- leaning back (radians) about a point `pivot` studs above the feet; pi/2 lies flat
	pivot: number,
	legs: { number }, -- left, right: swing forward (radians)
	arms: { Arm }, -- left, right
	head: number, -- turn to the left (radians)
	nod: number, -- head tipped up (radians)
	twist: number, -- the body above the hips turned (radians; + brings the right shoulder forward)
	roll: number, -- the body above the hips leaning to the right (radians)
	lean: number, -- the body above the hips leaning forward (radians)
	bob: number, -- the body above the hips raised (studs), for breathing
	hold: string?, -- the kit prop in the right hand (PropMegaphone, PropRevolver, PropClapper, ...)
	level: boolean?, -- hold the prop pointing straight ahead, whatever the arm does
	aim: Vector3?, -- point the held prop at this spot (the boom pole)
	hidden: boolean?, -- off set (walked indoors)
	walking: boolean?, -- mid-stride: the foot on the ground is planted (tests check it stays put)
	plant: number?, -- which foot bears the weight mid-stride (1 left, 2 right)
	ride: boolean?, -- carried by something else (the operator on the dolly)
}

export type Frame = {
	scene: number, -- the scene being shot (the Gulch has two)
	take: number,
	time: number, -- seconds into the slot
	phase: string, -- "rehearsal" or "take"
	poses: { [string]: Pose },
	stick: number, -- how far the clapperboard's top is open (radians)
	say: { [string]: string }, -- speech bubbles, by who says them
	shot: string?, -- who fires a shot this moment (a flash at their revolver's muzzle)
	things: { [string]: CFrame }, -- loose props and the moving camera rig (kit name: where)
	beat: string?, -- the latest moment with a sound (FilmScenes.BeatSounds), within half a second of it
	beatAt: number, -- the server time of that moment (tells one beat from the next)
	beatWho: string?, -- who makes that sound
}

-- What stands on a set all the time (MapModels places it). `label` letters a director's chair's
-- back, or any other kit model's Sign spot. `solid` says whether players bump into it when the
-- list is placed `loose` (TownSets.filmSetGear).
export type Gear = { kit: string, at: Vector3, yaw: number, label: string?, light: boolean?, solid: boolean? }

-- The owner's cue (FilmScenes.cue): the clock runs on `old` until `from`, then on `new`. `slot` is
-- the start of the slot the cue arrived in; `cut` the story time it ends that take at (-1: it
-- doesn't); `press` whether the owner called "Action!" (not just walked in).
export type Cue = { at: number, from: number, slot: number, old: number, new: number, cut: number, press: boolean }

export type SetScenes = {
	cast: { string }, -- everyone on set, in the order CrewRig builds them
	props: { [string]: { string } }, -- the props each person can hold
	things: { string }, -- loose props and moving rig parts the scene may show (Frame.things)
	gear: { Gear },
	centre: Vector3, -- the middle of the action
	period: number, -- seconds before the cycle repeats
	frame: (t: number, cue: Cue?) -> Frame,
}

-- Helpers --------------------------------------------------------------------------------------

local function span(s: number, t0: number, t1: number): number
	return math.clamp((s - t0) / (t1 - t0), 0, 1)
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

-- 0 outside t0..t1; inside, eases up to 1 over `ramp` seconds, holds, and eases back down by t1.
local function window(s: number, t0: number, t1: number, ramp: number): number
	if s <= t0 or s >= t1 then
		return 0
	end
	local r = math.min(ramp, (t1 - t0) / 2)
	return smooth(math.min(1, (s - t0) / r, (t1 - s) / r))
end

local function turn(a: number, b: number, u: number): number
	local d = (b - a + 180) % 360 - 180
	return a + d * u
end

local function angleGap(a: number, b: number): number
	return math.abs((b - a + 180) % 360 - 180)
end

-- Facing from `from` toward `to` (degrees, as Pose.yaw).
local function facing(from: Vector3, to: Vector3): number
	local d = to - from
	return math.deg(math.atan2(-d.X, -d.Z))
end

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function mix(a: number, b: number, u: number): number
	return a + (b - a) * u
end

local function yawCF(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

-- The point `forward` studs ahead of and `right` studs to the right of `at`, facing `yaw`.
local function offset(at: Vector3, yaw: number, right: number, forward: number): Vector3
	local r = math.rad(yaw)
	local c, s = math.cos(r), math.sin(r)
	return at + Vector3.new(right * c - forward * s, 0, -right * s - forward * c)
end

local function pose(at: Vector3, yaw: number): Pose
	return {
		at = at,
		yaw = yaw,
		tilt = 0,
		pivot = 0,
		legs = { 0, 0 },
		arms = { { 0, 0.08 }, { 0, 0.08 } },
		head = 0,
		nod = 0,
		twist = 0,
		roll = 0,
		lean = 0,
		bob = 0,
	}
end

-- Moves arm `i` (1 left, 2 right) of `p` toward (swing, out) by `w` (0 leaves it, 1 sets it).
local function arm(p: Pose, i: number, swing: number, out: number, w: number)
	if w <= 0 then
		return
	end
	local a = p.arms[i]
	a[1] += (swing - a[1]) * w
	a[2] += (out - a[2]) * w
end

-- Breathing, so nobody stands frozen: the chest rises and the shoulders lift a little.
local function breathe(p: Pose, s: number, seed: number)
	local b = math.sin(s * 1.75 + seed)
	p.bob += 0.04 * b
	p.lean -= 0.012 * b
	p.arms[1][2] += 0.025 * b
	p.arms[2][2] += 0.025 * b
	p.head += 0.1 * math.sin(s * 0.45 + seed * 2)
end

-- Hands together, apart, together: applause.
local function clap(p: Pose, s: number, w: number)
	local beat = math.abs(math.sin(s * 11))
	arm(p, 1, 1.25, -0.15 + beat * 0.45, w)
	arm(p, 2, 1.25, -0.15 + beat * 0.45, w)
end

local function waveLeft(p: Pose, s: number, w: number)
	arm(p, 1, 2.8, 0.35 + math.sin(s * 9) * 0.3, w)
end

local function waveRight(p: Pose, s: number, w: number)
	arm(p, 2, 2.9, 0.4 + math.sin(s * 9) * 0.3, w)
end

-- Explaining: the free (left) hand out, moving with the words.
local function explain(p: Pose, s: number, w: number)
	arm(p, 1, 1.15 + math.sin(s * 3.1) * 0.3, 0.3 + math.sin(s * 2.3) * 0.15, w)
	p.head += math.sin(s * 2.2) * 0.12 * w
end

-- The (swing, out) that points arm `i` (1 left, 2 right) of someone posed `p` toward `target`.
local function reach(p: Pose, i: number, target: Vector3): (number, number)
	local side = if i == 1 then -1 else 1
	local r = math.rad(p.yaw)
	local c, sn = math.cos(r), math.sin(r)
	local sx = SHOULDER_X * side
	local shoulder = p.at + Vector3.new(sx * c, HIPS + SHOULDER_Y + p.bob, -sx * sn)
	local d = target - shoulder
	local lx = d.X * c - d.Z * sn
	local lz = d.X * sn + d.Z * c
	local ly = d.Y
	local m = math.sqrt(lx * lx + ly * ly + lz * lz)
	if m < 1e-4 then
		return 0, 0
	end
	local gamma = math.asin(math.clamp(lx / m, -1, 1))
	return math.atan2(-lz / m, -ly / m), gamma * side
end

-- Where the hand of arm `i` is (roughly: the body's twist and lean left out).
local function hand(p: Pose, i: number): Vector3
	local side = if i == 1 then -1 else 1
	local a = p.arms[i]
	local gamma = a[2] * side
	local lx, ly, lz = math.sin(gamma), -math.cos(gamma) * math.cos(a[1]), -math.cos(gamma) * math.sin(a[1])
	local r = math.rad(p.yaw)
	local c, sn = math.cos(r), math.sin(r)
	local sx = SHOULDER_X * side
	local shoulder = p.at + Vector3.new(sx * c, HIPS + SHOULDER_Y + p.bob, -sx * sn)
	return shoulder + Vector3.new(lx * c + lz * sn, ly, -lx * sn + lz * c) * GRIP
end

-- Where each body piece goes for `pose`, with `base` the film set's space. The legs hang from the
-- hips, the arms from the shoulders, the torso stands on the hips and the head on the neck; a held
-- prop sits in the right hand. Pure CFrame math, shared by CrewRig (which moves the parts there)
-- and the scenes (handing props on and off).
function FilmScenes.pieces(base: CFrame, p: Pose, stick: number): { [string]: CFrame }
	local root = base * CFrame.new(p.at) * CFrame.Angles(0, math.rad(p.yaw), 0)
	if p.tilt ~= 0 then
		root = root * CFrame.new(0, p.pivot, 0) * CFrame.Angles(p.tilt, 0, 0) * CFrame.new(0, -p.pivot, 0)
	end
	local torso = root * CFrame.new(0, HIPS, 0) * CFrame.Angles(0, p.twist, 0) * CFrame.Angles(-p.lean, 0, -p.roll) * CFrame.new(0, p.bob, 0)
	local out: { [string]: CFrame } = {
		Torso = torso,
		Head = torso * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, p.head, 0) * CFrame.Angles(p.nod, 0, 0),
		LegL = root * CFrame.new(-0.45, HIPS, 0) * CFrame.Angles(p.legs[1], 0, 0),
		LegR = root * CFrame.new(0.45, HIPS, 0) * CFrame.Angles(p.legs[2], 0, 0),
	}
	-- The character's right is +X (it faces -Z); an arm swings out to its own side.
	for i, side in { -1, 1 } do
		local a = p.arms[i]
		out[if side < 0 then "ArmL" else "ArmR"] = torso * CFrame.new(SHOULDER_X * side, SHOULDER_Y, 0) * CFrame.Angles(a[1], 0, 0) * CFrame.Angles(0, 0, side * a[2])
	end
	if p.hold ~= nil then
		local grip = out.ArmR * CFrame.new(0, -GRIP, 0)
		if p.aim ~= nil then
			-- (Built by hand: Lune's CFrame.lookAt, which the previews and tests run on, is off.)
			local look = (base * p.aim - grip.Position).Unit
			local right = look:Cross(Vector3.yAxis).Unit
			grip = CFrame.fromMatrix(grip.Position, right, right:Cross(look), -look) * CFrame.Angles(math.pi / 2, 0, 0)
		elseif p.level then
			grip = CFrame.new(grip.Position) * root.Rotation * CFrame.Angles(math.pi / 2, 0, 0)
		end
		out[p.hold] = grip
		if p.hold == "PropClapper" then
			out.Stick = grip * CFrame.new(-1.2, -0.3, -2.05) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, 0, stick)
		elseif p.hold == "PropRevolver" then
			out.Muzzle = grip * CFrame.new(0, -1.5, -0.05)
		end
	end
	return out
end

-- The CFrame of a prop held in `p`'s right hand, in the set's space.
local function gripCF(p: Pose, kit: string): CFrame
	local held = p.hold
	p.hold = kit
	local cf = FilmScenes.pieces(CFrame.identity, p, 0)[kit]
	p.hold = held
	return cf
end

-- Walking -------------------------------------------------------------------------------------
-- A walk turns on the spot to face the way, walks a path of points with planted feet, and turns
-- on the spot to its end facing. The gait is worked out from the distance walked: the path is
-- cut into whole steps, the foot on the ground stays where it landed while the hips pass over it,
-- and the other foot swings from where it was to where it lands next; the first and last steps are
-- half steps, from feet together and back to feet together. The hips ride up and down on the leg
-- that bears weight, which gives the bob.

export type Ground = (x: number, z: number, y: number) -> number

type Walk = {
	pts: { Vector3 },
	cum: { number }, -- distance along the path at each point
	dirs: { number }, -- facing along each leg of the path
	corner: { number }, -- how far before and after each point the facing blends round the corner
	total: number,
	t0: number,
	t1: number,
	yaw0: number,
	yaw1: number,
	turnIn: number,
	turnOut: number,
	moving: number, -- seconds on the move
	steps: number,
	ground: Ground?,
}

local WALK = 4 -- studs a second
local SLOW = 2 -- rehearsing at half energy
local STEP = 1.6 -- a stride (studs), so a leg swings about 0.4 radians

local function turnTime(a: number, b: number): number
	local d = angleGap(a, b)
	if d < 4 then
		return 0
	end
	return 0.25 + d / 180 * 0.45
end

local function makeWalk(points: { Vector3 }, t0: number, yaw0: number, yaw1: number?, speed: number, arrive: number?, ground: Ground?, step: number?): Walk
	local pts = table.create(#points)
	for i, q in points do
		pts[i] = if ground ~= nil then Vector3.new(q.X, ground(q.X, q.Z, q.Y), q.Z) else q
	end
	local cum, dirs = { 0 }, {}
	for i = 2, #pts do
		local d = pts[i] - pts[i - 1]
		local flat = math.sqrt(d.X * d.X + d.Z * d.Z)
		cum[i] = cum[i - 1] + flat
		dirs[i - 1] = if flat > 1e-3 then facing(pts[i - 1], pts[i]) elseif i > 2 then dirs[i - 2] else yaw0
	end
	local total = cum[#pts]
	local w: Walk = {
		pts = pts,
		cum = cum,
		dirs = dirs,
		corner = {},
		total = total,
		t0 = t0,
		t1 = t0,
		yaw0 = yaw0,
		yaw1 = yaw1 or yaw0,
		turnIn = 0,
		turnOut = 0,
		moving = 0,
		steps = 1,
		ground = ground,
	}
	if total < 0.05 then
		-- Just a turn on the spot.
		w.pts = { pts[1], pts[1] }
		w.cum = { 0, 0 }
		w.dirs = { w.yaw1 }
		w.total = 0
		w.turnIn = turnTime(yaw0, w.yaw1)
		w.t1 = t0 + w.turnIn
		return w
	end
	w.yaw1 = yaw1 or dirs[#dirs]
	w.turnIn = turnTime(yaw0, dirs[1])
	w.turnOut = turnTime(dirs[#dirs], w.yaw1)
	w.moving = if arrive ~= nil then arrive - t0 - w.turnIn - w.turnOut else total / speed + 0.45
	assert(w.moving > 0 and total / w.moving < 9.5, `a walk of {total} studs is too quick ({w.moving} s)`)
	w.steps = math.max(1, math.floor(total / (step or STEP) + 0.5))
	for i = 2, #pts - 1 do
		w.corner[i] = math.min(0.9, (cum[i] - cum[i - 1]) / 2, (cum[i + 1] - cum[i]) / 2)
	end
	w.t1 = t0 + w.turnIn + w.moving + w.turnOut
	return w
end

-- The point `d` studs along the walk's path, and which leg of the path it is on.
local function along(w: Walk, d: number): (Vector3, number)
	local n = #w.pts
	for i = 2, n do
		if d <= w.cum[i] or i == n then
			local length = w.cum[i] - w.cum[i - 1]
			local u = if length > 0 then math.clamp((d - w.cum[i - 1]) / length, 0, 1) else 1
			local p = w.pts[i - 1]:Lerp(w.pts[i], u)
			local ground = w.ground
			if ground ~= nil then
				p = Vector3.new(p.X, ground(p.X, p.Z, p.Y), p.Z)
			end
			return p, i - 1
		end
	end
	return w.pts[n], n - 1
end

-- The facing `d` studs along, eased round the corners of the path.
local function heading(w: Walk, d: number, i: number): number
	local dirs, cum = w.dirs, w.cum
	local r = w.corner[i]
	if r ~= nil and r > 0 and d - cum[i] < r and i > 1 then
		return turn(dirs[i - 1], dirs[i], smooth(0.5 + (d - cum[i]) / (2 * r)))
	end
	r = w.corner[i + 1]
	if r ~= nil and r > 0 and cum[i + 1] - d < r then
		return turn(dirs[i], dirs[i + 1], smooth(0.5 - (cum[i + 1] - d) / (2 * r)))
	end
	return dirs[i]
end

-- Distance walked `tau` seconds into the move: easing up to speed, cruising, easing to a stop.
local function walked(w: Walk, tau: number): number
	local T, L = w.moving, w.total
	if tau <= 0 then
		return 0
	elseif tau >= T then
		return L
	end
	local ta = math.min(0.45, T / 3)
	local top = L / (T - ta)
	if tau < ta then
		return 0.5 * top * tau * tau / ta
	elseif tau > T - ta then
		local r = T - tau
		return L - 0.5 * top * r * r / ta
	end
	return top * (tau - ta / 2)
end

-- Small steps on the spot while turning: the feet lift in turn.
local function stepping(p: Pose, u: number, degrees: number)
	local steps = math.max(1, math.floor(degrees / 70 + 0.5))
	local phase = math.min(u * steps, steps - 1e-6)
	local k = math.floor(phase)
	local lift = math.sin(math.pi * (phase - k)) * 0.22
	if k % 2 == 0 then
		p.legs[2] = lift
	else
		p.legs[1] = lift
	end
	p.arms[1][1] += lift * 0.3
	p.arms[2][1] += lift * 0.3
end

-- The legs, arms and body `d` studs into the walk (see the note above).
local function gait(w: Walk, d: number, p: Pose)
	local L, n = w.total, w.steps
	local S = L / n
	local m, h0, h1
	if d < S / 2 then
		m, h0, h1 = 1, 0, S / 2
	elseif d >= L - S / 2 then
		m, h0, h1 = n + 1, L - S / 2, L
	else
		m = math.floor(d / S + 0.5) + 1
		h0, h1 = (m - 1.5) * S, (m - 0.5) * S
	end
	local F = (m - 1) * S -- where the foot on the ground stands
	local P = math.max(0, (m - 2) * S) -- where the swinging foot left from
	local N = math.min(m * S, L) -- and where it lands
	local f = math.clamp((d - h0) / (h1 - h0), 0, 1)
	local stance = math.asin(math.clamp((F - d) / LEG, -1, 1))
	local from = math.asin(math.clamp((P - h0) / LEG, -1, 1))
	local to = math.asin(math.clamp((N - h1) / LEG, -1, 1))
	-- The swinging foot must clear the ground: off the mark quickly on the first half step, down
	-- gently on the last, and eased in between.
	local ease = if m == 1 then math.sin(f * math.pi / 2) elseif m == n + 1 then 1 - math.cos(f * math.pi / 2) else smooth(f)
	local swing = from + (to - from) * ease
	local footF = (along(w, F)).Y
	local footN = (along(w, N)).Y
	local hip = mix(footF, footN, smooth(f)) + LEG * math.cos(stance)
	if m % 2 == 1 then
		p.legs[1], p.legs[2] = stance, swing
		p.plant = 1
	else
		p.legs[1], p.legs[2] = swing, stance
		p.plant = 2
	end
	p.at = Vector3.new(p.at.X, hip - HIPS, p.at.Z)
	p.arms[1][1] = 0.85 * p.legs[2]
	p.arms[2][1] = 0.85 * p.legs[1]
	p.arms[1][2], p.arms[2][2] = 0.1, 0.1
	p.twist = (p.legs[1] - p.legs[2]) * 0.18
	p.roll = (if m % 2 == 1 then -1 else 1) * 0.04 * math.sin(math.pi * f)
	p.walking = true
end

local function walkPose(w: Walk, s: number): Pose
	local tau = s - w.t0
	if tau < w.turnIn then
		local u = tau / w.turnIn
		local p = pose(w.pts[1], turn(w.yaw0, w.dirs[1], smooth(u)))
		stepping(p, u, angleGap(w.yaw0, w.dirs[1]))
		return p
	end
	tau -= w.turnIn
	if tau < w.moving then
		local d = walked(w, tau)
		local at, i = along(w, d)
		local p = pose(at, heading(w, d, i))
		gait(w, d, p)
		return p
	end
	tau -= w.moving
	local last = w.dirs[#w.dirs]
	local u = if w.turnOut > 0 then math.clamp(tau / w.turnOut, 0, 1) else 1
	local p = pose(w.pts[#w.pts], turn(last, w.yaw1, smooth(u)))
	if u < 1 then
		stepping(p, u, angleGap(last, w.yaw1))
	end
	return p
end

-- Plans ----------------------------------------------------------------------------------------
-- A person's plan is a list of moves in time: walks, turns, climbs and actions on the spot. It is
-- written like a script, with a cursor (where they are, which way they face, the time), and played
-- by planPose: the latest move that has started, held at its end until the next one starts.

type Move = { t0: number, t1: number, f: (number) -> Pose }
type Plan = { moves: { Move }, at: Vector3, yaw: number, t: number, ground: Ground?, start: Vector3, startYaw: number, keys: { [string]: number } }

local function newPlan(at: Vector3, yaw: number, t: number, ground: Ground?): Plan
	return { moves = {}, at = at, yaw = yaw, t = t, ground = ground, start = at, startYaw = yaw, keys = {} }
end

local function addWalk(p: Plan, w: Walk)
	table.insert(p.moves, {
		t0 = w.t0,
		t1 = w.t1,
		f = function(s: number): Pose
			return walkPose(w, s)
		end,
	})
	p.at, p.yaw, p.t = w.pts[#w.pts], w.yaw1, w.t1
end

-- Walks through `points`, turning to `yaw` at the end (or keeps facing the way it walked). At a
-- corner sharper than 20 degrees they stop, turn on the spot and walk on, so feet never skate.
local function go(p: Plan, points: { Vector3 }, yaw: number?, speed: number?, step: number?)
	local list = { p.at }
	for i, q in points do
		local prev = list[#list]
		if #list >= 2 and (q - prev).Magnitude > 0.05 then
			local before = facing(list[#list - 1], prev)
			if angleGap(before, facing(prev, q)) > 20 then
				addWalk(p, makeWalk(list, p.t, p.yaw, nil, speed or WALK, nil, p.ground, step))
				list = { p.at }
			end
		end
		table.insert(list, q)
	end
	addWalk(p, makeWalk(list, p.t, p.yaw, yaw, speed or WALK, nil, p.ground, step))
end

-- The same, arriving (and turned) at time `arrive`.
local function goBy(p: Plan, points: { Vector3 }, yaw: number?, arrive: number, step: number?)
	local list = { p.at }
	for _, q in points do
		table.insert(list, q)
	end
	addWalk(p, makeWalk(list, p.t, p.yaw, yaw, WALK, arrive, p.ground, step))
end

local function face(p: Plan, yaw: number)
	go(p, {}, yaw)
end

local function waitUntil(p: Plan, t: number)
	p.t = math.max(p.t, t)
end

-- An action on the spot for `length` seconds: `f(u, s, q)` dresses a standing pose `q` (u runs
-- 0..1). It must end back in a plain standing pose, so whatever comes next starts from it.
local function act(p: Plan, length: number, f: (number, number, Pose) -> ())
	local at, yaw, t0 = p.at, p.yaw, p.t
	table.insert(p.moves, {
		t0 = t0,
		t1 = t0 + length,
		f = function(s: number): Pose
			local q = pose(at, yaw)
			f(span(s, t0, t0 + length), s, q)
			return q
		end,
	})
	p.t = t0 + length
end

-- Climbs a ladder straight up or down to `to`, facing it, hand over hand.
local function climb(p: Plan, to: Vector3, length: number)
	local from, yaw, t0 = p.at, p.yaw, p.t
	local rungs = math.max(2, math.floor(math.abs(to.Y - from.Y) / 1.2 + 0.5))
	table.insert(p.moves, {
		t0 = t0,
		t1 = t0 + length,
		f = function(s: number): Pose
			local u = span(s, t0, t0 + length)
			local q = pose(from:Lerp(to, smooth(u)), yaw)
			local w = window(s, t0, t0 + length, 0.35)
			local r = math.sin(u * math.pi * rungs)
			arm(q, 1, 2.5 + r * 0.3, 0, w)
			arm(q, 2, 2.5 - r * 0.3, 0, w)
			q.legs = { 0.6 * math.max(r, 0) * w, 0.6 * math.max(-r, 0) * w }
			return q
		end,
	})
	p.at, p.t = to, t0 + length
end

local function planPose(p: Plan, s: number): Pose
	local moves = p.moves
	for i = #moves, 1, -1 do
		local m = moves[i]
		if s >= m.t0 then
			return m.f(math.min(s, m.t1))
		end
	end
	return pose(p.start, p.startYaw)
end

-- When the plan's last move ends.
local function planEnd(p: Plan): number
	return p.t
end

-- Scenes ---------------------------------------------------------------------------------------

type Mark = { at: Vector3, yaw: number }

-- One scene on a set: the actors' story, played from story time a = 0 (the moment after
-- "Action!"), and everything the crew needs to know about it.
type Ctx = { touchArrive: number, touchStart: number, touchWho: string }
type Scene = {
	number: number,
	actors: { string },
	places: { [string]: Mark }, -- where the actors stand before a take
	story: (a: number, frame: Frame, cut: number) -> (), -- the actors (and loose props) at story time a
	cut: number, -- the story time the director calls "CUT!" on a clean take
	length: number, -- when the actors finish (bows, thumbs up) and stand still
	safe: { number }, -- story times where everyone stands still, so a take may stop there
	blooper: { at: number, who: string }, -- the blooper starts at a safe time
	mic: { string }, -- who the boom follows
	aim: Vector3, -- where the camera points
	boom: Mark, -- the boom operator's spot (they face the camera's aim)
	notes: Mark, -- where the director gives notes
	touch: { who: string, at: Vector3, yaw: number, via: { Vector3 }?, wait: number? }, -- the make-up artist's spot for a touch-up (the way there, and how long after the reset starts she sets off)
	rehearse: { [string]: { Vector3 } }, -- the walk-through: each actor's path out (and back)
	-- The walk back to the marks after a take that stopped at story time `endA`; nil walks
	-- straight back. `ctx.touch` (when this actor gets the touch-up) holds them for it.
	reset: { [string]: (endA: number, from: Pose, t0: number, to: Mark, plan: Plan, touch: (Plan) -> ()) -> () }?,
	routes: { [string]: { Vector3 } }?, -- the way to the next scene's marks (or, on a one-scene set, back to the marks), when straight would bump into someone
	things: ((endA: number, s: number, t0: number, frame: Frame, plans: { [string]: Plan }) -> ())?, -- loose props during the reset
	dress: ((frame: Frame) -> ())?, -- what the actors keep hold of between takes (the guide's torch)
}

-- A set's crew: where each member stands and the gear they use.
type Crew = {
	ground: Ground,
	director: Mark,
	clapper: Mark,
	slate: Mark,
	operatorTrack: { from: Vector3, to: Vector3 },
	gaffer: Mark,
	lamp: Mark, -- the lamp's stand
	makeup: Mark,
	dollyBack: number, -- seconds after the reset starts before the dolly rolls back
}

-- Things the crew uses on every set (CrewRig builds them as loose props).
local RIG_THINGS = { "CrewDolly", "CrewJibArm", "CrewCameraHead", "CrewLightHead" }
local JIB_PIVOT = 4.6 -- the crane arm's hinge, above the dolly's feet
local JIB_FRONT = 6.5
local LAMP_PIVOT = 4.8
local PLATFORM = 1.0 -- the dolly's deck, above its feet

-- Bloopers, taking turns by cycle.
local BLOOPERS = { "trip", "line", "laugh" }
local GAG = 3.4 -- seconds a blooper lasts

-- The slot's fixed times.
local QUIET = 0.3 -- "Quiet on set!"
local SLATE_AT = 3.4 -- the clapper loader is on the slate mark
local SNAP = 5.0
local ACTION = 5.6
local STORY = 6.2 -- story time 0
local TOUCH = 2.6 -- a make-up touch-up

-- Ground heights --------------------------------------------------------------------------------

local GROUND, BOARDWALK, BALCONY = 0.2, 0.8, 10 -- feet heights: the street, boardwalks, the hotel balcony

-- Dusty Gulch: the street, the boardwalks either side (|x| >= 14) and the hotel balcony.
local function gulchGround(x: number, z: number, y: number): number
	if y > 5 then
		return BALCONY
	elseif math.abs(x) >= 14 and z > 24 and z < 136 then
		return BOARDWALK
	end
	return GROUND
end

local function moonGround(_x: number, _z: number, y: number): number
	return if y > 3 then 6.25 else GROUND
end

local STEPS_FOOT, STEPS_TOP, TOP_Y = 79, 89.5, 16.2 -- the temple steps (art/blender/jungle_kit.py)

-- The ground height on the temple steps at `z` (the ramp under them).
local function stepY(z: number): number
	return GROUND + (TOP_Y - GROUND) * math.clamp((z - STEPS_FOOT) / (STEPS_TOP - STEPS_FOOT), 0, 1)
end

local function jungleGround(x: number, z: number, _y: number): number
	if z > STEPS_FOOT and math.abs(x - 24) < 9 then
		return stepY(z)
	end
	return GROUND
end

-- Dusty Gulch ------------------------------------------------------------------------------------
-- The camera rolls along the east side of the street (+X) and films across it, toward the hotel
-- (-X). The crew keeps to the east side; the stunt double works on the hotel's balcony.

local CAMERA_SIDE = -90 -- facing the camera (+X)
local SHOT_SIDE = 90 -- facing the shot (-X)

local GULCH: Crew = {
	ground = gulchGround,
	director = { at = v(9, GROUND, 103.4), yaw = SHOT_SIDE },
	clapper = { at = v(4.5, GROUND, 124.5), yaw = SHOT_SIDE },
	slate = { at = v(-1.5, GROUND, 110.5), yaw = CAMERA_SIDE },
	operatorTrack = { from = v(9.5, GROUND, 109), to = v(9.5, GROUND, 118) },
	gaffer = { at = v(9.8, GROUND, 129.2), yaw = 120 },
	lamp = { at = v(6.5, GROUND, 127.2), yaw = 45 },
	makeup = { at = v(6, GROUND, 99.6), yaw = 0 },
	dollyBack = 0.5,
}

local SHERIFF_START = { v(-5, GROUND, 102), v(3, GROUND, 104) }
local OUTLAW_START = { v(-5, GROUND, 126), v(-2, GROUND, 120) }
local STUNT_BALCONY = v(-18, BALCONY, 114)
local STUNT_HIP_AIR = 2.8 -- the stunt double flips about his hips, 2.8 studs above his feet
local STUNT_JUMP_FROM = v(-16.5, BALCONY, 114)
local STUNT_LAND_HIPS = v(-8.5, 2.8, 114) -- lying on the hay, his hips over the bales' middle
local STUNT_FEET_LYING = v(-5.7, 2.8, 114) -- where his feet are then
local STUNT_HOP_DOWN = v(-4.5, GROUND, 114)
local HOTEL_INSIDE = v(-21.8, BOARDWALK, 114) -- through the hotel's open door, out of sight
local BALCONY_INSIDE = v(-21.8, BALCONY, 114) -- behind the open balcony door
local OUTLAW_AIM_AT = v(-16.5, BALCONY + 4, 114)
local OUTLAW_AIM = facing(OUTLAW_START[2], OUTLAW_AIM_AT)

local GULCH_BOOM: Mark = { at = v(-8.5, GROUND, 125), yaw = 0 }

-- Scene 1: the showdown.
local SHOWDOWN_SHERIFF = newPlan(SHERIFF_START[1], 180, 0)
goBy(SHOWDOWN_SHERIFF, { v(-5, GROUND, 108) }, 180, 4.4)
local SHOWDOWN_OUTLAW = newPlan(OUTLAW_START[1], 0, 0)
goBy(SHOWDOWN_OUTLAW, { v(-5, GROUND, 120) }, 0, 4.4)

local function showdown(a: number, frame: Frame, cut: number)
	local poses, say = frame.poses, frame.say
	local sheriff = planPose(SHOWDOWN_SHERIFF, a)
	local outlaw = planPose(SHOWDOWN_OUTLAW, a)

	-- Hands hover over the holsters, then the draw: the sheriff is quicker.
	local hover = window(a, 4.4, 5.9, 0.4)
	arm(sheriff, 2, -0.15, 0.35, hover)
	arm(outlaw, 2, -0.15, 0.35, window(a, 4.4, 6.05, 0.4))
	local draw = window(a, 5.8, 8.6, 0.2)
	if a >= 5.85 and a < 8.5 then
		sheriff.hold = "PropRevolver"
	end
	arm(sheriff, 2, 1.57, 0, draw)
	if a >= 6.0 and a < 6.45 then
		outlaw.hold = "PropRevolver"
	end
	arm(outlaw, 2, 1.2, 0, window(a, 5.95, 6.5, 0.22))
	if a >= 6.3 and a < 6.45 then
		frame.shot = "Sheriff"
	end
	if a >= 6.3 and a < 7.4 then
		say.Sheriff = "BANG!"
	end
	arm(sheriff, 1, 2.9, 0.3, window(a, 8.5, 9.6, 0.3)) -- tips his hat

	-- The outlaw falls flat on his back, lies still, then gets up for the cut.
	if a >= 6.4 and a < 13.4 then
		local down = if a < 12.4 then span(a, 6.4, 7.1) ^ 2 else 1 - smooth(span(a, 12.4, 13.4))
		outlaw.tilt = down * math.pi / 2
		outlaw.at += v(0, 0.5 * math.sin(outlaw.tilt), 0)
		local w = if a < 12.4 then smooth(span(a, 6.4, 6.8)) else down
		arm(outlaw, 1, 0.4, 0.9, w)
		arm(outlaw, 2, 0.4, 0.9, w)
		outlaw.legs = { 0.15 * down, -0.1 * down }
	end
	local thumbs = window(a, 13.4, 15.2, 0.3)
	arm(outlaw, 2, 2.75, 0.2, thumbs)
	if thumbs > 0.5 then
		say.Outlaw = "How was that?"
	end
	clap(sheriff, a, window(a, cut + 1, cut + 3, 0.3))

	-- The stunt double waits on the balcony for his scene, watching.
	local stunt = pose(STUNT_BALCONY, CAMERA_SIDE)
	poses.Sheriff, poses.Outlaw, poses.Stunt = sheriff, outlaw, stunt
end

-- Scene 2: the stunt.
local STUNT_STEP = newPlan(STUNT_BALCONY, CAMERA_SIDE, 0.5, gulchGround)
goBy(STUNT_STEP, { STUNT_JUMP_FROM }, CAMERA_SIDE, 1.3)

local function stuntScene(a: number, frame: Frame, cut: number)
	local poses, say = frame.poses, frame.say
	local sheriff = pose(SHERIFF_START[2], SHOT_SIDE)
	local outlaw = pose(OUTLAW_START[2], OUTLAW_AIM)
	local aimW = window(a, 0.7, 3.8, 0.3)
	if a >= 0.8 and a < 3.7 then
		outlaw.hold = "PropRevolver"
	end
	arm(outlaw, 2, 2.1, 0, aimW) -- aimed up at the balcony
	if a >= 1.8 and a < 1.95 then
		frame.shot = "Outlaw"
	end
	if a >= 1.8 and a < 2.8 then
		say.Outlaw = "BANG!"
	end
	local claps = window(a, cut + 1, cut + 3, 0.3)
	clap(sheriff, a, claps)
	clap(outlaw, a, claps)

	-- The stunt double: two steps to the rail, the hit, a flip off the balcony onto the hay, a
	-- moment lying still, then up, down off the bales and a thumbs up.
	local stunt: Pose
	if a < 2.0 then
		stunt = planPose(STUNT_STEP, a)
		local hit = smooth(span(a, 1.8, 1.92))
		arm(stunt, 1, 0.6, 1.2, hit)
		arm(stunt, 2, 0.6, 1.2, hit)
	elseif a < 3.1 then
		-- In the air: his hips fly a curve over the rail and down to the bales while he turns a
		-- back flip and a quarter, landing on his back.
		local u = span(a, 2.0, 3.1)
		local fromHips = STUNT_JUMP_FROM + v(0, STUNT_HIP_AIR, 0)
		local hips = fromHips:Lerp(STUNT_LAND_HIPS, u) + v(0, 34 * u * (1 - u), 0)
		stunt = pose(hips - v(0, STUNT_HIP_AIR, 0), CAMERA_SIDE)
		stunt.pivot = STUNT_HIP_AIR
		stunt.tilt = (2.5 * math.pi) * smooth(u)
		local flail = math.sin(a * 18) * 0.5 * window(a, 2.0, 3.1, 0.2)
		local inAir = window(a, 2.0, 3.1, 0.15)
		stunt.arms = { { 0.6, 1.2 }, { 0.6, 1.2 } }
		arm(stunt, 1, 1.4 + flail, 1.1, inAir)
		arm(stunt, 2, 1.4 - flail, 1.1, inAir)
		local land = smooth(span(a, 2.95, 3.1))
		arm(stunt, 1, 0.3, 0.8, land)
		arm(stunt, 2, 0.3, 0.8, land)
		stunt.legs = { 0.8 * math.sin(u * math.pi), 0.5 * math.sin(u * math.pi) }
	elseif a < 5.6 then
		-- Lying on the hay, then sitting up and standing on the bales' edge.
		stunt = pose(STUNT_FEET_LYING, CAMERA_SIDE)
		local up = smooth(span(a, 4.8, 5.6))
		stunt.tilt = (math.pi / 2) * (1 - up)
		stunt.arms = { { 0.3, 0.8 }, { 0.3, 0.8 } }
		arm(stunt, 1, 0.3, 0.5, up)
		arm(stunt, 2, 0.3, 0.5, up)
	elseif a < 6.0 then
		-- A hop down to the street.
		local u = span(a, 5.6, 6.0)
		stunt = pose(STUNT_FEET_LYING:Lerp(STUNT_HOP_DOWN, u) + v(0, 2.4 * u * (1 - u), 0), CAMERA_SIDE)
		stunt.arms = { { 0.3, 0.5 }, { 0.3, 0.5 } }
		local settle = smooth(span(a, 5.8, 6.0))
		arm(stunt, 1, 0, 0.08, settle)
		arm(stunt, 2, 0, 0.08, settle)
	else
		stunt = pose(STUNT_HOP_DOWN, CAMERA_SIDE)
		local thumbs = window(a, 6.0, 7.6, 0.3)
		arm(stunt, 2, 2.75, 0.2, thumbs)
		if thumbs > 0.5 then
			say.Stunt = "Nailed it!"
		end
		clap(stunt, a, claps)
	end
	poses.Sheriff, poses.Outlaw, poses.Stunt = sheriff, outlaw, stunt
end

-- The stunt double's way back to the balcony: in at the hotel's door, up the stairs out of sight,
-- and out of the balcony door.
local function stuntBack(endA: number, _from: Pose, _t0: number, to: Mark, plan: Plan, _touch: (Plan) -> ())
	if endA < 2.0 then
		-- He never left the balcony (the take stopped early).
		go(plan, { to.at }, to.yaw)
		return
	end
	go(plan, { v(-5, GROUND, 118.2), v(-12.5, GROUND, 118.2), v(-17.2, BOARDWALK, 114.8), HOTEL_INSIDE })
	local inside = plan.t
	table.insert(plan.moves, {
		t0 = inside,
		t1 = inside + 3,
		f = function(_s: number): Pose
			local q = pose(HOTEL_INSIDE, SHOT_SIDE)
			q.hidden = true
			return q
		end,
	})
	plan.at, plan.yaw, plan.t = BALCONY_INSIDE, CAMERA_SIDE, inside + 3
	go(plan, { to.at }, to.yaw)
end

local GULCH_SCENES: { Scene } = {
	{
		number = 1,
		actors = { "Sheriff", "Outlaw", "Stunt" },
		places = {
			Sheriff = { at = SHERIFF_START[1], yaw = 180 },
			Outlaw = { at = OUTLAW_START[1], yaw = 0 },
			Stunt = { at = STUNT_BALCONY, yaw = CAMERA_SIDE },
		},
		story = showdown,
		cut = 10.3,
		length = 15.4,
		safe = { 0, 4.4 },
		blooper = { at = 4.4, who = "Outlaw" },
		mic = { "Sheriff", "Outlaw" },
		aim = v(-5, 3.5, 114),
		boom = GULCH_BOOM,
		notes = { at = v(-0.5, GROUND, 114), yaw = SHOT_SIDE },
		touch = { who = "Sheriff", at = v(-5, GROUND, 104.4), yaw = 0 },
		rehearse = { Sheriff = { v(-5, GROUND, 107) }, Outlaw = { v(-5, GROUND, 121) } },
	},
	{
		number = 2,
		actors = { "Sheriff", "Outlaw", "Stunt" },
		places = {
			Sheriff = { at = SHERIFF_START[2], yaw = SHOT_SIDE },
			Outlaw = { at = OUTLAW_START[2], yaw = OUTLAW_AIM },
			Stunt = { at = STUNT_BALCONY, yaw = CAMERA_SIDE },
		},
		story = stuntScene,
		cut = 7.3,
		length = 10.5,
		safe = { 0, 0.4 },
		blooper = { at = 0.4, who = "Outlaw" },
		mic = { "Outlaw", "Sheriff" },
		aim = v(-9, 5, 114),
		boom = GULCH_BOOM,
		notes = { at = v(1.5, GROUND, 116), yaw = SHOT_SIDE },
		touch = { who = "Sheriff", at = v(0.7, GROUND, 104), yaw = CAMERA_SIDE, wait = 3.5 },
		rehearse = { Stunt = { STUNT_JUMP_FROM } },
		reset = { Stunt = stuntBack },
	},
}

-- Moon Base: The first step --------------------------------------------------------------------
-- The camera stands near the gate and pushes in toward the painted space backdrop at the far end
-- (+Z), so players walking in see the crew from behind and the scene beyond them.

local MOON: Crew = {
	ground = moonGround,
	director = { at = v(-6.5, GROUND, 43), yaw = 180 },
	clapper = { at = v(5.5, GROUND, 51.6), yaw = 180 },
	slate = { at = v(0, GROUND, 56.5), yaw = 0 },
	operatorTrack = { from = v(0, GROUND, 42), to = v(0, GROUND, 50.5) },
	gaffer = { at = v(10.5, GROUND, 49.5), yaw = 150 },
	lamp = { at = v(8.2, GROUND, 53.2), yaw = 165 },
	makeup = { at = v(-9, GROUND, 46), yaw = 90 },
	dollyBack = 0.5,
}

-- Only the crew's own gear: the moon set itself (lander, rocket, foam rock, flats and the rest) is
-- laid out in TownSets.moonBase.
local MOON_GEAR: { Gear } = {
	{ kit = "DirectorChair", at = v(-9.5, 0.2, 41.5), yaw = 180, label = "DIRECTOR" },
	{ kit = "CrewDollyTrack", at = v(0, 0.2, 47), yaw = 0 },
	{ kit = "CrewLightStand", at = v(8.2, 0.2, 53.2), yaw = 0 },
	{ kit = "CrewMakeupKit", at = v(-11, 0.2, 46), yaw = 90 },
}

local PORCH = v(-8, 6.25, 72.6) -- the lander's porch, where the astronaut waits
local LADDER_TOP = v(-8, 6.25, 71.4)
local LADDER_FOOT = v(-8, GROUND, 71.4)
local FLAG_SPOT = v(-0.5, GROUND, 62)
local FLAG_PLANTED = CFrame.new(0.9, GROUND, 61) * CFrame.Angles(math.pi, 0, 0)
local FLAG_HOLDER = CFrame.new(-6.3, GROUND, 70.4) * CFrame.Angles(math.pi, 0, 0) -- stuck in the dust by the ladder
local ALIEN_HIDE = v(17.5, GROUND, 84.2) -- crouched behind the foam rock (TownSets: the rock at 16, 80)
local ALIEN_ROUND = v(21.5, GROUND, 79.5) -- round the rock's east end
local ALIEN_MID = v(11, GROUND, 72) -- first stop, frozen while the astronaut half turns
local ALIEN_NEAR = v(6.3, GROUND, 66.9)
local ALIEN_BEHIND = v(3.2, GROUND, 63.5) -- behind his right shoulder, both in sight of the camera
local GRAB, PLANT = 3.75, 10.6 -- when the astronaut takes the flag, and plants it
local BOUNDS, BOUND_T0, BOUND_LEN = 4, 5.6, 1.0 -- the low-gravity walk: four slow bounds
local LOOK0, LOOK1 = 13.2, 14.4 -- the astronaut's half turn ("Hm?") while the alien freezes
local TAP, FACE_UP, JUMP, SHAKE = 17.2, 18.0, 18.4, 19.6 -- tap, turn round, both jump, handshake
local WAVE = 21.6 -- both wave to the camera

-- The alien's sneak, in stages: round the rock, tiptoe to the first stop, freeze while the
-- astronaut looks round, then tiptoe in close behind him.
local ALIEN_SNEAK = newPlan(ALIEN_HIDE, 0, 8.4)
goBy(ALIEN_SNEAK, { ALIEN_ROUND }, nil, 9.8, 1.2)
goBy(ALIEN_SNEAK, { ALIEN_MID }, nil, 12.6, 1.2)
waitUntil(ALIEN_SNEAK, 14.9)
goBy(ALIEN_SNEAK, { ALIEN_NEAR, ALIEN_BEHIND }, nil, TAP - 0.3, 1.2)
face(ALIEN_SNEAK, facing(ALIEN_BEHIND, FLAG_SPOT))

-- A prop moving from one place to another over `length` seconds from `t0` (a hand-off).
local function handOff(from: CFrame, to: CFrame, s: number, t0: number, length: number): CFrame
	return from:Lerp(to, smooth(span(s, t0, t0 + length)))
end

-- One low-gravity bound at u (0..1): a crouch, a long floaty hang in the air, and a soft landing.
-- Returns how far along the bound the body is (0..1) and how high it is.
local function bound(u: number): (number, number)
	local air = span(u, 0.18, 0.88)
	local up = if air > 0 and air < 1 then math.sin(air * math.pi) ^ 0.7 else 0
	return smooth(air), 2.2 * up
end

local function moonStory(a: number, frame: Frame, cut: number)
	local poses, say, things = frame.poses, frame.say, frame.things
	local walkYaw = facing(LADDER_FOOT, FLAG_SPOT)
	local toAlien = facing(FLAG_SPOT, ALIEN_BEHIND)

	-- The astronaut.
	local astro: Pose
	if a < 0.8 then
		astro = pose(PORCH, turn(0, 180, smooth(span(a, 0.4, 0.8))))
	elseif a < 3.2 then
		-- A step back onto the ladder, then down it, facing it, hand over hand.
		local u = span(a, 0.8, 3.2)
		local at = if u < 0.1 then PORCH:Lerp(LADDER_TOP, smooth(u / 0.1)) else LADDER_TOP:Lerp(LADDER_FOOT, smooth((u - 0.1) / 0.9))
		astro = pose(at, 180)
		local w = window(a, 0.8, 3.2, 0.3)
		local rung = math.sin(u * math.pi * 6)
		arm(astro, 1, 2.5 + rung * 0.3, 0, w)
		arm(astro, 2, 2.5 - rung * 0.3, 0, w)
		astro.legs = { 0.6 * math.max(rung, 0) * w, 0.6 * math.max(-rung, 0) * w }
	elseif a < BOUND_T0 then
		-- Turns round at the foot, takes the flag from its stand, looks round at the moon and waves
		-- to the camera, then turns the way he will bound.
		astro = pose(LADDER_FOOT, if a < 5.0 then turn(180, 0, smooth(span(a, 3.2, 3.6))) else turn(0, walkYaw, smooth(span(a, 5.1, 5.5))))
		astro.head += 0.5 * math.sin(span(a, 3.9, 4.9) * math.pi * 2) * window(a, 3.9, 4.9, 0.2)
		waveLeft(astro, a, window(a, 4.4, 5.3, 0.25))
	elseif a < BOUND_T0 + BOUNDS * BOUND_LEN then
		-- The low-gravity walk: four slow bounds with a long hang in the air, arms out for balance.
		local k = math.floor((a - BOUND_T0) / BOUND_LEN)
		local along, up = bound(span(a, BOUND_T0 + k * BOUND_LEN, BOUND_T0 + (k + 1) * BOUND_LEN))
		local at = LADDER_FOOT:Lerp(FLAG_SPOT, (k + along) / BOUNDS)
		astro = pose(at + v(0, up, 0), walkYaw)
		local w = window(a, BOUND_T0, BOUND_T0 + BOUNDS * BOUND_LEN, 0.3)
		local tuck = up / 2.2
		arm(astro, 1, 0.6, 0.9, w)
		astro.legs = { 0.55 * tuck, -0.35 * tuck }
		astro.lean += 0.15 * tuck
	else
		local yaw = turn(walkYaw, 0, smooth(span(a, 9.6, 9.9)))
		yaw = turn(yaw, 70, window(a, LOOK0, LOOK1, 0.35)) -- "Hm?" a half turn, and back
		yaw = turn(yaw, toAlien, smooth(span(a, FACE_UP, FACE_UP + 0.4)))
		yaw = turn(yaw, 0, smooth(span(a, WAVE - 0.4, WAVE)))
		astro = pose(FLAG_SPOT, yaw)
		-- Plants the flag two-handed, salutes it, admires it.
		local push = window(a, 9.9, PLANT + 0.35, 0.3)
		arm(astro, 1, if a < PLANT - 0.4 then 2.9 else mix(2.9, 2.2, span(a, PLANT - 0.4, PLANT)), -0.35, push)
		astro.lean += 0.25 * window(a, PLANT - 0.4, PLANT + 0.4, 0.3)
		arm(astro, 2, 2.6, -0.5, window(a, 11.2, 12.5, 0.3)) -- a salute
		astro.nod -= 0.4 * window(a, 12.6, LOOK0, 0.3) + 0.3 * window(a, LOOK1, TAP + 0.6, 0.4)
		if a >= LOOK0 + 0.2 and a < LOOK1 - 0.1 then
			say.Astronaut = "Hm?"
		end
		-- The jump of surprise, the handshake, then waving to the camera.
		if a >= JUMP and a < JUMP + 1 then
			local u = span(a, JUMP, JUMP + 1)
			astro.at += v(0, 3 * math.sin(u * math.pi), 0)
			astro.legs = { 0.4 * math.sin(u * math.pi), 0.2 * math.sin(u * math.pi) }
		end
		local jump = window(a, JUMP - 0.2, JUMP + 1.3, 0.45)
		arm(astro, 1, 3.0, 0.5, jump)
		arm(astro, 2, 3.0, 0.5, jump)
		local shake = window(a, SHAKE, SHAKE + 1.6, 0.35)
		arm(astro, 2, 1.35 + 0.18 * math.sin(a * 12), 0.05, shake)
		waveRight(astro, a, window(a, WAVE, cut + 0.8, 0.3))
		clap(astro, a, window(a, cut + 1, cut + 3, 0.3))
	end
	-- The flag: in its stand by the ladder, then in his hand held high, then planted.
	local carry = window(a, 3.62, PLANT + 0.35, 0.3)
	arm(astro, 2, if a < PLANT - 0.4 then 2.9 else mix(2.9, 2.2, span(a, PLANT - 0.4, PLANT)), 0.1, carry)
	if a < GRAB then
		things.PropFlag = FLAG_HOLDER
	elseif a < GRAB + 0.2 then
		things.PropFlag = handOff(FLAG_HOLDER, gripCF(astro, "PropFlag"), a, GRAB, 0.2)
	elseif a < PLANT then
		astro.hold = "PropFlag"
	else
		things.PropFlag = if a < PLANT + 0.3 then handOff(gripCF(astro, "PropFlag"), FLAG_PLANTED, a, PLANT, 0.3) else FLAG_PLANTED
	end
	if a >= 3.6 and a < 5.4 then
		say.Astronaut = "One small step..."
	elseif a >= JUMP and a < JUMP + 1.2 then
		say.Astronaut = "AAH!"
	elseif a >= SHAKE + 0.2 and a < SHAKE + 1.6 then
		say.Astronaut = "Welcome to the Moon!"
	end

	-- The alien: peeks out from behind the foam rock, sneaks up in stages (freezing mid-tiptoe when
	-- the astronaut looks round), taps his shoulder, jumps when he jumps, and shakes his hand.
	local alien = planPose(ALIEN_SNEAK, a)
	local peek = window(a, 1.8, 3.4, 0.4) + window(a, 5.8, 7.6, 0.4)
	alien.head += 0.6 * math.sin(a * 2) * peek
	alien.roll -= 0.35 * peek -- leaning out past the rock's edge
	local tiptoe = window(a, 8.4, TAP - 0.2, 0.4)
	arm(alien, 1, 1.0, 0.5, tiptoe)
	arm(alien, 2, 1.0, 0.5, tiptoe)
	local freeze = window(a, LOOK0 - 0.1, LOOK1 + 0.3, 0.2)
	arm(alien, 1, 2.6, 0.9, freeze) -- frozen mid-tiptoe, arms up, "I'm a rock"
	arm(alien, 2, 2.6, 0.9, freeze)
	alien.legs[1] += 0.45 * freeze
	local tap = window(a, TAP, FACE_UP + 0.2, 0.2)
	arm(alien, 2, 1.5 + math.sin(a * 14) * 0.15 * tap, 0.1, tap) -- tap, tap
	if tap > 0.5 then
		say.Alien = "Psst!"
	end
	if a >= JUMP and a < JUMP + 1 then
		local u = span(a, JUMP, JUMP + 1)
		alien.at += v(0, 2.5 * math.sin(u * math.pi), 0)
		say.Alien = "EEP!"
	end
	local jump = window(a, JUMP - 0.2, JUMP + 1.3, 0.45)
	arm(alien, 1, 2.9, 0.6, jump)
	arm(alien, 2, 2.9, 0.6, jump)
	arm(alien, 2, 1.35 - 0.18 * math.sin(a * 12), 0.05, window(a, SHAKE, SHAKE + 1.6, 0.35))
	if a >= SHAKE + 1.6 and a < WAVE + 0.6 then
		say.Alien = "Take me to your director!"
	end
	alien.yaw = turn(alien.yaw, 0, smooth(span(a, WAVE - 0.4, WAVE)))
	local wave = window(a, WAVE, cut + 0.8, 0.3)
	waveLeft(alien, a, wave)
	waveRight(alien, a + 0.4, wave)
	clap(alien, a, window(a, cut + 1, cut + 3, 0.3))
	poses.Astronaut, poses.Alien = astro, alien
end

-- After the take the astronaut pulls up the flag, carries it back to its stand by the ladder, has
-- his face touched up there and climbs back up to the porch.
local BY_LADDER = v(-7.7, GROUND, 70)

local function astronautBack(endA: number, from: Pose, _t0: number, to: Mark, plan: Plan, touch: (Plan) -> ())
	if endA >= PLANT then
		face(plan, facing(from.at, FLAG_PLANTED.Position))
		plan.keys.pull = plan.t
		act(plan, 1.0, function() end)
		go(plan, { v(-4.5, GROUND, 67), BY_LADDER }, 0)
		plan.keys.stand = plan.t
		act(plan, 0.8, function() end)
	else
		go(plan, { BY_LADDER }, 0)
	end
	touch(plan)
	face(plan, 180)
	go(plan, { LADDER_FOOT }, 180)
	climb(plan, LADDER_TOP, 2.2)
	go(plan, { PORCH }, nil, 1.5)
	face(plan, to.yaw)
end

-- The flag during the reset: pulled up, carried high and stood back by the ladder.
local function moonThings(endA: number, s: number, _t0: number, frame: Frame, plans: { [string]: Plan })
	local things = frame.things
	local keys = plans.Astronaut.keys
	if endA < PLANT or keys.pull == nil then
		things.PropFlag = FLAG_HOLDER
		return
	end
	local astro = frame.poses.Astronaut
	arm(astro, 2, 2.9, 0.1, window(s, keys.pull, keys.stand + 0.65, 0.45))
	if s < keys.pull + 0.45 then
		things.PropFlag = FLAG_PLANTED
	elseif s < keys.pull + 0.7 then
		things.PropFlag = handOff(FLAG_PLANTED, gripCF(astro, "PropFlag"), s, keys.pull + 0.45, 0.25)
	elseif s < keys.stand + 0.25 then
		astro.hold = "PropFlag"
		things.PropFlag = nil
	elseif s < keys.stand + 0.5 then
		things.PropFlag = handOff(gripCF(astro, "PropFlag"), FLAG_HOLDER, s, keys.stand + 0.25, 0.25)
	else
		things.PropFlag = FLAG_HOLDER
	end
end

local MOON_SCENES: { Scene } = {
	{
		number = 1,
		actors = { "Astronaut", "Alien" },
		places = {
			Astronaut = { at = PORCH, yaw = 0 },
			Alien = { at = ALIEN_HIDE, yaw = 0 },
		},
		story = moonStory,
		cut = 23.4,
		length = 26.6,
		safe = { 0, 3.6 },
		blooper = { at = 3.6, who = "Astronaut" },
		mic = { "Astronaut", "Alien" },
		aim = v(0, 3.5, 66),
		boom = { at = v(-8, GROUND, 55.6), yaw = 0 },
		notes = { at = v(-3.5, GROUND, 55.5), yaw = 180 },
		touch = { who = "Astronaut", at = v(-7.7, GROUND, 67.6), yaw = 180, via = { v(-10.5, GROUND, 56.5) } },
		rehearse = { Alien = { ALIEN_ROUND, ALIEN_MID } },
		reset = { Astronaut = astronautBack },
		routes = { Alien = { ALIEN_ROUND } },
		things = moonThings,
	},
}

-- Jungle Temple: The idol --------------------------------------------------------------------------
-- The camera stands in the clearing and pushes in toward the temple steps (+Z). The temple's
-- steps run from z = 79 on the ground up to z = 89.5 at the top platform, 16 up.

local JUNGLE: Crew = {
	ground = jungleGround,
	director = { at = v(14.2, GROUND, 57.5), yaw = 180 },
	clapper = { at = v(34, GROUND, 55.5), yaw = 180 },
	slate = { at = v(19.5, GROUND, 66), yaw = 0 },
	operatorTrack = { from = v(19.5, GROUND, 54), to = v(29, GROUND, 54) },
	gaffer = { at = v(38, GROUND, 59.5), yaw = 150 },
	lamp = { at = v(35.5, GROUND, 62.8), yaw = 175 },
	makeup = { at = v(12.8, GROUND, 63), yaw = 90 },
	dollyBack = 11, -- the guide pushes the boulder back past the camera first
}

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
	{ kit = "DirectorChair", at = v(11.5, 0.2, 55.5), yaw = 180, label = "DIRECTOR" },
	{ kit = "CrewDollyTrack", at = v(24, 0.2, 54), yaw = 90 },
	{ kit = "CrewLightStand", at = v(35.5, 0.2, 62.8), yaw = 0 },
	{ kit = "CrewMakeupKit", at = v(10.4, 0.2, 63), yaw = 90 },
}

local IDOL_ON_PEDESTAL = CFrame.new(24, TOP_Y + 1.6, 92.5) * CFrame.Angles(math.pi, 0, 0)
local SANDBAG_ON_PEDESTAL = IDOL_ON_PEDESTAL -- the sandbag sits where the idol stood
local IDOL_REACH = v(24, TOP_Y, 90.6) -- where the explorer stands to reach the idol
local BOULDER_R = 3.2
local DOOR_Z = 97.5 -- the boulder's middle when it rests in the doorway
local BOULDER_STOP = 66
local EXPLORER_PLACES = v(22, GROUND, 75)
local GUIDE_PLACES = v(27.5, GROUND, 74)
local GUIDE_COVER = v(39.5, GROUND, 70.5) -- off to the right, out of the boulder's way
local TRAP_STEP = v(24, GROUND, 84) -- halfway up, where the dart trap goes off
local RUN_END = v(10.5, GROUND, 70.2) -- the chase veers left off the boulder's line, toward the fallen column
local DIVE_TO = v(7.6, GROUND, 68.6)
local DIVE_YAW = 63
local SWAP, SWAP_LEN = 10.0, 0.35 -- the sandbag goes on the pedestal as the idol comes off
local DART_FROM, DART_TO, DART_AT = v(11, 12.9, 84), v(40, 12.9, 84), 5.65 -- flies across just over his ducked head
local DART_LEN = 0.55
local RUMBLE = 11.4
local BOULDER_OUT, BOULDER_TOP, BOULDER_FOOT, BOULDER_STILL = 12.4, 13.6, 14.4, 16.2

local function boulderCF(z: number): CFrame
	return CFrame.new(24, stepY(z) + BOULDER_R, z) * CFrame.Angles(-(DOOR_Z - z) / BOULDER_R, 0, 0)
end

-- The boulder's middle along its path: out of the doorway, over the edge, down the steps and
-- across the clearing, slowing to a stop just short of the camera.
local function boulderZ(a: number): number
	if a < BOULDER_OUT then
		return DOOR_Z
	elseif a < BOULDER_TOP then
		return DOOR_Z + (STEPS_TOP - DOOR_Z) * smooth(span(a, BOULDER_OUT, BOULDER_TOP)) ^ 0.7
	elseif a < BOULDER_FOOT then
		return STEPS_TOP + (STEPS_FOOT - STEPS_TOP) * span(a, BOULDER_TOP, BOULDER_FOOT)
	end
	local u = span(a, BOULDER_FOOT, BOULDER_STILL)
	return STEPS_FOOT + (BOULDER_STOP - STEPS_FOOT) * (1 - (1 - u) * (1 - u))
end

-- The explorer creeps up the steps in small steps, stops halfway to check for traps (the dart),
-- creeps on to the idol; then turns and sprints down the steps with the boulder behind him and
-- veers left off its line across the clearing.
local EXPLORER_UP = newPlan(EXPLORER_PLACES, 180, 1.0, jungleGround)
goBy(EXPLORER_UP, { v(24, GROUND, 77.5) }, 180, 2.6)
goBy(EXPLORER_UP, { TRAP_STEP }, 180, 5.2, 0.9)
waitUntil(EXPLORER_UP, 6.6)
goBy(EXPLORER_UP, { IDOL_REACH }, 180, 9.0, 0.9)
local EXPLORER_RUN = newPlan(IDOL_REACH, 180, 11.9, jungleGround)
do
	-- Down the steps, then a smooth curve off the boulder's line (a sharp corner at a sprint would
	-- skid his planted foot).
	local path = { v(24, GROUND, 82) }
	local p0, p1, p2 = Vector3.new(24, 0, 82), Vector3.new(24, 0, 72.5), Vector3.new(RUN_END.X, 0, RUN_END.Z)
	for i = 1, 16 do
		local u = i / 16
		local q = p0 * (1 - u) ^ 2 + p1 * 2 * u * (1 - u) + p2 * u * u
		table.insert(path, v(q.X, GROUND, q.Z))
	end
	goBy(EXPLORER_RUN, path, nil, 15.8, 2.4)
end
local GUIDE_RUN = newPlan(GUIDE_PLACES, 180, 12.0)
goBy(GUIDE_RUN, { v(33, GROUND, 72.4), GUIDE_COVER }, 90, 14.6, 2.4)

local function jungleStory(a: number, frame: Frame, cut: number)
	local poses, say, things = frame.poses, frame.say, frame.things

	-- The explorer.
	local explorer: Pose
	if a < 15.8 then
		explorer = if a < 11.9 then planPose(EXPLORER_UP, a) else planPose(EXPLORER_RUN, a)
		explorer.head += 0.5 * window(a, 0.1, 1.0, 0.3) -- a nod to the guide
		-- Creeping (eased off by 5.2, where a take may stop, so that moment is a plain pose).
		explorer.lean += 0.22 * (window(a, 2.6, 5.2, 0.5) + window(a, 6.4, 9.2, 0.5))
		explorer.head += 0.6 * math.sin((a - 5.25) * 6) * window(a, 5.25, 5.75, 0.2) -- checking for traps
		local duck = window(a, DART_AT - 0.1, DART_AT + 0.7, 0.2)
		explorer.lean += 0.8 * duck
		explorer.bob -= 0.3 * duck
		arm(explorer, 1, 2.5, 0.2, duck)
		-- Weighing the sandbag against the idol, the swap, a look at the prize.
		arm(explorer, 2, 1.2 + 0.25 * math.sin(a * 9), 0, window(a, 9.0, SWAP, 0.3))
		arm(explorer, 2, 1.35, 0, window(a, SWAP - 0.2, SWAP + SWAP_LEN + 0.2, 0.15))
		arm(explorer, 2, 1.5, 0.1, window(a, SWAP + SWAP_LEN, RUMBLE + 0.3, 0.3))
		explorer.nod -= 0.2 * window(a, SWAP + SWAP_LEN, RUMBLE, 0.3)
		explorer.nod += 0.35 * window(a, RUMBLE, 12.2, 0.2) -- up at the rumbling doorway
		arm(explorer, 2, 2.4, 0.2, window(a, 12.2, 16.2, 0.3)) -- the idol held tight on the run
	else
		-- A dive to the side, face down, then up again, dusting off, and the idol held high.
		local u = span(a, 15.8, 16.4)
		local getUp = span(a, 18.2, 19.0)
		explorer = pose(RUN_END:Lerp(DIVE_TO, smooth(u)), turn(DIVE_YAW, 0, smooth(span(a, 19.2, 19.8))))
		local down = if a < 18.2 then smooth(u) else 1 - smooth(getUp)
		explorer.tilt = -down * math.pi / 2
		explorer.at += v(0, 0.5 * math.sin(down * math.pi / 2) + (if a < 16.4 then 1.2 * math.sin(u * math.pi) else 0), 0)
		arm(explorer, 1, 2.6, 0.3, down)
		arm(explorer, 2, 2.6, 0.3, down)
		arm(explorer, 2, 2.4, 0.2, window(a, 15.6, 16.0, 0.2))
		-- Dusting off: the free hand pats down his front.
		local dust = window(a, 19.0, 20.2, 0.25)
		arm(explorer, 1, 0.5 + 0.35 * math.abs(math.sin(a * 8)), -0.3, dust)
		explorer.nod -= 0.25 * dust
		arm(explorer, 2, 2.9, 0.2, window(a, 20.2, cut + 1.4, 0.4))
		clap(explorer, a, window(a, cut + 1.4, cut + 3, 0.3))
	end
	if a < SWAP then
		things.PropIdol = IDOL_ON_PEDESTAL
		explorer.hold = "PropSandbag"
	elseif a < SWAP + SWAP_LEN then
		things.PropIdol = handOff(IDOL_ON_PEDESTAL, gripCF(explorer, "PropIdol"), a, SWAP, SWAP_LEN)
		things.PropSandbag = handOff(gripCF(explorer, "PropSandbag"), SANDBAG_ON_PEDESTAL, a, SWAP, SWAP_LEN)
	else
		explorer.hold = "PropIdol"
		things.PropSandbag = SANDBAG_ON_PEDESTAL
	end
	if a >= DART_AT and a < DART_AT + DART_LEN then
		things.PropDart = CFrame.new(DART_FROM:Lerp(DART_TO, span(a, DART_AT, DART_AT + DART_LEN))) * yawCF(-90)
	end
	-- A second dart a beat later, over the back of his head.
	local second = DART_AT + 0.3
	if a >= second and a < second + DART_LEN then
		things.PropDart2 = CFrame.new(DART_FROM:Lerp(DART_TO, span(a, second, second + DART_LEN)) + v(0, 0.7, 2)) * yawCF(-90)
	end
	if a >= DART_AT + 0.2 and a < DART_AT + 1.4 then
		say.Explorer = "Whoa!"
	elseif a >= 9.1 and a < 9.9 then
		say.Explorer = "Hmm..."
	elseif a >= 20.3 and a < 21.5 then
		say.Explorer = "Ta-da!"
	end
	things.PropBoulder = boulderCF(boulderZ(a))

	-- The guide: holds the torch, points the way, worries, shouts and runs for cover.
	local guide = planPose(GUIDE_RUN, a)
	guide.hold = "PropTorch"
	arm(guide, 2, 1.9, 0, 1 - window(a, 0.4, 2.2, 0.3) - window(a, 12.0, 14.6, 0.3))
	arm(guide, 2, 2.6, 0.1, window(a, 0.4, 2.2, 0.3)) -- the torch up toward the shrine
	arm(guide, 2, 2.4, 0.3, window(a, 12.0, 14.6, 0.3))
	guide.head += 0.4 * math.sin(a * 3) * (window(a, 2.6, 5.2, 0.4) + window(a, 6.8, 9.0, 0.4))
	local gasp = window(a, DART_AT, DART_AT + 1.2, 0.2)
	arm(guide, 1, 2.7, 0.4, gasp)
	guide.lean -= 0.15 * gasp
	local cower = window(a, 14.6, 17.4, 0.35)
	arm(guide, 1, 2.9, -0.3, cower)
	guide.lean += 0.25 * cower
	local cheer = window(a, 19.4, cut + 1, 0.35)
	arm(guide, 1, 2.8, 0.5, cheer)
	clap(guide, a, window(a, cut + 1, cut + 3, 0.3) * 0.5)
	if a >= 0.4 and a < 2.2 then
		say.Guide = "The idol... up there!"
	elseif a >= 3.0 and a < 4.8 then
		say.Guide = "Careful, boss..."
	elseif a >= DART_AT and a < DART_AT + 1.0 then
		say.Guide = "Look out!"
	elseif a >= RUMBLE and a < 12.0 then
		say.Guide = "Uh oh..."
	elseif a >= 12.0 and a < 13.4 then
		say.Guide = "RUN!!!"
	end
	poses.Explorer, poses.Guide = explorer, guide
end

local GUIDE_PUSH_SPEED = 2.6
local PUSH_GAP = BOULDER_R + 1.2 -- the guide's feet behind the boulder's middle while he pushes

-- After the take the explorer carries the idol back up, swaps it back for the sandbag and waits
-- aside, and the guide pushes the boulder back up the steps into the doorway.
local function explorerBack(endA: number, _from: Pose, t0: number, to: Mark, plan: Plan, touch: (Plan) -> ())
	if endA >= SWAP then
		go(plan, { v(27, GROUND, 78.6), IDOL_REACH }, 180)
		plan.keys.place = plan.t
		act(plan, 1.3, function(_u, s, q)
			arm(q, 2, 1.4, 0, window(s, plan.keys.place, plan.keys.place + 1.3, 0.4))
		end)
		go(plan, { v(20.5, GROUND, 79.5), v(20.5, GROUND, 73.5), v(16.5, GROUND, 72) }, 30)
		-- Waits for the boulder to roll past before walking to the mark.
		waitUntil(plan, t0 + 13.5)
	end
	go(plan, { to.at }, to.yaw)
	touch(plan)
end

local function guideBack(endA: number, _from: Pose, t0: number, to: Mark, plan: Plan, _touch: (Plan) -> ())
	if endA < BOULDER_OUT then
		go(plan, { to.at }, to.yaw)
		return
	end
	local behind = BOULDER_STOP - PUSH_GAP
	-- Round the boulder's right side, between it and the boom, to get behind it.
	go(plan, { v(29.4, GROUND, 68.6), v(29.4, GROUND, 63), v(24, GROUND, behind) }, 180)
	-- The push: he walks behind the boulder all the way up to the doorway.
	waitUntil(plan, t0 + 6)
	plan.keys.push0 = plan.t
	go(plan, { v(24, GROUND, DOOR_Z - PUSH_GAP) }, 180, GUIDE_PUSH_SPEED, 1.3)
	plan.keys.push1 = plan.t
	act(plan, 0.6, function() end)
	go(plan, { v(29, TOP_Y, 90.5), v(27.2, GROUND, 78.6), to.at }, to.yaw)
end

local function jungleThings(endA: number, s: number, t0: number, frame: Frame, plans: { [string]: Plan })
	local things = frame.things
	local explorer = frame.poses.Explorer
	things.PropDart, things.PropDart2 = nil, nil
	-- The idol: carried up and swapped back for the sandbag on its pedestal.
	local place = plans.Explorer.keys.place
	if endA >= SWAP and place ~= nil then
		local swap = place + 0.5
		if s < swap then
			things.PropIdol, things.PropSandbag = nil, SANDBAG_ON_PEDESTAL
			explorer.hold = "PropIdol"
			arm(explorer, 2, 2.9, 0.2, window(s, t0, place + 0.4, 0.4))
		elseif s < swap + SWAP_LEN then
			explorer.hold = nil
			things.PropIdol = handOff(gripCF(explorer, "PropIdol"), IDOL_ON_PEDESTAL, s, swap, SWAP_LEN)
			things.PropSandbag = handOff(SANDBAG_ON_PEDESTAL, gripCF(explorer, "PropSandbag"), s, swap, SWAP_LEN)
		else
			things.PropIdol, things.PropSandbag = IDOL_ON_PEDESTAL, nil
			explorer.hold = "PropSandbag"
		end
	else
		things.PropIdol, things.PropSandbag = IDOL_ON_PEDESTAL, nil
		explorer.hold = "PropSandbag"
	end
	-- The boulder: rolled back up to the doorway in front of the guide.
	local keys = plans.Guide.keys
	if endA >= BOULDER_OUT and keys.push0 ~= nil then
		local guide = frame.poses.Guide
		local z = BOULDER_STOP
		if s >= keys.push1 then
			z = DOOR_Z
		elseif s >= keys.push0 then
			z = math.clamp(guide.at.Z + PUSH_GAP, BOULDER_STOP, DOOR_Z)
			arm(guide, 1, 1.5, -0.1, window(s, keys.push0, keys.push1, 0.3))
		end
		things.PropBoulder = boulderCF(z)
	else
		things.PropBoulder = boulderCF(DOOR_Z)
	end
end

local JUNGLE_SCENES: { Scene } = {
	{
		number = 1,
		actors = { "Explorer", "Guide" },
		places = {
			Explorer = { at = EXPLORER_PLACES, yaw = 180 },
			Guide = { at = GUIDE_PLACES, yaw = 180 },
		},
		story = jungleStory,
		cut = 21.8,
		length = 24.8,
		safe = { 0, 5.2 },
		blooper = { at = 5.2, who = "Explorer" },
		mic = { "Explorer", "Guide" },
		aim = v(24, 5, 80),
		boom = { at = v(31.5, GROUND, 64.5), yaw = 0 },
		notes = { at = v(17, GROUND, 68.5), yaw = 180 },
		touch = { who = "Explorer", at = v(24.4, GROUND, 75.4), yaw = SHOT_SIDE, wait = 12, via = { v(24.5, GROUND, 71) } },
		rehearse = { Explorer = { v(24, GROUND, 77.5), v(24, GROUND, 84) } },
		reset = { Explorer = explorerBack, Guide = guideBack },
		things = jungleThings,
		dress = function(frame: Frame)
			local guide = frame.poses.Guide
			guide.hold = "PropTorch"
			arm(guide, 2, 1.9, 0, 1)
			frame.poses.Explorer.hold = "PropSandbag"
		end,
	},
}


-- The slots ------------------------------------------------------------------------------------
-- A set plays a fixed cycle of slots (a rehearsal and three takes per scene). Each slot's plan is
-- worked out once: the crew's moves, and the walk back from wherever the take left everyone.

type Outcome = string -- "clean", "blooper", "early" (stopped by the owner's cue) or "rehearsal"

type SlotPlan = {
	outcome: Outcome,
	scene: Scene,
	nextScene: Scene,
	endA: number, -- the story time whose poses the reset starts from
	cutAt: number, -- slot time of "CUT!"
	resetAt: number, -- slot time the reset starts
	length: number,
	plans: { [string]: Plan },
	dollyEnd: number, -- how far along its track the dolly got
	dollyBack: number, -- slot time it starts rolling back
}

type Slot = { kind: string, scene: number, k: number, start: number, stop: number, plan: SlotPlan }

type SetDef = {
	id: string,
	crew: Crew,
	scenes: { Scene },
	cycle: { Slot },
	period: number,
	cast: { string },
	seeds: { [string]: number },
}

local function blankFrame(): Frame
	return { scene = 1, take = 1, time = 0, phase = "take", poses = {}, stick = 0, say = {}, things = {}, beatAt = 0 }
end

-- Where the gaffer stands to adjust the lamp: just behind it, facing the way it shines.
local function lampSpot(crew: Crew): Vector3
	return offset(crew.lamp.at, crew.lamp.yaw, 0.4, -1.7)
end

local function noTouch(_p: Plan) end

local function crewPlans(crew: Crew, plans: { [string]: Plan })
	plans.Director = newPlan(crew.director.at, crew.director.yaw, 0, crew.ground)
	plans.Clapper = newPlan(crew.clapper.at, crew.clapper.yaw, 0, crew.ground)
	plans.Gaffer = newPlan(crew.gaffer.at, crew.gaffer.yaw, 0, crew.ground)
	plans.Makeup = newPlan(crew.makeup.at, crew.makeup.yaw, 0, crew.ground)
end

local function takePlan(set: SetDef, scene: Scene, nextScene: Scene, outcome: Outcome, early: number?): SlotPlan
	local crew = set.crew
	local cutA, stopA, endA
	if outcome == "clean" then
		cutA, stopA, endA = scene.cut, scene.length, scene.length
	elseif outcome == "blooper" then
		cutA, stopA, endA = scene.blooper.at + 1.4, scene.blooper.at + GAG, scene.blooper.at
	else
		local at = early or 0
		cutA, stopA, endA = at, at, at
	end
	local cutAt, resetAt = STORY + cutA, STORY + stopA
	local plans: { [string]: Plan } = {}
	crewPlans(crew, plans)

	-- The clapper loader: out to the slate mark, slates the take, back again.
	local clapper = plans.Clapper
	waitUntil(clapper, 0.2)
	goBy(clapper, { crew.slate.at }, crew.slate.yaw, SLATE_AT)
	waitUntil(clapper, SNAP + 0.3)
	go(clapper, { crew.clapper.at }, crew.clapper.yaw, 5)

	-- The make-up artist sets off for the touch-up as soon as the reset starts; the actor who gets
	-- it waits on their spot until she is there.
	local touch = nextScene.touch
	local makeup = plans.Makeup
	waitUntil(makeup, resetAt + (touch.wait or 0.8))
	local route = table.clone(touch.via or {})
	table.insert(route, touch.at)
	go(makeup, route, touch.yaw)
	local arrive = makeup.t
	local touchStart = arrive
	local function touchFn(p: Plan)
		local start = math.max(p.t, arrive)
		p.keys.touch = start
		touchStart = start
		waitUntil(p, start + TOUCH)
	end

	-- The actors, back to their marks for the next slot.
	local ends = blankFrame()
	scene.story(endA, ends, scene.cut)
	for i, who in scene.actors do
		local from = ends.poses[who]
		local to = nextScene.places[who]
		local p = newPlan(from.at, from.yaw, resetAt + (i - 1) * 0.7, crew.ground)
		local custom = if scene.reset ~= nil then scene.reset[who] else nil
		local t = if who == touch.who then touchFn else noTouch
		if custom ~= nil then
			custom(endA, from, resetAt, to, p, t)
		else
			local routes = if nextScene ~= scene or scene.number == nextScene.number and #set.scenes == 1 then scene.routes else nil
			local route = table.clone(if routes ~= nil and routes[who] ~= nil then routes[who] else {})
			table.insert(route, to.at)
			go(p, route, to.yaw)
			t(p)
		end
		plans[who] = p
	end
	waitUntil(makeup, touchStart)
	makeup.keys.touch = touchStart
	act(makeup, TOUCH, function() end)
	local home = {}
	for i = #route - 1, 1, -1 do
		table.insert(home, route[i])
	end
	table.insert(home, crew.makeup.at)
	go(makeup, home, crew.makeup.yaw)

	-- The director's notes: over to the actors, a word, and back.
	local director = plans.Director
	if outcome ~= "early" then
		waitUntil(director, cutAt + (if outcome == "clean" then 3.6 else 2.4))
		go(director, { scene.notes.at }, scene.notes.yaw)
		director.keys.notes = director.t
		act(director, 2.8, function() end)
		go(director, { crew.director.at }, crew.director.yaw)
	end

	-- The lighting tech tweaks the lamp.
	local gaffer = plans.Gaffer
	waitUntil(gaffer, resetAt + 1.4)
	go(gaffer, { lampSpot(crew) }, crew.lamp.yaw)
	gaffer.keys.adjust = gaffer.t
	act(gaffer, 2.6, function() end)
	go(gaffer, { crew.gaffer.at }, crew.gaffer.yaw)

	local dollyEnd = smooth(span(cutAt, STORY, STORY + scene.cut))
	local dollyBack = resetAt + crew.dollyBack

	-- The boom operator moves to the next scene's spot once the camera has turned to it.
	local boom = newPlan(scene.boom.at, facing(scene.boom.at, scene.aim), 0, crew.ground)
	if (nextScene.boom.at - scene.boom.at).Magnitude > 0.1 then
		waitUntil(boom, dollyBack + 4)
		go(boom, { nextScene.boom.at }, facing(nextScene.boom.at, nextScene.aim))
		plans.Boom = boom
	end
	local length = dollyBack + 4
	for _, p in plans do
		length = math.max(length, planEnd(p))
	end
	return {
		outcome = outcome,
		scene = scene,
		nextScene = nextScene,
		endA = endA,
		cutAt = cutAt,
		resetAt = resetAt,
		length = length + 0.8,
		plans = plans,
		dollyEnd = dollyEnd,
		dollyBack = dollyBack,
	}
end

local function rehearsalPlan(set: SetDef, scene: Scene): SlotPlan
	local crew = set.crew
	local plans: { [string]: Plan } = {}
	crewPlans(crew, plans)
	local done = 0
	for who, mark in scene.places do
		local p = newPlan(mark.at, mark.yaw, 2.8, crew.ground)
		local path = scene.rehearse[who]
		if path ~= nil then
			go(p, path, nil, SLOW)
			act(p, 1.2, function() end)
			local back = {}
			for i = #path - 1, 1, -1 do
				table.insert(back, path[i])
			end
			table.insert(back, mark.at)
			go(p, back, mark.yaw, SLOW)
		end
		plans[who] = p
		done = math.max(done, p.t)
	end
	local director = plans.Director
	waitUntil(director, 2.6)
	go(director, { scene.notes.at }, scene.notes.yaw)
	director.keys.notes = director.t
	act(director, math.max(1, done - director.t), function() end)
	go(director, { crew.director.at }, crew.director.yaw)
	local length = 0
	for _, p in plans do
		length = math.max(length, planEnd(p))
	end
	return {
		outcome = "rehearsal",
		scene = scene,
		nextScene = scene,
		endA = 0,
		cutAt = math.huge,
		resetAt = 0,
		length = length + 3.2,
		plans = plans,
		dollyEnd = 0,
		dollyBack = math.huge,
	}
end

local function buildSet(id: string, crew: Crew, scenes: { Scene }, cast: { string }): SetDef
	local set: SetDef = { id = id, crew = crew, scenes = scenes, cycle = {}, period = 0, cast = cast, seeds = {} }
	for i, who in cast do
		set.seeds[who] = i * 1.37
	end
	for si in scenes do
		table.insert(set.cycle, { kind = "rehearsal", scene = si, k = 0, start = 0, stop = 0, plan = (nil :: any) })
		for k = 1, 3 do
			table.insert(set.cycle, { kind = "take", scene = si, k = k, start = 0, stop = 0, plan = (nil :: any) })
		end
	end
	local t = 0
	for i, slot in set.cycle do
		local scene = scenes[slot.scene]
		local nextSlot = set.cycle[i % #set.cycle + 1]
		slot.plan = if slot.kind == "rehearsal"
			then rehearsalPlan(set, scene)
			else takePlan(set, scene, scenes[nextSlot.scene], if slot.k == 2 then "blooper" else "clean")
		slot.start = t
		t += slot.plan.length
		slot.stop = t
	end
	set.period = t
	return set
end

-- The slot playing at time `t` on a clock that started at `anchor`: its cycle number, its index
-- in the cycle, and when it started.
local function locate(set: SetDef, t: number, anchor: number): (number, number, number)
	local tau = t - anchor
	local n = math.floor(tau / set.period)
	local into = tau - n * set.period
	for i, slot in set.cycle do
		if into < slot.stop then
			return n, i, anchor + n * set.period + slot.start
		end
	end
	return n, #set.cycle, anchor + n * set.period + set.cycle[#set.cycle].start
end

-- Takes stopped early by a cue, worked out once.
local earlyPlans: { [string]: SlotPlan } = {}

local function earlyPlan(set: SetDef, index: number, cut: number): SlotPlan
	local key = `{set.id}:{index}:{cut}`
	local plan = earlyPlans[key]
	if plan == nil then
		local slot = set.cycle[index]
		local nextSlot = set.cycle[index % #set.cycle + 1]
		plan = takePlan(set, set.scenes[slot.scene], set.scenes[nextSlot.scene], "early", cut)
		earlyPlans[key] = plan
	end
	return plan
end

-- The poses ------------------------------------------------------------------------------------

-- A blooper on top of the actor's frozen pose: `u` seconds in.
local function blooper(kind: string, scene: Scene, frame: Frame, u: number)
	local who = scene.blooper.who
	local p = frame.poses[who]
	local w = window(u, 0, GAG, 0.4)
	if kind == "trip" then
		-- A stumble: he trips, staggers forward with arms windmilling and catches himself.
		local lurch = window(u, 0, 2.2, 0.35)
		p.lean += 0.7 * lurch
		p.at += v(0, 0.35 * math.sin(math.pi * span(u, 0, 0.6)), 0)
		p.legs[1] += 0.45 * lurch
		p.legs[2] -= 0.25 * lurch
		local spin = math.sin(u * 13) * 0.6
		arm(p, 1, 2.2 + spin, 0.9, w)
		arm(p, 2, 2.2 - spin, 0.9, w)
		frame.say[who] = if u < 1.5 then "Whoa!" else "Oops! Sorry!"
	elseif kind == "line" then
		arm(p, 2, 2.75 + math.sin(u * 9) * 0.08, -0.55, w) -- scratching his head
		p.head += 0.3 * w
		p.nod += 0.15 * w
		frame.say[who] = "Uh... what's my line?"
	else
		for _, other in scene.actors do
			local q = frame.poses[other]
			q.bob += 0.07 * math.abs(math.sin(u * 16)) * w
			q.nod += 0.3 * w
			q.lean -= 0.1 * w
			arm(q, 1, 0.6, -0.45, w)
			arm(q, 2, 0.6, -0.45, w)
			frame.say[other] = if other == who then "Hahaha! Sorry!" else "Hehe!"
		end
	end
end

local function mean(points: { Vector3 }): Vector3
	local sum = Vector3.zero
	for _, q in points do
		sum += q
	end
	return sum / math.max(1, #points)
end

-- The crew at slot time `s`.
local function crewPoses(set: SetDef, plan: SlotPlan, s: number, frame: Frame, greet: boolean, press: number?)
	local crew, scene = set.crew, plan.scene
	local plans, poses, say = plan.plans, frame.poses, frame.say
	local rehearsal = plan.outcome == "rehearsal"

	-- The director.
	local director = planPose(plans.Director, s)
	director.hold = "PropMegaphone"
	director.level = true
	local call = window(s, QUIET, QUIET + 2.2, 0.3)
	if greet then
		waveLeft(director, s, window(s, QUIET, QUIET + 2.8, 0.35))
	end
	if call > 0 then
		say.Director = if rehearsal then "Rehearsal! Nice and easy." elseif greet then "Places everyone!" else "Quiet on set!"
	end
	if not rehearsal then
		local action = window(s, ACTION, ACTION + 1.4, 0.25)
		local cut = window(s, plan.cutAt, plan.cutAt + 1.6, 0.25)
		call = math.max(call, action, cut)
		if action > 0 then
			say.Director = "ACTION!"
		elseif cut > 0 then
			say.Director = if plan.outcome == "clean" then "CUT! Print it!" elseif plan.outcome == "blooper" then "CUT! Cut!" else "CUT! Back to one!"
		end
		if plan.outcome == "clean" then
			clap(director, s, window(s, plan.cutAt + 1.6, plan.cutAt + 3.4, 0.3))
		elseif plan.outcome == "blooper" then
			arm(director, 1, 2.6, -0.65, window(s, plan.cutAt + 1.6, plan.cutAt + 2.9, 0.3)) -- face palm
		end
	end
	arm(director, 2, 1.85, -0.45, call) -- the megaphone up at his mouth
	local notes = plans.Director.keys.notes
	if notes ~= nil then
		local length = if rehearsal then plans.Director.moves[#plans.Director.moves - 1].t1 - notes else 2.8
		local w = window(s, notes - 0.2, notes + length + 0.2, 0.4)
		explain(director, s, w)
		if w > 0.5 then
			say.Director = if rehearsal
				then (if s - notes < length / 2 then "Walk it through..." else "...and hit your mark!")
				elseif plan.outcome == "clean" then "Lovely! One more!"
				else "Shake it off. Again!"
		end
	end
	if rehearsal and s > plan.length - 3.0 and s < plan.length - 0.8 then
		say.Director = "Great. Let's shoot it!"
	end

	-- The clapper loader.
	local clapper = planPose(plans.Clapper, s)
	clapper.hold = "PropClapper"
	arm(clapper, 2, 0.35, 0.15, 1)
	if not rehearsal then
		local up = window(s, 2.6, SNAP + 0.5, 0.35)
		arm(clapper, 2, 1.5, 0.1, up)
		arm(clapper, 1, 1.2, -0.35, up) -- the other hand on the stick
		frame.stick = if s < SNAP - 0.05 then 0.55 * smooth(span(s, 2.8, 3.2)) else 0.55 * (1 - span(s, SNAP - 0.05, SNAP + 0.03))
		if s >= SLATE_AT and s < SNAP - 0.1 then
			say.Clapper = `Scene {scene.number}, take {frame.take}!`
		end
		if plan.outcome == "clean" then
			clap(clapper, s, window(s, plan.cutAt + 1.0, plan.cutAt + 3.0, 0.3))
		end
	end
	if press ~= nil and s >= press and s < press + 2.2 and say.Clapper == nil then
		say.Clapper = "Right away, boss!"
	end

	-- The camera: the dolly rolls along its track during the take and back after it, and the
	-- crane arm rises with it; the camera points at the action.
	local track = crew.operatorTrack
	local u = 0
	if not rehearsal then
		u = smooth(span(math.min(s, plan.cutAt), STORY, STORY + scene.cut))
		u *= 1 - smooth(span(s, plan.dollyBack, plan.dollyBack + 4))
	end
	local back = if rehearsal then 0 else smooth(span(s, plan.dollyBack, plan.dollyBack + 4))
	local aim = scene.aim:Lerp(plan.nextScene.aim, back)
	local dollyAt = track.from:Lerp(track.to, u)
	local pivot = dollyAt + v(0, JIB_PIVOT, 0)
	local jibYaw = facing(pivot, aim)
	local lift = mix(-0.04, 0.28, u)
	local jib = CFrame.new(pivot) * yawCF(jibYaw) * CFrame.Angles(lift, 0, 0)
	frame.things.CrewDolly = CFrame.new(dollyAt) * yawCF(facing(track.from, track.to))
	frame.things.CrewJibArm = jib
	frame.things.CrewCameraHead = CFrame.new((jib * CFrame.new(0, 0, -JIB_FRONT)).Position) * yawCF(jibYaw)

	-- The operator rides the dolly behind the crane's hinge, hands on its handle bar.
	local operator = pose(offset(dollyAt, jibYaw, 0, -1.65) + v(0, PLATFORM, 0), jibYaw)
	operator.ride = true
	for i, side in { -1, 1 } do
		local grip = (jib * CFrame.new(side * 0.6, -0.95, 0.98)).Position
		local sw, out = reach(operator, i, grip)
		operator.arms[i][1], operator.arms[i][2] = sw, out
	end
	if plan.outcome == "clean" then
		clap(operator, s, window(s, plan.cutAt + 1.2, plan.cutAt + 3.0, 0.3))
	end

	-- The boom operator: the pole up over the actors while the camera rolls, resting otherwise.
	local boom = if plans.Boom ~= nil then planPose(plans.Boom, s) else pose(scene.boom.at, facing(scene.boom.at, aim))
	boom.hold = "PropBoomPole"
	local heads = {}
	for _, who in scene.mic do
		local q = poses[who]
		if q ~= nil and not q.hidden then
			table.insert(heads, q.at + v(0, 8.4, 0))
		end
	end
	local up = if rehearsal then window(s, 2.4, plan.length - 1.4, 0.9) else window(s, STORY - 1.8, plan.cutAt + 1.2, 0.9)
	local rest = offset(boom.at, boom.yaw, 0.8, 3) + v(0, 10, 0)
	local target = rest:Lerp(if #heads > 0 then mean(heads) else rest, up)
	local sw, out = reach(boom, 2, target)
	boom.arms[2][1], boom.arms[2][2] = sw, out
	local dir = (target - hand(boom, 2)).Unit
	sw, out = reach(boom, 1, hand(boom, 2) + dir * 1.6)
	boom.arms[1][1], boom.arms[1][2] = sw, out
	boom.aim = target
	boom.head += 0.25 * up * math.sin(s * 0.7)
	boom.nod += 0.35 * up

	-- The lighting tech and the lamp.
	local gaffer = planPose(plans.Gaffer, s)
	local lampYaw, lampTilt = crew.lamp.yaw, -0.12
	local adjust = plans.Gaffer.keys.adjust
	if adjust ~= nil then
		local w = window(s, adjust - 0.2, adjust + 2.6, 0.45)
		local k = span(s, adjust + 0.3, adjust + 2.3)
		lampYaw += 12 * math.sin(k * math.pi * 2) * w
		lampTilt += 0.08 * math.sin(k * math.pi) * w
		local head = CFrame.new(crew.lamp.at + v(0, LAMP_PIVOT, 0)) * yawCF(lampYaw)
		for i, side in { -1, 1 } do
			local swing, wide = reach(gaffer, i, (head * CFrame.new(side * 0.85, 0.55, 0.1)).Position)
			arm(gaffer, i, swing, wide, w)
		end
		gaffer.nod += 0.4 * w
	end
	frame.things.CrewLightHead = CFrame.new(crew.lamp.at + v(0, LAMP_PIVOT, 0)) * yawCF(lampYaw) * CFrame.Angles(lampTilt, 0, 0)

	-- The make-up artist.
	local makeup = planPose(plans.Makeup, s)
	makeup.hold = "PropMakeupBrush"
	arm(makeup, 2, 0.5, 0.1, 1)
	local touch = plans.Makeup.keys.touch
	if touch ~= nil then
		local w = window(s, touch, touch + TOUCH, 0.4)
		arm(makeup, 2, 1.95 + math.sin(s * 12) * 0.12, -0.2, w)
		arm(makeup, 1, 1.3, -0.1, w * 0.6)
		if w > 0.5 then
			say.Makeup = "Hold still, darling!"
		end
	end

	poses.Director, poses.Clapper, poses.Operator, poses.Boom, poses.Gaffer, poses.Makeup = director, clapper, operator, boom, gaffer, makeup
end

-- Where everyone is on `set` at time `t`, with the owner's `cue` (if any).
local function frameAt(set: SetDef, t: number, cue: Cue?): Frame
	local anchor = 0
	if cue ~= nil then
		anchor = if t < cue.from then cue.old else cue.new
	end
	local n, index, start = locate(set, t, anchor)
	local slot = set.cycle[index]
	local plan = slot.plan
	if cue ~= nil and cue.cut >= 0 and t < cue.from and math.abs(start - cue.slot) < 1e-3 then
		plan = earlyPlan(set, index, cue.cut)
	end
	local greet = cue ~= nil and math.abs(start - cue.from) < 1e-3
	local press = if cue ~= nil and cue.press then cue.at - start else nil
	local s = t - start
	local scene = plan.scene
	local takeOffset = (n % 3) * 3
	local frame: Frame = {
		scene = scene.number,
		take = takeOffset + (if slot.kind == "rehearsal" then 1 else slot.k),
		time = s,
		phase = slot.kind,
		poses = {},
		stick = 0,
		say = {},
		things = {},
		beatAt = 0,
	}

	-- The actors.
	if plan.outcome == "rehearsal" or s >= plan.resetAt then
		if plan.outcome ~= "rehearsal" then
			-- The props as the take left them, unless the reset moves them.
			local ends = blankFrame()
			scene.story(plan.endA, ends, scene.cut)
			frame.things = ends.things
		else
			scene.story(0, frame, scene.cut)
		end
		for _, who in scene.actors do
			frame.poses[who] = planPose(plan.plans[who], s)
		end
		local dress = scene.dress
		if dress ~= nil then
			dress(frame)
		end
		local things = scene.things
		if things ~= nil and plan.outcome ~= "rehearsal" then
			things(plan.endA, s, plan.resetAt, frame, plan.plans)
		end
	else
		local a = math.max(0, s - STORY)
		local stop = if plan.outcome == "clean" then scene.length else plan.endA
		scene.story(math.min(a, stop), frame, scene.cut)
		if plan.outcome == "blooper" and a >= plan.endA then
			blooper(BLOOPERS[n % #BLOOPERS + 1], scene, frame, a - plan.endA)
		end
	end
	crewPoses(set, plan, s, frame, greet, press)

	-- The moment's sound, if one just happened.
	local beats = if plan.outcome == "rehearsal"
		then {}
		else { { "places", QUIET, "Director" }, { "snap", SNAP, "Clapper" }, { "action", ACTION, "Director" }, { "cut", plan.cutAt, "Director" }, { "cheer", plan.cutAt + 1.0, "Director" } }
	for _, b in beats do
		local at = b[2] :: number
		if s >= at and s - at < 0.5 and (b[1] ~= "cheer" or plan.outcome == "clean") and (b[1] ~= "places" or greet) then
			frame.beat, frame.beatAt, frame.beatWho = b[1] :: string, start + at, b[3] :: string
		end
	end

	for who, p in frame.poses do
		if not p.hidden then
			breathe(p, t, set.seeds[who] or 0)
		end
	end
	return frame
end

-- The owner's cue on set `id` at server time `now`, after `previous` (or nil while one is still
-- pending). `press` is the owner calling "Action!" at the clapper: a take that is rolling stops
-- at the next moment everyone stands still. Either way the next slot greets the owner.
function FilmScenes.cue(id: string, previous: Cue?, now: number, press: boolean): Cue?
	local set = (FilmScenes :: any)._defs[id] :: SetDef
	assert(set ~= nil, `no film set scenes called {id}`)
	if previous ~= nil and now < previous.from then
		return nil
	end
	local old = if previous ~= nil then previous.new else 0
	local n, index, start = locate(set, now, old)
	local slot = set.cycle[index]
	local plan = slot.plan
	local cut = -1
	local from = start + plan.length
	if press and slot.kind == "take" then
		local a = now - start - STORY
		local scene = plan.scene
		local own = if slot.k == 2 then scene.blooper.at else scene.cut
		if a >= 0.5 then
			for _, safe in scene.safe do
				if safe >= a + 0.8 and safe < own then
					cut = safe
					break
				end
			end
		end
		if cut >= 0 then
			from = start + earlyPlan(set, index, cut).length
		end
	end
	local nextStart = if index < #set.cycle then set.cycle[index + 1].start else set.period
	return { at = now, from = from, slot = start, old = old, new = from - (n * set.period + nextStart), cut = cut, press = press }
end

-- A cue as the text FilmSetService publishes (a workspace attribute), and back.
function FilmScenes.cueText(cue: Cue): string
	return string.format("%.3f %.3f %.3f %.3f %.3f %.2f %d", cue.at, cue.from, cue.slot, cue.old, cue.new, cue.cut, if cue.press then 1 else 0)
end

function FilmScenes.parseCue(text: any): Cue?
	if type(text) ~= "string" then
		return nil
	end
	local parts = string.split(text, " ")
	if #parts ~= 7 then
		return nil
	end
	local nums = {}
	for i, part in parts do
		local x = tonumber(part)
		if x == nil or x ~= x then
			return nil
		end
		nums[i] = x
	end
	return { at = nums[1], from = nums[2], slot = nums[3], old = nums[4], new = nums[5], cut = nums[6], press = nums[7] == 1 }
end

-- The sets -------------------------------------------------------------------------------------

local CREW = { "Director", "Clapper", "Operator", "Boom", "Gaffer", "Makeup" }
local CREW_PROPS = {
	Director = { "PropMegaphone" },
	Clapper = { "PropClapper" },
	Boom = { "PropBoomPole" },
	Makeup = { "PropMakeupBrush" },
}

local function castOf(actors: { string }): { string }
	local list = table.clone(CREW)
	for _, who in actors do
		table.insert(list, who)
	end
	return list
end

local function propsWith(extra: { [string]: { string } }): { [string]: { string } }
	local props = table.clone(CREW_PROPS)
	for who, kits in extra do
		props[who] = kits
	end
	return props
end

local GULCH_GEAR: { Gear } = {
	{ kit = "CrewDollyTrack", at = v(9.5, 0.2, 113.5), yaw = 0 },
	{ kit = "DirectorChair", at = v(11.6, 0.2, 103), yaw = 90, label = "DIRECTOR" },
	{ kit = "CrewLightStand", at = GULCH.lamp.at, yaw = 0 },
	{ kit = "CrewMakeupKit", at = v(6, 0.2, 97.4), yaw = 0 },
	-- The stunt double's landing, under the hotel balcony, and the hotel's doors stood open.
	{ kit = "HayBale", at = v(-7.7, 0.2, 114), yaw = 90 },
	{ kit = "HayBale", at = v(-10.3, 0.2, 114), yaw = 90 },
	{ kit = "CrewOpenDoor", at = v(-18.8, BOARDWALK, 114), yaw = -90 },
	{ kit = "CrewBalconyDoor", at = v(-18.8, BALCONY, 114), yaw = -90 },
}

local defs: { [string]: SetDef } = {
	Gulch = buildSet("Gulch", GULCH, GULCH_SCENES, castOf({ "Sheriff", "Outlaw", "Stunt" })),
	MoonBase = buildSet("MoonBase", MOON, MOON_SCENES, castOf({ "Astronaut", "Alien" })),
	Jungle = buildSet("Jungle", JUNGLE, JUNGLE_SCENES, castOf({ "Explorer", "Guide" })),
}
;(FilmScenes :: any)._defs = defs

local function sceneSet(id: string, extraProps: { [string]: { string } }, things: { string }, gear: { Gear }, centre: Vector3): SetScenes
	local set = defs[id]
	local all = table.clone(RIG_THINGS)
	for _, kit in things do
		table.insert(all, kit)
	end
	return {
		cast = set.cast,
		props = propsWith(extraProps),
		things = all,
		gear = gear,
		centre = centre,
		period = set.period,
		frame = function(t: number, cue: Cue?): Frame
			return frameAt(set, t, cue)
		end,
	}
end

FilmScenes.Sets = table.freeze({
	Gulch = sceneSet("Gulch", { Sheriff = { "PropRevolver" }, Outlaw = { "PropRevolver" } }, {}, GULCH_GEAR, v(0, 0, 114)),
	MoonBase = sceneSet("MoonBase", { Astronaut = { "PropFlag" } }, { "PropFlag" }, MOON_GEAR, v(0, 0, 62)),
	Jungle = sceneSet("Jungle", { Explorer = { "PropIdol", "PropSandbag" }, Guide = { "PropTorch" } }, { "PropIdol", "PropBoulder", "PropSandbag", "PropDart", "PropDart2" }, JUNGLE_GEAR, v(24, 0, 72)),
}) :: { [string]: SetScenes }

-- Where everyone is on set `id` at time `t`, after the owner's `cue` (if any).
function FilmScenes.frame(id: string, t: number, cue: Cue?): Frame
	local set = FilmScenes.Sets[id]
	assert(set ~= nil, `no film set scenes called {id}`)
	return set.frame(t, cue)
end

return FilmScenes
