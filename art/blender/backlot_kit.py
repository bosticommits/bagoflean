"""Backlot kit: the studio dressing that makes a film set read as an open backlot set, not props on
a pad. map_kit.py builds these into the one map_kit.fbx and the one MapKitShapes.luau with the
rest of the map kit, so run that file, not this one. Each set places them from a gear list in its
own TownSets function (TownSets.filmSetGear, with `loose` so they don't collide).

  Fence     BacklotFence (a 12-stud run of chain link hung with green screen mesh, a post at each
            end, along X), BacklotFenceSign (the same with a studio banner: spot Sign),
            BacklotFencePost (a capped corner or end post)
  Flats     BacklotFlatDesert (painted desert sky and mesas, 40 x 22), BacklotFlatTrail (a trail
            running off between buttes, 44 x 18), BacklotBrace (one triangular jack with its
            sandbag, to prop the back of anything). Built by flat() below, which other kits import
            to paint their own flats with the same frame, jacks and sandbags.
  Lights    BacklotTrussTower (a 24-stud box truss with a bar of three lamps), BacklotScaffold (a
            pipe scaffold tower with two lamps on its top rail), BacklotGroundLight (a big fresnel
            on a roller stand), BacklotCStand (a C-stand holding a black flag), BacklotScrim (a
            silk on a frame between two stands). The lamps shine toward -Y, tilted down.
  Cables    BacklotCable (8 studs along X), BacklotCableBend (a quarter turn: in along +X at the
            origin, out along +Y at (3, 3)), BacklotCableRamp (a yellow crossover, cable along X),
            BacklotCableCoil, BacklotGenerator (a tow generator the cables start from)
  Gear      BacklotCase (a road case), BacklotCaseStack, BacklotCart (a grip cart)
  Crew area BacklotCraftTent (a canopy over a snack table with a coffee urn, and a cooler: spot
            Sign), BacklotVideoVillage (a monitor cart with two monitors under a big umbrella),
            BacklotAppleBoxes, BacklotScriptTable
  Ground    BacklotBerm (a low drift of sand, 12 along X), BacklotClump (rocks and dry grass), both
            sunk into the ground so set pieces sit in the dirt instead of on it

Chunky low-poly toy style (ART_STYLE.md), the game palette. Blender axes, in studs: Z up, the
model faces -Y, standing on Z = 0.
"""

import math

from kitdsl import B, C, G, K, L, S, T, W, ring  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.12, neon=False):
    return B(at, size, color, rot, bevel, neon)


PIPE = "#C9CDD4"  # aluminium truss and scaffold pipe
CASE = "#34323A"  # road case black
CABLE = "#1F1E24"
STINGER = "#FF8C28"  # the orange extension cable beside the black one
SKY = "#8CCBF2"
SKY_DEEP = "#5AA8EC"
HAZE = "#FBE3B4"


# --- Fence -------------------------------------------------------------------------------------

FENCE_W = 12.0
FENCE_H = 7.0


def fence(sign):
    """12 studs of chain link along X, hung with green mesh on the -Y side (the inside of the lot)."""
    w, h = FENCE_W, FENCE_H
    s = [
        B((0, -0.05, h / 2 + 0.2), (w, 0.16, h - 0.9), "MeshGreen"),
        B((0, -0.14, h - 0.55), (w, 0.04, 0.22), "OffWhite"),
        B((0, 0.05, h / 2 + 0.2), (w - 0.4, 0.06, h - 1.0), "#8E949C"),
        B((0, 0, h - 0.1), (w, 0.3, 0.3), PIPE),
        B((0, 0, 0.45), (w, 0.26, 0.26), PIPE),
    ]
    for x in (-w / 2, w / 2):
        s += [
            C((x, 0, h / 2), 0.28, h + 0.3, PIPE, seg=8),
            BV((x, 0, 0.25), (1.2, 1.2, 0.5), "Charcoal", bevel=0.1),
        ]
    if sign:
        s += [
            BV((0, -0.25, h * 0.55), (7.4, 0.2, 2.4), "Navy", bevel=0.06),
            B((0, -0.37, h * 0.55), (7.0, 0.06, 2.0), "OffWhite"),
            T((0, -0.41, h * 0.55), (6.8, 0.05, 1.8), "Sign"),
            S((-4.4, -0.3, h * 0.55), 0.8, 0.2, "Gold"),
            S((4.4, -0.3, h * 0.55), 0.8, 0.2, "Gold"),
        ]
    else:
        # The studio's stencil: a gold star in a white roundel on the mesh.
        s += [
            C((0, -0.16, h * 0.55), 1.2, 0.06, "OffWhite", rot=(90, 0, 0), seg=12),
            S((0, -0.2, h * 0.55), 0.85, 0.08, "Gold"),
        ]
    return s


def fence_post():
    h = FENCE_H
    return [
        BV((0, 0, h / 2 + 0.2), (0.9, 0.9, h + 0.4), PIPE, bevel=0.15),
        BV((0, 0, h + 0.55), (1.2, 1.2, 0.3), "Charcoal", bevel=0.08),
        BV((0, 0, 0.3), (1.6, 1.6, 0.6), "Charcoal", bevel=0.12),
        B((0, 0, h * 0.55), (0.95, 0.95, 0.5), "Gold"),
    ]


# --- Flats -------------------------------------------------------------------------------------
# A flat is a painted plywood wall that only has a front: a timber frame skinned with plywood,
# painted on the -Y face, and held up from behind by triangular jacks with a sandbag on each.

