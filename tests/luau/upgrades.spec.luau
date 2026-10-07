local H = require("./harness")
local Actors = H.require("Actors")
local Config = H.require("Config")
local Upgrades = H.require("Upgrades")
local test, expect, equal, near = H.test, H.expect, H.equal, H.near

local function stats(overrides: { [string]: any }?): any
	local s = { upgrades = {}, stageCount = Config.StartingStages, rewards = {}, passes = {} }
	for k, v in overrides or {} do
		s[k] = v
	end
	return s
end

test("every upgrade has a price and Fame gate for each level", function()
	for _, upgrade in Upgrades.List do
		expect(upgrade.maxLevel > 0, `{upgrade.id} maxLevel`)
		equal(#upgrade.costs, upgrade.maxLevel, `{upgrade.id} costs`)
		equal(#upgrade.fame, upgrade.maxLevel, `{upgrade.id} fame`)
		for level = 0, upgrade.maxLevel do
			expect(type(upgrade.effect(level)) == "string", `{upgrade.id} effect({level})`)
		end
	end
end)

test("upgrade prices rise and Fame gates never drop", function()
	for _, upgrade in Upgrades.List do
		for i = 2, upgrade.maxLevel do
			expect(upgrade.costs[i] > upgrade.costs[i - 1], `{upgrade.id} cost {i}`)
			expect(upgrade.fame[i] >= upgrade.fame[i - 1], `{upgrade.id} fame {i}`)
		end
	end
end)

test("upgrade ids are unique and found by id", function()
	local seen = {}
	for _, upgrade in Upgrades.List do
		expect(not seen[upgrade.id], `duplicate {upgrade.id}`)
		seen[upgrade.id] = true
		equal(Upgrades.get(upgrade.id), upgrade, upgrade.id)
	end
	equal(Upgrades.get("Nope"), nil, "unknown upgrade")
end)

test("stage upgrades stop at the stage limit", function()
	local stages = Upgrades.get("Stages")
	equal(Config.StartingStages + stages.maxLevel, Config.MaxStages, "bought stages reach MaxStages")
	local maxed = stats({ stageCount = Config.MaxStages })
	equal(Upgrades.level(maxed, "Stages"), stages.maxLevel, "level from stageCount")
	maxed.passes = { ExtraStage = true }
	expect(Upgrades.stages(maxed) <= Config.StageLimit, "stage pass can't exceed StageLimit")
	equal(Upgrades.stages(stats()), Config.StartingStages, "new player")
end)

test("luck adds upgrade levels and claimed tier rewards only", function()
	near(Upgrades.luck(stats()), Config.BaseLuck, 1e-9, "base")
	local s = stats({
		upgrades = { Luck = 3 },
		rewards = { ["tier:Newcomer"] = true, ["tier:Rising"] = false, ["genre:Action"] = true },
	})
	near(Upgrades.luck(s), Config.BaseLuck + 0.3 + Config.TierRewardLuck, 1e-9, "levels + one tier")
end)

test("derived stats grow with their upgrade", function()
	local base, upgraded = stats(), stats({ upgrades = { Clap = 2, Offline = 1, Cinema = 4 } })
	expect(Upgrades.clapSeconds(upgraded) > Upgrades.clapSeconds(base), "clap")
	expect(Upgrades.offlineCap(upgraded) > Upgrades.offlineCap(base), "offline")
	expect(Upgrades.royaltyMultiplier(upgraded) > Upgrades.royaltyMultiplier(base), "cinema")
	equal(Upgrades.genreBonus(base, "Action"), 1, "no genre reward")
	near(Upgrades.genreBonus(stats({ rewards = { ["genre:Action"] = true } }), "Action"), 1 + Config.GenreBonus, 1e-9, "genre reward")
end)

test("Index rewards are earned only when the whole row or genre is found", function()
	local index: { [string]: boolean } = {}
	local newcomers = Actors.actorsInTier("Newcomer")
	for i = 1, #newcomers - 1 do
		index[Actors.key(newcomers[i].id, "Normal")] = true
	end
	expect(not Upgrades.rewardEarned(index, "tier:Newcomer"), "partial row")
	-- Any variant counts as discovering the actor.
	index[Actors.key(newcomers[#newcomers].id, "Shiny")] = true
	expect(Upgrades.rewardEarned(index, "tier:Newcomer"), "full row")

	local all: { [string]: boolean } = {}
	for _, actor in Actors.List do
		if actor.genre == "Horror" then
			all[Actors.key(actor.id, "Normal")] = true
		end
	end
	expect(Upgrades.rewardEarned(all, "genre:Horror"), "full genre")
	expect(not Upgrades.rewardEarned(all, "genre:Comedy"), "other genre")
	expect(not Upgrades.rewardEarned(all, "genre:Western"), "unknown genre")
	expect(not Upgrades.rewardEarned(all, "tier:Nope"), "unknown tier")
	expect(not Upgrades.rewardEarned(all, "garbage"), "bad id")
end)
