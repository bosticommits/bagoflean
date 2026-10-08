"""Store icon, Roblox front-page style: a star-struck bacon-hair player in a director's beret,
with a clapperboard. compose_roblox.py puts it on a sunburst and sizes it to 512.

Renders $STORE_OUT/icon_bacon.png (1024 x 1024, transparent background).
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bacon  # noqa: E402
import kit  # noqa: E402
import logo  # noqa: E402


def build(size=1024, samples=128):
    kit.new_scene(size, size, samples=samples, transparent=True)
    kit.sky(top="#9FD4FF", middle="#7DB8F0", horizon="#5A8FD0", glow="#3A6AB0", strength=0.8)
    cam = kit.camera((0.9, -9.5, 5.2), (0.1, 0, 4.55), lens=72)
    with kit.collect() as player:
        bacon.avatar("Player", (0, 0, 0), yaw=-10, face="starstruck", hat="beret",
                     head_scale=1.3,
                     pose={"arm_r": (-25, 6, 0), "arm_l": (-20, -6, 0), "head": (-4, -12, 4), "body": (4, 0, 0)})
    logo.clapperboard("Clapper", (-1.45, -2.4, 3.05), rotation=(4, -18, 16), size=0.42, open_angle=30)
    for i, (x, z, s) in enumerate([(-1.9, 6.6, 0.3), (1.9, 6.55, 0.24), (2.1, 4.3, 0.2)]):
        kit.sparkle(f"Glint{i}", (x, -1.5, z), size=s, strength=9, face=cam)
    for i, (x, z, s, r) in enumerate([(1.95, 5.6, 0.3, 14), (-2.1, 5.3, 0.26, -12)]):
        kit.gold_star(f"Star{i}", (x, -1, z), (0, r, 0), size=s, color="#FFD23F", emission=0.4)
    key = kit.light("AREA", (-4, -8, 9), 1800, "#FFF6E8", target=(0, 0, 4.5), size=7, name="Key")
    kit.light("AREA", (5, -7, 3), 700, "#DCEBFF", target=(0, 0, 4.5), size=6, name="Fill")
    for sx, color in ((-1, "#FFC8F4"), (1, "#9FE6FF")):
        kit.light("AREA", (sx * 5, 4, 8), 1600, color, target=(0, 0, 4.8), size=3, name=f"Rim{sx}")
    kit.glare(threshold=1.4, size=6, mix=-0.7)
    return key, player


if __name__ == "__main__":
    build()
    kit.render(os.path.join(kit.OUT, "icon_bacon.png"))