FACE = -0.3  # the front of a flat's skin


def dab(x, z, w, h, color, layer=1, turn=0):
    """A patch of paint on a flat's face, centred at (x, z) (x across, z up from the ground).
    Higher layers sit in front of lower ones."""
    return B((x, FACE - 0.04 * layer + 0.01, z), (w, 0.04, h), color, rot=(0, turn, 0))


def disc(x, z, r, color, layer=1, seg=16):
    """A round patch of paint (a sun, a moon, a planet)."""
    return C((x, FACE - 0.04 * layer + 0.01, z), r, 0.04, color, rot=(90, 0, 0), seg=seg)


def jack(x, height, depth=None):
    """A triangular brace behind a flat at x: an upright against the back, a diagonal down to a
    ground rail, and a sandbag weighing the rail down."""
    d = depth or max(3.0, height * 0.36)
    top = height * 0.8
    run = math.hypot(d, top)
    lean = math.degrees(math.atan2(d, top))
    return [
        B((x, 0.7, height / 2), (0.7, 0.6, height), "Wood"),
        B((x, 0.4 + d / 2, top / 2), (0.6, 0.6, run), "Wood", rot=(lean, 0, 0)),
        B((x, 0.4 + d / 2, 0.25), (0.7, d, 0.5), "Wood"),
        B((x, 0.4 + d * 0.3, top * 0.3), (0.5, d * 0.62, 0.4), "Wood"),
        BV((x, 0.4 + d * 0.78, 0.75), (1.8, 1.4, 0.9), "Sandbag", bevel=0.3),
        BV((x + 0.3, 0.4 + d * 0.55, 0.6), (1.5, 1.2, 0.7), "Sandbag", bevel=0.25, rot=(0, 0, 25)),
    ]


def flat(width, height, paint, base=SKY, jacks=None):
    """A painted flat `width` x `height` standing on the ground, face toward -Y. `paint` is a list
    of shapes made with dab() and disc(); `base` is the face's own color. Jacks go roughly every
    10 studs unless `jacks` lists their x."""
    zc = height / 2
    s = [
        B((0, 0, zc), (width, 0.6, height), base),
        B((0, 0.2, zc), (width - 0.2, 0.4, height - 0.2), "Plywood"),
        # The frame round the face, and the timber frame seen from behind: stiles and toggles.
        B((0, -0.1, height - 0.2), (width + 0.4, 0.6, 0.5), "Wood"),
        B((0, -0.1, 0.25), (width + 0.4, 0.6, 0.5), "Wood"),
        B((-width / 2, -0.1, zc), (0.5, 0.6, height), "Wood"),
        B((width / 2, -0.1, zc), (0.5, 0.6, height), "Wood"),
    ]
    for z in (height * 0.36, height * 0.68):
        s.append(B((0, 0.45, z), (width, 0.35, 0.4), "Wood"))
    n = jacks if jacks is not None else [-width / 2 + 2 + i * (width - 4) / max(1, round(width / 10) - 1) for i in range(max(2, round(width / 10)))]
    for x in n:
        s += jack(x, height)
    return s + paint


def slope(x, z, w, h, color, layer, right):
    """A right-angled triangle of paint, its tall side at x, sloping down away from it (toward +x
    when `right`)."""
    return W((x + (w / 2 if right else -w / 2), FACE - 0.04 * layer + 0.01, z), (0.04, w, h), color, rot=(0, 0, -90 if not right else 90))


def mesa_paint(x, w, h, z0, layer, light, mid, dark):
    """A painted butte: a flat-topped block on talus slopes, lit from the left, with a striped
    face and a pale cap."""
    body = w * 0.6
    return [
        dab(x, z0 + h * 0.46, body, h * 0.92, mid, layer),
        slope(x - body / 2, z0 + h * 0.3, w * 0.2, h * 0.6, mid, layer, False),
        slope(x + body / 2, z0 + h * 0.3, w * 0.2, h * 0.6, dark, layer, True),
        dab(x + body * 0.32, z0 + h * 0.46, body * 0.36, h * 0.92, dark, layer + 1),
        dab(x, z0 + h * 0.62, body, h * 0.06, light, layer + 2),
        dab(x, z0 + h * 0.4, body, h * 0.05, light, layer + 2),
        dab(x, z0 + h * 0.93, body + 0.8, h * 0.1, light, layer + 2),
    ]


def cactus_paint(x, z0, h, layer):
    return [
        dab(x, z0 + h * 0.42, h * 0.5, h * 0.12, "CactusDark", layer),
        dab(x, z0 + h / 2, h * 0.2, h, "Cactus", layer + 1),
        dab(x - h * 0.22, z0 + h * 0.55, h * 0.16, h * 0.4, "Cactus", layer + 1),
        dab(x + h * 0.22, z0 + h * 0.7, h * 0.16, h * 0.36, "Cactus", layer + 1),
    ]


def cloud_paint(x, z, w, layer):
    return [
        dab(x, z, w, w * 0.18, "OffWhite", layer),
        dab(x - w * 0.1, z + w * 0.12, w * 0.5, w * 0.16, "OffWhite", layer + 1),
        dab(x + w * 0.2, z + w * 0.07, w * 0.35, w * 0.14, "OffWhite", layer + 2),
    ]


