"""Studio mascots: six chunky toy companions that follow their owner around town.

  PopcornPup      Popcorn Pup       a puppy wearing a popcorn bucket
  ClapperCroc     Clapper Croc      a crocodile whose top jaw is a clapperboard
  ReelKitty       Reel Kitty        a cat with film reels for ears
  CameraBot       Camera Bot        a film-camera robot riding a rocket flame
  SpotlightOwl    Spotlight Owl     an owl whose eyes are spotlights
  PremiereDragon  Premiere Dragon   a baby dragon in red-carpet colours

Each mascot is built from rounded shapes in the Roblox front-page toy style: big heads, glossy
eyes and a thick dark outline (an "inverted hull": a slightly bigger copy of each big shape, turned
inside out, which Roblox draws only from behind, so it shows as a rim round the model).

Each mascot is split into moving pieces (P below: legs, tail, head, ears, wings, reels, flame...),
one mesh each, named <id>_<piece> ("PopcornPup_Tail"). The game turns each piece about its pivot
(src/shared/Models/MascotRig.luau) to make the mascot trot, jump, wag and look around.

The same shapes are also written to src/shared/Models/MascotShapes.luau (with the pieces and their
pivots), which the game uses to build a part version of each mascot until the meshes are imported
(art/README.md). So the Blender design is the one source for both: edit the shapes here and run
this script again.

Run from the repo root with Blender, or with the `bpy` package (see mmkit.py):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/mascots.py
Writes art/exports/mascots.fbx (every piece of all six), art/previews/mascots.png (the line-up)
and one art/previews/mascot_<name>.png each. Set MASCOT_SAMPLES for quicker test renders.
art/preview/mascot_moves.py renders the animations as a GIF.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

STUD = mmkit.STUD
OUTLINE = 0.09  # outline thickness, studs
INK = "#1E1630"
LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "MascotShapes.luau")
SAMPLES = int(os.environ.get("MASCOT_SAMPLES", "64"))

# --- Shapes ----------------------------------------------------------------------------------
# Blender coordinates in studs: Z up, the mascot faces -Y, feet on Z = 0.


def E(at, radii, color, rot=(0, 0, 0), outline=None, neon=False):
    """Ellipsoid centred on `at` with half-sizes `radii`. Outlined if it is big enough."""
    if outline is None:
        outline = min(radii) >= 0.12 and max(radii) >= 0.2
    return {"kind": "ball", "at": at, "size": tuple(2 * r for r in radii), "color": color, "rot": rot, "outline": outline, "neon": neon}


def B(at, size, color, rot=(0, 0, 0), bevel=0.12, outline=True, neon=False):
    """Rounded box centred on `at`."""
    return {"kind": "box", "at": at, "size": size, "color": color, "rot": rot, "bevel": bevel, "outline": outline, "neon": neon}


def C(at, radius, length, color, rot=(0, 0, 0), outline=True, neon=False):
    """Cylinder centred on `at`, its axis along local Z (rotate it to point elsewhere)."""
    return {"kind": "cyl", "at": at, "size": (2 * radius, 2 * radius, length), "color": color, "rot": rot, "outline": outline, "neon": neon}


def G(at, rot, *children):
    """A group: its children's positions and rotations are relative to it."""
    return {"kind": "group", "at": at, "rot": rot, "children": children}


def P(name, role, pivot, *children, axis=(0, 0, 1), amp=1.0, phase=0.0):
    """A moving piece. Its children are in the same coordinates as the piece itself (a piece does
    not move them in Blender); in the game they turn about `pivot` the way `role` says
    (MascotRig.luau): leg, tail, head, ear, hat, wing, arm, spin, tape, flame or jaw. `axis` is the
    turning axis for spin and wing, or the sliding direction for tape. `amp` scales the motion
    (for tape it is the gap the tape slides before it starts again) and `phase` delays it."""
    return {"kind": "piece", "name": name, "role": role, "at": pivot, "rot": (0, 0, 0), "axis": axis, "amp": amp, "phase": phase, "children": children}


def mirror(shape):
    """The same shape on the other side (x -> -x), for ears, legs and eyes."""
    if shape["kind"] == "piece":
        name = shape["name"][:-1] + "R" if shape["name"].endswith("L") else shape["name"]
        ax, ay, az = shape["axis"]
        return {**shape, "name": name, "at": (-shape["at"][0], *shape["at"][1:]), "axis": (-ax, ay, az), "children": tuple(mirror(c) for c in shape["children"])}
    if shape["kind"] == "group":
        rx, ry, rz = shape["rot"]
        return {**shape, "at": (-shape["at"][0], *shape["at"][1:]), "rot": (rx, -ry, -rz), "children": tuple(mirror(c) for c in shape["children"])}
    rx, ry, rz = shape["rot"]
    return {**shape, "at": (-shape["at"][0], *shape["at"][1:]), "rot": (rx, -ry, -rz)}


def pair(*shapes):
    out = list(shapes)
    out += [mirror(s) for s in shapes]
    return out


