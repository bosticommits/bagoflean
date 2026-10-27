# Film set authoring pipeline

The runtime already consumes keyed set entries: `FilmSets.List` holds progression data,
`MapModels.FilmSets` places the gate and walkable area, and `FilmScenes.Sets` supplies the scene
cast, props, gear and timeline. All three use the same stable set id. `FilmScenes` is the scene
script for choreography that is unique to a set; `FilmSetWorld` handles the shared crew rig,
timing, ownership gate, and playback.

## Add a set

1. **Choose one stable id** (for example `PirateCove`) and add its name, price, Luck and box-office
   bonus to `src/shared/FilmSets.luau`. Add its world frame, gate width, walkable rectangle and owner
   arrival point to `src/shared/Models/MapModels.luau`.
2. **Write the scene script** in `src/shared/FilmScenes.luau`: crew marks, named actors, allowed props,
   set gear, the scene timeline, and a centre point. Register the same id in both `defs` and
   `FilmScenes.Sets`. Positions are set-local; ground is y=0.2 and +Z leads in from the gate.
3. **Build the art kit** by copying `art/blender/film_set_template.py` to `<theme>_kit.py`. Name each
   Blender model exactly as its `kit` name in the Luau scene gear/props. Add the module to the
   `map_kit.py` aggregator, `MapKitShapes.luau` generation and preview lineup so art exports and
   part fallbacks share names. Use `art/blender/kitdsl.py`, keep collision as simple invisible
   parts, and add every new mesh name to the asset manifest/rebuild path.
4. **Check the shared data**: `tests/luau/filmsets.spec.luau`, `visits.spec.luau`, `crew.spec.luau`
   and `map.spec.luau` check ids, map clearance, arrivals, scene poses and prop references. Run
   `Game checks` before merging. Import the generated mesh kit into Studio and verify the gate,
   crew marks, arrival point and full scene together.

## Kit starter

`art/blender/film_set_template.py` is a runnable shape-language starter. Replace its landmark with
the theme's named models; add matching names in the scene script. Existing examples are
`space_kit.py` and `jungle_kit.py`. The art is isolated in a theme kit, while the scene script is
kept in one place with the shared timeline helpers. Keep per-set scenes data-like (marks, gear,
props, cues and timed poses); add a new engine feature only when the set needs behavior the shared
crew/timeline runtime does not yet provide.