def flat_desert():
    """Big western sky over a row of buttes, a low sun and painted saguaros: the Gulch's horizon."""
    w, h = 40.0, 22.0
    p = [
        dab(0, h * 0.84, w, h * 0.32, SKY_DEEP, 1),
        dab(0, h * 0.36, w, h * 0.16, HAZE, 1),
        disc(9, h * 0.62, 3.6, "#FFF0C0", 2),
        disc(9, h * 0.62, 2.6, "#FFD25A", 3),
    ]
    p += cloud_paint(-11, h * 0.8, 9, 2) + cloud_paint(14, h * 0.88, 6, 2)
    p += mesa_paint(-12, 14, 9.5, h * 0.24, 5, "RockLight", "Rock", "RockDark")
    p += mesa_paint(2, 9, 6.0, h * 0.24, 5, "#F2B486", "RockLight", "Rock")
    p += mesa_paint(15, 12, 8.0, h * 0.24, 5, "RockLight", "Rock", "RockDark")
    p += [
        dab(0, h * 0.14, w, h * 0.26, "Sand", 9),
        dab(-6, h * 0.08, w * 0.5, 0.5, "Dust", 10),
        dab(10, h * 0.18, w * 0.35, 0.5, "Dust", 10),
    ]
    p += cactus_paint(-16, h * 0.1, 6, 11) + cactus_paint(5, h * 0.14, 4, 11) + cactus_paint(17, h * 0.08, 5, 11)
    return flat(w, h, p)


def flat_trail():
    """A dusty trail running off to the horizon between two buttes: for the end of a street."""
    w, h = 44.0, 18.0
    hz = h * 0.42  # the horizon
    p = [
        dab(0, h * 0.86, w, h * 0.28, SKY_DEEP, 1),
        dab(0, hz + 1.2, w, 2.4, HAZE, 1),
        disc(-4, hz + 5.5, 2.4, "#FFD25A", 2),
    ]
    p += cloud_paint(10, h * 0.82, 8, 2) + cloud_paint(-15, h * 0.78, 6, 2)
    p += mesa_paint(-15, 15, 8.5, hz, 5, "RockLight", "Rock", "RockDark")
    p += mesa_paint(15, 13, 7.0, hz, 5, "RockLight", "Rock", "RockDark")
    p += [
        dab(0, hz / 2, w, hz, "Sand", 9),
        # The trail: a strip narrowing to a point on the horizon, with ruts down it.
        dab(0, hz / 2, 1.2, hz, "Dust", 10),
        slope(-0.6, hz / 2, 6.4, hz, "Dust", 10, False),
        slope(0.6, hz / 2, 6.4, hz, "Dust", 10, True),
        slope(-1.6, hz * 0.3, 2.2, hz * 0.6, "#D49A60", 11, False),
        slope(1.6, hz * 0.3, 2.2, hz * 0.6, "#D49A60", 11, True),
    ]
    p += cactus_paint(-11, hz * 0.1, 5, 11) + cactus_paint(12, hz * 0.2, 4, 11)
    return flat(w, h, p)


def brace():
    """One jack on its own, 14 tall: props up the back of a false front."""
    return jack(0, 14.0)


# --- Lights ------------------------------------------------------------------------------------


def lamp(at, tilt=28, size=1.0):
    """A studio lamp head facing -Y, tilted down by `tilt`, on a yoke: housing, lit lens, barn doors."""
    k = size
    return G(
        at, (tilt, 0, 0),
        BV((0, 0.2, 0), (2.0 * k, 1.8 * k, 1.8 * k), "Charcoal", bevel=0.18),
        B((0, -0.75 * k, 0), (1.6 * k, 0.1, 1.4 * k), "Light", neon=True),
        B((-1.1 * k, -1.05 * k, 0), (0.1, 0.7 * k, 1.6 * k), "Charcoal", rot=(0, 0, 28)),
        B((1.1 * k, -1.05 * k, 0), (0.1, 0.7 * k, 1.6 * k), "Charcoal", rot=(0, 0, -28)),
        B((0, -1.05 * k, 1.05 * k), (1.8 * k, 0.7 * k, 0.1), "Charcoal", rot=(-28, 0, 0)),
        B((0, 1.2 * k, 0), (0.8 * k, 0.4, 0.8 * k), "#4A4A52"),
    )


