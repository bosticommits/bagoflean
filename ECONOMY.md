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
    python3 tools/economy_sim.py --no-weekly         # the same week without weekly quest rewards
    python3 tools/economy_sim.py --weekly-day 1      # weekly quests all finished on day one (worst case)
    python3 tools/economy_sim.py --cast-rate 1.0     # casts per second while online (default 0.35); 1.0 = the server cap, 1 / CastCooldown
    python3 tools/economy_sim.py --no-hot-start      # a new player without the "Discovered!" guarantees

The sim includes Award Night, special events, daily rewards, Studio Requests, weekly quests, achievements, codes, the "don't leave yet" gift,
Lucky Casting boosts, Skip tokens and rebirths (its player saves for a rebirth once it costs less
than about 20 minutes of income, and rebirths as soon as it can afford one). It does not model game passes other than 2x Luck, or
Robux cash packs. Treat it as the shape of the curve, not a promise: playtests decide.

## The curve in plain words

- **First session (about 20 minutes).** The "Discovered!" hot start guarantees a Rising on the 3rd
  cast, a Pro on the 10th and a purple **Star** on the 25th, so the first Star lands around minute
  7 (4 to 9). A second sound stage and the Horror and Romance scripts unlock around minute 6.
- **Day one (about an hour).** The **Talent Agency** opens around minute 30, and the premiere
  that unlocks it says so. Feature scripts and Sci-Fi follow by minute 40. Talent Agency casts
  are where spare Cash goes for the rest of the hour, so the third sound stage comes at the start
  of day 2.
- **Days 2 to 3.** The overnight box office pays for the **first rebirth** early on day 2
  (Movie Cash x1.5). The first **Superstar** comes early on day 2, the first **Masterpiece** on
  day 2 or 3. **Epic** scripts and the **second rebirth** come on day 3, and the fourth stage
  late on day 3.
- **Days 4 to 7.** The **third rebirth** comes on day 4 and every upgrade is maxed again on day 5.
  **Hollywood Casting** opens on day 6. About two thirds of players pull a **Legend** in week one.
  **Icon** stays a rare brag (about 1 in 17 players in week one). About 38 of the 63 Index slots
  are found in week one.
- **Weeks 2 to 4.** Rebirths keep coming, each further apart: the fourth on day 6 or 7, the fifth
  on day 10, the sixth on day 17, the seventh in week five. The Legend row of the Index is done
  around day 13, and about half of players have an Icon by day 28.

How you earn changes over the week. Early on, active play (Short Films plus clapping) is most of
the income. By the end of the week, about three quarters comes from time away: overnight Epics
and the cinema's royalties. Logging in to premiere and cast is the core habit, and an active
session is mostly spent casting.

## Milestones (typical player: 60 minutes on day one, then three 15-minute visits a day)

Median time, from 300 runs. "Slow 10%" is the unlucky end. Rebirths reset upgrades, so "Sound
stage 4" and "maxed" mean the first time.

| Milestone | Median | Slow 10% |
|---|---|---|
| First Pro actor | day 1, 3 min played | 5 min |
| Horror and Romance scripts | day 1, 6 min | 7 min |
| Sound stage 2 | day 1, 6 min | 8 min |
| First Star actor | day 1, 7 min | 9 min |
| Talent Agency | day 1, 28 min | 31 min |
| Feature scripts | day 1, 35 min | 37 min |
| Sci-Fi scripts | day 1, 37 min | 43 min |
| Sound stage 3 | day 2 (60 min) | day 2 (60 min) |
| First Superstar | day 2 (66 min) | day 3 (139 min) |
| **Rebirth 1** (Movie Cash x1.5) | day 2 (75 min) | day 2 (101 min) |
| First Masterpiece | day 2 (100 min) | day 6 |
| Epic scripts | day 3 (106 min) | day 3 (120 min) |
| **Rebirth 2** (x2) | day 3 (120 min) | day 3 (146 min) |
| Sound stage 4 | day 3 (142 min) | day 4 |
| Cinema, Offline, Clapperboard maxed | day 4 | day 4 |
| **Rebirth 3** (x2.5) | day 4 (165 min) | day 5 |
| All upgrades maxed | day 5 (210 min) | day 6 |
| Hollywood Casting | day 6 (243 min) | day 6 (270 min) |
| First Legend | day 6 (64% of players in week one) | |
| First Icon | 6% of players in week one | |
| **Rebirth 4** (x3) | day 6 (75% in week one) | day 9 |
| **Rebirth 5** (x3.5) | day 10 | day 12 |
| **Rebirth 6** (x4) | day 17 | day 19 |

Other players:
- **Casual** (25 min on day one, then 20 min a day): Talent Agency on day 2 (30 min played),
  the first rebirth and first Superstar on day 3, Epic scripts and the second rebirth on day 5,
  the third rebirth on day 7 (70%). Legend 8% and Icon under 1% in week one; Legend on day 13
  (99% by day 28).
