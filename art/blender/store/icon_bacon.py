"""Store icon, Roblox front-page style: a star-struck bacon-hair player in a director's beret
holds the glowing rainbow star they just pulled up high. compose_roblox.py puts it on a sunburst and
sizes it to 512.

Renders $STORE_OUT/icon_bacon.png (1024 x 1024, transparent background).
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bacon  # noqa: E402
import kit  # noqa: E402

RAINBOW = [(0.0, "#FF2238"), (0.2, "#FF8A00"), (0.4, "#FFE000"), (0.6, "#1FD14A"), (0.8, "#1E7BFF"), (1.0, "#A22BFF")]
STAR_AT = Vector((-2.05, -0.5, 5.75))


def build(size=1024, samples=128):
    kit.new_scene(size, size, samples=samples, transparent=True)
    kit.sky(top="#9FD4FF", middle="#7DB8F0", horizon="#5A8FD0", glow="#3A6AB0", strength=0.8)
    cam = kit.camera((0.9, -8.0, 4.2), (-0.45, 0, 4.25), lens=52)
    with kit.collect() as player:
        bacon.avatar("Player", (0, 0, 0), yaw=-6, face="starstruck", hat="beret",
                     face_span=0.88, pose={"arm_r": (-168, -22, 0), "arm_l": (-12, 0, -6), "head": (10, -6, -16)})
    # The pull: a fat rainbow star, glowing, held up high.
    star_mat = kit.ramp_material("RainbowStar", RAINBOW, axis="X", emission=0.45)
    star = kit.add_object("PullStar", kit.star_mesh("PullStar", 1.0, 0.48, 0.45), star_mat, STAR_AT, (0, -14, 0), bevel=0.12)
    star.modifiers["Bevel"].segments = 4
    kit.light("POINT", STAR_AT + Vector((0, -0.4, 0.6)), 90, "#FFE9A8", size=0.6, name="StarGlow")
    kit.glow_disc("StarAura", STAR_AT + Vector((0, 0.3, 0)), 1.6, "#FFF2B0", strength=0.8, facing=cam.location, power=2.0)
    rnd = random.Random(2)
    for i in range(9):
        a = rnd.uniform(0.55 * math.pi, 1.6 * math.pi)  # round the star, away from the face
        r = rnd.uniform(1.3, 2.4)
        kit.sparkle(f"Glint{i}", STAR_AT + Vector((math.cos(a) * r, -0.6, math.sin(a) * r)), size=rnd.uniform(0.12, 0.26), strength=10, face=cam)
    kit.light("AREA", (-4, -8, 9), 1500, "#FFF6E8", target=(0, 0, 4.5), size=7, name="Key")
    kit.light("AREA", (5, -7, 3), 600, "#DCEBFF", target=(0, 0, 4.5), size=6, name="Fill")
    for sx, color in ((-1, "#FFC8F4"), (1, "#9FE6FF")):
        rim = kit.light("AREA", (sx * 5, 4, 8), 2200, color, target=(0, 0, 4.8), size=3, name=f"Rim{sx}")
        kit.light_only(rim, player.objects)
    kit.glare(threshold=1.3, size=7, mix=-0.6)


if __name__ == "__main__":
    build()
    kit.render(os.path.join(kit.OUT, "icon_bacon.png"))
