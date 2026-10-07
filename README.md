# bagoflean: Roblox Limited trade advisor

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
