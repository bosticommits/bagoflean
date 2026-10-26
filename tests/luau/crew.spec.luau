-- The film crews' animation quality: plays every set's whole cycle at 30 frames a second (and the
-- wrap back to the start, and an owner's cue) and checks nobody snaps, slides or bumps into
-- anyone or anything.
local roblox = require("@lune/roblox")

local H = require("./harness")
local FilmScenes = H.require("FilmScenes")
local MapKitShapes = H.require("Models/MapKitShapes")
local Sounds = H.require("Sounds")
local test, expect, equal = H.test, H.expect, H.equal

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local DT = 1 / 30
local MAX_MOVE = 1.4 -- studs a body point may move in one frame (a running foot is the fastest)
local MAX_FLIP = 1.6 -- the stunt double's flip off the balcony is the one faster move
local SLIDE = 0.06 -- studs a planted foot may slip in one frame
local APART = 1.5 -- studs between two people's feet
local MARGIN = 0.25 -- how close feet may come to set gear
local CREW = { Director = true, Clapper = true, Operator = true, Boom = true, Gaffer = true, Makeup = true }

-- Body points that show a snap: the head's top, the hands, the feet and the torso.
local function points(p: any): { Vector3 }
	local cf = FilmScenes.pieces(CFrame.identity, p, 0)
	return {
		(cf.Head * CFrame.new(0, 1.8, 0)).Position,
		(cf.ArmL * CFrame.new(0, -1.8, 0)).Position,
		(cf.ArmR * CFrame.new(0, -1.8, 0)).Position,
		(cf.LegL * CFrame.new(0, -2, 0)).Position,
		(cf.LegR * CFrame.new(0, -2, 0)).Position,
		cf.Torso.Position,
	}
end

-- Gear footprints people must keep out of (the ones they stand on or climb are left out).
local WALK_ON = { CrewOpenDoor = true, CrewBalconyDoor = true, JungleTemple = true, MoonLander = true, IdolPedestal = true, SpaceBackdrop = true, MoonCrater = true, JungleFern = true }

local function inside(gear: any, x: number, z: number): boolean
	local b = MapKitShapes.Bounds[gear.kit]
	if b == nil then
		return false
	end
	local cf = CFrame.new(gear.at) * CFrame.Angles(0, math.rad(gear.yaw), 0) * CFrame.new(b.center)
	local p = cf:PointToObjectSpace(Vector3.new(x, cf.Position.Y, z))
	return math.abs(p.X) < b.size.X / 2 + MARGIN and math.abs(p.Z) < b.size.Z / 2 + MARGIN
end

type Report = { snaps: { string }, slides: { string }, bumps: { string }, clips: { string }, worstMove: number, worstSlide: number, closest: number }

-- Plays set `id` from t0 to t1 and checks every frame against the one before.
local function play(id: string, t0: number, t1: number, cue: any?): Report
	local set = FilmScenes.Sets[id]
	local report: Report = { snaps = {}, slides = {}, bumps = {}, clips = {}, worstMove = 0, worstSlide = 0, closest = math.huge }
	local last: { [string]: any } = {}
	local lastThings: { [string]: Vector3 } = {}
	local frames = math.floor((t1 - t0) / DT)
	for i = 0, frames do
		local t = t0 + i * DT
		local frame = FilmScenes.frame(id, t, cue)
		local feet: { [string]: Vector3 } = {}
		for _, who in set.cast do
			local p = frame.poses[who]
			expect(p ~= nil, `{id}: {who} has no pose at {t}`)
			if p.hidden then
				last[who] = nil
				continue
			end
			local pts = points(p)
			local prev = last[who]
			if prev ~= nil then
				local cap = if who == "Stunt" and frame.phase == "take" and frame.scene == 2 then MAX_FLIP else MAX_MOVE
				for k, q in pts do
					local d = (q - prev.pts[k]).Magnitude
					report.worstMove = math.max(report.worstMove, d)
					-- A snap: too far in one frame, or far more than the frames either side of it.
					local before = prev.moves[k]
					local spike = before ~= nil and prev.spike[k] ~= nil and prev.spike[k] > 0.3 and prev.spike[k] > 4 * math.max(before, d)
					if (d > cap or spike) and #report.snaps < 8 then
						table.insert(report.snaps, `{who} point {k} {if spike then "snaps" else "jumps"} {string.format("%.2f", if spike then prev.spike[k] else d)} at {string.format("%.2f", frame.time)} ({frame.phase} {frame.take})`)
					end
				end
				-- The planted foot of a stride stays put.
				if p.walking and prev.walking and p.plant == prev.plant then
					local k = 3 + p.plant
					local a, b = pts[k], prev.pts[k]
					local slip = Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
					report.worstSlide = math.max(report.worstSlide, slip)
					if slip > SLIDE and #report.slides < 8 then
						table.insert(report.slides, `{who} slides {string.format("%.3f", slip)} at {string.format("%.2f", frame.time)} ({frame.phase} {frame.take})`)
					end
				end
				-- The other foot never digs into the ground while it swings.
				if p.walking then
					local k = if p.plant == 1 then 5 else 4
					local dig = pts[9 - k].Y - pts[k].Y
					if dig > 0.03 and #report.slides < 8 then
						table.insert(report.slides, `{who}'s swinging foot digs {string.format("%.3f", dig)} into the ground at {string.format("%.2f", frame.time)}`)
					end
				end
			end
			local moves, spike = {}, {}
			for k, q in pts do
				if prev ~= nil then
					spike[k] = (q - prev.pts[k]).Magnitude
					moves[k] = prev.spike[k]
				end
			end
			last[who] = { pts = pts, walking = p.walking, plant = p.plant, spike = spike, moves = moves }
			feet[who] = Vector3.new(p.at.X, p.at.Y, p.at.Z)
			if not p.ride and p.tilt == 0 then
				for _, gear in set.gear do
					if not WALK_ON[gear.kit] and inside(gear, p.at.X, p.at.Z) and p.at.Y < gear.at.Y + 2 and #report.clips < 8 then
						table.insert(report.clips, `{who} stands in the {gear.kit} at {string.format("%.2f", frame.time)} ({frame.phase} {frame.take})`)
					end
				end
				local dolly = frame.things.CrewDolly
				if dolly ~= nil then
					local d = dolly:PointToObjectSpace(p.at)
					if math.abs(d.X) < 2.1 and math.abs(d.Z) < 2.1 and #report.clips < 8 then
						table.insert(report.clips, `{who} walks into the dolly at {string.format("%.2f", frame.time)}`)
					end
				end
			end
		end
		-- Nobody walks into anybody.
		-- (The make-up artist steps up close to an actor on purpose, brush to their face.)
		local touching = frame.say.Makeup ~= nil
		for a, pa in feet do
			for b, pb in feet do
				if a < b and math.abs(pa.Y - pb.Y) < 3 then
					local d = Vector3.new(pa.X - pb.X, 0, pa.Z - pb.Z).Magnitude
					local makeup = (a == "Makeup" or b == "Makeup") and not (CREW[a] and CREW[b])
					local limit = if makeup then (if touching then 0.9 else 1.2) else APART
					report.closest = math.min(report.closest, d)
					if d < limit and #report.bumps < 8 then
						table.insert(report.bumps, `{a} and {b} {string.format("%.2f", d)} apart at {string.format("%.2f", frame.time)} ({frame.phase} {frame.take})`)
					end
				end
			end
		end
		-- The camera rig and the props glide too.
		for kit, cf in frame.things do
			local q = cf.Position
			local prev = lastThings[kit]
			if prev ~= nil and (q - prev).Magnitude > MAX_MOVE * 2 and #report.snaps < 8 then
				table.insert(report.snaps, `{kit} jumps {string.format("%.2f", (q - prev).Magnitude)} at {string.format("%.2f", frame.time)}`)
			end
			lastThings[kit] = q
		end
		for kit in lastThings do
			if frame.things[kit] == nil then
				lastThings[kit] = nil
			end
		end
	end
	return report
end

local function check(id: string, what: string, report: Report)
	print(`  {id} {what}: worst move {string.format("%.2f", report.worstMove)}/frame, worst planted-foot slip {string.format("%.3f", report.worstSlide)}, closest people {string.format("%.2f", report.closest)}`)
	local problems = {}
	for name, list in { snaps = report.snaps, ["foot slides"] = report.slides, bumps = report.bumps, clips = report.clips } do
		if #list > 0 then
			table.insert(problems, `{name}: {table.concat(list, "; ")}`)
		end
	end
	expect(#problems == 0, `{id} {what}: {table.concat(problems, "\n         ")}`)
end

for _, id in { "Gulch", "MoonBase", "Jungle" } do
	test(`{id}: a whole cycle and the wrap to the next plays without snaps, slides or bumps`, function()
		local period = FilmScenes.Sets[id].period
		check(id, "cycle", play(id, 0, period + 4))
	end)

	test(`{id}: the owner calling Action mid-take stops it smoothly and greets them`, function()
		local period = FilmScenes.Sets[id].period
		-- Press during the first take's action, then again after that cue has played out.
		local t = 1
		local frame = FilmScenes.frame(id, t)
		while not (frame.phase == "take" and frame.time > 6.9 and frame.time < 7.2) do
			t += 0.25
			frame = FilmScenes.frame(id, t)
		end
		local cue = FilmScenes.cue(id, nil, t, true)
		expect(cue ~= nil, "a cue")
		expect(FilmScenes.cue(id, cue, t + 1, true) == nil, "one cue at a time")
		local text = FilmScenes.cueText(cue)
		local back = FilmScenes.parseCue(text)
		expect(back ~= nil and math.abs(back.from - cue.from) < 0.01 and back.press, "the cue survives the attribute")
		check(id, "cue", play(id, t - 2, cue.from + 12, cue))
		local greeted = FilmScenes.frame(id, cue.from + 1, cue)
		equal(greeted.say.Director, "Places everyone!", `{id}: the director greets the owner`)
		equal(FilmScenes.frame(id, cue.from + 0.4, cue).beat, "places", `{id}: "Places everyone!" is heard`)
		local acked = FilmScenes.frame(id, t + 0.5, cue)
		expect(acked.say.Clapper ~= nil, `{id}: the clapper loader answers the owner`)
		-- A second cue later on, chained on the first.
		local later = FilmScenes.cue(id, cue, cue.from + 20, true)
		expect(later ~= nil, "a later cue")
		check(id, "second cue", play(id, cue.from + 18, later.from + 6, later))
		expect(period > 100, `{id}'s loop is {period} s`)
	end)
end

test("every set has the whole crew, a slate, Action, a clean cut, a blooper and applause", function()
	for id, set in FilmScenes.Sets do
		local said: { [string]: boolean } = {}
		local beats: { [string]: boolean } = {}
		local cheers = 0
		local t = 0
		while t < set.period do
			local frame = FilmScenes.frame(id, t)
			for _, words in frame.say do
				said[words] = true
			end
			if frame.beat ~= nil then
				beats[frame.beat] = true
				if frame.beat == "cheer" and frame.time - (frame.beatAt - (t - frame.time)) < 0.2 then
					cheers += 1
				end
			end
			t += 0.1
		end
		for _, words in { "ACTION!", "CUT! Print it!", "CUT! Cut!", "Quiet on set!", "Rehearsal! Nice and easy.", "Hold still, darling!" } do
			expect(said[words], `{id} never says "{words}"`)
		end
		for beat, slot in FilmScenes.BeatSounds do
			expect(beats[beat] or beat == "places", `{id} never has the {beat} moment`)
			expect(Sounds.Slots[slot] ~= nil, `{beat} plays unknown sound slot {slot}`)
		end
		expect(#set.cast >= 8, `{id} has {#set.cast} people`)
		for _, who in { "Director", "Clapper", "Operator", "Boom", "Gaffer", "Makeup" } do
			expect(table.find(set.cast, who) ~= nil, `{id} has no {who}`)
		end
	end
end)

test("the blooper takes turns: a stumble, a forgotten line, the giggles", function()
	for id, set in FilmScenes.Sets do
		local seen: { [string]: boolean } = {}
		for cycle = 0, 2 do
			local t = cycle * set.period
			while t < (cycle + 1) * set.period do
				local frame = FilmScenes.frame(id, t)
				for _, words in frame.say do
					seen[words] = true
				end
				t += 0.2
			end
		end
		for _, words in { "Oops! Sorry!", "Uh... what's my line?", "Hahaha! Sorry!" } do
			expect(seen[words], `{id} never has the blooper "{words}"`)
		end
	end
end)
