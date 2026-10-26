"""Jungle kit: the Jungle Temple film set (the third film set, west of Starlight Park). map_kit.py
builds these into the one map_kit.fbx and the one MapKitShapes.luau with the rest of the map
kit, so run that file, not this one.

It is an open-backlot set: the themed middle is dressed like a real jungle, but the fake rocks,
the river and the backdrop show their wooden frames from behind, the way film sets do.

  JungleTemple       a stepped stone pyramid, 34 wide at the base and 16 high, with a ramp of
                     steps up the front to a shrine whose dark doorway (7 wide) lets the rolling
                     boulder out. The steps run from 17 in front of the middle (on the ground) to
                     6.5 in front of it (at the top, 16 up); the doorway's face is 1 in front of
                     the middle (src/shared/FilmScenes.luau walks the explorer up them). Dressed
                     with mossy blocks, draped vines, serpent heads, guardians, side stairs and
                     broken pillars; none of that touches the steps.
  IdolPedestal       a carved stone pillar, 1.6 high, for the golden idol
  JungleTree         a big rainforest tree with buttress roots and hanging vines
  JunglePalm         a leaning palm with big fronds
  JungleFern         a clump of big leaves
  JungleTorch        a bamboo torch with a burning flame (lit by the game)
  JungleRuin         a broken carved column, mossy

  Ruins and rocks
  JungleArch         a mossy stone arch to walk through (opening 6 wide, 8 high)
  JungleColumnFallen a toppled column in drums beside its broken stump
  JungleStoneHead    a big carved stone head, half sunk and mossy
  JungleFakeRock     a studio foam rock: painted front, plywood back with a frame and a brace
  JungleFakeCliff    a taller foam rock wall, the same trick
  JungleVines        a curtain of creepers hanging from a mossy log, to hang between trees

  Water
  JungleRiver        a straight piece of shallow painted river, 24 long (along X), 10 wide
  JungleRiverBend    a quarter bend of the same river round the origin, radius 12: it comes in
                     along Y at (12, 0) and leaves along X at (0, 12)
  JungleBridge       a little plank bridge with rope rails, spanning 11 along Y

  Plants and ground
  JungleBigLeaf      elephant-ear plant
  JungleBanana       banana plant with a bunch
  JungleBush         a round leafy bush with flowers
  JungleFlowers      a low patch of tropical flowers
  JungleRoots        a clump of arching roots
  JungleMound        a low faceted mossy mound, sunk into the ground (not lifted)
  JungleLeafLitter   a flat patch of fallen leaves
  JungleDirtPatch    worn dirt with a ragged edge, 22 x 16, sunk into the ground (not lifted);
                     JungleDirtPatchSmall (11 x 8) and JungleDirtPatchLong (26 x 11) the same
  JungleShrineBack   the shrine's back as a set piece: plywood on a 2x4 frame, jacks, sandbags
  PropSandbag        the bag of sand the explorer swaps for the idol (held like the idol)
  PropDart           a trap's dart, flying toward -Y, centred on the origin

  Backdrop and way in
  JungleBackdrop     a painted flat (32 wide, 22 high): jungle, mountains and a waterfall,
                     built with backlot_kit.flat (timber frame, jacks and sandbags behind)
  JungleBackdropSide the matching side flat: jungle and mountains, no waterfall
  JungleSignpost     a wooden signpost for the park path; spot Sign (the arrow board)
  JungleGateArch     a jungle arch for the park fence gap: two stone totems and a log lintel,
                     18 clear between the totems; spot Sign (the lintel board)

Chunky low-poly toy style (ART_STYLE.md): mossy stone, gold, bold greens. Blender axes, in
studs: Z up, the model faces -Y, standing on Z = 0.
"""

import math

from kitdsl import B, C, E, G, K, L, T, W, ring, shade  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.15, neon=False):
    return B(at, size, color, rot, bevel, neon)


def rnd(i, k=1):
    """A fixed pseudo-random number in [0, 1) for scatter, so the models don't change run to run."""
    return (math.sin(i * 12.9898 + k * 78.233) * 43758.5453) % 1.0


STONE = "#A9A28E"
STONE_DARK = "#857E6A"
STONE_MOSSY = "#8E9870"
MOSS = "#5E9E3E"
MOSS_DARK = "#477F31"
VINE = "#3E8A2E"
HOLE = "#1A1714"
EYES = "#2E2C34"
PLY = "#D9BF8C"  # bare plywood on the back of the set pieces
FRAME = "#B08A58"  # the 2x4s
SANDBAG = "#B5A27A"
MUD = "#6E5236"
WATER = "#2FA6C8"


def vine(x, y, z, length, color=VINE, leaves=2, seed=0):
    """A hanging vine: a strand with a few leaf tufts down it, its top at (x, y, z)."""
    s = [B((x, y, z - length / 2), (0.22, 0.22, length), color)]
    for k in range(leaves):
        lz = z - length * (k + 0.6) / (leaves + 0.3)
        s.append(B((x + (0.25 if k % 2 else -0.25), y, lz), (0.6, 0.2, 0.6), "Leaf" if (k + seed) % 2 else "LeafDark", rot=(0, 45, 30 * k + seed * 17)))
    return s


# --- The temple ----------------------------------------------------------------------------


