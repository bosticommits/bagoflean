--!strict
-- Director Lucien's tutorial lines: one short line per view key (Tutorial.luau), so a line can be
-- read at a glance. Tests (tests/luau/tutoriallines.spec.luau) keep each at 12 words / 60 chars.
-- VOICE maps a key to the Sounds slot of its spoken clip (lines without one, such as "Open
-- Scripts.", stay silent).
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
	intro1 = "lucienTutWelcome",
	intro2 = "lucienTutIntro",
	cast = "lucienTutCast",
	claim = "lucienTutPad",
	studio = "lucienTutStudio",
	scriptBuy = "lucienTutBuyFilm",
	filmGo = "lucienTutStart",
	shoot = "lucienTutClap",
	ready = "lucienTutPremiere",
	resultFlop = "lucienTutFlop",
	resultHit = "lucienTutHit",
	resultBlockbuster = "lucienTutBlockbuster",
	resultCult = "lucienTutCult",
	resultMasterpiece = "lucienTutMasterpiece",
	collect = "lucienTutCollect",
	joy = "lucienTutWrap",
}

return TutorialLines
