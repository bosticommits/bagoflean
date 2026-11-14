# UI phone checks (rur)

Renders our real UI code (`src/client/*Ui.luau`, built at runtime with UiKit) with fake data in
rur (v0.3.1) (offline Studio-parity GUI renderer), then checks the layout of every
`scene.json`. Run it before any UI playtest in Studio.

```
tests/ui/run.sh                 # render Hud, HudMore (More flyout open), Studio, Picker, Visit at 4 sizes, check, exit 1 on a NEW finding
tests/ui/run.sh Picker          # one story
tests/ui/run.sh --strict        # ignore baseline.json, list every finding
tests/ui/run.sh --update-baseline   # accept today's findings as known (do this only on purpose)
node tests/ui/selftest.mjs      # proves each check can fail (also runs first in run.sh)
```
Output: `/tmp/rur-ui/<Story>-<WxH>/render.png` + `scene.json` (override with `RUR_UI_OUT`). Look at the PNGs.

Needs rur's binary (`RUR_BIN`, default `~/Desktop/tools/rur-bin/x/rur-native`) and Roblox Studio's `content`
folder for fonts (`RUR_ROBLOX_CONTENT`, default the macOS Studio app). See `~/.claude/skills/rur/SKILL.md`.

## What is rendered
- `stories/*.story.luau` call the real `SideMenu`, `Hud`, `CastingUi`, `StudioUi`, `VisitUi` `start()` functions the way
  `Main.client.luau` does. `lib/Harness.luau` fakes only what they reach for: `ReplicatedStorage.Remotes`, the local
  player's attributes, `ClientState` (studio, roster, index) and `workspace.Lots`. No game logic is replaced.
- Picker: `Picker.actions.json` clicks Start movie, picks a script and three actors (full cast in the footer).
- One seam in game code: `VisitUi.assumeCanInvite` (default false, behaviour-neutral). rur's SocialService always says
  "cannot invite", so the Visit story sets it to show the Invite friends button.
- Sizes: 844x390 and 667x375 (phones), 750x390 (the 844 phone minus its 47 px notch insets: rur has no side insets,
  and the picker layout depends on them), 1336x653 (PC). Top bar inset 36 on all.

## Checks (`check.mjs`; rules from Movie Mogul/UI Taste Rules.md "Borrowed checks")
offscreen (outside the safe area) · outside-panel (past its panel outline) · overlap (buttons/labels in the same layer,
and HUD blocks over each other) · touch-target (<44 px, phones) · safe-zone (top 36 px, thumbstick, jump button; not
inside the picker modal, which hides touch controls; a non-modal panel only warns) · text-size (TextScaled <12 px) ·
picker-columns (cast grid must be 3 columns). Scroll content is clipped to its window first.
`baseline.json` lists findings known on main so the script only fails on new ones (empty since the phone-size fixes; entries
for touch-target / text-size carry `|size=N`, and a known finding that gets smaller than N fails). `warn` findings (a panel
button over the thumbstick/jump zone) are listed but never fail the run; only `FAIL` lines do.
A story can list nodes it must render in `stories/<Story>.expect.json` (Visit: `InviteFriends`); a missing one fails.
These checks are a **subset** of what makes a good layout (no glyph shapes, icons, contrast, motion, taste): always look at the PNGs.
`run.sh` only wipes `RUR_UI_OUT` when its folder name starts with `rur-ui` (or is a `mktemp -d` dir).

## Limits
- Offline: 3D icons (ViewportFrames) and cloud fonts are missing, so icons are blank and text uses fallback metrics
  for one display font ("Missing font ..." in the log). Layout rects are right; look at glyph widths with care.
- Only the screens above. Other screens need a story + a line in `run.sh`. Tutorial, modals' dim, tweens past 1.5 s,
  gameplay and save data are not covered. Panel-vs-HUD overlap is not checked (panels sit on top on purpose).
- rur has no notch insets, no portrait, no real Roblox touch controls (zones are the fractions from roblox-ui-verify).

## CI (not enabled)
Fonts come from Studio, which GitHub runners lack. To run it in Actions: download Roblox's Studio `content/fonts` into
a cached folder (or a frozen copy, see rur docs/testing.md `--freeze-fonts`), set `RUR_ROBLOX_CONTENT`, fetch rur's Linux
binary (verified release), and add `tests/ui/run.sh` as a step. Until then it is a local pre-playtest check.
