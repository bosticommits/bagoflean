--!strict
-- Fits a line of dialogue into its box so no word is ever cut off: the biggest text size from
-- `maxSize` down to `minSize` that shows the whole line, and if even `minSize` is too big, the
-- line split into pages (whole words) that each fit. `measure(text, size, width)` is the wrapped
-- text's size (TextService:GetTextSize in the game, a stand-in in the tests).
local Dialogue = {}

export type Measure = (text: string, size: number, width: number) -> Vector2

function Dialogue.fit(text: string, box: Vector2, maxSize: number, minSize: number, measure: Measure): ({ string }, number)
	local function fits(chunk: string, size: number): boolean
		return measure(chunk, size, box.X).Y <= box.Y
	end
	local size = maxSize
	while size > minSize and not fits(text, size) do
		size -= 1
	end
	if fits(text, size) then
		return { text }, size
	end
	local pages: { string } = {}
	local page = ""
	for word in string.gmatch(text, "%S+") do
		local longer = if page == "" then word else page .. " " .. word
		if page ~= "" and not fits(longer, size) then
			table.insert(pages, page)
			page = word
		else
			page = longer
		end
	end
	table.insert(pages, page)
	return pages, size
end

return Dialogue
