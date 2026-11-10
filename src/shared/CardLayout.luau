--!strict
-- Vertical layout of the cast reveal card (CastingUi.luau), worked out from the card's real pixel
-- height so the foot buttons (44 px at least) always leave CLEAR px between the stat chips and the
-- buttons' gold halo. Everything above the chips shrinks to make room. Pure, so Lune can test it.
local CardLayout = {}

CardLayout.MIN_BUTTON = 44 -- tap height
CardLayout.CLEAR = 20 -- stats bottom to the halo's outer edge
CardLayout.HALO = 8 -- how far the Cast again halo reaches past the button (5 gap + half the stroke)
CardLayout.MIN_STATS = 30

export type Layout = {
	artY: number, -- every field below is a fraction of the card's height
	artH: number,
	nameY: number,
	nameH: number,
	ribbonY: number,
	ribbonH: number,
	statsY: number,
	statsH: number,
	buttonH: number,
	buttonBottom: number, -- the buttons' bottom edge (anchor y = 1)
}

-- Card height as a fraction of the overlay: taller on short screens (phones in landscape).
function CardLayout.cardScale(overlayHeight: number): number
	return if overlayHeight < 500 then 0.9 else 0.72
end

function CardLayout.compute(cardHeight: number): Layout
	local h = math.max(cardHeight, 1)
	local buttonH = math.max(CardLayout.MIN_BUTTON, 0.12 * h)
	local pad = 0.015 * h
	local buttonTop = h - pad - buttonH
	local statsH = math.max(CardLayout.MIN_STATS, 0.125 * h)
	local statsTop = buttonTop - CardLayout.HALO - CardLayout.CLEAR - statsH
	local band = 0.09 * h -- the name and the ribbon
	local ribbonY = statsTop - 0.02 * h - band
	local nameY = ribbonY - band
	local artY = 0.08 * h
	return {
		artY = artY / h,
		artH = (nameY + 0.04 * h - artY) / h, -- the actor's feet tuck behind the name, as before
		nameY = nameY / h,
		nameH = band / h,
		ribbonY = ribbonY / h,
		ribbonH = band / h,
		statsY = statsTop / h,
		statsH = statsH / h,
		buttonH = buttonH / h,
		buttonBottom = (h - pad) / h,
	}
end

return CardLayout
