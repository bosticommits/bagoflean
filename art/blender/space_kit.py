"""Space kit: the Moon Base film set (the second film set, east of Dusty Gulch). map_kit.py builds
these into the one map_kit.fbx and the one MapKitShapes.luau with the rest of the map kit, so run
that file, not this one.

  MoonRocket      a striped rocket on its launch pad with a gantry tower (about 40 tall: the set's
                  landmark, seen from Dusty Gulch). Spot: Side (the name down its side)
  MoonLander      the lunar lander the astronaut climbs out of: gold foil, four legs, a ladder
  MoonDome        a white habitat dome with round windows and an airlock
  MoonRock        a grey moon boulder
  MoonCrater      a low crater rim with a dark floor
  SpaceBackdrop   the painted backdrop at the far end of the set: stars and a ringed planet on a
                  big flat, propped up behind with wooden braces, the way film sets do it
  MoonBuggy       a little moon buggy with mesh wheels and a dish

A film set, so a little stagey: bright toy colors, gold foil, glowing lights. Chunky low-poly toy
style (ART_STYLE.md). Blender axes, in studs: Z up, the model faces -Y, standing on Z = 0.
"""

from kitdsl import B, C, E, K, L, S, T, ring, shade  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.15, neon=False):
    return B(at, size, color, rot, bevel, neon)


MOON = "#C9CCD2"
MOON_DARK = "#9A9EA8"
FOIL = "#F5B82E"


def moon_rocket():
    s = [
        # The launch pad: a round concrete pad with yellow and black hazard edging.
        C((0, 0, 0.5), 9.0, 1.0, "#B0B6C2", seg=16),
        C((0, 0, 1.05), 8.4, 0.1, "#2E2C34", seg=16),
        C((0, 0, 1.15), 4.2, 0.12, "#E8E8E8", seg=14),
    ]
    s += ring(12, 8.7, 1.0, lambda x, y, a: B((x, y, 1.02), (1.4, 0.6, 0.1), "Gold", rot=(0, 0, -a)))
    # Four fins, the body in white and red bands, round windows, and the nose cone.
    s += ring(4, 3.4, 4.6, lambda x, y, a: BV((x, y, 4.6), (0.5, 3.0, 6.0), "Carpet", rot=(0, 0, -a), bevel=0.15), start=45)
    s += [
        K((0, 0, 2.6), 2.2, 1.6, 2.6, "#4A4A52", seg=12),
        E((0, 0, 1.5), (1.4, 1.4, 0.6), "Flame", neon=True),
        C((0, 0, 9.5), 3.0, 13.0, "OffWhite", seg=16),
        C((0, 0, 5.2), 3.05, 1.6, "Carpet", seg=16),
        C((0, 0, 14.5), 3.05, 1.2, "Carpet", seg=16),
        C((0, 0, 21.0), 2.7, 10.0, "OffWhite", seg=16),
        C((0, 0, 16.4), 3.05, 0.6, "Navy", seg=16),
        C((0, 0, 25.8), 2.75, 1.0, "Carpet", seg=16),
        K((0, 0, 30.3), 2.7, 0.2, 8.0, "Carpet", seg=16),
        E((0, 0, 34.4), (0.4, 0.4, 0.4), "Light", neon=True),
    ]
    for z in (11.0, 19.0, 23.5):
        s += [
            C((0, -2.9, z), 0.8, 0.4, "Chrome", rot=(90, 0, 0), seg=12),
            C((0, -3.05, z), 0.6, 0.3, "Glass", rot=(90, 0, 0), seg=12),
        ]
    s.append(T((2.75, -1.5, 9.5), (0.05, 2.0, 9.0), "Side", rot=(0, 0, 90)))
    # The gantry tower beside it, a red and white lattice with a walkway arm.
    gx = 7.4
    for x in (gx - 1.4, gx + 1.4):
        for y in (-1.4, 1.4):
            s.append(B((x, y, 15.0), (0.5, 0.5, 30.0), "Carpet"))
    for k in range(10):
        z = 2.0 + k * 3.0
        s += [
            B((gx, -1.4, z), (3.3, 0.3, 0.3), "OffWhite"),
            B((gx, 1.4, z), (3.3, 0.3, 0.3), "OffWhite"),
            B((gx - 1.4, 0, z + 1.5), (0.3, 3.3, 0.3), "OffWhite"),
            B((gx + 1.4, 0, z + 1.5), (0.3, 3.3, 0.3), "OffWhite"),
        ]
    s += [
        BV((gx, 0, 30.4), (3.8, 3.8, 0.6), "#2E2C34", bevel=0.08),
        E((gx, 0, 31.1), (0.4, 0.4, 0.4), "Carpet", neon=True),
        B(((gx + 3.0) / 2 - 0.3, 0, 22.0), (gx - 3.0 + 0.6, 1.6, 0.4), "#9AA0AA"),
        B(((gx + 3.0) / 2 - 0.3, -0.8, 22.7), (gx - 3.0 + 0.6, 0.1, 1.0), "Gold"),
    ]
    return s


