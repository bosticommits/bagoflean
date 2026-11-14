# Actors v2: 21 → 30 everyday actors + polish pass

Status: design, 2026-11-14. Ships before the Nov 18 soft launch (user decision 2026-11-14).
No code in this PR. Builds on `src/shared/Actors.luau`, `art/blender/actors.py`,
`ECONOMY.md` and the vault's `Movie Mogul/UI Taste Rules.md` + `Actor References.md`.

**The idea (UI Taste Rules §1):** on the Index, every actor you have not found is a **black
silhouette on a poster wall**, so the silhouette itself is the teaser. Nine new actors with nine
shapes the cast doesn't have yet (very tall, very wide, floating, winged, animal costume, huge prop,
tiny-on-a-mount) make that wall worth staring at. The one live thing stays the same: the black
shape turns into the figure the moment you find it. No new screen, so no Figma storyboard: the
visual work is 3D figures, reviewed as Blender renders (drafts, 64 px silhouette strip, 5×6 sheet)
on the Command Center.

User decisions (2026-11-14): 9 new everyday actors (21 → 30), only the 5 existing genres, the same
chunky figurine style but polished, all of it before Nov 18.

---

## 1. The 9 new actors

All original, kid-friendly, no real people and no copyrighted characters. Ids are new strings, so
nothing old changes (see section 3). Each fills a silhouette slot the cast lacks and a genre gap in
its tier.

| # | id | Name | Tier | Genre | Personality (one line) | Hero element (≥25% head width, breaks the outline) | Silhouette slot | Colours (4–6) | Body template |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `WerewolfPup` | Werewolf Pup | Newcomer | Horror | A shy understudy in a too-big wolf onesie who howls, then says sorry. | Wolf hood with two tall pointed ears + a floppy tail | Animal costume | fur grey `#8A8F99`, belly cream `#F4E7CF`, paw pink `#F08A8A`, sneaker red `#D83A3A` | Kid |
| 2 | `CardboardAstronaut` | Cardboard Astronaut | Newcomer | Sci-Fi | Built a spacesuit out of a fridge box and is sure today is launch day. | Huge box body + box helmet with a drawn-on visor and a whisk antenna | Very wide | cardboard `#C9A86A`, foil `#BFC6D6`, marker blue `#2E86DE`, tape `#F4E7CF` | Kid (box torso) |
| 3 | `RodeoRookie` | Rodeo Rookie | Rising | Action | Has never ridden a real horse but twirls a lasso like a champion. | Wide-brim hat (≈1.6× head width) + a lasso loop spun over the head | Huge prop (loop) | hat caramel `#B9773C`, bandana red `#D83A3A`, denim `#3A6EA5`, boots `#7A5434`, rope `#E8D29A` | Kid |
| 4 | `WobblyWitch` | Wobbly Witch | Rising | Horror | A trainee witch whose spells only ever make bubbles. | Towering crooked hat (bent tip) + a broom taller than she is | Very tall | plum `#6B3FA0`, lime `#9BE564`, bubble cyan `#7FE3FF` (small emissive), straw `#E8C15A`, skin | Lanky |
| 5 | `LagoonMermaid` | Lagoon Mermaid | Pro | Romance | Sings love songs to every boat; nobody has told her it's a film set. | Big curled tail fin flicked up beside her + a seashell microphone; sits on a rock | No legs (S-curve tail) | tail coral `#FF7F6A`, fins lilac `#B79CFF`, hair navy `#2B3A67`, pearl `#FAF6EC`, rock `#6E7078` | Seated / no legs |
| 6 | `TimeTourist` | Time Tourist | Pro | Sci-Fi | Took a wrong turn in a time machine and rides home on a baby dinosaur, snapping photos. | Baby dino mount (original, round, spotted) + a chunky camera | Tiny on a mount | dino green `#54B860`, spots `#FFD84A`, shirt pink `#FF6FA8` + white flowers, shorts khaki `#C9A86A`, goggle cyan glow | Kid, seated |
| 7 | `CaptainKapow` | Captain Kapow | Star | Action | A big-hearted superhero who shouts her own sound effects. | Cape flared out to one side + raised fist holding a star-burst "pow" shape (no lettering, no S-style emblem) | Floating (hovers: `rig.float`) | suit red `#D83A3A`, cape cobalt `#2E5BDB`, emblem gold `#F5B82E`, mask/gloves white `#FAF6EC` | Hero |
| 8 | `InspectorWhoops` | Inspector Whoops | Star | Comedy | A detective who solves every case by accident. | Magnifying glass bigger than his head, held to one eye (a giant eye behind the lens) | Huge prop | trench tan `#C9A86A`, cap check `#7A5434`/`#F4E7CF`, brass `#F5B82E`, lens `#BFE9FF` | Lanky |
| 9 | `PirateCaptain` | Captain Squawk | Superstar | Comedy | A pirate captain who secretly takes orders from her enormous parrot. | Giant parrot on the shoulder, wings spread wider than she is + tricorn hat (Superstar 2nd silhouette extension) | Winged | coat navy `#1B2340`, trim gold `#F5B82E`, sash red `#D83A3A`, parrot green/red/yellow `#54B860` `#E8453C` `#FFD84A` | Hero |

