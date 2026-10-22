--!strict
-- Brings a mascot (MascotModels) to life by moving its pieces: the legs, tails, heads, ears,
-- hats, wings, arms, film reels, film tape, rocket flame and clapper jaw that the Blender designs
-- split it into (MascotShapes.Pieces, art/blender/mascots.py). Legs trot in diagonal pairs, tails
-- wag, heads look around, ears and hats jiggle when it lands, wings beat on the way up and glide
-- on the way down, reels spin, the Camera Bot's flame flickers and the Clapper Croc snaps its jaw.
--
-- The caller (MascotWorld) works out a Pose each frame from how the mascot is moving; this
-- module turns it into a CFrame for every part. It is plain CFrame maths, with no services, so
-- the tests and the preview tools run exactly the same code as the game.
local MascotShapes = require(script.Parent.MascotShapes)

local MascotRig = {}

export type Pose = {
	time: number, -- seconds, always running (idle motions)
	gait: number, -- stride phase in radians, advanced by the distance walked
	move: number, -- 0 standing still .. 1 trotting
	air: number, -- 0 on the ground .. 1 in the air
	vy: number, -- how fast it is going up, studs/s (negative is falling)
	land: number, -- 0 .. 1 .. 0 over the moment after landing
	jiggle: number, -- a spring that lags behind bumps (ears, hats), about -1 .. 1
	spin: number, -- radians turned by the spinning parts so far
	clap: number, -- 0 clapper jaw at rest .. 1 wide open (it snaps back to 0 for the "clap")
}

export type Rig = {
	pieces: { MascotShapes.Piece },
	pivots: { CFrame }, -- each piece's pivot, at the model's scale
	parts: { BasePart },
	piece: { number }, -- which piece each part belongs to
	rest: { CFrame }, -- each part relative to the mascot's feet, standing still
	restSize: { Vector3 },
	scale: number,
	moved: { CFrame }, -- each piece's transform this frame (scratch)
	sizes: { Vector3 }, -- each part's size this frame (only flames change it)
	cframes: { CFrame }, -- each part's world CFrame this frame (scratch)
}

function MascotRig.pose(): Pose
	return { time = 0, gait = 0, move = 0, air = 0, vy = 0, land = 0, jiggle = 0, spin = 0, clap = 0 }
end

-- A rig for `model`, a mascot built by MascotModels.build at `base` and `scale`: every part
-- carries a "Piece" attribute naming its piece. Nil for a mascot without pieces.
function MascotRig.new(model: Model, id: string, base: CFrame, scale: number): Rig?
	local pieces = MascotShapes.Pieces[id]
	if pieces == nil then
		return nil
	end
	local rig: Rig = {
		pieces = pieces,
		pivots = {},
		parts = {},
		piece = {},
		rest = {},
		restSize = {},
		scale = scale,
		moved = {},
		sizes = {},
		cframes = {},
	}
	for i, piece in pieces do
		rig.pivots[i] = CFrame.new(piece.pivot * scale)
		rig.moved[i] = CFrame.identity
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local index = d:GetAttribute("Piece")
			if type(index) ~= "number" or pieces[index] == nil then
				index = 1
			end
			table.insert(rig.parts, d)
			table.insert(rig.piece, index :: number)
			table.insert(rig.rest, base:ToObjectSpace(d.CFrame))
			table.insert(rig.restSize, d.Size)
			table.insert(rig.sizes, d.Size)
			table.insert(rig.cframes, d.CFrame)
		end
	end
	return rig
end

local function side(piece: MascotShapes.Piece): number
	return if piece.pivot.X >= 0 then 1 else -1
end

