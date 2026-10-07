"""Searchlight: premiere searchlight on a turret (the light beam itself is a Roblox part).

About 4.5 studs tall, the drum aimed up and toward the front (-Y). Placed on the grand cinema's
roof. In Studio, name the MeshPart "Searchlight".
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

AIM = math.radians(65)  # drum tilt above the horizon


def T(x, y, z):
    return Matrix.Translation(Vector((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z))))


def build():
    m = mmkit.Model("Searchlight")
    dark = m.mat("Charcoal", metallic=0.3)
    steel = m.mat("Steel", metallic=0.5)
    red = m.mat("Carpet")
    gold = m.mat("Gold", metallic=0.4)
    lens = m.mat("Light", emission=4.0)

    # Turret: square platform, round turntable.
    m.box((2.6, 2.6, 0.5), at=(0, 0, 0.25), mat=red)
    m.box((2.2, 2.2, 0.2), at=(0, 0, 0.6), mat=dark)
    m.lathe([(0, 0.7), (1.0, 0.7), (1.0, 1.0), (0.8, 1.1), (0, 1.1)], steel, segments=12)
    # Yoke arms.
    for side in (-1, 1):
        m.box((0.3, 0.7, 2.0), at=(side * 1.05, 0, 2.0), mat=dark)
    # Drum on its pivot, aimed up and forward.
    pivot = T(0, 0, 2.6) @ Matrix.Rotation(math.pi / 2 - AIM, 4, "X")
    m.cylinder(0.85, 2.4, at=(0, 0, 0.3), mat=steel, segments=14, matrix=pivot)
    m.cylinder(0.95, 0.3, at=(0, 0, 1.45), mat=gold, segments=14, matrix=pivot)
    m.cylinder(0.75, 0.1, at=(0, 0, 1.62), mat=lens, segments=14, matrix=pivot)
    m.cylinder(0.6, 0.4, at=(0, 0, -1.05), mat=dark, segments=10, matrix=pivot)
    m.cylinder(0.18, 2.5, at=(0, 0, 0), mat=gold, segments=8, matrix=pivot @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    # Cooling fins along the drum.
    for k in range(4):
        m.box((1.95, 0.15, 0.15), at=(0, 0, -0.5 + k * 0.45), mat=dark, matrix=pivot @ T(0, 0.8, 0))
    return m.obj()


mmkit.finish(build(), "searchlight", max_tris=2000)
