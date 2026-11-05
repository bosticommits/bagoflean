--!strict
-- Game passes and developer products (plan section 7). Shared so the shop screen can list them;
-- only the server grants anything (ShopService).
--
-- IDs: create each pass and product on the Creator Hub (Monetization tab of the experience), then
-- paste its ID here. An entry with id 0 is not set up yet: the shop shows it as "coming soon" and
-- the server ignores it. Prices come from Roblox (the client reads them), so they are not set here.
--
-- Rules from the plan: odds always visible, no buying specific actors, free players can reach
-- everything. Nothing here sells an actor; it sells time, Luck and convenience.
--
-- `randomItems` marks what Roblox counts as buying paid random items: Robux spent on Luck, or on
-- Cash that pays for Casting Calls. Players whose region restricts paid random items
-- (PolicyService) are never offered these; ShopService sets the PaidRandomRestricted attribute.
local Shop = {}

export type Pass = {
	key: string, -- stable id used in saved data; never rename
	id: number, -- Roblox game pass id
	name: string,
	description: string,
	randomItems: boolean?, -- leads to random actors; hidden where paid random items are restricted
}

export type Reward = {
	cash: number?, -- at least this much Cash...
	cashMinutes: number?, -- ...or this many minutes of the player's current cinema income, if more
	script: { genre: string, length: string, count: number }?,
	luckMinutes: number?, -- Lucky Casting boost (x2 casting Luck), stacks in time
	skips: number?, -- Skip Filming tokens
	fame: number?, -- Fame, capped at Rewards.MaxFame
}

export type Product = {
	key: string, -- stable id used in analytics; never rename
	id: number, -- Roblox developer product id
	name: string,
	description: string,
	reward: Reward,
	randomItems: boolean?, -- leads to random actors; hidden where paid random items are restricted
}

Shop.Passes = {
	{ key = "Luck2x", id = 2058624083, name = "2x Luck", description = "Double casting Luck, forever", randomItems = true },
	{ key = "AutoCollect", id = 2058156082, name = "Auto-Collect", description = "Box office cash comes to you" },
	{ key = "ExtraStage", id = 2057682079, name = "+1 Sound Stage", description = "Film one more movie at once" },
	{ key = "FastFilming", id = 2061100781, name = "Faster Filming", description = "Every movie films 25% faster" },
	{ key = "VIP", id = 0, name = "VIP", description = "Gold VIP tag, chat tag and a starred marquee" },
} :: { Pass }

Shop.Products = {
	{
		key = "LuckyCasting",
		id = 3723666459,
		name = "Lucky Casting",
		description = "x2 casting Luck for 15 minutes",
		reward = { luckMinutes = 15 },
		randomItems = true,
	},
	{
		key = "SkipFilming",
		id = 3723666557,
		name = "Skip Filming",
		description = "Finish one movie instantly",
		reward = { skips = 1 },
	},
	{
		key = "CashSmall",
		id = 3723666635,
		name = "Box Office Bag",
		description = "30 minutes of box office cash",
		reward = { cash = 5000, cashMinutes = 30 },
		randomItems = true,
	},
	{
		key = "CashLarge",
		id = 3723666724,
		name = "Box Office Vault",
		description = "4 hours of box office cash",
		reward = { cash = 50000, cashMinutes = 240 },
		randomItems = true,
	},
} :: { Product }

local passByKey: { [string]: Pass } = {}
local passById: { [number]: Pass } = {}
for _, pass in Shop.Passes do
	passByKey[pass.key] = pass
	if pass.id ~= 0 then
		passById[pass.id] = pass
	end
end
local productByKey: { [string]: Product } = {}
local productById: { [number]: Product } = {}
for _, product in Shop.Products do
	productByKey[product.key] = product
	if product.id ~= 0 then
		productById[product.id] = product
	end
end

-- Whether paid random items may take effect or be sold, from the player's PaidRandomRestricted
-- attribute (ShopService sets it from PolicyService). Only a confirmed `false` allows it: nil
-- (not checked yet) counts as restricted. The server uses it to refuse receipts and pause the
-- Luck pass; the client uses it to hide offers.
function Shop.paidRandomAllowed(restricted: any): boolean
	return restricted == false
end

-- True when a purchase must be refused: it leads to random actors (`randomItems`) and the player's
-- region does not allow that.
function Shop.blocksPurchase(randomItems: boolean?, restricted: any): boolean
	return randomItems == true and not Shop.paidRandomAllowed(restricted)
end

function Shop.getPass(key: string): Pass?
	return passByKey[key]
end

function Shop.passById(id: number): Pass?
	return passById[id]
end

function Shop.getProduct(key: string): Product?
	return productByKey[key]
end

function Shop.productById(id: number): Product?
	return productById[id]
end

return Shop
