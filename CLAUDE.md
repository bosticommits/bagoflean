# Dink District (bagoflean)

An Etsy print-on-demand shop, **DinkDistrictArt**, selling funny pickleball apparel and gifts through Printify.

**Before any task, read `knowledge/what-works.md`** (shared memory: what's live, prices, market findings, rules). **For any design work, also read `knowledge/design-playbook.md`** (house style, checklist, what the owner likes). After any task that changes something, add a dated line to the right file.

## Specialist subagents (`.claude/agents/`)
- **designer**: new or improved print-ready designs plus `listing.json`
- **listing-writer**: Etsy titles, tags and descriptions
- **shop-manager**: Printify drafts, prices, publishing (only after the owner approves)
- **marketer**: Pinterest pins and schedule, social and community post drafts (no unsolicited DMs, emails or texts)
- **researcher**: turns Etsy screenshots and stats into decisions; keeps the memory file current

## Map
- `knowledge/design-playbook.md`: house style (the mascot), design checklist, scoring, owner taste and lessons logs
- `scripts/design_check.py`: automatic pre-flight check for a design folder (writes `thumbs.png`)
- `scripts/photo_studio.py`: listing photos into `photos/<slug>/` (gitignored)
- `designs-round-4/` (current mascot style), `designs-round-2/`, `samples/`: one folder per design (`design.png`, `mockup.png`, `listing.json`)
- `scripts/printify_publish.py`: create, publish and reprice products; `printify/state.json` records what's created and live
- `scripts/marketing_pins.py`: Pinterest pins plus bulk CSV in `marketing/`
- `scripts/club_shirt.py`: personalised "<Town> Pickleball Club" file per order
- `etsy_agent/`: design pipeline, renderer (`render.py`), drawing helpers (`artkit.py`), listing checks (`compliance.py`), niche profile (`niche.py`)
- `brand/`: logo, banner and shop text

## Ground rules
- Never publish to Etsy or spend money without the owner's go-ahead.
- No fake discounts (the seller is in the EU), no brand or player names, and no spam marketing.
- Explain things to the owner in plain language; they are new to this.
