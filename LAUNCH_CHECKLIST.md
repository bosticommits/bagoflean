# Launch Checklist: Hollywood RNG

From where the game is today (7 Oct 2026) to a public, publishable release.
Work top to bottom. Each step has a "done when" so it is clear when to tick it.
Design details live in [GAME_PLAN.md](GAME_PLAN.md); the look lives in
[ART_STYLE.md](ART_STYLE.md).

## Where we are now

- In `main`: M0 to M5 (lots, casting, movies, Index, upgrades, lot visuals, effects, sounds,
  tutorial), the art guide and first trophy model, the M6 launch features (passes, products,
  Award Night, daily rewards, codes, quests, analytics) and the restyled UI.
- Owned by other threads right now: lot and actor models, economy balance, icon and
  thumbnails.
- Still open: real art, playtests and tuning, device checks, the Studio tests
  in section 7, and filling in the store page on the Creator Dashboard.

---

## 1. Lock in what is built

- [x] Merge `m5-polish` (it contains M0 to M5) into `main`. *Done when:* `main` has `src/`
      and the updated GAME_PLAN.
- [x] Merge `art-pipeline` into `main`. *Done when:* `ART_STYLE.md` is on `main`.
- [x] Decide the final name: **Hollywood RNG** (chosen 7 Oct; it was Movie Mogul). *Done when:* the name is in
      GAME_PLAN section 10 as decided and in `Config.GameName`.

## 2. Core loop: make it fun first

The plan's rule: if casting plus a premiere is not exciting, fix that before adding more.

- [ ] Playtest the first 15 minutes with 3 or more people who have not seen the game.
      *Done when:* each one finishes the tutorial unaided and plays a second movie by choice.
- [ ] Tune the economy: roll costs, script prices, payouts, upgrade costs, Fame gates.
      *Done when:* a new player reaches Talent Agency in about 20 to 30 minutes and
      Hollywood Casting in a few play sessions, and nobody hits a dead end with no Cash.
- [ ] Tune timers: Short, Indie, Feature, Epic and the offline cap. *Done when:* there is
      always something to do in a session, and a reason to come back later.
- [ ] Check the premiere and rare-pull moments feel big. *Done when:* testers react to a
      Blockbuster or a Star pull without being told to.

## 3. Content

- [ ] Final lot art, built from ART_STYLE.md: cinema, sound stages, offices, billboard,
      red carpet, trophies, lot ground. *Done when:* no placeholder parts are left on a lot.
- [ ] A look for all 21 actors (portrait or model), with Shiny and Award-Winning versions.
      All original characters, no real people. *Done when:* every one of the 63 Index slots
      shows real art.
- [ ] Script posters for the 5 genres and 4 script sizes. *Done when:* the script shop
      and cinema show art, not plain text.
- [x] Server hub between the 6 lots (paths, sky, lighting, a few landmarks).
      *Done when:* the map looks finished from any lot.
- [ ] Music: a lobby track and a premiere sting, licensed or from Roblox's library.
      *Done when:* every sound and track has a known, allowed source.

## 4. UI

- [x] Restyle every screen to ART_STYLE.md: HUD, casting, roster, studio, script shop,
      Index, upgrades, tutorial. *Done when:* all screens share one look and rarity colors.
- [ ] Phone check on a small Android and an iPhone, portrait and landscape.
      *Done when:* every button is easy to tap and nothing is hidden behind controls.
- [ ] PC and gamepad check. *Done when:* every screen can be opened, used and closed with
      mouse, keyboard and a controller.
- [ ] Odds are visible on the casting screen for every agency. *Done when:* the shown odds
      match the real roll code.

## 5. Retention (M6)

- [x] Award Night every 30 minutes: 3 minutes of more Luck and double premiere payouts.
      *Done when:* it starts on time on every server, with a countdown players can see.
- [x] Server announcement when anyone pulls Legend or Icon or gets a Masterpiece.
      *Done when:* everyone on the server sees the message.
