local fs = require("@lune/fs")

local H = require("./harness")
local Sounds = H.require("Sounds")
local test, expect, equal = H.test, H.expect, H.equal

test("every sound slot plays something", function()
	for name, slot in Sounds.Slots do
		expect(slot.id ~= 0 or Sounds.Library[slot.fallback] ~= nil, `slot {name} has no id and an unknown fallback "{slot.fallback}"`)
		local id, volume, pitch = Sounds.resolve(name)
		expect(id ~= nil and id > 0, `slot {name} resolves to no sound`)
		expect(volume > 0 and volume <= 1, `slot {name} volume {volume} is outside 0..1`)
		expect(pitch >= 0.5 and pitch <= 2, `slot {name} pitch {pitch} is extreme`)
	end
	equal(Sounds.resolve("noSuchSlot"), nil)
end)

test("every Sfx.play in the client names a real slot", function()
	local count = 0
	for _, file in fs.readDir("src/client") do
		if string.match(file, "%.luau$") then
			local source = fs.readFile("src/client/" .. file)
			for name in string.gmatch(source, 'Sfx%.play%("([%w_]+)"') do
				count += 1
				expect(Sounds.Slots[name] ~= nil, `{file} plays unknown slot "{name}"`)
			end
			for a, b in string.gmatch(source, 'Sfx%.play%(if [^)]- then "([%w_]+)" else "([%w_]+)"%)') do
				count += 2
				expect(Sounds.Slots[a] ~= nil and Sounds.Slots[b] ~= nil, `{file} plays unknown slot "{a}" or "{b}"`)
			end
		end
	end
	expect(count > 10, `found only {count} Sfx.play calls; the pattern may be stale`)
end)

test("music tracks have sane volumes", function()
	for _, track in Sounds.Music.lobby do
		expect(track.volume > 0 and track.volume <= 1, `{track.name} volume`)
	end
	expect(Sounds.Music.event.volume > 0 and Sounds.Music.event.volume <= 1, "event track volume")
	for _, track in Sounds.lobbyTracks() do
		expect(track.id ~= 0, "lobbyTracks lists only tracks with ids")
	end
end)

test("volume settings are cleaned to 10% steps in 0..1", function()
	equal(Sounds.cleanVolume(0.5, 1), 0.5)
	equal(Sounds.cleanVolume(0.44, 1), 0.4)
	equal(Sounds.cleanVolume(-3, 1), 0)
	equal(Sounds.cleanVolume(7, 0), 1)
	equal(Sounds.cleanVolume(0 / 0, 0.6), 0.6)
	equal(Sounds.cleanVolume("loud", 0.6), 0.6)
	equal(Sounds.cleanVolume(nil, 1), 1)
end)
