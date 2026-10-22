# Gifting and Trading: Design

Status: **design only, waiting for Bosti's OK.** No game code is changed by this document.

---

## Part 1: The short version (plain words)

### What players get

- **Trading:** two players in the same server open a trade window, each puts in actors, both press
  **Ready**, a 5 second countdown runs, both press **Confirm**, and the actors swap.
- **Gifting:** the same window, but only one side puts something in. The other player still has to
  accept. A gift is just a one-sided trade, so it uses exactly the same safe code.
- Only **actors** can be traded (any tier, any variant). Not Cash, not scripts, not upgrades, not
  mascots.

### How it stays safe

1. **The server decides everything.** The player's screen only says "I want to offer this" or
   "I'm ready". The server checks every actor is really owned and not busy filming, every time.
2. **Promise first, then deliver.** Roblox cannot save two players in one go. So before any actor
   moves, the server writes a trade receipt (the "promise"). If the server crashes halfway, the
   receipt lets the game finish the trade the next time each player joins. Nobody can end up with a
   copied actor, and nobody can lose one.
3. **Both players' saves are locked** while they play (ProfileStore already does this), so the same
   player cannot be loaded on two servers and trade the same actor twice.
4. **Limits on rare actors**, so a hacked account or a scammer cannot empty a studio in one day.
5. **Roblox's rules:** our actors can come from Robux (Cash packs pay for Casting Calls, Lucky
   Casting boosts Luck). Roblox says players in some countries must not trade items like that. The
   game asks Roblox for **both** players, and the trade button only appears if both are allowed.
6. **An off switch.** One command in Studio turns trading off on every live server within a minute.
7. **A receipt for every trade**, so Bosti can see who traded what and undo a scam if needed.

### What I need Bosti to decide (my pick in bold)

| # | Question | Options |
|---|----------|---------|
| 1 | Can players trade Cash? | **No** (stops Robux-bought Cash being passed around and keeps the economy simple) / Yes |
| 2 | Icon actors and Award-Winning copies | **Tradable, with a daily limit** / Never tradable |
| 3 | Does an actor you get in a trade fill your Index? | **Yes** (what players expect; Index rewards still pay only once) / No |
| 4 | Gifts to friends who are offline | **Later** (version 2) / Now |
| 5 | Limited seasonal actors (Pumpkin Phantom and friends) | **Tradable** (makes them feel special) / Not tradable |

### The simplest safe version (version 1)

- Same server only, both players online. No offline gifts yet.
- Actors only.
- Players need: the tutorial finished, a Roblox account at least 3 days old, and Roblox's trading
  check passed. Everyone else never sees the trade button.
- Limits: 8 actors per side per trade, 20 trades a day, and 3 "rare" actors (Legend, Icon, or
  Award-Winning) given away per day.

Version 2 (later, only if version 1 is calm): offline gifting through ProfileStore messages, and a
trading booth area in the town.

---

## Part 2: How it works (for whoever builds it)

### What the save data looks like today

- `PlayerData.roster: { [key]: number }` where key is `"actorId:variantId"`, value is copies owned.
- `PlayerData.index: { [key]: boolean }` is "ever discovered", kept through rebirth.
- Copies in `PlayerData.films[*].cast` are busy until their premiere (MovieService counts them).
- Rebirth keeps actors and the Index (`Rebirth.reset` does not touch them).
- `DataService` is the only code that touches ProfileStore. Each player is their own profile key
  (`player_<UserId>`), session-locked by ProfileStore.

Nothing in the roster shape needs to change to trade. Trading only adds and removes copies.

### Who can trade (checked when the trade opens, and again at commit)

```
canTrade(player) =
    LiveConfig trading switch is on
    and data loaded and session active
    and data.tutorialDone
    and player.AccountAge >= 3
    and policy.IsPaidItemTradingAllowed == true   -- PolicyService, see below
```

**Roblox policy.** `PolicyService:GetPolicyInfoForPlayerAsync(player)` returns
`IsPaidItemTradingAllowed`. Roblox's paid random items guidelines say users marked ineligible must
not be able to trade the outcome of a paid random item, and that includes things bought with paid
in-game currency. Every actor in our game can come from Robux indirectly (Cash packs, Lucky Casting),
and we cannot tell a "free" copy from a "paid" copy, so we treat **all** actors as paid items:

- Read the policy once on join (wrapped in `pcall`; same pattern as `ShopService` reads
  `ArePaidRandomItemsRestricted`). Store it on the server, and set a `TradeAllowed` attribute so the
  client can hide the button.
- **A failed read means not allowed.** Never assume true.
- Both players must be allowed. If either is not, the request is refused before any window opens,
  and the other player just sees "This player can't trade right now" (we never say why, it reveals
  their region).
- Gifts follow the same rule, because a gift moves the item too.

### What can be offered

- Actor copies only: `{ key = "actorId:variantId", count = n }`.
- A copy is offerable if `roster[key] - busy[key] - alreadyOffered[key] >= 1`, where busy is
  counted exactly like `MovieService` counts it.
- Up to 8 entries per side. Counts are whole numbers from 1 up.
- Unknown actor or variant ids are refused (`Actors.get` / `Actors.variant` return nil).

### Limits

Kept in `PlayerData.trading` (new field, reconciled from the template, so old profiles are fine):

```
trading = {
    day = 0,                -- UTC day the counters below belong to
    trades = 0,             -- trades completed today (max 20)
    rareGiven = 0,          -- Legend, Icon or Award-Winning copies given away today (max 3)
    applied = {},           -- last 50 trade ids applied to this profile (idempotency)
    pending = nil,          -- { id, other, give, get } while a commit is in flight
    history = {},           -- last 20 trades for a "Trade history" screen
}
```

Server-side request limits on top: one open trade per player, one trade request every 5 seconds,
offer edits at most 10 per second, requests time out after 30 seconds.

Numbers live in a new `src/shared/Trading.luau` so they can be tuned, tested, and shown to players.

### The trade window, as a state machine (server owns it)

```
Requested --accept--> Open --both Ready--> Countdown (5 s) --both Confirm--> Committing --> Done
    |                  |  ^                    |                                 |
  decline/timeout      |  +-- any offer edit --+  (edits reset both Ready)       +--> Failed (nothing moved)
                       +-- cancel / leave / session ends --> Cancelled
```

- Client remotes only carry intent: `TradeRequest(target)`, `TradeRespond(accept)`,
  `TradeOffer(key, count)`, `TradeReady(bool)`, `TradeConfirm()`, `TradeCancel()`.
  Every one is type-checked and rate-limited; anything odd cancels the trade.
- The server sends both players the full window state after every change (`TradeSync`). The client
  never computes what is in the trade.
- Any edit during the countdown cancels Ready on both sides and restarts. This stops the classic
  "swap the item at the last second" scam.
- A player leaving, their data session ending, or the off switch flipping cancels the trade.

### Commit: the crash-safe part

**The problem.** Roblox DataStores cannot save two keys in one transaction. A naive trade (move the
actors in memory, then save A, then save B) duplicates or loses an actor if the server dies between
the two saves.

**The fix: a write-ahead receipt with three steps.** A new DataStore `Trades_v1` holds one key per
trade, `trade_<id>` (id = `HttpService:GenerateGUID(false)`). That single key is the one place
that decides whether the trade happened.

1. **Lock.** Re-validate everything. Put `trading.pending = { id, other, give, get }` in **both**
   profiles (no actors move yet) and save both. Wait until both `OnAfterSave` show the pending id
   (same waiting pattern as `DataService.grantPurchaseOnce`). If either save fails or times out:
   clear both pending marks and cancel. Nothing moved.
   While `pending` is set, that player cannot cast actors into a film, rebirth, or open another trade.
2. **Decide.** `UpdateAsync` on `trade_<id>`: if the key is empty, write
   `{ status = "committed", a, b, giveA, giveB, time }`; if it already says `"aborted"`, keep that and
   cancel. This is atomic on one key, so there is exactly one answer.
3. **Apply.** In one step with **no yields** (Luau runs it without interruption): re-check both sides
   still have the copies, move them on both profiles, set `index` for received keys, bump the daily
   counters, add the id to `trading.applied`, add a `history` row, clear `pending`. Then save both
   and wait for both saves. Tell the players "Trade complete!" only after that.