def eye(at, size=1.0, iris=None, look=(0, 0)):
    """A big glossy cartoon eye: white, a dark pupil (or a coloured iris) and a sparkle."""
    x, y, z = at
    lx, lz = look
    white = E((x, y, z), (0.2 * size, 0.1 * size, 0.24 * size), "#FFFFFF", outline=True)
    parts = [white]
    if iris:
        parts.append(E((x + lx, y - 0.075 * size, z + lz), (0.14 * size, 0.06 * size, 0.18 * size), iris, outline=False))
    parts.append(E((x + lx, y - 0.1 * size, z + lz - 0.01), (0.1 * size, 0.06 * size, 0.14 * size), "#161220", outline=False))
    parts.append(E((x + lx - 0.045 * size, y - 0.15 * size, z + lz + 0.06 * size), (0.045 * size, 0.025 * size, 0.05 * size), "#FFFFFF", outline=False))
    return parts


def leg(name, at, radii, color, paw=None, pivot_up=0.32):
    """A leg the game swings from its hip (`pivot_up` studs above the leg's centre)."""
    x, y, z = at
    shapes = [E(at, radii, color)]
    if paw:
        shapes.append(E((x, y - 0.08, 0.08), (radii[0] * 0.92, radii[1] * 1.05, 0.1), paw, outline=False))
    return P(name, "leg", (x, y, z + pivot_up), *shapes)


def popcorn_pup():
    tan, cream, brown = "#EDB872", "#FFF1D6", "#A8693B"
    red, white, corn = "#E8333A", "#FFF8EE", "#FFE58A"
    shapes = [
        E((0, 0.3, 1.0), (0.72, 0.9, 0.68), tan),
        E((0, -0.18, 0.88), (0.5, 0.45, 0.5), cream),
        *pair(
            leg("LegFL", (0.42, -0.32, 0.3), (0.24, 0.27, 0.3), tan, paw=cream),
            leg("LegBL", (0.45, 0.82, 0.3), (0.25, 0.3, 0.3), tan),
        ),
        P("Tail", "tail", (0, 1.08, 1.18), E((0, 1.25, 1.45), (0.15, 0.15, 0.38), tan, rot=(-35, 0, 0))),
        P(
            "Head",
            "head",
            (0, -0.4, 1.6),
            E((0, -0.55, 2.02), (0.86, 0.76, 0.76), tan),
            E((0, -1.18, 1.82), (0.42, 0.3, 0.3), cream),
            E((0, -1.46, 1.95), (0.17, 0.1, 0.12), "#3A2A2A", outline=False),
            E((0, -1.33, 1.6), (0.13, 0.06, 0.1), "#FF7A8A", outline=False),
            *eye((0.32, -1.17, 2.24)),
            *eye((-0.32, -1.17, 2.24)),
            # Floppy ears hang from the top of the head and swing as it moves.
            *pair(P("EarL", "ear", (0.68, -0.42, 2.5), E((0.82, -0.42, 2.02), (0.22, 0.3, 0.55), brown, rot=(0, -22, 0)))),
            # The popcorn bucket hat, tipped a little to one side; it wobbles when the pup lands.
            P(
                "Hat",
                "hat",
                (0.12, -0.5, 2.62),
                G(
                    (0.12, -0.5, 2.88),
                    (-8, 12, 0),
                    C((0, 0, 0), 0.46, 0.62, red),
                    *[B((0.465 * math.cos(a), 0.465 * math.sin(a), 0), (0.16, 0.05, 0.6), white, rot=(0, 0, math.degrees(a) + 90), bevel=0.02, outline=False) for a in (i * math.pi / 4 for i in range(8))],
                    C((0, 0, 0.33), 0.5, 0.1, white),
                    E((0, 0, 0.42), (0.22, 0.22, 0.2), corn),
                    E((0.24, 0.1, 0.42), (0.18, 0.18, 0.16), corn),
                    E((-0.22, 0.12, 0.44), (0.18, 0.18, 0.17), corn),
                    E((0.05, -0.25, 0.43), (0.18, 0.18, 0.16), corn),
                    E((-0.08, 0.26, 0.47), (0.17, 0.17, 0.16), corn),
                    E((0.05, 0.02, 0.6), (0.16, 0.16, 0.15), corn),
                ),
            ),
        ),
    ]
    return shapes


