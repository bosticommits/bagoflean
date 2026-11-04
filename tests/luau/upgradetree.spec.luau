local H = require("./harness")
local Upgrades = H.require("Upgrades")
local UpgradeTree = H.require("UpgradeTree")
local test, expect, equal = H.test, H.expect, H.equal

test("every upgrade has its own ray and no two hexes overlap", function()
	local centres = {}
	local seen = {}
	for _, upgrade in Upgrades.List do
		local angle = UpgradeTree.ANGLES[upgrade.id]
		expect(angle ~= nil, `{upgrade.id} has a ray`)
		expect(seen[angle] == nil, `{upgrade.id} ray is not shared`)
		seen[angle] = true
		for n = 1, upgrade.maxLevel do
			local x, y = UpgradeTree.offset(upgrade.id, n)
			table.insert(centres, { x = x, y = y, name = `{upgrade.id}{n}` })
		end
	end
	-- Hexes are about 100 px across (circumradius 50 plus a 5 px rim), START about 128.
	for i, a in centres do
		expect(math.sqrt(a.x * a.x + a.y * a.y) >= 64 + 55, `{a.name} clears START`)
		for j = i + 1, #centres do
			local b = centres[j]
			local gap = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
			expect(gap >= 110, `{a.name} and {b.name} overlap ({gap})`)
		end
	end
end)

test("Offline points straight down", function()
	local x, y = UpgradeTree.offset("Offline", 2)
	expect(math.abs(x) < 1e-6 and math.abs(y - 2 * UpgradeTree.STEP) < 1e-6, "Offline ray")
end)

test("node states follow level, Fame and Cash", function()
	local upgrade = { id = "T", name = "T", maxLevel = 3, costs = { 100, 200, 300 }, fame = { 0, 50, 0 }, effect = tostring }
	equal(UpgradeTree.nodeState(upgrade, 1, 1, 0, 0), "owned")
	equal(UpgradeTree.nodeState(upgrade, 1, 3, 1e9, 1e9), "locked")
	equal(UpgradeTree.nodeState(upgrade, 1, 2, 1e9, 10), "fame")
	equal(UpgradeTree.nodeState(upgrade, 1, 2, 199, 50), "short")
	equal(UpgradeTree.nodeState(upgrade, 1, 2, 200, 50), "buy")
end)

test("buyable count only counts affordable next levels", function()
	local stats = { upgrades = {}, stageCount = 1, rewards = {}, passes = {} }
	equal(UpgradeTree.buyableCount(stats, 0, 0), 0)
	expect(UpgradeTree.buyableCount(stats, 1e12, 1e12) == #Upgrades.List, "all buyable when rich")
end)

test("hex names use Roman numerals", function()
	equal(UpgradeTree.roman(3), "III")
	equal(UpgradeTree.roman(10), "X")
	equal(UpgradeTree.roman(11), "11")
end)