Originality notes for the artist: the mermaid avoids the famous red-hair/green-tail/purple-shell
look; Captain Kapow uses a star-burst emblem, no letter emblem; the dino is a made-up round
baby, not a toy-line design; the witch has normal skin (not green). Check the names in a quick web
search before upload (Captain Kapow is a common phrase; rename if a well-known character owns it).

### Tier and genre counts, before → after

| Tier | Before (3 each) | Added | After | Genres after |
|---|---|---|---|---|
| Newcomer | C, A, R | H, S | 5 | all 5 |
| Rising | R, C, S | A, H | 5 | all 5 |
| Pro | A, C, H | R, S | 5 | all 5 |
| Star | R, H, S | A, C | 5 | all 5 |
| Superstar | A, H, R | C | 4 | A, H, R, C |
| Legend | R, C, S | none | 3 | unchanged |
| Icon | R, A, H | none | 3 | unchanged |

| Genre | Before | After |
|---|---|---|
| Action | 4 | 6 |
| Comedy | 4 | 6 |
| Horror | 4 | 6 |
| Romance | 6 | 7 |
| Sci-Fi | 3 | 5 |

Why this spread: every genre now has an actor in every tier a new player meets in the first hour
(Newcomer to Star), so any script genre can get a genre match early; the new faces land where
players actually roll (7 of 9 in the first-session tiers); Legend and Icon stay at 3 so the long
chase (and "Discover all actors") is no longer than today.

Insert each new row at the **end of its tier block** in `Actors.List` (not at the end of the
list). `TopStudios.rarest` breaks ties inside a tier by list position; this keeps the old order.

---

## 2. Economy and odds

Tier odds do not change (`Actors.Tiers.oneIn`). A tier's chance is split evenly between its
actors (`Actors.castOdds`, `PullNews.oneIn`), so per-actor odds move only in tiers that grow. The
odds panel, reveal card and pull news read the count live, so what is shown stays what is rolled
(paid-random-items rule: odds shown before purchase, live).

### Per-actor odds at Open Casting, Luck 1

| Tier | Tier odds | Each actor now | Each actor after |
|---|---|---|---|
| Newcomer | ~1 in 1.2 | 1 in 4 | 1 in 6 |
| Rising | 1 in 6 | 1 in 18 | 1 in 31 |
| Pro | 1 in 40 | 1 in 120 | 1 in 200 |
| Star | 1 in 700 | 1 in 2,100 | 1 in 3,500 |
| Superstar | 1 in 8,000 | 1 in 24,000 | 1 in 32,000 |
| Legend | 1 in 220,000 | 1 in 660,000 | unchanged |
| Icon | 1 in 5,000,000 | 1 in 15,000,000 | unchanged |

Expected casts to finish a tier row at Open Casting, Luck 1 (coupon collector): Newcomer 7 → 14,
Rising 34 → 70, Pro 220 → 457, Star 3,850 → 8,000, Superstar 44,000 → 67,000; Legend and Icon
unchanged. Real players switch agencies and gain Luck, so read the sim below for times.

### Sim results (`tools/economy_sim.py`, seed 7)

Run on a scratch copy with the 30-actor list; the sim reads `Actors.List`, so no sim code change is
needed for the odds. Only its Index milestone labels (`Index n/63`) are hard-coded.

