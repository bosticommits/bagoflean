# Launch Checklist: Movie Mogul

From where the game is today (7 Oct 2026) to a public, publishable release.
Work top to bottom. Each step has a "done when" so it is clear when to tick it.
Design details live in [GAME_PLAN.md](GAME_PLAN.md); the look lives in `ART_STYLE.md`
(on the `art-pipeline` branch).

## Where we are now

- M0 to M5 are built: lots and cash, casting, movies, Index, agencies, upgrades, lot
  visuals, billboard, effects, sounds and the tutorial.
- That work sits on the stacked branches `m0-rojo-setup` to `m5-polish`. None of it is in
  `main` yet, and `main`'s GAME_PLAN still says "nothing built".
- Art is placeholder parts. The Blender art pipeline has started (`art-pipeline` branch:
  style guide and a gold trophy).
- Not built yet: Award Night, daily rewards, Studio Requests, codes, game passes and
  developer products, Sequel, analytics.

---

## 1. Lock in what is built

- [ ] Merge `m5-polish` (it contains M0 to M5) into `main`. *Done when:* `main` has `src/`
      and the updated GAME_PLAN.
- [ ] Merge `art-pipeline` into `main`. *Done when:* `ART_STYLE.md` is on `main`.
- [ ] Decide the final name ("Movie Mogul" or another). *Done when:* the name is in
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
- [ ] Server hub between the 6 lots (paths, sky, lighting, a few landmarks).
      *Done when:* the map looks finished from any lot.
- [ ] Music: a lobby track and a premiere sting, licensed or from Roblox's library.
      *Done when:* every sound and track has a known, allowed source.

## 4. UI

- [ ] Restyle every screen to ART_STYLE.md: HUD, casting, roster, studio, script shop,
      Index, upgrades, tutorial. *Done when:* all screens share one look and rarity colors.
- [ ] Phone check on a small Android and an iPhone, portrait and landscape.
      *Done when:* every button is easy to tap and nothing is hidden behind controls.
- [ ] PC and gamepad check. *Done when:* every screen can be opened, used and closed with
      mouse, keyboard and a controller.
- [ ] Odds are visible on the casting screen for every agency. *Done when:* the shown odds
      match the real roll code.

## 5. Retention (M6)

- [ ] Award Night every 30 minutes: 3 minutes of more Luck and double premiere payouts.
      *Done when:* it starts on time on every server, with a countdown players can see.
- [ ] Server announcement when anyone pulls Legend or Icon or gets a Masterpiece.
      *Done when:* everyone on the server sees the message.
- [ ] Daily login rewards. *Done when:* they cannot be claimed twice by changing the
      device clock or rejoining.
- [ ] 3 daily Studio Requests (small quests). *Done when:* they reset once a day and pay out.
- [ ] Codes for social posts. *Done when:* each code works once per player and can be
      switched off without a game update.

## 6. Monetization (M6)

Rules from the plan: odds always visible, no buying a specific rare actor, free players can
reach everything.

- [ ] Game passes: 2x Luck, Auto-Collect, +1 Sound Stage, Faster Filming, VIP cosmetics.
      *Done when:* each works right after buying and after rejoining.
- [ ] Developer products: Lucky Casting (15 min), skip filming, Cash packs.
      *Done when:* each purchase is granted exactly once, even if the player leaves mid-buy.
- [ ] Shop screen and in-context prompts (for example, offer a skip on a long filming timer).
      *Done when:* buying never blocks normal play and every price is shown before buying.
- [ ] Check prices against similar games. *Done when:* every item has a price written down
      with a reason.

## 7. Testing before launch

- [ ] Saving: join, play, leave, rejoin; two servers at once; server shutdown.
      *Done when:* no Cash, actors or Index entries are lost or duplicated.
- [ ] Cheating: every remote is checked by the server and rate limited.
      *Done when:* a security review finds no way to get free Cash, rolls or timers.
- [ ] Performance on a low-end phone with 6 full lots. *Done when:* it stays smooth and
      memory does not keep climbing over a 30-minute session.
- [ ] No errors in the output during a full play session. *Done when:* a clean log is saved.
- [ ] Duplicate-script check from the README. *Done when:* it prints no `DUPLICATE` lines.
- [ ] Analytics: tutorial steps, first roll, first premiere, day-1 return, purchases.
      *Done when:* events show up in the Creator Dashboard.
- [ ] Private test with 10 to 20 players for a few days. *Done when:* their top problems
      are fixed.

## 8. Store listing and publish

- [ ] Game icon (512x512) in the art style. *Done when:* it reads clearly at small size.
- [ ] 3 to 5 thumbnails showing casting, a premiere and a big lot. *Done when:* uploaded.
- [ ] Short description: what you do in one line, then the hook (offline filming, rare
      actors, Masterpiece premieres). *Done when:* written and checked for spelling.
- [ ] Genre, max players, supported devices, and age questionnaire filled in.
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
