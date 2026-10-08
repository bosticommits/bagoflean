# Hollywood RNG economy

This is the progression curve the numbers in `src/shared/` are tuned to, and how to check it.
Every number below comes from `tools/economy_sim.py`, which reads the Luau files directly and
plays a simple, sensible player through a week. Run it after changing any price, payout or odds:

    python3 tools/economy_sim.py                    # typical player, 300 runs
    python3 tools/economy_sim.py --player casual     # also: hardcore
    python3 tools/economy_sim.py --luck-pass         # owns the 2x Luck pass
    python3 tools/economy_sim.py --no-achievements   # leave achievement rewards out, to compare
    python3 tools/economy_sim.py --days 28           # four weeks, to see the rebirth ladder
    python3 tools/economy_sim.py --no-rebirth        # a player who never rebirths
    python3 tools/economy_sim.py --no-events         # the same week without special events

The sim includes Award Night, special events, daily rewards, Studio Requests, achievements, codes, the "don't leave yet" gift,
Lucky Casting boosts, Skip tokens and rebirths (its player saves for a rebirth once it costs less
than about 20 minutes of income, and rebirths as soon as it can afford one). It does not model game passes other than 2x Luck, or
Robux cash packs. Treat it as the shape of the curve, not a promise: playtests decide.

## The curve in plain words

- **First session (about 20 minutes).** The first casts already give a Rising and usually a Pro
  actor. A second sound stage and the Horror and Romance scripts unlock around minute 8. Most
  players see their first purple **Star** actor around minute 20.
- **Day one (about an hour).** The **Talent Agency** opens around minute 30, and the premiere
  that unlocks it says so. Feature scripts and Sci-Fi follow by minute 40. Talent Agency casts
  are where spare Cash goes for the rest of the hour, so the third sound stage comes at the start
  of day 2.
- **Days 2 to 3.** The overnight box office pays for the **first rebirth** early on day 2
  (Movie Cash x1.5). The first **Superstar** comes around the end of day 1 or early on day 2, the
  first **Masterpiece** on day 2 or 3. The **second rebirth** and **Epic** scripts come late on
  day 3.
- **Days 4 to 7.** The fourth stage comes on day 4 and the **third rebirth** on day 5. Every
  upgrade is maxed again by day 6, and **Hollywood Casting** opens on day 6. About two thirds of
  players pull a **Legend** in week one. **Icon** stays a rare brag (about 1 in 20 players in week
  one). Most of the Index (about 35 of 63 slots) is left
  for week two.
- **Weeks 2 to 4.** Rebirths keep coming, each further apart: the fourth on day 8, the fifth on
  day 12, the sixth on day 19, the seventh in week five. That is the long goal once the week-one
  unlocks are done.

How you earn changes over the week. Early on, active play (Short Films plus clapping) is most of
the income. By the end of the week, about three quarters comes from time away: overnight Epics
and the cinema's royalties. Logging in to premiere and cast is the core habit, and an active
session is mostly spent casting.

## Milestones (typical player: 60 minutes on day one, then three 15-minute visits a day)

Median time, from 300 runs. "Slow 10%" is the unlucky end. Rebirths reset upgrades, so "Sound
stage 4" and "maxed" mean the first time.

| Milestone | Median | Slow 10% |
|---|---|---|
| Horror and Romance scripts | day 1, 6 min played | 8 min |
| Sound stage 2 | day 1, 6 min | 9 min |
| First Star actor | day 1, 17 min | 30 min |
| Feature scripts | day 1, 35 min | 39 min |
| Sci-Fi scripts | day 1, 38 min | 44 min |
| Talent Agency | day 1, 30 min | 35 min |
| Sound stage 3 | day 2 (60 min) | day 2 (60 min) |
| First Superstar | day 2 (60 min), often late day 1 | day 3 |
| **Rebirth 1** (Movie Cash x1.5) | day 2 (75 min) | day 2 (99 min) |
| First Masterpiece | day 3 (113 min) | day 6 |
| **Rebirth 2** (x2) | day 3 (136 min) | day 4 |
| Epic scripts | day 3 (146 min) | day 4 |
| Sound stage 4 | day 4 (150 min) | day 4 |
| Cinema, Offline, Clapperboard maxed | day 4 | day 5 |
| **Rebirth 3** (x2.5) | day 5 (195 min) | day 5 |
| All upgrades maxed | day 6 (98% in week one) | day 7 |
| First Legend | day 6 (64% of players in week one) | |
| Hollywood Casting | day 6 (258 min) | day 7 |
| First Icon | 6% of players in week one | |
| **Rebirth 4** (x3) | day 8 (52% in week one) | day 11 |
| **Rebirth 5** (x3.5) | day 12 | day 14 |
| **Rebirth 6** (x4) | day 19 | day 22 |

Without rebirths (`--no-rebirth`) the week-one unlocks land within a few minutes of the same times
(Epic scripts at 147 minutes instead of 150), Legend is 57% and Icon 5%, and income at the end of
the week is about 30,000 a minute instead of 80,000.

