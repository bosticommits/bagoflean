--!strict
-- How long a tutorial line stays up (Tutorial.luau). A voiced line outlasts its clip by GAP so
-- Lucien is never cut off; an unvoiced line (or a clip not loaded yet) keeps the old reading time.
-- Pure, so Lune can test it.
local TutorialPacing = {}

TutorialPacing.MIN_HOLD = 2.2
TutorialPacing.GAP = 0.8 -- silence between the clip's end and the next line

-- Seconds a finished line waits before the next one. `clip`: the voice clip's length (nil or 0
-- when unknown), `typingTime`: how long the text took to type.
function TutorialPacing.hold(chars: number, clip: number?, typingTime: number): number
	if clip ~= nil and clip > 0 then
		return math.max(TutorialPacing.MIN_HOLD, clip + TutorialPacing.GAP - typingTime)
	end
	return math.clamp(chars * 0.045, TutorialPacing.MIN_HOLD, 4)
end

-- A tap on a finished line moves on only once its clip has ended.
function TutorialPacing.canAdvance(now: number, clipEndsAt: number): boolean
	return now >= clipEndsAt
end

return TutorialPacing
