--!strict
-- Rare-pull news (plan section 22): the banner text for a Superstar-and-up pull, the check every
-- cross-server message must pass, and a small sliding-window rate limiter. Pure, so Lune tests it.
-- The text is always rebuilt from our own Actors table: messages carry ids, never free text.
local Actors = require(script.Parent.Actors)

local PullNews = {}

PullNews.MinTier = "Superstar" -- banner in this server
PullNews.Global = { Legend = true, Icon = true } -- also sent to every other server

local function rank(tierId: string): number
	for index, tier in Actors.Tiers do
		if tier.id == tierId then
			return index
		end
	end
	return 0
end
PullNews.rank = rank

function PullNews.isBig(tierId: string): boolean
	return rank(tierId) >= rank(PullNews.MinTier)
end

local function comma(n: number): string
	local s = tostring(math.floor(n + 0.5))
	while true do
		local nextS, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = nextS
		if count == 0 then
			return s
		end
	end
end

-- Odds of this exact actor and variant at Luck 1 (Open Casting): tier odds, shared by the tier's
-- actors, times the variant's odds.
function PullNews.oneIn(actor: Actors.Actor, variant: Actors.Variant): number
	local tier = Actors.getTier(actor.tier)
	local share = math.max(1, #Actors.actorsInTier(actor.tier))
	return (if tier ~= nil then tier.oneIn else 1) * share * (variant.oneIn or 1)
end

-- "AVA pulled a SUPERSTAR: Box Office King! (1 in 16,000)". `name` nil means our own pull ("You").
function PullNews.text(name: string?, actor: Actors.Actor, variant: Actors.Variant, global: boolean?): string
	local what = string.upper(actor.tier)
	if variant.id ~= "Normal" then
		what = `{variant.name} {what}`
	end
	local article = if string.match(what, "^[AEIOU]") then "an" else "a"
	local who = if name == nil then "You" else name
	return `{if global then "WORLDWIDE: " else ""}{who} pulled {article} {what}: {actor.name}! (1 in {comma(PullNews.oneIn(actor, variant))})`
end

-- Several pulls at once collapse into one line: "3 big pulls: AVA (LEGEND), BEN (SUPERSTAR) +1".
export type Entry = { name: string, tier: string }
function PullNews.merge(entries: { Entry }): (string, string)
	local best = entries[1].tier
	local parts = {}
	for index, entry in entries do
		if rank(entry.tier) > rank(best) then
			best = entry.tier
		end
		if index <= 2 then
			table.insert(parts, `{entry.name} ({string.upper(entry.tier)})`)
		end
	end
	local extra = if #entries > 2 then ` +{#entries - 2}` else ""
	return `{#entries} big pulls: {table.concat(parts, ", ")}{extra}`, best
end

-- The cross-server message, built only on the server from trusted values.
export type Message = { u: number, a: string, v: string, t: string, j: string }
function PullNews.message(userId: number, actorId: string, variantId: string, tierId: string, jobId: string): Message
	return { u = userId, a = actorId, v = variantId, t = tierId, j = jobId }
end

-- Checks a message from another server. Returns the actor and variant, or nil to drop it.
function PullNews.validate(data: any, ownJobId: string): (Message?, Actors.Actor?, Actors.Variant?)
	if type(data) ~= "table" then
		return nil
	end
	local u, a, v, t, j = data.u, data.a, data.v, data.t, data.j
	if type(u) ~= "number" or u ~= u or u < 1 or u > 2 ^ 53 or u % 1 ~= 0 then
		return nil
	end
	if type(a) ~= "string" or #a > 64 or type(v) ~= "string" or #v > 32 or type(t) ~= "string" or #t > 32 then
		return nil
	end
	if type(j) ~= "string" or #j > 64 or j == ownJobId then
		return nil
	end
	local actor, variant = Actors.getActor(a), Actors.getVariant(v)
	if actor == nil or variant == nil or actor.tier ~= t or not PullNews.Global[t] then
		return nil
	end
	return { u = u, a = a, v = v, t = t, j = j }, actor, variant
end

-- At most `max` hits per `window` seconds. Call it with the current time; true means go ahead.
function PullNews.limiter(max: number, window: number): (now: number) -> boolean
	local hits: { number } = {}
	return function(now: number): boolean
		while hits[1] ~= nil and now - hits[1] >= window do
			table.remove(hits, 1)
		end
		if #hits >= max then
			return false
		end
		table.insert(hits, now)
		return true
	end
end

return PullNews