def clapper_croc():
    """A chunky baby crocodile: long low body, stubby splayed legs, a long tail in two parts and a
    head whose top jaw is a clapperboard that snaps shut ("Take!")."""
    green, light, dark = "#4CC764", "#C9F29B", "#2F8F45"
    board, white, mouth = "#2E2C34", "#FAF6EC", "#C8202F"
    # The clapper's striped stick across the front of the top jaw.
    stick = [B((0, -1.86, 1.36), (0.94, 0.24, 0.12), white, bevel=0.04)]
    stick += [B((x, -1.86, 1.425), (0.12, 0.25, 0.02), board, rot=(0, 0, 32), bevel=0.0, outline=False) for x in (-0.33, -0.11, 0.11, 0.33)]
    # A chalk label on top of the board.
    label = [B((0, -1.3, 1.34), (0.6, 0.5, 0.02), white, bevel=0.0, outline=False)]
    label += [B((0, y, 1.355), (0.46, 0.04, 0.01), "#9AA0AA", bevel=0.0, outline=False) for y in (-1.42, -1.3, -1.18)]
    return [
        # Body: long and low, a pale belly and a row of darker scutes down the back.
        E((0, 0.4, 0.85), (0.8, 1.15, 0.6), green),
        E((0, 0.25, 0.62), (0.66, 0.95, 0.38), light),
        *[E((x, y, 1.4), (0.13, 0.16, 0.09), dark, outline=False) for y in (-0.2, 0.35, 0.9) for x in (-0.25, 0.25)],
        # Stubby legs set wide at the sides, like a real croc.
        *pair(
            leg("LegFL", (0.66, -0.35, 0.3), (0.21, 0.23, 0.3), green, paw=light),
            leg("LegBL", (0.7, 1.05, 0.3), (0.22, 0.25, 0.3), green, paw=light),
        ),
        # Tail in two parts, so it swings like a whip.
        P(
            "Tail",
            "tail",
            (0, 1.4, 0.82),
            E((0, 1.95, 0.72), (0.44, 0.7, 0.36), green, rot=(8, 0, 0)),
            *[E((0, y, z), (0.1, 0.13, 0.08), dark, outline=False) for y, z in ((1.7, 1.05), (2.1, 0.98))],
            P(
                "TailTip",
                "tail",
                (0, 2.5, 0.66),
                E((0, 2.9, 0.56), (0.27, 0.52, 0.21), green, rot=(8, 0, 0)),
                E((0, 2.82, 0.76), (0.07, 0.1, 0.06), dark, outline=False),
                amp=1.4,
                phase=0.9,
            ),
        ),
        P(
            "Head",
            "head",
            (0, -0.6, 0.98),
            # Skull and the long lower jaw, with a red mouth and teeth along both sides.
            E((0, -0.85, 1.1), (0.56, 0.48, 0.46), green),
            B((0, -1.4, 0.84), (0.9, 1.1, 0.36), green, bevel=0.16),
            B((0, -1.4, 1.025), (0.76, 0.94, 0.04), mouth, bevel=0.015, outline=False),
            *[B((x, y, 1.06), (0.1, 0.1, 0.12), white, bevel=0.0, outline=False) for x in (-0.34, 0.34) for y in (-1.1, -1.4, -1.7)],
            *[B((x, -1.86, 1.06), (0.1, 0.1, 0.12), white, bevel=0.0, outline=False) for x in (-0.13, 0.13)],
            E((0, -1.95, 0.86), (0.28, 0.1, 0.13), light, outline=False),
            # Big eyes on bumps on top of the head.
            *pair(
                E((0.28, -0.75, 1.58), (0.26, 0.26, 0.28), green),
                *eye((0.28, -0.9, 1.66), size=0.9),
            ),
            # The top jaw: a clapperboard hinged at the back of the mouth.
            P(
                "Clapper",
                "jaw",
                (0, -0.95, 1.1),
                B((0, -1.38, 1.2), (0.92, 1.1, 0.26), board, bevel=0.08),
                *stick,
                *label,
                C((0, -0.95, 1.2), 0.1, 0.96, "#9AA0AA", rot=(0, 90, 0), outline=False),
            ),
        ),
    ]


def reel_kitty():
    blue, belly, pink, reel, steel, gold = "#8EC5FF", "#EAF4FF", "#FF8FB1", "#2E2C34", "#B8BEC8", "#F5B82E"

    def reel_ear():
        holes = [C((0.22 * math.cos(a), 0.22 * math.sin(a), 0.0), 0.08, 0.22, steel, outline=False) for a in (i * 2 * math.pi / 5 + 0.3 for i in range(5))]
        # The film reels turn like real reels.
        return G(
            (0.55, -0.3, 2.72),
            (90, 0, -20),
            P(
                "EarL",
                "spin",
                (0, 0, 0),
                C((0, 0, 0), 0.44, 0.18, reel),
                *holes,
                C((0, 0, 0), 0.12, 0.24, gold, outline=False),
                axis=(0, 0, 1),
            ),
        )

    return [
        E((0, 0.35, 0.92), (0.66, 0.82, 0.68), blue),
        E((0, -0.05, 0.85), (0.45, 0.45, 0.5), belly),
        *pair(
            leg("LegFL", (0.4, -0.3, 0.3), (0.22, 0.25, 0.3), blue, paw=belly),
            leg("LegBL", (0.43, 0.8, 0.3), (0.23, 0.28, 0.3), blue),
        ),
        C((0, -0.35, 1.52), 0.62, 0.16, gold),
        # A long tail that swishes, with a pale tip.
        P(
            "Tail",
            "tail",
            (0.18, 0.95, 0.92),
            E((0.35, 1.2, 1.25), (0.14, 0.14, 0.5), blue, rot=(-35, 0, -10)),
            E((0.5, 1.45, 1.75), (0.16, 0.16, 0.2), belly),
            amp=1.2,
        ),
        P(
            "Head",
            "head",
            (0, -0.35, 1.55),
            E((0, -0.4, 2.02), (0.86, 0.74, 0.72), blue),
            E((0, -1.02, 1.82), (0.42, 0.22, 0.24), belly),
            E((0, -1.2, 1.94), (0.1, 0.06, 0.07), pink, outline=False),
            *eye((0.33, -1.02, 2.22), iris="#3FCF6A"),
            *eye((-0.33, -1.02, 2.22), iris="#3FCF6A"),
            *pair(
                reel_ear(),
                B((0.55, -1.12, 1.82), (0.36, 0.02, 0.03), "#5A6A80", rot=(0, -12, 0), bevel=0.0, outline=False),
                B((0.55, -1.12, 1.72), (0.36, 0.02, 0.03), "#5A6A80", rot=(0, 8, 0), bevel=0.0, outline=False),
            ),
        ),
    ]


