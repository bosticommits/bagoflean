--!strict
-- Founding Tester rule (pure, so Lune can test it). A founder is someone whose soft-launch save
-- (the old PlayerData_v1 store) finished the tutorial and was created before the launch cut-off.
-- The v1 store is only ever read; the verdict is saved once in the new store's profile.
local Founder = {}

-- 2026-11-19 00:00 UTC: saves created from here on are not founders. Move it if launch slips.
Founder.CutOff = 1795046400

-- `old` is the old save's Data (or nil when there is none), `createdAt` its creation time.
function Founder.isFounder(old: any, createdAt: number): boolean
	return type(old) == "table" and old.tutorialDone == true and createdAt > 0 and createdAt < Founder.CutOff
end

-- Records the verdict once on the live data. True only on the single call that grants founder
-- status; later calls (and a first verdict of false) change nothing.
function Founder.settle(data: { founder: boolean, founderChecked: boolean }, isFounder: boolean): boolean
	if data.founderChecked then
		return false
	end
	data.founderChecked = true
	data.founder = isFounder
	return isFounder
end

return Founder
