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

The open backlot version of the set (TownSets.moonBase) uses the bigger pieces: MoonRocketPad (the
rocket on an octagonal pad with a lattice gantry), MoonLanderHero (the lander, same porch and
ladder as MoonLander), MoonHabitat (dome, airlock, lab, solar panels, dish), MoonBuggyHero,
MoonFoamRock, MoonPropCart, MoonFakeEarth, MoonSupplyCrates, the ground pieces (MoonCraterSmall,
-Mid, -Big, MoonRegolith, MoonDuneEdge, MoonBoulders, MoonPebbles, MoonTracks, MoonFootprints,
MoonFlagMark), and the painted flats, built with backlot_kit.flat() so they share its timber frame,
jacks and sandbags: MoonFlatEarthrise, MoonFlatStarfield, MoonFlatHorizon and MoonGroundRow.

A film set, so a little stagey: bright toy colors, gold foil, glowing lights. Chunky low-poly toy
style (ART_STYLE.md). Blender axes, in studs: Z up, the model faces -Y, standing on Z = 0.
"""

import math

import backlot_kit
from kitdsl import B, C, E, G, K, L, S, T, W, ring, shade  # noqa: F401


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
    s += rocket_body()
    s += old_gantry()
    return s


def rocket_body():
    """The rocket on its own, for a pad whose top is at Z = 1.1 (MoonRocket, MoonRocketPad)."""
    s = []
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
    return s


def old_gantry():
    """MoonRocket's gantry tower, a red and white lattice with a walkway arm."""
    s = []
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


# --- Moon Base backlot pieces (the open studio set) ----------------------------------------------

SAND = "#ECC480"  # the desert floor round the set (MapScenery DesertFloor)
DUST_1 = "#D5C9B7"  # moon dust a third of the way to sand
DUST_2 = "#E0C79C"  # two thirds of the way
FOAM = "#F2E2B8"
TAPE = "#FF8C28"
PANEL = "#D7DAE1"
STRUT = "#9AA0AA"
DARK = "#4A4A52"


def rod(p, q, r, color, seg=6):
    """A cylinder from point p to point q."""
    d = [b - a for a, b in zip(p, q)]
    n = math.sqrt(sum(v * v for v in d))
    tilt = math.degrees(math.asin(-d[1] / n))
    turn = math.degrees(math.atan2(d[0], d[2]))
    return C(tuple((a + b) / 2 for a, b in zip(p, q)), r, n, color, rot=(tilt, turn, 0), seg=seg)


def dish(at, r, color, tilt=-35, yaw=0):
    """A shallow antenna dish facing up and tilted toward -Y, with its feed horn."""
    return G(at, (tilt, 0, yaw),
        K((0, 0, 0.35), r * 0.2, r, 0.7, color, seg=12),
        C((0, 0, 0.71), r * 0.85, 0.04, "#E8EAEE", seg=12),
        C((0, 0, 1.1), 0.06, 1.4, STRUT, seg=5),
        E((0, 0, 1.8), (0.15, 0.15, 0.15), "Carpet", neon=True),
    )


