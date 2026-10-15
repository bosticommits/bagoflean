"""Map kit, part two: the town's landmarks, street furniture and film sets, the low-poly hills
and mountains round the map, and the little living things (clouds, birds, butterflies).

These used to be built from plain blocks in the game code (TownSets, MapModels). Each one is
now a Blender model in the chunky, faceted low-poly style of ART_STYLE.md: chamfered edges,
few-sided cylinders, faceted spheres and two-tone faces on the hills and mountains. map_kit.py
adds them to the same map_kit.fbx and MapKitShapes.luau as the first kit, so nothing changes in
how they are imported (art/README.md).

Every shape here is written in the GAME's coordinates (Roblox: Y up, front toward -Z), with the
R* helpers below, so positions can be checked against the old part code line by line. Signs are
left blank: the game still writes their words on a see-through board in front.

Not run on its own: map_kit.py imports it.
"""

import math

from map_kit import B, C, COL, E, G, K, L, W, shade  # noqa: F401

# Colors only this part of the kit uses.
COL.update(
    {
        "Pink": "#FF78AA",
        "Teal": "#20B2BE",
        "Chroma": "#2FD25A",
        "Chrome": "#D7DAE1",
        "Stone": "#B0B6C2",
        "Hay": "#F0CD8C",
        "Duck": "#FFD63C",
        "Beak": "#FF8C28",
        "Dino": "#6EBE50",
        "DinoDark": "#5AA046",
        "Moon": "#E1E1D7",
        "Crater": "#B4B4AC",
        "Snow": "#F6F8FF",
        "Cloud": "#FFFFFF",
        "CloudShade": "#E4ECF6",
        "Grass": "#60B254",
        "Mint": "#7FD8B0",
    }
)


# --- Game-space helpers -----------------------------------------------------------------------
# Roblox model space (x right, y up, front -Z) -> the kit's Blender space (Z up, front -Y).
# A Roblox turn about Y (yaw) is the same turn about Blender Z, a Roblox pitch (about X) is the
# opposite turn about Blender X, and a Roblox roll (about Z) is the same turn about Blender Y.
# Blender applies pitch, then roll, then yaw: the same as Roblox's
# CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, roll) * CFrame.Angles(pitch, 0, 0).


def rb(x, y, z):
    return (-x, z, y)


def rs(x, y, z):
    return (x, z, y)


def rr(pitch=0.0, yaw=0.0, roll=0.0):
    return (-pitch, roll, yaw)


def RB(at, size, color, yaw=0, pitch=0, roll=0, bevel=0.0, neon=False):
    """Box: centre and size as in the part code."""
    return B(rb(*at), rs(*size), color, rr(pitch, yaw, roll), bevel, neon)


def RC(at, d, h, color, yaw=0, pitch=0, roll=0, seg=10, neon=False):
    """Upright cylinder `d` across and `h` tall (like Builder:cylinder); roll=90 lays it along X,
    pitch=90 along Z."""
    return C(rb(*at), d / 2, h, color, rr(pitch, yaw, roll), seg, neon)


def RK(at, d0, d1, h, color, yaw=0, pitch=0, roll=0, seg=8, neon=False):
    """Cone or tapered cylinder, `d0` across at the bottom and `d1` at the top."""
    return K(rb(*at), d0 / 2, max(d1, 0.02) / 2, h, color, rr(pitch, yaw, roll), seg, neon)


def RE(at, size, color, yaw=0, pitch=0, roll=0, neon=False):
    """Smooth ellipsoid `size` across (x, y, z)."""
    return E(rb(*at), tuple(v / 2 for v in rs(*size)), color, rr(pitch, yaw, roll), neon)


def RL(at, size, color, yaw=0, pitch=0, roll=0):
    """Faceted low-poly blob `size` across."""
    return L(rb(*at), tuple(v / 2 for v in rs(*size)), color, rr(pitch, yaw, roll))


def RF(at, size, color, tones=(), yaw=0):
    """Faceted ball with flat facets (no wobble), its faces in a few `tones` (hills, moons)."""
    s = L(rb(*at), tuple(v / 2 for v in rs(*size)), color, rr(0, yaw, 0))
    s["kind"] = "facet"
    s["tones"] = [COL.get(t, t) for t in tones]
    return s


def RW(at, size, color, yaw=0, pitch=0, roll=0):
    """Wedge like a WedgePart: tall side at +Z (back), slope facing -Z and up."""
    return W(rb(*at), rs(*size), color, rr(pitch, yaw, roll))


def RG(at, yaw, *children, pitch=0, roll=0):
    return G(rb(*at), rr(pitch, yaw, roll), *children)


def STAR(at, d, depth, color, yaw=0, pitch=0, neon=False):
    """A five-point star `d` across standing up and facing -Z, its middle raised front and back
    (a faceted star like a trophy's). The part version is flat, from wedges."""
    return {"kind": "star", "at": rb(*at), "size": (d, depth, d), "color": COL.get(color, color),
            "rot": rr(pitch, yaw, 0), "neon": neon}


def toned(s, *tones):
    s["tones"] = [COL.get(t, t) for t in tones]
    return s


def bulbs_row(x0, x1, y, z, n, size=0.42):
    """A row of n marquee bulbs from x0 to x1."""
    return [RE((x0 + (x1 - x0) * i / (n - 1), y, z), (size, size, size), "Light", neon=True) for i in range(n)]


def bulbs_col(x, y0, y1, z, n, size=0.42):
    return [RE((x, y0 + (y1 - y0) * i / (n - 1), z), (size, size, size), "Light", neon=True) for i in range(n)]


# --- Landmarks --------------------------------------------------------------------------------


