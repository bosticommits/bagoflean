# Game Plan: Hollywood RNG (working title was Movie Mogul)

You own a tiny film studio. Roll casting calls for random actors (rarity, luck, variants),
pair them with a script, and shoot a movie. It keeps filming while you are offline. Come back
for the **premiere**, where a box-office roll decides between Flop and Masterpiece.
Every actor you discover fills your Index, and your studio lot grows into a Hollywood empire
that everyone on the server can see.

Look and feel: see [ART_STYLE.md](ART_STYLE.md).

Status: **M0 to M5 built** (version 1, with placeholder part-based art), and the **M6 launch
features** (Award Night, daily rewards, Studio Requests, codes, game passes, developer products,
analytics). Icon, thumbnails and the publish checklist are still to do. Prices, payouts and odds
are tuned with a simulator against a target progression curve: see [ECONOMY.md](ECONOMY.md).
Playtests should confirm them. Sections 11 and 12 list the decisions made while building.

Why this game: it combines the loops behind the biggest 2025-26 hits. Grow a Garden has
progress while offline and come-back-later payoffs. RNG games have rarity, luck, an index
and variants. Steal a Brainrot shows off your rarest items to the server and runs rare
spawn events. On top of that is a theme (filmmaking) that is not already crowded on Roblox.

---

## 1. The loop

| Layer | Time | What the player does |
|---|---|---|
| Core action | seconds | **Collect** box-office cash at your cinema. **Tap the clapperboard** to speed up filming |
| RNG roll | seconds | **Casting Call**: spend Cash to roll a random actor, with a rarity reveal |
| Make a movie | minutes | Pick a **script** (genre) and cast up to 3 actors, then filming starts on a real-time timer |
| Come back | minutes to hours | Filming continues **while offline**. Return for the **premiere roll** |
| Collection | days | Fill the **Talent Index** (actors and variants) and win genre awards |
| Long goal | weeks | Grow the lot (more stages, bigger cinema), raise Fame, **Sequel** (rebirth) |
| Expansion | updates | New departments: Music Label, TV Network, Streaming (the "any career" idea) |

## 2. Making a movie

1. **Script**, bought from the script shop. It sets the genre (Action, Comedy, Horror,
   Romance, Sci-Fi), base earnings and filming time.
   - Short Film: 2 min, Indie: 10 min, Feature: 45 min, Epic: 3 h.
2. **Cast**, up to 3 actors from your roster. Each actor has **Star Power** (from rarity)
   and a **specialty genre**. Casting an actor in their specialty gives ×1.5. This creates
   real choices beyond "use your rarest actor".
3. **Filming**: a timer on one of your stages. It keeps running offline. Tapping the
   clapperboard takes a few seconds off.
4. **Premiere**: a box-office roll, affected by Luck.

| Result | Chance | Payout |
|---|---|---|
| Flop | 20% | ×0.5 |
| Hit | 55.25% | ×1 |
| Blockbuster | 20% | ×3 |
| Cult Classic | 4.5% | ×6, plus the poster becomes collectible |
| Masterpiece | 0.25% (1 in 400) | ×20, plus a server-wide announcement and a trophy on your lot |

Payout = script base × total Star Power × genre bonus × premiere result. It gives Cash and Fame.
Finished movies go to your **cinema** and earn a small royalty every second, including
offline up to a cap (start at 4 h, raised by upgrades).

## 3. Casting rarity (actors)

All actors are **original fictional characters**: no real celebrities, names or likenesses.
Luck divides the "1 in N" chance (Luck ×2 turns 1/5,000 into 1/2,500).

| Tier | Example actors | Base chance | Star Power |
|---|---|---|---|
| Newcomer | Nervous Intern, Stunt Double | 1 in 2 | 1 |
| Rising | Soap Opera Regular, Ad Model | 1 in 6 | 3 |
| Pro | Action Veteran, Comedy Duo | 1 in 40 | 8 |
| Star | Teen Heartthrob, Method Actor | 1 in 500 | 20 |
| Superstar | Box Office King, Scream Queen | 1 in 5,000 | 50 |
| Legend | Golden Age Diva | 1 in 60,000 | 120 |
| Icon | The Mogul's Muse | 1 in 1,000,000 | 300 |

**Variants**, rolled on top of any actor: *Shiny* (1 in 40, ×2) and *Award-Winning*
(1 in 800, ×5). Each variant has its own Index slot. Version 1 ships 21 actors (3 per tier),
which with variants makes **63 Index slots**.

**Casting agencies** (Fame-gated): Open Casting, Talent Agency, Hollywood Casting.
Better agencies cost more per roll and remove the bottom tier from the pool.

Odds are always shown on the casting screen. Roblox requires this for paid random items,
and players expect it.

## 4. Your studio lot (the show-off part)

- Each server has 6 lots, so you see other players' studios. Building is visual: stages,
  cinema, offices, trophies.