Typical player, 100 runs, 14 days (`--days 14`). "Now" = 21 actors, "Rec." = the spread above
(5/5/5/5/4/3/3), "Alt." = 6/6/6/3/3/3/3 (Q1 b). Median times.

| Milestone | Now | Rec. | Alt. |
|---|---|---|---|
| Newcomer row done | day 1, 3 min | day 1, 3 min | day 1, 4 min |
| Rising row done | day 1, 4 min | day 1, 8 min | day 1, 10 min |
| Pro row done | day 1, 11 min | day 1, 17 min | day 1, 19 min |
| First Star / first Superstar | 6 / 12 min | 5 / 12 min | 6 / 12 min |
| Star row done | day 1, 31 min | **day 2, 65 min** | day 1, 33 min |
| Superstar row done | day 3, 116 min | **day 4, 168 min** | day 3, 115 min |
| Legend row done | day 11 (64% by day 14) | day 10 (67%) | day 10 (55%) |
| Every actor but the Icons | day 11 (69%) | day 10 (73%) | day 10 (57%) |
| First Icon by day 14 | 17% | 18% | 15% |
| Index slots found, end of week 1 | 39 / 63 (62%) | 59 / 90 (66%) | 62 / 90 (69%) |
| Index slots found, end of week 2 | 44 / 63 | 67 / 90 | 67 / 90 |
| Cash/min, end of week 1 | 140.9k | 138.1k (-2%, noise) | 142.9k |
| Cash/min, end of week 2 | 341.6k | 343.8k | 330.0k |
| Rebirths 1 / 3 | day 2 / day 4 | day 2 / day 4 | day 2 / day 4 |

Casual player (100 runs, 7 days): Index slots end of week 1 32/63 → 48/90; Star row day 2 → day 3;
Superstar row done in week one by 82% → 42% of players; Cash within 4%.
Seasonal week (`--season FrightNight`, 60 runs): the limited Star actor is still found by 100% of
players on day 1, at minute 45 instead of 27; week-1 Cash 141.0k → 142.6k.

**Reading it:** the economy (Cash, Fame, rebirths, agencies) doesn't move. What moves is the
collection: about 20 more Index slots found in week one, the Star row takes one more day and the
Superstar row one more day, which is the "new faces early, more to chase mid-game" we want. The
long tail (Legend row, all-but-Icons, first Icon) is unchanged within noise.

### Recommended numbers

- **Tier odds:** unchanged.
- **Hot start, pity, first Superstar:** unchanged (they guarantee a tier, not an actor).
- **Festival limited actors:** keep the rule "as often as one everyday actor of its tier"
  (`Actors.limitedChance`). With 5 Stars that is 1 in 3,500 in season (was 1 in 2,100). It still
  takes nothing from other actors, and winning the festival still gives a copy. (Alternative in Q2.)
- **Best cast:** unchanged. The only new high-power actor is one Superstar (starPower 50); the
  sim's best-cast logic and `Movies.actorPower` need nothing.
- **Genre match:** `Movies.SpecialtyBonus` unchanged. Every genre in tiers 1–4 means more early
  matches; the sim shows the effect is within noise on Cash (see table).
- **Genre and tier Index rewards** (`Config.GenreBonus`, `Config.TierRewardLuck`): unchanged. A
  genre's reward still depends on its rarest member (Legend/Icon), which did not change.
- **Index achievements, 63 → 90 slots** (`src/shared/Achievements.luau:57-61`):

| id | Now | After | Why |
|---|---|---|---|
| Index1 | 5 slots | 5 | first minutes, keep |
| Index2 | 15 | 20 | lands in the first ~15 min, like 15 today |
| Index3 | 30 | 45 | sim: day 3 (116 min), same day as today's 30 (day 3, 107 min) |
| Index4 | 45 | 65 | stretch into week 2 like today's 45 (35% by day 14); sim median is 67 slots at day 14, 60 at day 8 |
| Index5 | all 21 actors | `#Actors.List` (30) | text built from the count so it can't drift again |

  Texts: Index1–4 say "Fill N Index slots" (today "Discover 30 actors in the Index" would sit next
  to "Discover all 30 actors" and read as the same goal). Index5: `` `Discover all {#Actors.List} actors` ``.

