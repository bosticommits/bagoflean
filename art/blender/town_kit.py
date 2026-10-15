"""Town kit: the Blender models for the town's set pieces, which were part-built until now.
map_kit.py builds them together with its own models into the one map_kit.fbx and the one
MapKitShapes.luau (the part version), so run that file, not this one.

  Lobby       StoreStand<Color> (the eight store stands), PlazaFountain, Planter, BoulevardArch,
              TownPillar, HedgeSection, PosterColumn<Color>, VintageCar<Color>, BusStop, Hydrant,
              TrashBin, NewsStand, FlowerPatch
  Landmarks   PremiereTheatre, StudioGate, GuardBooth, HillStar, Blimp, CityTower1-3,
              Hill<Color> (the big hills round the town)
  Film sets   ChromaWall, CameraCrane, DirectorChair, LightStand, Clapperboard, SetSign<Color>,
              PropCrate, DinoHead, PropMoon, RollingSpotlight, StarTrailer<Color>, PatioTable,
              TacoTruck, PopcornCart, CafeTable<Color>
  Dusty Gulch GulchArch, Barrel, HayBale, Wagon, HitchRail, Trough, Fence<Color>, Tumbleweed,
              WantedBoard
  The park    ParkArch, ParkFountain, MovieScreen, Duck, PicnicBlanket, FootBridge, PondStone,
              LilyPad, LilyFlower
  Ambient     Bird, Butterfly, Cloud (moved round by the client, src/client/MapLife.luau)

Chunky low-poly toy style (ART_STYLE.md): bevelled edges, faceted foliage and rocks whose facets
take neighbouring shades, flat shading, the game palette. Words are never modelled: each sign
has a named spot (T) where the game letters it, so the text stays crisp and translatable.
Blender axes, in studs: Z up, the model faces -Y, standing on Z = 0.
"""

import math

from kitdsl import B, C, E, G, H, K, L, S, T, W, mirror_x, ring, shade  # noqa: F401

SLOPE_AWNING = math.degrees(math.atan2(1.3, 3))


def BV(at, size, color, rot=(0, 0, 0), bevel=0.15, neon=False):
    """A box with rounded edges, the kit's default chunky block."""
    return B(at, size, color, rot, bevel, neon)


def both(x, make):
    """make(x) for x and -x."""
    return make(x) + make(-x)


# --- Lobby: store stands ------------------------------------------------------------------------
# A market stand: counter, striped awning, lit sign, shelves of goods in the store's color. The
# game adds the store's icon on the roof, the actor serving and the floating name. Spots:
# Counter (the action, on the counter's front) and Sign (the store's name, on the roof board).

STAND_COLORS = {
    "Gold": "Gold",
    "Purple": "Purple",
    "Red": "Carpet",
    "Blue": "Blue",
    "Green": "Green",
    "Teal": "Teal",
}


def store_stand(accent):
    light = shade(accent, -0.45)
    s = [
        B((0, 1.85, 0.1), (12.4, 6.9, 0.2), "Burgundy"),
        BV((0, 1.85, 0.3), (12, 6.5, 0.2), "Paving", bevel=0.06),
        BV((0, 4.6, 3.9), (11, 0.8, 7), "Cream"),
    ]
    for x in (-5.1, 5.1):
        s += [
            BV((x, 2.3, 3.9), (0.8, 5.4, 7), "Cream"),
            C((x, -1.1, 5.6), 0.38, 3.8, "Cream", seg=8),
            C((x, -1.1, 3.95), 0.5, 0.3, "Gold", seg=8),
            C((x, -1.1, 7.3), 0.5, 0.3, "Gold", seg=8),
        ]
    for i, z in enumerate((4.6, 6.2)):
        s.append(BV((0, 3.7, z), (9, 1.1, 0.25), "Wood", bevel=0.05))
        for j in range(-2, 3):
            col = accent if (i + j) % 2 == 0 else light
            if (i + j) % 3 == 0:
                s += [C((j * 1.7, 3.7, z + 0.6), 0.42, 0.95, col, seg=8), C((j * 1.7, 3.7, z + 1.12), 0.3, 0.12, "OffWhite", seg=8)]
            else:
                s.append(BV((j * 1.7, 3.7, z + 0.57), (1.1, 0.8, 0.9), col, bevel=0.08))
    s += [
        BV((0, -0.6, 1.9), (10.2, 1.6, 3), accent),
        BV((0, -0.6, 0.65), (10.4, 1.7, 0.5), "Burgundy", bevel=0.08),
        BV((0, -0.7, 3.6), (11, 2.2, 0.4), "Wood", bevel=0.1),
        T((0, -1.42, 2.0), (9.6, 0.05, 2.4), "Counter"),
        BV((0, 1.5, 7.7), (12.4, 7.4, 0.6), "Burgundy", bevel=0.12),
    ]
    stripes = 6
    for i in range(stripes):
        x = -6 + (i + 0.5) * 12 / stripes
        col = accent if i % 2 == 0 else "OffWhite"
        s.append(B((x, -3.6, 7.05), (12 / stripes, 3.3, 0.3), col, rot=(SLOPE_AWNING, 0, 0)))
        s.append(B((x, -5.12, 5.95), (12 / stripes, 0.2, 0.9), "OffWhite" if i % 2 == 0 else accent))
        # A rounded flap under each stripe.
        s.append(C((x, -5.12, 5.5), 0.9, 0.2, "OffWhite" if i % 2 == 0 else accent, rot=(90, 0, 0), seg=10))
    s += [
        BV((0, -0.7, 9.9), (10.8, 0.4, 3.6), accent, bevel=0.1),
        B((0, -0.95, 9.9), (10, 0.3, 2.8), "Navy"),
        T((0, -1.11, 9.9), (9.6, 0.05, 2.6), "Sign"),
    ]
    s += [E((-4.5 + i * 1.8, -0.9, 11.85), (0.26, 0.26, 0.26), "Light", neon=True) for i in range(6)]
    s += [E((-4.5 + i * 1.8, -0.9, 7.95), (0.22, 0.22, 0.22), "Light", neon=True) for i in range(6)]
    s.append(BV((0, 1.9, 0.7), (3, 2, 0.6), "Wood", bevel=0.08))
    for x in (-7.2, 7.2):
        s += [
            K((x, -2.4, 0.6), 0.75, 0.6, 1.2, "Burgundy", seg=8),
            C((x, -2.4, 1.05), 0.78, 0.18, "Gold", seg=8),
            L((x, -2.4, 2.0), (1.05, 1.05, 1.0), "LeafDark"),
            L((x + 0.3, -2.7, 2.6), (0.6, 0.6, 0.55), "Leaf", rot=(0, 0, 30)),
        ]
    return s


# --- Lobby: plaza and streets -------------------------------------------------------------------


def plaza_fountain():
    """The spawn plaza's fountain basin and pedestal (the gold trophy, the jets and the spray are
    added by the game). Spots: PlaqueFront, PlaqueBack."""
    s = [
        C((0, 0, 0.7), 9, 1.4, "Cream", seg=18),
        C((0, 0, 1.43), 8.3, 0.08, "Water", seg=18),
        C((0, 0, 1.46), 6.4, 0.04, "WaterLight", seg=18),
        C((0, 0, 1.48), 4.6, 0.04, "Water", seg=18),
    ]
    s += ring(18, 8.45, 1.65, lambda x, y, a: BV((x, y, 1.65), (3.2, 1.3, 0.5), "Burgundy", rot=(0, 0, -a), bevel=0.08), start=10)
    s += [
        K((0, 0, 1.6), 3.0, 2.6, 3.2, "Burgundy", seg=8, rot=(0, 0, 22.5)),
        C((0, 0, 3.0), 3.0, 0.4, "Gold", seg=8, rot=(0, 0, 22.5)),
        C((0, 0, 3.5), 3.3, 0.6, "Cream", seg=8, rot=(0, 0, 22.5)),
    ]
    for front in (True, False):
        y = -1 if front else 1
        s += [
            BV((0, y * 2.68, 2.0), (3.2, 0.3, 1.0), "Gold", bevel=0.06),
            T((0, y * 2.85, 2.0), (3.0, 0.05, 0.85), "PlaqueFront" if front else "PlaqueBack", rot=(0, 0, 0 if front else 180)),
        ]
    return s


def planter():
    """Round planter for the plaza palms (the palm is its own Blender model)."""
    return [
        K((0, 0, 0.5), 2.5, 2.3, 1.0, "Burgundy", seg=10),
        C((0, 0, 0.9), 2.45, 0.2, "Gold", seg=10),
        C((0, 0, 1.03), 2.1, 0.08, "Bark", seg=10),
    ]


