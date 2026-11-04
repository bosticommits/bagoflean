--!strict
-- Layout and node states for the hex upgrade tree (src/client/UpgradesUi.luau). A START hex sits
-- in the middle and each upgrade chain is a ray going out from it, one hex per level. Pure, so the
-- specs can check it; the server still prices and applies every purchase.
local Upgrades = require(script.Parent.Upgrades)

local UpgradeTree = {}

-- Gap between hex centres along a ray (and from START to the first hex), in unzoomed pixels.
UpgradeTree.STEP = 122

-- Ray direction per upgrade, in degrees on screen (0 = right, 90 = down), as in the Figma mockup:
-- five rays 72 degrees apart with Offline pointing straight down.
UpgradeTree.ANGLES = table.freeze({
	Luck = -126,
	Stages = -54,
	Cinema = 18,
	Offline = 90,
	Clap = 162,
} :: { [string]: number })

-- Centre of level `n` (or the ray's label with n = maxLevel + 0.6) relative to START's centre.
function UpgradeTree.offset(id: string, n: number): (number, number)
	local angle = math.rad(UpgradeTree.ANGLES[id] or 90)
	local distance = UpgradeTree.STEP * n
	return math.cos(angle) * distance, math.sin(angle) * distance
end

-- "owned", "buy" (next level, affordable), "short" (next level, not enough Cash), "fame" (next
-- level, needs more Fame) or "locked" (a later level).
export type NodeState = "owned" | "buy" | "short" | "fame" | "locked"

function UpgradeTree.nodeState(upgrade: Upgrades.Upgrade, level: number, n: number, cash: number, fame: number): NodeState
	if n <= level then
		return "owned"
	elseif n > level + 1 then
		return "locked"
	elseif fame < upgrade.fame[n] then
		return "fame"
	elseif cash >= upgrade.costs[n] then
		return "buy"
	end
	return "short"
end

-- Upgrades whose next level the player can buy right now (for the menu badge).
function UpgradeTree.buyableCount(stats: any, cash: number, fame: number): number
	local count = 0
	for _, upgrade in Upgrades.List do
		local level = Upgrades.level(stats, upgrade.id)
		if level < upgrade.maxLevel and UpgradeTree.nodeState(upgrade, level, level + 1, cash, fame) == "buy" then
			count += 1
		end
	end
	return count
end

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

-- "Luck III": the hex's name, Roman numerals as in the mockup (levels past X fall back to digits).
function UpgradeTree.roman(n: number): string
	return ROMAN[n] or tostring(n)
end

return UpgradeTree
