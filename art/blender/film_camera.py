"""FilmCamera: vintage movie camera on a tripod, with two film reels on top.

About 6.5 studs tall, lens facing the front (-Y). Stands outside each owned sound stage.
In Studio, name the MeshPart "FilmCamera".
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402



def T(x, y, z):
    return Matrix.Translation(Vector((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z))))


def build():
    m = mmkit.Model("FilmCamera")
    body = m.mat("Charcoal", metallic=0.2)
    trim = m.mat("Gold", metallic=0.5)
    steel = m.mat("Steel", metallic=0.5)
    red = m.mat("Carpet")
    glass = m.mat("Blue", metallic=0.3)
    wood = m.mat("Wood")

    # Tripod: three splayed legs to a head plate.
    head_z = 3.6
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        foot = Vector((1.5 * math.cos(a), 1.5 * math.sin(a), 0))
        top = Vector((0.25 * math.cos(a), 0.25 * math.sin(a), head_z))
        mid = (foot + top) / 2
        d = top - foot
        tilt = math.atan2(math.hypot(d.x, d.y), d.z)
        heading = math.atan2(d.y, d.x)
        leg = (
            T(mid.x, mid.y, mid.z)
            @ Matrix.Rotation(heading, 4, "Z")
            @ Matrix.Rotation(tilt, 4, "Y")
        )
        m.box((0.3, 0.3, d.length), mat=wood, matrix=leg)
        m.box((0.45, 0.45, 0.25), at=(foot.x, foot.y, 0.12), mat=body)
    m.lathe([(0, head_z - 0.2), (0.6, head_z - 0.2), (0.6, head_z + 0.1), (0, head_z + 0.1)], steel, segments=8)

    # Camera body with a gold trim band.
    base = head_z + 0.1
    m.box((1.4, 2.4, 1.6), at=(0, 0.1, base + 0.8), mat=body)
    m.box((1.5, 2.5, 0.2), at=(0, 0.1, base + 0.3), mat=trim)
    m.box((0.1, 1.2, 0.7), at=(0.75, 0.3, base + 0.9), mat=red)  # side plate
    # Lens barrel and hood toward -Y.
    m.cylinder(0.45, 0.9, at=(0, -1.5, base + 0.9), mat=steel, segments=12, axis="Y")
    m.cylinder(0.6, 0.35, at=(0, -2.1, base + 0.9), mat=body, segments=12, axis="Y")
    m.cylinder(0.42, 0.05, at=(0, -2.3, base + 0.9), mat=glass, segments=12, axis="Y")
    # Viewfinder and crank.
    m.box((0.35, 0.8, 0.35), at=(-0.85, 0.5, base + 1.3), mat=body)
    m.cylinder(0.08, 0.6, at=(0.95, 0.5, base + 0.7), mat=trim, segments=6, axis="X")
    m.box((0.12, 0.12, 0.5), at=(1.25, 0.5, base + 0.5), mat=trim)

    # Two big reels on top (front and back), with spokes.
    for y, r in ((-0.55, 1.05), (0.95, 1.05)):
        z = base + 1.6 + r
        m.cylinder(r, 0.3, at=(0, y, z), mat=steel, segments=16, axis="X")
        m.cylinder(r + 0.08, 0.12, at=(0.2, y, z), mat=trim, segments=16, axis="X")
        m.cylinder(r + 0.08, 0.12, at=(-0.2, y, z), mat=trim, segments=16, axis="X")
        for k in range(3):
            a = 2 * math.pi * k / 3
            m.cylinder(0.22, 0.34, at=(0, y + 0.55 * math.cos(a), z + 0.55 * math.sin(a)), mat=body, segments=8, axis="X")
    return m.obj()


mmkit.finish(build(), "film_camera", max_tris=2000)
