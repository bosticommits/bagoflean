--!strict
-- Redeemable codes (plan section 5: "codes for socials"). Server only, so the list never reaches
-- clients. Add a code here and publish; players type it on the Codes tab (any case, spaces ignored).
-- `expires` is an optional os.time() stamp (UTC); after it the code says "expired". To switch a code
-- off without an update, see LiveConfig.
-- Rewards use the same shape as daily rewards (see Shop.Reward). Keep them modest: codes are public.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shop = require(ReplicatedStorage.Shared.Shop)

-- `dev` codes work only for the game's creator (a user-owned game) and can be used again and again;
-- anyone else is told "Invalid code" (RewardService).
export type Code = { reward: Shop.Reward, expires: number?, dev: boolean? }

return table.freeze({
	PREMIERE = { reward = { cash = 500, cashMinutes = 15 } },
	LIGHTSCAMERA = { reward = { luckMinutes = 10 } },
	DIRECTORSCUT = { reward = { cash = 9_900_000, fame = 500_000 }, dev = true },
	ACTION = { reward = { script = { genre = "Action", length = "Indie", count = 2 } } },
} :: { [string]: Code })
