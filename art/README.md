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
| `src/shared/Models/TownSets.luau` | The town's landmarks and film sets: the Grand Premiere Theatre, the Studio Gate, the four back street sets, poster columns, the far skyline |
| `src/shared/Models/ActorModels.luau` | The 21 actors as toy figures, plus Shiny and Award-Winning effects. The four limited seasonal actors come from `art/blender/seasonal_actors.py` |
| `src/shared/Models/MapKit.luau` | Places a Blender map kit model (mesh once imported, parts until then) |
| `src/shared/Models/MapScenery.luau` | The woods, desert and mountains beyond the paths |
| `src/shared/Models/Walkways.luau` | Where players may walk, and the invisible walls along the path borders |
| `art/blender/*.py` | Blender models: `palm_tree`, `searchlight`, `film_camera`, `film_reel_logo` (and `trophy_gold`), `mystery_crate` (the Mystery Crate event's crate, lid and parachute), `festival_laurel` (the Film Festival prize that stands on a player's lot), `mascots` (the six studio mascots; it also writes `src/shared/Models/MascotShapes.luau`, the part version the game shows until the meshes are imported), `seasonal_actors` (the four limited seasonal actors, built with the mascots' shapes; it writes `src/shared/Models/SeasonalShapes.luau` the same way), and `map_kit` (about 120 map models in one file: `map_kit.py` has the lamps, trees, cacti, rocks, mesas, water towers, bandstand, benches and Dusty Gulch's eight buildings, `town_kit.py` the store stands, plaza fountain, hedges, arches, theatre, Studio Gate, film sets, cars, street furniture, Gulch and park props, hills, the hill star, the blimp, city towers, clouds, gulls, butterflies and ducks, `boulevard_kit.py` the tall boulevard buildings (Hotel Stardust, Sunset Tower, four apartment blocks, two costume shops, the radio station and the Star Cafe), `crew_kit.py` the film set crew and actors (six people in rig pieces: head, torso, arm, leg), their props and the film set gate, all written in the shape language in `kitdsl.py`; it also writes `src/shared/Models/MapKitShapes.luau`, with the sign spots the game letters text on) |
| `art/preview/` | Draws previews of the code-built models without opening Studio |

How the lot grows:

- **Sound stages**: one per owned stage, grey while the lot is free. A red ON AIR light turns on while a movie films there, and a film camera stands outside each one.
- **Cinema**: Cinema Size levels 0-1 small, 2-3 adds a CINEMA blade sign, 4-5 adds columns and side wings, 6 adds a gold dome and searchlights.
- **Office**: Offline Earnings level 0 is a star trailer, 1-2 a two-floor office, 3-4 a glass tower, 5 adds the gold film reel logo on the roof.
- **Top star**: the owner's rarest actor stands on a pedestal by the red carpet (glowing for Star and up) and appears as a portrait on the billboard.
- **Festival Laurels**: each Film Festival the owner wins puts a gold laurel (the Blender `FestivalLaurel` once imported) on a stand between the trophy case and the top star, on a plinth lit in that festival's color. The newest three show.

The town around the lots (`MapModels`, built by `src/server/MapService.luau`):

- **Boulevard** between the two rows of lots, which stand well apart (116 studs): a red carpet, Walk of Fame stars, lamps and palms by turns, crossings to the gates, and a HOLLYWOOD BLVD arch at each end.
- **Boulevard buildings** (`MapModels.Buildings`): tall Blender buildings, 3 to 5 floors, line the boulevard. A narrow pair stands at the front of each path between the lots, and Hotel Stardust and Sunset Tower close each end.
- **Spawn plaza** in the middle, with a fountain and a giant gold trophy (the Blender `TrophyGold` once imported). Players appear on the gold star.
- **Store stands**: eight stalls on the sidewalks. Walking up to one shows a prompt that opens its screen: Shop, Rewards, Requests, Codes, Movies, Upgrades, Casting Odds and Talent Index.
- **Paths** between the lots and round the outside, inside a hedge, so every lot is joined to the others. Lawns, bushes and flowers break up the paving.
- **Edge of town**: hills with a giant gold star sign, two big sound stages and two water towers.
- **Landmarks** (`TownSets`): the boulevard runs out through the hedge to the **Grand Premiere
  Theatre** in the west (marquee, "RNG" sign, carpet up the steps) and through the **Studio Gate**
  in the east to a big sound stage.