def jungle_temple():
    s = []
    # Four stepped tiers, each 4 high and 7 narrower than the one below.
    for i in range(4):
        w = 34 - 7 * i
        z = 4 * i + 2
        s += [
            BV((0, 0, z), (w, w, 4), STONE if i % 2 == 0 else shade(STONE, 0.06), bevel=0.2),
            B((0, 0, z + 1.65), (w + 0.3, w + 0.3, 0.3), STONE_DARK),  # a band just under the top, not level with it
            # Moss creeping over each ledge, dripping down the face below.
            B((-w / 4, -w / 2 + 0.6, z + 2.05), (w / 3, 1.4, 0.2), MOSS),
            B((-w / 4 - 1.0, -w / 2 - 0.12, z + 1.0), (w / 5, 0.2, 2.0), MOSS_DARK),
            B((w / 3, w / 2 - 0.8, z + 2.05), (w / 4, 1.8, 0.2), MOSS),
            B((w / 2 - 0.6, -w / 6, z + 2.05), (1.4, w / 4, 0.2), MOSS),
            B((w / 2 + 0.12, -w / 6, z + 1.1), (0.2, w / 5, 1.8), MOSS_DARK),
        ]
        # Odd blocks sticking out of the faces in other shades, so the tiers read as laid stone.
        for k in range(6):
            r = rnd(i * 10 + k)
            side = -1 if k % 2 else 1
            fx = side * (5.2 + r * (w / 2 - 6.5)) if w > 14 else side * (w / 2 - 1.2)
            color = (STONE_DARK, STONE_MOSSY, shade(STONE, -0.08))[k % 3]
            s.append(B((fx, -w / 2 - 0.12, z - 1.2 + (k % 3) * 1.1), (1.6 + r * 1.4, 0.3, 0.9), color))
            # and on the sides
            s.append(B((side * (w / 2 + 0.12), (r - 0.5) * (w - 4), z - 0.9 + (k % 2) * 1.3), (0.3, 1.8 + r, 0.9), color))
        # Carved faces on the front of the lower tiers, either side of the steps.
        if i < 2:
            for x in (-1, 1):
                fx = x * (w / 2 - 4.5)
                s += [
                    BV((fx, -w / 2 - 0.2, z), (3.0, 0.4, 3.0), STONE_DARK, bevel=0.1),
                    B((fx - 0.6, -w / 2 - 0.45, z + 0.4), (0.6, 0.2, 0.5), EYES),
                    B((fx + 0.6, -w / 2 - 0.45, z + 0.4), (0.6, 0.2, 0.5), EYES),
                    B((fx, -w / 2 - 0.45, z - 0.7), (1.6, 0.2, 0.3), EYES),
                    B((fx, -w / 2 - 0.45, z + 1.15), (2.4, 0.2, 0.25), "Gold"),
                ]
    # The steps: one ramp (players and the boulder roll on it) with step edges on top.
    s.append(W((0, -11.75, 8.0), (8.0, 10.5, 16.0), STONE, rot=(0, 0, 0)))
    for k in range(16):
        f = (k + 0.5) / 16
        s.append(B((0, -17 + 10.5 * f, 16 * f - 0.05), (8.2, 0.4, 0.25), STONE_DARK))
    for x in (-4.4, 4.4):
        s.append(W((x, -11.75, 8.2), (0.8, 10.5, 16.4), STONE_DARK))
        # A serpent head at the foot of each balustrade, jaws open.
        s += [
            BV((x, -17.6, 0.9), (1.5, 1.8, 1.4), STONE_MOSSY, bevel=0.2),
            BV((x, -18.3, 0.35), (1.5, 1.2, 0.5), STONE_DARK, bevel=0.15),
            B((x, -18.55, 0.75), (1.1, 0.5, 0.3), "#7A1F2B"),
            B((x - 0.45, -18.5, 1.35), (0.3, 0.2, 0.3), "Gold"),
            B((x + 0.45, -18.5, 1.35), (0.3, 0.2, 0.3), "Gold"),
            K((x, -17.2, 1.8), 0.6, 0.1, 0.6, STONE_DARK, seg=4, rot=(0, 0, 45)),
        ]
    # Side stairs up the bottom tier on both sides, running along the face.
    for side in (-1, 1):
        for k in range(4):
            s.append(B((side * (17.0 + 1.2), 3.0 - k * 1.3, 0.5 + k * 1.0), (2.4, 5.6 - k * 2.6 if k < 2 else 1.4, 1.0 + k * 2.0), STONE_DARK if k % 2 else STONE))
    # Broken pillars on the corners of the second and third tiers.
    for i, (cx, cy) in enumerate(((-11.5, -11.5), (11.5, -11.5), (-8.0, -8.0), (8.0, -8.0))):
        z0 = 8 if i < 2 else 12
        h = 3.2 - i * 0.5 + (1.0 if i == 1 else 0)
        s += [
            BV((cx, cy, z0 + 0.3), (2.0, 2.0, 0.6), STONE_DARK, bevel=0.1),
            C((cx, cy, z0 + 0.6 + h / 2), 0.7, h, STONE, seg=8),
            K((cx + 0.1, cy, z0 + 0.6 + h + 0.2), 0.72, 0.45, 0.4, STONE, seg=8, rot=(0, 14, 0)),
            B((cx, cy - 0.5, z0 + 0.6 + h + 0.1), (1.2, 0.8, 0.2), MOSS, rot=(0, 14, 0)),
        ]
    # The shrine on top: a stone hut with a big dark doorway and a gold crest.
    s += [
        BV((-4.6, 2.0, 20.5), (1.8, 6.0, 9.0), STONE, bevel=0.15),
        BV((4.6, 2.0, 20.5), (1.8, 6.0, 9.0), STONE, bevel=0.15),
        BV((0, 4.2, 20.5), (11.0, 1.6, 9.0), STONE, bevel=0.15),
        BV((0, 2.0, 25.7), (11.6, 6.6, 1.6), STONE_DARK, bevel=0.15),
        B((0, 2.6, 20.0), (7.4, 3.0, 8.0), HOLE),
        BV((0, -1.15, 24.4), (7.8, 0.4, 0.7), "Gold", bevel=0.08),
        K((0, 2.0, 27.6), 3.2, 0.8, 2.2, STONE, seg=4, rot=(0, 0, 45)),
        E((0, 2.0, 29.0), (0.7, 0.7, 0.7), "Gold"),
        # Carved teeth under the lintel and glyphs down the jambs.
        B((0, -1.05, 23.75), (7.4, 0.25, 0.3), STONE_DARK),
    ]
    for k in range(6):
        s.append(K((-3.1 + k * 1.24, -1.1, 23.35), 0.32, 0.02, 0.5, STONE_DARK, seg=4, rot=(180, 0, 45)))
    for x in (-4.6, 4.6):
        for k in range(3):
            s.append(B((x, -1.05, 18.0 + k * 2.0), (1.0, 0.2, 0.9), STONE_DARK if k % 2 else "Gold" if k == 1 else STONE_MOSSY))
    # Two guardian statues either side of the shrine.
    for x in (-5.7, 5.7):
        s += [
            BV((x, -4.6, 16.4), (1.4, 1.4, 0.8), STONE_DARK, bevel=0.1),
            BV((x, -4.6, 17.8), (1.1, 0.9, 2.0), STONE_MOSSY, bevel=0.15),
            BV((x, -4.6, 19.4), (1.2, 1.1, 1.2), STONE, bevel=0.2),
            B((x - 0.25, -5.2, 19.5), (0.25, 0.1, 0.2), EYES),
            B((x + 0.25, -5.2, 19.5), (0.25, 0.1, 0.2), EYES),
            B((x, -4.6, 20.1), (1.5, 0.5, 0.3), "Gold"),
        ]
    # Vines hanging over the doorway, the shrine roof and draped down the tiers.
    s += vine(-3.4, -1.3, 24.6, 4.0, seed=1) + vine(3.0, -1.3, 24.6, 3.0, seed=2)
    s += vine(-5.6, -1.3, 26.3, 5.5, seed=3) + vine(5.7, 1.0, 26.3, 4.5, seed=4)
    s += [B((0, -1.2, 26.5), (11.0, 0.3, 0.5), MOSS)]
    for i, (vx, top) in enumerate(((-9.0, 3), (7.5, 2), (-13.5, 1), (13.0, 2), (-6.0, 3))):
        # Over each ledge from the tier `top` down to the ground: a strand on the ledge, then down the face.
        for t in range(top, -1, -1):
            w = 34 - 7 * t
            z = 4 * t + 4
            s.append(B((vx, -w / 2 + 0.6, z + 0.1), (0.3, 1.4, 0.2), VINE))
            s += vine(vx + (t % 2) * 0.3, -w / 2 - 0.15, z, 3.0 if t else 3.6, seed=i + t)
    for y in (-8.0, 0.0, 9.0):
        for side in (-1, 1):
            s += vine(side * 17.15, y + side, 4.0, 3.2, seed=int(y))
    s += vine(-13.65, 2.0, 12.0, 6.5, seed=5) + vine(10.15, -2.0, 16.0, 6.0, seed=6)
    # Ferns and roots round the foot, kept clear of the steps.
    for i, (fx, fy) in enumerate(((-16.0, -17.0), (-9.5, -17.6), (10.0, -17.5), (16.5, -16.5), (-17.5, 8.0), (17.6, 12.0), (0.0, 17.6))):
        s.append(L((fx, fy, 0.5), (1.6, 1.1, 0.9), "LeafDark" if i % 2 else "Leaf", rot=(0, 0, 20 * i)))
        s.append(L((fx + 0.9, fy - 0.3, 0.4), (0.9, 0.8, 0.6), "LeafLight", rot=(0, 0, 40 * i)))
    for x in (-16.4, 16.4):
        s += [
            B((x, -14.0, 0.6), (0.5, 3.6, 0.5), "Bark", rot=(28, 0, 0)),
            B((x - 0.4 * math.copysign(1, x), -12.0, 1.0), (0.45, 3.4, 0.45), "Bark", rot=(-34, 0, 0)),
        ]
    return s


