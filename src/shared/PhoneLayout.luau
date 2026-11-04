--!strict
-- Shared responsive breakpoints and touch-control clearances. ScreenGui uses
-- CoreUISafeInsets, so these offsets are measured inside the Roblox/device safe area.
local PhoneLayout = {}

export type Profile = {
	compact: boolean,
	menuGrow: number,
	walletScale: number,
	giftScale: number,
	giftBottomInset: number,
	jumpTop: number,
	soundSize: number,
	soundTopInset: number,
	castBottomInset: number,
}

function PhoneLayout.profile(width: number, height: number, touch: boolean): Profile
	local shortSide = math.min(width, height)
	local compact = shortSide <= 500 or height < 500
	return {
		compact = compact,
		menuGrow = math.clamp(height / 880, 1, 1.25),
		walletScale = math.clamp(height / 880, if height < 500 then 0.8 else 1, 1.25),
		giftScale = if compact then 0.8 else 1,
		-- PC: the gift row sits above the 48 px sound button. Touch screens show one present
		-- button by the HUD pull tab instead (PlaytimeGiftsUi), placed from jumpTop.
		giftBottomInset = 76,
		-- Top of Roblox's jump button: 90 px up on small screens, 210 px once the short side is over 500 px.
		jumpTop = if shortSide <= 500 then 90 else 210,
		soundSize = if touch then (if compact then 34 else 40) else 48,
		soundTopInset = if touch then (if compact then 66 else 86) else 0,
		castBottomInset = if touch and width < height then 130 else 14,
	}
end

return PhoneLayout