- **Back streets**: each path between two lots is a film set, with its props along the sides and
  the middle kept clear: a green screen stage with a camera crane, the props yard (dinosaur head,
  fake moon, crates), star trailers, and a food corner with a taco truck.
- **Poster columns** on the sidewalks and a hazy **city skyline** behind the hills.
- The town's palm trees and searchlights switch to the Blender meshes too, once imported.
- **Walk anywhere inside the map**: the town inside its hedge, the theatre forecourt, the Studio
  Gate road, Starlight Park and Dusty Gulch (`MapModels.PlayAreas`; add a rectangle there to open
  up a new area). One tall invisible wall (`MapWall`, 400 studs) runs round the outside of all of
  it, so nobody can jump out over a hedge or a gate; there are no walls inside. Trees, rocks and
  buildings stay solid.
- **Map kit** (`art/blender/map_kit.py`, `town_kit.py`, `boulevard_kit.py` and `crew_kit.py`): every prop and building on the map is
  a low-poly Blender model, placed by `MapKit` (only the flat ground, paths and lawns are parts).
  Walk-on models (stands, the theatre steps, arches, the bridge) get invisible box colliders;
  sign text is lettered on named spots, so it stays sharp.
- **Life** (`src/client/MapLife.luau`, each player's own copy): gulls gliding in flocks, clouds
  drifting overhead, butterflies over the park and ducks paddling on the pond.
- **Film sets** (`src/client/FilmSetWorld.luau`, each player's own copy): on the Dusty Gulch set a
  film crew (`CrewRig`, Blender pieces from `crew_kit.py`) shoots two scenes from
  `src/shared/FilmScenes.luau`, a showdown and a balcony stunt, timed by the server clock so
  everyone sees the same take. The gate on the way in is bought with Cash; it opens on the
  owner's screen only. Preview a moment with `MAP_SCENE=filmset MAP_ARG=<seconds>` and the
  `filmset`, `filmbalcony`, `filmsetwide` or `filmgate` shots.
- **Scenery**: woods of trees, pines and bushes round the town and behind the park, a desert of
  cacti, boulders and mesas behind Dusty Gulch, trees up the hills, and a ring of terrain
  mountains (snowy peaks, sandstone mesas behind the Gulch) on the horizon.
- **Lighting**: `Future` lighting (set in `default.project.json`, so Rojo sets it when it
  connects; without Rojo, set Lighting > Technology to Future by hand), a late-afternoon golden
  sun, warm haze, sun rays and bloom (`MapService`), a warm light in every lamp and lantern, and a
  mood shift per area (`src/client/AreaMood.luau`: warmer in the Gulch, greener in the park).

Previews: `art/previews/map_kit_*.png` (including `map_kit_crew.png` and `map_kit_set_gate.png`), `art/previews/town_kit_*.png` and `art/previews/boulevard_kit.png` show every kit model. For
lit Blender renders of the town from fixed spots (aerial, theatre, gate, each back street), run
`art/preview/map_shots.py` the same way as the store art (see below); it draws the kit models with
their real Blender meshes, as players see them once `map_kit.fbx` is imported.

## Importing the Blender models into Studio

Do this once. Until you do, the game shows the part-built versions, so nothing breaks.

1. Build the FBX files on your Mac, from the repo folder:
   `for m in palm_tree searchlight film_camera film_reel_logo mystery_crate festival_laurel mascots seasonal_actors map_kit; do /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/$m.py; done`
   This writes `art/exports/<model>.fbx` (`mystery_crate` writes three files, `mascots` one file
   holding every piece of all six mascots, `seasonal_actors` four, `map_kit` one file holding all the map models).
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
| `mystery_crate.fbx` | `MysteryCrate` |
| `mystery_crate_lid.fbx` | `MysteryCrateLid` |
| `crate_parachute.fbx` | `CrateParachute` |
| `festival_laurel.fbx` | `FestivalLaurel` |
| `pumpkin_phantom.fbx` | `PumpkinPhantom` |
| `jingle_jester.fbx` | `JingleJester` |
| `cupid_crooner.fbx` | `CupidCrooner` |
| `heatwave_hero.fbx` | `HeatwaveHero` |

**The map kit and the mascots are quicker**: import `map_kit.fbx` and `mascots.fbx` once each
(Home → Import 3D, with "Merge meshes" off), then drag each whole imported model into
`ReplicatedStorage > LotMeshes` as it is. The game finds each piece inside by name and sets the
colors itself, so there is nothing to rename. The mascots come in moving pieces
(`PopcornPup_Body`, `PopcornPup_Tail`, ...) that the game animates; if you imported the older
one-piece mascots (`PopcornPup` and so on), delete those, since the game no longer uses them.

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
`actor <Id>`, `director` (or `director bust`), `lotEmpty`, `lotStarter`, `lotMid`, `lotMax`, `map` for the whole town, `events` for
the special event props). The renderer draws shapes and
colors only (no text, particles or lights).

The Blender scripts also run with the `bpy` Python package (Python 3.11) instead of the Blender
app; see the top of `art/blender/mmkit.py`.

## Store art: logo, thumbnails and icon

`art/blender/store/` renders the Roblox store images in Blender from the game's own lot and actor
models (through `art/preview/dump.luau`), so the art shows what players can really get. The
finished images are in `art/store/`.

| Script | What it makes |
|---|---|
| `logo.py` | The 3D "HOLLYWOOD RNG" logo (gold and rainbow with a white outline), a clapperboard, a die and the bacon-hair player in a beret, on a transparent background |
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

### Roblox front-page style (October 2026)

The newer set copies what front-page Roblox thumbnails do: a plain blocky player with bacon hair,
bright sky and grass, sunbursts, and fat outlined words with rainbow numbers.

| Script | What it makes |
|---|---|
| `bacon.py` | The player: R6 blocky body, round head with a painted face (smug, shocked, star-struck, grin), bacon hair melted from metaballs, optional director's beret |
| `thumbnail_tower.py` | Thumbnail A: a smug player shows off a four-floor studio tower full of the game's actors ("99 SUPERSTARS", "$1,000,000/s") |
| `thumbnail_reveal.py` | Thumbnail B: a mystery casting ticket, a red arrow, and a rainbow superstar ("1 IN 1,000,000") |
| `icon_bacon.py` | The icon: the star-struck player in a beret holding up a rainbow star |
| `compose_roblox.py` | Draws the skies, sunbursts and checks, adds the words and arrow, and writes the finished PNGs |

```
python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/store/words.py -- superstars per_second one_in_million
for s in icon_bacon thumbnail_reveal thumbnail_tower logo; do
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/store/$s.py
done
python art/blender/store/compose_roblox.py    # writes $STORE_OUT/final/*.png
```

For quick test renders set `STORE_SCALE=50 STORE_SAMPLES=24`. Everything renders with Cycles on
the CPU; the main thumbnail takes about 15 minutes on 4 cores.

To upload them: on the Creator Dashboard open the game, then **Configure → Places**, click the
start place, and use **Icon** (`hollywood-rng-icon-512.png`) and **Thumbnails** (the 1920 x 1080
PNGs). Roblox can rotate several thumbnails and show each player the one that works best. Keep
important things away from the bottom edge of a thumbnail, where Roblox may draw player counts.
