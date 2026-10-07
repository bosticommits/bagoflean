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


def build():
    m = mmkit.Model("PalmTree")
    bark = m.mat("Bark")
    wood = m.mat("Wood")
    leaf = m.mat("Green")
    leaf_dark = m.mat("DarkGreen")
    nut = m.mat("#6B4426")

    # Trunk: stacked tapered octagons with a lip on each, so it reads as a palm trunk.
    for i in range(SEGMENTS):
        t0 = i / SEGMENTS
        p, angle = trunk_point(t0)
        length = HEIGHT * 0.85 / SEGMENTS
        r0 = 0.85 - 0.35 * t0
        r1 = 0.85 - 0.35 * (i + 1) / SEGMENTS
        matrix = Matrix.Translation(Vector([mmkit.studs(c) for c in p])) @ Matrix.Rotation(angle, 4, "Y")
        m.lathe(
            [(0, 0), (r0 * 1.12, 0), (r0 * 1.12, 0.3), (r0, 0.45), (r1, length + 0.05), (0, length + 0.05)],
            bark if i % 2 == 0 else wood,
            segments=8,
            matrix=matrix,
        )

    top, top_angle = trunk_point(1.0)
    crown = Matrix.Translation(Vector([mmkit.studs(c) for c in top])) @ Matrix.Rotation(top_angle * 0.5, 4, "Y")
    m.lathe([(0, -0.3), (1.0, -0.2), (1.1, 0.5), (0.6, 1.0), (0, 1.1)], leaf_dark, segments=8, matrix=crown)

    # Fronds: 8 arching blades made of tapering boxes, alternating two greens.
    fronds = 8
    for f in range(fronds):
        yaw = 2 * math.pi * f / fronds + 0.2
        color = leaf if f % 2 == 0 else leaf_dark
        pos = Vector((0, 0, 0.7))
        pitch = math.radians(28 + (f % 3) * 6)  # starts rising
        pieces = 5
        for k in range(pieces):
            length = 1.6
            width = 1.7 * (1 - k / (pieces + 1)) + 0.25
            direction = Vector((0, math.cos(pitch), math.sin(pitch)))
            mid = pos + direction * (length / 2)
            local = (
                Matrix.Rotation(yaw, 4, "Z")
                @ Matrix.Translation(Vector([mmkit.studs(c) for c in mid]))
                @ Matrix.Rotation(pitch, 4, "X")
            )
            m.box((width, length + 0.15, 0.22), mat=color, matrix=crown @ local)
            pos = pos + direction * length
            pitch -= math.radians(22)  # droops more toward the tip

    # Coconuts tucked under the crown.
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        at = Vector((0.75 * math.cos(a), 0.75 * math.sin(a), -0.35))
        m.lathe(
            [(0, -0.45), (0.35, -0.3), (0.45, 0), (0.35, 0.3), (0, 0.45)],
            nut,
            segments=6,
            matrix=crown @ Matrix.Translation(Vector([mmkit.studs(c) for c in at])),
        )
    return m.obj()


mmkit.finish(build(), "palm_tree", max_tris=2000)