def camera_bot():
    purple, light, charcoal, gold, glass, steel = "#A04DFF", "#C99BFF", "#2E2C34", "#F5B82E", "#7FD8FF", "#9AA0AA"

    def reel(name, x):
        # Spins about its own axle (front to back).
        return P(
            name,
            "spin",
            (x, 0.1, 2.55),
            G(
                (x, 0.1, 2.55),
                (90, 0, 0),
                C((0, 0, 0), 0.46, 0.22, charcoal),
                *[C((0.24 * math.cos(a), 0.24 * math.sin(a), 0), 0.09, 0.26, steel, outline=False) for a in (i * 2 * math.pi / 5 for i in range(5))],
                C((0, 0, 0), 0.12, 0.28, gold, outline=False),
            ),
            axis=(0, 1, 0),
        )

    hole = 0.14  # gap between the film's sprocket holes; the tape slides one gap and starts again
    return [
        B((0, 0.05, 1.62), (1.45, 1.25, 1.12), purple, bevel=0.3),
        B((0, 0.05, 1.62), (1.5, 0.5, 0.5), light, bevel=0.12, outline=False),
        reel("ReelL", 0.42),
        reel("ReelR", -0.42),
        # The film running over the top of both reels; its sprocket holes slide along it.
        B((0, 0.1, 3.0), (0.86, 0.2, 0.05), charcoal, bevel=0.01, outline=False),
        P(
            "Tape",
            "tape",
            (0, 0.1, 3.03),
            *[B((-0.35 + hole * i, 0.1, 3.03), (0.06, 0.11, 0.02), "#FAF6EC", bevel=0.0, outline=False) for i in range(6)],
            axis=(1, 0, 0),
            amp=hole,
        ),
        C((0, -0.72, 1.62), 0.42, 0.42, charcoal, rot=(90, 0, 0)),
        C((0, -0.95, 1.62), 0.5, 0.12, gold, rot=(90, 0, 0)),
        E((0, -0.99, 1.62), (0.34, 0.07, 0.34), glass, outline=False, neon=True),
        E((0, -1.04, 1.62), (0.15, 0.04, 0.15), "#161220", outline=False),
        E((-0.07, -1.07, 1.7), (0.06, 0.02, 0.06), "#FFFFFF", outline=False),
        E((0.52, -0.63, 2.0), (0.09, 0.05, 0.09), "#FF3040", outline=False, neon=True),
        *pair(
            P(
                "ArmL",
                "arm",
                (0.76, -0.05, 1.68),
                E((0.9, -0.05, 1.42), (0.17, 0.17, 0.34), light, rot=(0, -28, 0)),
                E((1.04, -0.1, 1.1), (0.16, 0.16, 0.14), "#FFFFFF"),
            ),
        ),
        # A rocket thruster underneath keeps it in the air.
        C((0, 0.05, 0.92), 0.42, 0.24, steel),
        C((0, 0.05, 0.74), 0.3, 0.16, charcoal),
        P(
            "Flame",
            "flame",
            (0, 0.05, 0.66),
            E((0, 0.05, 0.56), (0.24, 0.24, 0.14), "#FFE14A", outline=False, neon=True),
            E((0, 0.05, 0.36), (0.19, 0.19, 0.26), "#FF8A1E", outline=False, neon=True),
            E((0, 0.05, 0.14), (0.09, 0.09, 0.12), "#FF3D1E", outline=False, neon=True),
        ),
    ]


