--!strict
-- Pure rules of the loading screen (no Instances): progress easing, the timing / cap state machine,
-- tip rotation, countdown numbers and preload batching. Tested in tests/luau/loadingscreen.spec.luau.
-- Lives in ReplicatedFirst next to LoadingScreen.client.luau, which must not wait for ReplicatedStorage.
local LoadingLogic = {}

LoadingLogic.MIN_SECONDS = 1.5 -- never shown for less than this, unless skipped
LoadingLogic.CAP_SECONDS = 8 -- hard cap: fade out whatever is still loading
LoadingLogic.TIP_SECONDS = 3
LoadingLogic.FRAMES = 10 -- film-strip cells
LoadingLogic.BATCH = 5 -- assets per PreloadAsync call

-- Lucien's tips: at most 12 words each, teach the loop (cast, studio, film, premiere, collect).
-- No Robux or purchase hints. Kept here, not in TutorialLines, because ReplicatedFirst runs before
-- ReplicatedStorage has replicated.
LoadingLogic.TIPS = {
	"Tap CAST to sign a star. Luck picks who walks in.",
	"Every star needs a studio. Walk onto a green pad.",
	"Match a star's genre to the script. Hits pay more.",
	"Short films shoot fast. Tap CLAP to speed them up.",
	"Premiere your movie, then collect from the gold pad.",
	"Spend Cash on scripts and upgrades. Then cast again.",
	"Rarer stars make bigger hits. Keep casting, producer!",
	"A flop? Every great director has one. Roll again!",
}

-- What each step of loading is worth toward the bar (sums to 1).
local WEIGHTS = { loaded = 0.2, ready = 0.35, character = 0.15, preload = 0.3 }

export type Inputs = {
	loaded: boolean, -- game:IsLoaded()
	ready: boolean, -- the client UI says it is built and synced
	character: boolean, -- the character has spawned
	preload: number, -- 0..1 of first-screen assets handled
}

-- Real progress 0..1 from what is done.
function LoadingLogic.target(inputs: Inputs): number
	local total = 0
	if inputs.loaded then
		total += WEIGHTS.loaded
	end
	if inputs.ready then
		total += WEIGHTS.ready
	end
	if inputs.character then
		total += WEIGHTS.character
	end
	total += WEIGHTS.preload * math.clamp(inputs.preload, 0, 1)
	return math.clamp(total, 0, 1)
end

LoadingLogic.EASE_RATE = 5 -- 1/s: how fast the bar closes the gap to the real progress
LoadingLogic.CREEP_RATE = 0.06 -- progress per second when waiting, so the bar never looks frozen
LoadingLogic.CREEP_CEILING = 0.92 -- creep stops here until the real progress is done

-- One frame of the displayed progress: eased toward `target`, never backwards, never frozen (it
-- creeps up to CREEP_CEILING), and exactly 1 once the target is 1 and the gap is closed.
function LoadingLogic.step(shown: number, target: number, dt: number): number
	dt = math.max(dt, 0)
	local eased = shown + (target - shown) * (1 - math.exp(-LoadingLogic.EASE_RATE * dt))
	local creep = math.min(shown + LoadingLogic.CREEP_RATE * dt, LoadingLogic.CREEP_CEILING)
	local nextValue = math.max(eased, creep)
	if target >= 1 and nextValue > 0.995 then
		nextValue = 1
	end
	return math.clamp(math.max(nextValue, shown), 0, 1)
end

export type Reason = "ready" | "cap" | "skip"

-- Should the screen end now? Skip wins at once; the cap wins over missing inputs; otherwise
-- everything must be done and the minimum time shown.
function LoadingLogic.decide(elapsed: number, inputs: Inputs, skipped: boolean): Reason?
	if skipped then
		return "skip"
	end
	if elapsed >= LoadingLogic.CAP_SECONDS then
		return "cap"
	end
	if elapsed >= LoadingLogic.MIN_SECONDS and inputs.loaded and inputs.ready and inputs.character and inputs.preload >= 1 then
		return "ready"
	end
	return nil
end

-- Fade length: a new player's fade reveals the curtain intro (0.4 s), a returning player's goes
-- straight to the world (0.3 s).
function LoadingLogic.fadeSeconds(newPlayer: boolean): number
	return if newPlayer then 0.4 else 0.3
end

-- The tip shown after `elapsed` seconds, 1-based, starting from `startIndex`.
function LoadingLogic.tipIndex(elapsed: number, startIndex: number, count: number): number
	if count <= 0 then
		return 1
	end
	local turns = math.floor(math.max(elapsed, 0) / LoadingLogic.TIP_SECONDS)
	return (startIndex - 1 + turns) % count + 1
end

-- The leader countdown: 3, 2, 1 one second each, looping.
function LoadingLogic.countNumber(elapsed: number): number
	return 3 - math.floor(math.max(elapsed, 0) % 3)
end

-- Sweeping hand: one turn per second, degrees clockwise from 12 o'clock.
function LoadingLogic.handAngle(elapsed: number): number
	return (math.max(elapsed, 0) % 1) * 360
end

-- Film-strip fill: how many cells are full, and how full the next one is (0..1).
function LoadingLogic.filled(progress: number, frames: number): (number, number)
	local scaled = math.clamp(progress, 0, 1) * frames
	local whole = math.min(math.floor(scaled), frames)
	return whole, if whole >= frames then 0 else scaled - whole
end

-- Splits a list into batches of `size` (PreloadAsync works best in small calls).
function LoadingLogic.batches<T>(list: { T }, size: number): { { T } }
	local out: { { T } } = {}
	local current: { T } = {}
	for _, item in list do
		table.insert(current, item)
		if #current >= size then
			table.insert(out, current)
			current = {}
		end
	end
	if #current > 0 then
		table.insert(out, current)
	end
	return out
end

-- Which assets to try again: only those that timed out. A Failure (bad id) is never retried.
function LoadingLogic.retryList(statuses: { [string]: string }): { string }
	local out: { string } = {}
	for id, status in statuses do
		if status == "TimedOut" then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

return LoadingLogic