def moon_rocket_pad():
    """The rocket on a big octagonal launch pad, with a lattice gantry, service arms and a ladder."""
    top = 2.2
    s = [
        C((0, 0, top / 2), 13.0, top, "Stone", rot=(0, 0, 22.5), seg=8),
        C((0, 0, top + 0.05), 12.2, 0.1, "Asphalt", rot=(0, 0, 22.5), seg=8),
        C((0, 0, top + 0.1), 5.6, 0.1, "Charcoal", seg=16),
        C((0, 0, top + 0.15), 4.0, 0.08, "#5A5A62", seg=16),
    ]
    # Yellow and black hazard blocks round the deck edge, and four hold-down clamps.
    s += ring(16, 11.4, top, lambda x, y, a: B((x, y, top + 0.1), (2.6, 0.8, 0.12), "Duck" if round(a / 22.5) % 2 else "Charcoal", rot=(0, 0, -a)), start=11.25)
    s += ring(4, 3.4, top, lambda x, y, a: BV((x, y, top + 0.6), (1.2, 1.6, 1.0), STRUT, rot=(0, 0, -a), bevel=0.1), start=0)
    # Steps up the front, two fuel tanks on saddles at the back.
    for k in range(3):
        s.append(B((-6.0, -12.6 - k * 0.9, 0.37 * (3 - k)), (4.0, 1.0, 0.74 * (3 - k)), "Stone"))
    for x in (-5.5, -1.5):
        s += [
            C((x, 9.0, top + 1.3), 1.4, 5.0, "OffWhite", rot=(90, 0, 0), seg=12),
            C((x, 9.0, top + 1.3), 1.45, 0.4, "Carpet", rot=(90, 0, 0), seg=12),
            B((x, 7.6, top + 0.3), (2.0, 0.5, 0.6), STRUT),
            B((x, 10.4, top + 0.3), (2.0, 0.5, 0.6), STRUT),
        ]
    s.append(G((0, 0, top - 1.1), (0, 0, 0), *rocket_body()))

    # The gantry: four red legs, white rails every bay and a zigzag of braces on each face.
    gx, half, h, bay = 10.0, 2.0, 40.0, 3.6
    bays = int((h - 2.0) / bay)
    for x in (gx - half, gx + half):
        for y in (-half, half):
            s.append(B((x, y, top + h / 2), (0.6, 0.6, h), "Carpet"))
    for k in range(bays + 1):
        z = top + 1.0 + k * bay
        s += [
            B((gx, -half, z), (2 * half, 0.35, 0.35), "OffWhite"),
            B((gx, half, z), (2 * half, 0.35, 0.35), "OffWhite"),
            B((gx - half, 0, z), (0.35, 2 * half, 0.35), "OffWhite"),
            B((gx + half, 0, z), (0.35, 2 * half, 0.35), "OffWhite"),
        ]
        if k < bays:
            lean = math.degrees(math.atan2(2 * half, bay)) * (1 if k % 2 else -1)
            zm = z + bay / 2
            length = math.hypot(2 * half, bay)
            s += [
                B((gx, -half, zm), (0.3, 0.3, length), "OffWhite", rot=(0, lean, 0)),
                B((gx, half, zm), (0.3, 0.3, length), "OffWhite", rot=(0, -lean, 0)),
                B((gx + half, 0, zm), (0.3, 0.3, length), "OffWhite", rot=(lean, 0, 0)),
            ]
    # The ladder up the outside face.
    lx = gx + half + 0.6
    s += [B((lx, y, top + h / 2), (0.15, 0.15, h), STRUT) for y in (-0.6, 0.6)]
    s += [B((lx, 0, top + 0.6 + k * 1.4), (0.12, 1.2, 0.12), STRUT) for k in range(int(h / 1.4))]
    # Service arms swung across to the rocket: a walkway with rails and a hose; a white room at the
    # top one, where the crew climb in.
    for z, room in ((top + 12.0, False), (top + 19.5, False), (top + 25.0, True)):
        x0, x1 = gx - half, 2.2
        mid = (x0 + x1) / 2
        s += [
            B((mid, 0, z), (x0 - x1, 1.6, 0.35), STRUT),
            B((mid, -0.75, z + 0.6), (x0 - x1, 0.1, 0.1), "Duck"),
            B((mid, 0.75, z + 0.6), (x0 - x1, 0.1, 0.1), "Duck"),
            rod((x0, 0.9, z - 0.2), (x1 + 0.8, 0.9, z - 1.4), 0.18, "Charcoal"),
        ]
        if room:
            s += [
                BV((x1 + 0.9, 0, z + 1.3), (1.8, 2.2, 2.6), "OffWhite", bevel=0.15),
                B((x1 + 0.9, -1.12, z + 1.5), (1.2, 0.05, 0.8), "Glass"),
            ]
    # The hammerhead crane, a lightning mast and warning lights on top.
    zt = top + h
    s += [
        BV((gx, 0, zt + 0.3), (4.8, 4.8, 0.6), "Charcoal", bevel=0.08),
        B((gx - 3.0, 0, zt + 1.6), (9.0, 0.8, 0.8), "Carpet"),
        B((gx - 7.0, 0, zt + 0.7), (0.1, 0.1, 1.8), STRUT),
        B((gx - 7.0, 0, zt - 0.3), (0.6, 0.6, 0.3), "Charcoal"),
        B((gx + 1.6, 0, zt + 1.0), (1.2, 1.2, 1.4), "OffWhite"),
        C((gx, 0, zt + 4.0), 0.1, 5.0, STRUT, seg=5),
        E((gx, 0, zt + 6.6), (0.35, 0.35, 0.35), "Carpet", neon=True),
        E((gx - 7.4, 0, zt + 2.2), (0.3, 0.3, 0.3), "Carpet", neon=True),
    ]
    return s


def lander_body():
    """The new lander's shapes round its ladder and porch, which stay exactly MoonLander's (the
    astronaut's marks in FilmScenes stand on them)."""
    s = []
    # Four legs: a main strut, two side braces, a round footpad.
    for x in (-1, 1):
        for y in (-1, 1):
            foot = (3.3 * x, 3.3 * y, 0.5)
            knee = (2.9 * x, 2.9 * y, 1.9)
            s += [
                rod((2.0 * x, 2.0 * y, 4.4), foot, 0.17, STRUT),
                rod((2.7 * x, 1.0 * y, 3.4), knee, 0.1, PANEL),
                rod((1.0 * x, 2.7 * y, 3.4), knee, 0.1, PANEL),
                K((3.3 * x, 3.3 * y, 0.2), 0.95, 0.65, 0.4, PANEL, seg=10),
                C((3.3 * x, 3.3 * y, 0.45), 0.25, 0.2, STRUT, seg=8),
            ]
    # The descent stage: an eight-sided drum in gold foil, crinkled panels on its faces and black
    # blankets on the corners, the engine bell underneath.
    s += [
        C((0, 0, 4.6), 2.92, 2.6, FOIL, rot=(0, 0, 22.5), seg=8),
        C((0, 0, 3.25), 2.6, 0.3, DARK, rot=(0, 0, 22.5), seg=8),
        C((0, 0, 5.95), 2.75, 0.12, "#D99A22", rot=(0, 0, 22.5), seg=8),
        K((0, 0, 2.6), 1.2, 0.7, 1.3, DARK, seg=10),
    ]
    s += ring(4, 2.78, 4.6, lambda x, y, a: L((x, y, 4.5), (1.0, 0.16, 0.95), FOIL, rot=(0, 0, -a), jitter=0.16), start=90)
    s += [L((0, 2.78, 4.5), (1.0, 0.16, 0.95), FOIL, jitter=0.16)]
    s += ring(4, 2.72, 4.6, lambda x, y, a: B((x, y, 4.6), (1.6, 0.12, 2.0), "Charcoal", rot=(0, 0, -a)), start=45)
    # The ascent cabin: grey panels, a slanted front with two windows over the hatch, side tanks,
    # an equipment bay at the back and thruster clusters on the corners.
    s += [
        BV((0, 0.4, 7.6), (4.6, 3.4, 3.2), PANEL, bevel=0.35),
        BV((0, -1.55, 7.9), (3.4, 1.4, 2.6), "#C3C7CF", rot=(-14, 0, 0), bevel=0.25),
        BV((0, -2.1, 6.95), (1.5, 0.3, 1.6), DARK, bevel=0.1),
        B((-0.95, -2.2, 8.7), (0.9, 0.12, 0.65), "Glass", rot=(-14, 0, 18)),
        B((0.95, -2.2, 8.7), (0.9, 0.12, 0.65), "Glass", rot=(-14, 0, -18)),
        C((-2.55, 0.7, 7.3), 0.75, 1.8, STRUT, seg=10),
        C((2.55, 0.7, 7.3), 0.75, 1.8, STRUT, seg=10),
        BV((0, 2.5, 7.0), (3.6, 1.2, 1.8), DARK, bevel=0.15),
        B((0, 2.5, 8.0), (3.4, 1.0, 0.2), FOIL),
        C((0, 0.4, 9.35), 0.8, 0.4, STRUT, seg=10),
        dish((1.5, 1.4, 9.5), 0.8, "OffWhite", tilt=-40, yaw=20),
        rod((-1.6, 1.4, 9.1), (-2.2, 1.9, 11.0), 0.06, STRUT, seg=4),
        rod((-1.2, -0.6, 9.1), (-1.8, -1.0, 10.6), 0.06, STRUT, seg=4),
    ]
    for x in (-1, 1):
        for y in (-1, 1):
            cx, cy, cz = 2.45 * x, 0.4 + 1.85 * y, 8.6
            s += [
                B((cx, cy, cz), (0.5, 0.5, 0.5), STRUT),
                K((cx, cy, cz + 0.45), 0.16, 0.24, 0.4, DARK, seg=6),
                K((cx, cy, cz - 0.45), 0.24, 0.16, 0.4, DARK, seg=6),
                K((cx + 0.45 * x, cy, cz), 0.16, 0.24, 0.4, DARK, rot=(0, 90 * x, 0), seg=6),
            ]
    return s