- [x] Daily login rewards. *Done when:* they cannot be claimed twice by changing the
      device clock or rejoining.
- [x] 3 daily Studio Requests (small quests). *Done when:* they reset once a day and pay out.
- [x] Codes for social posts. *Done when:* each code works once per player and can be
      switched off without a game update.

## 6. Monetization (M6)

Rules from the plan: odds always visible, no buying a specific rare actor, free players can
reach everything.

- [x] Game passes: 2x Luck, Auto-Collect, +1 Sound Stage, Faster Filming, VIP cosmetics.
      *Done when:* each works right after buying and after rejoining.
- [x] Developer products: Lucky Casting (15 min), skip filming, Cash packs.
      *Done when:* each purchase is granted exactly once, even if the player leaves mid-buy.
- [x] Hide Robux items that lead to random actors (2x Luck, Lucky Casting, Cash packs) for
      players whose region restricts paid random items. *Done when:* the shop shows them as
      "Not available" for those players (Roblox PolicyService rule).
- [x] Shop screen and in-context prompts (for example, offer a skip on a long filming timer).
      *Done when:* buying never blocks normal play and every price is shown before buying.
- [ ] Check prices against similar games. *Done when:* every item has a price written down
      with a reason.

## 7. Testing before launch

- [ ] Saving: join, play, leave, rejoin; two servers at once; server shutdown.
      *Done when:* no Cash, actors or Index entries are lost or duplicated.
- [x] Cheating: every remote is checked by the server and rate limited.
      *Done when:* a security review finds no way to get free Cash, rolls or timers.
      (Reviewed 7 Oct: all 16 remote handlers check types, ranges, ownership and cooldowns. Note for
      tuning: an autoclicker on the clapperboard films about 5x faster.)
- [ ] Performance on a low-end phone with 6 full lots. *Done when:* it stays smooth and
      memory does not keep climbing over a 30-minute session.
- [ ] No errors in the output during a full play session. *Done when:* a clean log is saved.
- [ ] Duplicate-script check from the README. *Done when:* it prints no `DUPLICATE` lines.
- [ ] Analytics (events are built; check they arrive): tutorial steps, first roll, first premiere, day-1 return, purchases.
      *Done when:* events show up in the Creator Dashboard.
- [ ] Private test with 10 to 20 players for a few days. *Done when:* their top problems
      are fixed.

## 8. Store listing and publish

- [x] Game icon (512x512) in the art style. *Done when:* it reads clearly at small size.
      (Rendered in Blender: `art/store/hollywood-rng-icon-512.png`.)
- [ ] 3 to 5 thumbnails showing casting, a premiere and a big lot. *Done when:* uploaded.
      (Two are ready in `art/store/`: the Icon pull and noob to mogul lots. Upload steps in
      `art/README.md`.)
- [x] Short description: what you do in one line, then the hook (offline filming, rare
      actors, Masterpiece premieres). *Done when:* written and checked for spelling.
      See [STORE_LISTING.md](STORE_LISTING.md).
- [ ] Genre, max players (**6**, one per lot), supported devices, and age questionnaire
      filled in, using the answers in STORE_LISTING.md.
      *Done when:* every Creator Dashboard field is complete.
- [ ] Social links (group, Discord or X) for the codes. *Done when:* linked on the game page.
- [ ] Run the publish checklist (the `roblox-publish-checklist` skill).
      *Done when:* it says READY, with evidence for each gate.
- [ ] Rollback plan. *Done when:* the last good version is noted and it is known how to
      revert to it.
- [ ] Switch the game to Public. *Done when:* it can be found and joined by anyone.

## 9. After launch (M7 and later)

- [ ] Watch the first week: errors, retention, where players quit, purchases.
- [ ] Weekly Film Festival events with a limited actor pool.
- [ ] Sequel (rebirth).
- [ ] New genres and the Music Label department.