def truss_tower():
    """A 24-stud box truss on a weighted base, a lamp bar of three lamps across its top."""
    h, a = 24.0, 1.2
    bays, bay = 6, 3.8
    diag = math.hypot(2 * a, bay)
    s = [
        BV((0, 0, 0.25), (4.6, 4.6, 0.5), "Charcoal", bevel=0.1),
    ]
    for x in (-a, a):
        for y in (-a, a):
            s.append(B((x, y, h / 2), (0.5, 0.5, h), PIPE))
    for k in range(bays + 1):
        z = 1.0 + k * bay
        s += [
            B((0, -a, z), (2 * a, 0.3, 0.3), PIPE),
            B((0, a, z), (2 * a, 0.3, 0.3), PIPE),
            B((-a, 0, z), (0.3, 2 * a, 0.3), PIPE),
            B((a, 0, z), (0.3, 2 * a, 0.3), PIPE),
        ]
        if k == bays:
            break
        # Zig-zag diagonals on the front and the sides.
        lean = math.degrees(math.atan2(2 * a, bay)) * (1 if k % 2 == 0 else -1)
        s += [
            B((0, -a, z + bay / 2), (0.26, 0.26, diag), PIPE, rot=(0, lean, 0)),
            B((-a, 0, z + bay / 2), (0.26, 0.26, diag), PIPE, rot=(-lean, 0, 0)),
            B((a, 0, z + bay / 2), (0.26, 0.26, diag), PIPE, rot=(lean, 0, 0)),
        ]
    s += [
        # The lamp bar: a short horizontal truss, three lamps hanging off its front.
        BV((0, 0, h + 0.3), (3.2, 3.2, 0.6), "Charcoal", bevel=0.1),
        B((0, -0.7, h + 1.5), (11.0, 0.45, 0.45), PIPE),
        B((0, 0.7, h + 1.5), (11.0, 0.45, 0.45), PIPE),
        B((0, 0, h + 2.7), (11.0, 0.45, 0.45), PIPE),
        lamp((-3.9, -1.9, h + 0.5), 30, 1.25),
        lamp((0, -1.9, h + 0.5), 30, 1.25),
        lamp((3.9, -1.9, h + 0.5), 30, 1.25),
    ]
    for x in (-1.9, 1.9):
        s.append(BV((x, 2.4, 0.6), (1.4, 1.6, 0.7), "Sandbag", bevel=0.25))
    s.append(BV((-2.4, -1.4, 0.6), (1.6, 1.4, 0.7), "Sandbag", bevel=0.25, rot=(0, 0, 70)))
    return s


def scaffold():
    """A two-lift pipe scaffold, 6 x 4, plank decks, a ladder up the side, two lamps on the top
    rail and a black flag."""
    w, d, h = 6.0, 4.0, 12.0
    s = []
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            s += [
                B((x, y, h / 2 + 1.5), (0.42, 0.42, h + 3.0), PIPE),
                B((x, y, 0.1), (0.9, 0.9, 0.2), "Charcoal"),
            ]
    for z in (0.8, 6.0, h, h + 2.8):
        s += [
            B((0, -d / 2, z), (w, 0.3, 0.3), PIPE),
            B((0, d / 2, z), (w, 0.3, 0.3), PIPE),
            B((-w / 2, 0, z), (0.3, d, 0.3), PIPE),
            B((w / 2, 0, z), (0.3, d, 0.3), PIPE),
        ]
    # Cross bracing on the back and both ends.
    for z0, z1 in ((0.8, 6.0), (6.0, h)):
        zm, run = (z0 + z1) / 2, z1 - z0
        s += [
            B((0, d / 2, zm), (0.26, 0.26, math.hypot(w, run)), PIPE, rot=(0, math.degrees(math.atan2(w, run)), 0)),
            B((-w / 2, 0, zm), (0.26, 0.26, math.hypot(d, run)), PIPE, rot=(math.degrees(math.atan2(d, run)), 0, 0)),
            B((w / 2, 0, zm), (0.26, 0.26, math.hypot(d, run)), PIPE, rot=(-math.degrees(math.atan2(d, run)), 0, 0)),
        ]
    for z in (6.0, h):
        s += [
            BV((0, 0, z + 0.25), (w + 0.4, d + 0.2, 0.3), "Plywood", bevel=0.06),
            B((0, -d / 2 - 0.05, z + 0.6), (w, 0.1, 0.5), "Gold"),
        ]
    # The ladder up the +X end.
    for y in (-0.6, 0.6):
        s.append(B((w / 2 + 0.4, y, h / 2), (0.24, 0.24, h), "Gold"))
    for k in range(7):
        s.append(B((w / 2 + 0.4, 0, 1.0 + k * 1.7), (0.22, 1.2, 0.22), "Gold"))
    s += [
        lamp((-1.6, -d / 2 - 0.9, h + 2.0), 32, 1.2),
        lamp((1.6, -d / 2 - 0.9, h + 2.0), 32, 1.2),
        # A black flag on an arm off the -X corner, cutting the spill.
        B((-w / 2 - 1.5, -d / 2, h + 3.4), (3.0, 0.15, 0.15), PIPE),
        BV((-w / 2 - 2.6, -d / 2, h + 2.2), (2.2, 0.15, 2.4), "Charcoal", bevel=0.05),
        BV((0, 0, h + 0.8), (2.4, 1.6, 1.0), CASE, bevel=0.15),
    ]
    return s


def ground_light():
    """A big fresnel on a wheeled roller stand, aimed toward -Y and a little up."""
    s = [
        C((0, 0, 3.0), 0.25, 4.4, PIPE, seg=8),
        C((0, 0, 1.4), 0.4, 1.4, "Charcoal", seg=8),
        B((0, 0, 5.2), (3.6, 0.3, 0.3), "Charcoal"),
        B((-1.7, 0, 5.9), (0.3, 0.3, 1.6), "Charcoal"),
        B((1.7, 0, 5.9), (0.3, 0.3, 1.6), "Charcoal"),
        G(
            (0, 0, 6.1), (-8, 0, 0),
            C((0, 0.4, 0), 1.45, 2.6, "Charcoal", rot=(90, 0, 0), seg=12),
            C((0, -0.95, 0), 1.2, 0.12, "Light", rot=(90, 0, 0), seg=12, neon=True),
            C((0, 1.8, 0), 1.0, 0.4, "#4A4A52", rot=(90, 0, 0), seg=10),
            B((0, 0.4, 1.55), (0.8, 1.4, 0.3), "Charcoal"),
            B((-1.6, -1.25, 0), (0.1, 0.8, 2.2), "Charcoal", rot=(0, 0, 25)),
            B((1.6, -1.25, 0), (0.1, 0.8, 2.2), "Charcoal", rot=(0, 0, -25)),
        ),
    ]
    for a in (0, 120, 240):
        r = math.radians(a)
        x, y = math.sin(r) * 1.8, math.cos(r) * 1.8
        s += [
            B((x / 2, y / 2, 0.75), (0.3, 1.9, 0.3), PIPE, rot=(0, 0, -a)),
            C((x, y, 0.35), 0.35, 0.3, "Charcoal", rot=(0, 90, 0), seg=8),
        ]
    return s


