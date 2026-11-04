local H = require("./harness")
local PullNews = H.require("PullNews")
local Actors = H.require("Actors")
local test, expect, equal = H.test, H.expect, H.equal

local legend = Actors.actorsInTier("Legend")[1]
local superstar = Actors.actorsInTier("Superstar")[1]
local function good(): any
	return { u = 12345, a = legend.id, v = "Shiny", t = "Legend", j = "other-job" }
end

test("a good message from another server passes and gives back the actor", function()
	local msg, actor, variant = PullNews.validate(good(), "my-job")
	expect(msg ~= nil, "accepted")
	equal(actor, legend)
	equal(variant.id, "Shiny")
end)

test("bad fields, unknown ids, small tiers and our own server are dropped", function()
	local function drop(change: (any) -> (), why: string)
		local data = good()
		change(data)
		equal(PullNews.validate(data, "my-job"), nil, why)
	end
	expect(PullNews.validate("hi", "my-job") == nil, "not a table")
	drop(function(d) d.u = "12345" end, "user id as text")
	drop(function(d) d.u = 0 / 0 end, "NaN user id")
	drop(function(d) d.u = -5 end, "negative user id")
	drop(function(d) d.u = 1.5 end, "fractional user id")
	drop(function(d) d.u = math.huge end, "infinite user id")
	drop(function(d) d.a = "NotAnActor" end, "unknown actor")
	drop(function(d) d.a = string.rep("x", 100) end, "huge actor id")
	drop(function(d) d.v = "Golden" end, "unknown variant")
	drop(function(d) d.t = "Icon" end, "tier does not match the actor")
	drop(function(d) d.a, d.t = superstar.id, "Superstar" end, "Superstar is not global")
	drop(function(d) d.j = "my-job" end, "our own message")
	drop(function(d) d.j = 7 end, "job id not text")
end)

test("the banner text is rebuilt from our own tables", function()
	local normal = Actors.getVariant("Normal")
	local text = PullNews.text("AVA", superstar, normal)
	expect(string.find(text, "AVA pulled a SUPERSTAR: " .. superstar.name, 1, true) ~= nil, text)
	expect(string.find(text, "(1 in ", 1, true) ~= nil, "shows the odds")
	expect(string.find(PullNews.text(nil, legend, Actors.getVariant("Award"), true), "^WORLDWIDE: You pulled an Award") ~= nil, "global, own, an")
end)

test("bursts merge into one line led by the rarest tier", function()
	local text, best = PullNews.merge({ { name = "A", tier = "Superstar" }, { name = "B", tier = "Icon" }, { name = "C", tier = "Legend" } })
	equal(best, "Icon")
	equal(text, "3 big pulls: A (SUPERSTAR), B (ICON) +1")
	expect(PullNews.isBig("Superstar") and not PullNews.isBig("Star"), "Superstar and up")
end)

test("the limiter allows max per window and frees up as time passes", function()
	local allow = PullNews.limiter(2, 10)
	expect(allow(0) and allow(1), "first two")
	expect(not allow(5), "third in the window is refused")
	expect(allow(10.5), "the first hit left the window")
	expect(not allow(10.6), "full again")
	local publish = PullNews.limiter(1, 10)
	expect(publish(0) and not publish(9.9) and publish(10), "one per 10 s")
end)
