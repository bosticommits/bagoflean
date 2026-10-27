"""FestivalLaurel: the Film Festival prize, a gold laurel wreath round a film reel on a round foot.

About 2.6 studs tall, facing the front (-Y). Players earn one each week they finish all three
Film Festival goals; it stands on a plinth on their lot whose plaque takes the festival's genre
color (the plinth is Roblox parts, so one mesh serves every genre). In Studio, name the MeshPart
"FestivalLaurel".
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

REEL_Z = 1.55  # reel centre height
REEL_R = 0.72
WREATH_R = 1.02  # leaves sit on this circle round the reel centre
LEAVES = 4  # per branch, in pairs


def T(x, y, z):
    return Matrix.Translation(Vector((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z))))


def R(angle, axis):
    return Matrix.Rotation(angle, 4, axis)


def leaf(m, mat, matrix, size=1.0):
    """A pointed low-poly leaf in the XZ plane, along +Z from its stem at the origin: a ridge
    on the front (-Y), flat at the back. 6 triangles."""
    w, t = mmkit.studs(0.17 * size), mmkit.studs(0.07)
    length = mmkit.studs(0.7 * size)
    verts = [(0, 0, 0), (w, 0, length * 0.45), (0, 0, length), (-w, 0, length * 0.45), (0, -t, length * 0.45)]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)]
    m._add(verts, faces, mat, matrix)


def stalk(m, mat, side):
    """The bent branch as one three-sided tube along the wreath circle."""
    steps, r = 4, 0.08
    rings = []
    for i in range(steps + 1):
        a = math.radians(-72 + 128 * i / steps)
        c = Vector((side * math.cos(a) * WREATH_R, 0, REEL_Z + math.sin(a) * WREATH_R))
        out = Vector((side * math.cos(a), 0, math.sin(a)))
        rings.append([c + r * (math.cos(b) * out + math.sin(b) * Vector((0, 1, 0))) for b in (2 * math.pi * k / 3 for k in range(3))])
    verts = [mmkit.studs(1) * v for ring in rings for v in ring]
    faces = [(3 * i + k, 3 * i + (k + 1) % 3, 3 * i + 3 + (k + 1) % 3, 3 * i + 3 + k) for i in range(steps) for k in range(3)]
    faces += [(0, 1, 2), (3 * steps + 2, 3 * steps + 1, 3 * steps)]
    m._add(verts, faces, mat, Matrix.Identity(4))


def build():
    m = mmkit.Model("FestivalLaurel")
    gold = m.mat("Gold", metallic=0.6, roughness=0.3)
    dark_gold = m.mat("#C98A1A", metallic=0.6, roughness=0.35)
    film = m.mat("Charcoal", metallic=0.2)
    shine = m.mat("Light", emission=0.6)

    # Round foot and the stem up to the wreath, in one piece.
    m.lathe([(0.95, 0), (0.95, 0.22), (0.16, 0.6), (0.16, 0.9), (0, 0.9)], dark_gold, segments=8)

    # The film reel, facing the front: a gold disc with a dark film band and five holes.
    reel = T(0, 0, REEL_Z)
    m.cylinder(REEL_R, 0.22, mat=gold, segments=8, matrix=reel, axis="Y")
    m.cylinder(REEL_R * 0.86, 0.26, mat=film, segments=8, matrix=reel, axis="Y")
    m.cylinder(REEL_R * 0.62, 0.3, mat=gold, segments=8, matrix=reel, axis="Y")
    for k in range(5):
        a = math.pi / 2 + 2 * math.pi * k / 5
        x, z = math.cos(a) * REEL_R * 0.36, math.sin(a) * REEL_R * 0.36
        m.cylinder(0.12, 0.34, at=(x, 0, z), mat=film, segments=4, matrix=reel, axis="Y")

    # Two laurel branches curving up either side of the reel, from the stem to near the top.
    for side in (-1, 1):
        stalk(m, dark_gold, side)
        # Leaves in pairs along it, pointing up the branch and splaying in and out.
        for i in range(LEAVES):
            a = math.radians(-64 + 120 * i / (LEAVES - 1))
            size = 1.3 - 0.4 * i / (LEAVES - 1)  # big at the foot, small at the tips
            cx, cz = side * math.cos(a) * WREATH_R, REEL_Z + math.sin(a) * WREATH_R
            # Tangent up the branch.
            tangent = math.atan2(side * -math.sin(a), math.cos(a))
            for splay in (-1, 1):
                lean = tangent + side * splay * math.radians(30)
                face_turn = R(splay * math.radians(12), "Z")
                leaf(m, gold, T(cx, 0, cz) @ R(lean, "Y") @ face_turn, size)
        # The leaf at the tip, straight on.
        tip = math.radians(56)
        leaf(m, gold, T(side * math.cos(tip) * WREATH_R, 0, REEL_Z + math.sin(tip) * WREATH_R) @ R(math.atan2(side * -math.sin(tip), math.cos(tip)), "Y"), 0.9)

    # A little star on top, between the branch tips.
    star_z = REEL_Z + WREATH_R + 0.28
    points = []
    for k in range(10):
        r = 0.3 if k % 2 == 0 else 0.13
        a = math.pi / 2 + math.pi * k / 5
        points.append((math.cos(a) * r, math.sin(a) * r))
    # One outline ring and a pole front and back: a faceted star in 20 triangles.
    depth = mmkit.studs(0.18)
    verts = [(mmkit.studs(x), 0, mmkit.studs(z)) for x, z in points] + [(0, -depth, 0), (0, depth, 0)]
    faces = []
    for k in range(10):
        j = (k + 1) % 10
        faces.append((10, j, k))
        faces.append((11, k, j))
    m._add(verts, faces, shine, T(0, 0, star_z))
    return m.obj()


mmkit.finish(build(), "festival_laurel", max_tris=400)
