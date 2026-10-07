# Hollywood RNG economy

This is the progression curve the numbers in `src/shared/` are tuned to, and how to check it.
Every number below comes from `tools/economy_sim.py`, which reads the Luau files directly and
plays a simple, sensible player through a week. Run it after changing any price, payout or odds:

    python3 tools/economy_sim.py                    # typical player, 300 runs
    python3 tools/economy_sim.py --player casual     # also: hardcore
    python3 tools/economy_sim.py --luck-pass         # owns the 2x Luck pass
    python3 tools/economy_sim.py --no-events         # the same week without special events

The sim includes Award Night, special events, daily rewards, Studio Requests, codes, the "don't
leave yet" gift, Lucky Casting boosts and Skip tokens. It does not model game passes other than 2x Luck, or
Robux cash packs. Treat it as the shape of the curve, not a promise: playtests decide.

## The curve in plain words

- **First session (about 20 minutes).** The first casts already give a Rising and usually a Pro
  actor. A second sound stage and the Horror and Romance scripts unlock around minute 8. Most
  players see their first purple **Star** actor around minute 20.
- **Day one (about an hour).** Feature scripts and Sci-Fi unlock around minute 40, a third stage
  around minute 50, and the **Talent Agency** opens near the end of the hour.
- **Days 2 to 3.** The first **Superstar** and the first **Masterpiece** arrive on day 2. **Epic**
  scripts and the fourth stage unlock on day 3, which makes the overnight movie worth a lot more.
- **Days 4 to 7.** Cinema, Offline and Clapperboard upgrades max out on day 4. **Hollywood
  Casting** opens on day 6. About half of players pull a **Legend** in week one. **Icon** stays a
  rare brag (about 1 in 20 players in week one). The last Luck upgrades and most of the Index
  (about 35 of 63 slots) are left for week two.

How you earn changes over the week. Early on, active play (Short Films plus clapping) is most of
the income. By the end of the week, about three quarters comes from time away: overnight Epics
and the cinema's royalties. Logging in to premiere and cast is the core habit, and an active
session is mostly spent casting.

## Milestones (typical player: 60 minutes on day one, then three 15-minute visits a day)

Median time, from 100 runs. "Slow 10%" is the unlucky end.

| Milestone | Median | Slow 10% |
|---|---|---|
| Sound stage 2 | day 1, 8 min played | 10 min |
| Horror and Romance scripts | day 1, 7 min | 9 min |
| First Star actor | day 1, 19 min | 29 min |
| Feature scripts | day 1, 37 min | 40 min |
| Sci-Fi scripts | day 1, 39 min | 44 min |
| Sound stage 3 | day 1, 49 min | 55 min |
| Talent Agency | day 1, 55 min | day 2 |
| First Superstar | day 2 (70 min) | day 3 |
| First Masterpiece | day 2 (82 min) | day 6 |
| Epic scripts | day 3 (142 min) | day 4 |
| Sound stage 4 | day 3 (147 min) | day 4 |
| Cinema, Offline, Clapperboard maxed | day 4 | day 5 |
| First Legend | day 5 (about 60% of players in week one) | |
| Hollywood Casting | day 6 (258 min) | day 7 |
| All upgrades maxed | day 6 (65% in week one) | |
| First Icon | 3 to 6% of players in week one (it varies from run to run) | |

Other players:
- **Casual** (25 min on day one, then 20 min a day): Talent Agency on day 3, first Superstar on
  day 4, Epic scripts on day 7. Legend 23%, Icon 1% in week one.
- **Hardcore** (about 2 hours a day): Talent Agency in the first hour, Hollywood on day 3, Legend
  on day 4 (88%), Icon 7% in week one, all upgrades maxed on day 6.
- **2x Luck pass** (typical schedule): Star at 15 min, Superstar in the first hour, Legend 64%,
  Icon 5%. Faster, but nothing a free player cannot reach.

## The levers and why they are set this way

**Star Power grows about 2.5 times per tier** (1, 3, 8, 20, 50, 120, 300). It used to grow 4 to 8
times per tier (up to 20,000), so every rare pull multiplied income, which bought more pulls. In
the old numbers a player had every upgrade maxed after 35 minutes and earned 270 million a minute
by day 7.

**Odds are rarer at the top** (Star 1 in 500, Superstar 1 in 5,000, Legend 1 in 60,000, Icon
1 in 1,000,000). Casting soon costs almost nothing compared with income, so how fast rare actors
arrive depends on how many casts a player makes. The odds are set for about one cast every
3 seconds of play.

**Agencies are the casting price ladder.** Open Casting $10, Talent Agency $1,000 (Fame 3,500),
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
Talent Agency 3,500, Epic 16,000, Hollywood 50,000, stages 50 / 2,800 / 16,000.

**Upgrade prices** grow 4 to 8 times per level. Other upgrade levels no longer have Fame gates;
cash alone sets their pace.

**Masterpiece is 1 in 400** (was 1 in 200). Players premiere about 100 movies on day one, so 1 in
200 made it a day-one event and the server-wide announcement would fire every few minutes.

**Cash packs.** Box Office Bag's minimum went from $1,000 to $5,000 and the Vault's from
$10,000 to $50,000. The minimums are what early players get. $1,000 was under a minute of
income on day one, which is a poor buy for Robux. Daily rewards, requests and codes were left as
they are; they come to about 1 to 5% of a week's cash, enough to feel good without skipping
progression.

## Special events

Every 15 minutes one of five special events runs for 90 to 120 seconds, in every server at the
same moment (`src/shared/SpecialEvents.luau`): Lucky Star (x2 casting Luck for everyone), Cash
Rain (16 coins round town, each worth $15 or 15 seconds of cinema income, whichever is more),
Mystery Crate (a free cast at the best unlocked agency with x3 Luck), Spotlight (a 5-minute
Lucky Casting boost for visiting one player's studio) and Golden Hour (films shoot twice as fast).
Nothing about them is sold, and every player on a server gets the same chance.

The sim's player takes part in every event it is online for: half the Cash Rain coins, the
crate, the Spotlight visit. Compared with the same week with events switched off
(`--no-events`), the typical player reaches each milestone 1 to 3 minutes of play sooner, and a
hardcore player about 5% sooner (Hollywood Casting at 335 instead of 354 minutes played). Event
cash is about 0.1% of a week's earnings, and the chance of a Legend or Icon in week one moves no
more than run-to-run noise. They are there to make the town feel alive and to give a reason to
stay a few more minutes, not to change the pace.

## What to watch in playtests

- Cast rate. If real players cast much faster than one every 3 seconds (auto-clickers),
  Superstar and Legend come sooner. The first fix would be rarer odds, not higher prices.
- Holding finished Epics for Award Night doubles them. The sim's player does this when an Award
  Night falls inside the session, which slows Fame slightly.
- Special events: if they feel rare, `SpecialEvents.SlotSeconds` can drop to 10 minutes; if Cash
  Rain coins are all grabbed in seconds, spread `CoinSpots` further. A crowded server shares one
  crate and one Spotlight studio, but every player gets their own pickup.
- After week one income keeps growing slowly. The Sequel (rebirth) in M7 is the planned long-term
  sink.