def c_stand():
    """A C-stand: a staggered three-leg base, a riser, a grip arm and a black flag."""
    s = [
        C((0, 0, 3.0), 0.12, 6.0, PIPE, seg=6),
        C((0, 0, 0.9), 0.22, 1.8, "Steel", seg=6),
        BV((0, 0, 5.4), (0.5, 0.5, 0.5), "Charcoal", bevel=0.08),
        B((-1.3, -0.4, 5.4), (3.2, 0.14, 0.14), "Steel", rot=(0, 0, -18)),
        BV((-2.4, -1.3, 4.6), (2.8, 0.12, 2.4), "Charcoal", bevel=0.04, rot=(0, 0, -18)),
        BV((0.8, 0.4, 0.45), (1.3, 1.0, 0.6), "Sandbag", bevel=0.2),
    ]
    for a, z in ((0, 0.2), (120, 0.45), (240, 0.7)):
        r = math.radians(a)
        s.append(B((math.sin(r) * 0.9, math.cos(r) * 0.9, z), (0.16, 1.8, 0.16), "Steel", rot=(0, 0, -a)))
    return s


def scrim():
    """An 8 x 6 silk on a frame between two stands, softening the sun on the actors."""
    s = [
        BV((0, 0, 5.0), (8.0, 0.1, 5.2), "OffWhite", bevel=0.03),
        B((0, 0, 7.7), (8.4, 0.24, 0.24), PIPE),
        B((0, 0, 2.3), (8.4, 0.24, 0.24), PIPE),
    ]
    for x in (-4.1, 4.1):
        s += [
            B((x, 0, 4.4), (0.24, 0.24, 8.0), PIPE),
            BV((x, 0, 0.2), (1.8, 1.2, 0.3), "Charcoal", bevel=0.08),
            BV((x, 0.9, 0.45), (1.2, 1.0, 0.6), "Sandbag", bevel=0.2),
        ]
    return s


# --- Cables ------------------------------------------------------------------------------------


def cable():
    """8 studs of cable along X: a heavy black feeder with an orange stinger beside it."""
    return [
        C((0, 0, 0.32), 0.32, 8.0, CABLE, rot=(0, 90, 0), seg=6),
        C((0, 0.75, 0.2), 0.2, 8.0, STINGER, rot=(0, 90, 0), seg=6),
    ]


def cable_bend():
    """A quarter turn, radius 3: in along +X at the origin, out along +Y at (3, 3)."""
    s = []
    for k in range(4):
        a = math.radians(11.25 + k * 22.5)
        for r, rad, color in ((3.0, 0.32, CABLE), (2.25, 0.2, STINGER)):
            x, y = math.sin(a) * r, 3.0 - math.cos(a) * r
            s.append(C((x, y, rad), rad, r * 0.41, color, rot=(0, 90, math.degrees(a)), seg=6))
    return s


def cable_ramp():
    """A yellow cable crossover: the cables run along X through it, people step across along Y."""
    s = [
        BV((0, 0, 0.3), (2.8, 2.4, 0.6), "Gold", bevel=0.08),
        W((0, -1.9, 0.3), (2.8, 1.4, 0.6), "Gold", rot=(0, 0, 0)),
        W((0, 1.9, 0.3), (2.8, 1.4, 0.6), "Gold", rot=(0, 0, 180)),
    ]
    for y in (-0.6, 0.6):
        s.append(B((0, y, 0.62), (2.84, 0.5, 0.06), "Charcoal"))
    return s


def cable_coil():
    """A coil of cable lying on the ground, its end trailing off along +X."""
    s = []
    for layer, r in enumerate((1.4, 1.25, 1.35)):
        s += ring(10, r, 0.22 + layer * 0.3, lambda x, y, a, z=0.22 + layer * 0.3, r=r: B((x, y, z), (0.95, 0.46, 0.46), CABLE, rot=(0, 0, -a)))
    s += [
        C((2.6, -1.3, 0.28), 0.28, 2.6, CABLE, rot=(0, 90, 0), seg=6),
        BV((3.8, -1.3, 0.3), (0.6, 0.5, 0.5), STINGER, bevel=0.08),
    ]
    return s


