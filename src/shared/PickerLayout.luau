--!strict
-- Layout maths for the Start-movie picker (docs/design/picker-layout.md section 2). Pure numbers in
-- main-gui pixels, so tests/luau can check every viewport outside Roblox. StudioUi applies them.
local PickerLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }

export type Footer = {
	height: number,
	twoRow: boolean,
	slotSize: number,
	slotGap: number,
	slotCentres: { { x: number, y: number } }, -- centre of each cast slot, footer-local (slots are centre-anchored)
	text: Rect, -- the two text lines (footer-local)
	lineH: number,
	lineGap: number,
	clear: Rect,
	go: Rect,
}

export type Body = {
	scripts: Rect, -- panel-local
	cast: Rect,
	headingH: number, -- 0 on a phone (no pane headings)
	headingY: number,
}

export type Grid = { cols: number, cellW: number, cellH: number, gap: number }

PickerLayout.STROKE = 5 -- the panel outline, drawn outside the panel
PickerLayout.MAX_W = 760
PickerLayout.MAX_H = 600

local function pick<T>(compact: boolean, phone: T, pc: T): T
	return if compact then phone else pc
end

-- Outer gutter, to the outer edge of the outline or the corner icon.
function PickerLayout.gutter(compact: boolean): number
	return pick(compact, 12, 16)
end

function PickerLayout.iconTop(compact: boolean): number
	return pick(compact, 14, 16)
end

function PickerLayout.iconLeft(compact: boolean): number
	return pick(compact, 10, 14)
end

function PickerLayout.padding(compact: boolean): number
	return pick(compact, 8, 12)
end

function PickerLayout.titleHeight(compact: boolean): number
	return pick(compact, 40, 54)
end

-- The panel rect in main-gui space. `panelTop` is the tutorial bubble's reserve (PR 2 removes it).
function PickerLayout.panelRect(areaW: number, areaH: number, menuRight: number, compact: boolean, panelTop: number?, maxW: number, maxH: number): Rect
	local g = PickerLayout.gutter(compact)
	local leftBound = menuRight + g + math.max(PickerLayout.STROKE, PickerLayout.iconLeft(compact))
	local rightBound = areaW - g - PickerLayout.STROKE
	local topBound = g + math.max(PickerLayout.STROKE, PickerLayout.iconTop(compact))
	if panelTop ~= nil then
		topBound = math.max(topBound, panelTop + PickerLayout.iconTop(compact))
	end
	local bottomBound = areaH - g - PickerLayout.STROKE
	local w = math.max(0, math.min(rightBound - leftBound, maxW))
	local h = math.max(0, math.min(bottomBound - topBound, maxH))
	local x = if areaW / 2 - w / 2 >= leftBound then areaW / 2 - w / 2 else leftBound
	local y = topBound + (bottomBound - topBound - h) / 2
	return { x = math.floor(x + 0.5), y = math.floor(y + 0.5), w = math.floor(w), h = math.floor(h) }
end

-- The footer ("call sheet") for a panel `w` wide. `slots` is Config.MaxCast.
function PickerLayout.footer(w: number, compact: boolean, slots: number): Footer
	local pad = PickerLayout.padding(compact)
	local s = pick(compact, 40, 56)
	local slotGap = pick(compact, 6, 8)
	local btnGap = pick(compact, 8, 10)
	local textGap = pick(compact, 10, 16)
	local textRightGap = pick(compact, 10, 14)
	local clearW, clearH = pick(compact, 84, 130), pick(compact, 40, 52)
	local goW, goH = pick(compact, 128, 210), pick(compact, 44, 56)
	local minText = pick(compact, 110, 150)
	local lineH, lineGap = pick(compact, 18, 24), pick(compact, 2, 4)
	local textX = pad + slots * s + (slots - 1) * slotGap + textGap
	local goX = w - pad - goW
	local clearX = goX - btnGap - clearW
	local textW = clearX - textRightGap - textX
	local twoRow = textW < minText
	local f = pick(compact, 60, 84)
	local centres: { { x: number, y: number } } = {}
	local textRect: Rect
	local clear: Rect
	local go: Rect
	if not twoRow then
		for i = 1, slots do
			table.insert(centres, { x = pad + s / 2 + (i - 1) * (s + slotGap), y = f / 2 })
		end
		local block = 2 * lineH + lineGap
		textRect = { x = textX, y = (f - block) / 2, w = textW, h = block }
		clear = { x = clearX, y = (f - clearH) / 2, w = clearW, h = clearH }
		go = { x = goX, y = (f - goH) / 2, w = goW, h = goH }
	else
		f = pick(compact, 96, 132)
		for i = 1, slots do
			table.insert(centres, { x = pad + s / 2 + (i - 1) * (s + slotGap), y = pad + s / 2 })
		end
		local block = 2 * lineH + lineGap
		textRect = { x = textX, y = pad + (s - block) / 2, w = w - pad - textX, h = block }
		local rowH = pick(compact, 34, 44)
		local rowY = pad + s + pick(compact, 6, 8)
		local inner = w - 2 * pad - btnGap
		local clearW2 = math.floor(inner * 0.34)
		clear = { x = pad, y = rowY, w = clearW2, h = rowH }
		go = { x = pad + clearW2 + btnGap, y = rowY, w = inner - clearW2, h = rowH }
	end
	return {
		height = f,
		twoRow = twoRow,
		slotSize = s,
		slotGap = slotGap,
		slotCentres = centres,
		text = textRect,
		lineH = lineH,
		lineGap = lineGap,
		clear = clear,
		go = go,
	}
end

-- The two panes, in panel-local pixels. `footerH` is Footer.height.
function PickerLayout.body(w: number, h: number, compact: boolean, footerH: number): Body
	local pad = PickerLayout.padding(compact)
	local top = PickerLayout.titleHeight(compact) + pad
	local headingH = pick(compact, 0, 24)
	local listTop = top + pick(compact, 0, 30)
	local bottom = h - footerH - pad
	local bodyW = w - 2 * pad
	local scriptsW = math.clamp(math.floor(bodyW * 0.3 + 0.5), 140, 220)
	local gap = pick(compact, 8, 12)
	local listH = math.max(0, bottom - listTop)
	return {
		scripts = { x = pad, y = listTop, w = scriptsW, h = listH },
		cast = { x = pad + scriptsW + gap, y = listTop, w = math.max(0, bodyW - scriptsW - gap), h = listH },
		headingH = headingH,
		headingY = top,
	}
end

PickerLayout.GRID_PADDING = 3 -- UIPadding on every side of the cast pane

-- Actor card grid for a cast pane whose scroll window is `windowW` wide (padding not included).
function PickerLayout.grid(windowW: number, compact: boolean): Grid
	local contentW = windowW - 2 * PickerLayout.GRID_PADDING
	local gap = pick(compact, 8, 10)
	local minW = pick(compact, 100, 140)
	local cols = math.max(2, math.floor((contentW + gap) / (minW + gap)))
	local cellW = math.max(1, math.floor((contentW - (cols - 1) * gap) / cols))
	local cellH = math.floor(cellW * 0.62 + 0.5) + pick(compact, 40, 52)
	return { cols = cols, cellW = cellW, cellH = cellH, gap = gap }
end

return PickerLayout
