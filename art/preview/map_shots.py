"""Blender renders of the town (the `map` scene) from a few fixed spots, to check map changes
without Studio. Uses the store art helpers (art/blender/store/kit.py), so it needs the `bpy`
package and Lune, like the store art:

  LUNE=/path/to/lune python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" \
      art/preview/map_shots.py [shot ...]

Writes $STORE_OUT/map/<shot>.png (default /tmp/store). Set STORE_SAMPLES / STORE_SCALE to trade
quality for time. Text on signs is not drawn.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "blender", "store"))
import kit  # noqa: E402

# Shots in Roblox coordinates: camera position, target, lens.
SHOTS = {
    "aerial": ((90, 260, -330), (-20, 0, 10), 30),
    "boulevard": ((-24, 8, -4), (110, 18, 12), 26),
    "boulevardback": ((24, 8, 4), (-110, 18, -12), 26),
    "towers": ((40, 60, -150), (60, 20, 60), 30),
    "theatre": ((-176, 12, 24), (-222, 12, 0), 26),
    "west": ((-340, 120, 150), (-90, 0, 0), 30),
    "gate": ((174, 8, -10), (222, 12, 0), 30),
    "propsyard": ((50, 10, -40), (58, 3, -98), 30),
    "trailers": ((-50, 10, 40), (-58, 3, 98), 30),
    "greenscreen": ((-50, 10, -40), (-58, 3, -98), 30),
    "foodcorner": ((50, 10, 40), (58, 3, 98), 30),
    "busstop": ((82, 9, -4), (98, 4, -24), 30),
    "boulevardend": ((140, 9, 4), (186, 12, 30), 30),
    "spawn": ((0, 7, -17), (0, 6, 40), 28),
    "park": ((30, 60, 120), (-10, 0, 198), 30),
    "parkpath": ((4, 7, 142), (-4, 6, 208), 28),
    "pond": ((-8, 14, 176), (-62, 2, 218), 28),
    "screen": ((10, 10, 183), (0, 14, 243), 28),
    "western": ((0, 7, -144), (0, 8, -228), 28),
    "gulch": ((70, 70, -118), (0, 0, -208), 30),
    "blimp": ((60, 40, -128), (0, 110, -248), 30),
    "backlot": ((-298, 46, -96), (-182, 0, 0), 30),
    "lanterns": ((10, 6, -158), (-14, 6, -208), 30),
    "desert": ((0, 40, -258), (0, 10, -428), 30),
    "filmgate": ((0, 8, -100), (0, 6, -140), 30),
    "filmset": ((-6, 8, -212), (2, 4, -242), 30),
    "filmsetwide": ((0, 46, -196), (2, 3, -242), 30),
    "filmbalcony": ((-8, 7, -220), (10, 7, -242), 26),
}


def roblox(p):
    x, y, z = p
    return (-x, z, y)


def main(names):
    # MAP_SCENE=filmset MAP_ARG=<seconds> draws the town with the film crew posed at that moment.
    scene = os.environ.get("MAP_SCENE", "map")
    parts = [p for p in kit.dump(scene, os.environ.get("MAP_ARG")) if p["name"] not in ("SearchlightBeam", "MapWall", "PathWall")]
    kit.new_scene(1280, 720, samples=48)
    kit.sky(top="#4A86E0", middle="#8FBDF2", horizon="#F4E6CF", glow="#FFD9A8", strength=1.0, light_strength=0.8)
    kit.light("SUN", (0, 0, 100), 3.2, "#FFF1DC", target=(-40, -60, 0), angle=4, name="Sun")
    kit.import_parts(parts, "Town", bevel=0.05)
    out = os.path.join(kit.OUT, "map")
    for name in names or SHOTS:
        location, target, lens = SHOTS[name]
        cam = kit.camera(roblox(location), roblox(target), lens=lens)
        cam.data.clip_end = 3000
        kit.render(os.path.join(out, f"{name}.png"))


main(sys.argv[2:] if len(sys.argv) > 2 else [])