def idol_pedestal():
    return [
        BV((0, 0, 0.15), (1.8, 1.8, 0.3), STONE_DARK, bevel=0.08),
        BV((0, 0, 0.8), (1.2, 1.2, 1.1), STONE, bevel=0.1),
        B((0, 0, 1.45), (1.5, 1.5, 0.2), "Gold"),
        E((0, -0.62, 0.8), (0.18, 0.05, 0.18), "Teal", neon=True),
    ]


def jungle_tree():
    s = [
        K((0, 0, 7.0), 1.6, 1.0, 14.0, "Bark", seg=8),
        L((0, 0, 15.5), (7.0, 6.5, 3.6), "LeafDark", jitter=0.09),
        L((3.0, 1.5, 17.5), (4.5, 4.0, 2.8), "Leaf", jitter=0.1),
        L((-3.2, -1.0, 17.0), (4.2, 4.2, 2.6), "LeafDark", jitter=0.1),
        L((0.5, -2.5, 19.0), (3.0, 3.0, 2.0), "LeafLight", jitter=0.1),
    ]
    # Buttress roots fanning out at the foot.
    s += ring(5, 1.6, 1.2, lambda x, y, a: B((x, y, 1.2), (0.6, 2.6, 2.4), "Bark", rot=(0, 0, -a)), start=10)
    # Vines hanging from the canopy.
    for i, (x, y) in enumerate(((4.5, -2.0), (-4.0, 2.5), (1.5, 4.5), (-2.5, -4.0))):
        s.append(B((x, y, 10.5 + (i % 2)), (0.25, 0.25, 6.0 - (i % 2) * 2), VINE))
    return s


def jungle_palm():
    s = []
    for k in range(6):
        s.append(C((k * 0.35, 0, 1.0 + k * 2.0), 0.55 - k * 0.04, 2.1, "#8A6A44", rot=(0, 6 + k * 2, 0), seg=8))
    top = (2.1, 0, 12.3)
    s += ring(7, 2.6, top[2], lambda x, y, a: B((top[0] + x, top[1] + y, top[2] - 0.6), (1.2, 5.6, 0.25), "Leaf", rot=(-25, 0, -a)))
    s += [E(top, (0.9, 0.9, 0.8), "#6A4A2A"), E((top[0] + 0.6, -0.5, top[2] - 0.8), (0.4, 0.4, 0.4), "#7A5434")]
    return s


def jungle_fern():
    return ring(7, 0.9, 0.9, lambda x, y, a: B((x, y, 0.8), (0.9, 3.0, 0.15), "LeafDark" if int(a) % 2 else "Leaf", rot=(-35, 0, -a))) + [
        L((0, 0, 0.4), (1.0, 1.0, 0.5), "LeafDark"),
    ]


def jungle_torch():
    return [
        C((0, 0, 2.2), 0.18, 4.4, "#B89A5A", seg=6),
        B((0, 0, 1.2), (0.42, 0.42, 0.12), "#7A5434"),
        B((0, 0, 3.2), (0.42, 0.42, 0.12), "#7A5434"),
        K((0, 0, 4.55), 0.35, 0.45, 0.4, "#5A3A24", seg=8),
        K((0, 0, 5.3), 0.35, 0.03, 1.1, "Flame", seg=8, neon=True),
    ]


def jungle_ruin():
    return [
        BV((0, 0, 0.4), (3.0, 3.0, 0.8), STONE_DARK, bevel=0.1),
        C((0, 0, 2.6), 1.1, 3.8, STONE, seg=10),
        C((0.2, 0, 4.9), 1.05, 0.8, STONE, rot=(0, 12, 0), seg=10),
        B((0, -1.1, 2.6), (0.8, 0.2, 0.8), STONE_DARK),
        B((0.4, 0, 5.3), (1.6, 1.6, 0.25), MOSS, rot=(0, 12, 0)),
        L((1.8, -1.2, 0.5), (0.9, 0.8, 0.5), STONE_DARK),
        B((-1.0, -0.9, 2.0), (0.25, 0.25, 3.0), VINE),
    ]


# --- Ruins and rocks ---------------------------------------------------------------------


def jungle_arch():
    s = []
    for side in (-1, 1):
        x = side * 4.0
        h = 5 if side < 0 else 4  # the right pillar has lost a block
        for k in range(h):
            r = rnd(k, side)
            s.append(BV((x + (r - 0.5) * 0.3, (r - 0.5) * 0.3, 0.8 + k * 1.6), (2.0, 2.2, 1.6), (STONE, STONE_MOSSY, shade(STONE, 0.06))[k % 3], bevel=0.15))
        s.append(B((x - side * 1.05, -0.4, 1.6 + 0.8), (0.2, 1.2, 1.2), STONE_DARK))  # a carved glyph
    s += [
        # The stepped lintel, with the broken right end resting on the shorter pillar.
        BV((-1.4, 0, 8.6), (6.0, 2.4, 1.4), STONE, bevel=0.15),
        BV((2.6, 0, 7.9), (3.6, 2.3, 1.4), STONE_MOSSY, rot=(0, 9, 0), bevel=0.15),
        BV((-1.0, 0, 9.9), (4.0, 2.0, 1.2), STONE_DARK, bevel=0.15),
        B((0.2, 0, 9.35), (10.6, 2.6, 0.3), MOSS, rot=(0, 3, 0)),
        L((-1.5, 0.2, 10.7), (1.8, 1.2, 0.6), MOSS_DARK),
        # A carved face in the keystone.
        B((-1.5, -1.25, 8.7), (0.5, 0.2, 0.4), EYES),
        B((-0.3, -1.25, 8.7), (0.5, 0.2, 0.4), EYES),
        # Fallen blocks and the missing one at the foot.
        BV((6.6, -1.4, 0.7), (1.8, 2.0, 1.4), STONE, rot=(0, 0, 25), bevel=0.15),
        BV((5.8, 0.8, 0.5), (1.4, 1.4, 1.0), STONE_DARK, rot=(8, 0, -15), bevel=0.15),
    ]
    for i, (vx, vy, top, ln) in enumerate(((-2.8, -1.3, 8.0, 3.5), (-0.8, -1.3, 8.0, 2.2), (1.6, -1.3, 7.3, 3.0), (-4.9, 0.3, 9.0, 6.0), (3.6, 1.3, 8.0, 4.0))):
        s += vine(vx, vy, top, ln, seed=i)
    s += [L((x, -1.2, 0.5), (1.2, 0.9, 0.8), "LeafDark" if x < 0 else "Leaf") for x in (-5.6, -2.8)]
    return s