def spotlight_owl():
    gold, belly, dark, orange, charcoal, light = "#E8A63A", "#FFE7B0", "#B9761F", "#FF8C2E", "#2E2C34", "#FFF1A8"

    def lamp(x):
        return G(
            (x, -0.62, 2.42),
            (90, 0, 0),
            C((0, 0, 0), 0.34, 0.38, charcoal),
            C((0, 0, 0.2), 0.38, 0.1, "#F5B82E"),
            E((0, 0, 0.24), (0.28, 0.28, 0.06), light, outline=False, neon=True),
            E((0, 0, 0.29), (0.11, 0.11, 0.03), "#161220", outline=False),
            E((-0.05, 0.06, 0.31), (0.04, 0.04, 0.015), "#FFFFFF", outline=False),
        )

    return [
        E((0, 0.08, 1.25), (0.95, 0.85, 1.12), gold),
        E((0, -0.38, 1.08), (0.62, 0.45, 0.78), belly),
        *pair(E((0.3, -0.42, 0.12), (0.22, 0.26, 0.12), orange)),
        *[E((x, -0.78, z), (0.09, 0.03, 0.07), "#F0C870", outline=False) for x, z in ((-0.2, 1.25), (0.2, 1.25), (0, 1.0), (-0.22, 0.8), (0.22, 0.8))],
        # Wings flap when it jumps and glide it down.
        *pair(P("WingL", "wing", (0.84, 0.1, 1.9), E((0.95, 0.12, 1.32), (0.24, 0.55, 0.75), dark, rot=(0, -14, 0)), axis=(0, 1, 0))),
        # The head swivels like a real owl's, spotlight eyes and all.
        P(
            "Head",
            "head",
            (0, 0, 1.95),
            E((0, -0.02, 2.42), (0.92, 0.8, 0.66), gold),
            lamp(0.38),
            lamp(-0.38),
            E((0, -0.86, 2.08), (0.13, 0.12, 0.2), orange),
            *pair(E((0.6, 0.0, 3.0), (0.15, 0.15, 0.36), dark, rot=(0, -25, 0))),
            amp=1.8,
        ),
    ]


def premiere_dragon():
    red, belly, wing, gold = "#FF5A2E", "#FFD36B", "#C8202F", "#F5B82E"
    return [
        E((0, 0.35, 1.05), (0.74, 0.92, 0.78), red),
        E((0, -0.12, 0.92), (0.52, 0.55, 0.62), belly),
        *pair(
            leg("LegFL", (0.45, -0.3, 0.3), (0.24, 0.27, 0.3), red, paw=belly),
            leg("LegBL", (0.48, 0.85, 0.3), (0.25, 0.3, 0.3), red),
            # Wings flap when it walks and beat hard when it jumps.
            P(
                "WingL",
                "wing",
                (0.6, 0.66, 1.4),
                G(
                    (0.72, 0.62, 1.85),
                    (20, 0, -35),
                    E((0, 0, 0), (0.07, 0.42, 0.62), wing),
                    E((0, -0.05, 0.55), (0.1, 0.1, 0.12), gold),
                ),
                axis=(0, 1, 0),
            ),
        ),
        *[E((0, y, z), (0.08, 0.14, 0.16), gold, rot=(-20, 0, 0)) for y, z in ((0.1, 1.86), (0.55, 1.78), (1.0, 1.55))],
        P(
            "Tail",
            "tail",
            (0, 0.95, 0.85),
            E((0, 1.4, 0.72), (0.24, 0.72, 0.24), red, rot=(18, 0, 0)),
            E((0, 2.05, 0.55), (0.24, 0.26, 0.07), gold, rot=(12, 0, 0)),
        ),
        P(
            "Head",
            "head",
            (0, -0.45, 1.75),
            E((0, -0.55, 2.25), (0.76, 0.7, 0.66), red),
            E((0, -1.15, 2.02), (0.46, 0.38, 0.32), red),
            E((0, -1.2, 1.88), (0.38, 0.3, 0.16), belly, outline=False),
            *eye((0.32, -1.08, 2.42), iris="#FFB020"),
            *eye((-0.32, -1.08, 2.42), iris="#FFB020"),
            *pair(
                E((0.34, -0.38, 2.88), (0.1, 0.1, 0.32), gold, rot=(18, -16, 0)),
                E((0.22, -1.48, 2.12), (0.05, 0.04, 0.05), "#7A1F2B", outline=False),
            ),
        ),
    ]


# id (the name players and the game use) -> (file name, builder)
MASCOTS = [
    ("PopcornPup", "popcorn_pup", popcorn_pup),
    ("ClapperCroc", "clapper_croc", clapper_croc),
    ("ReelKitty", "reel_kitty", reel_kitty),
    ("CameraBot", "camera_bot", camera_bot),
    ("SpotlightOwl", "spotlight_owl", spotlight_owl),
    ("PremiereDragon", "premiere_dragon", premiere_dragon),
]

# --- Flattening ------------------------------------------------------------------------------


def rotation(rot):
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def flatten(shapes, pieces, parent=None, piece="Body"):
    """[(shape, world matrix in studs, piece name)] with groups resolved. Each moving piece met on
    the way is added to `pieces` (with its pivot and axis in world studs and its parent piece)."""
    parent = parent or Matrix.Identity(4)
    out = []
    for s in shapes:
        if s["kind"] == "piece":
            assert all(p["name"] != s["name"] for p in pieces), f"two pieces called {s['name']}"
            pieces.append(
                {
                    "name": s["name"],
                    "role": s["role"],
                    "parent": piece,
                    "pivot": parent @ Vector(s["at"]),
                    "axis": (parent.to_3x3() @ Vector(s["axis"])).normalized(),
                    "amp": s["amp"],
                    "phase": s["phase"],
                }
            )
            out += flatten(s["children"], pieces, parent, s["name"])
            continue
        m = parent @ Matrix.Translation(Vector(s["at"])) @ rotation(s["rot"])
        if s["kind"] == "group":
            out += flatten(s["children"], pieces, m, piece)
        else:
            out.append((s, m, piece))
    return out


