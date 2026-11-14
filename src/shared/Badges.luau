--!strict
-- Badges: official Roblox badges awarded via BadgeService.
--
-- Set real badge IDs created on the Creator Hub (Badges tab). An ID of 0 is ignored.
local Badges = {}

export type BadgeDef = {
	id: number,
	name: string,
	description: string,
}

-- Registry of game badges
Badges.List = {
	FirstFilm = { id = 0, name = "That's a Wrap!", description = "Premiere your very first movie" },
	FirstBlockbuster = { id = 0, name = "Box Office Smash", description = "Premiere a Blockbuster or better" },
	Masterpiece = { id = 0, name = "Cinematic Genius", description = "Produce a Masterpiece" },
	StarDiscovered = { id = 0, name = "A Star is Born", description = "Discover a Star tier actor" },
	IconDiscovered = { id = 0, name = "Hollywood Royalty", description = "Discover an Icon tier actor" },
	FirstSequel = { id = 0, name = "The Sequel", description = "Perform your first Rebirth / Sequel" },
	FoundingTester = { id = 0, name = "Founding Tester", description = "Played Hollywood RNG before launch" },
	MascotOwner = { id = 0, name = "Studio Pet", description = "Equip or adopt a studio mascot" },
} :: { [string]: BadgeDef }

return Badges
