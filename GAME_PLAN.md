# Game Plan: Movie Mogul (working title)

You own a tiny film studio. Roll casting calls for random actors (rarity, luck, variants),
pair them with a script, and shoot a movie. It keeps filming while you are offline. Come back
for the **premiere**, where a box-office roll decides between Flop and Masterpiece.
Every actor you discover fills your Index, and your studio lot grows into a Hollywood empire
that everyone on the server can see.

Status: **draft, nothing built yet.** Numbers are starting points, to be tuned in playtests.

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
| Hit | 55% | ×1 |
| Blockbuster | 20% | ×3 |
| Cult Classic | 4.5% | ×6, plus the poster becomes collectible |
| Masterpiece | 0.5% | ×20, plus a server-wide announcement and a trophy on your lot |

Payout = script base × total Star Power × genre bonus × premiere result. It gives Cash and Fame.
Finished movies go to your **cinema** and earn a small royalty every second, including
offline up to a cap (start at 4 h, raised by upgrades).

## 3. Casting rarity (actors)

All actors are **original fictional characters**: no real celebrities, names or likenesses.
Luck divides the "1 in N" chance (Luck ×2 turns 1/1,500 into 1/750).

| Tier | Example actors | Base chance | Star Power |
|---|---|---|---|
| Newcomer | Nervous Intern, Stunt Double | 1 in 2 | 1 |
| Rising | Soap Opera Regular, Ad Model | 1 in 6 | 4 |
| Pro | Action Veteran, Comedy Duo | 1 in 30 | 15 |
| Star | Teen Heartthrob, Method Actor | 1 in 200 | 70 |
| Superstar | Box Office King, Scream Queen | 1 in 1,500 | 400 |
| Legend | Golden Age Diva | 1 in 15,000 | 2,500 |
| Icon | The Mogul's Muse | 1 in 150,000 | 20,000 |

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
- **Sequel** (rebirth, unlocked at a Fame level): reset Cash, stages and roster but keep the
  Index and Fame, for a permanent earnings multiplier and +Luck.

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

- Final game name ("Movie Mogul", "Studio Tycoon RNG", "Hollywood RNG"...)
- Art style (bright cartoon is the safe pick for this audience)
- Whether to add light player interaction later (visiting lots, co-starring in premieres)
