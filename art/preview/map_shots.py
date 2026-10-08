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
    "aerial": ((70, 200, -250), (-20, 0, 10), 30),
    "theatre": ((-114, 12, 24), (-160, 12, 0), 26),
    "west": ((-270, 110, 130), (-70, 0, 0), 30),
    "gate": ((112, 8, -10), (160, 12, 0), 30),
    "propsyard": ((34, 10, -46), (42, 3, -90), 30),
    "trailers": ((-34, 10, 46), (-42, 3, 90), 30),
    "greenscreen": ((-34, 10, -46), (-42, 3, -90), 30),
    "foodcorner": ((34, 10, 46), (42, 3, 90), 30),
    "busstop": ((82, 9, -4), (98, 4, -24), 30),
    "boulevardend": ((96, 9, 16), (124, 4, 2), 30),
    "spawn": ((0, 7, -17), (0, 6, 40), 28),
}


def roblox(p):
    x, y, z = p
    return (-x, z, y)


def main(names):
    parts = [p for p in kit.dump("map") if p["name"] not in ("SearchlightBeam",)]
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
