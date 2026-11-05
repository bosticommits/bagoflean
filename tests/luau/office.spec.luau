local roblox = require("@lune/roblox")

local H = require("./harness")
local LotModels = H.require("Models/LotModels")
local Build = H.require("Models/Build")
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

test("every Offline Earnings level has its own Blender office look", function()
	for level = 0, 5 do
		local look = LotModels.OfficeLooks[level]
		expect(look ~= nil, `no office look for level {level}: run art/blender/lot_office_kit.py`)
		expect(look.accent.size.X > 0, `level {level} has an accent mesh`)
		equal(count(look, "Hitbox"), 1, `level {level} has one hitbox`)
		expect(#look.parts <= 20, `level {level} has {#look.parts} parts (aim for 10-20)`)
		-- Same features at the same levels as the part office: trailer star at 0, antenna 2-4.
		equal(count(look, "TrailerStar"), if level == 0 then 1 else 0, `trailer star at level {level}`)
		equal(count(look, "AntennaLight"), if level >= 2 and level <= 4 then 1 else 0, `antenna at level {level}`)
		if level >= 2 then
			local below = LotModels.OfficeLooks[level - 1]
			expect(look.body.size.Y >= below.body.size.Y, `level {level} is shorter than the one before`)
		end
	end
end)

test("the part fallback builds every level when the meshes are missing", function()
	for level = 0, 5 do
		local folder = roblox.Instance.new("Folder")
		LotModels.office(Build.new(folder, roblox.CFrame.new()), level, roblox.Color3.new(1, 0, 0))
		expect(#folder:GetChildren() > 0, `level {level} built nothing`)
	end
end)