def theatre():
    """The Grand Premiere Theatre (TownSets.theatre): about 52 wide and 26 deep, the bottom step at
    z = -3. Blank: the marquee board, the two posters and the tall RNG blade."""
    s = [RB((0, 0.5, 13), (52, 1, 26), "Burgundy", bevel=0.15)]
    for i in range(3):
        h = (3 - i) / 3
        s += [RB((0, h / 2, -i - 0.5), (26, h, 1), "Cream", bevel=0.06), RB((0, h + 0.03, -i - 0.5), (6, 0.08, 1.02), "Carpet")]
    s += [RB((0, 1.04, 3), (6, 0.08, 6), "Carpet")]
    for x in (-3.3, 3.3):
        s.append(RB((x, 1.06, 3), (0.5, 0.1, 6), "Gold"))
    # The hall: cream with a gold band, a burgundy cornice and a stepped parapet on top.
    s += [
        RB((0, 11, 16), (34, 20, 20), "Cream", bevel=0.25),
        RB((0, 17.5, 16), (34.5, 0.8, 20.5), "Gold", bevel=0.1),
        RB((0, 21.4, 16), (35.4, 1.2, 21.4), "Burgundy", bevel=0.2),
        RB((0, 22.6, 17), (28, 1.2, 16), "Cream", bevel=0.2),
        RB((0, 23.5, 17), (28.6, 0.6, 16.6), "Burgundy", bevel=0.12),
    ]
    for side in (-1, 1):
        s += [
            RB((side * 21.3, 7.5, 16.5), (8.6, 13, 17), "Cream", bevel=0.2),
            RB((side * 21.3, 14.4, 16.5), (9.4, 1, 17.8), "Burgundy", bevel=0.15),
            # A pennant on each wing.
            RC((side * 21.3, 17.4, 12), 0.35, 5, "Charcoal", seg=6),
            RW((side * 21.3 + side * 1.3, 18.8, 12), (0.2, 1.8, 2.4), "Carpet", yaw=side * 90),
            RE((side * 21.3, 20.0, 12), (0.6, 0.6, 0.6), "Gold"),
        ]
        for x in (-2.2, 2.2):
            s += [
                RB((side * 21.3 + x, 5.9, 7.95), (2.9, 6.6, 0.3), "Burgundy", bevel=0.05),
                RB((side * 21.3 + x, 5.9, 7.8), (2.2, 6, 0.3), "Navy"),
                RC((side * 21.3 + x, 8.9, 7.8), 2.2, 0.3, "Navy", pitch=90, seg=10),
                RB((side * 21.3 + x, 2.7, 7.6), (2.8, 0.35, 0.8), "Cream"),
            ]
    # Columns along the front, with gold tops.
    for x in (-15, -9, 9, 15):
        s += [
            RB((x, 1.5, 4.6), (2.4, 1, 2.4), "Burgundy", bevel=0.1),
            RC((x, 7.25, 4.6), 1.7, 10.5, "Cream", seg=8),
            RB((x, 12.9, 4.6), (2.6, 0.8, 2.6), "Gold", bevel=0.1),
            RC((x, 2.3, 4.6), 2.0, 0.5, "Gold", seg=8),
        ]
    # Three glass doors in gold frames.
    for x in (-4.2, 0, 4.2):
        s += [
            RB((x, 4.4, 5.95), (3.8, 6.8, 0.3), "Gold", bevel=0.05),
            RB((x, 4.1, 5.8), (3.2, 6.2, 0.3), "Navy"),
            RB((x, 4.1, 5.62), (0.18, 6.2, 0.1), "Gold"),
            RB((x - 0.5, 4.0, 5.55), (0.2, 1.2, 0.2), "Gold"),
            RB((x + 0.5, 4.0, 5.55), (0.2, 1.2, 0.2), "Gold"),
        ]
    # Poster cases between the columns (the posters keep their film's color; words in game).
    for x, color in ((-12, "Blue"), (12, "Pink")):
        s += [RB((x, 5.2, 5.9), (4, 5.6, 0.3), "Gold", bevel=0.05), RB((x, 5.2, 5.75), (3.4, 5, 0.3), color)]
    # The marquee: a deep canopy over the doors, a board on its front edged with bulbs and
    # bulbs underneath.
    s += [
        RB((0, 10, 2.5), (26, 3.6, 7), "Burgundy", bevel=0.2),
        RB((0, 12.1, 2.5), (27, 0.6, 7.6), "Gold", bevel=0.1),
        RB((0, 12.7, 2.0), (18, 0.8, 5), "Burgundy", bevel=0.12),
        RB((0, 8.1, 2.5), (25, 0.3, 6.4), "Light", neon=True),
        RB((0, 10, -1.1), (24, 2.6, 0.3), "OffWhite"),
        RB((0, 10, -0.9), (25.2, 3.4, 0.2), "Gold"),
    ]
    s += bulbs_row(-11.8, 11.8, 8.55, -1.35, 17) + bulbs_row(-11.8, 11.8, 11.45, -1.35, 17)
    s += bulbs_col(-12.3, 9.0, 11.0, -1.35, 3) + bulbs_col(12.3, 9.0, 11.0, -1.35, 3)
    # The tall blade sign rising over the roof, edged with bulbs, a gold star on top.
    s += [
        RB((0, 22.3, 5.2), (6.6, 19, 1.2), "Gold", bevel=0.15),
        RB((0, 22.3, 4.6), (5.6, 18, 0.6), "Navy"),
        RB((0, 32.1, 5.2), (4.4, 0.8, 1.6), "Burgundy", bevel=0.1),
    ]
    s += bulbs_col(-2.95, 13.8, 30.8, 4.15, 12, 0.46) + bulbs_col(2.95, 13.8, 30.8, 4.15, 12, 0.46)
    s.append(STAR((0, 35.0, 5.0), 5.4, 1.4, "Gold"))
    # Bushes in round planters at the ends of the porch.
    for x in (-19.5, 19.5):
        s += [RC((x, 1.6, 1.8), 2.6, 1.2, "Burgundy", seg=8), RL((x, 3.0, 1.8), (2.8, 2.2, 2.8), "Leaf")]
    return s


def studio_gate():
    """The Studio Gate (TownSets.studioGate): two towers, an arch with a blank navy sign on both
    faces and a gold star, iron gates swung open, and the guard booth (at x = -22, z = -4)."""
    s = []
    for side in (-1, 1):
        x = side * 14
        s += [
            RB((x, 1, 0), (7.6, 2, 7.6), "Burgundy", bevel=0.2),
            RB((x, 13, 0), (6, 22, 6), "Cream", bevel=0.2),
            RB((x, 6, 0), (6.5, 0.8, 6.5), "Gold", bevel=0.1),
            RB((x, 18, 0), (6.5, 0.8, 6.5), "Gold", bevel=0.1),
            RB((x, 24.7, 0), (7.4, 1.4, 7.4), "Burgundy", bevel=0.2),
            RK((x, 26.2, 0), 5.6, 1.2, 1.8, "Burgundy", seg=4, yaw=45),
            RF((x, 27.6, 0), (2.4, 2.4, 2.4), "Gold"),
            # A tall slot window on the front and back.
            RB((x, 12, -3.05), (1.6, 5, 0.2), "Navy"),
            RB((x, 12, 3.05), (1.6, 5, 0.2), "Navy"),
        ]
        hinge = side * 10.6
        for y in (1.2, 8.4):
            s.append(RB((hinge, y, 5.4), (0.4, 0.4, 9), "Charcoal"))
        for k in range(5):
            z = 1.6 + k * 1.9
            s += [RB((hinge, 4.8, z), (0.32, 8.4, 0.32), "Charcoal"), RK((hinge, 9.4, z), 0.7, 0.05, 0.9, "Gold", seg=4)]
    s += [
        RB((0, 21.5, 0), (22.2, 5, 4), "Cream", bevel=0.15),
        RB((0, 18.8, 0), (22.6, 0.6, 4.6), "Gold", bevel=0.08),
        RB((0, 24.2, 0), (22.6, 0.6, 4.6), "Gold", bevel=0.08),
        RB((0, 21.5, -2.15), (19.6, 3.4, 0.3), "Navy"),
        RB((0, 21.5, 2.15), (19.6, 3.4, 0.3), "Navy"),
        STAR((0, 27.4, 0), 5.0, 1.3, "Gold"),
    ]
    # The guard booth.
    bx, bz = -22, -4
    s += [
        RB((bx, 0.3, bz), (5.6, 0.6, 5.6), "Burgundy", bevel=0.1),
        RB((bx, 2.8, bz), (5, 4.4, 5), "Cream", bevel=0.15),
        RB((bx, 3.4, bz - 2.55), (3.6, 1.8, 0.2), "Glass"),
        RB((bx + 2.55, 3.4, bz), (0.2, 1.8, 3.2), "Glass"),
        RB((bx, 2.6, bz - 2.6), (1.4, 0.2, 0.6), "Gold"),
        RB((bx, 5.3, bz), (6.4, 0.6, 6.4), "Burgundy", bevel=0.12),
        RK((bx, 6.1, bz), 6.0, 1.0, 1.0, "Burgundy", seg=4, yaw=45),
        RE((bx, 6.9, bz), (1, 1, 1), "Light", neon=True),
    ]
    return s