def generator():
    """A tow generator: a yellow box on two wheels with a tow bar toward -Y, an exhaust stack and
    a panel of outlets on the +X side."""
    s = [
        BV((0, 0, 3.0), (4.4, 8.4, 3.6), "Gold", bevel=0.35),
        B((0, 0, 1.15), (4.5, 8.2, 0.5), "Charcoal"),
        BV((0, 0.4, 4.95), (4.0, 6.8, 0.4), "#E0A020", bevel=0.12),
        C((1.2, 3.0, 5.9), 0.3, 2.2, "Charcoal", seg=8),
        B((2.25, 1.0, 3.0), (0.1, 3.0, 2.0), "Charcoal"),
        B((2.32, 1.0, 3.0), (0.1, 2.6, 0.3), "OffWhite"),
        B((-2.25, -1.0, 3.2), (0.1, 4.0, 1.6), "Charcoal"),
        B((0, -4.25, 3.4), (3.6, 0.1, 0.5), "Charcoal"),
        BV((0, -5.6, 1.0), (0.4, 3.4, 0.4), "Charcoal", bevel=0.08),
        C((0, -7.2, 0.5), 0.35, 1.0, "Steel", seg=8),
    ]
    for k in range(3):
        s.append(BV((2.4, 0.2 + k * 0.9, 2.6), (0.4, 0.5, 0.5), STINGER if k == 1 else CABLE, bevel=0.06))
    for x in (-2.4, 2.4):
        s += [C((x, 0.5, 1.2), 1.2, 0.7, "Charcoal", rot=(0, 90, 0), seg=12), C((x * 1.02, 0.5, 1.2), 0.5, 0.74, "Steel", rot=(0, 90, 0), seg=8)]
    return s


# --- Gear --------------------------------------------------------------------------------------


def road_case(at=(0, 0, 0), size=(3.0, 2.0, 2.0), turn=0, label="OffWhite"):
    """A black road case with aluminium edges and a label, on casters."""
    x, y, z = at
    w, d, h = size
    zc = z + 0.3 + h / 2
    body = [
        BV((0, 0, 0), (w, d, h), CASE, bevel=0.1),
        B((0, 0, h * 0.18), (w + 0.06, d + 0.06, 0.16), PIPE),
        B((0, -d / 2 - 0.04, h * 0.05), (w * 0.4, 0.06, h * 0.3), label),
    ]
    for sx in (-1, 1):
        for sy in (-1, 1):
            body.append(B((sx * (w / 2 - 0.15), sy * (d / 2 - 0.15), 0), (0.36, 0.36, h + 0.06), PIPE))
    for sx in (-1, 1):
        body.append(B((sx * w * 0.25, -d / 2 - 0.06, h * 0.32), (0.3, 0.08, 0.2), "Gold"))
    parts = [G((x, y, zc), (0, 0, turn), *body)]
    if z == 0:
        for sx in (-1, 1):
            for sy in (-1, 1):
                parts.append(G((x, y, 0), (0, 0, turn), C((sx * (w / 2 - 0.4), sy * (d / 2 - 0.4), 0.15), 0.15, 0.25, "Charcoal", rot=(0, 90, 0), seg=6)))
    return parts


def case():
    return road_case()


def case_stack():
    return (
        road_case((0, 0, 0), (4.0, 2.6, 2.4))
        + road_case((-0.2, 0.1, 2.7), (3.2, 2.2, 1.8), turn=8, label="Gold")
        + road_case((0.3, 0, 4.5), (2.2, 1.6, 1.2), turn=-10)
        + road_case((3.6, 0.2, 0), (2.4, 2.0, 2.0), turn=-14, label="Carpet")
    )


def cart():
    """A grip cart: two shelves on casters with a push bar, sandbags, an apple box, stands and
    a spare lamp."""
    s = [
        BV((0, 0, 0.9), (5.0, 2.6, 0.3), CASE, bevel=0.06),
        BV((0, 0, 3.0), (5.0, 2.6, 0.3), CASE, bevel=0.06),
        BV((-2.6, 0, 3.8), (0.25, 2.4, 0.25), PIPE, bevel=0.05),
        BV((1.4, 0, 1.4), (1.8, 1.3, 0.7), "Sandbag", bevel=0.25),
        BV((-0.6, 0.3, 1.4), (1.6, 1.3, 0.7), "Sandbag", bevel=0.25),
        BV((-1.2, 0, 3.75), (1.8, 1.4, 1.2), "Plywood", bevel=0.08),
        B((-1.2, -0.72, 3.75), (0.9, 0.06, 0.3), "Bark"),
        lamp((1.3, 0, 3.95), -6, 0.6),
    ]
    for x in (-2.4, 2.4):
        for y in (-1.2, 1.2):
            s += [B((x, y, 2.0), (0.2, 0.2, 2.6), PIPE), C((x, y, 0.3), 0.3, 0.3, "Charcoal", rot=(0, 90, 0), seg=8)]
    for k in range(3):
        s.append(B((0.2, -0.6 + k * 0.6, 3.35), (5.4, 0.12, 0.12), "Steel"))
    return s


# --- Crew area ---------------------------------------------------------------------------------


