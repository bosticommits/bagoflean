local H = require("./harness")
local Config = H.require("Config")
local Rebirth = H.require("Rebirth")
local Upgrades = H.require("Upgrades")
local test, expect, equal, near = H.test, H.expect, H.equal, H.near

test("the first rebirth costs FirstCost and each one costs more", function()
	equal(Rebirth.cost(0), Rebirth.FirstCost, "first price")
	for n = 1, Rebirth.Max - 1 do
		local before, now = Rebirth.cost(n - 1), Rebirth.cost(n)
		expect(before ~= nil and now ~= nil and now > before, `price {n + 1} rises`)
	end
	equal(Rebirth.cost(Rebirth.Max), nil, "no price once maxed")
end)

test("every price is a whole number the HUD can print with commas", function()
	for n = 0, Rebirth.Max - 1 do
		local cost = Rebirth.cost(n)
		expect(cost ~= nil and cost == math.floor(cost), `price {n + 1} whole`)
		-- Roblox prints numbers from 1e14 up in e-notation, which Hud.comma can't group.
		expect(cost ~= nil and cost < 1e14, `price {n + 1} under 1e14`)
	end
end)

test("the bonus grows with every rebirth and starts at nothing", function()
	equal(Rebirth.cashMultiplier(0), 1, "no rebirths: x1")
	equal(Rebirth.luckBonus(0), 0, "no rebirths: no Luck")
	for n = 1, Rebirth.Max do
		expect(Rebirth.cashMultiplier(n) > Rebirth.cashMultiplier(n - 1), `multiplier {n}`)
		expect(Rebirth.luckBonus(n) > Rebirth.luckBonus(n - 1), `luck {n}`)
	end
	equal(Rebirth.multiplierText(0), "x1", "text x1")
	equal(Rebirth.multiplierText(1), "x" .. string.format("%.1f", 1 + Rebirth.CashStep), "text after one")
end)

test("bad counts read as safe ones", function()
	equal(Rebirth.cashMultiplier(-3), 1, "negative")
	equal(Rebirth.cashMultiplier(0 / 0), 1, "NaN")
	equal(Rebirth.cashMultiplier(nil), 1, "missing")
	equal(Rebirth.cashMultiplier(1.9), Rebirth.cashMultiplier(1), "fraction rounds down")
	equal(Rebirth.cashMultiplier(Rebirth.Max + 50), Rebirth.cashMultiplier(Rebirth.Max), "capped at Max")
end)

test("progress runs from 0 to 1 and is full once affordable or maxed", function()
	equal(Rebirth.progress(0, 0), 0, "broke")
	near(Rebirth.progress(Rebirth.FirstCost / 2, 0), 0.5, 1e-9, "halfway")
	equal(Rebirth.progress(Rebirth.FirstCost * 10, 0), 1, "more than enough")
	equal(Rebirth.progress(-5, 0), 0, "negative cash")
	equal(Rebirth.progress(0, Rebirth.Max), 1, "maxed")
end)

test("the studio's name gets its sequel number", function()
	equal(Rebirth.sequelSuffix(0), "", "original")
	equal(Rebirth.sequelSuffix(1), " 2", "first sequel")
	equal(Rebirth.sequelSuffix(4), " 5", "fifth movie")
end)

test("a reset clears upgrades and stages and keeps everything else", function()
	local roster, index, scripts, cinema, films, passes = { ["StuntDouble:Normal"] = 2 }, { ["StuntDouble:Normal"] = true }, { ["Action:Short"] = 3 }, { { payout = 500 } }, { { stage = 3 } }, { Luck2x = true }
	local data: any = {
		cash = 400000,
		fame = 12345,
		stageCount = 4,
		upgrades = { Cinema = 3, Offline = 2, Luck = 6, Clap = 1 },
		rebirths = 2,
		roster = roster,
		index = index,
		scripts = scripts,
		cinema = cinema,
		films = films,
		passes = passes,
		trophies = 3,
	}
	Rebirth.reset(data)
	equal(next(data.upgrades), nil, "upgrades cleared")
	equal(data.stageCount, Config.StartingStages, "back to the first stage")
	equal(data.rebirths, 3, "one more rebirth")
	equal(data.cash, 400000, "Cash is left to RebirthService")
	equal(data.fame, 12345, "Fame kept")
	equal(data.trophies, 3, "trophies kept")
	equal(data.roster, roster, "actors kept")
	equal(data.roster["StuntDouble:Normal"], 2, "actor copies kept")
	equal(data.index, index, "Index kept")
	equal(data.scripts, scripts, "scripts kept")
	equal(data.cinema, cinema, "cinema kept")
	equal(data.films, films, "films still filming kept")
	equal(data.passes, passes, "passes kept")
end)

test("rebirths add Luck on top of upgrades and Index rewards", function()
	local stats = { upgrades = { Luck = 2 }, stageCount = 1, rewards = { ["tier:Newcomer"] = true }, passes = {}, rebirths = 0 }
	local before = Upgrades.luck(stats)
	stats.rebirths = 3
	near(Upgrades.luck(stats), before + Rebirth.luckBonus(3), 1e-9, "luck after three rebirths")
	stats.rebirths = nil
	near(Upgrades.luck(stats), before, 1e-9, "no rebirth field (older clients)")
end)