def boulevard_arch():
    """"HOLLYWOOD BLVD" arch over each end of the boulevard. Its posts stand either side of the
    road (along Y); the signs face along the road. Spots: SignA (+X face), SignB (-X face)."""
    span = 12.5
    s = []
    for y in (-span, span):
        s += [
            BV((0, y, 0.6), (3.6, 3.6, 1.2), "Burgundy"),
            BV((0, y, 1.5), (3.0, 3.0, 0.6), "Gold", bevel=0.1),
            BV((0, y, 8.4), (2.6, 2.6, 13.8), "Cream", bevel=0.2),
            BV((0, y, 5.0), (2.9, 2.9, 0.5), "Gold", bevel=0.08),
            BV((0, y, 11.0), (2.9, 2.9, 0.5), "Gold", bevel=0.08),
            C((0, y, 16.6), 0.5, 1.2, "Charcoal", seg=8),
            E((0, y, 17.8), (1.1, 1.1, 1.2), "Light", neon=True),
            K((0, y, 19.05), 0.8, 0.1, 0.5, "Gold", seg=8),
        ]
    s += [
        BV((0, 0, 15.6), (2, span * 2 + 2.6, 1), "Burgundy", bevel=0.12),
        BV((0, 0, 12.9), (1, span * 2 - 3, 4.8), "Gold", bevel=0.1),
        B((0, 0, 12.9), (1.2, span * 2 - 4, 4), "Navy"),
        T((0.61, 0, 12.9), (span * 2 - 4.6, 0.05, 3.6), "SignA", rot=(0, 0, 90)),
        T((-0.61, 0, 12.9), (span * 2 - 4.6, 0.05, 3.6), "SignB", rot=(0, 0, -90)),
        B((0, 0, 16.5), (0.6, 0.6, 0.8), "Gold"),
        S((0, 0, 18.4), 1.7, 0.6, "Gold", rot=(0, 0, 90)),
    ]
    return s


def town_pillar():
    """Cream pillar with a lamp, along the town's hedge."""
    return [
        BV((0, 0, 0.3), (3.2, 3.2, 0.6), "Burgundy", bevel=0.08),
        BV((0, 0, 2.7), (2.8, 2.8, 4.4), "Cream", bevel=0.2),
        BV((0, 0, 4.2), (3.0, 3.0, 0.4), "Gold", bevel=0.08),
        BV((0, 0, 5.1), (3.2, 3.2, 0.6), "Burgundy", bevel=0.1),
        C((0, 0, 5.55), 0.5, 0.3, "Gold", seg=8),
        E((0, 0, 6.3), (0.65, 0.65, 0.7), "Light", neon=True),
        K((0, 0, 7.05), 0.45, 0.05, 0.3, "Gold", seg=8),
    ]


def hedge_section():
    """A 10-stud stretch of the town's hedge, 3 tall, with leafy bumps along the top."""
    s = [BV((0, 0, 1.4), (10, 2, 2.8), "DarkGreen", bevel=0.35)]
    for i, x in enumerate((-3.8, -1.2, 1.3, 3.9)):
        s.append(L((x, 0, 2.8), (1.6, 1.25, 0.75), "Green" if i % 2 == 0 else "Leaf", rot=(0, 0, i * 40)))
    return s


def poster_column(color):
    """Round poster column with a gold dome. Spot: Poster (the front poster's title)."""
    s = [
        C((0, 0, 0.4), 1.7, 0.8, "Burgundy", seg=10),
        C((0, 0, 4.0), 1.4, 6.4, "Cream", seg=12),
        C((0, 0, 7.4), 1.55, 0.5, "Burgundy", seg=12),
        K((0, 0, 8.1), 1.3, 0.4, 1.0, "Gold", seg=12),
        E((0, 0, 8.85), (0.4, 0.4, 0.4), "Gold"),
    ]
    for k in range(4):
        col = color if k == 0 else shade(color, -0.35)
        s.append(G((0, 0, 0), (0, 0, k * 90), B((0, -1.42, 4.2), (1.9, 0.1, 4.4), col)))
    s.append(T((0, -1.48, 4.2), (1.8, 0.05, 4.2), "Poster"))
    return s


CAR_COLORS = {"Teal": "Teal", "Pink": "Pink", "Gold": "Gold", "Red": "Carpet"}


def vintage_car(color):
    """A rounded 1950s convertible, about 4.4 wide and 9.6 long, nose toward -Y."""
    s = [
        BV((0, 0, 1.45), (4.2, 9, 1.5), color, bevel=0.35),
        BV((0, -2.6, 2.25), (3.8, 3.2, 0.5), color, bevel=0.2),
        BV((0, 3.2, 2.25), (3.8, 2.2, 0.5), color, bevel=0.2),
        BV((0, -2.9, 1.75), (4.5, 2.6, 0.9), color, bevel=0.35),
        BV((0, 2.9, 1.75), (4.5, 2.6, 0.9), color, bevel=0.35),
        B((0, 0, 1.4), (4.24, 8.4, 0.22), "OffWhite"),
        BV((0, 0.4, 2.35), (3.4, 2.6, 0.9), "OffWhite", bevel=0.25),
        BV((0, 1.45, 2.95), (3.4, 0.6, 1.2), "OffWhite", bevel=0.25),
        B((0, -0.95, 3.1), (3.6, 0.15, 1.3), "Glass", rot=(-20, 0, 0)),
        B((0, -0.95, 3.72), (3.7, 0.2, 0.15), "Chrome", rot=(-20, 0, 0)),
        BV((0, -4.6, 1.0), (4.4, 0.3, 0.45), "Chrome", bevel=0.1),
        BV((0, 4.6, 1.0), (4.4, 0.3, 0.45), "Chrome", bevel=0.1),
        B((0, -4.56, 1.45), (1.6, 0.1, 0.5), "Chrome"),
    ]
    for x in (-1.4, 1.4):
        s += [
            C((x, -4.52, 1.75), 0.36, 0.15, "Light", rot=(90, 0, 0), seg=10, neon=True),
            B((x, 4.55, 1.75), (0.7, 0.12, 0.35), "Carpet"),
        ]
    for x in (-1.75, 1.75):
        s.append(W((x, 3.75, 2.75), (0.35, 2.2, 0.9), color))
    for x in (-1.95, 1.95):
        for y in (-2.9, 2.9):
            s += [
                C((x, y, 0.85), 0.85, 0.6, "Charcoal", rot=(0, 90, 0), seg=12),
                C((x, y, 0.85), 0.58, 0.62, "OffWhite", rot=(0, 90, 0), seg=12),
                C((x, y, 0.85), 0.34, 0.7, "Chrome", rot=(0, 90, 0), seg=8),
            ]
    return s


def bus_stop():
    """Bus shelter. Spots: Poster (on the back panel), BusSign (the round sign)."""
    s = [
        BV((0, 0.2, 7.2), (8.4, 3.6, 0.4), "Burgundy", bevel=0.1),
        B((0, 0.2, 6.92), (8.6, 3.8, 0.25), "Gold"),
        B((0, 1.6, 3.6), (8, 0.3, 5.6), shade("Glass", -0.3)),
        BV((0, 1.6, 0.6), (8.2, 0.5, 1.0), "Charcoal", bevel=0.08),
        B((-1.8, 1.42, 3.6), (3, 0.1, 4.2), "#6EBE50"),
        T((-1.8, 1.36, 3.6), (2.8, 0.05, 4.0), "Poster"),
        BV((1.6, 0.8, 1.5), (4.6, 1.2, 0.35), "Wood", bevel=0.08),
        C((-5.2, -1.3, 3.75), 0.15, 7.5, "Charcoal", seg=8),
        C((-5.2, -1.3, 7.6), 1.1, 0.3, "Blue", rot=(90, 0, 0), seg=14),
        C((-5.2, -1.3, 7.6), 1.2, 0.2, "OffWhite", rot=(90, 0, 0), seg=14),
        T((-5.2, -1.46, 7.6), (1.6, 0.05, 1.4), "BusSign"),
    ]
    for x in (-3.9, 3.9):
        s.append(B((x, -1.3, 3.4), (0.35, 0.35, 6.8), "Charcoal"))
        s.append(B((x, 1.6, 3.4), (0.4, 0.4, 6.8), "Charcoal"))
    for x in (3.4, -0.2):
        s.append(B((x, 0.8, 0.65), (0.3, 1, 1.3), "Charcoal"))
    return s


def hydrant():
    return [
        C((0, 0, 0.15), 0.65, 0.3, "Carpet", seg=10),
        C((0, 0, 1.1), 0.45, 1.6, "Carpet", seg=10),
        C((0, 0, 1.75), 0.52, 0.18, "Gold", seg=10),
        E((0, 0, 1.95), (0.48, 0.48, 0.42), "Carpet"),
        K((0, 0, 2.42), 0.2, 0.08, 0.28, "Gold", seg=6),
        C((0, 0, 1.25), 0.2, 1.4, "Gold", rot=(0, 90, 0), seg=8),
        C((0, -0.5, 1.15), 0.24, 0.3, "Gold", rot=(90, 0, 0), seg=8),
    ]


def trash_bin():
    return [
        K((0, 0, 1.1), 0.75, 0.85, 2.2, "DarkGreen", seg=12),
        C((0, 0, 0.5), 0.82, 0.25, "Gold", seg=12),
        C((0, 0, 1.8), 0.88, 0.25, "Gold", seg=12),
        K((0, 0, 2.4), 0.95, 0.7, 0.35, "Charcoal", seg=12),
        E((0, 0, 2.7), (0.22, 0.22, 0.18), "Gold"),
    ]


def news_stand():
    """A green kiosk with stacks of papers and a striped roof. Spot: NewsSign."""
    s = [
        BV((0, 0, 1.7), (4.4, 2.6, 3.4), "DarkGreen", bevel=0.15),
        BV((0, -1.8, 2.3), (4.6, 1.2, 0.3), "Wood", bevel=0.06),
        B((0, -1.35, 3.2), (4, 0.2, 0.9), "Navy"),
        T((0, -1.46, 3.2), (3.8, 0.05, 0.8), "NewsSign"),
    ]
    for i in range(3):
        x = -1.4 + i * 1.4
        s += [BV((x, -1.8, 2.65), (1.1, 0.9, 0.4), "OffWhite", bevel=0.05), B((x, -1.8, 2.86), (0.9, 0.7, 0.04), "Carpet" if i == 1 else "Blue")]
    for k in range(4):
        s.append(B((1.8 - k * 1.2, -0.5, 4.5), (1.2, 3.6, 0.25), "Carpet" if k % 2 == 0 else "OffWhite", rot=(12, 0, 0)))
    return s


