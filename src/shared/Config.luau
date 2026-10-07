return table.freeze({
	GameName = "Movie Mogul",

	LotCount = 6,

	StartingCash = 0,
	-- Cinema earns while you are away, up to the cap (plan section 2: start at 4 h).
	CinemaIncomePerSecond = 1,
	OfflineCapSeconds = 4 * 60 * 60,
	-- Minimum seconds between collects per player (server enforced).
	CollectCooldown = 0.3,

	-- Casting (plan section 3). Luck is 1 until M4 adds upgrades.
	CastCost = 20,
	BaseLuck = 1,
	-- Minimum seconds between casting calls per player (server enforced).
	CastCooldown = 0.6,
})
