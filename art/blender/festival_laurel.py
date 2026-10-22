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
LEAVES = 6  # per branch


def T(x, y, z):
    return Matrix.Translation(Vector((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z))))


def R(angle, axis):
    return Matrix.Rotation(angle, 4, axis)


def leaf(m, mat, matrix, size=1.0):
    """A pointed low-poly leaf in the XZ plane, along +Z from its stem at the origin."""
    w, t = mmkit.studs(0.15 * size), mmkit.studs(0.04)
    length = mmkit.studs(0.62 * size)
    verts = [
        (0, 0, 0),
        (-w, -t, length * 0.45),
        (w, -t, length * 0.45),
        (0, 0, length),
        (-w, t, length * 0.45),
        (w, t, length * 0.45),
    ]
    faces = [(0, 2, 1), (1, 2, 3), (0, 1, 4), (0, 4, 5), (0, 5, 2), (4, 3, 5), (1, 3, 4), (2, 5, 3)]
    m._add(verts, faces, mat, matrix)


def build():
    m = mmkit.Model("FestivalLaurel")
    gold = m.mat("Gold", metallic=0.6, roughness=0.3)
    dark_gold = m.mat("#C98A1A", metallic=0.6, roughness=0.35)
    film = m.mat("Charcoal", metallic=0.2)
    shine = m.mat("Light", emission=0.6)

    # Round foot and a short stem up to the wreath.
    m.lathe([(0, 0), (0.95, 0), (0.95, 0.22), (0.7, 0.32), (0.32, 0.42), (0.22, 0.62), (0, 0.62)], dark_gold, segments=14)
    m.cylinder(0.16, 0.3, at=(0, 0, 0.72), mat=gold, segments=8)

    # The film reel, facing the front: a gold disc with a dark film band and five round holes.
    reel = T(0, 0, REEL_Z)
    m.cylinder(REEL_R, 0.22, mat=gold, segments=18, matrix=reel, axis="Y")
    m.cylinder(REEL_R * 0.86, 0.26, mat=film, segments=18, matrix=reel, axis="Y")
    m.cylinder(REEL_R * 0.62, 0.3, mat=gold, segments=18, matrix=reel, axis="Y")
    for k in range(5):
        a = math.pi / 2 + 2 * math.pi * k / 5
        x, z = math.cos(a) * REEL_R * 0.36, math.sin(a) * REEL_R * 0.36
        m.cylinder(0.11, 0.34, at=(x, 0, z), mat=film, segments=8, matrix=reel, axis="Y")
    m.cylinder(0.12, 0.36, mat=shine, segments=8, matrix=reel, axis="Y")

    # Two laurel branches curving up either side of the reel, from the stem to near the top.
    for side in (-1, 1):
        # The branch: a thin bent stalk of short segments.
        steps = 8
        for i in range(steps):
            a0 = math.radians(-72 + 125 * i / steps)
            a1 = math.radians(-72 + 125 * (i + 1) / steps)
            p0 = Vector((side * math.cos(a0) * WREATH_R, 0, REEL_Z + math.sin(a0) * WREATH_R))
            p1 = Vector((side * math.cos(a1) * WREATH_R, 0, REEL_Z + math.sin(a1) * WREATH_R))
            mid = (p0 + p1) / 2
            direction = (p1 - p0).normalized()
            tilt = math.atan2(direction.x, direction.z)
            half = (p1 - p0).length / 2
            m.lathe(
                [(0, -half - 0.05), (0.07, -half), (0.07, half), (0, half + 0.05)],
                dark_gold,
                segments=6,
                matrix=T(mid.x, mid.y, mid.z) @ R(tilt, "Y"),
            )
        # Leaves in pairs along it, pointing up the branch and splaying in and out.
        for i in range(LEAVES):
            a = math.radians(-64 + 120 * i / (LEAVES - 1))
            size = 1.15 - 0.35 * i / (LEAVES - 1)  # big at the foot, small at the tips
            cx, cz = side * math.cos(a) * WREATH_R, REEL_Z + math.sin(a) * WREATH_R
            # Tangent up the branch.
            tangent = math.atan2(side * -math.sin(a), math.cos(a))
            for splay in (-1, 1):
                lean = tangent + side * splay * math.radians(30)
                face_turn = R(splay * math.radians(12), "Z")
                leaf(m, gold, T(cx, 0, cz) @ R(lean, "Y") @ face_turn, size)
        # The leaf at the tip, straight on.
        tip = math.radians(56)
        leaf(m, gold, T(side * math.cos(tip) * WREATH_R, 0, REEL_Z + math.sin(tip) * WREATH_R) @ R(math.atan2(side * -math.sin(tip), math.cos(tip)), "Y"), 0.85)
        # A berry where the branch starts.
        m.lathe([(0, -0.11), (0.11, 0), (0, 0.11)], dark_gold, segments=6, matrix=T(side * 0.28, 0, REEL_Z - WREATH_R + 0.08))

    # A little star on top, between the branch tips.
    star_z = REEL_Z + WREATH_R + 0.28
    points = []
    for k in range(10):
        r = 0.3 if k % 2 == 0 else 0.13
        a = math.pi / 2 + math.pi * k / 5
        points.append((math.cos(a) * r, math.sin(a) * r))
    depth = mmkit.studs(0.1)
    verts = [(mmkit.studs(x), -depth, mmkit.studs(z)) for x, z in points] + [(mmkit.studs(x), depth, mmkit.studs(z)) for x, z in points]
    verts += [(0, -depth * 1.8, 0), (0, depth * 1.8, 0)]
    faces = []
    for k in range(10):
        j = (k + 1) % 10
        faces.append((20, j, k))
        faces.append((21, 10 + k, 10 + j))
        faces.append((k, j, 10 + j, 10 + k))
    m._add(verts, faces, shine, T(0, 0, star_z))
    return m.obj()


mmkit.finish(build(), "festival_laurel", max_tris=2000)