**Recovery on join** (in `DataService.load`, after `migrate`): if `trading.pending` is set and its id
is not in `trading.applied`:

- Read `trade_<id>` with `UpdateAsync`. If it is empty, write `"aborted"`. (So a trade can never be
  committed after a player's recovery has decided it was not.)
- If the receipt says `"committed"`: apply **this player's side only** (remove what they gave, add
  what they got), add the id to `applied`, clear `pending`. The other player does the same on their
  own next join, or already did.
- If it says `"aborted"`: just clear `pending`.

Why this covers every crash point:

| Server dies... | Receipt | What happens next join |
|---|---|---|
| before step 1 saves land | none | `pending` not saved, nothing to do |
| after step 1, before step 2 | none | recovery writes "aborted", both clear `pending`, nobody loses anything |
| after step 2, before step 3 saves | committed | each player applies their own side once |
| after only one step 3 save | committed | the saved one has the id in `applied` and skips; the other applies |
| after both step 3 saves | committed | nothing to do |

Applying is **idempotent** because each profile records the ids it applied, and each profile only
ever changes itself. Session locking guarantees the trading server and a recovering server never
hold the same profile at the same time. If a trading server is slow and a player's session is taken
by another server, that profile's `OnSessionEnd` fires and the trading server cancels; if the receipt
was already committed, the new server's recovery finishes that player's side.

**Cost.** Two saves per player plus one or two receipt writes per trade. With 20 trades a day per
player and a 6 player server, this is far under the DataStore write budget
(60 + 10 x players per minute per server).

### Index, achievements, quests

- Received actors set `index[key] = true` (decision 3). Index rewards are claimed once per profile,
  so passing an actor back and forth gives each player at most the one-time reward.
- Trading does **not** count as casting: no `cast` stat, no hot start progress, no casting quests.
- `AchievementTracker.changed` and `RosterSync` fire after the commit so screens update.

### Support tools for Bosti

- **Off switch:** `GameConfig` key `TradingEnabled = false` via `LiveConfig` (same as
  `DisabledEvents`). Open trades cancel; nothing half-done is left behind.
- **Look up a trade:** read `Trades_v1/trade_<id>` from the command bar. Each player's last 20 trades
  are in their profile with the ids.
- **Undo a scam:** a Studio-only `TradeAdmin.reverse(id)` that runs a new trade the other way through
  the same three steps (so it is crash-safe too), only if both players still own the copies.
- Analytics events: `trade_done` (tiers moved), `trade_cancelled` (reason). No item lists in
  analytics.

### Anti-scam and fairness

- Both offers shown side by side with rarity colors and the actor's earning multiplier.
- Giving away a Legend, Icon or Award-Winning copy for nothing shows "This can't be undone" and needs
  a second tap.
- 5 second countdown, edits reset Ready, final Confirm on both sides.
- No Cash in trades, so "I'll pay you later" style scams have nothing to promise with in the game.
- Trades are only between players in the same server; no trade ads or global trade board in v1.

### Tests

- `tests/luau/trading.spec.luau`: pure rules in `Trading.luau` (offerable counts with busy copies,
  limits, day rollover, unknown ids refused).
- A pure `Trading.applySide(data, give, get, id)` tested for idempotency (applying twice changes
  nothing the second time) and for never going below zero.
- Recovery tested with a fake receipt store for every row of the crash table above.
- Studio playtest with two players (Test > Clients and Servers > 2 players): trade, gift, cancel,
  leave mid-trade, and a debug flag `TradeCrashAt = "lock" | "decide" | "apply"` that stops the
  server at each step to prove recovery works.

### Build plan (one visible change at a time)

1. **Server only, no UI** (Opus high): `Trading.luau`, `TradeService.luau`, the `trading` save field,
   recovery in `DataService.load`, LiveConfig switch, tests. Hidden behind the switch, off by default.
2. **Trade window UI** (Opus medium): the window, request popup, history screen, in the UiKit style.
3. **Bosti playtest with two players**, then turn the switch on.

---

Sources: [Roblox paid random items guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items)
(IsPaidItemTradingAllowed and ArePaidRandomItemsRestricted), [PolicyService guidelines thread](https://devforum.roblox.com/t/policyservice-guidelines/773321).
