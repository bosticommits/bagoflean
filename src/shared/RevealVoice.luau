--!strict
-- Which voice slots a full reveal plays. The announcer calls Star and up; Lucien is throttled so
-- he is a treat, not spam: nothing on Pro, Star/Superstar only after a 180 s rest AND (the first
-- Star+ of the session, a NEW actor, or a 25% roll), Icon always. Call once per reveal, or once for
-- the best result of a batch (Cast x10). Pure and clock-free (`now` and `roll` come from the caller).
local RevealVoice = {}

RevealVoice.COOLDOWN = 180
RevealVoice.CHANCE = 0.25
RevealVoice.Announcer = { [4] = "voiceStar", [5] = "voiceSuperstar", [6] = "voiceLegend", [7] = "voiceIcon" }

export type State = { lastLine: number, seenStar: boolean }

function RevealVoice.new(): State
	return { lastLine = -math.huge, seenStar = false }
end

function RevealVoice.pick(state: State, rank: number, isNew: boolean, now: number, roll: number): { string }
	local slots: { string } = {}
	local announcer = RevealVoice.Announcer[rank]
	if announcer ~= nil then
		table.insert(slots, announcer)
	end
	if rank == 7 then
		table.insert(slots, "lucienLegendPull") -- Icon always speaks; Legend keeps the announcer only
		state.lastLine = now
	elseif rank == 4 or rank == 5 then
		local first = not state.seenStar
		state.seenStar = true
		if now - state.lastLine >= RevealVoice.COOLDOWN and (first or isNew or roll < RevealVoice.CHANCE) then
			table.insert(slots, "lucienRarePull")
			state.lastLine = now
		end
	end
	return slots
end

return RevealVoice
