# Art: lot and actor models

Everything players see on a studio lot is built by code in `src/shared/Models/`, in the style of
`ART_STYLE.md`. It works with no imports at all. The curved props also have Blender versions
that look smoother; once you import them, the game uses them automatically.

| File | What it builds |
|---|---|
| `src/shared/Models/Build.luau` | Part builder, palette, and the Blender mesh lookup |
| `src/shared/Models/LotModels.luau` | Sound stage, cinema (4 sizes), office (6 levels), billboard, gate, hedges, palm, lamp, searchlight, film camera, kiosk, trophies, pedestal. Also the lot layout |
| `src/shared/Models/LotLook.luau` | Puts the pieces together for a lot at a given progress |
| `src/shared/Models/MapModels.luau` | The town around the lots: boulevard, spawn plaza and fountain, paths, the 8 store stands, hills with the gold star sign. Also where each lot sits |
| `src/shared/Models/ActorModels.luau` | The 21 actors as toy figures, plus Shiny and Award-Winning effects |
| `art/blender/*.py` | Blender models: `palm_tree`, `searchlight`, `film_camera`, `film_reel_logo` (and `trophy_gold`) |
| `art/preview/` | Draws previews of the code-built models without opening Studio |

How the lot grows:

- **Sound stages**: one per owned stage, grey while the lot is free. A red ON AIR light turns on while a movie films there, and a film camera stands outside each one.
- **Cinema**: Cinema Size levels 0-1 small, 2-3 adds a CINEMA blade sign, 4-5 adds columns and side wings, 6 adds a gold dome and searchlights.
- **Office**: Offline Earnings level 0 is a star trailer, 1-2 a two-floor office, 3-4 a glass tower, 5 adds the gold film reel logo on the roof.
- **Top star**: the owner's rarest actor stands on a pedestal by the red carpet (glowing for Star and up) and appears as a portrait on the billboard.

The town around the lots (`MapModels`, built by `src/server/MapService.luau`):

- **Boulevard** between the two rows of lots: a red carpet, Walk of Fame stars, lamps, palms, crossings to the gates, and a HOLLYWOOD BLVD arch at each end.
- **Spawn plaza** in the middle, with a fountain and a giant gold trophy (the Blender `TrophyGold` once imported). Players appear on the gold star.
- **Store stands**: eight stalls on the sidewalks. Walking up to one shows a prompt that opens its screen: Shop, Rewards, Requests, Codes, Movies, Upgrades, Casting Odds and Talent Index.
- **Paths** between the lots and round the outside, inside a hedge, so every lot is joined to the others. Lawns, bushes and flowers break up the paving.
- **Edge of town**: hills with a giant gold star sign, two big sound stages and two water towers.
- The town's palm trees and searchlights switch to the Blender meshes too, once imported.

Previews: `art/previews/town.png` and `art/previews/town_boulevard.png`.

## Importing the Blender models into Studio

Do this once. Until you do, the game shows the part-built versions, so nothing breaks.

1. Build the FBX files on your Mac, from the repo folder:
   `for m in palm_tree searchlight film_camera film_reel_logo; do /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/$m.py; done`
   This writes `art/exports/<model>.fbx`.
2. In Studio, in the Explorer, add a **Folder** inside **ReplicatedStorage** and name it `LotMeshes`.
3. For each FBX: **Home → Import 3D**, pick the file, click **Import**. It lands in the world as a Model.
4. In the Explorer, open that Model, find its MeshPart, and:
   - set **Color** to white (255, 255, 255) and **Material** to SmoothPlastic, so the baked colors show,
   - rename it to the name below,
   - drag it into `ReplicatedStorage > LotMeshes`, then delete the leftover Model from the world.

| FBX file | Name it |
|---|---|
| `palm_tree.fbx` | `PalmTree` |
| `searchlight.fbx` | `Searchlight` |
| `film_camera.fbx` | `FilmCamera` |
| `film_reel_logo.fbx` | `FilmReelLogo` |
| `trophy_gold.fbx` (already uploaded) | `TrophyGold` |

5. Press Play. The lots now use the meshes. Save the place so the folder is kept.

Rojo only manages `ReplicatedStorage.Shared`, so it leaves the `LotMeshes` folder alone.

## Previewing without Studio

Needs [Lune](https://github.com/lune-org/lune) and Python with numpy and Pillow. From the repo root:

```
lune run art/preview/dump.luau lotMax /tmp/lot.json
python3 art/preview/render.py /tmp/lot.json /tmp/lot.png --view 34
art/preview/actor_sheet.sh   # all actors -> art/previews/actors_sheet.png
```

Scenes are listed in `art/preview/scenes.luau` (`stage`, `cinema`, `office`, `props`, `actors`, `icons`,
`actor <Id>`, `lotEmpty`, `lotStarter`, `lotMid`, `lotMax`, `map` for the whole town). The renderer draws shapes and
colors only (no text, particles or lights).

The Blender scripts also run with the `bpy` Python package (Python 3.11) instead of the Blender
app; see the top of `art/blender/mmkit.py`.

## Store art: logo, thumbnails and icon

`art/blender/store/` renders the Roblox store images in Blender from the game's own lot and actor
models (through `art/preview/dump.luau`), so the art shows what players can really get. The
finished images are in `art/store/`.

| Script | What it makes |
|---|---|
| `logo.py` | The 3D "HOLLYWOOD RNG" logo with a clapperboard and a die, on a transparent background |
| `thumbnail.py` | Main thumbnail: a shocked player pulls the Icon actor (The Mogul's Muse, 1 in 1,000,000) on a max-level lot |
| `thumbnail_lots.py` | Second thumbnail: the same lot on day one and fully upgraded ("noob" to "mogul") |
| `icon.py` | The icon: a close-up of the main thumbnail's scene |
| `words.py` | The chunky 3D words laid on top ("1 IN 1,000,000!", "ICON", "RNG", "NOOB", "MOGUL", the arrow) |
| `compose.py` | Lays the words on the renders and writes the finished PNGs |
| `kit.py` | Shared helpers: the part importer, materials, 3D words, props, and the player's faces |

It needs the `bpy` Python package (Python 3.11) with `shapely` and `Pillow`, and Lune. From the
repo root:

```
pip install bpy shapely pillow
export LUNE=/path/to/lune STORE_OUT=/tmp/store
for s in words logo icon thumbnail thumbnail_lots; do
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/store/$s.py
done
python art/blender/store/compose.py    # writes $STORE_OUT/final/*.png
```

For quick test renders set `STORE_SCALE=50 STORE_SAMPLES=24`. Everything renders with Cycles on
the CPU; the main thumbnail takes about 15 minutes on 4 cores.

To upload them: on the Creator Dashboard open the game, then **Configure → Places**, click the
start place, and use **Icon** (`hollywood-rng-icon-512.png`) and **Thumbnails** (the 1920 x 1080
PNGs). Roblox can rotate several thumbnails and show each player the one that works best. Keep
important things away from the bottom edge of a thumbnail, where Roblox may draw player counts.