- **Hardcore** (about 2 hours a day): Talent Agency at 30 minutes, the first rebirth and Epic
  scripts on day 1, the second rebirth on day 2, Hollywood on day 3, a Legend on day 4 (95% in
  week one), Icon 17% in week one.
- **2x Luck pass** (typical schedule): Talent Agency at 27 minutes, Superstar at 46 minutes,
  first rebirth at 60, Hollywood on day 5, Legend 96% and Icon 12% in week one, and about 1.8
  times the income at the end of the week. Faster, but nothing a free player cannot reach.

## Economy fixes (2026-10-15)

From the review in `ECONOMY_SUMMARY.md` (project files, 2026-10-12). Numbers are sim estimates.

- **Luck works at every agency.** Agencies used to remove their bottom tiers after Luck was
  applied, and Luck mostly turned Newcomers into Risings, which the Talent Agency removes anyway:
  going from Luck 2 to 4 moved its Legend odds by 5% and Hollywood's by under 1%, so the Luck
  upgrade, Lucky Casting, Award Night and the 2x Luck pass did almost nothing to rare pulls once
  a player left Open Casting. `Actors.tierChances` now applies Luck to the agency's own pool, so
  Luck x2 halves every "1 in N" at every agency. Open Casting is unchanged.
- **Rare odds retuned to match.** Luck now counts at the agencies, so with the old odds a typical
  player pulled a Legend 99% of the time in week one, an Icon 32% of the time, and earned twice as
  much. Star 1 in 500 to 700, Superstar 5,000 to 8,000, Legend 60,000 to 220,000, Icon 1,000,000
  to 5,000,000 put the typical week back on the curve: first Superstar at 66 minutes (was 60),
  Legend 64% (was 69%), Icon 6% (was 5%). Week-one income ends about 118,000 a minute (was 92,000),
  partly from the earlier Epics below. Players with more Luck now gain more: casual players get
  fewer Legends in week one (8%, was 17%) but nearly all of them have one by day 28, and the 2x Luck
  pass gives 96% instead of 76%.
- **Epic scripts at Fame 10,000 (was 16,000).** Casual players had a quiet day 4 and 5: nothing
  new between the first rebirth (day 3) and the second (day 6), with Epics on day 7. Epics now
  come on day 5 for casual players and at 106 minutes (day 3) for typical ones, and casual players
  reach the third rebirth in week one 70% of the time (was 22%).
- **Flop never drops below 5%** (`Movies.MinFlop`). Premiere Luck took its extra good results out of
  Flop first, so from Luck 2 (day 3) Flops vanished. Luck now takes Flop down to 5%, then takes from
  Hit.
- **"Discover all 21 actors"** replaces "Complete the whole Index" (achievement `Index5`, new stat
  `actors`). All 63 slots included an Award-Winning Icon, tens of millions of casts even at
  Hollywood Casting, so nobody could earn it.
- **Casting speed.** `Config.CastCooldown` is 1.0 s (from the `economy-safety` branch), so
  scripted clients cannot cast faster than a person can (see "What to watch in playtests").
- **Unlock analytics.** Each Fame unlock a premiere crosses logs a custom "Unlock" event with the
  unlock's name and the player's premiere count, so real timings can be checked against the table
  above.
- **Left as it is:** time away earns about 72% of a typical player's Cash by day 7. That is the
  design (it drives log-ins); `Config.RoyaltyRate` is the lever if playtests say late-week active
  play feels weak.

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

**Odds are rarer at the top** (Star 1 in 700, Superstar 1 in 8,000, Legend 1 in 220,000, Icon
1 in 5,000,000, at Luck 1 at Open Casting). Casting soon costs almost nothing compared with income, so how fast rare actors
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
Talent Agency 1,400, Epic 10,000, Hollywood 50,000, stages 50 / 2,800 / 16,000.

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