- **Upgrades** (Cash): more sound stages (start 1, max 4 movies filming at once), cinema
  size (royalty rate), offline cap, Luck, clapperboard power.
- **Billboard**: automatically shows your rarest actor to the whole server.
- **Red carpet**: Masterpiece premieres play a short celebration on your lot.

## 5. Events and retention

- **Award Night**, every 30 min on each server: 3 minutes of boosted casting Luck and
  doubled premiere payouts. It brings people back on a schedule.
- **Live events** (weekly): a limited "Film Festival" actor pool, like the hits' admin events.
- **Server announcement** when anyone pulls Legend or Icon, or gets a Masterpiece.
- Daily login rewards, 3 daily **Studio Requests** (small quests), codes for socials.

## 6. Progression

- **Fame** never resets. It unlocks agencies, genres, script tiers and lot expansions.
- **Index rewards**: complete a tier row for +Luck. Complete all of a genre's actors for a
  permanent genre bonus.
- **Sequel** (the Rebirth button): pay Cash to start the studio over. Cash and every upgrade reset,
  but actors, the Index and Fame are kept, for a permanent Cash multiplier and +Luck. See section 13.

## 7. Monetization (after version 1 is fun)

- Game passes: **2× Luck**, **Auto-Collect**, **+1 Sound Stage**, **Faster Filming**, VIP cosmetics.
- Developer products: **Lucky Casting** boost (15 min), skip filming, Cash packs.
- Rules: odds always visible, no buying specific rare actors, free players can reach everything.

## 8. Technical rules (from the Roblox skills)

- **Server decides everything**: rolls, Cash, timers and premiere results. The client sends
  requests and plays animations. Validate and rate-limit every remote.
- **Offline timers**: store real `os.time()` start/end stamps. Never trust client time.
- **Saving**: DataStore with session locking (ProfileStore) and a versioned schema. Save on
  leave, periodically, and on shutdown.
- **Purchases**: `ProcessReceipt` grants each purchase exactly once.
- **Rojo project** in this repo, so every script is in Git.
- Mobile-first UI: big buttons, safe areas, readable on phones.

## 9. Milestones

| # | Milestone | Done when |
|---|---|---|
| M0 | Setup | Rojo project synced into Studio. Claude can see and playtest the place |
| M1 | Lot and cash | 6 claimable lots, cinema collect pad earns Cash, HUD, data saves |
| M2 | Casting | Casting Call roll with odds and reveal, roster screen, 21 actors and variants |
| M3 | Movies | Script shop, cast 3, filming timer (incl. offline), premiere roll, cinema royalties |
| M4 | Index and progression | Index screen, tier rewards, Fame, agencies, lot upgrades |
| M5 | Polish | Lot visuals, billboard, premiere and rare-pull VFX and sounds, 60-second tutorial |
| M6 | Launch prep | Award Night, daily rewards, monetization, publish checklist, icon and thumbnail |
| M7+ | Live ops | Weekly events, Sequel, new genres, Music Label department |

**Version 1 = M0 to M5.** Playtest after every milestone. If casting plus a premiere is not
exciting by M3, fix the core before adding anything else.

## 10. Open questions

- ~~Final game name~~ Decided 7 Oct 2026: **Hollywood RNG**.
- Whether to add light player interaction later (visiting lots, co-starring in premieres)

## 11. As built (decisions made during M0 to M5)

- **Tier odds** are rolled rarest first, so every tier from Rising up hits its "1 in N" exactly.
  Newcomer gets the rest (about 80%, not "1 in 2"): both cannot be true at once.
- **Agencies**: Open Casting $10 (Fame 0), Talent Agency $1,000 (Fame 3,500), Hollywood
  Casting $100,000 (Fame 50,000). Removing bottom tiers rescales the rest of the pool, so better
  agencies make rare tiers more likely (Icon: 1 in 1,000,000, 189,301 and 27,162).
- **Actors are not used up.** A copy is busy while it is filming and returns after the
  premiere, so duplicates and extra stages matter.
- **Fame** is a threshold, never spent: about the square root of each payout. It gates
  agencies, Feature (1,800) and Epic (16,000) scripts, Horror and Romance (100), Sci-Fi (2,000),
  and stages 2 to 4 (50, 2,800, 16,000).
- **Index rewards**: a complete tier row gives +0.05 Luck; a complete genre set gives x1.15
  payout for that genre. Both are claimed in the Collection screen.
- **Upgrades**: Sound Stage (to 4), Cinema Size (royalties x1.25 per level), Offline Earnings
  (+2 h per level), Luck (+0.1 per level), Clapperboard (+0.5 s per tap per level, 2 s to 4 s).
  Prices grow about 4 to 8 times per level so the last levels land around the end of week one.