def moon_lander_hero():
    s = lander_body()
    # MoonLander's porch and ladder, unchanged.
    s.append(B((0, -3.4, 5.9), (2.2, 1.6, 0.25), "#9AA0AA"))
    for x in (-0.7, 0.7):
        s.append(B((x, -3.9, 3.0), (0.15, 0.15, 6.0), "#9AA0AA"))
    for k in range(6):
        s.append(B((0, -3.9, 0.6 + k * 0.9), (1.4, 0.15, 0.12), "#9AA0AA"))
    s += [
        B((x, -3.0, 6.55), (0.1, 1.2, 0.1), "Duck") for x in (-1.05, 1.05)
    ]
    s += [B((x, -3.6, 6.3), (0.1, 0.1, 0.6), "Duck") for x in (-1.05, 1.05)]
    return s


def moon_habitat():
    """A habitat dome sunk into the ground (origin at ground level, the dome's middle) with an
    airlock tunnel toward -Y, a lab module, solar panels, a dish and supply crates."""
    s = [
        E((0, 0, 0), (8.0, 8.0, 6.4), "OffWhite"),
        C((0, 0, 0.5), 8.2, 1.0, STRUT, seg=18),
        E((0, 0, 6.1), (1.8, 1.8, 0.8), "Glass"),
        C((0, 0, 6.5), 1.9, 0.25, PANEL, seg=12),
        C((0, 0, 7.4), 0.12, 1.8, STRUT, seg=5),
        E((0, 0, 8.4), (0.25, 0.25, 0.25), "Teal", neon=True),
    ]
    # Round lit windows set into the dome, and seams of darker panels between them.
    for i in range(6):
        a = math.radians(30 + i * 60)
        e = math.radians(28)
        n = (math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))
        p = (8.0 * n[0], 8.0 * n[1], 6.4 * n[2])
        out = tuple(pv + nv * 0.6 for pv, nv in zip(p, n))
        s += [rod(p, out, 0.95, PANEL, seg=10), rod(p, tuple(pv + nv * 0.7 for pv, nv in zip(p, n)), 0.7, "Light", seg=10)]
        s[-1]["neon"] = True
    # The airlock tunnel with ribs, and a square airlock box with a door and a lamp.
    s += [C((0, -9.6, 2.2), 2.1, 4.2, PANEL, rot=(90, 0, 0), seg=12)]
    s += [C((0, y, 2.2), 2.3, 0.35, STRUT, rot=(90, 0, 0), seg=12) for y in (-8.4, -10.2)]
    s += [
        BV((0, -13.0, 2.6), (5.2, 3.2, 5.2), "OffWhite", bevel=0.4),
        B((0, -13.0, 5.3), (5.4, 3.4, 0.3), "Carpet"),
        BV((0, -14.6, 2.2), (2.4, 0.3, 3.8), DARK, bevel=0.15),
        B((0, -14.78, 2.5), (1.2, 0.06, 1.0), "Glass"),
        E((1.7, -14.7, 4.3), (0.25, 0.12, 0.25), "Duck", neon=True),
        B((0, -15.4, 0.2), (3.0, 1.4, 0.4), STRUT),
    ]
    # A lab module on the right, on short legs, joined to the dome.
    s += [
        C((12.0, 1.0, 3.0), 2.4, 7.0, PANEL, rot=(0, 90, 0), seg=12),
        E((15.5, 1.0, 3.0), (0.9, 2.4, 2.4), PANEL),
        C((12.0, 1.0, 3.0), 2.5, 0.4, "Carpet", rot=(0, 90, 0), seg=12),
        C((8.2, 1.0, 3.0), 1.6, 2.4, STRUT, rot=(0, 90, 0), seg=10),
        B((12.0, -1.5, 3.4), (3.6, 0.2, 0.8), "Light", neon=True),
        B((10.0, 1.0, 0.4), (0.6, 3.0, 0.8), STRUT),
        B((14.0, 1.0, 0.4), (0.6, 3.0, 0.8), STRUT),
    ]
    # Two solar panels on the left on poles, tilted to the sun.
    for y in (-3.0, 4.5):
        s += [
            C((-11.5, y, 1.6), 0.18, 3.2, STRUT, seg=6),
            G((-11.5, y, 3.3), (0, -30, 0),
              BV((0, 0, 0), (4.2, 3.4, 0.2), "Navy", bevel=0.05),
              B((0, 0, 0.11), (4.0, 0.08, 0.04), PANEL),
              B((-1.0, 0, 0.11), (0.08, 3.2, 0.04), PANEL),
              B((1.0, 0, 0.11), (0.08, 3.2, 0.04), PANEL),
              B((0, 0, -0.15), (4.2, 0.2, 0.1), STRUT)),
        ]
    # A dish on a tripod behind the lab, and a stack of supply crates by the airlock.
    s += [rod((12 + 1.4 * math.sin(a), 7.5 + 1.4 * math.cos(a), 0), (12, 7.5, 3.4), 0.1, STRUT) for a in (0, 2.1, 4.2)]
    s.append(dish((12, 7.5, 3.4), 2.0, "OffWhite", tilt=-45, yaw=200))
    s += supply_crates((4.6, -12.0, 0))
    return s


