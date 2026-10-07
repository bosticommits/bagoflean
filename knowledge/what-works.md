# Dink District: shared memory

Every agent reads this file before starting and adds what it learns at the end
(see "How to update"). Keep it short, factual and current. Newest entries go
first in each log.

## The business
- **Shop:** DinkDistrictArt on Etsy (brand name "Dink District"). The owner is based in Romania (EU), and most buyers are in the US.
- **Niche:** funny, giftable pickleball apparel and gifts. Buyers are players (many 50+), plus spouses, kids and grandkids shopping for gifts.
- **Fulfilment:** Printify (shop id 29206471), connected to Etsy. Products are created and published with `scripts/printify_publish.py`.
- **Goal right now:** first sales and reviews. The owner has spent about $20 so far and wants it back first. Keep spending near zero.
- **Brand colours:** navy #1D2B45, coral #E76F51, teal #2A9D8F, lime #D9F03C, cream #FBF3E4. The tone is warm and clever, never mean.

## Live on Etsy (22 listings, as of 2026-10-06)
- **Round 4 (mascot style, best work):** Merry Dinkmas, Santa's Favorite Dinker, Dashing Through the Kitchen, Jingle All the Way to the Kitchen knit sweater (crewnecks); Grandma's Got Game, My Knees Say No My Heart Says Pickleball, Kitchen Staff Only, Retired Now Serving Full Time (Comfort Colors tees)
- **Older crewnecks:** Dink the Halls, Santa's Naughty List Kitchen Violators, Dear Santa Fix My Backhand, Gobble Gobble Dink Dink
- **Older tees (Bella+Canvas 3001):** Grandma (Sweet as Pie), Grandpa (Dinking Since Retirement), Retirement Schedule, 2027 Resolutions, Mine Yours Oops, Just One More Game, Doctor's Orders Rx
- **Mugs (11oz):** Coffee then Pickleball, What's the Score
- **Sticker:** Official Kitchen Inspector

**No drafts.** On 2026-10-06 the owner had the 17 old drafts deleted (name tees, Comfort Colors copies, accent mugs). Don't run `create-all` without asking, because it would recreate them.

The source of truth for what's live is `printify/state.json` plus `python scripts/printify_publish.py list`.

## Prices (free US shipping on apparel)
| Product | S-XL | 2XL | 3XL | 4XL | 5XL | Approx. profit S-XL |
|---|---|---|---|---|---|---|
| Crewneck | $36.99 | $39.99 | $41.99 | $44.99 | $44.99 | about $7.80 |
| Tee | $24.99 | $26.99 | $30.99 | $32.99 | $34.99 | about $6 |
| Tee, Comfort Colors 1717 | $26.99 | $28.99 | $31.99 | $33.99 | - | about $6 |
| Mug 11oz | $16.99 + shipping | | | | | about $10 |
| Accent mug 11oz (lime or black handle and inside) | $18.99 + shipping | | | | | about $10.70 |
| Sticker | $4.99 (3") / $5.99 (4") + shipping | | | | | about $3 |

Costs: crewneck $17.87 (S-XL), tee $11.29 (S-XL), Comfort Colors tee $12.65 (S-XL), mug $5.03, accent mug $6.40, sticker $1.58. Etsy fees are about 9.5% + $0.45 per order. Off-site ads take 15% when an ad brings the sale.

## What the market shows (Etsy search, early Oct 2026)
- **Personalisation leads.** Bestsellers include "Pickleball Grandma sweatshirt personalised Gigi" (235 reviews), team/club shirts ("TEAM NAME, EST 2025, PICKLEBALL CLUB, AUSTIN TX") and name mugs.
- **Mugs:** a short, cocky one-liner on a two-tone accent mug (coloured handle and inside). "Tears of my pickleball opponents" has 18.2k reviews. Don't copy that phrase.
- **Christmas:** ugly-Christmas-sweater knit styles dominate (pickleballs and snowflakes in knit patterns). "Merry Dinkmas" is proven (one shop has 985 reviews), so it's competitive.
- **Tees:** most top sellers are **Comfort Colors** garment-dyed tees (moss, sage, blue jean, pepper, ivory), photographed as styled flat-lays with props.
- **Styles that sell:** cute illustrated mascots (smiling ball and paddle, geese), retro cartoon characters, vintage illustration, script lettering, collegiate club crests.
- **Saturated, avoid:** "I can't, I have pickleball", "dinking problem", "dink responsibly", "born to play pickleball, forced to work", "where tennis players go to die", "playing pickleball improves memory", soft serve, plain frog or goose memes with no twist.
- **Competitor prices:** tees €14-17 and sweatshirts €19-32, usually shown with a struck-through "sale" price, and shipping often charged on top.
- **Our biggest weakness:** plain Printify mockups as listing photos. Lifestyle or flat-lay photos are what get clicks.