def moon_lander():
    s = []
    # Four splayed legs with round feet.
    for x in (-3.0, 3.0):
        for y in (-3.0, 3.0):
            s += [
                C((x * 0.85, y * 0.85, 2.3), 0.18, 4.4, "#9AA0AA", rot=(y * -4, x * 4, 0), seg=6),
                C((x, y, 0.15), 0.8, 0.3, "#9AA0AA", seg=10),
            ]
    s += [
        # The descent stage in gold foil, the ascent cabin on top, with a hatch facing front.
        BV((0, 0, 4.6), (5.6, 5.6, 2.6), FOIL, bevel=0.3),
        B((0, 0, 3.25), (4.2, 4.2, 0.3), "#4A4A52"),
        BV((0, 0, 7.4), (4.4, 4.0, 3.0), "#D7DAE1", bevel=0.4),
        BV((0, -2.05, 7.1), (1.6, 0.2, 1.8), "#4A4A52", bevel=0.1),
        E((-1.2, -1.95, 8.2), (0.45, 0.1, 0.35), "Glass"),
        E((1.2, -1.95, 8.2), (0.45, 0.1, 0.35), "Glass"),
        # The porch the astronaut stands on, and the ladder down the front leg.
        B((0, -3.4, 5.9), (2.2, 1.6, 0.25), "#9AA0AA"),
        C((0, 0, 9.4), 0.12, 1.4, "#9AA0AA", seg=6),
        C((0.4, 0.3, 10.2), 0.8, 0.12, "OffWhite", rot=(-30, 20, 0), seg=10),
        E((0.6, 1.2, 9.4), (0.15, 0.15, 0.15), "Carpet", neon=True),
    ]
    for x in (-0.7, 0.7):
        s.append(B((x, -3.9, 3.0), (0.15, 0.15, 6.0), "#9AA0AA"))
    for k in range(6):
        s.append(B((0, -3.9, 0.6 + k * 0.9), (1.4, 0.15, 0.12), "#9AA0AA"))
    return s


def moon_dome():
    s = [
        E((0, 0, 0), (9.0, 9.0, 7.0), "OffWhite"),
        C((0, 0, 0.4), 9.1, 0.8, "#9AA0AA", seg=20),
        E((0, 0, 6.9), (1.6, 1.6, 0.5), "Glass"),
        C((0, 0, 7.6), 0.15, 1.6, "#9AA0AA", seg=6),
        E((0, 0, 8.5), (0.25, 0.25, 0.25), "Teal", neon=True),
    ]
    # Round windows round the dome, lit from inside.
    s += ring(8, 7.6, 3.8, lambda x, y, a: E((x, y, 3.8), (0.9, 0.9, 0.9), "Light", neon=True), start=22.5)
    # The airlock tunnel at the front with a round door.
    s += [
        C((0, -9.2, 2.2), 2.4, 4.0, "#D7DAE1", rot=(90, 0, 0), seg=14),
        C((0, -11.25, 2.2), 2.5, 0.3, "#9AA0AA", rot=(90, 0, 0), seg=14),
        C((0, -11.45, 2.2), 1.7, 0.2, "#4A4A52", rot=(90, 0, 0), seg=14),
        E((1.2, -11.5, 2.2), (0.15, 0.08, 0.15), "Carpet", neon=True),
    ]
    return s


def moon_rock():
    return [
        L((0, 0, 1.2), (2.8, 2.2, 1.8), MOON_DARK, jitter=0.09),
        L((1.8, -0.8, 0.7), (1.2, 1.1, 0.9), MOON, jitter=0.1),
    ]


def moon_crater():
    s = ring(12, 5.5, 0.35, lambda x, y, a: L((x, y, 0.35), (2.0, 1.4, 0.7), MOON, rot=(0, 0, -a), jitter=0.08))
    s.append(C((0, 0, 0.06), 5.0, 0.12, MOON_DARK, seg=16))
    return s