### Every place that says 21 / 63 / 3-per-tier

| File:line | Now | Change |
|---|---|---|
| `src/shared/Achievements.luau:58-60` | Index2-4 targets 15/30/45, "Discover N actors in the Index" | 20/45/65, "Fill N Index slots" |
| `src/shared/Achievements.luau:61` | `target = 21`, "Discover all 21 actors" | `target = #Actors.List`, text from the count |
| `src/shared/Models/ActorModels.luau:2` | "The 21 castable actors" | "The castable actors" (no number) |
| `tests/luau/actors.spec.luau:13-17` | every tier has 3, IndexSlots 63 | per-tier table {5,5,5,5,4,3,3}, IndexSlots 90 |
| `tests/luau/limited.spec.luau:67` | `equal(#actorsInTier(limited.tier), 3)` | compare with the count before the season, not 3 |
| `tests/luau/achievements.spec.luau:83` | comment "all 63 slots" | "every slot" |
| `tools/economy_sim.py:996-997` | marks `Index n/63` at 21/32/42/63 | marks at the achievement targets (20/45/65/90), label `/{IndexSlots}` |
| `art/blender/actors.py:1, 17, 1122-1145` | "The 21 castable actors", sheet "three rows of seven" | no number; sheet 5 rows of 6 |
| `art/README.md:16` | "The 21 actors" | "The 30 actors" |
| `art/README.md:143` | "101 meshes" | the new count printed by the export |
| `ECONOMY.md:53, 132-133` | "38 of the 63 Index slots", "Discover all 21 actors", "63 slots" | new numbers + a short "Actors v2" note |
| `STORE_LISTING.md:50` | "discover 21 original actors" | "discover 30 original actors" |
| `LAUNCH_CHECKLIST.md:49-51` | "all 21 actors", "63 Index slots" | 30 / 90 |
| `GAME_PLAN.md:76, 144` | "Version 1 ships 21 actors (3 per tier)" | "30 actors (5/5/5/5/4/3/3)" |
| Creator Hub description (live) | same text as STORE_LISTING | user pastes the new line on publish day |
| Vault: `Movie Mogul/Economy.md` and any note quoting 21/63 | | via VAULT block |

Code that already reads the count and needs nothing: `Actors.IndexSlots`, `CastingUi`
(Index chip `x/90`, Collection header, tier rows from `actorsInTier`), `Upgrades.tierProgress` /
`genreProgress`, `PullNews.oneIn`, the odds panel ("Each actor in this tier"), `TopStudios`,
`LuckDetails`.

---

## 3. Save data: additive, no migration

Confirmed by reading the code:

- `roster`, `index`, `cast` are keyed by the string `"actorId:variantId"` (`DataService.luau:21, 43-44`).
- `pity` is keyed by agency id; `hotStart`, `early`, `played` are numbers (`DataService.luau:78-79, 226-235`).
- `rewards` (`"tier:<id>"`, `"genre:<name>"`) and `achievements` are keyed by id strings.
- `TopStudios.rarest` (top star pedestal, billboard portrait, Rare Wall) sorts by tier rank, variant
  rank, then list position *built at load* (`listOrder`); nothing saves a position.
- `ShowMe.TARGETS` points at UI controls only; no actor ids or indices.
- No `DataService` version bump; no repair step needed.

Behaviour for an existing save (soft-launch testers; launch day flips `Config.LaunchWipe` to the
fresh `PlayerData_v2` store anyway):

- A claimed tier/genre reward stays claimed and keeps its bonus, even though the row now shows
  e.g. 3/5. The row shows "(claimed)" whenever the flag is set (`CastingUi.luau:603`), so no
  second claim and no confusing button.
- A claimed Index5 stays claimed. An unclaimed 21/21 becomes 21/30.
- Achievement targets that drop below a player's progress simply become claimable.

Test to add: an old-shape save table (21-actor keys) loads, `tierProgress` reports 3/5, and claimed
rewards are not lost.

---

## 4. Polish spec for all 30

Rules from `Movie Mogul/Actor References.md` (taste research 2026-11-14) and `Art Style`. User
decisions: **no outline**, **escalate the silhouette from Superstar up**, **rework all 21**.