def plaza_fountain():
    """The spawn plaza fountain's stone (MapModels.fountain): an 18-across basin with a burgundy
    rim and a pedestal for the trophy. The water, jets and trophy stay separate."""
    radius = 9
    s = [RC((0, 0.7, 0), radius * 2, 1.4, "Cream", seg=12)]
    n = 12
    for i in range(n):
        a = i * 360 / n
        width = 2 * math.pi * radius / n + 0.4
        s.append(RG((0, 0, 0), a, RB((0, 1.65, -radius + 0.55), (width, 0.6, 1.4), "Burgundy", bevel=0.12)))
    s += [
        RC((0, 1.6, 0), 6, 3.2, "Burgundy", seg=8),
        RC((0, 3, 0), 6.4, 0.4, "Gold", seg=8),
        RC((0, 3.5, 0), 6.8, 0.6, "Cream", seg=8),
        RB((0, 2.3, -3.0), (3.4, 1, 0.2), "Gold"),
        RB((0, 2.3, 3.0), (3.4, 1, 0.2), "Gold"),
    ]
    return s


def park_arch():
    """Starlight Park's entrance arch (in TownSets.park): pillars, a beam and a blank green sign,
    with a gold star on top. Centred on z = 4."""
    s = []
    for x in (-10, 10):
        s += [
            RB((x, 5.5, 4), (3.4, 11, 3.4), "Cream", bevel=0.15),
            RB((x, 0.4, 4), (4.2, 0.8, 4.2), "ParkGreen", bevel=0.1),
            RB((x, 11.5, 4), (4, 1, 4), "DarkGreen", bevel=0.12),
            RF((x, 12.9, 4), (1.8, 1.8, 1.8), "Gold"),
            # Ivy climbing the pillars.
            RL((x - 1.5, 3.5, 2.6), (1.4, 2.4, 1.0), "Leaf"),
            RL((x + 1.4, 7.0, 2.6), (1.2, 2.0, 0.9), "LeafDark"),
        ]
    s += [
        RB((0, 11.5, 4), (24, 2, 2.4), "DarkGreen", bevel=0.15),
        RB((0, 15, 4), (19, 4.4, 0.6), "Gold", bevel=0.1),
        RB((0, 15, 4), (18, 3.6, 0.7), "Green"),
        STAR((0, 19.6, 4), 3.6, 1.0, "Gold"),
    ]
    return s


def park_fountain():
    """Starlight Park's fountain stone (rim, column and bowl). The water stays separate."""
    return [
        RC((0, 0.8, 0), 12, 1.6, "Stone", seg=10),
        RC((0, 1.66, 0), 12.4, 0.2, "Cream", seg=10),
        RC((0, 2.5, 0), 1.6, 3.4, "Stone", seg=8),
        RK((0, 1.2, 0), 2.6, 1.6, 0.8, "Stone", seg=8),
        RK((0, 4.2, 0), 2.0, 5.0, 0.8, "Stone", seg=10),
        RC((0, 4.65, 0), 5.2, 0.15, "Cream", seg=10),
    ]


def movie_screen():
    """The open-air movie screen (in TownSets.park, at z = 112): posts, a frame, a blank screen
    and a blank red marquee edged with bulbs."""
    s = []
    for x in (-24, 24):
        s += [
            RB((x, 15, 1), (2.4, 30, 2.4), "Charcoal", bevel=0.15),
            RB((x, 0.6, 1), (3.6, 1.2, 3.6), "Charcoal", bevel=0.1),
            RW((x, 3, 3.6), (1.2, 6, 3), "Charcoal"),
        ]
    s += [
        RB((0, 17, 1), (46, 24, 1), "Charcoal", bevel=0.2),
        RB((0, 17, 0.4), (43, 21, 0.4), "OffWhite"),
        RB((0, 31, 1), (30, 3.6, 0.8), "Carpet", bevel=0.1),
        RB((0, 31, 1.2), (31, 4.4, 0.6), "Gold"),
    ]
    s += bulbs_row(-14.6, 14.6, 33.3, 0.7, 13, 0.5) + bulbs_row(-14.6, 14.6, 28.7, 0.7, 13, 0.5)
    return s


def pond_bridge():
    """The wooden bridge out to the pond's island: 28 long along x, 5 wide, centred."""
    length = 28
    s = [RB((0, 1.8, 0), (length, 0.8, 5), "Wood", bevel=0.08)]
    for i in range(int(length / 2.5) + 1):
        s.append(RB((-length / 2 + i * 2.5, 2.25, 0), (0.3, 0.12, 5), "Bark"))
    for side in (-1, 1):
        s.append(RB((0, 4.2, side * 2.3), (length, 0.5, 0.5), "Bark", bevel=0.06))
        for i in range(5):
            s.append(RB((-length / 2 + i * length / 4, 2.9, side * 2.3), (0.7, 3, 0.7), "Bark", bevel=0.06))
    s.append(RW((length / 2 + 1.5, 1.1, 0), (5, 2.2, 3), "Wood", yaw=-90))
    return s


def gold_star():
    """A gold star standing on its point, about 5 across (signs and arches)."""
    return [STAR((0, 2.6, 0), 5.0, 1.3, "Gold")]


# --- Street furniture --------------------------------------------------------------------------


def car(color):
    """A rounded vintage convertible (TownSets.car): about 4.4 wide, 9.6 long, nose toward -Z."""

    def build():
        s = [
            RB((0, 1.45, 0), (4.2, 1.5, 9), color, bevel=0.35),
            RB((0, 2.35, -2.6), (3.8, 0.5, 3.2), color, bevel=0.2),
            RB((0, 2.35, 3.2), (3.8, 0.5, 2.2), color, bevel=0.2),
            RB((0, 2.4, 0.6), (3.4, 1, 2.6), "OffWhite", bevel=0.2),
            RB((0, 3.1, -0.95), (3.6, 1.3, 0.15), "Glass", pitch=-20),
            RB((0, 2.45, -0.8), (3.7, 0.2, 0.3), "Chrome"),
            RB((0, 1.4, 0), (4.25, 0.25, 9.05), "OffWhite"),
            # Grille and tail fins.
            RB((0, 1.65, -4.55), (2.0, 0.7, 0.2), "Chrome", bevel=0.05),
        ]
        for z in (-2.9, 2.9):
            s.append(RB((0, 1.75, z), (4.5, 0.9, 2.6), color, bevel=0.35))
        for x in (-1.75, 1.75):
            s.append(RW((x, 2.7, 4.0), (0.35, 0.6, 1.6), color))
        for z in (-4.6, 4.6):
            s.append(RB((0, 1.0, z), (4.4, 0.45, 0.3), "Chrome", bevel=0.1))
        for x in (-1.4, 1.4):
            s.append(RC((x, 1.75, -4.55), 0.7, 0.18, "Light", pitch=90, seg=8, neon=True))
            s.append(RB((x, 1.6, 4.6), (0.6, 0.3, 0.15), "Carpet"))
        for x in (-1.95, 1.95):
            for z in (-2.9, 2.9):
                s.append(RC((x, 0.85, z), 1.7, 0.6, "Charcoal", roll=90, seg=10))
                s.append(RC((x, 0.85, z), 0.8, 0.64, "Chrome", roll=90, seg=8))
        return s

    return build


