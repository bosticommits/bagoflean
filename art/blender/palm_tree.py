"""PalmTree: chunky curved palm for the lots and the boulevard (about 15 studs tall).

Run from the repo root (see mmkit.py for the commands). Writes art/previews/palm_tree_*.png
and art/exports/palm_tree.fbx. In Studio, import it and name the MeshPart "PalmTree" (see
art/README.md).
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

HEIGHT = 15.0  # studs to the top of the crown
SEGMENTS = 7
LEAN = math.radians(14)  # total lean of the trunk, toward +X


def trunk_point(t):
    """Point along the trunk centre line (studs), t from 0 to 1. Leans more near the top."""
    angle = LEAN * t * t
    x = HEIGHT * 0.85 * (LEAN / 2) * t**3
    return Vector((x, 0, HEIGHT * 0.85 * t)), angle


def frond(m, mat, matrix, pitch, pieces=5, length=1.8):
    """One arching blade: a three-sided strip (flat underside, raised rib on top) that tapers to
    a short point and droops toward the tip. Starts at the crown origin, pointing along +Y."""
    rings, pos = [], Vector((0, 0, 0.7))
    for k in range(pieces):
        width = 1.7 * (1 - k / (pieces + 1)) + 0.25
        up = Vector((0, -math.sin(pitch), math.cos(pitch)))
        rings.append([pos + Vector((-width / 2, 0, 0)), pos + Vector((width / 2, 0, 0)), pos + up * 0.3])
        pos = pos + Vector((0, math.cos(pitch), math.sin(pitch))) * (length if k < pieces - 1 else length / 2)
        pitch -= math.radians(22)  # droops more toward the tip
    verts = [mmkit.studs(1) * v for ring in rings for v in ring] + [mmkit.studs(1) * pos]
    tip = len(verts) - 1
    faces = [(0, 2, 1)]
    for i in range(pieces - 1):
        for k in range(3):
            n = (k + 1) % 3
            faces.append((3 * i + k, 3 * i + n, 3 * i + 3 + n, 3 * i + 3 + k))
    last = 3 * (pieces - 1)
    faces += [(last + k, last + (k + 1) % 3, tip) for k in range(3)]
    m._add(verts, faces, mat, matrix)


def build():
    m = mmkit.Model("PalmTree")
    bark = m.mat("Bark")
    wood = m.mat("Wood")
    leaf = m.mat("Green")
    leaf_dark = m.mat("DarkGreen")
    nut = m.mat("#6B4426")

    # Trunk: stacked tapered hexagons, each wider at its foot than the one below ends, so the
    # rings read as a palm trunk.
    for i in range(SEGMENTS):
        t0 = i / SEGMENTS
        p, angle = trunk_point(t0)
        length = HEIGHT * 0.85 / SEGMENTS
        r0 = 0.85 - 0.35 * t0
        r1 = 0.85 - 0.35 * (i + 1) / SEGMENTS
        matrix = Matrix.Translation(Vector([mmkit.studs(c) for c in p])) @ Matrix.Rotation(angle, 4, "Y")
        m.lathe([(r0 * 1.15, 0), (r1 * 0.95, length + 0.05)], bark if i % 2 == 0 else wood, segments=6, matrix=matrix)

    top, top_angle = trunk_point(1.0)
    crown = Matrix.Translation(Vector([mmkit.studs(c) for c in top])) @ Matrix.Rotation(top_angle * 0.5, 4, "Y")
    m.lathe([(0, -0.3), (1.1, 0.3), (0.6, 1.0), (0, 1.1)], leaf_dark, segments=6, matrix=crown)

    # Fronds: 8 arching blades, alternating two greens.
    fronds = 8
    for f in range(fronds):
        yaw = 2 * math.pi * f / fronds + 0.2
        pitch = math.radians(28 + (f % 3) * 6)  # starts rising
        frond(m, leaf if f % 2 == 0 else leaf_dark, crown @ Matrix.Rotation(yaw, 4, "Z"), pitch)

    # Coconuts tucked under the crown.
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        at = Vector((0.75 * math.cos(a), 0.75 * math.sin(a), -0.35))
        m.lathe(
            [(0, -0.45), (0.45, 0), (0, 0.45)],
            nut,
            segments=4,
            matrix=crown @ Matrix.Translation(Vector([mmkit.studs(c) for c in at])),
        )
    return m.obj()


mmkit.finish(build(), "palm_tree", max_tris=450)
