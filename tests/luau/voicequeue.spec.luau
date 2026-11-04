local H = require("./harness")
local VoiceQueue = H.require("VoiceQueue")
local Sounds = H.require("Sounds")
local test, expect, equal = H.test, H.expect, H.equal

test("a lone voice line starts after its own delay", function()
	local q = VoiceQueue.new()
	equal(VoiceQueue.schedule(q, "a", 10, 0.8, 2), 10.8)
end)

test("a second line waits for the first to finish", function()
	local q = VoiceQueue.new()
	VoiceQueue.schedule(q, "a", 10, 0, 2) -- talks until 12
	equal(VoiceQueue.schedule(q, "b", 10.5, 0, 1), 12 + VoiceQueue.GAP)
end)

test("a line that follows a finished one is not held back", function()
	local q = VoiceQueue.new()
	VoiceQueue.schedule(q, "a", 10, 0, 1)
	equal(VoiceQueue.schedule(q, "b", 20, 0.5, 1), 20.5)
end)

test("the same line again within 2 s is dropped, later it plays", function()
	local q = VoiceQueue.new()
	VoiceQueue.schedule(q, "a", 10, 0, 1)
	equal(VoiceQueue.schedule(q, "a", 11.5, 0, 1), nil)
	equal(VoiceQueue.schedule(q, "a", 12.5, 0, 1), 12.5)
end)

test("a line that would start too late is dropped and does not block the queue", function()
	local q = VoiceQueue.new()
	VoiceQueue.schedule(q, "a", 10, 0, 6) -- talks until 16
	equal(VoiceQueue.schedule(q, "b", 11, 0, 1), nil)
	equal(VoiceQueue.schedule(q, "c", 14, 0, 1), 16 + VoiceQueue.GAP) -- waited 2.15 s
	equal(q.asked.b, nil)
end)

test("voice slots are marked and their delays are sane", function()
	local voices = 0
	for name, slot in Sounds.Slots do
		if string.sub(name, 1, 6) == "lucien" then
			expect(Sounds.isVoice(name), `{name} should be a voice slot`)
		end
		if Sounds.isVoice(name) then
			voices += 1
		end
		local delay = Sounds.delayOf(name)
		expect(delay >= 0 and delay <= 1.5, `slot {name} delay {delay} is outside 0..1.5`)
		expect(delay == 0 or slot.delay ~= nil, `{name} delay mismatch`)
	end
	expect(voices >= 15, `only {voices} voice slots`)
	equal(Sounds.isVoice("click"), false)
	equal(Sounds.isVoice("noSuchSlot"), false)
end)