def bus_stop():
    """A bus stop (TownSets.busStop). The glass back stays a see-through part in the game; the
    poster and the round BUS sign are blank."""
    s = [
        RB((0, 7.2, 0.2), (8.4, 0.4, 3.6), "Burgundy", bevel=0.1),
        RB((0, 6.9, 0.2), (8.6, 0.25, 3.8), "Gold"),
        RB((0, 3.6, 1.75), (8.0, 0.4, 0.3), "Charcoal"),
        RB((0, 0.95, 1.75), (8.0, 0.3, 0.3), "Charcoal"),
        RB((1.8, 3.6, 1.42), (3, 4.2, 0.12), "#6EBE50"),
        RB((-1.6, 1.5, 0.8), (4.6, 0.35, 1.2), "Wood", bevel=0.06),
        RB((-1.6, 2.3, 1.35), (4.6, 1.0, 0.2), "Wood", bevel=0.05),
        RC((5.2, 3.75, -1.3), 0.3, 7.5, "Charcoal", seg=6),
        RC((5.2, 7.6, -1.3), 2.2, 0.3, "Blue", pitch=90, seg=12),
        RC((5.2, 7.6, -1.2), 2.5, 0.2, "OffWhite", pitch=90, seg=12),
    ]
    for x in (-3.9, 3.9):
        s += [RB((x, 3.4, -1.3), (0.35, 6.8, 0.35), "Charcoal"), RB((x, 3.4, 1.7), (0.35, 6.8, 0.35), "Charcoal")]
    for x in (-3.4, 0.2):
        s.append(RB((x, 0.65, 0.8), (0.3, 1.3, 1), "Charcoal"))
    return s


def hydrant():
    return [
        RC((0, 0.15, 0), 1.3, 0.3, "Carpet", seg=8),
        RC((0, 1.1, 0), 0.9, 1.6, "Carpet", seg=8),
        RC((0, 1.75, 0), 1.1, 0.2, "Carpet", seg=8),
        RK((0, 2.05, 0), 0.95, 0.35, 0.5, "Carpet", seg=8),
        RC((0, 2.4, 0), 0.3, 0.25, "Gold", seg=6),
        RC((0, 1.3, 0), 0.4, 1.5, "Gold", roll=90, seg=6),
        RC((0, 1.3, -0.5), 0.45, 0.3, "Gold", pitch=90, seg=6),
    ]


def trash_bin():
    return [
        RK((0, 1.1, 0), 1.5, 1.7, 2.2, "DarkGreen", seg=8),
        RC((0, 1.8, 0), 1.75, 0.3, "Gold", seg=8),
        RK((0, 2.4, 0), 1.85, 1.2, 0.4, "Charcoal", seg=8),
        RC((0, 2.7, 0), 0.4, 0.3, "Charcoal", seg=6),
    ]


def news_stand():
    """A green kiosk (TownSets.newsStand) with stacks of papers and a striped roof; its sign board
    is blank."""
    s = [
        RB((0, 1.7, 0), (4.4, 3.4, 2.6), "DarkGreen", bevel=0.12),
        RB((0, 2.3, -1.8), (4.6, 0.3, 1.2), "Wood", bevel=0.05),
        RB((0, 3.2, -1.35), (4, 0.9, 0.2), "Navy"),
        RB((0, 0.2, 0), (4.6, 0.4, 2.8), "Charcoal"),
    ]
    for i in range(3):
        s.append(RB((-1.4 + i * 1.4, 2.65, -1.8), (1.1, 0.4, 0.9), "OffWhite", yaw=(i - 1) * 6))
    for k in range(4):
        s.append(RB((-1.8 + k * 1.2, 4.5, -0.5), (1.2, 0.25, 3.6), "Carpet" if k % 2 == 0 else "OffWhite", pitch=-12))
    return s


def poster_column():
    """A round poster column with a gold dome (TownSets.posterColumn). The posters, with their
    film's color and title, stay in the game."""
    return [
        RC((0, 0.4, 0), 3.4, 0.8, "Burgundy", seg=10),
        RC((0, 4, 0), 2.8, 6.4, "Cream", seg=10),
        RC((0, 7.4, 0), 3.2, 0.5, "Burgundy", seg=10),
        RK((0, 8.1, 0), 2.6, 1.0, 1.0, "Gold", seg=10),
        RF((0, 8.85, 0), (0.8, 0.8, 0.8), "Gold"),
    ]


# --- The back street film sets ----------------------------------------------------------------


def director_chair():
    """A director's chair, facing -Z (its back board is blank)."""
    s = []
    for x in (-0.9, 0.9):
        s += [
            RB((x, 1.3, -0.5), (0.25, 2.6, 0.25), "Wood", pitch=8),
            RB((x, 1.3, 0.6), (0.25, 2.8, 0.25), "Wood", pitch=-8),
            RB((x, 2.0, 0), (0.25, 0.25, 1.5), "Wood"),
        ]
    s += [
        RB((0, 1.5, 0), (1.8, 0.15, 1.5), "Charcoal"),
        RB((0, 2.5, 0.7), (2.0, 0.8, 0.15), "Charcoal"),
        RB((0, 0.8, -0.5), (1.8, 0.2, 0.2), "Wood"),
    ]
    return s


def light_stand():
    """A film light on a tripod, its glowing face toward -Z."""
    s = [
        RC((0, 3.2, 0), 0.3, 6, "Steel", seg=6),
        RB((0, 6.6, 0), (2.2, 1.8, 1.2), "Charcoal", bevel=0.12),
        RB((0, 6.6, -0.62), (1.8, 1.4, 0.1), "Light", neon=True),
        RB((0, 7.6, -0.7), (2.2, 0.15, 0.6), "Charcoal", pitch=25),
        RB((-1.15, 6.6, -0.7), (0.15, 1.8, 0.6), "Charcoal", yaw=-25),
        RB((1.15, 6.6, -0.7), (0.15, 1.8, 0.6), "Charcoal", yaw=25),
    ]
    for a in (0, 120, 240):
        s.append(RG((0, 0, 0), a, RB((0, 0.9, -0.8), (0.18, 2.0, 0.18), "Steel", pitch=-35)))
    return s


def crate():
    """A wooden prop crate, 3 studs a side (the game scales it)."""
    return [
        RB((0, 1.5, 0), (3, 3, 3), "Wood", bevel=0.12),
        RB((0, 1.5, 0), (3.1, 0.55, 3.1), "Bark"),
        RB((0, 1.5, -1.52), (0.4, 3.0, 0.1), "Bark", roll=45),
    ]


def camera_crane():
    """The green screen set's camera crane: a dolly, a post and a long arm with the camera, the
    arm reaching toward -X (TownSets.greenScreen)."""
    arm = [
        RB((2.5, 0, 0), (11, 0.6, 0.6), "Gold", bevel=0.08),
        RB((-2.6, -0.5, 0), (1.6, 1.6, 1.6), "Charcoal", bevel=0.12),
        RB((8.2, -1, 0), (1.8, 1.4, 1.2), "Charcoal", bevel=0.12),
        RC((9.4, -1, 0), 0.8, 0.9, "Steel", roll=90, seg=8),
        RC((8.0, -0.1, 0), 1.0, 0.4, "Charcoal", pitch=90, seg=8),
    ]
    return [
        RB((0, 0.7, 0), (3, 1, 4.4), "Charcoal", bevel=0.12),
        RC((-1.2, 0.35, -1.6), 0.7, 0.4, "Steel", roll=90, seg=8),
        RC((1.2, 0.35, -1.6), 0.7, 0.4, "Steel", roll=90, seg=8),
        RC((-1.2, 0.35, 1.6), 0.7, 0.4, "Steel", roll=90, seg=8),
        RC((1.2, 0.35, 1.6), 0.7, 0.4, "Steel", roll=90, seg=8),
        RC((0, 3.7, 0), 0.8, 5, "Steel", seg=8),
        RG((0, 6.3, 0), 0, *arm, roll=14),
    ]


