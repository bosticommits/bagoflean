# bagoflean

Two separate projects live in this repo:

1. **Hollywood RNG** (working title Movie Mogul), a Roblox game built with Rojo. Design: [GAME_PLAN.md](GAME_PLAN.md).
2. **A Roblox Limited trade advisor**, a Python terminal chatbot (see further down).

## Hollywood RNG (Roblox game)

Status: milestones M0 to M5 are built and playtested in Studio: lots and cash, casting,
movies, Index, agencies, upgrades, lot visuals, billboard, effects, sounds and the tutorial.
The M6 launch features are built too: Award Night, daily rewards, Studio Requests, codes, game
passes, developer products and analytics. Art is still placeholder parts. See GAME_PLAN.md
sections 9, 11 and 12.

### Setup

1. Install the pinned Rojo with [Aftman](https://github.com/LPGhatguy/aftman) (`aftman.toml`
   pins Rojo 7.7.0):
   ```
   aftman install
   ```
2. Install the Rojo plugin into Studio **once**, from the command line:
   ```
   rojo plugin install
   ```
   Do not also install a Rojo plugin from the Creator Store. Two Rojo plugins connected at the
   same time can each create the same new script, which leaves duplicate scripts in the place.
3. Start the sync server from the repo root, then press **Connect** in the Rojo plugin (port 34872):
   ```
   rojo serve
   ```
4. To test saving in Studio, publish the place and turn on Game Settings > Security >
   **Enable Studio Access to API Services**. Without it the game falls back to in-memory data
   (it logs a warning, and nothing is saved).

### Layout

| Folder | Runs on | Contents |
|---|---|---|
| `src/shared` | both | Config, actors and odds, movies, upgrades, shop items, rewards, events (pure rules, no state) |
| `src/server` | server | Data (ProfileStore), economy, lots, casting, movies, upgrades, rewards, codes, shop, Award Night, analytics |
| `src/client` | client | HUD, casting, studio, upgrades, shop, rewards and tutorial screens |

The server decides every roll, price, timer and payout. Remotes carry requests, never values.
`src/server/ProfileStore.luau` is vendored from MadStudioRoblox/ProfileStore (Apache-2.0, see
`LICENSE-ProfileStore`).

### Setting up purchases

The shop lists every pass and product, but shows "Soon" until it has a real Roblox id.

1. Publish the place, then open the experience on the Creator Hub > **Monetization**.
2. Create the 5 game passes (2x Luck, Auto-Collect, +1 Sound Stage, Faster Filming, VIP) and the
   4 developer products (Lucky Casting, Skip Filming, Box Office Bag, Box Office Vault), with a
   price and an icon each.
3. Paste each id into `src/shared/Shop.luau` (the `id = 0` fields) and publish again.

Test purchases in Studio are free and go through the same server code. Prices are read from
Roblox, so the shop always shows what the prompt will charge.

### Before you publish

Run this in Studio's command bar and make sure it prints no `DUPLICATE` lines. A duplicated
script that was published would run twice in every server:
```lua
local seen = {}
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		local p = d:GetFullName()
		if seen[p] then print("DUPLICATE", p) end
		seen[p] = true
	end
end
print("duplicate check done")
```
The game also checks at startup and warns in the output (`[MovieMogul] duplicate ...`).

---

## Roblox Limited trade advisor

A terminal chatbot that gives cautious trade advice on Roblox Limiteds using public
[Rolimons](https://www.rolimons.com/) data and Claude.

**Advice only.** It never logs in to Roblox, never asks for or uses your password or
cookie, and never sends, accepts or automates trades or purchases. You make every trade
yourself, in Roblox's own trade window.

## Setup

1. Python 3.10 or newer.
2. Install the dependencies:
   ```
   pip install requests anthropic
   ```
3. Get an API key at https://console.anthropic.com/ and set it as an environment variable
   (never paste it into the code):
   ```
   export ANTHROPIC_API_KEY=sk-ant-...      # macOS / Linux
   setx ANTHROPIC_API_KEY sk-ant-...        # Windows (then open a new terminal)
   ```

## Usage

Chat mode:
```
python agent.py
you> I have 5k Robux, what should I buy to flip?
you> is giving Classic Fedora + Golden Crown for Blue Fedora a good trade?
you> I bought Ice Fedora for 1200
you> how's my portfolio doing?
```

One question, no chat:
```
python agent.py --once "is Teapot Hat for Classic Fedora a good trade?"
```
Add `--quiet` to hide the `[checking ...]` lines that show which data the agent looked up.

The original commands still work without an API key:
```
python roblox_trade_advisor.py search fedora
python roblox_trade_advisor.py trade --give "Item A" "Item B" --get "Item C"
python roblox_trade_advisor.py scan --budget 5000 --min-edge 0.1 --min-demand 2
python roblox_trade_advisor.py portfolio
```

## How it works

- `roblox_trade_advisor.py` fetches `https://api.rolimons.com/items/v2/itemdetails` and
  caches it for 15 minutes (in memory and in `.rolimons_cache.json`), so the API is hit at
  most once every 15 minutes.
- `agent.py` gives Claude (`claude-sonnet-5-5`) five tools: `search_items`,
  `evaluate_trade`, `scan_candidates`, `get_portfolio` and `update_portfolio`. It runs the
  tool loop until Claude has an answer and keeps the conversation in memory for the session.
- `portfolio.json` (created on first use) records what you bought and for how much.
  "Net if sold now" subtracts Roblox's 30% marketplace fee.

Limits to keep in mind:
- RAP is used as the buy price. The cheapest real listing may be higher or lower.
- Trade verdicts compare Rolimons values: **good** if you get 10%+ more value, **fair**
  within -5% to +10%, **bad** below that. A "good" trade is downgraded to "fair" when part
  of what you get is projected, unvalued or low demand.

## Tests

Offline, using mock item data and a fake Claude client:
```
python -m unittest discover -s tests -v
```
To try the CLI without hitting Rolimons: `ROLIMONS_MOCK_FILE=tests/mock_items.json python roblox_trade_advisor.py scan --budget 5000`.

## Roblox skills for Claude

`.claude/skills/` holds 27 Roblox game-development skills (Luau, data saving, networking
and security, monetization, UI, VFX, physics, publishing and more). Claude loads them
automatically in sessions that work on this repo.

They were copied from [Roqer](https://github.com/S4US/Roqer) at commit `62f4295`, leaving out
`roblox-studio-mcp`, which only covers Roqer's own app. Most are based on
[roblox-brain](https://github.com/TabooHarmony/roblox-brain) (MIT, see
`ROBLOX-BRAIN-LICENSE.txt`), and Roqer's additions are AGPL-3.0 (see
`ROQER-LICENSE-AGPL-3.0.txt` and `ROQER-PROVENANCE.md`). Those licences cover the skill
files only, not the rest of this repo. Where a skill mentions Roqer's Studio commands
(such as `build_instances` or the Blender worker), Claude writes plain Luau or Rojo files instead.