### Global pass (shared helpers in `actors.py`, so it lands on all 30 at once)

| Piece | Now | After |
|---|---|---|
| Head size | skull ~2.0 of ~5.1 studs (~39%) | skull+hair **45–55%** of figure height (hats and props not counted); grow the head, shorten legs/torso so the total stays ~5.0–5.4 |
| Head shape | faceted ball (10 seg) | rounded box with a **2-segment bevel, 6–8%** of head width; ball kept only where it is the character (Zombie, Alien, Brain) (Q4) |
| Eyes | 15% of head width, mid height | **18–22%** each, set low (centre ~45% up the head), dark `#161220`, one white specular dot |
| Brows | optional, thin | always; **thick and angled** to the personality |
| Mouth | ~22% of head width | **≥25%**, bold shape (smile, grin, nervous, evil, open "O") |
| Face detail | some bits tiny | faces as geometry; **nothing under 3%** of head width |
| Body bevels | mixed | **2-segment bevel, 4–5%** on torso, limbs, shoes |
| Body templates | one shared body | **≥3**: Kid (short, round), Hero (broad, `wide=1.25`), Lanky (long legs, slim) + "no legs" special (gown, tail, float, mount) |
| Hero element | most have one, some small | **one per actor, ≥25% of head width, breaking the outline** |
| Colour | flat face colours | **baked vertex-colour AO + warm rim** (bake in `mmkit`, multiply into the face colours); 4–6 colours per actor |
| Outline | none | none (decided) |
| Silhouette test | none | render every actor black at **64 px**; each must be told apart from all others |
| Tris | budget 2,500 (assert) | **700–1,800** per actor; Legend/Icon hero up to **2,500** (keep the assert, add a warning over 1,800 for tiers below Legend) |

### Rarity ladder (the figure escalates from Superstar)

| Tier | Figure | Plinth (2-step chamfered hex, **12–15% of figure height** ≈ 0.65–0.8 studs, was 0.45) |
|---|---|---|
| Newcomer | standard | grey `#A7A9AC`, plain |
| Rising | standard | green `#4CC764`, chamfered top |
| Pro | standard | blue `#3A8DFF`, rim stripe |
| Star | standard | purple `#A04DFF`, inlaid star |
| Superstar | **+ a second silhouette extension** (King: cape spread + crown; Scream Queen: hair flare + spotlight cone; Cupid: big wings; Squawk: parrot wings) | gold `#FFC21A`, bulb ring |
| Legend | + **gold/emissive accents** | orange `#FF5A2E`, **stepped** base, emissive trim |
| Icon | + **floating element + aura** | pink `#FF5FD2`, **unique base** per Icon |

### Per-actor notes for the 21 (from `art/previews/actors_blender.png`)

| Actor | Keep | Push |
|---|---|---|
| Nervous Intern | coffee-cup tower | taller wobblier tower; sweat drop as geometry ≥3% |
| Stunt Double | helmet | bigger crash helmet + arm cast in a sling; weak at 64 px today |
| Zombie Extra | green head | arms forward pose, holding a rose (its genre is Romance) |
| Soap Opera Star | curly hair | huge hair swoop + hand mirror as hero element |
| Hot Dog Mascot | bun costume | fine; bevel the bun, bigger face hole |
| Robot Sidekick | screen face | ok; antenna taller, claw bigger |
| Commando | headband, eyepatch | bigger walkie or rope coil as hero element |
| Ventriloquist | dummy | dummy bigger (≥ head width), same pose |
| Night Shift Villain | cape collar | taller collar points, lantern bigger |
| Teen Heartthrob | | weak today: guitar slung big across the body |
| Method Knight | helmet, shield | plume on the helmet |
| Alien Captain | antennae, 3 eyes | ok; cape a bit wider |
| Box Office King | crown | Superstar extension: cape spread wide + money bag |
| Scream Queen | | weak today: hair flare + scream "O" mouth; Superstar extension: spotlight cone |
| Cupid | wings, halo | Superstar extension: wings ≥ body width |
| Showgirl Diva | feather headdress | Legend: gold/emissive feathers, stepped base |
| Silent Film Clown | top hat | Legend: gold cane, emissive buttons |
| Brain in a Jar | jar | Legend: emissive brain glow, gold jar rim |
| Golden Muse | gold gown, halo | Icon: floating halo + aura + unique base (film-reel ring) |
| Mech Hero | mech body | Icon: floating thruster flames + aura + unique base (launch pad) |
| The Phantom Auteur | ghost tail, film strip | Icon: ok; aura + unique base (spotlight stage) |