def jungle_column_fallen():
    s = [
        # The stump still standing, snapped at an angle.
        BV((-6.0, 0.4, 0.4), (3.0, 3.0, 0.8), STONE_DARK, bevel=0.12),
        C((-6.0, 0.4, 1.9), 1.1, 2.2, STONE, seg=10),
        K((-6.0, 0.4, 3.25), 1.12, 0.6, 0.5, STONE, seg=10, rot=(0, -18, 0)),
        B((-6.0, 0.4, 3.2), (1.4, 1.6, 0.2), MOSS, rot=(0, -18, 0)),
    ]
    # The drums that fell, lying along X, each a little out of line.
    for i in range(3):
        x = -3.0 + i * 2.6
        s += [
            C((x, (rnd(i) - 0.5) * 0.8, 1.05), 1.05, 2.3, STONE if i % 2 == 0 else shade(STONE, 0.05), rot=(0, 90, rnd(i, 2) * 16 - 8), seg=10),
            B((x, 0.0, 2.08), (1.6, 1.0, 0.16), MOSS if i != 1 else MOSS_DARK),
        ]
    s += [
        # The capital, tipped on its side at the end.
        BV((5.0, 0.6, 1.3), (2.6, 2.6, 2.4), STONE_DARK, rot=(0, 0, 20), bevel=0.15),
        B((5.0, 0.6, 2.55), (2.0, 2.0, 0.2), MOSS, rot=(0, 0, 20)),
        L((3.6, -1.5, 0.4), (1.1, 0.8, 0.6), "Leaf"),
        L((-4.5, 1.8, 0.5), (1.3, 1.0, 0.7), "LeafDark"),
        L((0.5, 1.6, 0.35), (0.9, 0.7, 0.4), STONE_DARK),
    ]
    return s


def jungle_stone_head():
    tilt = (6, 4, -8)
    return [G((0, 0, 0), tilt,
        BV((0, 0, 2.4), (4.6, 4.2, 4.8), STONE, bevel=0.6),
        BV((0, 0, 4.7), (4.9, 4.5, 1.2), STONE_DARK, bevel=0.4),  # the helmet band
        B((0, -2.2, 4.55), (3.8, 0.3, 0.4), "Gold"),
        BV((0, -2.0, 3.45), (3.8, 0.6, 0.6), STONE_DARK, bevel=0.2),  # brow
        B((-0.95, -2.18, 2.95), (1.0, 0.3, 0.5), EYES),
        B((0.95, -2.18, 2.95), (1.0, 0.3, 0.5), EYES),
        W((0, -2.4, 2.3), (1.1, 0.8, 1.3), STONE_DARK),  # nose
        BV((0, -2.2, 1.3), (2.2, 0.6, 0.7), shade(STONE, 0.12), bevel=0.25),  # lips
        BV((-2.45, -0.4, 2.8), (0.5, 1.2, 1.8), STONE_DARK, bevel=0.15),  # ears
        BV((2.45, -0.4, 2.8), (0.5, 1.2, 1.8), STONE_DARK, bevel=0.15),
        L((0.6, 0.4, 5.5), (2.2, 1.9, 0.6), MOSS),
        L((-1.6, 1.4, 4.4), (1.0, 1.0, 1.0), MOSS_DARK),
    )] + vine(-1.8, -2.2, 5.3, 2.6, seed=3) + [
        L((1.8, -2.2, 0.4), (1.3, 0.9, 0.7), "LeafDark"),
        L((-2.4, -1.6, 0.4), (1.0, 0.8, 0.6), "Leaf"),
    ]


def fake_rock(lumps, w, h, seed):
    """A studio foam rock: painted lumps bulging forward from y = 0, a plywood back cut to its
    outline at y = 0.3 with a 2x4 frame on it, and a brace with a sandbag."""
    s = []
    for i, (x, z, rx, rz) in enumerate(lumps):
        color = ("#9C9484", "#8A8274", "#A8A090")[i % 3]
        s.append(L((x, -rx * 0.35, z), (rx, rx * 0.75, rz), color, rot=(0, 0, rnd(i, seed) * 30), jitter=0.1))
    # Moss on the tops.
    for i, (x, z, rx, rz) in enumerate(lumps[:3]):
        s.append(L((x, -rx * 0.35, z + rz * 0.8), (rx * 0.6, rx * 0.5, 0.35), MOSS))
    # The back: plywood steps that follow the outline, then the frame and a brace.
    for x, z, rx, rz in lumps:
        s.append(B((x, rx * 0.4 + 0.1, z), (rx * 1.5, 0.2, rz * 1.5), PLY))
    s += [
        B((0, w * 0.05 + 0.7, 0.3), (w * 0.8, 0.3, 0.4), FRAME),
        B((-w * 0.25, w * 0.05 + 0.7, h * 0.35), (0.35, 0.3, h * 0.7), FRAME),
        B((w * 0.25, w * 0.05 + 0.7, h * 0.3), (0.35, 0.3, h * 0.6), FRAME),
        B((0, w * 0.05 + 0.7 + h * 0.2, h * 0.3), (0.3, 0.3, h * 0.75), FRAME, rot=(-35, 0, 0)),
        BV((0, w * 0.05 + 1.0 + h * 0.4, 0.3), (1.4, 0.9, 0.5), SANDBAG, bevel=0.2),
    ]
    return s


def jungle_fake_rock():
    return fake_rock([(0, 2.0, 2.4, 2.0), (-2.2, 1.2, 1.6, 1.3), (2.0, 1.4, 1.8, 1.4), (0.6, 3.4, 1.4, 1.0)], 7, 4.5, 1)


def jungle_fake_cliff():
    return fake_rock([
        (0, 4.0, 3.0, 4.0), (-4.0, 2.6, 2.6, 2.8), (4.2, 3.2, 2.8, 3.2), (-1.5, 7.6, 2.2, 1.6),
        (2.4, 6.8, 2.0, 1.8), (-6.4, 1.4, 1.6, 1.5), (6.8, 1.6, 1.8, 1.6),
    ], 15, 9.0, 2)