- **Cinema** keeps 10 movies; when full, the lowest-earning one is dropped.
- **Tutorial**: about a minute. New players start with $100, and their first Short Film takes
  15 seconds. Steps complete from real game state, so returning players skip what they have done.
- **Sounds** come from Roblox's own UI sound library (creator: Roblox). Effects use built-in
  textures only. Lots are plain parts: there is no mesh or uploaded art yet.
- **Saving** uses ProfileStore (vendored), as planned.

## 12. As built (M6 launch features)

- **Award Night** runs on a fixed clock: the first 3 minutes of every half hour (UTC :00 and :30),
  the same on every server. Casting Luck x2 and premiere payouts x2. The HUD shows a countdown,
  and the server announces the start. A premiere claimed during Award Night is doubled, so
  players can save finished movies for it.
- **Luck stacking** for Casting Calls: Luck upgrades and Index rewards, then x2 for each of the 2x
  Luck pass, an active Lucky Casting boost, and Award Night. Premieres use the upgrade Luck only.
  The odds panel always shows the current, boosted odds.
- **Daily rewards**: a 21-day streak that repeats, with big milestone days at 7, 14 and 21
  ("play N days in a row to unlock this rare reward"); days after tomorrow show "???"; missing a UTC day starts again at day 1. Days
  come from the server clock, so changing the device clock does nothing. A "Welcome back!" screen
  opens by itself when a reward is waiting (not during the tutorial).
- **Studio Requests**: 3 a day from a pool of 6 (the same 3 for everyone), reset at UTC midnight.
- **Cash rewards scale**: each one is "at least $X, or N minutes of your box office income if
  that is more", so they stay worth having late in the game.
- **Codes** live in `src/server/Codes.luau` (server only). Each works once per player. A code can be
  switched off without an update through the `GameConfig` DataStore (see `LiveConfig.luau`).
- **Game passes**: 2x Luck, Auto-Collect (banks the box office every 10 s), +1 Sound Stage (a 5th
  stage), Faster Filming (films take 75% of the time), VIP (head tag, chat tag, starred marquee).
  Ownership is checked on join and saved once confirmed, so an API outage never removes a pass.
- **Developer products**: Lucky Casting (15 min), Skip Filming (a token; the stage's Skip button
  uses it, or prompts the purchase and uses it on arrival), Box Office Bag (30 min of income, at
  least $5,000) and Box Office Vault (4 h, at least $50,000). Receipts use ProfileStore's
  purchase-id pattern: the grant and the receipt id are saved together, and the purchase is only
  acknowledged after that save, so every purchase is granted exactly once.
- **"Don't leave yet!" gift**: opening the Roblox menu (often the first step of leaving) shows a
  gift behind the menu: x2 Luck for 10 minutes plus some Cash. Once per UTC day, and only after
  5 minutes of play in that session, both checked on the server, so it cannot be farmed.
- **Welcome back**: on joining, a banner says what the cinema earned while the player was away.
- No Robux purchase gives a random item, so no paid-random-item rules apply yet.
- **Analytics** (server only): every Cash source and sink (batched per minute), the onboarding
  funnel for new players (joined, lot, first cast, script, film, premiere, collect, tutorial), and
  custom events for rare pulls, premieres, daily claims, requests, codes and purchases.

## 13. As built (Rebirth, the Sequel)

- **Rebirth button** in the side menu (second column, under Upgrade) with a green chip: how close Cash
  is to the next rebirth ("43%"), "READY!" on gold once it is affordable, "MAX" after the last one.
- **Price**: $250,000 for the first, then 6 times more each time. There are 12. Tuned with the
  sim: the first lands early on day 2, the next ones further and further apart (ECONOMY.md).
- **What resets**: Cash (to the starting $100, plus the box office waiting at the gold pad) and
  every upgrade, sound stages included.
- **What is kept**: every actor (the plan first said the roster would reset; keeping it is kinder
  and is how the reference games do it), the Index and its rewards, Fame and everything it unlocks,
  scripts, the cinema's movies, trophies, game passes, boosts and Skip tokens. A film still
  filming keeps going, and its stage stays open until it premieres.
- **Bonus, forever**: every premiere's Cash x1.5 after one rebirth, x2 after two, and so on, plus
  +0.1 Luck each. Fame is worked out before the bonus, so Fame unlocks stay on their curve. The
  cinema keeps the boosted payout, so the box office grows with it. The premiere card shows
  "(rebirth x2)".
- **Show-off**: the studio's marquee gets its sequel number ("BOSTI PICTURES 2"), the whole server
  sees an announcement and fireworks over the lot, and the player gets a big reveal card.
- **Screen**: the price and a progress bar, the bonus now and after, what is kept and what starts
  over, then a "Yes, start over!" confirmation. The server checks everything; the remote carries
  no values.
- **Saving**: a `rebirths` count in the player's profile (schema version 6). Older profiles get 0.
