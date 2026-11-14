--!nonstrict
-- Shared test harness for the rur UI stories (tests/ui). It makes the few things our real UI code
-- reaches for exist in rur's emulated DataModel, with fake data, then lets the stories call the
-- real `start` functions in src/client. No game code is replaced.
--
-- Faked: ReplicatedStorage.Remotes (silent RemoteEvents), the local player's attributes, the
-- ClientState snapshot (studio, roster, index) and the lots in workspace.Lots. Left alone: UiKit,
-- PhoneLayout, PickerLayout, TweenService (rur runs the tweens on its virtual clock; stories render
-- at --time 1.5 so entrance tweens are done) and every layout rule.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Harness = {}

local REMOTE_NAMES = {
	"RosterSync", "StudioSync", "RosterRequest", "StudioRequest", "RewardsSync", "RewardsRequest",
	"Cast", "CastResult", "ClaimReward", "BuyScript", "StartFilm", "Clap", "Premiere", "PremiereResult",
	"PremiereAll", "PremiereBatch", "QuickPremieres", "StudioError", "UseSkip",
	"EquipMascot", "BuyMascot", "SoundSettings", "ClaimAchievement", "ClaimRequest", "AchievementsSync", "AchievementsRequest", "TutorialDone",
	"VisitStudio", "VisitFilmSet", "Applaud", "Applause", "VisitNotice", "VisitArrived", "LotPremiere",
}

function Harness.client()
	return game:GetService("StarterPlayer").StarterPlayerScripts.Client
end

function Harness.shared()
	return ReplicatedStorage.Shared
end

-- Fake roster: 14 actor keys across tiers and variants (key "actorId:variantId" -> copies).
local ROSTER = {
	["NervousIntern:Normal"] = 3,
	["StuntDouble:Normal"] = 2,
	["BackgroundExtra:Shiny"] = 1,
	["SoapRegular:Normal"] = 1,
	["AdModel:Normal"] = 2,
	["ActionVeteran:Normal"] = 1,
	["NightShiftVillain:Shiny"] = 1,
	["MethodActor:Normal"] = 1,
	["SpaceCaptain:Award"] = 1,
	["IndieSidekick:Normal"] = 1,
	["ComedyDuo:Normal"] = 1,
	["TeenHeartthrob:Normal"] = 2,
	["BoxOfficeKing:Normal"] = 1,
	["ScreamQueen:Normal"] = 1,
}

-- Builds the fake world. `gui` is the story's own ScreenGui (RURStory), which stands in for the game's
-- MovieMogulUI. Returns it, with the modules already required.
function Harness.boot(Target: Frame)
	local gui = Target.Parent :: ScreenGui
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Main.client.luau's settings: the game sits inside Roblox's safe area (below the 36 px top bar).
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
	remotes.Parent = ReplicatedStorage

	local player = Players.LocalPlayer
	player:SetAttribute("DataLoaded", true)
	player:SetAttribute("Cash", 1234567)
	player:SetAttribute("Fame", 2300)
	player:SetAttribute("LotIndex", 3)
	player:SetAttribute("Pity" .. "Open", 12)

	-- Lots for the Visit screen: ours (lot 3) and five neighbours.
	local lots = Instance.new("Folder")
	lots.Name = "Lots"
	lots.Parent = workspace
	local names = { "Reel Deal", "Popcorn Palace", "Mogul Mansion", "Clapboard Co", "Starlight Pics", "Golden Hour" }
	for index, studioName in names do
		local lot = Instance.new("Model")
		lot.Name = "Lot" .. index
		lot:SetAttribute("OwnerUserId", if index == 3 then player.UserId else 1000 + index)
		lot:SetAttribute("StudioName", studioName)
		lot:SetAttribute("Likes", index * 37)
		lot:SetAttribute("Trophies", index)
		lot:SetAttribute("TopStar", "MethodActor")
		lot:SetAttribute("TopStarTier", "Star")
		lot.Parent = lots
	end

	local C = Harness.client()
	local ClientState = require(C.ClientState)
	local Movies = require(Harness.shared().Movies)
	local now = os.time()
	ClientState.roster = table.clone(ROSTER)
	ClientState.index = { ["NervousIntern:Normal"] = true, ["StuntDouble:Normal"] = true }
	ClientState.studio = {
		serverNow = now,
		stageCount = 3,
		stages = 3,
		passes = {},
		skips = 2,
		luckBoostUntil = 0,
		fame = 2300,
		rate = 125,
		scripts = {
			[Movies.scriptKey("Action", "Short")] = 2,
			[Movies.scriptKey("Comedy", "Indie")] = 1,
			[Movies.scriptKey("Horror", "Feature")] = 1,
		},
		films = {
			{
				stage = 2, title = "Midnight Reel", genre = "Horror", length = "Indie",
				cast = { "ActionVeteran:Normal", "SoapRegular:Normal" }, startTime = now - 120, endTime = now + 480,
			},
			{
				stage = 3, title = "Laugh Track", genre = "Comedy", length = "Short",
				cast = { "StuntDouble:Normal" }, startTime = now - 400, endTime = now - 10,
			},
		},
		cinema = {},
		upgrades = {},
		rewards = {},
		trophies = {},
		posters = {},
		tutorialDone = true,
		rebirths = 0,
	}
	ClientState.syncedAt = os.clock()
	return gui
end

-- The real screens, started the way Main.client.luau starts them. Returns the side menu buttons.
function Harness.startHud(gui: ScreenGui)
	local C = Harness.client()
	local side = require(C.SideMenu).start(gui)
	require(C.Hud).start(gui, side.wallet)
	return side
end

return Harness