def jungle_vines():
    s = [
        C((0, 0, 9.0), 0.5, 12.0, "Bark", rot=(0, 90, 0), seg=8),
        B((0, 0, 9.5), (11.0, 0.9, 0.25), MOSS),
        L((-4.0, 0, 9.6), (1.4, 0.9, 0.6), "LeafDark"),
        L((3.5, 0, 9.6), (1.2, 0.8, 0.5), "Leaf"),
    ]
    for i in range(11):
        x = -5.4 + i * 1.08
        ln = 4.5 + rnd(i, 3) * 4.0
        s += vine(x, -0.3 if i % 2 else 0.3, 8.7, ln, color=VINE if i % 3 else MOSS_DARK, leaves=3, seed=i)
    return s


# --- Water -------------------------------------------------------------------------------


def river_slice(at, yaw, length, seed):
    """One straight bit of the channel along local X, centred on `at`, as a group."""
    # Neighbouring slices of a bend overlap, so each sits a hair higher than the last: coplanar
    # overlaps render as black seams.
    dz = (seed % 5) * 0.012
    parts = [
        B((0, 0, 0.1 + dz), (length, 8.0, 0.2), WATER),
        B((0, 0, 0.26 + dz), (length * 0.9, 0.5, 0.04), "WaterLight"),  # painted ripples
        B((length * 0.15, 2.2, 0.26 + dz), (length * 0.4, 0.35, 0.04), "WaterLight"),
        B((-length * 0.2, -2.4, 0.26 + dz), (length * 0.35, 0.35, 0.04), "WaterLight"),
    ]
    for side in (-1, 1):
        parts += [
            B((0, side * 4.5, 0.3 + dz), (length, 1.4, 0.6), MUD),  # the bank
            B((0, side * 5.6, 0.45 + dz), (length, 1.2, 0.9), MOSS_DARK),
        ]
    for i in range(2):
        r = rnd(i, seed)
        parts.append(L(((r - 0.5) * length * 0.8, (-1 if (i + seed) % 2 else 1) * 4.3, 0.7), (1.0 + r * 0.6, 0.8, 0.6 + r * 0.4), "#9C9484", rot=(0, 0, r * 90), jitter=0.1))
    return G(at, (0, 0, yaw), *parts)


def jungle_river():
    s = [river_slice((-6, 0, 0), 0, 12.0, 1), river_slice((6, 0, 0), 0, 12.0, 2)]
    s += [
        # Stepping stones and a reed clump: fake rocks again.
        L((-2.0, 0.6, 0.35), (1.0, 0.8, 0.4), "#A8A090", jitter=0.1),
        L((4.5, -1.4, 0.3), (0.8, 0.7, 0.3), "#9C9484", jitter=0.1),
        L((-8.0, 5.6, 1.2), (1.4, 0.9, 0.9), "Leaf"),
        L((9.0, -5.6, 1.1), (1.2, 0.8, 0.8), "LeafDark"),
    ]
    return s


def jungle_river_bend():
    s = []
    n = 5
    for i in range(n):
        a = (i + 0.5) * 90 / n
        r = 12.0
        s.append(river_slice((r * math.cos(math.radians(a)), r * math.sin(math.radians(a)), 0), a + 90, 2 * math.pi * r / 4 / n + 0.6, i))
    s += [L((12 * 0.71 - 0.5, 12 * 0.71 - 0.5, 0.35), (1.0, 0.8, 0.4), "#A8A090", jitter=0.1)]
    return s


def jungle_bridge():
    s = []
    for k in range(9):
        y = -5.0 + k * 1.25
        z = 1.0 + 0.5 * math.cos(y / 5.5 * math.pi / 2)  # a gentle hump
        s.append(B((0, y, z), (4.2, 1.1, 0.25), "Wood" if k % 2 else "Bark", rot=(math.degrees(-math.atan(y / 12)) * 0.6, 0, rnd(k) * 4 - 2), bevel=0.05))
    for side in (-1, 1):
        s += [
            B((side * 1.4, 0, 0.75), (0.5, 11.4, 0.5), "Bark", rot=(0, 0, 0)),  # the stringers
        ]
        for y in (-5.4, 0.0, 5.4):
            s.append(C((side * 2.2, y, 1.6 if y else 1.2), 0.22, 2.6 if y else 2.0, "Bark", seg=6))
        s += [
            B((side * 2.2, -2.7, 2.6), (0.12, 5.6, 0.12), "#C8B080", rot=(-8, 0, 0)),  # rope rails
            B((side * 2.2, 2.7, 2.6), (0.12, 5.6, 0.12), "#C8B080", rot=(8, 0, 0)),
        ]
    s += vine(-2.2, 0.0, 2.9, 1.6, seed=1)
    return s


# --- Plants and ground --------------------------------------------------------------------


def jungle_big_leaf():
    s = [L((0, 0, 0.3), (0.8, 0.8, 0.4), "LeafDark")]
    for i in range(6):
        a = i * 60 + 15
        reach = 1.4 + (i % 2) * 0.5
        x, y = math.sin(math.radians(a)) * reach, math.cos(math.radians(a)) * reach
        z = 1.6 + (i % 3) * 0.5
        s += [
            B((x / 2, y / 2, z / 2 + 0.2), (0.12, 0.12, z), "LeafDark", rot=(math.degrees(math.atan2(y, z)) * -1, math.degrees(math.atan2(x, z)), 0)),
            L((x * 1.35, y * 1.35, z + 0.1), (1.1, 0.7, 0.12), ("Leaf", "LeafDark", "LeafLight")[i % 3], rot=(0, -25, -a + 90), jitter=0.1),
        ]
    return s


def jungle_banana():
    s = [K((0, 0, 2.2), 0.55, 0.35, 4.4, "#8A9A4A", seg=7)]
    for i in range(7):
        a = i * 360 / 7
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        # Each leaf in two parts: rising from the top, then drooping at the tip.
        s += [
            B((sa * 1.3, ca * 1.3, 4.9), (0.9, 2.8, 0.08), "Leaf" if i % 2 else "LeafLight", rot=(-30, 0, -a)),
            B((sa * 3.3, ca * 3.3, 5.0), (0.8, 1.8, 0.08), "LeafDark" if i % 2 else "Leaf", rot=(25, 0, -a)),
        ]
    s += [
        B((0.6, -0.4, 3.6), (0.12, 0.12, 1.4), "#8A9A4A", rot=(0, 25, 0)),
        L((0.9, -0.6, 2.8), (0.5, 0.5, 0.6), "Duck"),
        L((0.8, -0.5, 2.2), (0.4, 0.4, 0.4), "#9AC84A"),
        K((1.0, -0.6, 1.6), 0.22, 0.02, 0.6, "#8A3A6A", seg=5, rot=(180, 0, 0)),
    ]
    return s