def dino_head():
    """The props yard's monster-movie dinosaur head, mouth open toward -Z."""
    s = [
        RB((0, 1.5, 2.8), (3.4, 3, 3.4), "Dino", bevel=0.3),
        RB((0, 4, 0.6), (4.4, 3.8, 5), "Dino", bevel=0.4),
        RB((0, 4.4, -3.4), (3.6, 2.2, 4), "Dino", bevel=0.35),
        RB((0, 2.3, -2.6), (3.2, 0.9, 4.6), "DinoDark", pitch=-12, bevel=0.25),
        RB((0, 3.25, -3.4), (2.8, 0.3, 3.6), "Carpet"),
    ]
    for x in (-1.3, -0.45, 0.45, 1.3):
        s.append(RK((x, 3.0, -5.0), 0.45, 0.05, 0.8, "OffWhite", pitch=180, seg=4))
        s.append(RK((x, 2.95, -4.6), 0.4, 0.05, 0.6, "OffWhite", seg=4))
    for x in (-1.6, 1.6):
        s += [RF((x * 1.06, 5.2, -0.9), (0.9, 0.9, 0.9), "Gold"), RE((x * 1.06, 5.2, -1.3), (0.35, 0.5, 0.2), "Charcoal"),
              RB((x * 1.06, 5.95, -0.9), (1.3, 0.45, 1.5), "DinoDark", bevel=0.1, roll=-x * 6)]
    for i in range(3):
        s.append(RK((0, 6.5 + 0.6, 2.4 - i * 1.8), 1.3, 0.05, 1.4, "Carpet", seg=4, yaw=45))
    for x in (-1.0, 1.0):
        s.append(RE((x, 5.6, -5.0), (0.4, 0.3, 0.3), "DinoDark"))
    return s


def prop_moon():
    """A fake moon on a stand, for space movies."""
    s = [
        RB((0, 0.6, 0), (2.4, 1.2, 2.4), "Charcoal", bevel=0.12),
        RC((0, 1.6, 0), 0.6, 1.2, "Steel", seg=6),
        RF((0, 4.2, 0), (6, 6, 6), "Moon", tones=("Moon", "#D2D2C6", "#EAEAE0")),
    ]
    for c in ((-1.6, 1, -2.3), (1.2, -0.6, -2.6), (0.3, 1.9, -1.9), (-2.0, -1.2, -1.6), (2.3, 1.1, -1.0)):
        s.append(RF((c[0], 4.2 + c[1], c[2]), (1.4, 1.4, 0.6), "Crater"))
    return s


def spot_cart():
    """A rolling spotlight, its lamp tilted up toward -Z."""
    return [
        RB((0, 0.8, 0), (2.6, 0.8, 2.6), "Carpet", bevel=0.12),
        RC((-1.0, 0.35, -1.0), 0.6, 0.3, "Charcoal", roll=90, seg=6),
        RC((1.0, 0.35, -1.0), 0.6, 0.3, "Charcoal", roll=90, seg=6),
        RC((-1.0, 0.35, 1.0), 0.6, 0.3, "Charcoal", roll=90, seg=6),
        RC((1.0, 0.35, 1.0), 0.6, 0.3, "Charcoal", roll=90, seg=6),
        RB((-1.15, 2.0, 0), (0.25, 2.2, 0.6), "Steel"),
        RB((1.15, 2.0, 0), (0.25, 2.2, 0.6), "Steel"),
        RC((0, 2.6, 0), 2.0, 2.4, "Steel", pitch=-70, seg=10),
        RC((0, 2.6 + 0.42, -1.15), 1.7, 0.12, "Light", pitch=-70, seg=10, neon=True),
    ]


def clapperboard():
    """A giant clapperboard, standing up and facing -Z."""
    s = [RB((0, 1.8, 0), (5, 3.6, 0.4), "Charcoal", bevel=0.08)]
    for i in range(4):
        s.append(RB((-1.875 + i * 1.25, 4.0, 0), (1.25, 0.8, 0.45), "OffWhite" if i % 2 == 0 else "Charcoal"))
    s += [
        RB((0, 4.75, 0), (5, 0.5, 0.45), "Charcoal", roll=-10),
        RB((0, 2.4, -0.22), (4.2, 0.12, 0.05), "OffWhite"),
        RB((0, 1.4, -0.22), (4.2, 0.12, 0.05), "OffWhite"),
        RB((0, 1.9, -0.22), (0.12, 1.1, 0.05), "OffWhite"),
    ]
    return s


def set_sign():
    """A film set's sign on a post; the board is blank (the game writes the set's name)."""
    return [
        RB((0, 3, 0.3), (0.4, 6, 0.4), "Charcoal"),
        RB((0, 5.6, 0), (6.4, 2.2, 0.3), "Gold", bevel=0.08),
        RB((0, 5.6, -0.1), (6, 1.8, 0.3), "OffWhite"),
        RK((0, 6.95, 0.3), 0.6, 0.1, 0.5, "Gold", seg=6),
    ]


def trailer(color):
    """A star trailer (TownSets.trailers): about 5.4 wide and 13 long along z, its door, steps and
    awning on the -X side."""

    def build():
        s = [
            RB((0, 3.4, 0), (5.4, 5, 13), "OffWhite", bevel=0.4),
            RB((0, 2.4, 0), (5.5, 0.9, 13.1), color),
            RB((0, 6.05, 0), (5.2, 0.5, 12.6), "Steel", bevel=0.2),
            RB((0, 6.5, 2.5), (2.4, 0.6, 2.4), "Steel", bevel=0.1),
            RB((-2.75, 3.2, 0), (0.2, 3.6, 1.8), "Burgundy"),
            RB((-3.6, 0.5, 0), (1.6, 0.6, 2.2), "Steel"),
            RB((0, 1.0, -7.3), (1.0, 0.5, 2.0), "Charcoal"),
            STAR((-2.95, 3.9, 0), 1.1, 0.3, "Gold", yaw=-90),
        ]
        for z in (-4, 4):
            s += [RC((-2.3, 0.9, z), 1.8, 0.8, "Charcoal", roll=90, seg=10), RC((2.3, 0.9, z), 1.8, 0.8, "Charcoal", roll=90, seg=10)]
        for z in (-4.2, 4.2):
            s += [RB((-2.75, 4.2, z), (0.2, 1.4, 2.4), "Glass"), RB((-2.8, 4.2, z), (0.15, 1.7, 2.7), color)]
        for k in range(3):
            s.append(RB((-4, 5.2, -2.6 + k * 2.6), (2.4, 0.2, 2.6), color if k % 2 == 0 else "OffWhite", roll=-12))
        return s

    return build


def patio_table():
    return [
        RC((0, 2.1, 0), 2.4, 0.2, "OffWhite", seg=8),
        RC((0, 1.15, 0), 0.3, 1.9, "Steel", seg=6),
        RC((0, 0.15, 0), 1.2, 0.3, "Steel", seg=6),
    ]