# --- Mesh ------------------------------------------------------------------------------------


def unit_shape(kind, size, grow=0.0, bevel=0.0):
    """A bmesh of the shape in studs, centred on the origin, `grow` studs bigger all round."""
    bm = bmesh.new()
    sx, sy, sz = (s + 2 * grow for s in size)
    biggest = max(size)
    if kind == "ball":
        u = 16 if biggest > 1.0 else 12 if biggest > 0.4 else 8
        bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=max(5, u * 2 // 3), radius=0.5)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    elif kind == "cyl":
        seg = 18 if biggest > 0.6 else 12
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
        if biggest > 0.3:
            rim = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.z - e.link_faces[1].normal.z) > 0.5]
            bmesh.ops.bevel(bm, geom=rim, offset=min(0.06, sz * 0.25, sx * 0.2), segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
        b = min(bevel + grow, min(sx, sy, sz) * 0.45)
        if b > 0.005:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


MATERIALS = {}  # (color, neon, ink) -> material, shared by every piece in the scene


class Mascot:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.index = {}

    def mat(self, color, neon=False, ink=False):
        key = (color, neon, ink)
        if key in self.index:
            return self.index[key]
        if key in MATERIALS:
            self.materials.append(MATERIALS[key])
            self.index[key] = len(self.materials) - 1
            return self.index[key]
        mat = bpy.data.materials.new(f"Mat_{'Ink' if ink else color.lstrip('#')}{'_Neon' if neon else ''}")
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        linear = mmkit.hex_to_linear(color)
        bsdf.inputs["Base Color"].default_value = linear
        bsdf.inputs["Roughness"].default_value = 0.38
        bsdf.inputs["Coat Weight"].default_value = 0.35
        if neon:
            bsdf.inputs["Emission Color"].default_value = linear
            bsdf.inputs["Emission Strength"].default_value = 2.5
        if ink:
            # The outline hull: drawn only where its inside faces the camera, like Roblox does.
            out = nodes["Material Output"]
            geo = nodes.new("ShaderNodeNewGeometry")
            mix = nodes.new("ShaderNodeMixShader")
            clear = nodes.new("ShaderNodeBsdfTransparent")
            emit = nodes.new("ShaderNodeEmission")
            emit.inputs["Color"].default_value = linear
            # Seen by the camera only: from inside the hull it would shade the model.
            path = nodes.new("ShaderNodeLightPath")
            either = nodes.new("ShaderNodeMath")
            either.operation = "ADD"
            either.use_clamp = True
            links.new(geo.outputs["Backfacing"], either.inputs[0])
            notcam = nodes.new("ShaderNodeMath")
            notcam.operation = "SUBTRACT"
            notcam.inputs[0].default_value = 1.0
            links.new(path.outputs["Is Camera Ray"], notcam.inputs[1])
            links.new(notcam.outputs[0], either.inputs[1])
            links.new(either.outputs[0], mix.inputs["Fac"])
            links.new(emit.outputs["Emission"], mix.inputs[1])
            links.new(clear.outputs["BSDF"], mix.inputs[2])
            links.new(mix.outputs["Shader"], out.inputs["Surface"])
            mat.blend_method = "HASHED" if hasattr(mat, "blend_method") else None
        mat.diffuse_color = linear
        MATERIALS[key] = mat
        self.materials.append(mat)
        self.index[key] = len(self.materials) - 1
        return self.index[key]

    def add(self, tmp, matrix, mat, smooth, flip=False):
        vs = {v: self.bm.verts.new(matrix @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            verts = [vs[v] for v in f.verts]
            if flip:
                verts.reverse()
            face = self.bm.faces.new(verts)
            face.material_index = mat
            face.smooth = smooth
        tmp.free()

    def shape(self, s, m):
        scale = Matrix.Scale(STUD, 4)
        world = scale @ m
        smooth = s["kind"] != "box" or s.get("bevel", 0) > 0.05
        self.add(unit_shape(s["kind"], s["size"], 0, s.get("bevel", 0)), world, self.mat(s["color"], s["neon"]), smooth)
        if s["outline"]:
            self.add(unit_shape(s["kind"], s["size"], OUTLINE, s.get("bevel", 0)), world, self.mat(INK, ink=True), True, flip=True)

    def obj(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def build(mascot_id, builder):
    """One Blender object per piece, named <id>_<piece> ("PopcornPup_Body", "PopcornPup_Tail"...),
    plus the flattened shapes and the pieces (Body first)."""
    MATERIALS.clear()
    pieces = [{"name": "Body", "role": "body", "parent": None, "pivot": Vector((0, 0, 0)), "axis": Vector((0, 0, 1)), "amp": 1.0, "phase": 0.0}]
    flat = flatten(builder(), pieces)
    lowest = min(_lowest(s, m) for s, m, _ in flat)
    lift = Matrix.Translation((0, 0, -lowest))
    flat = [(s, lift @ m, piece) for s, m, piece in flat]
    for p in pieces:
        p["pivot"] = lift @ p["pivot"]
    objs = []
    for p in pieces:
        model = Mascot(f"{mascot_id}_{p['name']}")
        mine = [(s, m) for s, m, piece in flat if piece == p["name"]]
        assert mine, f"{mascot_id} piece {p['name']} has no shapes"
        for s, m in mine:
            model.shape(s, m)
        objs.append(model.obj())
    return objs, flat, pieces


def _lowest(s, m):
    sx, sy, sz = (v / 2 for v in s["size"])
    corners = [m @ Vector((x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    if s["kind"] == "ball":  # an ellipsoid's lowest point: support function
        r = m.to_3x3() @ Matrix.Diagonal((sx, sy, sz))
        down = Vector((0, 0, -1))
        return m.translation.z - (r.transposed() @ down).length
    return min(c.z for c in corners)


# --- Luau fallback ---------------------------------------------------------------------------

# Blender (x, y, z) -> Roblox (-x, z, y): a proper rotation taking Blender's up (Z) to Roblox's
# up (Y) and Blender's front (-Y) to Roblox's front (-Z).
TO_ROBLOX = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def to_roblox(s, m):
    pos = TO_ROBLOX @ m.translation
    rot = TO_ROBLOX @ m.to_3x3() @ TO_ROBLOX
    sx, sy, sz = s["size"]
    size = (sx, sz, sy)  # local Blender (x, y, z) -> Roblox local (x, z, y)
    return pos, rot, size


def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


MASCOT_HEADER = [
    "-- GENERATED by art/blender/mascots.py from the Blender mascot designs. Do not edit by hand:",
    "-- change the shapes there and run it again. Each mascot is a list of shapes in studs, feet on",
    "-- y = 0, facing -Z. MascotModels builds them as parts until the Blender meshes are imported.",
]


def vec(v):
    return f"Vector3.new({', '.join(num(c) for c in v)})"


def roblox_box(lo, hi):
    """Blender bounds (studs) -> Roblox (size, centre)."""
    lo_r, hi_r = TO_ROBLOX @ lo, TO_ROBLOX @ hi
    mn = [min(a, b) for a, b in zip(lo_r, hi_r)]
    mx = [max(a, b) for a, b in zip(lo_r, hi_r)]
    return [b - a for a, b in zip(mn, mx)], [(a + b) / 2 for a, b in zip(mn, mx)]


def write_luau(results, out=LUAU_OUT, module="MascotShapes", header=MASCOT_HEADER, what="mascot"):
    """Writes the shapes as a Luau module (`module` at `out`); other Blender scripts reuse it."""
    lines = [
        "--!strict",
        *header,
        "-- kind: \"ball\" (an ellipsoid), \"box\" or \"cyl\" (its axis along the CFrame's Y).",
        "-- piece: which moving piece the shape belongs to (an index into Pieces; 1 is the body).",
        "",
        "export type Shape = { kind: string, cf: CFrame, size: Vector3, color: Color3, neon: boolean?, outline: boolean?, piece: number }",
        "",
        "-- A moving piece (MascotRig animates it): it turns about `pivot` (studs, mascot space) as its",
        "-- `role` says, after its `parent` piece has moved. `axis` is the turning axis for spin and wing,",
        "-- or the sliding direction for tape; `amp` scales the motion (for tape: how far it slides",
        "-- before starting again) and `phase` delays it. `center` and `size` place its Blender mesh.",
        "export type Piece = {",
        "\tname: string,",
        "\trole: string,",
        "\tparent: number?,",
        "\tpivot: Vector3,",
        "\taxis: Vector3,",
        "\tamp: number,",
        "\tphase: number,",
        "\tcenter: Vector3,",
        "\tsize: Vector3,",
        "}",
        "",
        "local function S(kind: string, cf: CFrame, size: Vector3, hex: string, piece: number, neon: boolean?, outline: boolean?): Shape",
        "\treturn { kind = kind, cf = cf, size = size, color = Color3.fromHex(hex), neon = neon, outline = outline, piece = piece }",
        "end",
        "",
        f"local {module} = {{}}",
        "",
        f"{module}.Shapes = {{}} :: {{ [string]: {{ Shape }} }}",
        "",
        f"-- Each {what}'s mesh size and where its centre sits above the feet, for placing the mesh.",
        f"{module}.Bounds = {{}} :: {{ [string]: {{ size: Vector3, center: Vector3 }} }}",
        "",
        f"-- Each {what}'s pieces, the body first. Its Blender meshes are named <id>_<piece name>.",
        f"{module}.Pieces = {{}} :: {{ [string]: {{ Piece }} }}",
        "",
    ]
    for mascot_id, flat, bounds, pieces in results:
        index = {p["name"]: i + 1 for i, p in enumerate(pieces)}
        lines.append(f"{module}.Shapes.{mascot_id} = {{")
        for s, m, piece in flat:
            pos, r, size = to_roblox(s, m)
            cf = ", ".join(num(v) for v in (*pos, r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]))
            extra = ""
            if s["neon"] or s["outline"]:
                extra = f", {'true' if s['neon'] else 'nil'}, {'true' if s['outline'] else 'nil'}"
            lines.append(f"\tS(\"{s['kind']}\", CFrame.new({cf}), Vector3.new({', '.join(num(v) for v in size)}), \"{s['color'].lstrip('#')}\", {index[piece]}{extra}),")
        lines.append("}")
        size, center = roblox_box(*bounds)
        lines.append(f"{module}.Bounds.{mascot_id} = {{ size = {vec(size)}, center = {vec(center)} }}")
        lines.append(f"{module}.Pieces.{mascot_id} = {{")
        for p in pieces:
            psize, pcenter = roblox_box(*p["bounds"])
            parent = str(index[p["parent"]]) if p["parent"] else "nil"
            lines.append(
                f"\t{{ name = \"{p['name']}\", role = \"{p['role']}\", parent = {parent}, pivot = {vec(TO_ROBLOX @ p['pivot'])}, axis = {vec(TO_ROBLOX @ p['axis'])}, "
                f"amp = {num(p['amp'])}, phase = {num(p['phase'])}, center = {vec(pcenter)}, size = {vec(psize)} }},"
            )
        lines.append("}")
        lines.append("")
    lines.append(f"return {module}")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("Wrote", out)


# --- Previews --------------------------------------------------------------------------------


def stage(objects, file_name, width, height, distance_scale=1.0, angle=24, render=True):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = mmkit.hex_to_linear("#FFE9B8")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    for name, energy, rot, color in (("Key", 4.0, (50, 0, -35), (1, 0.95, 0.88)), ("Fill", 1.2, (60, 0, 140), (0.85, 0.9, 1.0))):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.color = color
        light.data.angle = math.radians(8)
        light.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(light)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 3.0
    rim.rotation_euler = (math.radians(-60), 0, math.radians(15))
    scene.collection.objects.link(rim)
    # A soft floor that fades into the background colour, so the line-up reads like a store card.
    floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=400)
    fb.to_mesh(floor.data)
    fb.free()
    fmat = bpy.data.materials.new("Mat_Floor")
    fmat.use_nodes = True
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = mmkit.hex_to_linear("#FFD978")
    fmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    floor.data.materials.append(fmat)
    scene.collection.objects.link(floor)

    bpy.context.view_layer.update()
    xs, ys, zs = [], [], []
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    target = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (max(zs)) * 0.48))
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    span = max(max(xs) - min(xs), (max(zs) - min(zs)) * width / height)
    dist = span / 2 / math.tan(cam.data.angle_x / 2) * 1.12 * distance_scale
    el = math.radians(angle)
    cam.location = target + Vector((0, -math.cos(el) * dist, math.sin(el) * dist))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = os.path.join(mmkit.PREVIEWS, file_name)
    if render:
        bpy.ops.render.render(write_still=True)
        print("Rendered", scene.render.filepath)


def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))) / STUD
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))) / STUD
    return lo, hi