def jungle_bush():
    s = [
        L((0, 0, 1.0), (1.8, 1.6, 1.1), "LeafDark", jitter=0.1),
        L((1.2, -0.5, 1.3), (1.2, 1.1, 0.9), "Leaf", jitter=0.1),
        L((-1.1, 0.4, 1.4), (1.1, 1.0, 0.9), "Leaf", jitter=0.1),
        L((0.1, 0.3, 2.0), (1.0, 0.9, 0.7), "LeafLight", jitter=0.1),
    ]
    s += ring(5, 1.7, 1.4, lambda x, y, a: L((x, y - 0.2, 1.2 + (a % 3) * 0.2), (0.25, 0.25, 0.22), "Pink" if int(a) % 2 else "Carpet"), start=20)
    return s


def jungle_flowers():
    s = []
    for i in range(5):
        x, y = (rnd(i) - 0.5) * 3.2, (rnd(i, 2) - 0.5) * 2.4
        s.append(L((x, y, 0.35), (0.8, 0.7, 0.4), "Leaf" if i % 2 else "LeafDark"))
    # Heliconia: red and orange beaks up a stalk.
    for i, (x, y) in enumerate(((-0.9, 0.2), (0.4, -0.4), (1.3, 0.6))):
        s.append(B((x, y, 1.1), (0.1, 0.1, 1.6), "LeafDark"))
        for k in range(3):
            s.append(K((x + (0.22 if k % 2 else -0.22), y, 0.9 + k * 0.4), 0.16, 0.02, 0.5, "Carpet" if (i + k) % 2 else "Orange", seg=4, rot=(0, 90 if k % 2 else -90, 0)))
    s += [L((x, y, 0.75), (0.22, 0.22, 0.18), c) for x, y, c in ((-1.6, -0.6, "Pink"), (1.8, -0.5, "Gold"), (-0.2, 0.9, "Purple"), (0.9, -1.0, "Pink"))]
    return s


def jungle_roots():
    s = []
    for i in range(6):
        a = i * 60 + rnd(i) * 20
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        ln = 2.6 + rnd(i, 2) * 1.4
        # Each root arches up out of the ground and back down.
        s += [
            B((sa * ln * 0.3, ca * ln * 0.3, 0.6), (0.5, ln * 0.7, 0.5), "Bark", rot=(25, 0, -a)),
            B((sa * ln * 0.75, ca * ln * 0.75, 0.4), (0.4, ln * 0.6, 0.4), shade("Bark", 0.1), rot=(-30, 0, -a)),
        ]
    s += [
        K((0, 0, 0.8), 1.0, 0.5, 1.6, "Bark", seg=7),
        L((0, 0, 1.6), (0.8, 0.8, 0.4), MOSS),
        L((1.4, -1.2, 0.3), (0.8, 0.6, 0.4), "LeafDark"),
        L((-1.6, 0.8, 0.3), (0.7, 0.6, 0.35), MOSS),
    ]
    return s


def jungle_mound():
    # Centred on the ground (not lifted), so only the top shows.
    return [
        L((0, 0, 0), (6.0, 4.5, 1.6), "#4A7A34", jitter=0.06),
        L((-3.0, 1.0, 0.3), (3.0, 2.6, 1.4), "#5A8A3A", jitter=0.06),
        L((3.2, -0.8, 0.1), (2.6, 2.2, 1.1), "#3F6E2E", jitter=0.06),
        L((0.6, -1.0, 1.4), (1.2, 1.0, 0.5), "LeafDark"),
        L((-2.8, 1.2, 1.6), (0.9, 0.8, 0.5), "Leaf"),
        L((-1.2, -0.6, 1.5), (0.8, 0.6, 0.35), "#9C9484", jitter=0.1),
    ]


def jungle_leaf_litter():
    s = [C((0, 0, 0.04), 4.0, 0.08, "#5E5030", rot=(0, 0, 0), seg=9)]
    s[0]["size"] = (8.0, 6.0, 0.08)  # an oval patch
    colors = ("#8A6A34", "#A8843E", "#6E7A34", "#4A7A34", "#C89A48")
    for i in range(14):
        r, a = math.sqrt(rnd(i)) * 0.9, rnd(i, 2) * 360
        x, y = math.sin(math.radians(a)) * r * 3.6, math.cos(math.radians(a)) * r * 2.6
        s.append(B((x, y, 0.1 + (i % 3) * 0.02), (0.9, 0.5, 0.04), colors[i % 5], rot=(0, 0, rnd(i, 3) * 180)))
    s += [B((-1.0, 0.6, 0.15), (2.4, 0.18, 0.18), "Bark", rot=(0, 0, 20)), L((1.6, -0.8, 0.2), (0.6, 0.5, 0.25), MOSS)]
    return s