def craft_tent():
    """Craft services: a 10 x 8 pop-up canopy in red and white over a snack table (tablecloth, a
    coffee urn, cups, a box of donuts, fruit) and a cooler. Spot: Sign (the valance front)."""
    w, d, h = 10.0, 8.0, 7.0
    s = [
        # The canopy roof: a low pyramid, then a striped valance round the edge.
        K((0, 0, h + 0.9), 7.2, 0.4, 1.8, "Carpet", rot=(0, 0, 45), seg=4),
        B((0, 0, h + 0.05), (w, d, 0.1), "OffWhite"),
    ]
    n = 6
    for i in range(n):
        col = "Carpet" if i % 2 == 0 else "OffWhite"
        s += [
            B((-w / 2 + (i + 0.5) * w / n, -d / 2, h - 0.35), (w / n, 0.12, 0.7), col),
            B((-w / 2 + (i + 0.5) * w / n, d / 2, h - 0.35), (w / n, 0.12, 0.7), col),
        ]
    for i in range(4):
        col = "OffWhite" if i % 2 == 0 else "Carpet"
        s += [
            B((-w / 2, -d / 2 + (i + 0.5) * d / 4, h - 0.35), (0.12, d / 4, 0.7), col),
            B((w / 2, -d / 2 + (i + 0.5) * d / 4, h - 0.35), (0.12, d / 4, 0.7), col),
        ]
    s += [
        BV((0, -d / 2 - 0.12, h - 0.35), (5.6, 0.1, 0.9), "OffWhite", bevel=0.03),
        T((0, -d / 2 - 0.2, h - 0.35), (5.4, 0.05, 0.8), "Sign"),
    ]
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            s += [B((x, y, h / 2), (0.3, 0.3, h), PIPE), BV((x, y, 0.3), (1.1, 0.9, 0.6), "Sandbag", bevel=0.2)]
    # The table, its cloth and the spread.
    t = 2.6
    s += [
        BV((0, 0.6, t), (7.0, 2.4, 0.2), "OffWhite", bevel=0.05),
        B((0, -0.62, t - 0.5), (7.0, 0.06, 1.0), "Carpet"),
        B((-3.2, 0.6, t / 2), (0.2, 2.0, t), "Steel"),
        B((3.2, 0.6, t / 2), (0.2, 2.0, t), "Steel"),
        # Coffee urn.
        C((-2.4, 0.9, t + 1.1), 0.6, 2.0, "Chrome", seg=10),
        C((-2.4, 0.9, t + 2.2), 0.45, 0.25, "Charcoal", seg=10),
        B((-2.4, 0.28, t + 0.5), (0.2, 0.3, 0.2), "Charcoal"),
        # A stack of cups and a pink box of donuts.
        C((-1.2, 0.5, t + 0.5), 0.25, 0.8, "OffWhite", seg=8),
        BV((0.4, 0.6, t + 0.25), (2.0, 1.4, 0.3), "Pink", bevel=0.06),
    ]
    for k in range(3):
        s.append(C((-0.2 + k * 0.6, 0.6, t + 0.45), 0.24, 0.14, "#E8A050", seg=8))
    s += [
        # A bowl of fruit.
        C((2.4, 0.7, t + 0.25), 0.8, 0.3, "Wood", seg=10),
        B((2.2, 0.6, t + 0.55), (0.5, 0.5, 0.5), "Orange", rot=(20, 30, 0)),
        B((2.7, 0.8, t + 0.55), (0.5, 0.5, 0.5), "Carpet", rot=(10, -20, 40)),
        B((2.4, 1.1, t + 0.6), (0.6, 0.35, 0.35), "Duck", rot=(0, 20, 30)),
        # The cooler beside the table.
        BV((4.0, -1.9, 0.75), (2.0, 1.4, 1.5), "Blue", bevel=0.15),
        BV((4.0, -1.9, 1.6), (2.1, 1.5, 0.3), "OffWhite", bevel=0.1),
        # A bin.
        C((-4.2, -2.2, 0.9), 0.6, 1.8, "ParkGreen", seg=10),
    ]
    return s


def video_village():
    """The monitor cart the director watches the take on: two monitors facing -Y on a cart, a
    big black-and-white umbrella over it, a walkie on the shelf."""
    s = [
        BV((0, 0, 2.0), (5.0, 2.4, 0.25), CASE, bevel=0.06),
        BV((0, 0, 0.6), (5.0, 2.4, 0.25), CASE, bevel=0.06),
        BV((-1.8, 0.4, 1.1), (1.0, 0.6, 0.7), "Gold", bevel=0.08),
    ]
    for x in (-2.3, 2.3):
        for y in (-1.0, 1.0):
            s += [B((x, y, 1.2), (0.2, 0.2, 1.9), PIPE), C((x, y, 0.2), 0.2, 0.25, "Charcoal", rot=(0, 90, 0), seg=6)]
    for x in (-1.3, 1.3):
        s += [
            BV((x, 0, 3.4), (2.3, 0.6, 1.6), "Charcoal", bevel=0.1),
            B((x, -0.31, 3.42), (2.0, 0.04, 1.3), "#4C7ACC"),
            B((x - 0.3, -0.34, 3.2), (0.9, 0.04, 0.5), "#E8C070"),
            B((x, 0.1, 2.3), (0.4, 0.4, 0.4), "Charcoal"),
        ]
    # The umbrella on a pole from the cart's back corner, with a sandbag on its base.
    s += [
        C((0, 1.6, 4.2), 0.12, 8.4, PIPE, seg=6),
        BV((0, 1.6, 0.25), (1.4, 1.4, 0.5), "Charcoal", bevel=0.1),
        BV((0.9, 2.1, 0.5), (1.3, 1.0, 0.6), "Sandbag", bevel=0.2),
        K((0, 0.6, 7.7), 4.8, 3.0, 0.5, "OffWhite", seg=8),
        K((0, 0.6, 8.32), 3.0, 0.3, 0.75, "Navy", seg=8),
        C((0, 0.6, 8.8), 0.3, 0.3, "Gold", seg=6),
    ]
    return s


