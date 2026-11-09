local roblox = require("@lune/roblox")

local H = require("./harness")
local LotModels = H.require("Models/LotModels")
local test, expect, equal = H.test, H.expect, H.equal

local function count(look, name: string): number
	local n = 0
	for _, p in look.parts do
		if p.name == name then
			n += 1
		end
	end
	return n
end

test("every Cinema Size level has its own Blender look that grows with the level", function()
	local previous = nil
	for level = 0, 6 do
		local look = LotModels.CinemaLooks[level]
		expect(look ~= nil, `no cinema look for level {level}: run art/blender/lot_cinema_kit.py`)
		equal(count(look, "MarqueeSign"), 1, `level {level} has one marquee board for the studio name`)
		expect(#look.parts <= 20, `level {level} has {#look.parts} parts (aim for 10-20)`)
		expect(look.accent.size.X > 0, `level {level} has an accent mesh`)
		if previous ~= nil then
			local a, b = previous.body.size, look.body.size
			expect(b.X >= a.X and b.Y >= a.Y and b.Z >= a.Z, `level {level} is smaller than the one before`)
			expect(#look.parts >= #previous.parts, `level {level} has fewer pieces than the one before`)
		end
		previous = look
	end
	-- The old tier features arrive at the same levels: blade sign at 2, wings at 4, dome at 6.
	for level = 0, 6 do
		local look = LotModels.CinemaLooks[level]
		equal(count(look, "BladeFace"), if level >= 2 then 1 else 0, `blade sign at level {level}`)
		equal(count(look, "Hitbox"), if level >= 6 then 4 elseif level >= 4 then 2 else 1, `wing and dome hitbox at level {level}`)
		equal(#look.lights, if level >= 6 then 2 else 0, `searchlights at level {level}`)
		equal(count(look, "DomeTop"), if level >= 6 then 1 else 0, `dome at level {level}`)
	end
end)

test("the part fallback keeps the four old tiers and still returns the marquee", function()
	local tiers = { [0] = 1, 1, 2, 2, 3, 3, 4 }
	for level = 0, 6 do
		equal(LotModels.cinemaTier(level), tiers[level], `tier for level {level}`)
		local folder = roblox.Instance.new("Folder")
		local Build = H.require("Models/Build")
		local label = LotModels.cinema(Build.new(folder, roblox.CFrame.new()), level, roblox.Color3.new(1, 0, 0))
		expect(label ~= nil and label:IsA("TextLabel"), `level {level} returns the marquee label`)
	end
end)

test("every cinema part stays inside the squeezed body width and the level 6 dome has a ball hitbox", function()
	for level = 0, 6 do
		local look = LotModels.CinemaLooks[level]
		local sx = LotModels.cinemaWidthScale(level)
		local half = look.body.size.X * sx / 2
		expect(half * 2 <= LotModels.CinemaMaxWidth + 1e-6, `level {level} body is wider than the lot gap`)
		for _, p in look.parts do
			local reach = math.abs(p.cf.X * sx) + (if p.name == "HeadboardStar" then p.size.X else p.size.X * sx) / 2
			expect(reach <= half + 1e-6, `level {level} {p.name} reaches {reach}, body half-width {half}`)
		end
		for _, at in look.lights do
			expect(math.abs(at.X * sx) <= half, `level {level} searchlight outside the body`)
		end
	end
	equal(LotModels.cinemaWidthScale(3), 1, "levels 0-3 keep their Blender width")
	local top = 0
	for _, p in LotModels.CinemaLooks[6].parts do
		if p.color == "hitbox" then
			top = math.max(top, p.cf.Y + p.size.Y / 2)
		end
	end
	expect(math.abs(top - 21.8) < 1e-6, `level 6 dome hitbox top is {top}`)
end)