Other players:
- **Casual** (25 min on day one, then 20 min a day): Talent Agency on day 2 (30 min played),
  the first rebirth on day 3,
  first Superstar on day 4, the second rebirth on day 6, Epic scripts on day 7. Legend 12 to 20%,
  Icon 1% in week one.
- **Hardcore** (about 2 hours a day): Talent Agency at 30 minutes, the first rebirth near the
  end of day 1, the second on day 2, Hollywood on day 3, the third rebirth and a Legend (95%) on
  day 4, Icon 11% in week one, all upgrades maxed again on day 5.
- **2x Luck pass** (typical schedule): Talent Agency at 26 minutes, first rebirth at 60 minutes,
  Superstar in the first hour, Legend about 80%, Icon 7 to 9%. Faster, but nothing a free player cannot reach.

## Talent Agency at 30 minutes (review, 2026-10-08)

`LAUNCH_CHECKLIST.md` asks for the Talent Agency in about 20 to 30 minutes; the sim had it at 54.
Before changing anything, the question was which requirement held it back, Cash or Fame.

- **Fame was the bottleneck.** The sim's player cast at the Talent Agency the same minute its Fame
  gate opened (54 and 54). With the Fame gate taken away, Cash alone would let it start at
  minute 20 (slow 10%: 24). The $1,000 price was never what made players wait.
- **One lever: the Fame gate, 3,500 to 1,400.** The price stays $1,000. Gates tried (typical
  player, 200 runs, median and slow 10% in minutes played): 1,000 gives 25 / 28, 1,200 gives
  28 / 31, **1,400 gives 30 / 35**, 1,500 gives 32 / 35, 1,800 gives 36 / 39, 3,500 gives 54 / 60.
- **What it changes.** Casual players reach it on day 2 instead of day 3 and hardcore players at 30
  minutes instead of 52. A typical player makes about 125 Talent Agency casts in the first hour
  instead of 52. Those casts are where spare Cash goes, so the third sound stage moves from minute
  48 to minute 60 (the start of day 2) and day one ends at about 2,500 a minute instead of 3,200.
  Hardcore players' first rebirth moves from 86 to 110 minutes for the same reason. The first
  Superstar stays around minute 60, and week one ends where it did: Hollywood Casting on day 6,
  Legend 64%, Icon 6%, about 91,000 a minute.
- **Players are told.** A premiere that pushes Fame past any gate now says so on its result card
  ("NEW: Talent Agency unlocked!"). `src/shared/Unlocks.luau` reads every Fame gate from Actors,
  Movies and Upgrades, so it stays right when a gate is retuned.

Other checks from the same review (nothing else was changed):
- **Unlucky players.** Fame is the square root of each payout, so a lucky premiere moves unlocks
  only a little: the slowest 10% reach the Talent Agency 5 minutes after the median. Nobody can hit
  a Cash dead end: the cinema always pays at least $0.50 a second and a Short Film script costs $15.
- **Active play against time away.** Unchanged by this: about a fifth of a typical player's
  income is earned away by the end of day one and about 70% by the end of week one. Playtests
  should check that casting and premieres still feel like the best use of a session late in the
  week; the cinema royalty rate is the first lever if they do not.
- **Sound stage 3 on day 2.** If playtesters feel the third stage comes too late, the fix is its
  price ($25,000), not the Talent Agency gate.

## The levers and why they are set this way

**Star Power grows about 2.5 times per tier** (1, 3, 8, 20, 50, 120, 300). It used to grow 4 to 8
times per tier (up to 20,000), so every rare pull multiplied income, which bought more pulls. In
the old numbers a player had every upgrade maxed after 35 minutes and earned 270 million a minute
by day 7.

**Odds are rarer at the top** (Star 1 in 500, Superstar 1 in 5,000, Legend 1 in 60,000, Icon
1 in 1,000,000). Casting soon costs almost nothing compared with income, so how fast rare actors
arrive depends on how many casts a player makes. The odds are set for about one cast every
3 seconds of play.

**Agencies are the casting price ladder.** Open Casting $10, Talent Agency $1,000 (Fame 1,400),
Hollywood Casting $100,000 (Fame 50,000). Better agencies remove common tiers, so they are much
luckier per cast. The price keeps each one limited by cash for a few days after it opens.

**Scripts earn slightly less per second the longer they are.** Short $15 / base 12 (2 min), Indie
$60 / 55 (10 min), Feature $250 / 220 (45 min), Epic $900 / 780 (3 h). So Shorts with clapping are
best while playing, and Features and Epics are for time away. Before, Epics were 2.6 times more
efficient per second, so clapping through an Epic beat everything.

**Clapperboard** starts at 2 seconds per tap and adds 0.5 seconds per level (max 4, was 6), so
tapping speeds filming up without replacing the timer.

**Cinema royalties** are 0.001% of each movie's payout per second (was 0.05%), plus a $0.50/s
base. At the old rate the cinema out-earned the movies themselves, and offline income dwarfed
everything else. Now it is under 5% of income on day one and about two thirds by day 7. Cash rewards
that say "N minutes of box office income" use this rate.