def flower_patch():
    """A clump of leaves and flowers for lawns and flower beds (about 3 by 1.6)."""
    s = [
        L((-0.6, 0, 0.35), (1.0, 0.8, 0.45), "Leaf"),
        L((0.7, 0.1, 0.32), (0.9, 0.75, 0.4), "LeafDark", rot=(0, 0, 40)),
    ]
    for i, (x, y, col) in enumerate(((-1.1, -0.2, "Carpet"), (-0.3, 0.3, "Gold"), (0.4, -0.3, "Pink"), (1.1, 0.25, "OffWhite"), (0.0, -0.5, "Purple"))):
        z = 0.75 + (i % 2) * 0.15
        s += [
            K((x, y, z), 0.42, 0.2, 0.28, col, seg=5, rot=(0, 0, i * 20)),
            E((x, y, z + 0.16), (0.14, 0.14, 0.1), "Gold" if col != "Gold" else "Orange"),
        ]
    return s


# --- Landmarks ----------------------------------------------------------------------------------


def premiere_theatre():
    """The Grand Premiere Theatre: steps up to a bulb-lit marquee, columns, poster cases, a tall
    blade sign with a gold star, side wings. About 52 wide and 29 deep; the bottom step's front
    is at y = -3. The searchlights are their own models. Spots: Marquee, Blade, PosterSpace
    (the blue poster), PosterLove (the pink one)."""
    s = [BV((0, 13, 0.5), (52, 26, 1), "Burgundy", bevel=0.12)]
    for i in range(3):
        h = (3 - i) / 3
        s += [
            BV((0, -i - 0.5, h / 2), (26, 1, h), "Cream", bevel=0.06),
            B((0, -i - 0.5, h + 0.03), (6, 1.02, 0.06), "Carpet"),
        ]
    s += [
        B((0, 3, 1.03), (6, 6, 0.06), "Carpet"),
        BV((0, 16, 11), (34, 20, 20), "Cream", bevel=0.3),
        BV((0, 16, 17.5), (34.4, 20.4, 0.8), "Gold", bevel=0.1),
        BV((0, 16, 21.4), (35.2, 21.2, 1.2), "Burgundy", bevel=0.15),
        BV((0, 16.5, 22.6), (28, 16, 1.2), "Cream", bevel=0.2),
        BV((0, 16.5, 23.5), (22, 12, 0.6), "Burgundy", bevel=0.1),
        # Fluting on the hall front above the marquee.
    ]
    s += [BV((x, 5.85, 15.5), (0.6, 0.3, 4.4), "Gold", bevel=0.05) for x in (-13.5, -11, -8.5, 8.5, 11, 13.5)]
    for side in (-1, 1):
        x = side * 21.3
        s += [
            BV((x, 16.5, 7.5), (8.6, 17, 13), "Cream", bevel=0.25),
            BV((x, 16.5, 14.4), (9.2, 17.6, 1), "Burgundy", bevel=0.12),
            BV((x, 16.5, 15.3), (6, 14, 0.8), "Cream", bevel=0.12),
        ]
        for dx in (-2.2, 2.2):
            s += [
                BV((x + dx, 7.95, 6.3), (2.8, 0.3, 6.4), "Gold", bevel=0.05),
                B((x + dx, 7.8, 6), (2.2, 0.3, 6), "DoorGlass"),
                C((x + dx, 7.82, 9.0), 1.1, 0.3, "DoorGlass", rot=(90, 0, 0), seg=10),
                C((x + dx, 7.97, 9.0), 1.4, 0.3, "Gold", rot=(90, 0, 0), seg=10),
            ]
    for x in (-15, -9, 9, 15):
        s += [
            BV((x, 4.6, 1.5), (2.2, 2.2, 1), "Burgundy", bevel=0.1),
            C((x, 4.6, 7.25), 0.8, 10.5, "Cream", seg=10),
            BV((x, 4.6, 12.9), (2.4, 2.4, 0.8), "Gold", bevel=0.1),
            BV((x, 4.6, 2.2), (1.9, 1.9, 0.4), "Gold", bevel=0.06),
        ]
    for x in (-4.2, 0, 4.2):
        s += [
            BV((x, 5.95, 4.4), (3.8, 0.3, 6.8), "Gold", bevel=0.06),
            B((x, 5.8, 4.1), (3.2, 0.3, 6.2), "DoorGlass"),
            B((x, 5.62, 4.1), (0.2, 0.1, 6.2), "Gold"),
        ]
    # Poster cases between the columns: blue "Space Cowboys" (game's -X side) and pink "Love in
    # Paris". Blender +X is the game's -X.
    for x, col, name in ((12, "Blue", "PosterSpace"), (-12, "Pink", "PosterLove")):
        s += [
            BV((x, 5.9, 5.2), (4, 0.3, 5.6), "Gold", bevel=0.06),
            B((x, 5.75, 5.2), (3.4, 0.3, 5), col),
            T((x, 5.58, 5.2), (3.2, 0.05, 4.8), name),
        ]
    # The marquee: a deep canopy, a lit board on its front and bulbs underneath and round it.
    s += [
        BV((0, 2.5, 10), (26, 7, 3.6), "Burgundy", bevel=0.2),
        BV((0, 2.5, 12.1), (27, 7.6, 0.6), "Gold", bevel=0.1),
        B((0, 2.5, 8.1), (25, 6.4, 0.3), "Light", neon=True),
        B((0, -1.1, 10), (24, 0.3, 2.6), "OffWhite"),
        T((0, -1.26, 10), (23, 0.05, 2.4), "Marquee"),
    ]
    for i in range(17):
        x = -12 + i * 1.5
        s += [BV((x, -1.3, 8.55), (0.42, 0.3, 0.42), "Light", bevel=0.08, neon=True), BV((x, -1.3, 11.45), (0.42, 0.3, 0.42), "Light", bevel=0.08, neon=True)]
    for x in (-12.15, 12.15):
        s += [BV((x, -1.3, 10), (0.42, 0.3, 0.42), "Light", bevel=0.08, neon=True)]
    # The tall blade sign rising over the roof, edged with bulbs, the gold star on top.
    s += [
        BV((0, 5.2, 22.3), (6.6, 1.2, 19), "Gold", bevel=0.15),
        B((0, 4.6, 22.3), (5.6, 0.6, 18), "Navy"),
        T((0, 4.27, 22.3), (5.0, 0.05, 17), "Blade"),
        C((0, 5.2, 31.9), 0.4, 1.2, "Gold", seg=8),
        S((0, 5.0, 34.2), 2.8, 0.9, "Gold"),
    ]
    for x in (-2.95, 2.95):
        s += [BV((x, 4.2, 14.2 + k * 1.35), (0.38, 0.3, 0.38), "Light", bevel=0.07, neon=True) for k in range(13)]
    # Potted topiaries either side of the steps.
    for x in (-11, 11):
        s += [
            K((x, -0.2, 1.6), 0.9, 0.75, 1.2, "Burgundy", seg=8),
            C((x, -0.2, 2.25), 0.1, 1.4, "Bark", seg=6),
            L((x, -0.2, 3.4), (1.1, 1.1, 1.1), "LeafDark"),
        ]
    return s


def studio_gate():
    """Grand studio entrance: two towers, an arch, iron gates swung open and a gold star. About
    36 wide; the road runs through the middle along Y. Spots: SignFront, SignBack."""
    s = []
    for x in (-14, 14):
        s += [
            BV((x, 0, 1), (7.4, 7.4, 2), "Burgundy", bevel=0.15),
            BV((x, 0, 13), (6, 6, 22), "Cream", bevel=0.3),
            BV((x, 0, 6), (6.4, 6.4, 0.8), "Gold", bevel=0.1),
            BV((x, 0, 18), (6.4, 6.4, 0.8), "Gold", bevel=0.1),
            BV((x, 0, 24.7), (7.2, 7.2, 1.4), "Burgundy", bevel=0.15),
            K((x, 0, 26.0), 2.6, 0.9, 1.2, "Burgundy", seg=8, rot=(0, 0, 22.5)),
            E((x, 0, 27.3), (1.1, 1.1, 1.1), "Gold"),
        ]
        # Long windows up the tower front and back.
        for y in (-3.02, 3.02):
            s += [B((x, y, 12), (1.6, 0.1, 9), "DoorGlass"), B((x, y * 1.005, 16.6), (2.2, 0.1, 0.4), "Gold")]
        # The iron gate swung back against the tower, so the way through is open.
        hinge = 10.6 if x > 0 else -10.6
        for z in (1.2, 8.4):
            s.append(B((hinge, 5.4, z), (0.35, 9, 0.35), "Charcoal"))
        for k in range(5):
            y = 1.6 + k * 1.9
            s += [B((hinge, y, 4.8), (0.3, 0.3, 8.4), "Charcoal"), K((hinge, y, 9.4), 0.3, 0.02, 0.8, "Gold", seg=4)]
        s.append(B((hinge, 5.4, 4.8), (0.25, 8.6, 0.25), "Charcoal", rot=(-47, 0, 0)))
    s += [
        BV((0, 0, 21.5), (22.2, 4, 5), "Cream", bevel=0.2),
        BV((0, 0, 18.8), (22.4, 4.4, 0.6), "Gold", bevel=0.08),
        BV((0, 0, 24.2), (22.4, 4.4, 0.6), "Gold", bevel=0.08),
        B((0, -2.15, 21.5), (19.6, 0.3, 3.4), "Navy"),
        B((0, 2.15, 21.5), (19.6, 0.3, 3.4), "Navy"),
        T((0, -2.31, 21.5), (19.0, 0.05, 3.0), "SignFront"),
        T((0, 2.31, 21.5), (19.0, 0.05, 3.0), "SignBack", rot=(0, 0, 180)),
        BV((0, 0, 25.1), (3, 2, 1.2), "Burgundy", bevel=0.1),
        S((0, 0, 27.6), 2.3, 0.8, "Gold"),
    ]
    return s


