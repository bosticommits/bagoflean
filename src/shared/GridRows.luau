--!strict
-- Splits N cards into rows of `columns`. UIGridLayout never centres a partial last row, so the Shop puts each row in
-- its own centred row frame; this is the pure part (tested in Lune): how many cards go in each row.
local GridRows = {}

function GridRows.split(count: number, columns: number): { number }
	local rows: { number } = {}
	local left = math.max(0, math.floor(count))
	local per = math.max(1, math.floor(columns))
	while left > 0 do
		local n = math.min(per, left)
		table.insert(rows, n)
		left -= n
	end
	return rows
end

return GridRows
