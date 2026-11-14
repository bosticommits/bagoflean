--!strict
-- Where the Next Up "Show me" button points for each start goal (pure data; the client in
-- ShowMeUi.luau resolves the names to instances).
--   screen/focus: opened with Screens.open(screen, focus) first.
--   ui: the control to ring, found under the PlayerGui child `root`; `alt` is tried when `name` is
--       not on screen. `needsLot`: only when the player already owns a lot.
--   world: "claimPad" draws an arrow at the nearest free claim pad (only while the player has no lot).
local ShowMe = {}

export type Ui = { root: string, name: string, alt: string?, needsLot: boolean? }
export type Target = { screen: string?, focus: string?, ui: Ui?, world: string? }

ShowMe.TARGETS = {
	Start1 = { ui = { root = "CastingBar", name = "CastButton" } },
	Start2 = { ui = { root = "SideMenu", name = "StudioButton", needsLot = true }, world = "claimPad" },
	Start3 = { screen = "Upgrades", focus = "Luck", ui = { root = "UpgradeTreeChrome", name = "Buy" } },
	Start4 = { screen = "Studio", focus = "Stages", ui = { root = "StudioPanel", name = "StartMovie", alt = "StageAction" } },
	Start5 = { screen = "Upgrades", focus = "Stages", ui = { root = "UpgradeTreeChrome", name = "Buy" } },
	Start6 = { ui = { root = "CastingBar", name = "OddsButton" } },
} :: { [string]: Target }

local METRES_PER_STUD = 0.28

-- Studs shown as whole metres, never "0 m".
function ShowMe.metres(studs: number): number
	return math.max(1, math.floor(studs * METRES_PER_STUD + 0.5))
end

return ShowMe