def guard_booth():
    return [
        BV((0, 0, 0.3), (5.4, 5.4, 0.6), "Burgundy", bevel=0.1),
        BV((0, 0, 2.8), (5, 5, 4.4), "Cream", bevel=0.2),
        B((0, -2.55, 3.4), (3.6, 0.2, 1.8), "Glass"),
        B((-2.55, 0, 3.4), (0.2, 3.2, 1.8), "Glass"),
        B((0, -2.58, 2.4), (3.8, 0.2, 0.2), "Gold"),
        BV((0, 0, 5.4), (6.2, 6.2, 0.8), "Burgundy", bevel=0.15),
        BV((0, 0, 5.9), (4.4, 4.4, 0.3), "Gold", bevel=0.08),
        E((0, 0, 6.5), (0.55, 0.55, 0.55), "Light", neon=True),
    ]


def hill_star():
    """The giant gold star sign on the hill behind the park, upright, facing -Y (the game leans
    it back into the slope)."""
    return [
        C((0, 1.2, 4), 0.8, 8, "Steel", seg=8),
        C((-6, 1.2, 3), 0.6, 6, "Steel", seg=8),
        C((6, 1.2, 3), 0.6, 6, "Steel", seg=8),
        S((0, 0, 15), 13, 1.6, "Gold", neon=True),
        S((0, -0.9, 15), 7, 0.6, "Light", neon=True),
    ]


def blimp():
    """A big striped blimp, nose toward -Y, about 46 long. Spots: BannerA (+X side), BannerB."""
    s = [
        C((0, 0, 0), 7, 30, "OffWhite", rot=(90, 0, 0), seg=14),
        E((0, -15, 0), (7, 7, 7), "OffWhite"),
        E((0, 15, 0), (7, 7, 7), "OffWhite"),
        E((0, -20.4, 0), (3, 3, 3), "Carpet"),
        C((0, -10, 0), 7.15, 1.6, "Carpet", rot=(90, 0, 0), seg=14),
        C((0, 10, 0), 7.15, 1.6, "Carpet", rot=(90, 0, 0), seg=14),
        C((0, -8.4, 0), 7.18, 0.8, "Gold", rot=(90, 0, 0), seg=14),
        C((0, 8.4, 0), 7.18, 0.8, "Gold", rot=(90, 0, 0), seg=14),
    ]
    for side in (-1, 1):
        s += [
            BV((side * 6.9, 0, 0), (0.4, 17, 5.4), "Gold", bevel=0.1),
            B((side * 7.0, 0, 0), (0.5, 16, 4.6), "Carpet"),
            T((side * 7.27, 0, 0), (15.5, 0.05, 4.2), "BannerA" if side > 0 else "BannerB", rot=(0, 0, 90 * side)),
        ]
    for size, at in (((1, 8, 8), (0, 18, 7.5)), ((1, 8, 7), (0, 18, -7)), ((8, 8, 1), (7.5, 18, 0)), ((8, 8, 1), (-7.5, 18, 0))):
        s.append(BV(at, size, "Gold", bevel=0.2))
        tip = (math.copysign(3.6, at[0]) + at[0] if at[0] else 0, at[1] + 2.6, math.copysign(3.6, at[2]) + at[2] if at[2] else 0)
        s.append(BV(tip, (2 if at[0] else 1.1, 3, 2 if at[2] else 1.1), "Carpet", bevel=0.2))
    s += [
        BV((0, -2, -8.2), (4.6, 11, 3), "Cream", bevel=0.4),
        BV((0, -2, -9.8), (5, 11.4, 0.6), "Gold", bevel=0.15),
        B((0, -2, -7.8), (4.7, 9, 1.1), "DoorGlass"),
    ]
    for x in (-3.4, 3.4):
        s += [
            C((x, 3, -8), 0.8, 3, "Steel", rot=(90, 0, 0), seg=10),
            B((x, 4.7, -8), (0.3, 0.3, 3.4), "Charcoal"),
            B((x, 4.7, -8), (3.4, 0.3, 0.3), "Charcoal"),
        ]
    return s


