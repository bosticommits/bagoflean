--!strict
-- Director Lucien's tutorial lines: one short line per view key (Tutorial.luau), so a line can be
-- read at a glance. Tests (tests/luau/tutoriallines.spec.luau) keep each at 12 words / 60 chars.
-- VOICE maps a key to the Sounds slot of its spoken clip. The lucienTut slots have id = 0 until
-- the recordings are uploaded; the tutorial skips a slot with no id.
local TutorialLines = {}

TutorialLines.LINES = {
	intro1 = "Welcome to Hollywood RNG! I'm Director Lucien Vale.",
	intro2 = "Let's make your first hit. Ready?",
	cast = "Tap CAST to sign your first star!",
	claim = "Every star needs a studio. Walk onto a green pad!",
	studio = "Now a story. Tap Studio.",
	studioNear = "Press E to make a movie.", -- Tutorial swaps in the player's own key or tap hint
	scriptOpen = "Open Scripts.",
	scriptBuy = "Buy a Short Film. It films fast.",
	filmStages = "Open Stages.",
	filmStart = "Tap Start Movie.",
	filmScript = "Pick your Short Film.",
	filmActor = "Pick your new star. Genre match earns more.",
	filmGo = "Lights, camera… tap Start!",
	shoot = "Cameras rolling! Tap CLAP to speed it up.",
	ready = "It's ready. Tap PREMIERE!",
	resultFlop = "A flop! Every great director has one.",
	resultHit = "A hit! The audience loved it.",
	resultBlockbuster = "A blockbuster! Look at that crowd!",
	resultCult = "A cult classic! They'll quote this for years.",
	resultMasterpiece = "A masterpiece! The lot will never forget it.",
	collect = "Step on your gold pad to collect!",
	-- The wrap-up; lines 2 to 5 each point at a control (Tutorial.updateFinaleGuide).
	joy = "That's a wrap! Your first movie, producer.",
	tipGifts = "Free presents unlock as you play.",
	tipBar = "This bar tracks your next guaranteed star.",
	tipTuck = "Tap X to tuck the HUD away.",
	tipVisit = "Visit lets you tour other studios.",
}

TutorialLines.FINALE = { "joy", "tipGifts", "tipBar", "tipTuck", "tipVisit" }

-- A premiere result id (Flop, Hit...) to its line key.
function TutorialLines.resultKey(resultId: string): string
	return "result" .. resultId
end

TutorialLines.VOICE = {
	intro1 = "lucienWelcome",
	intro2 = "lucienTut1",
	cast = "lucienFirstCast",
	claim = "lucienTut2",
	studio = "lucienTut3",
	studioNear = "lucienTut4",
	scriptOpen = "lucienTut5",
	scriptBuy = "lucienTut6",
	filmStages = "lucienTut7",
	filmStart = "lucienTut8",
	filmScript = "lucienTut9",
	filmActor = "lucienTut10",
	filmGo = "lucienTut11",
	shoot = "lucienTut12",
	ready = "lucienTut13",
	resultFlop = "lucienTut14",
	resultHit = "lucienTut15",
	resultBlockbuster = "lucienTut16",
	resultCult = "lucienTut17",
	resultMasterpiece = "lucienTut18",
	collect = "lucienTut19",
	joy = "lucienTut20",
}

return TutorialLines