### What must not change (so game code doesn't)

- Rig pieces stay **Body, Head, ArmL, ArmR, Base**; mesh names `<ActorId>_<Piece>`; feet on y = 0,
  facing -Z; pivots at hip, neck and shoulders (per actor in the generated file, so per-template
  shoulder widths are fine).
- Stay inside today's envelope so cards, pedestals and the Rare Wall need no change: height ≤ 6.7,
  width ≤ 4.6, depth ≤ 3.6 studs (today's max: Showgirl Diva 6.65 tall, Muse 4.50 wide, Commando
  3.52 deep).
- The Award medal is placed by code at chest height y 1.95–2.3, z ≈ -0.8
  (`ActorModels.luau:499-501`): keep the chest front there, or the builder nudges that one constant.
- `ActorShapes.luau` stays generated by `actors.py` (now including `BaseHeight` ~0.7); the part
  fallback keeps working for any actor without a mesh.

### Align with Actor References.md

The rules above are copied from the taste brief the coordinator relayed on 2026-11-14. When
`Movie Mogul/Actor References.md` lands in the vault, the artist reads it before the first draft;
any rule there that differs from this table wins, and the difference goes in the artist's report.

---

## 5. Build plan, Nov 14 → Nov 18

**Constraint:** the Sonnet weekly limit is used up until **Nov 16 07:00** (Handoff). Builder,
artist and playtester run on Sonnet. So Nov 14–15 is drafts and approvals only (Opus override for
the small draft job, Q5), and the real build is Nov 16–17.

**Asset rule (in every artist/builder prompt):** all actor art comes from live Blender (MCP for
Blender, `actors.py`); never Roblox generate_model, Creator Store, built-in generators,
Studio-part props or Claude-drawn placeholders. Drafts go on the Command Center for approval
before the batch.

### PRs

| PR | Who | Branch | Contents | Gate |
|---|---|---|---|---|
| this | designer | `docs/actors-v2` | this file | reviewer optional (docs) |
| A1 | artist | `art/actors-v2` | global pass in `actors.py` (head, face, bevels, AO+rim bake, plinths, templates) + the 3 approval drafts | user approves drafts on the Command Center |
| A2 | artist | same branch | the 9 new actors (rigs exist, not yet in `Actors.List`, so harmless) | reviewer + sheet approval |
| A3 | artist | same branch | per-actor rework of the 21 (2–3 batches) + regenerated `ActorShapes.luau`, 5×6 sheet, `actors.fbx` | reviewer + playtest |
| B | builder | `feat/actors-30` | `Actors.List` +9, Achievements, tests, sim labels, docs strings (section 2 table); new test: every `Actors.List` id has an `ActorShapes.Actors` rig | after A2 merges; reviewer + Game checks + playtest |
| C | artist (+builder for manifest) | `art/actor-meshes` | upload `actors.fbx` as a Model, insert into `LotMeshes`, add `<ActorId>_<Piece>` rows to `LotMeshManifest` (bump the count assert) | LotMeshCheck clean in a playtest; **cuttable** (parts fallback works) |

A1–A3 are one branch with sequential commits (they all regenerate one file); merge after A2 so B
can land, then again after A3. Don't stack B on the art branch.

### Lanes by day

| Day | Art lane (live Blender) | Code lane | Gates / user |
|---|---|---|---|
| **Sat Nov 14** | Opus override (Q5): global pass + 3 drafts: Nervous Intern (Kid template, shows the face/plinth pass on an old actor), Werewolf Pup (new low tier), Captain Squawk (Superstar escalation). Plus a 64 px silhouette strip. | none | docs PR open; user answers the questions |
| **Sun Nov 15** | (idle unless Q5 = Opus) | none | user approves or comments the drafts on the Command Center |
| **Mon Nov 16** (07:00+) | batch 1: the other 8 new actors in two runs of 4 (look → fix → sheet); A2 PR | builder PR B (after A2 merges); reviewer | approve the new-9 sheet |
| **Tue Nov 17** | batches 2–4: rework the 21 (Newcomer–Pro 9, Star–Superstar 6, Legend–Icon 6); A3 PR; export `actors.fbx`; PR C upload/import if time | merge B; reviewer on A3 | **one batched playtest** (temp branch with A3 + B (+C)): snapshot the save first, restore after |
| **Wed Nov 18** | none (freeze 12:00) | fixes only | merge, publish, paste store text, flip `LaunchWipe` as planned |