def taco_truck():
    """The pink taco truck (TownSets.foodCorner), nose toward -Z, its hatch on the -X side. The
    roof sign is blank."""
    s = [
        RB((0, 4, 1), (5.6, 6, 12), "Pink", bevel=0.35),
        RB((0, 2, 1), (5.7, 0.8, 12.1), "OffWhite"),
        RB((0, 3.3, -6.8), (5.6, 4.6, 4), "Pink", bevel=0.4),
        RB((0, 4.6, -8.85), (4.8, 1.8, 0.2), "Glass"),
        RB((2.85, 4.6, -6.6), (0.2, 1.6, 2.4), "Glass"),
        RB((-2.85, 4.6, -6.6), (0.2, 1.6, 2.4), "Glass"),
        RB((0, 1.3, -8.9), (5.8, 0.6, 0.4), "Steel", bevel=0.1),
        RB((0, 0.9, 7.1), (5.8, 0.5, 0.3), "Steel"),
        RB((-2.85, 4.6, 1.4), (0.2, 2.4, 6.4), "Navy"),
        RB((-3.3, 3.3, 1.4), (1, 0.3, 6.4), "OffWhite"),
        RB((-1.6, 8, 1), (0.4, 1.8, 8), "Gold", bevel=0.08),
        RB((-1.2, 8, 1), (0.3, 1.8, 8), "Pink"),
        RB((-1.4, 7.05, -2.0), (0.3, 0.4, 0.3), "Charcoal"),
        RB((-1.4, 7.05, 4.0), (0.3, 0.4, 0.3), "Charcoal"),
    ]
    for z in (-6.5, 4.5):
        s += [RC((-2.5, 1, z), 2, 0.9, "Charcoal", roll=90, seg=10), RC((2.5, 1, z), 2, 0.9, "Charcoal", roll=90, seg=10)]
    for x in (-1.6, 1.6):
        s.append(RC((x, 3.2, -8.9), 0.8, 0.2, "Light", pitch=90, seg=8, neon=True))
    for k in range(4):
        s.append(RB((-3.8, 6.4, -1 + k * 1.6), (2.4, 0.2, 1.6), "Gold" if k % 2 == 0 else "OffWhite", roll=-14))
    # A big taco on the roof.
    s += [
        RC((1.0, 7.8, 4.5), 3.2, 1.0, "Gold", pitch=90, seg=10),
        RL((1.0, 8.4, 4.5), (2.6, 1.0, 0.8), "Leaf"),
        RL((1.0, 8.6, 4.5), (1.8, 0.7, 0.7), "Carpet"),
    ]
    return s


def popcorn_cart():
    """The popcorn cart, long side along x, with a striped bucket of popcorn on top."""
    s = [
        RB((0, 2, 0), (4, 2.4, 2.2), "Carpet", bevel=0.15),
        RB((0, 3.3, 0), (4.1, 0.4, 2.3), "OffWhite", bevel=0.08),
        RB((0, 2.0, -1.12), (2.2, 1.0, 0.1), "Gold"),
        RB((0, 6.4, 0), (4.6, 0.3, 2.8), "OffWhite", bevel=0.08),
        RK((0, 6.8, 0), 3.6, 1.0, 0.6, "Carpet", seg=4, yaw=45),
        RC((-1.4, 0.8, -1.2), 1.6, 0.4, "Charcoal", pitch=90, seg=10),
        RC((1.4, 0.8, -1.2), 1.6, 0.4, "Charcoal", pitch=90, seg=10),
        RC((2.4, 3.0, 0), 0.25, 1.4, "Steel", roll=90, seg=6),
    ]
    for x in (-1.9, 1.9):
        s.append(RB((x, 5, 0), (0.2, 3, 0.2), "Gold"))
    # The bucket: red and white stripes, popcorn heaped on top.
    for k in range(8):
        a = k * 45
        s.append(RG((0, 0, 0), a, RB((0, 4.4, -0.62), (0.5, 1.6, 0.12), "Carpet" if k % 2 == 0 else "OffWhite")))
    s.append(RK((0, 4.4, 0), 1.1, 1.4, 1.6, "OffWhite", seg=8))
    for p in ((0, 5.4, 0), (0.4, 5.3, -0.3), (-0.4, 5.3, 0.3), (0.3, 5.5, 0.4), (-0.35, 5.5, -0.35), (0, 5.8, 0)):
        s.append(RL(p, (0.7, 0.6, 0.7), "#FFF4C8"))
    return s


def cafe_table(color):
    """A café table under an umbrella (eight-sided, striped), with two stools."""

    def build():
        s = [
            RC((0, 2.1, 0), 2.6, 0.25, "OffWhite", seg=8),
            RC((0, 2.9, 0), 0.25, 5.6, "Steel", seg=6),
            RC((0, 0.15, 0), 1.2, 0.3, "Steel", seg=6),
            RK((0, 5.85, 0), 5.8, 0.6, 1.3, color, seg=8),
            RK((0, 5.86, 0), 5.0, 0.5, 1.15, "OffWhite", seg=8, yaw=22.5),
            RF((0, 6.65, 0), (0.5, 0.5, 0.5), "Gold"),
        ]
        for dz in (-1.9, 1.9):
            s += [RC((0, 1.1, dz), 1.2, 0.25, "Carpet", seg=8), RC((0, 0.5, dz), 0.3, 1.0, "Steel", seg=6)]
        return s

    return build


# --- Dusty Gulch and the park's small things ---------------------------------------------------


def barrel():
    return [
        RK((0, 0.65, 0), 1.8, 2.15, 1.3, "Wood", seg=10),
        RK((0, 1.95, 0), 2.15, 1.8, 1.3, "Wood", seg=10),
        RC((0, 0.5, 0), 2.0, 0.25, "Charcoal", seg=10),
        RC((0, 2.1, 0), 2.0, 0.25, "Charcoal", seg=10),
        RC((0, 2.62, 0), 1.6, 0.06, "Bark", seg=10),
    ]


def hay_bale():
    return [
        RB((0, 1, 0), (3.4, 2, 2.2), "Hay", bevel=0.25),
        RB((-0.9, 1, 0), (0.2, 2.06, 2.26), "Bark"),
        RB((0.9, 1, 0), (0.2, 2.06, 2.26), "Bark"),
        RB((0.3, 2.05, -0.4), (1.2, 0.12, 0.2), "#E6B96E", yaw=30),
    ]


def wagon():
    """The covered wagon: a bed on four big spoked wheels under a white canvas hoop."""
    s = [
        RB((0, 2.4, 0), (5, 2, 9), "Wood", bevel=0.12),
        RB((0, 3.5, 0), (5.2, 0.4, 9.2), "Carpet"),
        RB((0, 2.0, -6.0), (0.5, 0.4, 4.0), "Bark"),
    ]
    # The canvas: a half-tube of flat boards over hoops.
    n = 7
    for i in range(n):
        a = -90 + 180 * i / (n - 1)
        x, y = math.sin(math.radians(a)) * 2.6, 3.6 + math.cos(math.radians(a)) * 2.6
        s.append(RB((x, y, 0), (1.3, 0.3, 8), "OffWhite", roll=-a))
    for z in (-3.8, 0, 3.8):
        for i in range(n):
            a = -90 + 180 * i / (n - 1)
            x, y = math.sin(math.radians(a)) * 2.75, 3.6 + math.cos(math.radians(a)) * 2.75
            s.append(RB((x, y, z), (1.3, 0.2, 0.3), "Bark", roll=-a))
    for x in (-2.8, 2.8):
        for z in (-3, 3):
            s += [RC((x, 1.7, z), 3.4, 0.4, "Bark", roll=90, seg=12), RC((x, 1.7, z), 1.0, 0.6, "Gold", roll=90, seg=8)]
            for k in range(4):
                s.append(RB((x, 1.7, z), (0.3, 3.0, 0.2), "Bark", pitch=k * 45))
    return s


