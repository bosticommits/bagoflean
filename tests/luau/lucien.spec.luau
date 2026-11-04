-- Director Lucien Vale's rig (LucienRig) and the intro's dialogue paging (Dialogue): his clips
-- loop without a snap, keep his feet on the floor and his cane by his side, and a line never
-- gets cut off.
local roblox = require("@lune/roblox")

local H = require("./harness")
local LucienRig = H.require("Models/LucienRig")
local Dialogue = H.require("Dialogue")
local test, expect, equal = H.test, H.expect, H.equal

local CFrame, Vector2 = roblox.CFrame, roblox.Vector2

local function lowestFoot(frames: { [string]: any }): number
	-- A foot's sole is 0.31 below its ankle joint (LucienShapes.Bounds.LucienFoot).
	return math.min((frames.LeftFoot * CFrame.new(0, -0.31, 0)).Position.Y, (frames.RightFoot * CFrame.new(0, -0.31, 0)).Position.Y)
end

test("lucien: every clip names only real joints and has keys in order", function()
	for name, clip in LucienRig.Clips do
		equal(clip.keys[1].time, 0, `{name} starts at 0`)
		equal(clip.keys[#clip.keys].time, clip.duration, `{name} ends at its duration`)
		for i, key in clip.keys do
			if i > 1 then
				expect(key.time > clip.keys[i - 1].time, `{name} key {i} goes back in time`)
			end
			for joint in key.pose do
				expect(LucienRig.isKey(joint), `{name} turns unknown joint {joint}`)
			end
		end
	end
end)

test("lucien: looping clips end where they start, one-shots start and end holding the cane", function()
	local function same(a: any, b: any, label: string)
		for _, joint in LucienRig.Joints do
			local fa, fb = LucienRig.solve(a, CFrame.identity)[joint.piece], LucienRig.solve(b, CFrame.identity)[joint.piece]
			expect((fa.Position - fb.Position).Magnitude < 1e-3, `{label}: {joint.piece} jumps`)
		end
	end
	for name, clip in LucienRig.Clips do
		if clip.loop then
			same(LucienRig.sample(clip, 0), LucienRig.sample(clip, clip.duration - 1e-6), `{name} loop`)
		else
			same(LucienRig.sample(clip, 0), LucienRig.sample(LucienRig.Clips.idle, 0), `{name} start`)
			same(LucienRig.sample(clip, clip.duration), LucienRig.sample(LucienRig.Clips.idle, 0), `{name} end`)
		end
	end
end)

test("lucien: no joint snaps between frames, feet stay on the floor and the cane by his side", function()
	for name, clip in LucienRig.Clips do
		local last: { [string]: any }? = nil
		for frame = 0, math.ceil(clip.duration * 30) do
			local frames = LucienRig.solve(LucienRig.sample(clip, frame / 30), CFrame.identity)
			local foot = lowestFoot(frames)
			expect(foot > -0.12 and foot < 0.35, `{name} at frame {frame}: lowest foot at {foot}`)
			expect(frames.Head.Position.Y > 3.8, `{name} at frame {frame}: head sank`)
			if last ~= nil then
				for _, joint in LucienRig.Joints do
					-- The twirling cane's grip barely moves; its tip sweeps, which is the point.
					local step = (frames[joint.piece].Position - last[joint.piece].Position).Magnitude
					expect(step < 0.5, `{name} at frame {frame}: {joint.piece} snaps {step}`)
				end
			end
			last = frames
		end
	end
	-- Standing (idle, talk): the cane's tip (2.03 below the grip) is on the floor.
	for _, name in { "idle", "talk" } do
		local frames = LucienRig.solve(LucienRig.sample(LucienRig.Clips[name], 0.4), CFrame.identity)
		local tip = (frames.Cane * CFrame.new(0, -2.03, 0)).Position.Y
		expect(math.abs(tip) < 0.3, `{name}: the cane's tip is at {tip}, not on the floor`)
		expect(frames.Cane.UpVector.Y > 0.99, `{name}: the cane leans`)
	end
end)

test("lucien: the wave raises his free hand above his head", function()
	local frames = LucienRig.solve(LucienRig.sample(LucienRig.Clips.wave, 0.8), CFrame.identity)
	expect(frames.LeftHand.Position.Y > frames.Head.Position.Y, "the waving hand is above the head")
	expect(frames.LeftHand.Position.X < -1, "it waves out to his left")
end)

test("lucien: builds every piece as parts without the meshes", function()
	local folder = roblox.Instance.new("Folder")
	local rig = LucienRig.build(folder)
	equal(rig.meshed, false)
	for _, joint in LucienRig.Joints do
		expect(rig.parts[joint.piece] ~= nil and #rig.parts[joint.piece] > 0, `{joint.piece} has parts`)
	end
	LucienRig.apply(rig, CFrame.new(0, 0, 0), LucienRig.sample(LucienRig.Clips.idle, 0))
	expect(rig.model.Parent == folder, "the model goes in the parent")
end)

-- A fake measure: every character is 10 px wide, lines are 20 px tall, wrapping on spaces.
local function measure(text: string, size: number, width: number): Vector2
	local scale = size / 20
	local lines, line = 1, 0
	for word in string.gmatch(text, "%S+") do
		local w = (#word + (if line > 0 then 1 else 0)) * 10 * scale
		if line > 0 and line + w > width then
			lines += 1
			line = #word * 10 * scale
		else
			line += w
		end
	end
	return Vector2.new(width, lines * 20 * scale)
end

test("dialogue: a line that fits keeps the biggest size", function()
	local pages, size = Dialogue.fit("Welcome to Hollywood.", Vector2.new(400, 60), 22, 14, measure)
	equal(#pages, 1)
	equal(size, 22)
end)

test("dialogue: a long line shrinks before it splits, and never loses a word", function()
	local text = "I'm Director Lucien Vale. Fifty years behind the camera, and I still love a fresh face. This studio is yours now. Let's make your very first picture!"
	local pages, size = Dialogue.fit(text, Vector2.new(300, 40), 22, 14, measure)
	expect(size >= 14 and size <= 22, "a size in range")
	expect(#pages > 1, "split into pages")
	for _, page in pages do
		expect(measure(page, size, 300).Y <= 40, `page "{page}" overflows`)
	end
	equal(table.concat(pages, " "), text)
end)

test("dialogue: a single huge word still shows (on its own page)", function()
	local pages = Dialogue.fit(string.rep("A", 80), Vector2.new(100, 20), 20, 14, measure)
	equal(#pages, 1)
end)

test("dialogue: an empty line is one empty page", function()
	local pages = Dialogue.fit("", Vector2.new(100, 20), 20, 14, measure)
	equal(#pages, 1)
	equal(pages[1], "")
end)
