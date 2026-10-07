You are the lead designer and market researcher for **DinkDistrictArt**, my Etsy print-on-demand shop that sells funny, original **pickleball** apparel and gifts (sweatshirts, t-shirts, hoodies, mugs, stickers), printed and shipped by Printify. Your job: research the market, review my current designs, decide which to keep, improve or replace, then produce a new, better set of print-ready designs that will sell more.

Work through the four phases below in order. Don't stop to ask me questions. Make sensible decisions and note your assumptions.

## About the shop
- **Buyers:** pickleball players (many 50+ and retirees), plus spouses, kids and grandkids buying gifts. Also couples, doubles partners, clubs and leagues.
- **Brand:** "Dink District". Navy #1D2B45, coral #E76F51, teal #2A9D8F, lime #D9F03C, cream #FBF3E4. The tone is warm, clever humor, never mean.
- **Current designs (17):** see the attached image `contact-sheet.png`. Dink the Halls, Merry Dinkmas, Santa's Favorite Dinker, Gobble Gobble Dink Dink, Pickleball Nana, Pickleball Papa, My Retirement Plan: Pickleball, Partners in Dink, Kitchen Inspector, Just One More Game, I've Got a Dinkin' Problem, It Always Starts With 0-0-2, Former Tennis Player / Pickleball Addict, Born to Dink Forced to Work, [Town] Pickleball Club (personalised), Coffee then Pickleball (mug), Paddle Up! (sticker).
- **Live so far:** Dink the Halls (crewneck sweatshirt). Merry Dinkmas is being set up.
- **Today's date:** check it. Holiday designs need to be listed 3–6 weeks before the holiday for Etsy to rank them.

## Phase 1: Market research (use web search)
Research the pickleball apparel and gift market as it is **right now**, mainly on Etsy, plus Amazon Merch, Redbubble, TikTok, Instagram and Pinterest:
1. **What sells:** the best-selling pickleball shirt, sweatshirt, mug and sticker designs (look at bestseller badges, review counts and "in X carts"). Note the jokes, styles, colours and products that win.
2. **Search demand:** the phrases buyers type (e.g. "pickleball gift for grandma", "funny pickleball shirt", "pickleball christmas sweatshirt") and which seem underserved, meaning high interest but generic or poor-quality results.
3. **Gaps and saturation:** jokes and styles that are overdone (avoid them) and fresh angles nobody does well yet.
4. **Upcoming occasions** in the next 4 months, and what's trending in pickleball culture (slang, memes, moments).
5. **Prices** competitors charge for tees, sweatshirts, hoodies and mugs.
6. **Buyer complaints in reviews** (print quality, sizing, colours) that good design can avoid.

Write a **one-page research brief** with sources (links).

## Phase 2: Review my current 17 designs
For each design, give:
- **Verdict:** KEEP / IMPROVE / REPLACE
- **Score 1–10** for sales potential, with one line on why, based on your research. Consider readability as a small Etsy thumbnail, how fresh the joke is, gift appeal, and contrast on the chosen shirt colour.
- **For IMPROVE:** exactly what to change.
- **For REPLACE:** what should replace it.

Be honest. I'd rather fix weak designs now than waste listing fees.

## Phase 3: Create the designs
Produce **15–20 finished designs**: improved versions of the IMPROVE ones, plus new designs that fill the best gaps you found. Weight them toward upcoming occasions and gift-buyer searches, and mix in personalisable ideas (names, towns, years), which sell well on Etsy.

**Print rules (strict, or the files can't be used):**
- **Shirts and hoodies:** 4500 × 5400 px PNG, 300 DPI, **transparent background** (no background colour or box). Artwork fills about 80–95% of the width, centred, starting near the top. Bottom empty space is fine.
- **Mugs:** 2475 × 1155 px PNG, transparent, artwork placed on both the left and right halves. **Stickers:** 3000 × 3000 px PNG with a white die-cut border drawn around the artwork.
- **Solid, flat colours only.** No gradients, soft shadows, glows or semi-transparent areas, because DTG and DTF printing turns them into ugly blocks. Use 2–5 colours.
- No lines or details thinner than about 20 px at full size. Text must be readable on a phone-size thumbnail.
- **Contrast:** light ink for dark shirts, dark ink for light shirts. Name the 3–4 shirt colours each design is for.
- **Fonts:** only fonts licensed for commercial use (Google Fonts / SIL OFL or Apache are safe). Convert text to shapes or embed it so it renders exactly.
- **Legal:** no brand names or logos (Selkirk, JOOLA, Franklin, Nike…), no pro players, leagues or tours (PPA, MLP, USA Pickleball, DUPR), no song lyrics, movie quotes or characters, no parodies of famous slogans. Check every slogan on tmsearch.uspto.gov and drop any that are trademarked.
- Spell-check every word in the artwork twice.

**For every design, also write the Etsy listing:**
- **Title:** max 140 characters, aim for 60–110. Lead with what a shopper searches (e.g. "Pickleball Christmas Sweatshirt"), no keyword stuffing.
- **13 tags:** each max **20 characters** including spaces, letters, numbers and spaces only, no repeats.
- **Description:** a 1–2 sentence hook, then "Who it's for:" bullets, then "About the design:", then a final line: "This design was created by our shop with the help of AI design tools and is printed on demand by our production partner."
- **Product(s)** to list it on (crewneck, tee, hoodie, mug, sticker), **shirt colours** (main colour first), and a **suggested price**.

## Phase 4: Deliver
Give me a **downloadable package** (a zip if you can) with one folder per design, named in lowercase-with-dashes (e.g. `pickleball-grandma-squad/`). Each folder contains:
- `design.png` (the print file, following the rules above)
- `mockup.png` (a preview on the main shirt colour)
- `listing.json` in exactly this format:
```json
{
  "slug": "pickleball-grandma-squad",
  "verdict_for_old_design": "new | improves <old design name>",
  "title": "…",
  "tags": ["…13 items…"],
  "description": "…",
  "alt_text": "One sentence describing the mockup",
  "products": [{"type": "crewneck", "colors": ["Navy", "Black", "Forest Green"], "price_usd": 44.99}],
  "occasion": "Christmas | Mother's Day | year-round | …"
}
```
Also include a top-level `REPORT.md` with the Phase 1 research brief, the Phase 2 review table, and a list of which old designs to **remove from the shop**.

Finally, show me a contact sheet of all new designs so I can see them at a glance.

(If you have write access to the GitHub repo `bosticommits/bagoflean`, also commit the package to a new branch `designs-round-2` under `designs-round-2/`, with the same folder structure. Don't change any other files.)