## Rules every agent follows
- **Print files:** shirts are 4500x5400 PNG, transparent, 300 DPI. Mugs are 2475x1155 with art on both halves. Stickers are 3000x3000 with a white die-cut border. Use solid flat colours only: no gradients, glows or semi-transparency. Nothing thinner than about 20 px.
- **Contrast:** light ink goes on dark garments and dark ink on light garments. Check every colour you list.
- **Legal:**
  - No brand, pro player, league or tour names (see `etsy_agent/niche.py` blocked terms). No lyrics or quotes.
  - Check new slogans on tmsearch.uspto.gov before publishing (the owner does this; agents can't reach it).
- **Etsy listings:**
  - Titles of at most 140 characters (aim for 60-110), exactly 13 tags of at most 20 characters each, and the AI disclosure line at the end of the description.
  - `etsy_agent/compliance.py` checks this.
- **Pricing honesty:** the seller is in the EU, so a "was" price must be a real earlier price (EU Omnibus rule). **Never inflate a price just to show a fake discount.** Real sales at real prices (Black Friday) are fine.
- **Marketing:** never send unsolicited DMs, bulk emails or texts. Only post to the shop's own accounts, or prepare posts the owner places in groups that allow promotion.
- **Publishing:** create as a Printify draft, tell the owner, and publish only after they say so. Every listing costs $0.20.

## Decisions log
- 2026-10-07: Authenticity details added to the 8 round-4 designs (club line, EST. / 2026, Dink District seal, purpose lines; see the playbook lessons log). New art is in `design.png`; the live art is saved as `design-v1.png`; comparison sheet at `designs-round-4/authenticity-before-after.jpg`. **Live listings keep v1 until the owner approves a swap** (`printify_publish.py swap`). Nothing published.
- 2026-10-06: Marketing restart for round 4: `marketing/pinterest_round4.csv` (24 pins, Oct 7-18, made from the new listing photos; `marketing_pins.py --round`) and the owner guide `marketing/START-HERE.md` (photos, Pinterest setup, optional Etsy Ads at $1-2/day, weekly Stats screenshots, and how to tell traffic problems from design problems). Day-14 check is around Oct 20, the day-30 decision around Nov 5.
- 2026-10-06: Created `knowledge/design-playbook.md` (house style, checklist, scoring, owner taste and lessons logs) and `scripts/design_check.py` (automatic pre-flight; all 8 round-4 designs pass). The designer agent must follow the playbook; the researcher feeds sales results into it.
- 2026-10-06: Published round 4 to Etsy (6 listings). Deleted the 17 old unpublished drafts at the owner's request. The owner chose to keep the 13 older live listings up for now. Next: check which older listings get no views after about 30 days and retire them.
- 2026-10-06: New `swap <old> <new>` command in `printify_publish.py` puts a new design onto an existing product (same listing, no duplicate). Used for Merry Dinkmas, Santa's Favorite Dinker (live, re-synced) and the Jingle draft. The state entry keeps the old slug and gains `"design": <new slug>`. Printify needs every variant id, including disabled ones, in `print_areas.variant_ids`.
- 2026-10-06: `scripts/photo_studio.py` makes listing photos (flat-lay hero, close-up, colour sheet, gift card) into `photos/<slug>/` (gitignored). Printify can't upload them, so the owner adds them in the Etsy listing editor. The close-up now frames the whole print.
- 2026-10-06: Round 4 evergreen gift tees (Comfort Colors, `scripts/round4_evergreen.py` → `designs-round-4/`): Grandma's Got Game, My Knees Say No My Heart Says Pickleball, Kitchen Staff Only (chef badge), Retired. Now Serving Full Time (waiter with tray). New house style to replace flat text + icons: one recurring lime rubber-hose ball mascot (pie-cut eyes, white gloves, sneakers) with a costume per joke, retro arched/script/extruded type, ribbons and starbursts, and a subtle binary speck texture. Dark-shirt designs get a cream halo, so the navy outlines don't vanish on Navy/Black. Drafts not created yet (DESIGN_DIRS now includes designs-round-4).
- 2026-10-06: **Round 4 holiday crewnecks** (`scripts/round4_holiday.py`, output in `designs-round-4/`): merry-dinkmas-mascot, dashing-through-the-kitchen, santas-favorite-dinker-badge, jingle-kitchen-knit-sweater. New house style replaces flat text plus icons: a retro rubber-hose pickleball mascot (gloves, high-tops, pie-cut eyes), ink outlines plus a cream "sticker" contour so art reads on Black/Navy/Forest/Maroon, extruded retro type, ribbons, and subtle binary-alpha distress. Three of them upgrade existing artwork (live Merry Dinkmas, live Santa's Favorite Dinker, draft Jingle sweater), so swap the artwork on those listings instead of adding duplicates. For knit designs, use the hand-built pixel font in the script; fonts rasterised onto the stitch grid come out unreadable.
- 2026-10-06: Added Grandma and Grandpa **name versions** as separate listings, so each ranks for "pickleball gigi shirt" etc. More names: `python scripts/name_variants.py grandma Lolli`.
- 2026-10-06: Added **Comfort Colors** tees as a second blank. Light-ink designs avoid CC Moss (too light for lime or gold ink); use Blue Spruce, Pepper, Navy or Black instead.
- 2026-10-06: New formats from market research: two-tone accent mugs with a one-liner, and a knit ugly-sweater crewneck (`scripts/round3_designs.py`).
- 2026-10-06: Subagents created (`.claude/agents/`), plus this shared memory file and `CLAUDE.md`.
- 2026-10-06: Lowered prices to crewneck $36.99 / tee $24.99 / mug $16.99 to compete as a new shop.
- 2026-10-06: Skipped "raise prices and run a permanent sale", because it would be an illegal fake discount for an EU seller.
- 2026-10-06: Hoodies skipped for now. Printify's Gildan 18500 front print area is short, so tall designs print small.
- 2026-10-06: 4 personalised round-2 designs are on hold until there's a per-order workflow (`scripts/club_shirt.py` exists for the town club shirt).
- 2026-10-05: Round 2 (designs-round-2/REPORT.md) replaced Dinkin' Problem, Former Tennis Player, Born to Dink and the Retirement badge.

## Results log (sales, views, favourites)
_No data yet. Add Etsy Stats here weekly: listing, views, favourites, orders and top search terms._

## How to update
Add a dated line to the right log. Update the "Live" and "Prices" sections when they change. Remove anything that's no longer true. Keep the file under about 200 lines.
