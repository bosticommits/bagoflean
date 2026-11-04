--!strict
-- The rules for the voice channel (Client/Sfx.luau plays them): voice lines (Lucien, the
-- announcer) never talk over each other. A line waits for the one before it to finish, a repeat of
-- the same line is dropped, and a line that would start too long after it was asked for is
-- dropped as stale. Pure and clock-free (the caller passes `now`), so Lune can test it.
local VoiceQueue = {}

VoiceQueue.REPEAT_GAP = 2 -- the same line again within this many seconds is dropped
VoiceQueue.MAX_WAIT = 3 -- a line that would start later than this after being asked for is dropped
VoiceQueue.GAP = 0.15 -- the pause left between two lines

export type State = { busyUntil: number, asked: { [string]: number } }

function VoiceQueue.new(): State
	return { busyUntil = 0, asked = {} }
end

-- `delay` is the slot's own wait (e.g. to let a sting land first), `duration` the clip length.
-- Returns when the line should start (same clock as `now`), or nil to drop it.
function VoiceQueue.schedule(state: State, name: string, now: number, delay: number, duration: number): number?
	local last = state.asked[name]
	if last ~= nil and now - last < VoiceQueue.REPEAT_GAP then
		return nil
	end
	local start = now + delay
	if state.busyUntil > 0 then
		start = math.max(start, state.busyUntil + VoiceQueue.GAP)
	end
	if start - now > VoiceQueue.MAX_WAIT then
		return nil
	end
	state.asked[name] = now
	state.busyUntil = start + duration
	return start
end

return VoiceQueue
