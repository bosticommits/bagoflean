# Start-movie picker layout (spec)

Status: design, 2026-11-14. Supersedes the footer in PR #135 (`fix/picker-footer-overlap`).
Code: `src/client/StudioUi.luau` (picker, from line 441 on the #135 branch), `src/client/UiKit.luau` (`makePanel`, line 739), `src/client/Tutorial.luau` (picker steps, line 1119; dialogue `layout()`, line 479).
Rules: vault `Movie Mogul/UI Taste Rules.md`, `HUD References.md`, `Tutorial References.md`, `Studio Testing Quirks.md`. Art Style wins on conflicts (gloss, halo and bevel stay).

**One idea:** on this screen the casting **call sheet** becomes the footer: three billing slots and the box-office forecast ("Hit pays $720").
**One live thing:** each actor you cast pops into its slot and the forecast counts up.

---

## 1. Ranked critique (from the #135 screenshots)

| # | Problem | Where | Cause |
|---|---|---|---|
| 1 | **Ghost text.** "Locked", "Cinema", "Start movie" and prices from the Studio panel show through the picker and its footer. | both | Picker is 6% see-through (`UiKit.luau:747` `BackgroundTransparency = 0.06`), the footer has no fill (`StudioUi.luau:445`), there is no dimmed backdrop, and the Studio panel stays open underneath (`StudioUi.luau:977` closes the picker when the Studio panel closes, so the panel can't simply be hidden). |
| 2 | **Phone: the actor grid uses only 2 of 3 columns.** The right third is empty and the panel underneath shows through. | phone | `CellSize = (1/3, -8)` with 10 px padding leaves about 1 px of slack (`StudioUi.luau:719`). Rounding or the scrollbar uses that up, so the third card wraps. The cell height is also set once at build time. |
| 3 | **Phone: almost nothing is visible.** During the tutorial the picker is only about 230 px tall, so about 125 px of list shows: less than one card row. The scripts sit above the actors in a single scroll, so the actor the tutorial points at is often below the fold. | phone | Lucien's bubble reserves the top 133 px (`PanelTop`, `Tutorial.luau:590`). There is one long list for scripts and actors. |
| 4 | **Lucien's bubble and Skip crowd the panel header.** Skip sits about 4 px above the red X (easy to tap the wrong one). The clapper icon pokes up into the gap (3 px left on PC). | both | `PanelTop` adds only 6 px and ignores the 14-16 px the clapper icon sticks out above the title bar. |
| 5 | **Uneven outer margins.** The panel's outline sits 3-4 px from the bottom edge (both devices) and the right edge (phone), but 5-60 px elsewhere. The drop shadow is cut off. | both | The 8 px gaps in `makePanel` (`UiKit.luau:856-877`) don't count the 5 px outer stroke. |
| 6 | **The footer doesn't read as its own row.** It has no surface or divider, so actor cards scroll underneath it and it looks like list content. | both | The footer is a transparent frame over the list. |
| 7 | **The forecast line is jammed against the buttons** (4 px gap on PC: preview 48-72, buttons start at 76). It is centred while the cast names are left-aligned, so the two lines don't line up. | PC | Fixed offsets in `layoutFooter` (`StudioUi.luau:498-501`). |
| 8 | **The names line repeats the slots.** On PC a lone "Commando" floats beside the slots. On phone "Method Knight, Method Knight, Alien Captain" wraps to 2 lines and squeezes the forecast. | both | `summaryLabel` lists every name (`StudioUi.luau:542`). The slots already show the faces. |
| 9 | **The panel is too small for the screen.** On PC a 560 px panel sits in a 1336 px landscape screen and shows about 1.3 card rows. The main thing should be bigger. | PC | `UISizeConstraint` 560x640 and height at 72% (`UiKit.luau:754`, `660-665`). |
| 10 | **Too many accents.** Green Start plus burgundy Clear (or blue Best cast) plus a selected script that turns green. Two green things compete for "go". | both | Rule 5: one accent on the main action. |
| 11 | **Phone hierarchy is upside down.** Card names (about 22 px) are bigger than the footer text (about 14 px) and the cards are 167 px wide while the list is tiny. | phone | One cell size for every width. |
| 12 | **The scrollbar overlays the card borders.** | both | No `VerticalScrollBarInset`. |
| 13 | **The title has a spaced hyphen** ("Start movie  -  Stage 1"). | both | Use "Start movie · Stage 1". |

---

## 2. Layout spec

Coordinates are in **main-gui space**, meaning the area left after `CoreUISafeInsets`. The measured or estimated areas are:

| Viewport | gui area | MenuRight |
|---|---|---|
| PC 1336x653 | 1336 x 595 (top inset 58, measured from Lucien's bust) | about 210 (wallet edge) |
| iPhone 7 667x375 | 667 x 320 (inset about 55, measured) | about 110 |
| iPhone 14-class 844x390 | about 750 x 311 (notch 47 each side, home bar 21; estimate) | about 115 |

The playtester logs the real `gui.AbsoluteSize` and `MenuRight`, and the builder recomputes from the formulas below, never from these constants.

### 2.1 Constants (new, picker-only unless Q10 says otherwise)
| Name | PC | Phone (`isCompact`) |
|---|---|---|
| G, outer gutter (to the stroke's or icon's outer edge) | 16 | 12 |
| STROKE (panel outline, drawn outside) | 5 | 5 |
| ICON_TOP / ICON_LEFT (clapper sticks out) | 16 / 14 | 14 / 10 |
| P, inner padding | 12 | 8 |
| Title bar TB (unchanged) | 54 | 40 |
| Footer F | 84 | 60 |
| Max panel size | 760 x 600 | none |
| Text caps: L title / M buttons / S body | 30 / 26 / 18 | 22 / 16 / 14 |

Three text sizes only. Buttons keep #134's caps (26 PC, 16 phone). `TextScaled` stays on, and nothing sets `TextWrapped=false`.

### 2.2 Panel rect (picker)
```
leftBound   = MenuRight + G + max(STROKE, ICON_LEFT)
rightBound  = area.X - G - STROKE
topBound    = G + max(STROKE, ICON_TOP)      (+ PanelTop only in fallback Q2-C)
bottomBound = area.Y - G - STROKE
W = min(rightBound - leftBound, maxW);  H = min(bottomBound - topBound, maxH)
x = centred on screen if area.X/2 - W/2 >= leftBound, else leftBound
y = centred between topBound and bottomBound
```
| | W x H | x .. | y .. |
|---|---|---|---|
| PC | 760 x 542 | 288..1048 | 32..574 |
| 667 | 518 x 277 | 132..650 | 26..303 |
| 844 | 596 x 268 | 137..733 | 26..294 |

The picker is **opaque** (`BackgroundTransparency 0`). A **scrim** sits behind it: a Frame `PickerScrim` with `ZIndex 4` (the picker is 5), INK at 0.45 transparency, Position (0,-200,0,-200), Size (1,400,1,400) so it also covers the inset strips, and `Active=true`. A tap on the scrim does nothing (Q4). Its `Visible` follows `picker.Visible`. The Studio panel stays open behind it, as now.

### 2.3 Inside the panel (panel-local px)
- **Body:** y `TB+P .. H-F-P`, x `P .. W-P`. PC: 66..446 (380 tall, 736 wide). 667: 48..209 (161 x 502). 844: 48..200 (152 x 580).
- **Two panes (Q1-A):**
  - `scriptsW = clamp(round(bodyW * 0.3), 140, 220)`. Gap: PC 12, phone 8.
  - Results: PC 220 | 504. 667: 151 | 343. 844: 174 | 398.
- **Pane headings, PC only (Q13):**
  - "1  Script" and "2  Cast (up to 3)", 24 px tall, S size, gold, left-aligned.
  - The lists start 30 px lower (y 96..446, 350 tall).
  - Phone has no headings; the footer prompt does that job.
- **Scripts pane** = the existing `List` ScrollingFrame, re-laid to the left pane. It keeps its name and the `PickScript_<Genre>:<Length>` buttons as direct children, which the tutorial looks up at line 1123.
  - Rows are PC 56 / phone 44 tall, with gaps of 8 / 6.
  - Each row: the genre colour, a script icon (36 / 28) at x 8, line 1 the genre (display font, white), line 2 "Short Film · 2:00" (body font, white), and the copies chip "x1" (`UiKit.chip`, inset).
  - **Selected** = genre colour + 4 px GOLD outline + `UiKit.tick` at the right. The row no longer turns green (Q6).
- **Cast pane** = a new ScrollingFrame `CastList` holding the grid Frame `Actors`. The cards are its direct children, as now.
  - Settings: `VerticalScrollBarInset = ScrollBar`, ScrollBarThickness 6 PC / 4 phone, UIPadding 3 on all sides.
  - Columns are recomputed on `CastList.AbsoluteWindowSize` change, not at build:
```
contentW = AbsoluteWindowSize.X - 6
gapC = 10 PC / 8 phone;   minW = 140 PC / 100 phone
cols  = max(2, floor((contentW + gapC) / (minW + gapC)))
cellW = floor((contentW - (cols - 1) * gapC) / cols)
cellH = round(cellW * 0.62) + (52 PC / 40 phone)
```
  - Results: PC 3 cols, 157x149 (2.2 rows visible). 667: 3 cols, 105x105 (1.5 rows). 844: 3 cols, 124x117 (1.3 rows).
  - Card text: name and power at S size. The bonus tag is 86x22 on PC and 72x18 on phone.
- **Footer (the call sheet):**
  - Full-bleed at y `H-F .. H`, x `0 .. W`. Fill DARK, **opaque**, with a 3 px INK top edge.
  - Built like the title bar mirrored: corner 16 plus a square top filler.
  - It is a sibling of the panes, never on top of them.
  - Content is vertically centred, with padding P.

| | PC (W 760, F 84) | 667 (W 518, F 60) | 844 (W 596) |
|---|---|---|---|
| Slots (centre-anchored: Position = left + i*(S+gap) + S/2, F/2) | S 56, gap 8, centres x 40/104/168, y 42 | S 40, gap 6, centres x 28/74/120, y 30 | same as 667 |
| Text block (2 lines, left-aligned) | x 212..384 (172), lines y 16-40 / 44-68 | x 150..280 (130), lines y 11-29 / 31-49 | x 150..358 (208) |
| Clear / Best cast (neutral, Q5) | 130x52, x 398..528 | 84x40, x 290..374 | x 368..452 |
| Start filming (GREEN + halo, name `StartFilming`) | 210x56, x 538..748 | 128x44, x 382..510 (halo clears the edges by 3 px) | x 460..588 |

- **Two-row fallback:** if the text block would be narrower than 150 PC / 110 phone, F becomes 132 / 96. Row 1 holds the slots and the text; row 2 holds Clear (34%) and Start (66%).
- **Footer copy (Q3).** The names line is removed.
  - No script: line 1 "Pick a script" (white). Line 2 is hidden and line 1 is centred vertically.
  - Script but no cast: line 1 "Tap an actor".
  - With a cast: line 1 "Star Power 60" (white), line 2 "Hit pays $720" (gold). Use `TopStudios.short` at 10,000 and above ("$12.5K").
- **Empty slot:** ROW fill, a 2 px MUTED outline and a FAINT "+", so it shows up on the dark footer.
- **Title:** "Start movie · Stage N". While the tutorial line sits in the title bar (Q2-A), it is just "Stage N".

### 2.4 Tutorial line while a panel is open (Q2-A, own PR)
`makePanel` adds a `DialogueSlot` Frame to every title bar:
- x runs from the header text's right edge (`TextBounds`) + 12 to the close X - 12.
- Its height is TB - 8.
- `applyLayout` keeps it up to date.

When a visible panel has a slot at least 220 px wide, `Tutorial.layout()` changes the dialogue:
- **Bubble:** it becomes a cream **one-row pill** in that slot. The cue name is hidden. Text is 13 px on phone and 16 px on PC, 2 lines at most.
- **Lucien:** a 28 / 36 px bust sits at the pill's left.
- **Skip:** 52x26 / 64x30, at the pill's right and at least 12 px from the X.
- **PanelTop:** set to `nil`, so panels get full height.

If the slot is narrower than 220 px, the current corner behaviour is used.

Slot widths: the phone picker ("Stage 2") gives about 318 px, so a 258 px pill (about 31 chars a line). PC gives about 690 px. All film lines are 43 characters or fewer.

Fallback Q2-C keeps the bubble above. Then `PanelTop` must add G + ICON_TOP (not 6), and the phone picker stays about 233 px tall.

---

## 3. Mockups (ASCII, 1 char = about 10 px)

PC 1336x653, no tutorial:
```
 HUD 0-210 |   PickerPanel 760 x 542  (x 288-1048, y 32-574)  scrim behind   |
 Shop      |[clap] Start movie · Stage 1                                 [X] |  title 54
 Actors    |----------------------------------------------------------------|
 Studio    | 1  Script           | 2  Cast (up to 3)                        |  headings 18 gold
 ...       |+-------------------+|+------------+ +------------+ +------------+|
           ||[sc] Action    [x1]|||  (portrait)| |  (portrait)| |  (portrait)||  cards 157 x 149
           ||     Short Film 2:00|||    Commando| | Ventriloq. | | Night Shift||  gap 10
           |+-------------------+||    Power 12| |   Power 8  | |   Power 8  ||
           |+===================+|+------------+ +------------+ +------------+|
           ||[sc] Comedy  [x2] ✓|||  ...        ...            ...           ||  selected = gold outline + tick
           |+===================+|                                          ||
           |  scripts 220        |  cast pane 504, 3 cols                   ||  body 380
           |################################################################|  3 px INK edge
 $130      | [s1][s2][s3]   Star Power 12        [Clear cast] [START FILMING]|  footer 84, opaque DARK
 Fame 0    |                Hit pays $144                                   |
           +----------------------------------------------------------------+
```

PC with the tutorial (Q2-A). The title bar carries Lucien and the panel keeps full height:
```
           |[clap] Stage 1  (L) "Pick your Short Film."     [Skip]       [X] |
```

iPhone 7 667x375 landscape (gui 667x320):
```
 HUD 0-110 | [clap] Start movie · Stage 2                  [X] |  title 40, panel 518 x 277
 Shop      |+-------------+ +---------+ +---------+ +---------+|
 Rewards   ||[sc] Action  | |(portrt) | |(portrt) | |(portrt) ||  cards 105 x 105
 Actors    ||  Short 2:00 | | Zombie E| | Nervous | |  Robot  ||
 Studio    |+-------------+ | Power 1 | | Power 1 | | Power 3 ||
 Codes     |+-------------+ +---------+ +---------+ +---------+|
 Upgrade   ||[sc] Comedy  |  ... 1.5 rows visible               |  body 161
           |#################################################|
 Goals     |[s][s][s] Star Power 60   [Clear][START FILMING]|  footer 60
 Mascots   |          Hit pays $720                           |
           +--------------------------------------------------+
 (12 px gutter to the right and bottom edges, 12 to the HUD + the clapper's 10)
```
With the tutorial on phone the title row reads: `[clap] Stage 2 (L)"Pick your new star. Genre match earns more." [Skip] [X]` (2 lines, 13 px).

---

## 4. Build plan (PR split)

**PR 1 `fix/picker-layout`** (builder, Sonnet). Branch from main and close #135 (Q9-A). It keeps #135's lesson that centre-anchored slots need the half-size offset.
1. `UiKit.luau:739` `makePanel`: add a 9th param `opts: { opaque: boolean?, scrim: boolean?, maxSize: Vector2?, gutter: boolean?, onLayout: ((compact: boolean) -> ())? }`.
   - `opaque` sets transparency 0 (line 747).
   - `scrim` creates `<Name>Scrim` as in 2.2.
   - `maxSize` sets the `UISizeConstraint` (line 754).
   - `gutter` uses the 2.2 rect instead of `panelSize()` + MenuRight + PanelTop (lines 849-878).
   - `onLayout` runs at the end of `applyLayout` (after line 906), so the picker lays out after the panel, with no race between two `onViewportChanged` hooks.
   - Other panels are unchanged.
2. `StudioUi.luau:442`: pass the opts. Delete the separate `onViewportChanged(layoutFooter)` / Visible hooks (lines 508-509). Everything goes in `onLayout`.
3. `StudioUi.luau:444-477`: build the opaque footer (2.3), slot styling, the 2-line text block and the buttons. The `StartFilming` name stays.
4. `StudioUi.luau:480-507` `layoutFooter` becomes `layoutPicker(compact)`:
   - the pane rects, the scripts `List` rect (override what makePanel set) and the `CastList` rect;
   - the footer table above, with the two-row fallback.
5. `StudioUi.luau:534-583` `updatePickerFooter`:
   - new copy (no names); `TopStudios.short` for the Hit;
   - Clear and Best cast both use TAB_OFF (`setEnabled` colour, Q5).
6. `StudioUi.luau:614`: the selected script gets the gold outline + `UiKit.tick` instead of GREEN.
7. `StudioUi.luau:664-697` `buildPicker`:
   - The scripts go into `pickerList` with the 2-line row layout. The `h1` heading row comes out of the list and becomes a PC-only label above the pane.
   - Line 699 `h2` likewise.
   - The grid moves to `CastList`. `noActorsRow` goes into `CastList` too.
8. `StudioUi.luau:719`: drop the static `CellSize`. Add `relayoutGrid()` (formula in 2.3) on `CastList.AbsoluteWindowSize` change. Card text caps follow S; the bonus tag size is set per device.
9. `Tutorial.luau:1140`: `list:FindFirstChild("Actors")` becomes `picker:FindFirstChild("Actors", true)`. Line 1123 (scripts in `List`) stays as is.
10. Lune tests: if `Movies.fillCast` or the copy helpers move into a pure module, add tests there. Run luau-lsp; copy `globalTypes.d.luau` into the worktree first.

**PR 2 `feat/tutorial-title-slot`** (builder). Depends on PR 1's `makePanel` opts.
1. `UiKit.makePanel`: add the `DialogueSlot` and update it in `applyLayout` (after the header sizing, about line 893).
2. `Tutorial.luau:479-595` `layout()`: add the pill branch (2.4) before the corner branch. Set `PanelTop = nil` in pill mode (line 590). Lucien's head and Skip move into the slot.
3. Picker header text is "Stage N" while the tutorial is active (`StudioUi` reads `gui:GetAttribute("TutorialActive")` or the equivalent flag; the builder checks what exists).

**PR 3 `polish/picker-live`** (builder, Haiku is fine; Q8):
- Every cast tap pops its slot. Reuse the 0.18 s Back Out `UIScale` code at `StudioUi.luau:803` as `popSlot(i)`.
- The "Hit pays" number counts up over 0.3 s (Quad Out) from the old value.
- No new art.

No new art in any PR. A clapper-stripe footer edge would come later from ForgeGUI, with a draft on the Command Center first (Q11). Never Studio generators, Creator Store or Claude-drawn art.

---

## 5. Playtest (playtester, one batched run for PR 1 + PR 2)
Setup:
- Ask the user to Connect Rojo after `rojo-switch.sh <worktree>`.
- Check that no playtest is running.
- Snapshot the save, and restore it afterwards.
- Inject the test state right before opening the picker: `ClientState.studio.scripts["Action:Short"]=1` and `roster["<id>:Normal"]=2`.

Devices: PC (`stopSimulation:true`), iPhone 7 667x375 landscape, iPhone 14-class 844x390 landscape. Set the simulator before play. Taps on PC; check phone hits with `GetGuiObjectsAtPosition`.

**Numbers (inspect_ui / client eval):**
1. Log `gui.AbsoluteSize` and `MenuRight`. The panel rect matches 2.2 within 2 px.
2. The visible outer edge (stroke or clapper icon) is at least G from every screen edge, from the HUD column and from Lucien's pill or bubble.
3. The grid has `cols` per the formula. The empty space right of the last card in a full row is less than one card width plus the gap.
4. The footer `BackgroundTransparency` is 0 and the picker's is 0. The scrim is visible only with the picker.
5. No footer label is below 12 px on phone (`TextBounds` / `TextSize`). `TextScaled` is still true on every scaled label.
6. Skip and X are at least 12 px apart (PR 2). `PanelTop` is nil in pill mode.
7. The tutorial finds `filmScript`, `filmActor` and `filmGo` (fresh profile). The ring sits on the target and `StartFilming` is still found.

**States to capture** (a full screenshot of each, on every device):
- no script; script + 0 cast; 1 cast; 3 cast with long names;
- 1 actor only; 20 actors scrolled to the bottom; 20 scripts;
- Best cast after the tutorial; the disabled Start;
- tutorial steps filmScript, filmActor and filmGo;
- after closing with X (the Studio panel is intact, the scrim is gone);
- Studio button toggle.

**Look at each picture and judge it, not just the numbers:**
- no ghost text anywhere;
- the footer reads as one solid strip;
- nothing touches an edge, and the margins look equal;
- no empty column;
- footer lines on one line each, not cramped against the buttons;
- the Start halo is not clipped;
- the cards are not cut by the scrollbar;
- one green thing on screen;
- the Lucien pill does not look like a button.

Report each issue with its screenshot path. Also re-check the Studio panel and one other panel (Shop) for regressions from the `makePanel` changes.

---

## 6. Open questions (recommended first)
1. **Body layout:** A) two panes, Scripts left and Cast right / B) one list, scripts on top / C) one list, and the scripts collapse to one row after picking.
2. **Lucien while a panel is open:** A) a pill in the panel's title bar, every panel, PC and phone / B) phone only / C) keep the bubble above with proper gaps (phone picker stays about 233 px tall).
3. **Footer text:** A) "Star Power N" + "Hit pays $X", no names / B) keep the names line too / C) names on PC only.
4. **Backdrop:** A) 45% dim, a tap does nothing / B) a tap on the dim closes the picker / C) no dim.
5. **Clear / Best cast colour:** A) both neutral navy (Start is the only green) / B) keep burgundy + blue (#130).
6. **Selected script:** A) gold outline + tick / B) turns green (as now).
7. **PC picker max width:** A) 760 / B) 680 / C) 560 (as now).
8. **Live thing:** A) slot pop on every tap + Hit pays counts up / B) A + a mini portrait flies to the slot / C) no motion now.
9. **#135:** A) close it, PR 1 replaces it / B) merge it now as a stop-gap / C) build PR 1 on top of it.
10. **Equal gutters for all panels:** A) picker now, other panels in a later small PR / B) all panels in PR 1 / C) picker only.
11. **Clapper-stripe footer edge:** A) later, via a ForgeGUI draft / B) order the draft now / C) never.
12. **Mockups:** A) the ASCII here + playtest screenshots / B) a Figma storyboard first.
13. **Pane headings:** A) PC only / B) both devices / C) none.
