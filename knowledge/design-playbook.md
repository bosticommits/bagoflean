# Dink District design playbook

The designer agent reads this before every design task and follows it. It holds
the house style, the checklist every design must pass, and what we've learned
from the owner's feedback and from sales. **It gets better only if every lesson
is written down:** after each round, add to the logs at the bottom.

Business facts (prices, what's live, market research) live in
`knowledge/what-works.md`. This file is only about how designs look and why.

---

## 1. What makes a design sell
A buyer scrolls past about 50 listings in 10 seconds. A design gets one look at
thumbnail size (about 300 px wide), so:

1. **One idea, readable in one glance.** The hook word (KITCHEN, DINKMAS, GRANDMA'S, NO!) must read at thumbnail size. If the joke needs the small print, it's the wrong joke.
2. **The buyer recognises themselves or the person they're buying for.** Every design names a person ("Grandma's", "Retired.") or a feeling every player has (bad knees, "just one more game"). Most buyers are gift buyers.
3. **A character beats a layout.** Text plus a small icon looks generic: the owner called rounds 1-3 "generic, nothing that would draw buyers". A character with a face, doing the joke, is what sells (see the mascot below).
4. **Insider, never mean.** Use real pickleball words (kitchen, dink, non-volley zone, third shot, erne, 0-0-2, banger, "calling the score") so players feel it was made by one of them. The joke is warm and self-deprecating, never at someone's expense.
5. **Fresh twist on a proven theme.** Proven themes: Christmas, grandparents, retirement, aging bodies, doubles partners, kitchen rules. Never use a saturated phrase (list in `what-works.md`); twist it instead ("Dashing Through the Kitchen", not "Merry Dinkmas" again).

## 2. House style (since round 4, 2026-10-06)

### The mascot: our brand character
A 1930s rubber-hose cartoon pickleball. Use the same character on every design, so the shop looks like a brand.
- **Body:** lime ball `#D4EE3B` with darker holes (olive `#93B41F` or `#A9C12B`), a small cream highlight, and a full ink outline.
- **Face:** big pie-cut eyes (oval white, black pupil with a wedge cut out), pink cheeks `#F49A8C`, an open smile with a tongue. A wink suits cheeky jokes.
- **Limbs:** thin ink rubber-hose arms and legs, white cartoon gloves with cuffs, and chunky sneakers (red on holiday designs, coral or white on evergreen ones).
- **Costume per joke:** Santa hat, reindeer antlers, chef hat and mustache, granny perm with glasses and pearls, waiter visor and bow tie, knee braces. **The costume is the joke made visible.**
- **Pose:** always doing something (waving, swinging, running, serving). Never just standing and smiling.
- **Code:** `ball_body`, `face`/`pie_eye`, `glove_open`/`glove_fist`/`glove_thumbs_up`, `sneaker`/`shoe`, `paddle`, and `limb`/`arm_to` in `scripts/round4_holiday.py` and `scripts/round4_evergreen.py`. Reuse them instead of starting from scratch.

### Lettering
- **Mix 2-3 styles at most:** a script for the warm word, a heavy block or slab for the hook, and small spaced caps for the tagline.
- **Fonts that worked in round 4:**
  - script: Lobster, Pacifico, Shrikhand
  - block: Bowlby One SC, Alfa Slab One, Bungee, Archivo Black, Anton
  - tagline: Righteous, Bebas Neue
- **Retro treatment:** an extruded drop shadow (3D offset in a second colour), arched words, and words on ribbons or banners.
- **The hook word is the biggest thing on the shirt after the mascot.** Taglines can be small; hooks never are.
- **Knit or ugly-sweater designs:** use the hand-built pixel font (`KNIT_FONT` / `knit_word` in `round4_holiday.py`). TTF fonts rasterised onto a stitch grid come out unreadable.

### Colour
- **Brand palette:** navy `#1D2B45`, coral `#E76F51`, teal `#2A9D8F`, lime `#D9F03C`, cream `#FBF3E4`.
- **Holiday palette:** ink `#1C1A2B`, red `#E0393E`, green `#2E9A5C`, gold `#F6C445`, plus lime and cream.
- **4-6 flat colours per design.** No gradients, glows or soft shadows; DTG printing turns them into muddy dots.
- **Outlines:** a 24-26 px ink outline on everything.
- **On dark shirts:** add a 30 px cream "sticker" contour around the whole artwork, so the dark outlines don't disappear into Black or Navy.
- **Distress:** a light worn-print speck texture (binary holes, never semi-transparent) reads as vintage. Keep it off faces where it looks like dirt, and off knit designs.

### Layouts that worked
| Layout | Example | Notes |
|---|---|---|
| Mascot sandwiched between script word (top) and block hook (bottom) | Merry Dinkmas, Grandma's Got Game | The default. Fills the chest, reads top to bottom. |
| Round vintage badge with ribbon across | Santa's Favorite Dinker, Kitchen Staff Only | Reads as "official", good for club or insider jokes. Wider than tall, so it prints shorter. |
| Mascot on a starburst, ribbon plus big block words below | Retired. Now Serving Full Time | The strongest of round 4 (scored 9). |
| Knit stitch grid with pixel art | Jingle All the Way to the Kitchen | Christmas only. Stitches about 44 px; the thin-line warning is expected. |

### Garment pairing
- **Light shirts:**
  - Comfort Colors: Ivory, Butter, Chalky Mint, Blossom
  - Gildan or Bella: White, Sand, Natural, Light Pink
  - Use navy ink and outlines, coral and teal accents.
- **Dark shirts:**
  - Comfort Colors: Pepper, Navy, Black, Blue Spruce
  - Gildan: Black, Navy, Forest Green, Maroon
  - Use cream, lime and coral ink, plus the cream contour.
- **Avoid:**
  - Comfort Colors Moss with lime or gold ink (too little contrast)
  - red details on Maroon (they vanish, so list Maroon last)
  - lime text on red bands unless the letters are big

## 3. Checklist: every design must pass before it's delivered
Run `python scripts/design_check.py designs-round-N/<slug>`. It checks automatically:
- size (shirts 4500x5400, mugs 2475x1155, stickers 3000x3000), RGBA and transparent, 300 DPI
- no glows, gradients or soft shadows (anti-aliased edges are fine)
- art 80-95% of the print width, starting under 300 px from the top
- lines thinner than about 20 px (a warning; fine for sparkle tips, specks and knit stitches)
- contrast of the ink and outer edge against **every listed garment colour**
- listing: title of at most 140 characters, exactly 13 tags of at most 20 characters, AI disclosure last, no blocked names

Then do these by eye. The checker writes `thumbs.png`, so look at it:
- [ ] **Thumbnail test:** in `thumbs.png`, can you read the hook word and tell what the character is doing? If not, make it bigger or simpler.
- [ ] **Spelling:** read every word letter by letter, including apostrophes.
- [ ] **Joke test:** say it out loud. Does a player smile? Would a grandkid buy it for Grandma?
- [ ] **Not a repeat:** different from everything live (see `what-works.md`) and not a saturated phrase.
- [ ] **No crowding:** at least about 60 px between separate elements. Nothing touches unless it's meant to overlap.
- [ ] **Face check:** eyes the same size, no texture specks in the eyes, the expression matches the joke.
- [ ] **Photos:** run `python scripts/photo_studio.py <slug>` and check that the hero photo looks like something you'd buy.

## 4. Scoring (deliver 8+ only)
| Score | Means |
|---|---|
| 10 | Stops the scroll. A clear character and joke, perfect at thumbnail size, nothing like it on Etsy. |
| 9 | Strong character and hook, one tiny nitpick. (Retired. Now Serving Full Time) |
| 8 | Good, sellable. Small text could be clearer or the idea is less fresh. (Merry Dinkmas mascot, knit sweater) |
| 6-7 | Fine but forgettable: text plus icon, or the joke needs explaining. Rework it. |
| 1-5 | Generic, hard to read or off-brand. Drop it. |

Be honest. The owner would rather get 3 designs scored 9 than 8 designs scored 7.

## 5. Ways the agent can improve the art (wishlist for the owner)
- **More fonts:** good commercial-use fonts dropped into `fonts/` widen the range a lot. Retro script, groovy 70s and collegiate fonts are the gaps.
- **Licensed illustration packs:** e.g. Creative Fabrica, about $10-30 a month, commercial licence. Put them in `assets/` with a note of the licence, and the agent can combine them with our mascot.
- **Real product photos:** one ordered sample photographed on a person beats any drawn mockup.

---

## 6. Owner taste log (newest first)
What the owner liked, disliked or picked. Follow it.
- 2026-10-06: The owner approved all 8 round-4 mascot designs straight away and said the older designs are "most definitely not going to sell". Keep the mascot style and don't go back to text plus icon.
- 2026-10-06: The owner said rounds 1-3 "all seem fairly generic, nothing that would draw buyers" and asked for more convincing photos as well. That led to the mascot style and `photo_studio.py`.

## 7. What sold or got attention (newest first)
Fill in from Etsy Stats: design, style or layout, views, favourites, orders, and what to learn from it.
- _No data yet. All round-4 designs went live on 2026-10-06; first review around 2026-11-06._

## 8. Lessons log (newest first)
- 2026-10-06: The knit design's thousands of small stitches give many anti-aliased edge pixels. That's fine; `design_check.py` tells edges apart from real glows.
- 2026-10-06: `etsy_agent.render.make_mockup` draws a T-shirt shape, even for crewnecks. Use `photo_studio.py` for listing photos.
- 2026-10-06: Wide badges print shorter (Kitchen Staff Only is about 11 inches tall). Fine for a badge, but consider a taller layout when the joke needs presence.
- 2026-10-06: Small taglines ("Official Nice List", "My knees say") disappear at thumbnail size. Fine as long as the hook word carries the design alone.