**Weekly quests are a small weekly top-up.** Each week brings three (`Rewards.Weekly`), worth 20 to
60 minutes of income, a short Luck boost, a Skip or two, or a couple of scripts each. Their Cash
floors are $100 to $300 (the second sound stage costs $600): a first draft with $600 to $2,000
floors would have let a new player pay for early upgrades just by casting 60 times or buying 8
scripts, so a Lune test now keeps every weekly floor at half the first sound stage or less. The sim
has the player finish all three ten minutes into a session (`--no-weekly` leaves them out,
`--weekly-day N` picks the day). Finishing on day 4: a typical player's first week ends with about
4% more Cash per minute (about 92k against 88k) and the milestones do not move. The worst case,
finishing all three in the very first session (`--weekly-day 1`), moves the typical player's day-one
milestones a few minutes sooner (first Star 17 to 14 minutes, Sound stage 3 49 to 47, Talent Agency
54 to 53, the first rebirth 75 to 71; measured before the Talent Agency's Fame gate dropped to 1,400) and week one ends 2% richer. The cut floors barely change that
(the first draft gave 14, 47, 52 and 70): most of the early effect is the Luck boost and Skips, not
Cash. Real players will finish fewer, so these are the upper end. They cannot change the odds of rare actors.

**The "Discovered!" hot start (2026-10-15).** Before it, a new player's best pull in the first 10
minutes was a Pro and the first Star came around minute 17 (slow 10%: minute 30). Now a brand-new
account's casts carry guarantees (`Actors.HotStart`): at least a Rising on cast 3, a Pro on cast 10
and a Star on cast 25, with a bar over the Cast button counting down. A luckier roll keeps its
better tier, and crate casts count too. It is one saved counter (`hotStart`, save version 9);
profiles from before it count as done, and after cast 25 nothing changes. Cast 25 was picked from
the sim: the typical player makes their 25th cast around minute 6 to 7. Sim, typical player, 300
runs, with against without: first Star 7 against 17 minutes (slow 10%: 9 against 30), first Pro 3
against 4, Talent Agency 28 against 30, the first rebirth unchanged at 75 minutes, and week one
ends within 1% on Cash per minute. Casual players: first Star 7 against 15 minutes, week one ends
about 4% richer on Cash per minute (the early Star's films pay a bit more all day one). Compare
with `--no-hot-start`. No price, odds or payout changed.

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

## Directing takes (premiere Luck while filming)

While a movie films, a TAKE! card pops up at each quarter of the shoot (`src/shared/Takes.luau`,
3 per film). A Good take adds +0.04 Luck to that film's premiere and a Perfect one +0.08, capped at
+0.24 per film. Takes only open while the film is still shooting and after the tutorial, so offline
films and offline income are unchanged, and casting Luck is never touched. At Luck 1 three perfect
takes lift the average premiere from x1.57 to about x1.76 (a test keeps the best case under +15%).

The sim's player plays every card with a so-so aim (25% Perfect, 45% Good, 30% Miss, about +0.13
Luck a film; `TAKE_SKILL`) and `--no-takes` turns them off. Over 150 typical, 150 casual and 100
hardcore runs the milestones and week-one income land within run-to-run noise of the same week
without takes (for example first Superstar 71 against 61 minutes and first Masterpiece 99 against
118 for the typical player, rebirth 1 at 75 minutes either way, week-one Fame 72.0 against 71.9 for
the casual player). The takes are there to give the 2-minute wait something to do, not to change
the pace.

## Mascot buffs

Each studio mascot gives one small buff, and only the one a player has out counts
(`src/shared/Mascots.luau`): Popcorn Pup +5% movie Cash, Clapper Croc films 10% faster, Reel Kitty
x1.1 casting Luck, Camera Bot +15% box office, Spotlight Owl x1.2 casting Luck and Premiere Dragon
+20% movie Cash. Every kind has a hard cap (`Mascots.Caps`: Cash +20%, Luck x1.2, filming 10%,
box office +15%) that tests keep under the Robux pass doing the same job (x2 Luck, 25% faster
filming). Cash is added after Fame is worked out, like the rebirth bonus, so Fame unlocks do not
move. Rewards paid as "minutes of box office" follow the boosted rate, as the screens show it. A
buff only works 30 seconds after equipping, so swapping mascots
between casting and premiering cannot collect two buffs; mascots are earned, never sold.

The sim's `--mascots` option keeps the strongest earned mascot of one kind out (the pup until
then). Typical player, 150 runs, end of week one: no buffs $96,562/min, Cash mascots
$112,093 (+16%), box office $100,778 (+4%), Luck and speed within run-to-run noise ($95,386 and
$94,649). Rebirth 1 stays on day 2 at 75 minutes and Legend in week one stays at 65 to 69% in
every setup. If every cap applied at once (what stacking would do; simulated on the retuned odds
of PR #43) a typical player would earn
about 64% more, which is why only one mascot counts.

## What to watch in playtests

- Casting speed (checked 2026-10-10, typical player, 30 runs each). Faster casting moves the whole
  curve: at 1.67 casts a second (the old 0.6 s server cap) 100% of players pulled a Legend in week one
  (median day 3) and week-one income was about 156,000 a minute, against 70% (day 5) and about
  82,000 at the assumed 0.35. At 1.0 a second: 93%, day 4, about 131,000. The reveal screen takes about
  a second per cast by hand, so `CastCooldown` is now 1.0 s: it only limits scripted clients. Rarer
  Superstar and Legend odds were tried instead (Superstar 1 in 8,000 and Legend 1 in 100,000: Legend 40%
  and week-one income about 74,000 at 0.35 casts a second, and the first Superstar slips from minute 50
  to 85). They fix fast casters but slow the typical player off the milestones above, so they were not
  applied. Revisit them if real players cast much faster than 0.35 a second.
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
