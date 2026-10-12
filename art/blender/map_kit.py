"""Map kit: the Blender models for the town's map overhaul (lamps, trees, Dusty Gulch's
buildings, Starlight Park's features and the far scenery).

  TownLamp          Hollywood double-globe street lamp (boulevard and back paths)
  ParkLamp          green Victorian lantern post (Starlight Park)
  Lantern           wooden post with a hanging oil lantern (Dusty Gulch boardwalks)
  ParkTree          round low-poly leafy tree
  BlossomTree       the same tree in pink blossom
  PineTree          tall pine for the far woods
  Bush              a clump of leafy blobs
  Cactus            saguaro with two arms and a flower
  DesertRock        a pair of sandstone boulders
  Mesa              striped sandstone butte for the desert behind Dusty Gulch
  WaterTower        studio water tower with a cone roof (the backlot)
  WaterTank         wooden railroad water tank on stilts (Dusty Gulch)
  Bandstand         octagonal park bandstand with a striped roof
  ParkBench         wrought-iron park bench with wooden slats
  Western<Name>     the eight false-front buildings of Dusty Gulch (Saloon, Bank, Barber, Hotel,
                    Sheriff, GeneralStore, PostOffice, Blacksmith). Their sign boards are left
                    blank: the game writes the names on them.

Every model is low-poly and flat shaded with baked vertex colors, in the chunky toy style of
ART_STYLE.md. The same shapes are written to src/shared/Models/MapKitShapes.luau, which the game
builds as parts until the meshes are imported, so this file is the one source for both. Points
that glow (lamp globes, lanterns) are listed there too, so the game can put a light on them.

All models go into ONE file, art/exports/map_kit.fbx: import it once in Studio and drop the
imported model into ReplicatedStorage > LotMeshes (art/README.md).

Run from the repo root with Blender, or with the `bpy` package (see mmkit.py):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/map_kit.py
Writes art/exports/map_kit.fbx, art/previews/map_kit.png (all models side by side) and the
Luau file. Set KIT_SAMPLES for quicker test renders, KIT_NO_RENDER=1 to skip the render.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402
from mascots import P, bounds, flatten, num, rotation, stage  # noqa: E402,F401

STUD = mmkit.STUD
LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "MapKitShapes.luau")
SAMPLES = int(os.environ.get("KIT_SAMPLES", "48"))
MAX_TRIS = 10000

# Colors: the game palette (Build.Palette) plus the outer ring's own (TownSets).
COL = {
    "Cream": "#F4E7CF",
    "Burgundy": "#7A1F2B",
    "Carpet": "#C8202F",
    "Gold": "#F5B82E",
    "Blue": "#2E86DE",
    "Navy": "#1B2340",
    "Green": "#5BBF5A",
    "DarkGreen": "#388C46",
    "Charcoal": "#2E2C34",
    "Steel": "#6E7078",
    "Bark": "#7A5434",
    "Wood": "#96623C",
    "Light": "#FFECBE",
    "OffWhite": "#FAF6EC",
    "Glass": "#96CDF0",
    "Leaf": "#4FB548",
    "LeafDark": "#2F8F3E",
    "LeafLight": "#7ED35F",
    "Pine": "#24704A",
    "PineDark": "#1B5A3C",
    "Blossom": "#FFA0CD",
    "BlossomDark": "#F27BB4",
    "Cactus": "#46AF50",
    "CactusDark": "#368C40",
    "Sand": "#F0CD8C",
    "Rock": "#D67C48",
    "RockDark": "#B5613A",
    "RockLight": "#E89A62",
    "Iron": "#2A3A34",
    "ParkGreen": "#2F6B4F",
    "Flame": "#FFB347",
}


def shade(hex_color, amount):
    """Darker (amount > 0) or lighter (amount < 0) version of a hex color."""
    h = hex_color.lstrip("#")
    rgb = [int(h[i : i + 2], 16) for i in (0, 2, 4)]
    if amount >= 0:
        rgb = [round(c * (1 - amount)) for c in rgb]
    else:
        rgb = [round(c + (255 - c) * -amount) for c in rgb]
    return "#" + "".join(f"{c:02X}" for c in rgb)


def c(name):
    return COL.get(name, name)


# --- Shapes ----------------------------------------------------------------------------------
# Blender coordinates in studs: Z up, the model faces -Y, standing on Z = 0.


def B(at, size, color, rot=(0, 0, 0), bevel=0.0, neon=False):
    """Box centred on `at`."""
    return {"kind": "box", "at": at, "size": size, "color": c(color), "rot": rot, "bevel": bevel, "neon": neon}


def C(at, radius, length, color, rot=(0, 0, 0), seg=12, neon=False):
    """Cylinder centred on `at`, its axis along local Z."""
    return {"kind": "cyl", "at": at, "size": (2 * radius, 2 * radius, length), "color": c(color), "rot": rot, "seg": seg, "neon": neon}


def K(at, r_bottom, r_top, length, color, rot=(0, 0, 0), seg=8, neon=False):
    """Cone (or tapered cylinder) centred on `at`, axis along local Z, wide end down."""
    return {
        "kind": "cone", "at": at, "size": (2 * r_bottom, 2 * r_bottom, length), "top": r_top / r_bottom,
        "color": c(color), "rot": rot, "seg": seg, "neon": neon,
    }


def E(at, radii, color, rot=(0, 0, 0), neon=False):
    """Smooth ellipsoid centred on `at` with half-sizes `radii`."""
    return {"kind": "ball", "at": at, "size": tuple(2 * r for r in radii), "color": c(color), "rot": rot, "neon": neon}


def L(at, radii, color, rot=(0, 0, 0)):
    """Faceted low-poly blob (foliage, rocks); a ball in the part version."""
    return {"kind": "blob", "at": at, "size": tuple(2 * r for r in radii), "color": c(color), "rot": rot, "neon": False}


def W(at, size, color, rot=(0, 0, 0)):
    """Wedge like a Roblox WedgePart: tall side at local +Y (the back), slope facing -Y and up."""
    return {"kind": "wedge", "at": at, "size": size, "color": c(color), "rot": rot, "neon": False}


def G(at, rot, *children):
    return {"kind": "group", "at": at, "rot": rot, "children": children}


def mirror_x(shapes):
    out = []
    for s in shapes:
        rx, ry, rz = s["rot"]
        m = {**s, "at": (-s["at"][0], *s["at"][1:]), "rot": (rx, -ry, -rz)}
        if s["kind"] == "group":
            m["children"] = tuple(mirror_x(list(s["children"])))
        out.append(m)
    return out


def ring(n, radius, z, make, start=0.0):
    """`make(x, y, angle_deg)` for n points round a circle."""
    out = []
    for i in range(n):
        a = start + i * 360 / n
        out.append(make(math.sin(math.radians(a)) * radius, math.cos(math.radians(a)) * radius, a))
    return out


# --- Lamps -----------------------------------------------------------------------------------


def town_lamp():
    s = [
        C((0, 0, 0.45), 0.95, 0.9, "Charcoal", seg=8),
        C((0, 0, 0.98), 0.75, 0.16, "Gold", seg=8),
        K((0, 0, 1.9), 0.62, 0.42, 1.7, "Charcoal", seg=8),
        K((0, 0, 6.6), 0.32, 0.2, 8.0, "Charcoal", seg=8),
        C((0, 0, 2.85), 0.46, 0.18, "Gold", seg=8),
        C((0, 0, 7.4), 0.3, 0.2, "Gold", seg=8),
        C((0, 0, 10.5), 0.26, 0.3, "Gold", seg=8),
        B((0, 0, 10.75), (4.2, 0.3, 0.32), "Charcoal"),
    ]
    for x in (-1, 1):
        s += [
            E((x * 1.9, 0, 10.45), (0.24, 0.24, 0.24), "Charcoal"),
            C((x * 1.9, 0, 11.0), 0.28, 0.32, "Gold", seg=8),
            E((x * 1.9, 0, 11.75), (0.72, 0.72, 0.82), "Light", neon=True),
            K((x * 1.9, 0, 12.62), 0.42, 0.12, 0.3, "Charcoal", seg=8),
        ]
    s += [
        C((0, 0, 11.3), 0.3, 0.6, "Gold", seg=8),
        E((0, 0, 12.25), (0.8, 0.8, 0.92), "Light", neon=True),
        K((0, 0, 13.25), 0.46, 0.12, 0.34, "Charcoal", seg=8),
        K((0, 0, 13.75), 0.14, 0.02, 0.7, "Gold", seg=6),
    ]
    return s


def park_lamp():
    s = [
        C((0, 0, 0.35), 0.8, 0.7, "ParkGreen", seg=8),
        K((0, 0, 1.3), 0.55, 0.3, 1.2, "ParkGreen", seg=8),
        C((0, 0, 4.9), 0.2, 6.2, "ParkGreen", seg=8),
        C((0, 0, 2.05), 0.36, 0.3, "Gold", seg=8),
        C((0, 0, 8.0), 0.34, 0.24, "Gold", seg=8),
        K((0, 0, 8.35), 0.3, 0.55, 0.5, "ParkGreen", seg=8),
        B((0, 0, 9.35), (1.15, 1.15, 1.5), "Light", neon=True),
    ]
    for x, y in ((-0.62, -0.62), (0.62, -0.62), (-0.62, 0.62), (0.62, 0.62)):
        s.append(B((x, y, 9.35), (0.16, 0.16, 1.6), "ParkGreen"))
    s += [
        B((0, 0, 8.6), (1.5, 1.5, 0.16), "ParkGreen"),
        K((0, 0, 10.5), 1.12, 0.12, 0.8, "ParkGreen", rot=(0, 0, 45), seg=4),
        E((0, 0, 11.05), (0.2, 0.2, 0.2), "Gold"),
        # Two little scroll arms under the lantern.
        B((0.5, 0, 7.6), (0.9, 0.12, 0.12), "ParkGreen", rot=(0, -35, 0)),
        B((-0.5, 0, 7.6), (0.9, 0.12, 0.12), "ParkGreen", rot=(0, 35, 0)),
    ]
    return s


def lantern():
    return [
        B((0, 0, 0.3), (1.1, 1.1, 0.6), "Bark"),
        B((0, 0, 4.6), (0.55, 0.55, 9.2), "Wood"),
        B((0, 0, 9.3), (0.75, 0.75, 0.3), "Bark"),
        B((0, -1.1, 8.6), (0.3, 2.4, 0.3), "Bark"),
        B((0, -0.55, 7.9), (0.22, 1.3, 0.22), "Bark", rot=(-45, 0, 0)),
        C((0, -2.0, 8.1), 0.05, 0.6, "Charcoal", seg=4),
        B((0, -2.0, 7.15), (0.8, 0.8, 0.14), "Charcoal"),
        B((0, -2.0, 6.65), (0.62, 0.62, 0.9), "Flame", neon=True),
        B((-0.36, -2.0 - 0.36, 6.65), (0.1, 0.1, 1.0), "Charcoal"),
        B((0.36, -2.0 - 0.36, 6.65), (0.1, 0.1, 1.0), "Charcoal"),
        B((-0.36, -2.0 + 0.36, 6.65), (0.1, 0.1, 1.0), "Charcoal"),
        B((0.36, -2.0 + 0.36, 6.65), (0.1, 0.1, 1.0), "Charcoal"),
        B((0, -2.0, 6.15), (0.8, 0.8, 0.14), "Charcoal"),
        K((0, -2.0, 7.45), 0.56, 0.08, 0.5, "Charcoal", rot=(0, 0, 45), seg=4),
    ]


# --- Plants and rocks ------------------------------------------------------------------------


def leafy_tree(light, mid, dark, height=9.0):
    t = height / 9.0
    s = [
        K((0, 0, 2.6 * t), 0.75 * t, 0.5 * t, 5.2 * t, "Bark", seg=7),
        B((0.9 * t, 0, 4.4 * t), (2.0 * t, 0.45 * t, 0.45 * t), "Bark", rot=(0, -40, 0)),
        B((-0.8 * t, 0.2 * t, 4.9 * t), (1.8 * t, 0.42 * t, 0.42 * t), "Bark", rot=(0, 45, 20)),
        L((0, 0, 7.2 * t), (3.6 * t, 3.4 * t, 2.9 * t), mid),
        L((1.9 * t, -0.8 * t, 6.2 * t), (2.4 * t, 2.3 * t, 2.1 * t), dark, rot=(10, 20, 30)),
        L((-2.0 * t, 0.9 * t, 6.4 * t), (2.5 * t, 2.4 * t, 2.2 * t), dark, rot=(-15, 10, 70)),
        L((0.4 * t, 1.6 * t, 8.6 * t), (2.3 * t, 2.2 * t, 1.9 * t), light, rot=(5, -20, 15)),
        L((-0.7 * t, -1.5 * t, 8.4 * t), (2.0 * t, 2.0 * t, 1.8 * t), light, rot=(25, 5, 50)),
    ]
    return s


def park_tree():
    return leafy_tree("LeafLight", "Leaf", "LeafDark")


def blossom_tree():
    s = leafy_tree("#FFC2DE", "Blossom", "BlossomDark")
    s += [E((x, y, z), (0.22, 0.22, 0.22), "OffWhite") for x, y, z in ((2.6, -1.8, 7.2), (-2.4, -1.6, 8.0), (1.0, -2.6, 9.0), (-3.4, 1.0, 6.4))]
    return s


def pine_tree():
    s = [K((0, 0, 1.6), 0.7, 0.45, 3.2, "Bark", seg=6)]
    tiers = ((3.2, 5.6, 0.0), (6.2, 4.6, 30.0), (9.0, 3.6, 10.0), (11.6, 2.6, 40.0))
    for i, (z, r, turn) in enumerate(tiers):
        s.append(K((0, 0, z + 1.6), r, 0.25 * r if i < 3 else 0.05, 4.4, "Pine" if i % 2 == 0 else "PineDark", rot=(0, 0, turn), seg=7))
    return s


def bush():
    return [
        L((0, 0, 1.3), (1.9, 1.7, 1.4), "Leaf"),
        L((1.5, 0.4, 1.0), (1.3, 1.2, 1.05), "LeafDark", rot=(0, 0, 30)),
        L((-1.4, -0.3, 1.05), (1.35, 1.2, 1.1), "LeafDark", rot=(0, 0, 70)),
        L((0.3, -0.8, 1.9), (1.0, 0.9, 0.8), "LeafLight", rot=(20, 0, 10)),
    ]


def cactus():
    s = [
        C((0, 0, 4.0), 0.95, 8.0, "Cactus", seg=10),
        E((0, 0, 8.0), (0.95, 0.95, 0.75), "Cactus"),
        E((0, 0, 8.7), (0.4, 0.4, 0.3), "#FF7AB5"),
    ]
    # Ribs down the trunk.
    s += ring(6, 0.88, 4.0, lambda x, y, a: B((x, y, 4.0), (0.22, 0.22, 7.6), "CactusDark", rot=(0, 0, -a)))
    s += [
        C((1.6, 0, 3.6), 0.55, 1.9, "Cactus", rot=(0, 90, 0), seg=8),
        C((2.35, 0, 5.0), 0.55, 2.8, "Cactus", seg=8),
        E((2.35, 0, 6.4), (0.55, 0.55, 0.45), "Cactus"),
        C((-1.45, 0, 5.0), 0.5, 1.6, "Cactus", rot=(0, 90, 0), seg=8),
        C((-2.05, 0, 6.0), 0.5, 2.0, "Cactus", seg=8),
        E((-2.05, 0, 7.0), (0.5, 0.5, 0.4), "Cactus"),
    ]
    return s


def desert_rock():
    return [
        L((0, 0, 1.7), (3.4, 2.8, 2.2), "Rock", rot=(0, 0, 20)),
        L((2.6, 1.2, 1.1), (2.0, 1.8, 1.5), "RockDark", rot=(10, 0, 60)),
        L((-0.6, -1.2, 3.2), (1.8, 1.6, 1.0), "RockLight", rot=(0, 15, 10)),
    ]


def mesa():
    s = []
    z = 0.0
    for i, (r, h, col) in enumerate(((16, 7, "RockDark"), (14.5, 6, "Rock"), (13.4, 4, "RockLight"), (12.6, 5, "Rock"), (11.8, 3, "RockDark"))):
        s.append(K((0, 0, z + h / 2), r, r - 1.0, h, col, rot=(0, 0, i * 9), seg=7))
        z += h
    s.append(K((0, 0, z + 0.4), 11.2, 10.0, 0.8, "Sand", rot=(0, 0, 40), seg=7))
    return s


# --- Water towers and the bandstand ----------------------------------------------------------


def water_tower():
    s = []
    for x in (-3.6, 3.6):
        for y in (-3.6, 3.6):
            s.append(B((x, y, 10.15), (0.8, 0.8, 20.3), "Steel"))
    for z in (6.0, 13.0):
        for y in (-1, 1):
            s.append(B((0, y * 3.6, z), (7.2, 0.35, 0.35), "Steel"))
            s.append(B((y * 3.6, 0, z), (0.35, 7.2, 0.35), "Steel"))
    for y in (-1, 1):
        s.append(B((0, y * 3.6, 9.5), (0.3, 0.3, 9.6), "Steel", rot=(0, 52, 0)))
    s += [
        C((0, 0, 20.3), 6.6, 0.6, "Steel", seg=16),
        C((0, 0, 21.0), 6.7, 0.25, "Charcoal", seg=16),
        C((0, 0, 25.4), 5.6, 9.0, "Cream", seg=16),
        C((0, 0, 21.6), 5.75, 0.7, "Burgundy", seg=16),
        C((0, 0, 28.6), 5.75, 0.7, "Burgundy", seg=16),
        K((0, 0, 31.1), 6.1, 0.5, 3.6, "Burgundy", seg=16),
        E((0, 0, 33.1), (0.7, 0.7, 0.7), "Gold"),
        # The ladder up one leg and a railing round the deck.
        B((-0.6, -6.5, 10.5), (0.15, 0.15, 21), "Charcoal"),
        B((0.6, -6.5, 10.5), (0.15, 0.15, 21), "Charcoal"),
    ]
    s += [B((0, -6.5, z), (1.2, 0.12, 0.12), "Charcoal") for z in range(1, 21, 2)]
    s += ring(16, 6.45, 21.8, lambda x, y, a: B((x, y, 21.8), (0.12, 0.12, 1.4), "Charcoal"))
    s.append(C((0, 0, 22.5), 6.5, 0.12, "Charcoal", seg=16))
    # The sign plate (the game writes "HOLLYWOOD RNG" on it).
    s.append(B((0, -5.65, 25.2), (7.6, 0.3, 2.8), "OffWhite"))
    return s


def water_tank():
    s = []
    for x in (-4, 4):
        for y in (-4, 4):
            s.append(B((x, y, 8), (1.2, 1.2, 16), "Bark"))
    for z in (5.0, 11.0):
        s.append(B((0, -4, z), (9.2, 0.5, 0.5), "Wood"))
        s.append(B((0, 4, z), (9.2, 0.5, 0.5), "Wood"))
        s.append(B((-4, 0, z), (0.5, 9.2, 0.5), "Wood"))
        s.append(B((4, 0, z), (0.5, 9.2, 0.5), "Wood"))
    s += [
        B((0, -4, 8), (0.4, 0.4, 11), "Wood", rot=(0, 52, 0)),
        B((0, 4, 8), (0.4, 0.4, 11), "Wood", rot=(0, -52, 0)),
        C((0, 0, 16.3), 6.6, 0.6, "Bark", seg=14),
        C((0, 0, 20.6), 6.0, 8.0, "Wood", seg=14),
    ]
    s += ring(14, 5.85, 20.6, lambda x, y, a: B((x, y, 20.6), (0.35, 0.35, 8.0), "Bark", rot=(0, 0, -a)))
    s += [
        C((0, 0, 17.6), 6.1, 0.45, "Charcoal", seg=14),
        C((0, 0, 23.6), 6.1, 0.45, "Charcoal", seg=14),
        K((0, 0, 26.0), 6.8, 0.6, 2.8, "Carpet", seg=14),
        # The spout, swung up.
        C((0, -6.4, 18.5), 0.5, 4.0, "Charcoal", rot=(-60, 0, 0), seg=8),
    ]
    return s


def bandstand():
    s = [
        C((0, 0, 0.8), 9.4, 1.6, "Cream", seg=8, rot=(0, 0, 22.5)),
        C((0, 0, 1.7), 8.8, 0.24, "Wood", seg=8, rot=(0, 0, 22.5)),
        C((0, 0, 1.65), 9.5, 0.12, "Gold", seg=8, rot=(0, 0, 22.5)),
        B((0, -10.2, 0.4), (6, 2, 0.8), "Cream"),
        B((0, -9.4, 1.05), (6, 0.8, 0.5), "Cream"),
    ]
    posts = []
    for i in range(8):
        a = math.radians(i * 45)
        x, y = math.sin(a) * 8.2, math.cos(a) * 8.2
        posts.append((x, y))
        s.append(C((x, y, 5.6), 0.42, 7.8, "OffWhite", seg=8))
        s.append(C((x, y, 2.0), 0.6, 0.5, "Gold", seg=8))
        s.append(C((x, y, 9.3), 0.6, 0.4, "Gold", seg=8))
    # Railings between the posts, leaving the front (between the two posts facing -Y) open.
    for i in range(8):
        x0, y0 = posts[i]
        x1, y1 = posts[(i + 1) % 8]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        if my < -7:
            continue
        length = math.hypot(x1 - x0, y1 - y0)
        yaw = math.degrees(math.atan2(y1 - y0, x1 - x0))
        s.append(B((mx, my, 4.2), (length, 0.35, 0.35), "OffWhite", rot=(0, 0, yaw)))
        s.append(B((mx, my, 2.3), (length, 0.25, 0.25), "OffWhite", rot=(0, 0, yaw)))
        for k in (-0.3, -0.1, 0.1, 0.3):
            s.append(B((mx + (x1 - x0) * k, my + (y1 - y0) * k, 3.25), (0.18, 0.18, 1.9), "OffWhite"))
    s += [
        C((0, 0, 9.8), 9.6, 0.6, "Burgundy", seg=8, rot=(0, 0, 22.5)),
        K((0, 0, 11.4), 10.2, 3.0, 2.6, "Carpet", seg=8, rot=(0, 0, 22.5)),
        K((0, 0, 11.45), 9.0, 2.4, 2.6, "OffWhite", seg=16, rot=(0, 0, 0)),
        C((0, 0, 12.9), 3.0, 0.4, "Gold", seg=8, rot=(0, 0, 22.5)),
        C((0, 0, 13.8), 1.9, 1.6, "OffWhite", seg=8, rot=(0, 0, 22.5)),
        K((0, 0, 15.2), 2.4, 0.3, 1.4, "Carpet", seg=8, rot=(0, 0, 22.5)),
        E((0, 0, 16.2), (0.6, 0.6, 0.6), "Gold"),
    ]
    # Scalloped stripes: carpet wedges hanging round the roof edge.
    s += ring(16, 9.7, 9.2, lambda x, y, a: B((x, y, 9.2), (3.6, 0.2, 0.7), "Carpet" if round(a / 22.5) % 2 == 0 else "OffWhite", rot=(0, 0, -a)), start=11.25)
    return s


def park_bench():
    s = []
    for x in (-2.6, 2.6):
        s += [
            B((x, -0.6, 0.7), (0.3, 0.3, 1.4), "Iron"),
            B((x, 0.6, 1.3), (0.3, 0.3, 2.6), "Iron", rot=(-12, 0, 0)),
            B((x, 0.0, 1.45), (0.3, 1.5, 0.25), "Iron"),
            B((x, -0.35, 2.15), (0.32, 1.2, 0.22), "Iron"),
            E((x, -0.95, 2.15), (0.24, 0.24, 0.24), "Iron"),
        ]
    for i, y in enumerate((-0.55, -0.15, 0.25)):
        s.append(B((0, y, 1.55), (5.8, 0.34, 0.16), "Wood" if i % 2 == 0 else "Bark", bevel=0.04))
    for i, z in enumerate((2.0, 2.45, 2.9)):
        s.append(B((0, 0.72 + (z - 2.0) * 0.21, z), (5.8, 0.14, 0.32), "Wood" if i % 2 == 0 else "Bark", rot=(-12, 0, 0), bevel=0.04))
    return s


# --- Dusty Gulch's buildings -----------------------------------------------------------------
# Laid out like TownSets' western buildings: front on y = 0 facing -Y, about w wide and 14 deep,
# the false front h tall. The sign board (h - 3.2 up, cream) is left blank for the game's text.

WESTERN = [
    # name, width, height, color, balcony, extra
    ("Saloon", 20, 20, "#CD4632", True, "saloon"),
    ("Bank", 18, 16, "#3C82D7", False, "bank"),
    ("Barber", 16, 14, "#EB73A5", False, "barber"),
    ("Hotel", 20, 20, "#915FCD", True, "hotel"),
    ("Sheriff", 18, 15, "#F0AF32", False, "sheriff"),
    ("GeneralStore", 22, 16, "#64AF4B", False, "store"),
    ("PostOffice", 18, 14, "#20B2BE", False, "post"),
    ("Blacksmith", 18, 15, "#96694F", False, "smith"),
]


def western(w, h, color, balcony, extra):
    dark = shade(color, 0.16)
    darker = shade(color, 0.3)
    depth = 14
    box_h = h * 0.72
    s = [
        B((0, depth / 2 + 0.4, box_h / 2), (w - 0.6, depth, box_h), dark),
        # Pitched roof behind the false front.
        W((0, depth / 2 + 0.4 - depth / 4, box_h + 1.4), (w - 0.2, depth / 2, 2.8), "Bark", rot=(0, 0, 180)),
        W((0, depth / 2 + 0.4 + depth / 4, box_h + 1.4), (w - 0.2, depth / 2, 2.8), "Bark"),
    ]
    # Clapboard front: overlapping boards in two shades.
    boards = max(6, int(h / 1.6))
    bh = h / boards
    for i in range(boards):
        s.append(B((0, -0.05 * (i % 2), bh * (i + 0.5)), (w, 0.8, bh + 0.05), color if i % 2 == 0 else dark))
    # Stepped false-front top with a crown.
    s += [
        B((0, 0, h + 0.4), (w + 1.0, 1.3, 0.8), "Cream"),
        B((0, 0, h + 1.7), (w * 0.56, 0.8, 1.8), color),
        B((0, 0, h + 2.9), (w * 0.56 + 1.0, 1.2, 0.6), "Cream"),
        B((0, 0, h + 3.8), (w * 0.3, 0.8, 1.2), dark),
        B((0, 0, h + 4.6), (w * 0.3 + 0.8, 1.1, 0.5), "Cream"),
    ]
    for x in (-1, 1):
        s += [
            B((x * (w / 2), 0, (h + 0.4) / 2), (1.4, 1.4, h + 0.4), "Bark", bevel=0.1),
            B((x * (w / 2), 0, h + 1.0), (1.8, 1.8, 0.5), "Cream"),
            B((x * w * 0.29, 0, h + 1.6), (0.6, 0.9, 1.6), "Bark"),
        ]
    # The sign board, framed (left blank for the game's lettering).
    sign_z = h - 3.2
    s += [
        B((0, -0.55, sign_z), (w - 3, 0.5, 4), "Bark", bevel=0.1),
        B((0, -0.75, sign_z), (w - 4, 0.4, 3.2), "Cream"),
    ]
    for x in (-1, 1):
        s.append(E((x * (w / 2 - 2.2), -0.85, sign_z), (0.22, 0.12, 0.22), "Gold"))
    # Door with a frame and a little transom window.
    s += [
        B((0, -0.55, 3.9), (4.8, 0.5, 7.8), "Cream"),
        B((0, -0.66, 3.5), (3.8, 0.5, 7.0), "Bark"),
        B((-0.95, -0.92, 3.5), (1.6, 0.1, 6.4), shade(COL["Bark"], 0.15)),
        B((0.95, -0.92, 3.5), (1.6, 0.1, 6.4), shade(COL["Bark"], 0.15)),
        B((0, -0.7, 7.25), (3.6, 0.5, 0.5), "Glass", neon=False),
        E((0.6, -1.0, 3.4), (0.22, 0.14, 0.22), "Gold"),
    ]
    # Windows with shutters.
    for x in (-w / 2 + 3.6, w / 2 - 3.6):
        s += [
            B((x, -0.55, 4.6), (4.2, 0.5, 4.2), "Cream"),
            B((x, -0.66, 4.6), (3.3, 0.5, 3.3), "Navy"),
            B((x, -0.72, 4.6), (0.3, 0.5, 3.3), "Cream"),
            B((x, -0.72, 4.6), (3.3, 0.5, 0.3), "Cream"),
            B((x - 2.55, -0.6, 4.6), (0.9, 0.3, 4.0), darker),
            B((x + 2.55, -0.6, 4.6), (0.9, 0.3, 4.0), darker),
            B((x, -0.9, 2.3), (4.4, 0.8, 0.3), "Cream"),
        ]
    # Porch posts with brackets, and a porch roof or a balcony.
    for x in (-1, 1):
        s += [
            B((x * (w / 2 - 0.3), -5.2, 4.2), (0.9, 0.9, 8.4), "Bark", bevel=0.08),
            B((x * (w / 2 - 0.3), -5.2, 0.3), (1.3, 1.3, 0.6), "Bark"),
            B((x * (w / 2 - 1.1), -5.2, 7.7), (1.8, 0.4, 0.4), "Bark", rot=(0, x * 40, 0)),
        ]
    if balcony:
        s += [
            B((0, -2.8, 8.8), (w + 1.0, 5.6, 0.8), "Wood"),
            B((0, -5.6, 8.8), (w + 1.2, 0.4, 1.0), color),
            B((0, -5.3, 11.8), (w + 1.0, 0.6, 0.6), "Cream"),
        ]
        n = int(w / 1.5)
        for i in range(n + 1):
            s.append(B((-w / 2 + i * w / n, -5.3, 10.5), (0.4, 0.4, 2.6), "Wood"))
        for x in (-w / 4, w / 4):
            s += [
                B((x, -0.55, 12.8), (4.0, 0.5, 4.4), "Cream"),
                B((x, -0.66, 12.8), (3.1, 0.5, 3.5), "Navy"),
                B((x, -0.72, 12.8), (0.3, 0.5, 3.5), "Cream"),
                B((x, -0.72, 12.9), (3.1, 0.5, 0.3), "Cream"),
            ]
    else:
        s += [
            B((0, -2.8, 8.75), (w + 1.2, 5.9, 0.5), "Cream", rot=(-10, 0, 0)),
            B((0, -5.65, 8.3), (w + 1.4, 0.5, 0.6), color),
        ]
        # Striped valance under the porch roof.
        n = int(w / 2)
        for i in range(n):
            s.append(B((-w / 2 + (i + 0.5) * w / n, -5.7, 7.75), (w / n, 0.2, 0.7), color if i % 2 == 0 else "OffWhite"))

    # Each building's own touch.
    if extra == "saloon":
        for x in (-0.95, 0.95):
            s.append(B((x, -1.1, 4.4), (1.7, 0.25, 3.0), "Gold"))
        s += [B((x, -0.95, 0.6), (1.0, 1.0, 1.2), "Wood") for x in (-6.5, 6.5)]
        s.append(C((-w / 2 + 1.0, -6.4, 0.9), 0.65, 1.8, "Wood", seg=10))
    elif extra == "bank":
        for x in (-4.5, 4.5):
            s += [
                C((x, -2.6, 4.2), 0.55, 7.6, "OffWhite", seg=10),
                B((x, -2.6, 0.4), (1.5, 1.5, 0.8), "OffWhite"),
                B((x, -2.6, 8.1), (1.5, 1.5, 0.5), "OffWhite"),
            ]
        s.append(B((0, -0.85, sign_z + 2.6), (2.4, 0.3, 1.2), "Gold"))
    elif extra == "barber":
        for x in (-w / 2 - 1.0, w / 2 + 1.0):
            s += [C((x, -2.0, 4.4), 0.38, 4.6, "OffWhite", seg=10)]
            s += [B((x, -2.0, 2.6 + k * 0.9), (0.84, 0.84, 0.32), "Carpet" if k % 2 == 0 else "Blue", rot=(18, 0, 0)) for k in range(5)]
            s += [E((x, -2.0, 6.9), (0.45, 0.45, 0.45), "Gold"), C((x, -2.0, 1.6), 0.5, 0.6, "Gold", seg=10)]
    elif extra == "hotel":
        s.append(B((0, -1.0, 0.25), (6, 2.0, 0.5), "Carpet"))
        for x in (-w / 2 + 2.2, w / 2 - 2.2):
            s.append(C((x, -6.0, 0.8), 0.7, 1.6, "Burgundy", seg=10))
            s.append(L((x, -6.0, 2.3), (1.0, 1.0, 0.9), "Leaf"))
    elif extra == "sheriff":
        # A big gold star over the sign, and bars on the windows.
        for turn in (0, 45):
            s.append(B((0, -0.95, h + 1.2), (3.2, 0.4, 3.2), "Gold", rot=(0, turn, 0)))
        s.append(C((0, -1.2, h + 1.2), 0.8, 0.3, "Carpet", rot=(90, 0, 0), seg=10))
        for x in (-w / 2 + 3.6, w / 2 - 3.6):
            for k in (-1.0, 0, 1.0):
                s.append(B((x + k, -0.95, 4.6), (0.18, 0.2, 3.3), "Charcoal"))
    elif extra == "store":
        s += [B((x, -1.3, 1.0), (2.0, 2.0, 2.0), "Wood", rot=(0, 0, 8)) for x in (-6.5,)]
        s += [B((-6.4, -1.3, 2.9), (1.6, 1.6, 1.6), "Bark", rot=(0, 0, -10))]
        s += [C((6.8, -1.6, 1.25), 0.95, 2.5, "Wood", seg=10), C((6.8, -1.6, 2.6), 1.0, 0.2, "Charcoal", seg=10)]
        s += [B((0, -0.75, sign_z + 2.9), (w * 0.5, 0.3, 0.5), "Carpet")]
    elif extra == "post":
        s += [
            B((5.6, -1.5, 1.6), (1.8, 1.4, 2.2), "Blue"),
            B((5.6, -1.5, 2.85), (2.0, 1.6, 0.3), "Navy"),
            B((5.6, -2.25, 2.0), (1.0, 0.1, 0.25), "Charcoal"),
        ]
    elif extra == "smith":
        s += [
            B((w / 2 - 3, depth - 1, box_h + 5.5), (2.4, 2.4, 6.0), "#8E8E96"),
            B((w / 2 - 3, depth - 1, box_h + 8.7), (3.0, 3.0, 0.6), "Charcoal"),
            B((-5.5, -1.6, 1.4), (2.6, 1.6, 0.6), "Charcoal"),
            B((-5.5, -1.6, 0.6), (1.0, 1.0, 1.2), "Charcoal"),
            K((-7.0, -1.6, 1.9), 0.4, 0.05, 1.4, "Charcoal", rot=(0, -90, 0), seg=6),
        ]
        s += [C((5.6, -1.2, 1.2), 1.2, 0.5, "Steel", rot=(90, 0, 0), seg=12)]
    return s


def western_builder(info):
    _, w, h, color, balcony, extra = info
    return lambda: western(w, h, color, balcony, extra)


KIT = [
    ("TownLamp", town_lamp),
    ("ParkLamp", park_lamp),
    ("Lantern", lantern),
    ("ParkTree", park_tree),
    ("BlossomTree", blossom_tree),
    ("PineTree", pine_tree),
    ("Bush", bush),
    ("Cactus", cactus),
    ("DesertRock", desert_rock),
    ("Mesa", mesa),
    ("WaterTower", water_tower),
    ("WaterTank", water_tank),
    ("Bandstand", bandstand),
    ("ParkBench", park_bench),
] + [("Western" + info[0], western_builder(info)) for info in WESTERN]


# --- Mesh ------------------------------------------------------------------------------------


def unit_shape(s):
    """A bmesh of the shape in studs, centred on the origin."""
    kind, size = s["kind"], s["size"]
    sx, sy, sz = size
    bm = bmesh.new()
    if kind == "ball":
        biggest = max(size)
        u = 14 if biggest > 1.0 else 10 if biggest > 0.4 else 8
        bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=max(5, u * 2 // 3), radius=0.5)
    elif kind == "blob":
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
        # Nudge the corners a little so neighbouring blobs don't look stamped out.
        for i, v in enumerate(bm.verts):
            k = 1.0 + 0.09 * math.sin(i * 2.3 + sx)
            v.co *= k
    elif kind in ("cyl", "cone"):
        top = s.get("top", 1.0)
        bmesh.ops.create_cone(bm, cap_ends=True, segments=s.get("seg", 12), radius1=0.5, radius2=0.5 * top, depth=1.0)
    elif kind == "wedge":
        verts = [bm.verts.new(v) for v in (
            (-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5),
            (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5),
        )]
        for f in ((0, 3, 2, 1), (0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4)):
            bm.faces.new([verts[i] for i in f])
    else:
        bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    if kind == "box":
        b = min(s.get("bevel", 0.0), min(sx, sy, sz) * 0.4)
        if b > 0.01:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


class Piece:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.index = {}

    def mat(self, color, neon):
        key = (color, neon)
        if key in self.index:
            return self.index[key]
        mat = bpy.data.materials.new(f"Mat_{color.lstrip('#')}{'_Neon' if neon else ''}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        linear = mmkit.hex_to_linear(color)
        bsdf.inputs["Base Color"].default_value = linear
        bsdf.inputs["Roughness"].default_value = 0.55
        if neon:
            bsdf.inputs["Emission Color"].default_value = linear
            bsdf.inputs["Emission Strength"].default_value = 3.0
        mat.diffuse_color = linear
        self.materials.append(mat)
        self.index[key] = len(self.materials) - 1
        return self.index[key]

    def shape(self, s, m):
        tmp = unit_shape(s)
        world = Matrix.Scale(STUD, 4) @ m
        mat = self.mat(s["color"], s["neon"])
        smooth = s["kind"] == "ball"
        vs = {v: self.bm.verts.new(world @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            face = self.bm.faces.new([vs[v] for v in f.verts])
            face.material_index = mat
            face.smooth = smooth
        tmp.free()

    def obj(self):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def lowest(s, m):
    sx, sy, sz = (v / 2 for v in s["size"])
    if s["kind"] in ("ball", "blob"):
        r = m.to_3x3() @ Matrix.Diagonal((sx, sy, sz))
        return m.translation.z - (r.transposed() @ Vector((0, 0, -1))).length
    corners = [m @ Vector((x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    return min(p.z for p in corners)


def build(name, builder):
    flat = flatten(builder())
    lift = Matrix.Translation((0, 0, -min(0.0, min(lowest(s, m) for s, m in flat))))
    flat = [(s, lift @ m) for s, m in flat]
    piece = Piece(name)
    for s, m in flat:
        piece.shape(s, m)
    return piece.obj(), flat


# --- Luau fallback ---------------------------------------------------------------------------


def to_roblox(s, m):
    pos = P @ m.translation
    rot = P @ m.to_3x3() @ P
    sx, sy, sz = s["size"]
    return pos, rot, (sx, sz, sy)


def write_luau(results):
    lines = [
        "--!strict",
        "-- GENERATED by art/blender/map_kit.py from the Blender map kit. Do not edit by hand: change",
        "-- the shapes there and run it again. Each model is a list of shapes in studs, standing on",
        "-- y = 0 and facing -Z. MapKit builds them as parts until the Blender meshes are imported.",
        "-- kind: \"box\", \"ball\" (an ellipsoid), \"cyl\" or \"cone\" (axis along the CFrame's Y; a cone's",
        "-- top is `top` times its bottom width) or \"wedge\" (a WedgePart).",
        "",
        "export type Shape = { kind: string, cf: CFrame, size: Vector3, color: Color3, neon: boolean?, top: number? }",
        "",
        "local function S(kind: string, cf: CFrame, size: Vector3, hex: string, neon: boolean?, top: number?): Shape",
        "\treturn { kind = kind, cf = cf, size = size, color = Color3.fromHex(hex), neon = neon, top = top }",
        "end",
        "",
        "local MapKitShapes = {}",
        "",
        "MapKitShapes.Shapes = {} :: { [string]: { Shape } }",
        "",
        "-- Each model's mesh size and where its centre sits above its feet, for placing the mesh.",
        "MapKitShapes.Bounds = {} :: { [string]: { size: Vector3, center: Vector3 } }",
        "",
        "-- Where each model glows (lamp globes, lanterns), for the lights the game adds.",
        "MapKitShapes.Glow = {} :: { [string]: { Vector3 } }",
        "",
    ]
    for name, flat, (lo, hi) in results:
        lines.append(f"MapKitShapes.Shapes.{name} = {{")
        glow = []
        for s, m in flat:
            pos, r, size = to_roblox(s, m)
            cf = ", ".join(num(v) for v in (*pos, r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]))
            kind = "ball" if s["kind"] == "blob" else s["kind"]
            extra = ""
            if s["neon"] or kind == "cone":
                extra = f", {'true' if s['neon'] else 'nil'}"
                if kind == "cone":
                    extra += f", {num(s['top'])}"
            if s["neon"]:
                glow.append(pos)
            lines.append(f"\tS(\"{kind}\", CFrame.new({cf}), Vector3.new({', '.join(num(v) for v in size)}), \"{s['color'].lstrip('#')}\"{extra}),")
        lines.append("}")
        lo_r, hi_r = P @ lo, P @ hi
        mn = [min(a, b) for a, b in zip(lo_r, hi_r)]
        mx = [max(a, b) for a, b in zip(lo_r, hi_r)]
        size = [b - a for a, b in zip(mn, mx)]
        center = [(a + b) / 2 for a, b in zip(mn, mx)]
        lines.append(
            f"MapKitShapes.Bounds.{name} = {{ size = Vector3.new({', '.join(num(v) for v in size)}), center = Vector3.new({', '.join(num(v) for v in center)}) }}"
        )
        if glow:
            lines.append(f"MapKitShapes.Glow.{name} = {{ " + ", ".join(f"Vector3.new({', '.join(num(v) for v in p)})" for p in glow) + " }")
        lines.append("")
    lines.append("return MapKitShapes")
    with open(LUAU_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("Wrote", LUAU_OUT)


def export_all(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(mmkit.EXPORTS, "map_kit.fbx"),
        use_selection=True,
        global_scale=1 / (STUD * 100),
        apply_unit_scale=True,
        bake_space_transform=True,
        colors_type="SRGB",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
    )
    print("Exported", os.path.join(mmkit.EXPORTS, "map_kit.fbx"))


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    results, objs = [], []
    for name, builder in KIT:
        obj, flat = build(name, builder)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lo, hi = bounds(obj)
        size = hi - lo
        print(f"{name}: {tris} tris, {size.x:.1f} x {size.y:.1f} x {size.z:.1f} studs")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        results.append((name, flat, (lo, hi)))
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    write_luau(results)
    export_all(objs)

    if not os.environ.get("KIT_NO_RENDER"):
        # Two line-ups: the props and plants, and Dusty Gulch's buildings.
        lineup(["TownLamp", "ParkLamp", "Lantern", "ParkBench", "Bush", "Cactus", "DesertRock", "ParkTree", "BlossomTree", "PineTree"],
               ["WaterTower", "WaterTank", "Bandstand", "Mesa"], "map_kit_props.png")
        lineup(["Western" + w[0] for w in WESTERN[:4]], ["Western" + w[0] for w in WESTERN[4:]], "map_kit_buildings.png")


def lineup(front, back, file_name):
    """Render two rows of kit models (front row nearer the camera)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = front + back
    objs = {n: build(n, dict(KIT)[n])[0] for n in names}
    shown = []
    y = 0.0
    for row in (front, back):
        widths = [(bounds(objs[n])[1] - bounds(objs[n])[0]).x for n in row]
        gap = 2.5
        x = -(sum(widths) + gap * (len(row) - 1)) / 2
        depth = max((bounds(objs[n])[1] - bounds(objs[n])[0]).y for n in row)
        for n, wd in zip(row, widths):
            o = objs[n]
            lo, hi = bounds(o)
            o.location = (STUD * (x + wd / 2 - (lo.x + hi.x) / 2), STUD * (y - (lo.y + hi.y) / 2), 0)
            o.rotation_euler = (0, 0, math.radians(-14))
            shown.append(o)
            x += wd + gap
        y += depth + 6
    stage(shown, file_name, 1800, 1000, 0.92, 22)


if __name__ == "__main__":
    main()
