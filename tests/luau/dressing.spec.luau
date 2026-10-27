local roblox = require("@lune/roblox")

local H = require("./harness")
local Build = H.require("Models/Build")
local LotModels = H.require("Models/LotModels")
local test, expect, equal = H.test, H.expect, H.equal

-- Outside Roblox there is no LotMeshes folder, so every piece takes its part fallback.
local function builder()
	local folder = roblox.Instance.new("Folder")
	return Build.new(folder, roblox.CFrame.new()), folder
end

local function named(folder: any, name: string): number
	local n = 0
	for _, p in folder:GetChildren() do
		if p.Name == name then
			n += 1
		end
	end
	return n
end

test("without the dressing meshes, the lot dressing still builds from parts", function()
	local b, folder = builder()
	LotModels.hedges(b, 56, 12)
	equal(named(folder, "Hedge"), 5, "five hedge runs")
	equal(named(folder, "Pillar"), 6, "six pillars")
	equal(named(folder, "Collider"), 0, "no mesh colliders in the part build")

	b, folder = builder()
	LotModels.gate(b, 12, 3)
	equal(named(folder, "GatePost"), 2, "two gate posts")
	equal(named(folder, "GateBadge"), 2, "two number badges")

	b, folder = builder()
	LotModels.stanchions(b, -13, 2, 3.8)
	equal(named(folder, "Stanchion"), 8, "four stanchions a side")
end)

test("the dressing still returns the parts its callers use", function()
	local b = builder()
	local head = LotModels.lamp(b)
	equal(head.Name, "LampHead", "lamp returns its glowing head")
	expect(head:FindFirstChildWhichIsA("PointLight") ~= nil, "the lamp head holds the light")

	b = builder()
	equal(LotModels.billboard(b, 8).Name, "Billboard", "billboard returns the board")

	b = builder()
	local ring = LotModels.pedestal(b, roblox.Color3.new(1, 0, 0), true)
	equal(ring.Name, "PedestalRing", "pedestal returns the glow ring")
	expect(ring:FindFirstChildWhichIsA("PointLight") ~= nil, "a rare star's ring glows")

	local folder
	b, folder = builder()
	LotModels.trophyCase(b, 3)
	equal(named(folder, "CaseBase"), 1, "the case LotLook looks up by name")
end)
