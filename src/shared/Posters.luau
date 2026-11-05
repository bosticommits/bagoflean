--!strict
-- The Cult Classic poster: a Cult result earns a collectible poster of the film, kept in the
-- Collection. Pure data rules, so the saved list can be checked (and old or damaged saves cleaned)
-- without Roblox.
local Posters = {}

export type Poster = {
	title: string,
	genre: string,
	cast: { string }, -- "actorId:variantId" keys, as on the film
	time: number,
}

Posters.Cap = 24 -- the most kept; a new poster pushes the oldest out

local MAX_TITLE = 60
local MAX_KEY = 64

-- A well-formed poster, or nil. Never trusts the saved shape.
local function tidy(raw: any): Poster?
	if type(raw) ~= "table" or type(raw.title) ~= "string" or type(raw.genre) ~= "string" then
		return nil
	end
	if #raw.title < 1 or #raw.title > MAX_TITLE or #raw.genre > 16 then
		return nil
	end
	local cast: { string } = {}
	if type(raw.cast) == "table" then
		for _, key in raw.cast do
			if type(key) == "string" and #key >= 1 and #key <= MAX_KEY and #cast < 3 then
				table.insert(cast, key)
			end
		end
	end
	local time = raw.time
	if type(time) ~= "number" or time ~= time or time < 0 then
		time = 0
	end
	return { title = raw.title, genre = raw.genre, cast = cast, time = time }
end

-- Cleans a saved list: keeps the well-formed posters (at most Cap, the newest), drops the rest.
-- Anything that is not a list (a save from before posters existed has none) becomes an empty list.
function Posters.clean(raw: any): { Poster }
	local out: { Poster } = {}
	if type(raw) == "table" then
		for _, entry in raw do
			local poster = tidy(entry)
			if poster ~= nil then
				table.insert(out, poster)
			end
		end
	end
	while #out > Posters.Cap do
		table.remove(out, 1)
	end
	return out
end

-- Adds a poster to `list` (in place). Returns false when the film is already there (same title and
-- genre), so a poster is never kept twice.
function Posters.add(list: { Poster }, poster: { title: string, genre: string, cast: { string }, time: number }): boolean
	local entry = tidy(poster)
	if entry == nil then
		return false
	end
	for _, have in list do
		if have.title == entry.title and have.genre == entry.genre then
			return false
		end
	end
	table.insert(list, entry)
	while #list > Posters.Cap do
		table.remove(list, 1)
	end
	return true
end

return Posters
