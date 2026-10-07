return table.freeze({
	GameName = "Movie Mogul",

	LotCount = 6,

	StartingCash = 0,
	-- Cinema earns while you are away, up to the cap (plan section 2: start at 4 h).
	-- Base income is the free trickle; each finished movie adds RoyaltyRate x its payout per second.
	CinemaIncomePerSecond = 1,
	RoyaltyRate = 0.0005,
	CinemaCapacity = 10, -- finished movies kept in the cinema; the oldest is replaced
	OfflineCapSeconds = 4 * 60 * 60,
	-- Minimum seconds between collects per player (server enforced).
	CollectCooldown = 0.3,

	-- Casting (plan section 3). Agency prices live in Actors.Agencies; Luck grows with upgrades and
	-- Index rewards (see Upgrades).
	BaseLuck = 1,
	TierRewardLuck = 0.05, -- per completed Index tier row, once claimed
	GenreBonus = 0.15, -- extra payout multiplier for a genre once all its actors are discovered
	OfflineCapStepSeconds = 2 * 60 * 60, -- per Offline upgrade level
	-- Minimum seconds between casting calls per player (server enforced).
	CastCooldown = 0.6,

	-- Movies (plan section 2).
	StartingStages = 1, -- sound stages; M4 upgrades raise this to MaxStages
	MaxStages = 4,
	MaxCast = 3,
	ClapSeconds = 2, -- taken off the filming timer per clapperboard tap
	ClapCooldown = 0.4,
	ActionCooldown = 0.25, -- min seconds between shop/start/premiere requests per player
})