def duck():
    """A yellow duck, 2.4 long (the game scales it)."""
    return [
        RL((0, 0.7, 0), (1.8, 1.3, 2.4), "Duck"),
        RW((0, 1.25, 1.25), (1.0, 0.8, 0.9), "Duck"),
        RL((0, 1.9, -0.9), (1.25, 1.25, 1.25), "Duck"),
        RK((0, 1.75, -1.75), 0.55, 0.2, 0.8, "Beak", pitch=90, seg=6),
        RE((-0.6, 2.1, -1.2), (0.15, 0.3, 0.3), "Charcoal"),
        RE((0.6, 2.1, -1.2), (0.15, 0.3, 0.3), "Charcoal"),
        RL((-0.85, 0.9, 0.2), (0.3, 0.8, 1.4), "#F5C21E"),
        RL((0.85, 0.9, 0.2), (0.3, 0.8, 1.4), "#F5C21E"),
    ]


def picnic_blanket():
    s = []
    for i in range(3):
        for k in range(3):
            s.append(RB(((i - 1) * 2.4, 0.24, (k - 1) * 2.4), (2.4, 0.08, 2.4), "Carpet" if (i + k) % 2 == 0 else "OffWhite"))
    s += [
        RB((0.8, 0.8, 0.4), (1.8, 1.2, 1.2), "Wood", bevel=0.12),
        RB((0.8, 1.45, 0.4), (1.9, 0.15, 1.3), "Bark"),
        RB((0.8, 1.9, 0.4), (1.2, 0.2, 0.2), "Bark"),
        RB((0.35, 1.9, 0.4), (0.2, 0.9, 0.2), "Bark"),
        RB((1.25, 1.9, 0.4), (0.2, 0.9, 0.2), "Bark"),
        RL((-1.6, 0.45, -1.2), (0.9, 0.4, 0.9), "Carpet"),
        RC((-0.6, 0.6, -1.6), 0.5, 0.8, "#6EBE50", seg=6),
    ]
    return s


def gulch_arch():
    """Dusty Gulch's welcome arch (in TownSets.westernTown, centred on z = 6): two log posts, a
    beam, chains and a blank red sign, with a gold star on top."""
    s = []
    for x in (-16, 16):
        s += [
            RC((x, 8.5, 6), 2.4, 17, "Bark", seg=7),
            RC((x, 17.4, 6), 3.0, 0.8, "Wood", seg=7),
            RK((x, 0.6, 6), 3.6, 2.4, 1.2, "Bark", seg=7),
        ]
    s += [
        RB((0, 15.6, 6), (36, 2, 2.2), "Wood", bevel=0.2),
        RB((0, 16.7, 6), (36.6, 0.3, 2.6), "Bark"),
        RB((0, 10, 6), (22, 5.4, 0.6), "Bark", bevel=0.12),
        RB((0, 10, 6), (20.6, 4.4, 0.8), "#C44632"),
        STAR((0, 19.4, 6), 3.8, 1.0, "Gold"),
    ]
    for x in (-6, 6):
        for k in range(3):
            s.append(RB((x, 12.6 + k * 0.8, 6), (0.35, 0.7, 0.2), "Charcoal", yaw=k * 90))
    # A cow skull nailed to the beam.
    s += [RL((0, 15.6, 4.7), (2.0, 1.4, 0.8), "OffWhite"), RK((-1.4, 16.1, 4.7), 0.5, 0.1, 1.4, "OffWhite", roll=60, seg=5),
          RK((1.4, 16.1, 4.7), 0.5, 0.1, 1.4, "OffWhite", roll=-60, seg=5)]
    return s


def hitch_rail():
    """A hitching rail, 8 long along z, with a water trough beside it."""
    return [
        RB((0, 2.8, 0), (0.5, 0.5, 8), "Wood", bevel=0.08),
        RB((0, 1.5, -3.6), (0.6, 3, 0.6), "Bark", bevel=0.06),
        RB((0, 1.5, 3.6), (0.6, 3, 0.6), "Bark", bevel=0.06),
    ]


def trough():
    """A wooden water trough, 6 long along z (the water stays a part)."""
    return [
        RB((0, 0.9, 0), (2.2, 1.6, 6), "Bark", bevel=0.1),
        RB((-0.75, 0.3, -2.4), (0.4, 0.6, 0.4), "Wood"),
        RB((0.75, 0.3, 2.4), (0.4, 0.6, 0.4), "Wood"),
    ]


def tumbleweed():
    """A tumbleweed, about 2.6 across: a tangle of faceted twigs."""
    return [
        RL((0, 1.3, 0), (2.6, 2.4, 2.6), "#BE965F"),
        RL((0.3, 1.5, -0.2), (2.0, 2.0, 2.2), "#A8824E", yaw=40),
        RL((-0.4, 1.2, 0.3), (1.8, 1.6, 1.8), "#D2AE78", yaw=80),
    ]


# --- Hills, mountains and the ground's small things --------------------------------------------


def hill(main, *tones):
    """A big low-poly hill: a faceted ball 100 across (the game scales and sinks it), its facets
    in a few shades."""
    return lambda: [RF((0, 50, 0), (100, 100, 100), main, tones=(main,) + tones)]


def mountain():
    """A big low-poly mountain about 200 across and 110 tall: grassy feet, rocky shoulders, a snow
    cap and two smaller peaks at its sides (the game scales it to each mountain on the ring)."""
    s = [
        toned(RK((0, 14, 0), 200, 150, 28, "Grass", seg=7), "Grass", "#56A84C", "#6CBD5C"),
        toned(RK((0, 48, 0), 152, 64, 40, "#8A8590", seg=7, yaw=20), "#8A8590", "#7C7782", "#9A95A0"),
        toned(RK((0, 80, 0), 66, 14, 26, "Snow", seg=7, yaw=8), "Snow", "#E6ECF6", "#FFFFFF"),
        toned(RK((0, 98, 0), 15, 0.5, 12, "Snow", seg=6, yaw=40), "Snow", "#E6ECF6"),
        toned(RK((-62, 34, 30), 90, 6, 64, "#8A8590", seg=6, yaw=12), "#8A8590", "#7C7782", "#9A95A0"),
        toned(RK((-62, 72, 30), 16, 0.5, 12, "Snow", seg=6, yaw=30), "Snow", "#E6ECF6"),
        toned(RK((58, 28, -24), 84, 5, 52, "#8A8590", seg=6, yaw=50), "#8A8590", "#7C7782", "#9A95A0"),
        toned(RK((58, 58, -24), 14, 0.5, 9, "Snow", seg=6, yaw=10), "Snow", "#E6ECF6"),
    ]
    return s


def grass_tuft():
    """A clump of grass blades, about 2 across."""
    s = []
    for i, (x, z, h, yaw) in enumerate(((0, 0, 1.6, 0), (0.5, 0.2, 1.2, 40), (-0.5, 0.1, 1.3, -30), (0.1, -0.5, 1.1, 80), (-0.2, 0.5, 1.0, 120))):
        s.append(RK((x, h / 2, z), 0.6, 0.05, h, "Grass" if i % 2 == 0 else "#4E9E46", yaw=yaw, seg=3))
    return s