def export_all(objs):
    """Every piece of every mascot in one file: art/exports/mascots.fbx."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(mmkit.EXPORTS, "mascots.fbx"),
        use_selection=True,
        # Roblox reads FBX units (cm) as studs, so write the model in studs.
        global_scale=1 / (STUD * 100),
        apply_unit_scale=True,
        bake_space_transform=True,
        colors_type="SRGB",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
    )
    print("Exported", os.path.join(mmkit.EXPORTS, "mascots.fbx"))


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    only = os.environ.get("MASCOT_ONLY")
    results = []
    for mascot_id, file_name, builder in MASCOTS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objs, flat, pieces = build(mascot_id, builder)
        tris = sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
        lo, hi = bounds(objs)
        size = hi - lo
        print(f"{mascot_id}: {tris} tris in {len(objs)} pieces, {size.x:.1f} x {size.y:.1f} x {size.z:.1f} studs")
        assert tris <= 9000, f"{mascot_id} is over its triangle budget"
        for p, o in zip(pieces, objs):
            p["bounds"] = bounds([o])
        results.append((mascot_id, flat, (lo, hi), pieces))
        if os.environ.get("MASCOT_NO_RENDER") or (only and only != mascot_id):
            continue
        for o in objs:
            o.rotation_euler = (0, 0, math.radians(float(os.environ.get("MASCOT_TURN", "-28"))))
        stage(objs, f"mascot_{file_name}.png", 640, 640, 1.25, 14)
    write_luau(results)

    # Every piece of every mascot into one FBX, side by side like the line-up.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    everything = []
    lineup = []
    for i, (mascot_id, _, builder) in enumerate(MASCOTS):
        objs, _, _ = build(mascot_id, builder)
        for o in objs:
            mmkit.bake_vertex_colors(o.data)
            o.location = (STUD * (i - 2.5) * 3.4, 0, 0)
            o.rotation_euler = (0, 0, math.radians(-18 + i * 7))
        everything += objs
        lineup.append(objs)
    if not os.environ.get("MASCOT_NO_RENDER") and not only:
        # The line-up: all six side by side, rarest on the right.
        stage(everything, "mascots.png", 1600, 640, 1.0, 12)
    for o in everything:
        o.location = (0, 0, 0)
        o.rotation_euler = (0, 0, 0)
    export_all(everything)


if __name__ == "__main__":
    main()
