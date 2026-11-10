local H = require("./harness")
local Lines = H.require("TutorialLines")
local Sounds = H.require("Sounds")
local test, expect = H.test, H.expect

test("every tutorial line is short enough to read at a glance", function()
	for key, text in Lines.LINES do
		local _, spaces = string.gsub(text, "%S+", "")
		expect(spaces <= 12, `{key} has {spaces} words`)
		expect(utf8.len(text) :: number <= 60, `{key} is {utf8.len(text)} characters`)
	end
end)

test("every voiced line has a line and a real sound slot", function()
	for key, slotName in Lines.VOICE do
		expect(Lines.LINES[key] ~= nil, `voice for unknown line {key}`)
		expect(Sounds.Slots[slotName] ~= nil, `{key} names unknown slot {slotName}`)
	end
	for _, key in Lines.FINALE do
		expect(Lines.LINES[key] ~= nil, `finale names unknown line {key}`)
	end
	for _, result in { "Flop", "Hit", "Blockbuster", "Cult", "Masterpiece" } do
		expect(Lines.LINES[Lines.resultKey(result)] ~= nil, `no line for result {result}`)
	end
end)