def city_tower(variant):
    """A pale far-off skyscraper for the hazy skyline (three shapes)."""
    cols = ("#B0C0DE", "#A0B2D4", "#BECAE2")
    col = cols[variant - 1]
    dark = shade(col, 0.12)
    if variant == 1:
        tiers = ((20, 70), (15, 20), (10, 12))
    elif variant == 2:
        tiers = ((24, 50), (18, 30), (12, 25))
    else:
        tiers = ((18, 90), (12, 14))
    s = []
    z = 0.0
    for i, (w, h) in enumerate(tiers):
        s.append(BV((0, 0, z + h / 2), (w, w * 0.85, h), col if i % 2 == 0 else dark, bevel=0.6))
        # Window bands: a darker stripe every 8 studs on the front and side.
        for k in range(int(h // 8)):
            s.append(B((0, 0, z + 4 + k * 8), (w + 0.1, w * 0.85 + 0.1, 0.9), dark))
        z += h
    s.append(C((0, 0, z + 6), 0.5, 12, dark, seg=6))
    return s


HILL_COLORS = {"Green": "Green", "Dark": "DarkGreen", "Sand": "Sand", "Dust": "Dust"}


def hill(color):
    """A big low-poly hill: a sphere 100 across (the game scales and sinks it)."""
    return [H((0, 0, 0), 50, color)]


# --- Film sets ----------------------------------------------------------------------------------


def chroma_wall():
    """The green screen: a chroma wall 26 long facing -Y, braced at the back, a lighting truss on
    top and a marked green floor in front."""
    s = [
        BV((0, 0, 5.7), (26, 0.8, 11), "Chroma", bevel=0.15),
        B((0, -2.4, 0.03), (26, 4, 0.06), "Chroma"),
        B((0, -2.6, 0.08), (2, 0.3, 0.06), "Gold", rot=(0, 0, 45)),
        B((0, -2.6, 0.08), (2, 0.3, 0.06), "Gold", rot=(0, 0, -45)),
        BV((0, -0.6, 11.4), (26.4, 0.8, 0.5), "Steel", bevel=0.1),
    ]
    for x in (-10, 10):
        s += [W((x, 1.1, 2.0), (0.6, 1.4, 4), "Steel", rot=(0, 0, 180)), B((x, 0, 6), (0.5, 0.9, 11.6), "Steel")]
    for x in (-8, 0, 8):
        s += [BV((x, -1.3, 10.8), (1.4, 1.0, 0.9), "Charcoal", bevel=0.1), B((x, -1.82, 10.75), (1.1, 0.06, 0.6), "Light", neon=True)]
    return s


def camera_crane():
    """A film camera on a crane arm, pointing toward -Y."""
    arm = G(
        (0, 0, 6.3), (-14, 0, 0),
        BV((0, -2.5, 0), (0.6, 11, 0.6), "Gold", bevel=0.12),
        BV((0, 2.6, -0.5), (1.6, 1.6, 1.6), "Charcoal", bevel=0.2),
        BV((0, -8.2, -1), (1.2, 1.8, 1.4), "Charcoal", bevel=0.2),
        C((0, -9.4, -1), 0.45, 0.8, "Steel", rot=(90, 0, 0), seg=10),
        C((0, -9.82, -1), 0.3, 0.06, "Glass", rot=(90, 0, 0), seg=10),
        C((0, -7.7, 0.1), 0.55, 0.3, "Charcoal", rot=(0, 90, 0), seg=10),
        C((0, -8.8, 0.1), 0.55, 0.3, "Charcoal", rot=(0, 90, 0), seg=10),
    )
    s = [
        BV((0, 0, 0.7), (3, 4.4, 1), "Charcoal", bevel=0.2),
        C((0, 0, 3.7), 0.4, 5, "Steel", seg=8),
        BV((0, 0, 6.3), (1, 1, 0.9), "Charcoal", bevel=0.15),
        arm,
    ]
    for x in (-1.5, 1.5):
        for y in (-1.8, 1.8):
            s.append(C((x, y, 0.35), 0.35, 0.3, "Steel", rot=(0, 90, 0), seg=8))
    return s


def director_chair():
    """Folding director's chair. Spot: Back (lettering on the back of the backrest)."""
    s = [
        BV((0, 0, 1.5), (1.8, 1.5, 0.15), "Charcoal", bevel=0.04),
        BV((0, 0.7, 2.5), (2.0, 0.15, 0.8), "Charcoal", bevel=0.04),
        T((0, 0.79, 2.5), (1.8, 0.05, 0.6), "Back", rot=(0, 0, 180)),
    ]
    for x in (-0.9, 0.9):
        s += [
            B((x, 0, 0.75), (0.18, 1.9, 0.18), "Wood", rot=(38, 0, 0)),
            B((x, 0, 0.75), (0.18, 1.9, 0.18), "Wood", rot=(-38, 0, 0)),
            B((x, 0, 1.95), (0.22, 1.6, 0.18), "Wood"),
            B((x, 0.7, 2.25), (0.18, 0.18, 1.6), "Wood"),
        ]
    return s


def light_stand():
    """A film light on a tripod, shining toward -Y."""
    s = [
        C((0, 0, 3.4), 0.15, 5.6, "Steel", seg=6),
        B((0, 0, 6.0), (2.6, 0.25, 0.25), "Charcoal"),
        BV((0, 0, 6.6), (2.2, 1.2, 1.8), "Charcoal", bevel=0.15),
        B((0, -0.62, 6.6), (1.8, 0.1, 1.4), "Light", neon=True),
        B((-1.25, -0.9, 6.6), (0.1, 0.6, 1.7), "Charcoal", rot=(0, 0, 30)),
        B((1.25, -0.9, 6.6), (0.1, 0.6, 1.7), "Charcoal", rot=(0, 0, -30)),
        B((0, -0.95, 7.65), (2.0, 0.6, 0.1), "Charcoal", rot=(-25, 0, 0)),
    ]
    # Three splayed tripod legs.
    s += ring(3, 0.55, 0.95, lambda x, y, a: G((x, y, 0.95), (0, 0, -a), B((0, 0, 0), (0.15, 0.15, 2.1), "Steel", rot=(28, 0, 0))))
    return s


def clapperboard():
    """A giant clapperboard leaning back, its clapper open."""
    stick = [B((-1.875 + i * 1.25 + 2.5, 0, 0.4), (1.25, 0.45, 0.8), "OffWhite" if i % 2 == 0 else "Charcoal") for i in range(4)]
    return [
        G(
            (0, 0, 0), (-10, 0, 0),
            BV((0, 0, 1.8), (5, 0.4, 3.6), "Charcoal", bevel=0.1),
            B((0, -0.21, 2.6), (4.6, 0.02, 0.12), "OffWhite"),
            B((0, -0.21, 1.8), (4.6, 0.02, 0.12), "OffWhite"),
            B((0, -0.21, 1.0), (4.6, 0.02, 0.12), "OffWhite"),
            B((0.2, -0.21, 1.4), (0.12, 0.02, 2.4), "OffWhite"),
            *[B((-1.875 + i * 1.25, 0, 4), (1.25, 0.45, 0.8), "OffWhite" if i % 2 == 1 else "Charcoal") for i in range(4)],
            G((-2.5, 0, 4.4), (0, -18, 0), *stick),
        ),
    ]


SIGN_COLORS = {"Green": "Chroma", "Red": "Carpet", "Gold": "Gold", "Pink": "Pink"}


def set_sign(color):
    """The sign at the street end of each film set. Spot: Sign."""
    return [
        C((0, 0.3, 3), 0.2, 6, "Charcoal", seg=8),
        BV((0, 0, 5.6), (6.4, 0.3, 2.2), color, bevel=0.08),
        B((0, -0.1, 5.6), (6, 0.3, 1.8), "OffWhite"),
        T((0, -0.26, 5.6), (5.8, 0.05, 1.7), "Sign"),
        S((3.2, -0.1, 6.7), 0.6, 0.25, "Gold"),
    ]


def prop_crate():
    """A 3-stud wooden crate (the game scales it)."""
    return [
        BV((0, 0, 1.5), (3, 3, 3), "Wood", bevel=0.12),
        B((0, 0, 1.5), (3.08, 3.08, 0.54), "Bark"),
        B((0, -1.52, 1.5), (0.35, 0.06, 3.8), "Bark", rot=(0, 45, 0)),
        B((1.52, 0, 1.5), (0.06, 0.35, 3.8), "Bark", rot=(45, 0, 0)),
    ]


def dino_head():
    """A giant monster-movie dinosaur head, mouth open, roaring toward -Y."""
    green, dark = "#6EBE50", "#5AA046"
    s = [
        BV((0, 2.8, 1.5), (3.4, 3.4, 3), green, bevel=0.4),
        BV((0, 0.6, 4), (4.4, 5, 3.8), green, bevel=0.5),
        BV((0, -3.4, 4.4), (3.6, 4, 2.2), green, bevel=0.4),
        BV((0, -2.6, 2.3), (3.2, 4.6, 0.9), dark, rot=(12, 0, 0), bevel=0.3),
        B((0, -2.4, 2.75), (2.6, 3.8, 0.1), "Carpet", rot=(12, 0, 0)),
    ]
    for x in (-1.3, -0.45, 0.45, 1.3):
        s += [K((x, -4.9, 3.0), 0.25, 0.02, 0.7, "OffWhite", rot=(180, 0, 0), seg=4), K((x * 0.85, -4.3, 3.15), 0.2, 0.02, 0.5, "OffWhite", seg=4)]
    for x in (-1.7, 1.7):
        s += [
            BV((x, -0.95, 5.2), (0.8, 0.8, 0.8), "Gold", bevel=0.15, neon=True),
            BV((x, -1.25, 5.2), (0.3, 0.3, 0.6), "Charcoal", bevel=0.05),
            BV((x, -0.9, 5.95), (1.2, 1.4, 0.4), dark, bevel=0.12),
            BV((x * 0.4, -5.35, 5.2), (0.4, 0.2, 0.25), dark, bevel=0.05),
        ]
    for i in range(3):
        s.append(K((0, 2.4 - i * 1.8, 6.4), 0.75, 0.05, 1.4, "Carpet", seg=4))
    return s


def prop_moon():
    """A fake moon on a stand, for space movies."""
    s = [
        BV((0, 0, 0.6), (2.4, 2.4, 1.2), "Charcoal", bevel=0.15),
        C((0, 0, 1.5), 0.3, 1.4, "Steel", seg=8),
        L((0, 0, 4.2), (3, 3, 3), "#E1E1D7", jitter=0.04),
    ]
    for at, r in (((1.6, -2.3, 5.2), 0.65), ((-1.2, -2.6, 3.6), 0.55), ((-0.3, -1.9, 6.1), 0.45), ((2.4, -0.6, 3.4), 0.5)):
        s.append(L(at, (r, r * 0.55, r), "#B4B4AC", jitter=0.03))
    return s


def rolling_spotlight():
    """A rolling studio spotlight on a red cart, aimed toward -Y and up."""
    s = [
        BV((0, 0, 0.9), (2.6, 2.6, 0.8), "Carpet", bevel=0.15),
        B((-1.1, 0, 2.0), (0.3, 0.6, 1.6), "Charcoal"),
        B((1.1, 0, 2.0), (0.3, 0.6, 1.6), "Charcoal"),
        C((0, 0, 2.6), 1.0, 2.4, "Steel", rot=(70, 0, 0), seg=12),
        C((0, -1.17, 3.03), 1.15, 0.2, "Gold", rot=(70, 0, 0), seg=12),
        C((0, -1.26, 3.06), 0.85, 0.1, "Light", rot=(70, 0, 0), seg=12, neon=True),
    ]
    for x in (-1.0, 1.0):
        for y in (-1.0, 1.0):
            s.append(C((x, y, 0.3), 0.3, 0.3, "Charcoal", rot=(0, 90, 0), seg=8))
    return s


TRAILER_COLORS = {"Red": "Carpet", "Blue": "Blue"}


def star_trailer(color):
    """A star's trailer, 13 long along Y, its door, windows and awning on the +X side (the game's
    -X, toward the middle of the set)."""
    s = [
        BV((0, 0, 3.4), (5.4, 13, 5), "OffWhite", bevel=0.45),
        B((0, 0, 2.4), (5.5, 12.4, 0.9), color),
        BV((0, 0, 6.05), (5.0, 12.4, 0.4), "Steel", bevel=0.15),
        BV((0, -7.1, 1.4), (0.5, 1.6, 0.4), "Charcoal", bevel=0.08),
        B((2.75, 0, 3.2), (0.2, 1.8, 3.6), "Burgundy"),
        S((2.9, 0, 4.0), 0.6, 0.2, "Gold", rot=(0, 0, 90)),
        BV((3.6, 0, 0.5), (1.6, 2.2, 0.6), "Steel", bevel=0.08),
    ]
    for y in (-4.2, 4.2):
        s += [B((2.75, y, 4.2), (0.2, 2.4, 1.4), "Glass"), B((-2.75, y, 4.2), (0.2, 2.4, 1.4), "Glass")]
    for x in (-2.3, 2.3):
        for y in (-4, 4):
            s += [C((x, y, 0.9), 0.9, 0.8, "Charcoal", rot=(0, 90, 0), seg=12), C((x, y, 0.9), 0.4, 0.84, "Steel", rot=(0, 90, 0), seg=8)]
    for k in range(3):
        s.append(B((4.0, -2.6 + k * 2.6, 5.2), (2.4, 2.6, 0.2), color if k % 2 == 0 else "OffWhite", rot=(0, 12, 0)))
    for y in (-3.6, 3.6):
        s.append(C((5.1, y, 2.5), 0.08, 5.0, "Steel", seg=6))
    return s


def patio_table():
    return [
        C((0, 0, 2.1), 1.2, 0.2, "OffWhite", seg=12),
        C((0, 0, 1.15), 0.15, 1.9, "Steel", seg=6),
        C((0, 0, 0.1), 0.65, 0.2, "Steel", seg=10),
    ]


def taco_truck():
    """A pink taco truck, 12 long along Y with the cab toward -Y; its serving hatch and the
    roof sign face +X (the game's -X). Spot: TruckSign."""
    s = [
        BV((0, 1, 4), (5.6, 12, 6), "Pink", bevel=0.45),
        B((0, 1, 2), (5.7, 11.6, 0.8), "OffWhite"),
        BV((0, -6.8, 3.3), (5.6, 4, 4.6), "Pink", bevel=0.6),
        B((0, -8.82, 4.6), (4.8, 0.2, 1.8), "Glass"),
        B((2.82, -7.0, 4.6), (0.2, 2.2, 1.5), "Glass"),
        B((-2.82, -7.0, 4.6), (0.2, 2.2, 1.5), "Glass"),
        BV((0, -8.9, 1.3), (5.8, 0.4, 0.6), "Chrome", bevel=0.1),
        B((2.85, 1.4, 4.6), (0.2, 6.4, 2.4), "Navy"),
        BV((3.3, 1.4, 3.3), (1, 6.4, 0.3), "OffWhite", bevel=0.06),
        BV((1.6, 1, 8), (0.4, 8, 1.8), "Gold", bevel=0.08),
        B((1.2, 1, 8), (0.3, 8, 1.8), "Pink"),
        T((1.81, 1, 8), (7.6, 0.05, 1.6), "TruckSign", rot=(0, 0, 90)),
        B((1.4, -1.5, 7.3), (0.3, 0.3, 0.8), "Charcoal"),
        B((1.4, 3.5, 7.3), (0.3, 0.3, 0.8), "Charcoal"),
        C((-2.2, 6.6, 7.6), 0.2, 2.2, "Steel", seg=6),
    ]
    for x in (-1.8, 1.8):
        s.append(C((x, -8.85, 2.6), 0.35, 0.15, "Light", rot=(90, 0, 0), seg=8, neon=True))
    for x in (-2.5, 2.5):
        for y in (-6.5, 4.5):
            s += [C((x, y, 1), 1, 0.9, "Charcoal", rot=(0, 90, 0), seg=12), C((x, y, 1), 0.45, 0.94, "Chrome", rot=(0, 90, 0), seg=8)]
    for k in range(4):
        s.append(B((3.8, -1 + k * 1.6, 6.4), (2.4, 1.6, 0.2), "Gold" if k % 2 == 0 else "OffWhite", rot=(0, 14, 0)))
    # A giant taco on the roof.
    s += [
        C((-0.6, 1, 7.7), 2.0, 1.4, "Gold", rot=(0, 90, 0), seg=12),
        L((-0.6, 0.0, 8.7), (0.7, 0.5, 0.4), "Leaf"),
        L((-0.6, 1.4, 8.8), (0.7, 0.5, 0.4), "Carpet"),
        L((-0.6, 2.2, 8.6), (0.5, 0.4, 0.35), "Leaf"),
    ]
    return s


def popcorn_cart():
    """A red popcorn cart with a glass case heaped with popcorn and a striped canopy."""
    s = [
        BV((0, 0, 2.0), (4, 2.2, 2.4), "Carpet", bevel=0.2),
        BV((0, 0, 3.3), (4.1, 2.3, 0.4), "OffWhite", bevel=0.08),
        BV((0, -1.12, 2.0), (2.6, 0.1, 1.2), "Gold", bevel=0.05),
        BV((0, 0, 5.6), (3.4, 1.9, 0.2), "Gold", bevel=0.05),
        BV((0, 0, 6.4), (4.6, 2.8, 0.3), "OffWhite", bevel=0.08),
        K((0, 0, 7.0), 2.4, 0.3, 0.9, "Carpet", seg=4, rot=(0, 0, 45)),
        E((0, 0, 7.6), (0.3, 0.3, 0.3), "Gold"),
    ]
    for x in (-1.6, 1.6):
        for y in (-0.85, 0.85):
            s.append(B((x, y, 4.55), (0.18, 0.18, 2.1), "Gold"))
    for x in (-2.15, 2.15):
        s += [C((x, 0, 1.1), 1.1, 0.25, "Charcoal", rot=(0, 90, 0), seg=12), C((x * 1.02, 0, 1.1), 0.35, 0.3, "Gold", rot=(0, 90, 0), seg=8)]
    for i, (x, y, z) in enumerate(((-0.9, -0.2, 3.9), (0.1, 0.2, 4.0), (1.0, -0.1, 3.85), (-0.4, 0.3, 4.4), (0.5, -0.3, 4.35), (0.0, 0.0, 4.75))):
        s.append(L((x, y, z), (0.5, 0.45, 0.4), "#FFF2C4", rot=(i * 30, 0, i * 50), jitter=0.06))
    s += [K((-1.3, 0.3, 4.1), 0.35, 0.5, 0.9, "Carpet", seg=8), L((-1.3, 0.3, 4.7), (0.42, 0.42, 0.3), "#FFF2C4")]
    s += [B((-1.3 + 0.35 * math.cos(math.radians(a)), 0.3 + 0.35 * math.sin(math.radians(a)), 4.1), (0.12, 0.12, 0.92), "OffWhite") for a in (0, 120, 240)]
    return s


UMBRELLA_COLORS = {"Teal": "Teal", "Gold": "Gold"}


def cafe_table(color):
    """Café table with a parasol and two stools."""
    s = [
        C((0, 0, 2.1), 1.3, 0.25, "OffWhite", seg=12),
        C((0, 0, 1.1), 0.15, 2.0, "Steel", seg=6),
        C((0, 0, 0.1), 0.7, 0.2, "Steel", seg=10),
        C((0, 0, 4.0), 0.12, 3.8, "Steel", seg=6),
        K((0, 0, 6.0), 2.9, 0.15, 1.1, color, seg=8),
        K((0, 0, 6.02), 1.4, 0.15, 0.6, "OffWhite", seg=8),
        E((0, 0, 6.65), (0.25, 0.25, 0.25), "OffWhite"),
    ]
    s += ring(8, 2.75, 5.35, lambda x, y, a: B((x, y, 5.35), (2.1, 0.08, 0.45), color if round(a / 45) % 2 == 0 else "OffWhite", rot=(0, 0, -a)), start=22.5)
    for y in (-1.9, 1.9):
        s += [C((0, y, 0.55), 0.18, 1.1, "Steel", seg=6), C((0, y, 1.15), 0.6, 0.2, "Carpet", seg=10)]
    return s


# --- Dusty Gulch --------------------------------------------------------------------------------


def gulch_arch():
    """The log arch over the road into Dusty Gulch. Spots: SignFront, SignBack."""
    s = []
    for x in (-16, 16):
        s += [
            C((x, 0, 8.5), 1.1, 17, "Bark", seg=8),
            K((x, 0, 17.4), 1.4, 1.1, 0.8, "Wood", seg=8),
            B((x - math.copysign(2.0, x), 0, 13.2), (0.55, 0.55, 5.2), "Bark", rot=(0, math.copysign(45, x), 0)),
            K((x, 0, 0.4), 1.6, 1.2, 0.8, "Wood", seg=8),
        ]
    s += [
        C((0, 0, 15.6), 1.15, 36, "Wood", rot=(0, 90, 0), seg=8),
        BV((0, 0, 10), (22, 0.6, 5.4), "Bark", bevel=0.15),
        B((0, 0, 10), (20.6, 0.72, 4.4), "#C44632"),
        T((0, -0.37, 10), (20.0, 0.05, 4.2), "SignFront"),
        T((0, 0.37, 10), (20.0, 0.05, 4.2), "SignBack", rot=(0, 0, 180)),
        E((-10.4, -0.45, 12.2), (0.25, 0.15, 0.25), "Gold"),
        E((10.4, -0.45, 12.2), (0.25, 0.15, 0.25), "Gold"),
        S((0, 0, 19.2), 1.8, 0.6, "Gold"),
    ]
    for x in (-6, 6):
        s += [B((x, 0, 13.9 - k * 0.55), (0.3 if k % 2 == 0 else 0.12, 0.12 if k % 2 == 0 else 0.3, 0.6), "Charcoal") for k in range(4)]
    # A cow skull on the beam.
    s += [
        BV((0, -1.05, 15.6), (1.2, 0.5, 1.3), "OffWhite", bevel=0.2),
        K((-1.1, -1.05, 15.9), 0.22, 0.05, 1.2, "OffWhite", rot=(0, -70, 0), seg=5),
        K((1.1, -1.05, 15.9), 0.22, 0.05, 1.2, "OffWhite", rot=(0, 70, 0), seg=5),
        B((-0.3, -1.32, 15.8), (0.25, 0.05, 0.25), "Charcoal"),
        B((0.3, -1.32, 15.8), (0.25, 0.05, 0.25), "Charcoal"),
    ]
    return s


def barrel():
    return [
        K((0, 0, 0.65), 0.95, 1.1, 1.3, "Wood", seg=10),
        K((0, 0, 1.95), 1.1, 0.95, 1.3, "Wood", seg=10),
        C((0, 0, 0.5), 1.07, 0.22, "Charcoal", seg=10),
        C((0, 0, 2.1), 1.07, 0.22, "Charcoal", seg=10),
        C((0, 0, 2.62), 0.9, 0.06, "Bark", seg=10),
    ]


def hay_bale():
    s = [BV((0, 0, 1), (3.4, 2.2, 2), "Sand", bevel=0.3)]
    s += [B((x, 0, 1), (0.2, 2.26, 2.06), "Bark") for x in (-0.9, 0.9)]
    s += [K((x, -1.1, 1.9), 0.18, 0.02, 0.6, "#E6BE78", rot=(-60, 0, i * 30), seg=4) for i, x in enumerate((-1.2, -0.2, 0.6, 1.3))]
    return s


def wagon():
    """A covered wagon, 9 long along Y."""
    s = [
        BV((0, 0, 2.4), (5, 9, 2), "Wood", bevel=0.15),
        B((0, 0, 3.5), (5.2, 9.2, 0.4), "Carpet"),
        C((0, 0, 3.6), 2.7, 8, "OffWhite", rot=(90, 0, 0), seg=10),
        B((0, -6, 1.4), (0.4, 3.6, 0.4), "Wood"),
        B((0, -7.7, 1.4), (2.2, 0.3, 0.3), "Wood"),
    ]
    s += [C((0, y, 3.6), 2.78, 0.25, "Wood", rot=(90, 0, 0), seg=10) for y in (-3.7, -1.2, 1.2, 3.7)]
    for x in (-2.8, 2.8):
        for y in (-3, 3):
            s += [
                C((x, y, 1.7), 1.7, 0.35, "Bark", rot=(0, 90, 0), seg=12),
                C((x, y, 1.7), 1.35, 0.4, "Sand", rot=(0, 90, 0), seg=12),
                C((x * 1.04, y, 1.7), 0.38, 0.8, "Gold", rot=(0, 90, 0), seg=8),
            ]
            s += [B((x, y, 1.7), (0.3, 2.9, 0.22), "Bark", rot=(k * 45, 0, 0)) for k in range(4)]
    return s


def hitch_rail():
    """A hitching rail, 8 long along Y."""
    return [
        C((0, 0, 2.8), 0.25, 8.4, "Wood", rot=(90, 0, 0), seg=6),
        BV((0, -3.6, 1.5), (0.6, 0.6, 3), "Bark", bevel=0.1),
        BV((0, 3.6, 1.5), (0.6, 0.6, 3), "Bark", bevel=0.1),
    ]


def trough():
    """A water trough, 6 long along Y."""
    return [
        BV((0, 0, 0.95), (2.2, 6, 1.3), "Bark", bevel=0.12),
        B((0, 0, 1.62), (1.6, 5.4, 0.08), "Water"),
        B((0, -2.2, 0.15), (2.4, 0.4, 0.3), "Wood"),
        B((0, 2.2, 0.15), (2.4, 0.4, 0.3), "Wood"),
    ]


FENCE_COLORS = {"Wood": "Wood", "White": "OffWhite"}


def fence(color):
    """A 5-stud ranch fence section along X, with a post at each end."""
    post = shade(color, 0.15)
    return [
        BV((0, 0, 1.4), (5.2, 0.5, 0.6), color, bevel=0.1),
        BV((0, 0, 2.8), (5.2, 0.5, 0.6), color, bevel=0.1),
        BV((-2.5, 0, 1.9), (0.9, 0.9, 3.8), post, bevel=0.12),
        BV((2.5, 0, 1.9), (0.9, 0.9, 3.8), post, bevel=0.12),
        K((-2.5, 0, 4.0), 0.55, 0.1, 0.4, post, seg=4, rot=(0, 0, 45)),
        K((2.5, 0, 4.0), 0.55, 0.1, 0.4, post, seg=4, rot=(0, 0, 45)),
    ]


def tumbleweed():
    s = [L((0, 0, 1.3), (1.3, 1.3, 1.3), "#BE965F", jitter=0.12)]
    s += ring(5, 0.9, 1.3, lambda x, y, a: L((x, y, 1.3 + math.sin(math.radians(a * 2)) * 0.6), (0.6, 0.55, 0.55), "#A57D4B", rot=(a, 0, a), jitter=0.1))
    return s


def wanted_board():
    """A WANTED poster nailed to a board. Spot: Poster."""
    return [
        BV((0, 0, 1.4), (2.4, 0.2, 3.0), "Bark", bevel=0.05),
        B((0, -0.11, 1.4), (2.1, 0.05, 2.7), "Cream"),
        T((0, -0.15, 1.4), (2.0, 0.05, 2.6), "Poster"),
        E((-0.9, -0.15, 2.6), (0.1, 0.06, 0.1), "Steel"),
        E((0.9, -0.15, 2.6), (0.1, 0.06, 0.1), "Steel"),
    ]


# --- Starlight Park -----------------------------------------------------------------------------


def park_arch():
    """The arch in from the hedge to Starlight Park. Spots: SignFront, SignBack."""
    s = []
    for x in (-10, 10):
        s += [
            BV((x, 0, 0.5), (4.2, 4.2, 1), "DarkGreen", bevel=0.12),
            BV((x, 0, 5.5), (3.4, 3.4, 11), "Cream", bevel=0.25),
            BV((x, 0, 11.5), (4, 4, 1), "DarkGreen", bevel=0.15),
            E((x, 0, 12.9), (0.9, 0.9, 0.9), "Gold"),
            L((x + math.copysign(2.6, x), -0.5, 1.2), (1.5, 1.4, 1.2), "Leaf"),
            L((x + math.copysign(2.0, x), -1.4, 1.0), (1.0, 0.9, 0.9), "LeafDark"),
        ]
        # Ivy climbing the pillar front, with a few flowers.
        s += [L((x + 0.4 * math.sin(k), -1.75, 2 + k * 1.8), (0.6, 0.3, 0.7), "Leaf" if k % 2 else "LeafDark") for k in range(5)]
        s += [E((x - 0.5, -1.95, 3.0 + k * 3.6), (0.22, 0.12, 0.22), "Pink") for k in range(2)]
    s += [
        BV((0, 0, 11.5), (24, 2.4, 2), "DarkGreen", bevel=0.2),
        BV((0, 0, 15), (19, 0.6, 4.4), "Gold", bevel=0.12),
        B((0, 0, 15), (18, 0.72, 3.6), "Green"),
        T((0, -0.37, 15), (17.4, 0.05, 3.4), "SignFront"),
        T((0, 0.37, 15), (17.4, 0.05, 3.4), "SignBack", rot=(0, 0, 180)),
        S((0, 0, 19), 1.7, 0.6, "Gold"),
    ]
    return s


def park_fountain():
    """The park's tiered stone fountain (its jet and splash are added by the game)."""
    s = [
        K((0, 0, 0.8), 6.2, 5.8, 1.6, "Stone", seg=10),
        C((0, 0, 1.62), 5.2, 0.06, "Water", seg=10),
        C((0, 0, 1.64), 3.6, 0.04, "WaterLight", seg=10),
        K((0, 0, 2.5), 1.0, 0.7, 3.4, "Stone", seg=8),
        K((0, 0, 4.2), 1.6, 2.6, 0.8, "Stone", seg=10),
        C((0, 0, 4.62), 2.0, 0.06, "WaterLight", seg=10),
        C((0, 0, 4.95), 0.35, 0.7, "Stone", seg=8),
    ]
    s += ring(10, 6.0, 1.6, lambda x, y, a: BV((x, y, 1.65), (3.6, 0.9, 0.3), shade("Stone", 0.1), rot=(0, 0, -a), bevel=0.06), start=18)
    return s


def movie_screen():
    """The open-air movie screen at the far end of the park, facing -Y. Spots: Screen, Marquee."""
    s = [
        BV((0, 1, 17), (46, 1, 24), "Charcoal", bevel=0.2),
        B((0, 0.4, 17), (43, 0.4, 21), "OffWhite"),
        T((0, 0.17, 17), (42, 0.05, 20), "Screen"),
        BV((0, 1, 31), (30, 0.8, 3.6), "Carpet", bevel=0.15),
        BV((0, 1.1, 31), (31, 0.6, 4.4), "Gold", bevel=0.1),
        T((0, 0.58, 31), (29, 0.05, 3.4), "Marquee"),
    ]
    for x in (-24, 24):
        s += [
            BV((x, 1, 15), (2.4, 2.4, 30), "Charcoal", bevel=0.2),
            B((x, 4, 9), (0.8, 0.8, 14), "Steel", rot=(-25, 0, 0)),
            BV((x * 1.12, -0.5, 1.6), (3, 2.2, 3.2), "Charcoal", bevel=0.25),
            C((x * 1.12, -1.62, 2.0), 0.9, 0.1, "Steel", rot=(90, 0, 0), seg=10),
            C((x * 1.12, -1.62, 0.8), 0.4, 0.1, "Steel", rot=(90, 0, 0), seg=8),
        ]
    s += [BV((-14.5 + i * 1.45, 0.5, 33.3), (0.4, 0.3, 0.4), "Light", bevel=0.07, neon=True) for i in range(21)]
    return s


def duck():
    return [
        BV((0, 0, 0.7), (1.8, 2.4, 1.4), "Duck", bevel=0.4),
        BV((0, 1.3, 1.3), (1.0, 0.8, 0.6), "Duck", rot=(-25, 0, 0), bevel=0.2),
        BV((0, -0.9, 1.9), (1.3, 1.3, 1.3), "Duck", bevel=0.35),
        BV((0, -1.8, 1.72), (0.8, 0.8, 0.3), "Orange", bevel=0.1),
        B((-0.66, -1.12, 2.1), (0.1, 0.3, 0.3), "Charcoal"),
        B((0.66, -1.12, 2.1), (0.1, 0.3, 0.3), "Charcoal"),
        BV((-0.92, 0.2, 0.85), (0.15, 1.4, 0.7), shade("Duck", 0.1), bevel=0.05),
        BV((0.92, 0.2, 0.85), (0.15, 1.4, 0.7), shade("Duck", 0.1), bevel=0.05),
    ]


def picnic_blanket():
    s = []
    for i in range(3):
        for k in range(3):
            s.append(B(((i - 1) * 2.4, (k - 1) * 2.4, 0.04), (2.4, 2.4, 0.08), "Carpet" if (i + k) % 2 == 0 else "OffWhite"))
    s += [
        BV((-0.8, 0.4, 0.68), (1.8, 1.2, 1.2), "Wood", bevel=0.12),
        B((-0.8, 0.4, 1.32), (1.9, 1.3, 0.1), "Carpet"),
        B((-1.45, 0.4, 1.65), (0.2, 0.2, 0.7), "Bark"),
        B((-0.15, 0.4, 1.65), (0.2, 0.2, 0.7), "Bark"),
        B((-0.8, 0.4, 2.0), (1.5, 0.2, 0.2), "Bark"),
        C((1.2, -1.0, 0.12), 0.6, 0.06, "OffWhite", seg=10),
        L((1.2, -1.0, 0.4), (0.3, 0.3, 0.3), "Carpet"),
        C((1.9, 0.6, 0.45), 0.25, 0.8, "Gold", seg=8),
    ]
    return s


def foot_bridge():
    """The wooden bridge out to the pond's island: 28 long along X, deck top 2.2 up, with a ramp
    down at the +X end (the game's -X end is the island)."""
    length = 28
    s = [BV((0, 0, 1.8), (length, 5, 0.8), "Wood", bevel=0.1)]
    s += [B((-length / 2 + i * 2.5, 0, 2.25), (0.3, 5, 0.1), "Bark") for i in range(int(length / 2.5) + 1)]
    for y in (-2.3, 2.3):
        s.append(C((0, y, 4.2), 0.25, length, "Bark", rot=(0, 90, 0), seg=6))
        s += [BV((-length / 2 + i * length / 4, y, 2.9), (0.7, 0.7, 3), "Bark", bevel=0.1) for i in range(5)]
        s += [C((-length / 2 + i * length / 4, y, 1.0), 0.45, 2.0, "Bark", seg=6) for i in (1, 2, 3)]
    s.append(W((-length / 2 - 1.5, 0, 1.1), (5, 3, 2.2), "Wood", rot=(0, 0, -90)))
    return s


def pond_stone():
    return [L((0, 0, 0.6), (3.8, 1.3, 0.75), "Stone", jitter=0.08)]


def lily_pad():
    return [C((0, 0, 0.06), 1.5, 0.12, "DarkGreen", seg=9), B((0.9, 0, 0.07), (1.2, 0.25, 0.14), "Water", rot=(0, 0, 20))]


def lily_flower():
    s = lily_pad()
    s += ring(5, 0.32, 0.4, lambda x, y, a: K((x, y, 0.4), 0.3, 0.1, 0.5, "Pink", rot=(25, 0, -a), seg=4))
    s.append(E((0, 0, 0.45), (0.18, 0.18, 0.12), "Gold"))
    return s


# --- Ambient life ---------------------------------------------------------------------------------


def bird():
    """A gliding gull, wings spread, flying toward -Y."""
    return [
        BV((0, 0, 0.5), (0.7, 2.2, 0.6), "OffWhite", bevel=0.2),
        BV((0, -1.3, 0.65), (0.55, 0.6, 0.5), "OffWhite", bevel=0.15),
        K((0, -1.75, 0.6), 0.14, 0.02, 0.5, "Orange", rot=(90, 0, 0), seg=4),
        B((1.4, 0.1, 0.65), (2.4, 0.9, 0.1), "OffWhite", rot=(0, -12, 0)),
        B((-1.4, 0.1, 0.65), (2.4, 0.9, 0.1), "OffWhite", rot=(0, 12, 0)),
        B((2.65, 0.25, 0.92), (0.6, 0.7, 0.1), "Charcoal", rot=(0, -12, 0)),
        B((-2.65, 0.25, 0.92), (0.6, 0.7, 0.1), "Charcoal", rot=(0, 12, 0)),
        W((0, 1.3, 0.55), (0.6, 0.6, 0.25), "OffWhite"),
    ]


def butterfly():
    return [
        B((0, 0, 0.3), (0.12, 0.6, 0.12), "Charcoal"),
        B((0.32, -0.08, 0.38), (0.55, 0.45, 0.04), "Pink", rot=(0, -25, 0)),
        B((-0.32, -0.08, 0.38), (0.55, 0.45, 0.04), "Pink", rot=(0, 25, 0)),
        B((0.26, 0.22, 0.34), (0.4, 0.3, 0.04), "Gold", rot=(0, -25, 0)),
        B((-0.26, 0.22, 0.34), (0.4, 0.3, 0.04), "Gold", rot=(0, 25, 0)),
    ]


def cloud():
    """A puffy low-poly cloud about 40 across."""
    return [
        L((0, 0, 6), (11, 8, 6), "OffWhite", jitter=0.04),
        L((-10, 1, 4.5), (8, 6.5, 4.5), "OffWhite", rot=(0, 0, 30), jitter=0.04),
        L((10, -1, 4.8), (8.5, 6.5, 4.8), "OffWhite", rot=(0, 0, 70), jitter=0.04),
        L((4, 2, 9.5), (6, 5, 4), "#FFFFFF", jitter=0.03),
        L((-17, 0, 3.2), (5, 4, 3.2), "#EEF2FA", jitter=0.03),
        L((18, 1, 3.4), (5, 4, 3.4), "#EEF2FA", jitter=0.03),
    ]


# --- The list -------------------------------------------------------------------------------------


def _v(fn, *args):
    return lambda: fn(*args)


KIT = (
    [("StoreStand" + name, _v(store_stand, col)) for name, col in STAND_COLORS.items()]
    + [
        ("PlazaFountain", plaza_fountain),
        ("Planter", planter),
        ("BoulevardArch", boulevard_arch),
        ("TownPillar", town_pillar),
        ("HedgeSection", hedge_section),
    ]
    + [("PosterColumn" + name, _v(poster_column, col)) for name, col in (("Green", "#6EBE50"), ("Blue", "Blue"), ("Pink", "Pink"), ("Red", "Carpet"))]
    + [("VintageCar" + name, _v(vintage_car, col)) for name, col in CAR_COLORS.items()]
    + [
        ("BusStop", bus_stop),
        ("Hydrant", hydrant),
        ("TrashBin", trash_bin),
        ("NewsStand", news_stand),
        ("FlowerPatch", flower_patch),
        ("PremiereTheatre", premiere_theatre),
        ("StudioGate", studio_gate),
        ("GuardBooth", guard_booth),
        ("HillStar", hill_star),
        ("Blimp", blimp),
    ]
    + [("CityTower" + str(i), _v(city_tower, i)) for i in (1, 2, 3)]
    + [("Hill" + name, _v(hill, col)) for name, col in HILL_COLORS.items()]
    + [
        ("ChromaWall", chroma_wall),
        ("CameraCrane", camera_crane),
        ("DirectorChair", director_chair),
        ("LightStand", light_stand),
        ("Clapperboard", clapperboard),
    ]
    + [("SetSign" + name, _v(set_sign, col)) for name, col in SIGN_COLORS.items()]
    + [
        ("PropCrate", prop_crate),
        ("DinoHead", dino_head),
        ("PropMoon", prop_moon),
        ("RollingSpotlight", rolling_spotlight),
    ]
    + [("StarTrailer" + name, _v(star_trailer, col)) for name, col in TRAILER_COLORS.items()]
    + [
        ("PatioTable", patio_table),
        ("TacoTruck", taco_truck),
        ("PopcornCart", popcorn_cart),
    ]
    + [("CafeTable" + name, _v(cafe_table, col)) for name, col in UMBRELLA_COLORS.items()]
    + [
        ("GulchArch", gulch_arch),
        ("Barrel", barrel),
        ("HayBale", hay_bale),
        ("Wagon", wagon),
        ("HitchRail", hitch_rail),
        ("Trough", trough),
    ]
    + [("Fence" + name, _v(fence, col)) for name, col in FENCE_COLORS.items()]
    + [
        ("Tumbleweed", tumbleweed),
        ("WantedBoard", wanted_board),
        ("ParkArch", park_arch),
        ("ParkFountain", park_fountain),
        ("MovieScreen", movie_screen),
        ("Duck", duck),
        ("PicnicBlanket", picnic_blanket),
        ("FootBridge", foot_bridge),
        ("PondStone", pond_stone),
        ("LilyPad", lily_pad),
        ("LilyFlower", lily_flower),
        ("Bird", bird),
        ("Butterfly", butterfly),
        ("Cloud", cloud),
    ]
)

# Preview line-ups (art/previews/<file>): front row, back row.
LINEUPS = {
    "town_kit_lobby.png": (
        ["Hydrant", "TrashBin", "FlowerPatch", "Planter", "TownPillar", "NewsStand", "PosterColumnBlue", "BusStop", "VintageCarTeal", "VintageCarPink"],
        ["StoreStandGold", "StoreStandPurple", "PlazaFountain", "HedgeSection", "BoulevardArch"],
    ),
    "town_kit_landmarks.png": (["GuardBooth", "StudioGate", "HillStar"], ["PremiereTheatre"]),
    "town_kit_sets.png": (
        ["DirectorChair", "LightStand", "Clapperboard", "SetSignGreen", "PropCrate", "DinoHead", "PropMoon", "RollingSpotlight", "PatioTable", "CafeTableTeal", "PopcornCart"],
        ["ChromaWall", "CameraCrane", "StarTrailerRed", "TacoTruck"],
    ),
    "town_kit_outer.png": (
        ["Barrel", "HayBale", "HitchRail", "Trough", "FenceWood", "Tumbleweed", "WantedBoard", "Duck", "PicnicBlanket", "LilyFlower", "PondStone", "Bird", "Butterfly"],
        ["GulchArch", "Wagon", "ParkArch", "ParkFountain", "FootBridge"],
    ),
    "town_kit_big.png": (["MovieScreen", "Blimp", "Cloud"], ["CityTower1", "CityTower2", "CityTower3", "HillGreen"]),
}
