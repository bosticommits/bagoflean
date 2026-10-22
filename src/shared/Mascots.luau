--!strict
-- Studio mascots: little companions that follow their owner round town. Every studio starts with
-- the Popcorn Pup; the others are bought once on the Mascots screen, with in-game Cash or with
-- Robux (a developer product per mascot), and kept for good (a rebirth resets Cash, never
-- mascots). Both ways give the very same mascot and buff: Robux only skips the saving up. The
-- models are Blender designs (art/blender/mascots.py); MascotService and ShopService check every
-- purchase and equip with this file and the Mascots screen shows the same rules.
--
-- Buffs (plan: plans/MASCOT_BUFFS.md in the project files). Each mascot gives one small buff, and
-- only the mascot a player has out counts, so buffs never stack. Every kind has a hard cap
-- (Mascots.Caps, checked by tests) kept well under the Robux pass that does the same job, and a
-- buff only switches on WarmUp seconds after equipping, so swapping mascots between a cast and a
-- premiere cannot collect two buffs. The server applies them:
--   cash       movie Cash, after Fame is worked out (MovieService), like the rebirth bonus
--   luck       casting Luck (CastingService.castLuck), like the 2x Luck pass; not premieres
--   speed      films take this much less time (MovieService), on top of Faster Filming
--   boxOffice  cinema royalties, also while away (EconomyService.rate)
local Mascots = {}

export type BuffKind = "cash" | "luck" | "speed" | "boxOffice"

export type Buff = {
	kind: BuffKind,
	amount: number, -- 0.2 is +20% Cash, x1.2 Luck, 20% faster films or +20% box office
}

export type Mascot = {
	id: string, -- stable; saved as the equipped mascot and used as the Blender mesh's name
	name: string,
	tier: string, -- an Actors tier id: the card and glow use its color
	blurb: string,
	price: number, -- Cash, bought once; 0 is free (the starter)
	product: number?, -- Roblox developer product id for buying it with Robux; nil or 0 until set up
	hover: boolean?, -- floats instead of hopping
	buff: Buff,
}

-- The most any mascot may give, per kind. The 2x Luck pass is x2 and Faster Filming is 25%.
Mascots.Caps = table.freeze({
	cash = 0.2,
	luck = 0.2,
	speed = 0.1,
	boxOffice = 0.15,
}) :: { [BuffKind]: number }

Mascots.WarmUp = 30 -- seconds after equipping before the buff works

-- Cheapest first; the rarity colors and buffs rise with the price. Prices sit along the typical
-- player's Cash curve (ECONOMY.md "Mascot buffs"): the Croc in the first session, the Bot around
-- the first rebirth, the Owl and Dragon as goals for days 2 to 4.
--
-- Robux: create one developer product per paid mascot on the Creator Hub (Monetization tab) and
-- paste its id into `product`. Suggested prices: Croc 25, Kitty 49, Bot 99, Owl 249, Dragon 449
-- Robux. The price itself is set on the Creator Hub; the game reads it from Roblox. Until an id is
-- set, the card's Robux button says "soon".
Mascots.List = {
	{ id = "PopcornPup", name = "Popcorn Pup", tier = "Newcomer", blurb = "Never misses a screening.", price = 0, buff = { kind = "cash", amount = 0.05 } },
	{ id = "ClapperCroc", name = "Clapper Croc", tier = "Rising", blurb = "Snaps for every take.", price = 5000, product = 0, buff = { kind = "speed", amount = 0.1 } },
	{ id = "ReelKitty", name = "Reel Kitty", tier = "Pro", blurb = "Hears every reel spin.", price = 25000, product = 0, buff = { kind = "luck", amount = 0.1 } },
	{ id = "CameraBot", name = "Camera Bot", tier = "Star", blurb = "Always rolling.", price = 75000, product = 0, hover = true, buff = { kind = "boxOffice", amount = 0.15 } },
	{ id = "SpotlightOwl", name = "Spotlight Owl", tier = "Superstar", blurb = "Lights up the night.", price = 1000000, product = 0, buff = { kind = "luck", amount = 0.2 } },
	{ id = "PremiereDragon", name = "Premiere Dragon", tier = "Legend", blurb = "Guards the red carpet.", price = 5000000, product = 0, buff = { kind = "cash", amount = 0.2 } },
} :: { Mascot }

Mascots.Default = "PopcornPup"

local byId: { [string]: Mascot } = {}
local byProduct: { [number]: Mascot } = {}
for _, mascot in Mascots.List do
	byId[mascot.id] = mascot
	if mascot.product ~= nil and mascot.product ~= 0 then
		byProduct[mascot.product] = mascot
	end
end

function Mascots.get(id: string): Mascot?
	return byId[id]
end

-- The mascot a Robux developer product buys, if `productId` is one of theirs.
function Mascots.byProduct(productId: number): Mascot?
	return byProduct[productId]
end

-- True for mascots whose buff is casting Luck: Robux spent on them counts as buying paid random
-- items (like the 2x Luck pass), so players whose region restricts those are not offered the
-- Robux button for them (Cash still works).
function Mascots.randomItems(mascot: Mascot): boolean
	return mascot.buff.kind == "luck"
end

-- Whether the save owns `mascot`: free ones always, the rest once bought (`data.mascotsOwned`,
-- a set of ids kept outside the save template).
function Mascots.owns(mascot: Mascot, data: any): boolean
	if mascot.price <= 0 then
		return true
	end
	local owned = data.mascotsOwned
	return type(owned) == "table" and owned[mascot.id] == true
end

-- Ids of every mascot the player owns, in list order.
function Mascots.owned(data: any): { string }
	local ids = {}
	for _, mascot in Mascots.List do
		if Mascots.owns(mascot, data) then
			table.insert(ids, mascot.id)
		end
	end
	return ids
end

-- The mascot a save shows: its choice if it owns it, none if it chose none, else the default. A missing or broken choice (an older save) gets the Popcorn Pup.
function Mascots.equipped(data: any): string
	local choice = data.mascot
	if choice == "" then
		return ""
	end
	if type(choice) == "string" then
		local mascot = byId[choice]
		if mascot ~= nil and Mascots.owns(mascot, data) then
			return choice
		end
	end
	return Mascots.Default
end


-- The buff as the Mascots screen says it.
function Mascots.describe(buff: Buff): string
	local percent = math.floor(buff.amount * 100 + 0.5)
	if buff.kind == "cash" then
		return `+{percent}% movie Cash`
	elseif buff.kind == "luck" then
		return `x{1 + buff.amount} casting Luck`
	elseif buff.kind == "speed" then
		return `Movies film {percent}% faster`
	end
	return `+{percent}% box office`
end

-- Seconds until the equipped mascot's buff works (0 once it does). `data.mascotSince` is when the
-- mascot was last changed (os.time()); older saves without it count as long ago.
function Mascots.warmUpLeft(data: any, now: number): number
	local since = if type(data.mascotSince) == "number" then data.mascotSince else 0
	return math.max(0, since + Mascots.WarmUp - now)
end

-- How much of `kind` the player's mascot gives right now: 0 when it gives another kind, is hidden
-- or is still warming up. Never above the kind's cap.
function Mascots.boost(data: any, kind: BuffKind, now: number): number
	local mascot = byId[Mascots.equipped(data)]
	if mascot == nil or mascot.buff.kind ~= kind or Mascots.warmUpLeft(data, now) > 0 then
		return 0
	end
	return math.clamp(mascot.buff.amount, 0, Mascots.Caps[kind])
end

return Mascots
