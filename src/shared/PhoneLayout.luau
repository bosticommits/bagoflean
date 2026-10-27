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
		-- The gifts sit above Roblox's jump control. On landscape phones it must also
		-- remain above the bottom controls; portrait gets a larger reserved band.
		giftBottomInset = if touch and width < height then 218 elseif touch then (if shortSide <= 500 then 100 else 220) else 76,
		soundSize = if touch then (if compact then 34 else 40) else 48,
		soundTopInset = if touch then (if compact then 66 else 86) else 0,
		castBottomInset = if touch and width < height then 130 else 14,
	}
end

return PhoneLayout