def flower_patch():
    """A few flowers on a leafy mound, about 3 across."""
    s = [RL((0, 0.3, 0), (3.0, 0.7, 2.6), "Leaf")]
    for (x, z), color in zip(((-0.8, -0.5), (0.7, -0.3), (0.1, 0.6), (-0.4, 0.2), (1.0, 0.5)), ("Carpet", "Gold", "Pink", "OffWhite", "#B07CFF")):
        s += [RC((x, 0.9, z), 0.12, 1.0, "DarkGreen", seg=4), RF((x, 1.45, z), (0.7, 0.4, 0.7), color), RF((x, 1.55, z), (0.25, 0.25, 0.25), "Gold" if color != "Gold" else "OffWhite")]
    return s


def boulder():
    """A grey mossy boulder, about 5 across."""
    return [
        RL((0, 1.5, 0), (5.0, 3.2, 4.2), "Stone", yaw=20),
        RL((1.9, 0.9, 1.0), (2.4, 1.8, 2.2), "#9AA0AC", yaw=60),
        RL((-0.4, 3.0, -0.2), (2.4, 0.5, 2.0), "Leaf", yaw=10),
    ]


# --- Living things -----------------------------------------------------------------------------


def cloud():
    """A puffy low-poly cloud about 40 across, flat underneath."""
    s = []
    for (x, y, z), (w, h, d) in (
        ((0, 6, 0), (22, 12, 16)),
        ((-11, 4.5, 2), (16, 9, 12)),
        ((12, 4.5, -1), (17, 9, 13)),
        ((-4, 9, -2), (14, 10, 11)),
        ((6, 8.5, 3), (13, 9, 10)),
        ((-18, 3, -1), (9, 6, 8)),
        ((19, 3, 2), (9, 6, 8)),
    ):
        s.append(RF((x, y, z), (w, h, d), "Cloud", tones=("Cloud", "#F6F9FF", "#EEF3FB")))
    s.append(RF((0, 1.6, 0), (38, 3.2, 14), "CloudShade", tones=("CloudShade", "#DCE6F2")))
    return s


def bird():
    """A white gull gliding, wings out, about 4 across and 2 long, nose toward -Z."""
    return [
        RE((0, 0, 0), (0.7, 0.6, 1.9), "OffWhite"),
        RE((0, 0.25, -0.9), (0.55, 0.55, 0.6), "OffWhite"),
        RK((0, 0.2, -1.35), 0.25, 0.04, 0.4, "Beak", pitch=90, seg=4),
        RW((0, 0.1, 1.1), (0.7, 0.2, 0.7), "#DDE3EA", yaw=180),
        RB((-1.0, 0.25, 0), (1.6, 0.12, 0.9), "OffWhite", roll=12),
        RB((1.0, 0.25, 0), (1.6, 0.12, 0.9), "OffWhite", roll=-12),
        RB((-2.3, 0.65, 0.15), (1.2, 0.1, 0.7), "#C9D0DA", roll=24),
        RB((2.3, 0.65, 0.15), (1.2, 0.1, 0.7), "#C9D0DA", roll=-24),
        RB((-2.95, 0.95, 0.25), (0.4, 0.1, 0.5), "Charcoal", roll=24),
        RB((2.95, 0.95, 0.25), (0.4, 0.1, 0.5), "Charcoal", roll=-24),
    ]


def butterfly(color, spot):
    """A butterfly, wings open, about 1.6 across."""

    def build():
        return [
            RC((0, 0, 0), 0.14, 0.9, "Charcoal", pitch=90, seg=4),
            RB((-0.45, 0.05, -0.2), (0.8, 0.1, 0.7), color, yaw=-15),
            RB((0.45, 0.05, -0.2), (0.8, 0.1, 0.7), color, yaw=15),
            RB((-0.35, 0.05, 0.3), (0.55, 0.1, 0.5), spot, yaw=20),
            RB((0.35, 0.05, 0.3), (0.55, 0.1, 0.5), spot, yaw=-20),
        ]

    return build


KIT = [
    ("Theatre", theatre),
    ("StudioGate", studio_gate),
    ("PlazaFountain", plaza_fountain),
    ("ParkArch", park_arch),
    ("ParkFountain", park_fountain),
    ("MovieScreen", movie_screen),
    ("PondBridge", pond_bridge),
    ("GoldStar", gold_star),
    ("CarTeal", car("Teal")),
    ("CarPink", car("Pink")),
    ("CarGold", car("Gold")),
    ("CarRed", car("Carpet")),
    ("BusStop", bus_stop),
    ("Hydrant", hydrant),
    ("TrashBin", trash_bin),
    ("NewsStand", news_stand),
    ("PosterColumn", poster_column),
    ("DirectorChair", director_chair),
    ("LightStand", light_stand),
    ("Crate", crate),
    ("CameraCrane", camera_crane),
    ("DinoHead", dino_head),
    ("PropMoon", prop_moon),
    ("SpotCart", spot_cart),
    ("Clapperboard", clapperboard),
    ("SetSign", set_sign),
    ("TrailerRed", trailer("Carpet")),
    ("TrailerBlue", trailer("Blue")),
    ("PatioTable", patio_table),
    ("TacoTruck", taco_truck),
    ("PopcornCart", popcorn_cart),
    ("CafeTableTeal", cafe_table("Teal")),
    ("CafeTableGold", cafe_table("Gold")),
    ("GulchArch", gulch_arch),
    ("HitchRail", hitch_rail),
    ("Trough", trough),
    ("Tumbleweed", tumbleweed),
    ("Barrel", barrel),
    ("HayBale", hay_bale),
    ("Wagon", wagon),
    ("Duck", duck),
    ("PicnicBlanket", picnic_blanket),
    ("Hill", hill("Grass", "#56A84C", "#6CBD5C", "#4E9E46")),
    ("HillDark", hill("#3E9450", "#388C46", "#47A05A", "#33804A")),
    ("HillSand", hill("Sand", "#E8C07E", "#F4D69C", "#DEAA6E")),
    ("Mountain", mountain),
    ("GrassTuft", grass_tuft),
    ("FlowerPatch", flower_patch),
    ("Boulder", boulder),
    ("Cloud", cloud),
    ("Bird", bird),
    ("ButterflyPink", butterfly("Pink", "Gold")),
    ("ButterflyBlue", butterfly("Blue", "Mint")),
]

# Line-ups for the preview renders (front row, back row, file name).
LINEUPS = [
    (["Hydrant", "TrashBin", "PosterColumn", "NewsStand", "BusStop", "CarTeal", "CarPink", "CarRed"], ["GoldStar", "PlazaFountain", "StudioGate", "Theatre"], "map_kit_town.png"),
    (["DirectorChair", "LightStand", "Crate", "Clapperboard", "SetSign", "SpotCart", "PropMoon", "DinoHead", "PatioTable", "CafeTableTeal"], ["CameraCrane", "PopcornCart", "TacoTruck", "TrailerRed"], "map_kit_sets.png"),
    (["Duck", "Barrel", "HayBale", "PicnicBlanket", "GrassTuft", "FlowerPatch", "Boulder", "ButterflyPink", "ButterflyBlue", "Bird"], ["Wagon", "ParkFountain", "PondBridge", "ParkArch", "Cloud"], "map_kit_park.png"),
    (["Hill", "HillSand"], ["Mountain"], "map_kit_land.png"),
]