def apple_boxes():
    """Apple boxes: a full, a half and a quarter, stacked a little skew."""
    def box(z, h, turn):
        return G(
            (0, 0, z + h / 2), (0, 0, turn),
            BV((0, 0, 0), (2.4, 1.6, h), "Plywood", bevel=0.06),
            B((0, -0.81, 0), (0.8, 0.04, min(0.4, h * 0.4)), "Bark"),
            B((1.21, 0, 0), (0.04, 0.6, min(0.4, h * 0.4)), "Bark"),
        )

    return [box(0, 1.0, 0), box(1.0, 0.5, 9), box(1.5, 0.25, -6)]


def script_table():
    """A folding table with the script, a coffee cup, a walkie-talkie and the shot list."""
    t = 2.4
    s = [
        BV((0, 0, t), (4.0, 2.2, 0.15), "OffWhite", bevel=0.04),
        B((-1.6, 0, t / 2), (0.15, 1.8, t), "Steel", rot=(0, 12, 0)),
        B((1.6, 0, t / 2), (0.15, 1.8, t), "Steel", rot=(0, -12, 0)),
        BV((-0.6, 0, t + 0.2), (1.2, 1.5, 0.25), "OffWhite", bevel=0.03),
        B((-0.6, 0, t + 0.34), (1.2, 1.5, 0.04), "Carpet"),
        BV((0.7, 0.2, t + 0.12), (1.0, 1.3, 0.1), "#FFF4C8", bevel=0.02, rot=(0, 0, 14)),
        C((1.5, -0.5, t + 0.35), 0.22, 0.55, "OffWhite", seg=8),
        BV((-1.6, -0.5, t + 0.45), (0.4, 0.3, 0.7), "Charcoal", bevel=0.05),
        C((-1.5, -0.5, t + 1.0), 0.05, 0.5, "Charcoal", seg=4),
    ]
    return s


# --- Ground ------------------------------------------------------------------------------------


def berm():
    """A low drift of sand and dirt, 12 along X, sunk into the ground (not lifted)."""
    return [
        L((-3.6, 0, -0.3), (3.4, 2.0, 1.2), "Sand", jitter=0.06),
        L((0.4, 0.3, -0.25), (3.8, 2.4, 1.4), "Dust", jitter=0.06),
        L((4.2, -0.2, -0.3), (2.8, 1.8, 1.0), "Sand", jitter=0.06),
    ]


def clump():
    """A clump of desert scatter: two stones and tufts of dry grass, sunk into the ground."""
    s = [
        L((0, 0, 0.1), (1.0, 0.8, 0.7), "RockDark", jitter=0.08),
        L((1.1, 0.6, 0.0), (0.6, 0.5, 0.45), "Rock", jitter=0.08),
        L((-0.6, 0.6, -0.2), (1.6, 1.2, 0.5), "Dust", jitter=0.05),
    ]
    for x, y, h in ((-1.4, -0.4, 1.4), (0.8, -0.9, 1.1), (-0.4, 1.4, 1.2)):
        s += [
            K((x, y, h / 2), 0.35, 0.05, h, "#C9A45A", seg=4, rot=(8, 0, 0)),
            K((x + 0.3, y + 0.1, h * 0.4), 0.25, 0.04, h * 0.8, "#B08A44", seg=4, rot=(-10, 14, 0)),
        ]
    return s


KIT = [
    ("BacklotFence", lambda: fence(False)),
    ("BacklotFenceSign", lambda: fence(True)),
    ("BacklotFencePost", fence_post),
    ("BacklotFlatDesert", flat_desert),
    ("BacklotFlatTrail", flat_trail),
    ("BacklotBrace", brace),
    ("BacklotTrussTower", truss_tower),
    ("BacklotScaffold", scaffold),
    ("BacklotGroundLight", ground_light),
    ("BacklotCStand", c_stand),
    ("BacklotScrim", scrim),
    ("BacklotCable", cable),
    ("BacklotCableBend", cable_bend),
    ("BacklotCableRamp", cable_ramp),
    ("BacklotCableCoil", cable_coil),
    ("BacklotGenerator", generator),
    ("BacklotCase", case),
    ("BacklotCaseStack", case_stack),
    ("BacklotCart", cart),
    ("BacklotCraftTent", craft_tent),
    ("BacklotVideoVillage", video_village),
    ("BacklotAppleBoxes", apple_boxes),
    ("BacklotScriptTable", script_table),
    ("BacklotBerm", berm),
    ("BacklotClump", clump),
]

# Sunk into the ground: drifts and clumps that the set pieces sit in.
NO_LIFT = {"BacklotBerm", "BacklotClump"}

# "@180" shows a model from behind (map_kit.lineup), for the flats' bracing.
LINEUPS = {
    "map_kit_backlot.png": (
        ["BacklotCable", "BacklotCableBend", "BacklotCableRamp", "BacklotCableCoil", "BacklotCase", "BacklotCaseStack", "BacklotCart",
         "BacklotAppleBoxes", "BacklotScriptTable", "BacklotCStand", "BacklotGroundLight", "BacklotBerm", "BacklotClump"],
        ["BacklotFence", "BacklotFenceSign", "BacklotFencePost", "BacklotGenerator", "BacklotVideoVillage", "BacklotCraftTent", "BacklotScrim",
         "BacklotScaffold", "BacklotTrussTower"],
    ),
    "map_kit_backlot_flats.png": (["BacklotFlatDesert", "BacklotFlatTrail", "BacklotBrace@180", "BacklotFlatDesert@180"], []),
}