def space_backdrop():
    """A 48 x 26 painted flat on legs, its face toward -Y: deep space, stars, a ringed planet."""
    w, h, z0 = 48.0, 26.0, 1.0
    zc = z0 + h / 2
    s = [
        BV((0, 0, zc), (w + 1.0, 0.8, h + 1.0), "#2E2C34", bevel=0.1),
        B((0, -0.45, zc), (w, 0.2, h), "#141A3A"),
        # The planet: a big orange disc with bands and a tilted ring.
        C((11, -0.6, zc + 3.5), 6.0, 0.15, "#E8834A", rot=(90, 0, 0), seg=24),
        C((11, -0.68, zc + 4.8), 5.4, 0.1, "#F2A86A", rot=(90, 0, 0), seg=24),
        C((11, -0.74, zc + 2.0), 4.6, 0.1, "#C9653A", rot=(90, 0, 0), seg=24),
        B((11, -0.8, zc + 3.5), (17.0, 0.1, 1.0), "#F5D58C", rot=(0, -18, 0)),
        # A small moon and a comet.
        C((-14, -0.6, zc + 7.0), 2.2, 0.15, "#D7DAE1", rot=(90, 0, 0), seg=16),
        C((-13.4, -0.68, zc + 7.4), 0.6, 0.1, MOON_DARK, rot=(90, 0, 0), seg=10),
        B((-6, -0.6, zc + 9.0), (6.0, 0.1, 0.4), "Teal", rot=(0, 20, 0)),
        E((-3.2, -0.65, zc + 10.0), (0.6, 0.1, 0.6), "OffWhite", neon=True),
    ]
    # Stars: a fixed scatter of glowing dots.
    for i in range(34):
        x = -w / 2 + 1.5 + ((i * 37) % 45)
        z = z0 + 1.5 + ((i * 53) % 23)
        if abs(x - 11) < 8 and abs(z - (zc + 3.5)) < 8:
            continue
        r = 0.18 + (i % 3) * 0.1
        s.append(E((x, -0.6, z), (r, 0.05, r), "Light", neon=True))
    # Wooden braces and sandbags behind: it's only a set.
    for x in (-18, -6, 6, 18):
        s += [
            B((x, 4.0, zc - 2.0), (0.6, 0.6, 19.0), "Wood", rot=(-28, 0, 0)),
            B((x, 0.6, z0 - 0.5), (0.8, 0.8, 1.0), "Wood"),
            BV((x, 8.4, 0.5), (2.0, 1.2, 1.0), "#B5A27A", bevel=0.3),
        ]
    return s


def moon_buggy():
    s = []
    for x in (-2.2, 2.2):
        for y in (-2.4, 2.4):
            s += [
                C((x, y, 1.0), 1.0, 0.8, "#4A4A52", rot=(0, 90, 0), seg=12),
                C((x, y, 1.0), 0.5, 0.85, "#D7DAE1", rot=(0, 90, 0), seg=8),
            ]
    s += [
        BV((0, 0, 1.8), (4.0, 6.4, 0.6), "#D7DAE1", bevel=0.15),
        BV((0, 0.6, 2.4), (2.6, 1.6, 0.8), "Navy", bevel=0.2),
        BV((0, -1.6, 2.3), (2.4, 1.0, 0.5), FOIL, bevel=0.1),
        C((1.2, 2.4, 3.6), 0.08, 2.4, "#9AA0AA", seg=6),
        C((1.2, 2.4, 4.9), 1.0, 0.12, "OffWhite", rot=(-40, 0, 0), seg=12),
        E((-1.5, -3.2, 2.0), (0.25, 0.08, 0.2), "Light", neon=True),
        E((1.5, -3.2, 2.0), (0.25, 0.08, 0.2), "Light", neon=True),
    ]
    return s


KIT = [
    ("MoonRocket", moon_rocket),
    ("MoonLander", moon_lander),
    ("MoonDome", moon_dome),
    ("MoonRock", moon_rock),
    ("MoonCrater", moon_crater),
    ("SpaceBackdrop", space_backdrop),
    ("MoonBuggy", moon_buggy),
]

# Sunk into the ground: the dome is the top half of a ball.
NO_LIFT = {"MoonDome"}

LINEUPS = {
    "space_kit.png": (["MoonLander", "MoonRock", "MoonCrater", "MoonBuggy", "MoonDome"], ["MoonRocket", "SpaceBackdrop"]),
}