### Playtest checklist (one run, PC + 844×390 landscape)

Before: user clicks Connect in Rojo after `rojo-switch.sh`; check no playtest is running; snapshot
the save.
1. Collection: 5-card tier rows, names fit, black silhouettes tell apart, counter `x/90`.
2. Odds panel: "Each actor in this tier" shows 1 in 3,500 for Star at Luck 1 (Open).
3. Cast ~50 at Open: reveal card odds text, a new actor's reveal, pull news "(1 in 32,000)" for a Superstar.
4. Lot: top star pedestal and Rare Wall with a new Superstar (Squawk); figure fits the pedestal.
5. A claimed tier reward on an old-style save shows claimed at 3/5.
6. Achievements list: Index texts read right, Index5 says "all 30".
7. Part count on a lot with 5 actors on the Rare Wall (parts vs meshes).
After: restore the save.

### If time runs out (cut in this order)

1. **PR C (mesh import)** → ship the part versions; import after launch.
2. **Per-actor rework of the Newcomer–Star 21** beyond the global pass → after launch.
3. **Superstar–Icon escalation** for the old 9 → after launch.
4. **A new actor whose art isn't approved by Nov 17 18:00** → drop its row from `Actors.List`
   (each is independent; tests read counts from a table, not 30).
Never cut: the global pass on all 30 (one shared helper change), and data + art landing together
(an id without a rig shows the Nervous Intern fallback).

The coordinator's alternative ("polish the 21 first, new 9 next") is Q6 option b; I recommend the
order above because the new 9 are the user's headline decision and the global pass already
upgrades the 21.

---

## 6. Questions (recommended first)

1. **Tier spread of the 9?** a) 5/5/5/5/4/3/3 (above; Star and Superstar rows take a day longer) ·
   b) 6/6/6/3/3/3/3: tidy rows of 3 and no change from Star up, but no new faces past Pro and no
   superhero/detective/pirate · c) one per tier + 2 extra low.
2. **Festival limited actor odds with 5 Stars?** a) keep the rule: as often as one Star actor
   (1 in 3,500) · b) pin it at 1 in 2,100 (one-line change in `limitedChance`).
3. **Captain Squawk's genre?** a) Comedy (Comedy 6, Sci-Fi 5) · b) Sci-Fi space pirate with a
   robot parrot (Sci-Fi 6, Comedy 5).
4. **Head shape in the polish pass?** a) rounded bevelled box, ball only where it is the character ·
   b) keep faceted balls, just bigger · c) all rounded boxes.
5. **Usage limit (Sonnet out until Nov 16 07:00)?** a) run the 3 drafts tonight with an Opus
   override, everything else from Nov 16 · b) wait until Nov 16 for everything · c) Opus for all.
6. **Cut order if late?** a) as in section 5 (new 9 + global pass are must-ship) · b) polish the 21
   first, new 9 next · c) move the launch.
7. **Getting meshes into the place?** a) artist uploads `actors.fbx` as a Model + manifest rows
   (rebuildable) · b) you import the FBX by hand in Studio · c) parts only for launch.
8. **Index achievement wording?** a) "Fill 45 Index slots" + "Discover all 30 actors" · b) keep
   "Discover N actors in the Index".
9. **Collection rows with 5 cards?** a) keep 3 columns, centre the short row (1 line, check in rur) ·
   b) 5 columns on PC, 3 on phone · c) leave left-aligned.
10. **Names OK?** a) as listed · b) I want to rename some (say which).
11. **Store text?** a) builder updates `STORE_LISTING.md`; you paste the line into Creator Hub on
    publish day · b) leave the store at "21" until after launch.
