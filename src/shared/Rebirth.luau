--!strict
-- Rebirth, the game's "Sequel" (plan section 6): start the studio over for a bigger, permanent
-- bonus. Pure functions of the saved rebirth count, so the HUD chip, the Rebirth screen and the
-- server always agree. Only the server performs a rebirth (src/server/RebirthService.luau).
--
-- A rebirth costs Cash and resets Cash and every upgrade (sound stages too). Actors, the Index,
-- Fame, scripts, the cinema's movies and everything bought with Robux are kept. Each rebirth adds
-- to the movie Cash multiplier and to Luck, forever.
local Config = require(script.Parent.Config)

local Rebirth = {}

-- Tuned with tools/economy_sim.py (see ECONOMY.md).
Rebirth.FirstCost = 250000 -- Cash needed for the first rebirth
Rebirth.CostGrowth = 6 -- each rebirth costs this many times the one before
Rebirth.CashStep = 0.5 -- movie Cash multiplier added per rebirth (x1.5, x2, x2.5...)
Rebirth.LuckStep = 0.1 -- Luck added per rebirth
Rebirth.Max = 12 -- the 12th costs about $90 trillion; prices stay in numbers the HUD can print
Rebirth.Cooldown = 2 -- min seconds between rebirth requests per player (server enforced)

local function count(done: number?): number
	local n = done or 0
	if n ~= n then
		return 0
	end
	return math.clamp(math.floor(n), 0, Rebirth.Max)
end

-- Price of the next rebirth for a player who has done `done`, or nil once they reach Max.
function Rebirth.cost(done: number?): number?
	local n = count(done)
	if n >= Rebirth.Max then
		return nil
	end
	return math.floor(Rebirth.FirstCost * Rebirth.CostGrowth ^ n)
end

-- Multiplier on every premiere's Cash (and so on the box office those movies earn).
function Rebirth.cashMultiplier(done: number?): number
	return 1 + Rebirth.CashStep * count(done)
end

function Rebirth.luckBonus(done: number?): number
	return Rebirth.LuckStep * count(done)
end

-- How close `cash` is to the next rebirth, 0 to 1 (1 once affordable or maxed).
function Rebirth.progress(cash: number, done: number?): number
	local cost = Rebirth.cost(done)
	if cost == nil then
		return 1
	end
	return math.clamp(cash / cost, 0, 1)
end

-- "x1.5": how the multiplier is written everywhere.
function Rebirth.multiplierText(done: number?): string
	local value = Rebirth.cashMultiplier(done)
	return if value == math.floor(value) then `x{value}` else `x{string.format("%.1f", value)}`
end

-- The slice of player data a rebirth changes (Cash moves through EconomyService instead).
export type Resettable = {
	upgrades: { [string]: number },
	stageCount: number,
	rebirths: number,
}

-- What a rebirth does to the saved data apart from Cash: every upgrade back to level 0, sound
-- stages back to the first one, and one more rebirth. Nothing else is touched, so actors, the
-- Index, Fame, scripts, the cinema, films still filming and Shop purchases all stay.
function Rebirth.reset(data: Resettable)
	data.upgrades = {}
	data.stageCount = Config.StartingStages
	data.rebirths = count(data.rebirths) + 1
end

-- A sequel number for the studio's name: "" before the first rebirth, then " 2", " 3"...
function Rebirth.sequelSuffix(done: number?): string
	local n = count(done)
	return if n > 0 then ` {n + 1}` else ""
end

return Rebirth