def dirt_patch(w, d, n, seed):
    """Worn dirt, w x d, ragged at the edge: overlapping seven-sided discs in two tones, sunk so only
    a sliver shows above the ground (not lifted)."""
    s = []
    for i in range(n):
        r = rnd(i, seed)
        a = rnd(i, seed + 1) * 2 * math.pi
        k = math.sqrt(rnd(i, seed + 2)) * 0.62
        x, y = math.cos(a) * k * w / 2, math.sin(a) * k * d / 2
        rad = min(w, d) * (0.24 + 0.16 * r)
        # Each disc a hair higher than the last: coplanar overlaps render as black.
        s.append(C((x, y, -0.04 + i * 0.004), rad, 0.2, "#96704A", rot=(0, 0, r * 51), seg=7))
    for i in range(n // 2):
        r = rnd(i, seed + 7)
        x, y = (r - 0.5) * w * 0.6, (rnd(i, seed + 8) - 0.5) * d * 0.5
        s.append(C((x, y, 0.012 + i * 0.004), min(w, d) * (0.14 + 0.1 * r), 0.2, "#86603E", rot=(0, 0, r * 40), seg=6))
    # A few pebbles and leaves on it.
    for i in range(4):
        x, y = (rnd(i, seed + 3) - 0.5) * w * 0.6, (rnd(i, seed + 4) - 0.5) * d * 0.6
        s.append(B((x, y, 0.13), (0.7, 0.4, 0.06), ("#A8843E", "#6E7A34", "#9C9484", "#8A6A34")[i], rot=(0, 0, rnd(i, seed + 5) * 180)))
    return s


def jungle_dirt_patch():
    return dirt_patch(22.0, 16.0, 12, 1)


def jungle_dirt_patch_small():
    return dirt_patch(11.0, 8.0, 7, 2)


def jungle_dirt_patch_long():
    return dirt_patch(26.0, 11.0, 12, 3)


def jungle_shrine_back():
    """The back of the temple's shrine as a set piece: a plywood skin on a 2x4 frame (its back
    toward +Y, the stone side against the shrine), two short jacks and a sandbag."""
    w, h = 11.6, 10.6
    s = [
        B((0, 0.15, h / 2), (w, 0.3, h), PLY),
        B((0, 0.4, 0.3), (w, 0.3, 0.4), FRAME),
        B((0, 0.4, h / 2), (w, 0.3, 0.4), FRAME),
        B((0, 0.4, h - 0.3), (w, 0.3, 0.4), FRAME),
        B((0, 0.42, h * 0.27), (0.3, 0.3, h * 0.5), FRAME, rot=(0, 50, 0)),
        # Painted stone blocks peeling at one corner, the plywood showing where they stop.
        B((-3.4, -0.02, h - 1.6), (3.6, 0.04, 2.2), STONE_DARK),
    ]
    for x in (-w / 2 + 0.25, 0, w / 2 - 0.25):
        s.append(B((x, 0.4, h / 2), (0.4, 0.3, h), FRAME))
    for x in (-3.6, 3.6):
        s += [
            B((x, 0.85, h * 0.32), (0.35, 0.35, h * 0.62), FRAME),
            B((x, 1.05, h * 0.3), (0.3, 0.3, h * 0.62), FRAME, rot=(-12, 0, 0)),
            B((x, 0.95, 0.15), (0.35, 1.4, 0.3), FRAME),
        ]
    s += [
        BV((-3.6, 1.2, 0.45), (1.4, 0.9, 0.5), SANDBAG, bevel=0.2),
        BV((3.4, 1.2, 0.45), (1.4, 0.9, 0.5), shade(SANDBAG, 0.08), bevel=0.2),
    ]
    return s


def prop_sandbag():
    """The bag of sand the explorer swaps for the idol: held from below like the idol (it sits
    along -Z from the grip), about the idol's size."""
    return [
        BV((0, 0, -0.55), (0.75, 0.6, 0.8), SANDBAG, bevel=0.25),
        BV((0, 0, -1.05), (0.45, 0.4, 0.3), shade(SANDBAG, 0.1), bevel=0.12),  # the gathered neck
        B((0, 0, -1.25), (0.5, 0.45, 0.08), "#C8B080"),  # the tie
        B((0, -0.31, -0.5), (0.3, 0.04, 0.2), MUD),  # a patch
    ]


def prop_dart():
    """A blowpipe dart from the temple's trap, flying toward -Y, centred on the origin."""
    return [
        C((0, 0.1, 0), 0.05, 1.0, "Bark", rot=(90, 0, 0), seg=6),
        K((0, -0.55, 0), 0.07, 0.0, 0.25, "Steel", rot=(90, 0, 0), seg=6),
        K((0, 0.62, 0), 0.22, 0.05, 0.35, "Carpet", rot=(-90, 0, 0), seg=6),  # the fluff
    ]


# --- Backdrop and way in ------------------------------------------------------------------


def backdrop(waterfall):
    """A 32 x 22 painted flat (backlot_kit.flat: the timber frame, jacks and sandbags behind), its
    face toward -Y: sky, misty mountains, a waterfall and jungle canopy, painted in layers."""
    from backlot_kit import dab, disc, flat

    w, h = 32.0, 22.0
    p = [
        dab(0, h * 0.86, w, h * 0.28, "#6FB4EA", 1),
        dab(0, h * 0.5, w, h * 0.3, "#BEE3F5", 1),
        # Clouds: overlapping puffs each on their own layer, so none z-fight.
        disc(-9, h * 0.8, 1.6, "OffWhite", 2, seg=10),
        disc(-7.2, h * 0.82, 2.0, "OffWhite", 3, seg=10),
        disc(-5.4, h * 0.8, 1.3, "OffWhite", 2, seg=10),
        disc(8.5, h * 0.87, 1.4, "OffWhite", 2, seg=10),
        disc(10.0, h * 0.86, 1.0, "OffWhite", 3, seg=10),
    ]
    # Far mountains: misty diamonds whose lower halves the jungle covers, lit tops a shade lighter.
    for i, (x, size, color) in enumerate(((-11, 14, "#7FA6A8"), (-2, 18, "#6E9A94"), (9, 14, "#7FA6A8"))):
        half = min(size / 2, w / 2 - abs(x))
        p.append(dab(x, h * 0.42, half * 1.41, half * 1.41, color, 3 + i % 2, turn=45))
    p.append(dab(-2, h * 0.42 + 7.2, 2.6, 2.6, "#9CC0B8", 6, turn=45))
    if waterfall:
        p += [
            dab(4.0, h * 0.42, 4.4, 7.0, "#5E7E70", 5),  # the cliff
            dab(4.0, h * 0.4, 1.8, 7.6, "OffWhite", 6),
            dab(4.0, h * 0.4, 0.7, 7.6, "WaterLight", 7),
            disc(4.0, h * 0.24, 1.9, "OffWhite", 8, seg=10),  # spray
        ]
    # Jungle canopy in three bands, nearer ones lower and darker: a solid band with round crowns
    # along its top edge.
    for band, (z, r, color, n) in enumerate(((h * 0.3, 2.2, "#4E8E5A", 9), (h * 0.2, 2.4, "#2F7A40", 8), (h * 0.1, 2.4, "#24603A", 8))):
        layer = 9 + band * 2
        p.append(dab(0, z / 2, w, z, color, layer))
        for i in range(n):
            x = -w / 2 + r + i * (w - r * 2) / (n - 1)
            if waterfall and band == 0 and abs(x - 4.0) < 2.6:
                continue
            p.append(disc(x, z + (rnd(i, band) - 0.5) * 1.2, r * (0.85 + rnd(i, band + 5) * 0.3), color, layer + 1, seg=8))
    # A couple of painted palms on the near band.
    for x in (-12.5, 12.0):
        p += [
            dab(x, h * 0.22, 0.4, 5.6, "#3A3020", 16),
            dab(x - 1.0, h * 0.35, 2.4, 0.5, "#24603A", 17, turn=20),
            dab(x + 1.0, h * 0.35, 2.4, 0.5, "#24603A", 17, turn=-20),
            dab(x, h * 0.37, 0.5, 1.8, "#2F7A40", 17),
        ]
    return flat(w, h, p, base="#8FC8F0")


def jungle_backdrop():
    return backdrop(True)


def jungle_backdrop_side():
    return backdrop(False)


def jungle_signpost():
    return [
        K((0, 0, 3.8), 0.4, 0.3, 7.6, "Bark", seg=6),
        K((0, 0, 7.85), 0.32, 0.02, 0.5, "Bark", seg=6),
        # The arrow board pointing +X, with its tip.
        BV((0.9, -0.42, 5.8), (4.2, 0.25, 1.3), "Wood", bevel=0.06),
        K((3.2, -0.42, 5.8), 0.92, 0.02, 0.9, "Wood", rot=(0, 90, 0), seg=4),
        T((0.8, -0.56, 5.8), (3.6, 0.05, 1.0), "Sign"),
        # A little lower board pointing back the other way, blank.
        BV((-0.6, -0.42, 4.3), (2.4, 0.22, 0.8), "Bark", rot=(0, 4, 0), bevel=0.05),
        K((-2.05, -0.42, 4.4), 0.56, 0.02, 0.5, "Bark", rot=(0, -90, 0), seg=4),
        # Rope lashing, vines and a fern at the foot.
        B((0, 0, 5.0), (0.95, 0.95, 0.2), "#C8B080"),
        B((0, 0, 6.6), (0.85, 0.85, 0.2), "#C8B080"),
        L((0.3, -0.3, 7.0), (0.6, 0.5, 0.4), "Leaf"),
        L((0.6, -0.5, 0.4), (1.0, 0.8, 0.5), "LeafDark"),
        L((-0.6, 0.4, 0.35), (0.8, 0.7, 0.4), "Leaf"),
    ] + vine(-0.35, -0.3, 7.2, 2.6, seed=2)


def jungle_gate_arch():
    s = []
    for side in (-1, 1):
        x = side * 10.5
        # A stone totem: three stacked carved blocks with a face, a torch bowl on top.
        for k in range(4):
            s.append(BV((x, 0, 1.6 + k * 3.0), (3.0 - k * 0.2, 3.0 - k * 0.2, 3.0), (STONE, STONE_MOSSY, shade(STONE, 0.06), STONE_DARK)[k], bevel=0.25))
        s += [
            BV((x, 0, 0.3), (3.8, 3.8, 0.6), STONE_DARK, bevel=0.15),
            B((x - 0.6, -1.45, 8.0), (0.6, 0.2, 0.6), EYES),
            B((x + 0.6, -1.45, 8.0), (0.6, 0.2, 0.6), EYES),
            B((x, -1.45, 6.9), (1.6, 0.2, 0.35), EYES),
            B((x, -1.5, 9.0), (2.4, 0.2, 0.3), "Gold"),
            K((x, 0, 13.6), 1.2, 1.6, 0.8, STONE_DARK, seg=8),
            K((x, 0, 14.6), 1.0, 0.05, 1.6, "Flame", seg=8, neon=True),
        ]
        s += vine(x - side * 1.4, -1.0, 12.0, 6.0, seed=side + 2)
        s += [L((x + side * 1.6, -1.4, 0.6), (1.4, 1.0, 0.9), "LeafDark"), L((x - side * 1.8, -1.6, 0.5), (1.0, 0.8, 0.6), "Leaf")]
    # The log lintel across, roped to the totems, with the sign board under it and vines hanging.
    s += [
        C((0, -0.2, 16.2), 0.8, 24.0, "Bark", rot=(0, 90, 0), seg=8),
        B((0, -0.2, 17.0), (20.0, 1.2, 0.3), MOSS),
        BV((0, -1.0, 14.4), (12.0, 0.4, 2.6), "Wood", bevel=0.1),
        BV((0, -1.15, 14.4), (12.6, 0.3, 3.0), "Bark", bevel=0.1),
        T((0, -1.3, 14.4), (11.0, 0.05, 2.0), "Sign"),
        B((-5.0, -1.0, 15.7), (0.15, 0.15, 1.2), "#C8B080"),
        B((5.0, -1.0, 15.7), (0.15, 0.15, 1.2), "#C8B080"),
        L((-7.5, -0.6, 17.0), (1.6, 1.0, 0.7), "LeafDark"),
        L((7.8, -0.6, 17.0), (1.4, 1.0, 0.6), "Leaf"),
        L((1.5, -0.6, 17.2), (1.0, 0.8, 0.5), "LeafLight"),
    ]
    for i, x in enumerate((-8.2, -7.0, 7.2, 8.4, -2.0, 2.4)):
        s += vine(x, -0.9, 15.6, 2.0 + rnd(i) * 3.0 if abs(x) > 6 else 0.9, seed=i)
    for x in (-10.5, 10.5):
        s += [B((x, -0.2, 16.2), (3.2, 1.9, 0.25), "#C8B080")]
    return s


KIT = [
    ("JungleTemple", jungle_temple),
    ("IdolPedestal", idol_pedestal),
    ("JungleTree", jungle_tree),
    ("JunglePalm", jungle_palm),
    ("JungleFern", jungle_fern),
    ("JungleTorch", jungle_torch),
    ("JungleRuin", jungle_ruin),
    ("JungleArch", jungle_arch),
    ("JungleColumnFallen", jungle_column_fallen),
    ("JungleStoneHead", jungle_stone_head),
    ("JungleFakeRock", jungle_fake_rock),
    ("JungleFakeCliff", jungle_fake_cliff),
    ("JungleVines", jungle_vines),
    ("JungleRiver", jungle_river),
    ("JungleRiverBend", jungle_river_bend),
    ("JungleBridge", jungle_bridge),
    ("JungleBigLeaf", jungle_big_leaf),
    ("JungleBanana", jungle_banana),
    ("JungleBush", jungle_bush),
    ("JungleFlowers", jungle_flowers),
    ("JungleRoots", jungle_roots),
    ("JungleMound", jungle_mound),
    ("JungleLeafLitter", jungle_leaf_litter),
    ("JungleDirtPatch", jungle_dirt_patch),
    ("JungleDirtPatchSmall", jungle_dirt_patch_small),
    ("JungleDirtPatchLong", jungle_dirt_patch_long),
    ("JungleShrineBack", jungle_shrine_back),
    ("PropSandbag", prop_sandbag),
    ("PropDart", prop_dart),
    ("JungleBackdrop", jungle_backdrop),
    ("JungleBackdropSide", jungle_backdrop_side),
    ("JungleSignpost", jungle_signpost),
    ("JungleGateArch", jungle_gate_arch),
]

# Sunk into the ground: the mound is the top of a squashed blob.
NO_LIFT = {"PropSandbag", "PropDart", "JungleMound", "JungleDirtPatch", "JungleDirtPatchSmall", "JungleDirtPatchLong"}

LINEUPS = {
    "jungle_kit.png": (["IdolPedestal", "JungleFern", "JungleTorch", "JungleRuin", "JunglePalm", "JungleTree"], ["JungleTemple"]),
    "jungle_temple.png": ([], ["JungleTemple"]),
    "jungle_ruins.png": (["JungleStoneHead", "JungleColumnFallen", "JungleFakeRock"], ["JungleArch", "JungleFakeCliff", "JungleVines"]),
    "jungle_plants.png": (["JungleFlowers", "JungleBigLeaf", "JungleBush", "JungleRoots", "JungleLeafLitter"], ["JungleBanana", "JungleMound", "JungleSignpost"]),
    "jungle_water.png": (["JungleRiver", "JungleBridge"], ["JungleRiverBend"]),
    "jungle_backdrop.png": ([], ["JungleBackdrop", "JungleBackdropSide"]),
    "jungle_gate.png": ([], ["JungleGateArch"]),
    "jungle_ground.png": (["JungleDirtPatchSmall", "JungleShrineBack@180", "PropSandbag", "PropDart"], ["JungleDirtPatch", "JungleDirtPatchLong"]),
}