def supply_crates(at=(0, 0, 0)):
    x, y, z = at
    return [
        BV((x, y, z + 0.8), (1.8, 1.6, 1.6), "OffWhite", bevel=0.12),
        B((x, y, z + 0.8), (1.86, 1.66, 0.35), "Carpet"),
        BV((x + 1.9, y + 0.2, z + 0.7), (1.6, 1.6, 1.4), FOIL, bevel=0.12),
        BV((x + 0.8, y + 0.1, z + 2.15), (1.5, 1.3, 1.1), "OffWhite", bevel=0.12),
        B((x + 0.8, y - 0.56, z + 2.15), (0.9, 0.06, 0.3), "Blue"),
        C((x - 1.5, y + 0.4, z + 1.0), 0.6, 2.0, PANEL, seg=10),
        C((x - 1.5, y + 0.4, z + 1.6), 0.62, 0.3, "Carpet", seg=10),
    ]


def moon_supply_crates():
    return supply_crates()


def crater(r, n):
    """A crater: a ring of wedges for the raised rim, sloping gently out to the ground and more
    steeply in to a darker floor, with a few rim boulders."""
    h = 0.45 + r * 0.08
    run_out, run_in = h * 3.2, h * 1.6
    s = []
    for i in range(n):
        a = i * 360 / n
        sa, ca = math.sin(math.radians(a)), math.cos(math.radians(a))
        tone = shade(MOON, 0.04 * (i % 3) - 0.03)
        ro = r + run_out / 2
        s += [
            W((sa * ro, ca * ro, h / 2), (2 * (r + run_out) * math.sin(math.pi / n) * 1.04, run_out, h), tone, rot=(0, 0, 180 - a)),
            W((sa * (r - run_in / 2), ca * (r - run_in / 2), h / 2), (2 * r * math.sin(math.pi / n) * 1.08, run_in, h), shade(tone, 0.08), rot=(0, 0, -a)),
        ]
    s.append(C((0, 0, 0.04), r - run_in * 0.5, 0.08, "#ABAFB8", seg=n))
    for k in range(max(2, n // 5)):
        a = math.radians(k * 137 + 20)
        rr = r + (0.2 if k % 2 else -0.3)
        size = 0.35 + 0.1 * r * (0.5 + (k % 3) * 0.3)
        s.append(L((math.sin(a) * rr, math.cos(a) * rr, h * 0.9), (size * 1.3, size, size * 0.8), MOON_DARK, rot=(0, 0, k * 50), jitter=0.1))
    return s


def blobs(spec, sink):
    """Flat faceted blobs sunk into the ground: (x, y, rx, ry, rise, color, turn)."""
    return [L((x, y, rise - rz), (rx, ry, rz), color, rot=(0, 0, turn), jitter=0.05)
            for x, y, rx, ry, rise, color, turn in spec for rz in [sink]]


def moon_regolith():
    """A big low patch of lumpy moon ground, about 34 x 26, to break up the flat set floor."""
    return blobs([
        (0, 0, 12.0, 8.0, 0.55, MOON, 10),
        (-9, 4, 8.0, 6.0, 0.45, shade(MOON, 0.05), -20),
        (9, -3, 8.0, 6.5, 0.4, shade(MOON, -0.08), 30),
        (3, 8, 7.0, 4.0, 0.35, shade(MOON, 0.03), 60),
        (-5, -7, 6.0, 4.0, 0.3, shade(MOON, -0.05), -40),
        (13, 6, 4.0, 3.0, 0.5, MOON_DARK, 15),
    ], 2.4)


def moon_dune_edge():
    """A 40-long strip of low mounds that fades moon grey (at -Y, the set side) into desert sand
    (at +Y), laid over the edge of the set's grey floor. Strips can overlap and turn corners."""
    spec = []
    for row, (y, color, rise) in enumerate(((-4.0, MOON, 0.45), (-0.5, DUST_1, 0.5), (3.0, DUST_2, 0.42), (6.5, SAND, 0.32))):
        for k in range(5):
            x = -16 + k * 8 + (row % 2) * 4 - 2 * (row // 2)
            spec.append((x, y + ((k * 7 + row) % 3 - 1) * 0.6, 6.0 + (k % 2), 3.2, rise + 0.08 * ((k + row) % 2), color, (k * 23 + row * 11) % 40 - 20))
    return blobs(spec, 1.6)


def moon_boulders():
    return [
        L((0, 0, 1.6), (3.0, 2.4, 2.4), MOON_DARK, rot=(0, 0, 15), jitter=0.1),
        L((2.6, -1.4, 0.9), (1.6, 1.4, 1.4), MOON, rot=(0, 0, 40), jitter=0.1),
        L((-2.4, -1.0, 0.6), (1.2, 1.0, 1.0), shade(MOON_DARK, -0.1), jitter=0.1),
        L((1.0, 2.2, 0.5), (1.0, 0.9, 0.8), MOON, jitter=0.1),
    ]


def moon_pebbles():
    pts = ((0, 0, 0.5), (1.1, 0.4, 0.35), (-0.9, 0.6, 0.4), (0.4, -1.0, 0.3), (-0.5, -0.8, 0.25), (1.6, -0.6, 0.22), (-1.6, -0.2, 0.3))
    return [L((x, y, r * 0.7), (r * 1.2, r, r * 0.8), MOON_DARK if i % 2 else MOON, rot=(0, 0, i * 40), jitter=0.12) for i, (x, y, r) in enumerate(pts)]


def moon_tracks():
    """Buggy tyre tracks, 24 long along Y: two rows of shallow tread marks."""
    s = []
    for x in (-1.9, 1.9):
        for k in range(20):
            s.append(B((x, -11.4 + k * 1.2, 0.02), (0.9, 0.5, 0.04), "#AEB2BB", rot=(0, 0, 14 if x < 0 else -14)))
    return s


def moon_footprints():
    """A trail of boot prints, 14 long along Y."""
    s = []
    for k in range(12):
        x = 0.45 if k % 2 else -0.45
        y = -7 + k * 1.2
        s += [
            B((x, y, 0.02), (0.5, 0.75, 0.04), "#AEB2BB"),
            B((x, y + 0.5, 0.02), (0.4, 0.3, 0.04), "#AEB2BB"),
        ]
    return s


def disc(at, r, color, seg=12, neon=False, t=0.1):
    """A flat disc facing -Y (a painted star on a backdrop's face)."""
    return C(at, r, t, color, rot=(90, 0, 0), seg=seg, neon=neon)


NIGHT = ("#3A3570", "#2A3266", "#1E2652", "#141A3A")  # the painted sky, bottom band to top


def night(w, h):
    """The painted night on a flat's face: darker toward the top, a purple haze low down."""
    return [backlot_kit.dab(0, h * (k + 0.5) / 4, w, h / 4, color, 1) for k, color in enumerate(NIGHT)]


def stars(w, h, seed, skip=(), z0=0.0):
    """Glowing painted stars over a flat's face, missing the circles in `skip` ((x, z, r), ...)."""
    s = []
    for i in range(int(w * (h - z0) / 22)):
        x = -w / 2 + 1.0 + ((i * 37 + seed * 11) % int(w - 2))
        z = z0 + 1.0 + ((i * 53 + seed * 7) % int(h - z0 - 2)) + 0.5 * (i % 2)
        if any(math.hypot(x - sx, z - sz) < sr for sx, sz, sr in skip):
            continue
        y = backlot_kit.FACE - 0.6
        if i % 7 == 0:
            s.append(S((x, y, z), 0.55, 0.1, "Light", neon=True))
        else:
            s.append(disc((x, y, z), 0.16 + (i % 3) * 0.08, "Light", seg=6, neon=True))
    return s


def moon_hills(w, z0, layer, color, peaks):
    """A painted grey horizon along a flat: a band of ground with rounded hill tops (x, rise)."""
    s = [backlot_kit.dab(0, z0 / 2, w, z0, color, layer)]
    for x, rise in peaks:
        s.append(backlot_kit.disc(x, z0 - rise * 0.4, rise, color, layer + 1, seg=14))
    return s


def earth(x, z, r, layer):
    """The painted Earth: blue with green land, white cloud swirls and a pale glow ring."""
    d = backlot_kit.disc
    return [
        d(x, z, r * 1.12, "#5A6AB8", layer, seg=20),
        d(x, z, r, "Blue", layer + 1, seg=20),
        d(x - r * 0.3, z + r * 0.25, r * 0.42, "Green", layer + 2, seg=10),
        d(x + r * 0.35, z - r * 0.25, r * 0.3, "Green", layer + 2, seg=10),
        d(x + r * 0.45, z + r * 0.45, r * 0.18, "DarkGreen", layer + 2, seg=8),
        d(x - r * 0.05, z - r * 0.45, r * 0.2, "Green", layer + 2, seg=8),
        # Cloud swirls: little clusters of white puffs.
        *[d(x + cx * r, z + cz * r, cr * r, "OffWhite", layer + 3 + i % 3, seg=8)
          for i, (cx, cz, cr) in enumerate( ((-0.35, 0.05, 0.16), (-0.15, 0.1, 0.2), (0.05, 0.02, 0.14), (0.3, 0.62, 0.13), (0.45, 0.58, 0.1),
                             (-0.25, -0.68, 0.12), (-0.08, -0.72, 0.1), (0.6, -0.1, 0.1)))],
    ]


def moon_flat_earthrise():
    """The middle backdrop, 44 x 26: the Earth rising over a grey moon horizon, under the stars."""
    w, h = 44.0, 26.0
    p = night(w, h) + earth(4, h * 0.56, 7.0, 2)
    p += moon_hills(w, h * 0.3, 6, "#7E828C", ((-15, 3.4), (-6, 2.2), (12, 4.0), (19, 2.4)))
    p += moon_hills(w, h * 0.2, 8, "#A7ABB4", ((-18, 2.0), (-2, 3.0), (9, 1.6), (17, 2.6)))
    # Painted craters on the near ground.
    for x, z, r in ((-12, 2.6, 1.6), (7, 3.4, 1.1), (15, 1.8, 2.0), (-3, 1.4, 0.9)):
        p += [backlot_kit.dab(x, z, r * 2.2, r * 0.7, MOON_DARK, 10), backlot_kit.dab(x, z + r * 0.2, r * 1.6, r * 0.3, "#C3C7CF", 11)]
    p += stars(w, h, 1, skip=((4, h * 0.56, 9),), z0=h * 0.45)
    return backlot_kit.flat(w, h, p, base=NIGHT[2])


def moon_flat_starfield():
    """A side backdrop, 36 x 24: deep space with a ringed planet, a purple nebula and a comet."""
    w, h = 36.0, 24.0
    d = backlot_kit.disc
    p = night(w, h) + [
        d(-7, h * 0.62, 5.6, "#3C2A78", 2, seg=12),
        d(-3, h * 0.7, 4.2, "#5A3A9A", 3, seg=12),
        d(-9, h * 0.48, 3.2, "#7A4AB8", 3, seg=10),
        d(9, h * 0.58, 4.4, "#E8834A", 4, seg=18),
        d(9.4, h * 0.62, 3.6, "#F2A86A", 5, seg=18),
        d(8.4, h * 0.5, 2.6, "#C9653A", 6, seg=14),
        backlot_kit.dab(9, h * 0.58, 13.0, 0.9, "#F5D58C", 7, turn=-16),
        backlot_kit.dab(-10, h * 0.86, 7.0, 0.4, "Teal", 4, turn=18),
        d(-6.6, h * 0.92, 0.7, "OffWhite", 5, seg=8),
    ]
    p += stars(w, h, 2, skip=((9, h * 0.58, 7), (-6, h * 0.62, 6)))
    return backlot_kit.flat(w, h, p, base=NIGHT[2])


def moon_flat_horizon():
    """A lower side backdrop, 36 x 16: a jagged grey moon horizon with a small distant moon."""
    w, h = 36.0, 16.0
    p = night(w, h) + [backlot_kit.disc(10, h * 0.78, 2.2, PANEL, 2, seg=14), backlot_kit.disc(10.7, h * 0.82, 0.6, MOON_DARK, 3, seg=8)]
    for x, pw, ph, color in ((-12, 14, 8.5, "#7E828C"), (2, 10, 6.0, "#8E929C"), (13, 12, 7.0, "#7E828C")):
        p += [
            backlot_kit.slope(x, h * 0.3, pw / 2, ph, color, 4, False),
            backlot_kit.slope(x, h * 0.3, pw / 2, ph, shade(color, 0.12), 4, True),
        ]
    p += moon_hills(w, h * 0.3, 7, "#A7ABB4", ((-10, 1.8), (6, 2.4), (15, 1.4)))
    p += stars(w, h, 3, skip=((10, h * 0.78, 3),), z0=h * 0.62)
    return backlot_kit.flat(w, h, p, base=NIGHT[2])


def moon_ground_row():
    """A ground row: grey hills cut out of board, 24 along X, standing in front of a backdrop to hide
    where it meets the floor, with a little brace and a sandbag behind each one."""
    s = []
    for i, (x, w, h) in enumerate(((-9, 8.0, 3.0), (-1, 9.0, 4.2), (8, 9.0, 3.4))):
        tone = MOON if i % 2 else shade(MOON, 0.08)
        s += [
            B((x, 0, h * 0.35), (w, 0.3, h * 0.7), tone),
            C((x, -0.05, h * 0.62), w * 0.38, 0.3, tone, rot=(90, 0, 0), seg=10),
            B((x, 0.25, h * 0.4), (w * 0.9, 0.2, 0.25), "Plywood"),
            B((x, 0.7, h * 0.3), (0.3, 1.0, h * 0.6), "Wood", rot=(-30, 0, 0)),
            BV((x, 1.3, 0.3), (1.0, 0.8, 0.6), "Sandbag", bevel=0.2),
        ]
        s += [L((x + dx, -0.4, 0.1), (0.5, 0.3, 0.35), MOON_DARK, jitter=0.1) for dx in (-w * 0.3, w * 0.25)]
    return s


def moon_foam_rock():
    """A fake moon rock: grey-painted foam on the front, bare yellow foam and a carved flat back
    with a prop tag behind (the camera only sees the front)."""
    return [
        L((0, 0.3, 1.5), (2.5, 1.5, 1.7), FOAM, rot=(0, 0, 8), jitter=0.04),
        L((0, -0.2, 1.6), (2.7, 1.5, 1.8), MOON, rot=(0, 0, -4), jitter=0.1),
        L((1.7, -0.6, 0.8), (1.1, 0.9, 0.9), MOON_DARK, jitter=0.1),
        B((0, 1.55, 1.4), (3.4, 0.2, 2.2), shade(FOAM, 0.06)),
        B((0.6, 1.7, 2.0), (0.9, 0.06, 0.6), "OffWhite"),
        B((0.6, 1.74, 2.0), (0.5, 0.04, 0.12), "Carpet"),
        B((-1.0, 2.1, 0.9), (0.3, 1.2, 0.3), "Wood", rot=(35, 0, 0)),
    ]


def moon_buggy_hero():
    """A bigger moon buggy: four tread wheels under fenders, two seats, a control post with a TV
    camera, a big umbrella dish and a whip antenna, foil battery packs at the back."""
    s = []
    for x in (-2.6, 2.6):
        for y in (-2.7, 2.7):
            s += [
                C((x, y, 1.3), 1.3, 0.9, "#5A5A62", rot=(0, 90, 0), seg=12),
                C((x, y, 1.3), 0.6, 0.96, PANEL, rot=(0, 90, 0), seg=8),
                C((x * 1.02, y, 1.3), 0.25, 1.0, FOIL, rot=(0, 90, 0), seg=6),
                BV((x, y, 2.75), (1.2, 2.9, 0.15), "Blue", bevel=0.05),
                B((x, y - 1.5, 2.4), (1.2, 0.15, 0.7), "Blue", rot=(-30, 0, 0)),
                B((x, y + 1.5, 2.4), (1.2, 0.15, 0.7), "Blue", rot=(30, 0, 0)),
            ]
            s += [B((x, y + 1.3 * math.cos(math.radians(a)), 1.3 + 1.3 * math.sin(math.radians(a))), (0.95, 0.3, 0.2), "#3A3A42", rot=(-a + 90, 0, 0)) for a in range(0, 360, 45)]
    s += [
        BV((0, 0, 2.0), (4.4, 7.0, 0.5), PANEL, bevel=0.12),
        B((0, 0, 1.6), (1.0, 6.0, 0.4), STRUT),
        # Two seats with tall backs.
        BV((-0.95, 0.4, 2.7), (1.3, 1.4, 0.4), "Navy", bevel=0.12),
        BV((0.95, 0.4, 2.7), (1.3, 1.4, 0.4), "Navy", bevel=0.12),
        BV((-0.95, 1.1, 3.4), (1.3, 0.3, 1.4), "Navy", bevel=0.12),
        BV((0.95, 1.1, 3.4), (1.3, 0.3, 1.4), "Navy", bevel=0.12),
        # The control post with a TV camera on it.
        C((0, -1.4, 3.2), 0.12, 2.0, STRUT, seg=6),
        BV((0, -1.4, 4.4), (0.8, 0.6, 0.5), DARK, bevel=0.08),
        C((0, -1.8, 4.4), 0.2, 0.4, "Glass", rot=(90, 0, 0), seg=8),
        BV((0, -2.6, 2.55), (1.8, 1.2, 0.6), FOIL, bevel=0.1),
        B((0, -3.25, 2.55), (1.4, 0.1, 0.3), "Charcoal"),
        # Battery packs at the back, the umbrella dish and whip antenna.
        BV((0, 2.8, 2.7), (3.0, 1.2, 0.9), FOIL, bevel=0.12),
        C((-1.2, 2.9, 4.2), 0.08, 2.4, STRUT, seg=5),
        G((-1.2, 2.9, 5.3), (-20, 0, 0),
          K((0, 0, 0.3), 0.3, 1.7, 0.6, "OffWhite", seg=10),
          C((0, 0, 0.6), 1.5, 0.04, "#E8EAEE", seg=10)),
        C((1.4, 3.0, 4.5), 0.04, 3.6, STRUT, seg=4),
        E((1.4, 3.0, 6.35), (0.12, 0.12, 0.12), "Carpet", neon=True),
        E((-1.6, -3.55, 2.1), (0.3, 0.08, 0.25), "Light", neon=True),
        E((1.6, -3.55, 2.1), (0.3, 0.08, 0.25), "Light", neon=True),
    ]
    return s


def moon_flag_mark():
    """Where the flag goes in: an orange tape X with a T mark on the dust, a little dug hole and a
    spare stake. Flat enough to walk over."""
    return [
        C((0, 0, 0.08), 1.5, 0.16, MOON_DARK, seg=10),
        C((0, 0, 0.12), 0.35, 0.1, "Charcoal", seg=8),
        B((0, 0, 0.18), (3.2, 0.25, 0.03), TAPE, rot=(0, 0, 45)),
        B((0, 0, 0.18), (3.2, 0.25, 0.03), TAPE, rot=(0, 0, -45)),
        B((0, -2.2, 0.04), (1.6, 0.25, 0.03), TAPE),
        B((0, -2.8, 0.04), (0.25, 1.2, 0.03), TAPE),
        B((1.8, 1.0, 0.1), (0.2, 1.6, 0.2), "Wood", rot=(0, 0, 30)),
    ]


def moon_fake_earth():
    """A fake Earth on a C-stand, the kind you hang in front of the camera: a painted ball on an arm,
    three legs, a sandbag on one leg."""
    s = [rod((0, 0, 1.2), (1.6 * math.sin(a), 1.6 * math.cos(a), 0.05), 0.1, STRUT, seg=5) for a in (0.5, 2.6, 4.7)]
    s += [
        C((0, 0, 3.4), 0.14, 6.4, STRUT, seg=6),
        C((0, 0, 6.4), 0.22, 0.4, "Charcoal", seg=8),
        rod((0, 0, 6.4), (2.6, -0.6, 6.9), 0.1, STRUT, seg=5),
        E((3.2, -0.8, 7.0), (1.6, 1.6, 1.6), "Blue"),
        L((3.0, -1.9, 7.5), (0.8, 0.55, 0.6), "Green", jitter=0.08),
        L((4.2, -1.5, 6.4), (0.6, 0.55, 0.7), "Green", jitter=0.08),
        L((2.5, -1.1, 8.3), (0.7, 0.5, 0.25), "OffWhite", jitter=0.04),
        BV((1.6 * math.sin(0.5) * 0.8, 1.6 * math.cos(0.5) * 0.8, 0.35), (0.9, 1.3, 0.6), "#B5A27A", rot=(0, 0, -28), bevel=0.25),
    ]
    return s


def moon_prop_cart():
    """A rolling prop cart for the set: two shelves with a spare helmet, oxygen tanks, a hose coil,
    a PROPS crate and a push handle."""
    s = [C((x, y, 0.35), 0.35, 0.3, "Charcoal", rot=(0, 90, 0), seg=8) for x in (-1.9, 1.9) for y in (-1.0, 1.0)]
    s += [B((x, y, 2.0), (0.2, 0.2, 2.8), STRUT) for x in (-2.0, 2.0) for y in (-1.1, 1.1)]
    s += [BV((0, 0, z), (4.4, 2.6, 0.2), "Steel", bevel=0.05) for z in (1.0, 3.3)]
    s += [
        rod((2.0, -1.1, 3.4), (2.6, -1.1, 4.4), 0.08, STRUT, seg=5),
        rod((2.0, 1.1, 3.4), (2.6, 1.1, 4.4), 0.08, STRUT, seg=5),
        C((2.6, 0, 4.4), 0.1, 2.3, "Carpet", rot=(90, 0, 0), seg=6),
        # Top shelf: a helmet with a gold visor and two tanks lying down.
        E((-1.0, 0, 4.25), (0.85, 0.85, 0.8), "OffWhite"),
        E((-1.0, -0.45, 4.3), (0.6, 0.45, 0.45), FOIL),
        C((-1.0, 0, 3.5), 0.75, 0.2, STRUT, seg=10),
        C((0.9, -0.5, 3.8), 0.4, 2.0, "OffWhite", rot=(0, 90, 0), seg=8),
        C((0.9, 0.45, 3.8), 0.4, 2.0, "OffWhite", rot=(0, 90, 0), seg=8),
        C((1.95, -0.5, 3.8), 0.2, 0.2, "Carpet", rot=(0, 90, 0), seg=6),
        C((1.95, 0.45, 3.8), 0.2, 0.2, "Carpet", rot=(0, 90, 0), seg=6),
        # Bottom shelf: a PROPS crate and a coiled hose.
        BV((-0.8, 0, 1.75), (2.0, 1.8, 1.3), "Wood", bevel=0.1),
        B((-0.8, -0.92, 1.75), (1.4, 0.05, 0.4), "OffWhite"),
        C((1.2, 0, 1.3), 0.8, 0.4, "Charcoal", seg=10),
        C((1.2, 0, 1.35), 0.4, 0.45, "Steel", seg=8),
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
    ("MoonRocketPad", moon_rocket_pad),
    ("MoonLanderHero", moon_lander_hero),
    ("MoonHabitat", moon_habitat),
    ("MoonSupplyCrates", moon_supply_crates),
    ("MoonCraterSmall", lambda: crater(3.0, 10)),
    ("MoonCraterMid", lambda: crater(6.0, 14)),
    ("MoonCraterBig", lambda: crater(11.0, 18)),
    ("MoonRegolith", moon_regolith),
    ("MoonDuneEdge", moon_dune_edge),
    ("MoonBoulders", moon_boulders),
    ("MoonPebbles", moon_pebbles),
    ("MoonTracks", moon_tracks),
    ("MoonFootprints", moon_footprints),
    ("MoonFlatEarthrise", moon_flat_earthrise),
    ("MoonFlatStarfield", moon_flat_starfield),
    ("MoonFlatHorizon", moon_flat_horizon),
    ("MoonGroundRow", moon_ground_row),
    ("MoonFoamRock", moon_foam_rock),
    ("MoonBuggyHero", moon_buggy_hero),
    ("MoonFlagMark", moon_flag_mark),
    ("MoonFakeEarth", moon_fake_earth),
    ("MoonPropCart", moon_prop_cart),
]

# Sunk into the ground: the domes are the top half of a ball, the ground pieces are flat blobs
# mostly below the floor, so their edges melt into it.
NO_LIFT = {"MoonDome", "MoonHabitat", "MoonRegolith", "MoonDuneEdge"}

LINEUPS = {
    "space_kit.png": (["MoonLander", "MoonRock", "MoonCrater", "MoonBuggy", "MoonDome"], ["MoonRocket", "SpaceBackdrop"]),
    "space_kit_hero.png": ([], ["MoonRocketPad", "MoonHabitat"]),
    "space_kit_props.png": ([], ["MoonLanderHero", "MoonBuggyHero", "MoonFakeEarth", "MoonPropCart", "MoonSupplyCrates", "MoonFoamRock"]),
    "space_kit_ground.png": (["MoonCraterSmall", "MoonCraterMid", "MoonBoulders", "MoonPebbles", "MoonFlagMark", "MoonTracks", "MoonFootprints"],
                             ["MoonCraterBig", "MoonRegolith", "MoonDuneEdge"]),
    "space_kit_backdrop.png": (["MoonGroundRow", "MoonFlatHorizon"], ["MoonFlatStarfield", "MoonFlatEarthrise", "MoonFlatEarthrise@180"]),
}