**Fame** is still about the square root of each payout. Its gates were set from the sim's Fame
curve to land each unlock at the time above: Horror and Romance 100, Feature 1,800, Sci-Fi 2,000,
Talent Agency 1,400, Epic 16,000, Hollywood 50,000, stages 50 / 2,800 / 16,000.

**Upgrade prices** grow 4 to 8 times per level. Other upgrade levels no longer have Fame gates;
cash alone sets their pace.

**Masterpiece is 1 in 400** (was 1 in 200). Players premiere about 100 movies on day one, so 1 in
200 made it a day-one event and the server-wide announcement would fire every few minutes.

**Rebirths are the long-term Cash sink.** A rebirth costs Cash ($250,000 for the first, then 6
times more each time: $1.5M, $9M, $54M, $324M...) and resets Cash and every upgrade, sound stages
included. Actors, the Index, Fame, scripts, the cinema's movies, films still filming and Robux
purchases are kept, and the box office waiting at the gold pad comes along as starting Cash. Each
rebirth adds x0.5 to every premiere's Cash (x1.5, x2, x2.5...) and +0.1 Luck, forever. Because
the cinema keeps the boosted payouts, the box office grows with the multiplier too.
- The bonus multiplies Cash, not Fame, so Fame unlocks (Epic, Hollywood Casting) stay on the curve
  above. Rebirths only cost a few minutes on them while the stages are bought back.
- The price grows 6 times per rebirth while the bonus grows by a fixed x0.5, so each rebirth takes
  longer than the last: about two days apart in week one, a week apart by week three. At 3 times
  per rebirth (tried first) players did five rebirths in week one and income ran away.
- The first one at $250,000 lands early on day 2, after the first night's box office, so day one
  shows the Rebirth chip filling up and gives a reason to come back.
- There are 12 rebirths (the last costs about $90 trillion); prices stay under 10^14, which Roblox
  still prints as plain digits.

**Cash packs.** Box Office Bag's minimum went from $1,000 to $5,000 and the Vault's from
$10,000 to $50,000. The minimums are what early players get. $1,000 was under a minute of
income on day one, which is a poor buy for Robux. Daily rewards, requests and codes were left as
they are; they come to about 1 to 5% of a week's cash, enough to feel good without skipping
progression.

**Achievements are one-time and small.** The 40 goals in `src/shared/Achievements.luau` give a
little Cash, a few Skips, scripts, or a short x2 Luck boost. Rewards for the first goals (10
casts, the first premiere, 5 Index slots) are kept tiny, because the first minutes are where
extra Cash shows most: an earlier draft with $200 to $300 floors moved Sound stage 2 from minute
8 to minute 4. With the shipped list, a typical player's milestones move by a minute or two on
day one (first Star around minute 18 instead of 21) and not at all later in the week. Casual
players get their first Superstar about a day sooner, mostly from the Luck boosts.

## Special events

Every 15 minutes one of five special events runs for 90 to 120 seconds, in every server at the
same moment (`src/shared/SpecialEvents.luau`): Lucky Star (x2 casting Luck for everyone), Cash
Rain (16 coins round town, each worth the most of $25, a tenth of the player's Fame, or 20
seconds of cinema income; Fame stands in for progress because most income comes from premieres),
Mystery Crate (a free cast at the best unlocked agency with x3 Luck), Spotlight (a 5-minute
Lucky Casting boost for visiting one player's studio) and Golden Hour (films shoot twice as fast).
Nothing about them is sold, and every player on a server gets the same chance.

The sim's player takes part in every event it is online for: half the Cash Rain coins, the crate,
the Spotlight visit. Compared with the same week with events switched off (`--no-events`), the
typical player reaches most milestones a few minutes of play sooner, and a hardcore player about
4% sooner (Hollywood Casting at 329 instead of 342 minutes played). Event cash is about 1% of a
first session's earnings and under half a percent of a week's, the rebirth ladder does not move,
and the chance of a Legend or Icon in week one moves no more than run-to-run noise. They are there
to make the town feel alive and to give a reason to stay a few more minutes, not to change the
pace.

## What to watch in playtests

- Cast rate. If real players cast much faster than one every 3 seconds (auto-clickers),
  Superstar and Legend come sooner. The first fix would be rarer odds, not higher prices.
- Holding finished Epics for Award Night doubles them. The sim's player does this when an Award
  Night falls inside the session, which slows Fame slightly.
- Rebirth timing. The sim's player stops buying upgrades once a rebirth is within about 20 minutes
  of income, and rebirths the moment it can. Real players will keep spending, so their rebirths
  may come later. Casual players who rebirth on day 3 pull slightly fewer Legends in week one (12
  to 20% against 18%), because the Cash goes back into upgrades. If early rebirths feel bad in
  playtests, the first fix would be a Fame gate on the first one (around 3,500, about minute 55).
- Special events: if they feel rare, `SpecialEvents.SlotSeconds` can drop to 10 minutes; if Cash
  Rain coins are all grabbed in seconds, spread `CoinSpots` further. A crowded server shares one
  crate and one Spotlight studio, but every player gets their own pickup.
