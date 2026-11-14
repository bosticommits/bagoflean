--!strict
-- Layout maths for Lucien's tutorial line inside a panel's title bar (docs/design/picker-layout.md
-- section 2.4). Pure numbers, so tests/luau can check them outside Roblox. UiKit.makePanel sizes the
-- DialogueSlot with `slot`; Tutorial.layout() places the bust, the pill and Skip with `pill`.
local TutorialPill = {}

TutorialPill.MIN_SLOT_PHONE = 280 -- a narrower slot keeps the corner bubble
TutorialPill.MIN_SLOT_PC = 350
TutorialPill.GAP = 12 -- slot to header text, and slot to the close X
TutorialPill.INNER = 6 -- between bust, pill and Skip

export type Slot = { x: number, y: number, rightInset: number, h: number }

-- The slot's place in a title bar, panel-local. Its width is panelW - x - rightInset (a UDim2 offset,
-- so it stays right before the panel's AbsoluteSize updates).
function TutorialPill.slot(headerRight: number, barH: number, closeSize: number, closeMargin: number): Slot
	local h = math.max(0, barH - 8)
	local x = headerRight + TutorialPill.GAP
	return { x = x, y = math.floor((barH - 4 - h) / 2), rightInset = closeSize + closeMargin + TutorialPill.GAP, h = h }
end

export type Pill = {
	bust: number,
	skipW: number,
	skipH: number,
	bustX: number, -- slot-local
	pillX: number,
	pillH: number, -- a little shorter than the slot, so the pill never touches the bar edges
	pillW: number,
	skipX: number, -- left edge of Skip
	textMax: number, -- UITextSizeConstraint cap
}

function TutorialPill.fits(slotW: number, compact: boolean): boolean
	return slotW >= (if compact then TutorialPill.MIN_SLOT_PHONE else TutorialPill.MIN_SLOT_PC)
end

function TutorialPill.pill(slotW: number, slotH: number, compact: boolean): Pill
	local bust = math.min(if compact then 28 else 36, slotH)
	local skipW = if compact then 52 else 64
	local skipH = math.min(if compact then 32 else 30, slotH)
	local gap = TutorialPill.INNER
	local pillX = bust + gap
	local skipX = slotW - skipW
	return {
		bust = bust,
		skipW = skipW,
		skipH = skipH,
		bustX = 0,
		pillX = pillX,
		pillH = math.max(0, slotH - 4),
		pillW = math.max(0, skipX - gap - pillX),
		skipX = skipX,
		textMax = if compact then 13 else 16,
	}
end

return TutorialPill