-- How one piece turns about its pivot this frame (before its parent piece moves it).
local function turn(piece: MascotShapes.Piece, p: Pose): CFrame
	local role = piece.role
	local amp = piece.amp
	local t = p.time - piece.phase * 0.12
	if role == "leg" then
		-- A trot: front-left with back-right, then the other pair. In the air the front legs
		-- reach forward and the back legs stretch out behind; a positive angle swings the foot
		-- forward.
		local front = piece.pivot.Z < 0
		local offset = if front == (side(piece) > 0) then 0 else math.pi
		local swing = math.sin(p.gait + offset) * 0.6 * p.move * (1 - p.air)
		local reach = (if front then 0.55 else -0.45) * p.air
		local splay = (if front then -0.15 else 0.15) * p.land
		return CFrame.Angles((swing + reach + splay) * amp, 0, 0)
	elseif role == "tail" then
		-- Wags all the time, faster while trotting; lifts in the air. A tail part further along
		-- (a larger phase) follows a moment later, so it swings like a whip.
		local rate = 6 + 5 * p.move
		local wag = math.sin(t * rate - piece.phase) * 0.32 * amp
		-- Only a little more lift further along, or a two-part tail would curl straight up.
		local lift = (-0.3 * p.air + p.jiggle * 0.25 + p.land * 0.2) / (1 + 2 * piece.phase)
		return CFrame.Angles(lift, wag, 0)
	elseif role == "head" then
		-- Looks around while it stands still, bobs while it trots, looks up on the way up and dips
		-- as it lands. `amp` lets the owl swivel much further than the others.
		local still = 1 - 0.75 * p.move
		local look = (math.sin(t * 0.55 + 1.3) * 0.6 + math.sin(t * 0.21) * 0.4) * 0.32 * amp * still
		local nod = math.sin(p.gait * 2) * 0.05 * p.move + math.clamp(p.vy * 0.008, -0.2, 0.2) * p.air - p.land * 0.22
		local tilt = math.sin(t * 0.9) * 0.06 * still
		return CFrame.Angles(nod, look, tilt)
	elseif role == "ear" then
		-- Floppy ears: flare out as it falls or lands, blow back as it runs, twitch now and then.
		local out = p.jiggle * 0.6 + p.air * 0.35 + math.max(0, math.sin(t * 1.7 + piece.pivot.X)) ^ 8 * 0.25
		return CFrame.Angles(-0.4 * p.move, 0, side(piece) * out * amp)
	elseif role == "hat" then
		return CFrame.Angles(p.jiggle * 0.22, 0, p.jiggle * 0.14 + math.sin(p.gait * 2) * 0.04 * p.move)
	elseif role == "wing" then
		-- Beats hard on the way up, spreads to glide on the way down, flutters while it walks.
		local beat: number
		if p.air > 0.5 and p.vy > 0 then
			beat = 0.25 + math.sin(t * 24) * 0.6
		elseif p.air > 0.5 then
			beat = 0.45 + math.sin(t * 9) * 0.12
		else
			beat = math.sin(p.gait) * 0.14 * p.move + math.sin(t * 2.2) * 0.05
		end
		return CFrame.fromAxisAngle(piece.axis, side(piece) * beat * amp)
	elseif role == "arm" then
		-- Swings while it moves, waves both arms up in the air.
		local swing = math.sin(p.gait + (if side(piece) > 0 then 0 else math.pi)) * 0.5 * p.move
		local idle = math.sin(t * 2 + piece.pivot.X) * 0.08
		return CFrame.Angles(swing + idle, 0, side(piece) * (0.9 * p.air + 0.1 * p.jiggle))
	elseif role == "spin" then
		return CFrame.fromAxisAngle(piece.axis, p.spin * amp)
	elseif role == "jaw" then
		-- A little open at rest; opens wide and snaps shut for a clap. Positive lifts its front.
		return CFrame.Angles(0.12 + 0.6 * p.clap, 0, 0)
	end
	return CFrame.identity
end

-- How much the rocket flame is stretched this frame (x and z across, y along it).
local function flameScale(p: Pose): Vector3
	local flicker = 1 + math.sin(p.time * 29) * 0.15 + math.sin(p.time * 53) * 0.08
	local push = 1 + math.clamp(p.vy / 20, 0, 1) * 0.6 + p.move * 0.25
	local across = 1 + math.sin(p.time * 41) * 0.06
	return Vector3.new(across, flicker * push, across)
end

-- Works out every part's CFrame (rig.cframes) and size (rig.sizes) for pose `p`, with the
-- mascot's feet at `root`. The caller moves the parts (workspace:BulkMoveTo) and sets sizes for
-- the parts whose size changed (MascotRig.sized).
function MascotRig.solve(rig: Rig, p: Pose, root: CFrame)
	local pieces = rig.pieces
	for i, piece in pieces do
		local own = CFrame.identity
		if i > 1 then
			local pivot = rig.pivots[i]
			if piece.role == "tape" then
				-- Slides along, one sprocket-hole gap at a time, as fast as the reel rims turn.
				own = CFrame.new(piece.axis * ((p.spin * 0.46) % piece.amp) * rig.scale)
			else
				own = pivot * turn(piece, p) * pivot:Inverse()
			end
		end
		local parent = piece.parent
		rig.moved[i] = if parent ~= nil then rig.moved[parent] * own else own
	end
	local stretch = flameScale(p)
	for j, part in rig.parts do
		local index = rig.piece[j]
		local rest = rig.rest[j]
		local piece = pieces[index]
		if piece.role == "flame" then
			-- Stretch about the nozzle: positions move away from the pivot, sizes grow to match.
			local pivot = rig.pivots[index].Position
			local at = pivot + (rest.Position - pivot) * stretch
			rest = CFrame.new(at) * rest.Rotation
			rig.sizes[j] = rig.restSize[j] * stretch
		end
		rig.cframes[j] = root * rig.moved[index] * rest
	end
end

-- True for parts whose size changes as they move (the flame), so the caller sets their Size.
function MascotRig.sized(rig: Rig, j: number): boolean
	return rig.pieces[rig.piece[j]].role == "flame"
end

-- The first part of the piece with `role` (for hanging effects on it, like the flame's fire).
function MascotRig.partOf(rig: Rig, role: string): BasePart?
	for j, part in rig.parts do
		if rig.pieces[rig.piece[j]].role == role then
			return part
		end
	end
	return nil
end

return MascotRig
