"""Jungle kit: the Jungle Temple film set (the third film set, west of Starlight Park). map_kit.py
builds these into the one map_kit.fbx and the one MapKitShapes.luau with the rest of the map
kit, so run that file, not this one.

  JungleTemple    a stepped stone pyramid, 34 wide at the base and 16 high, with a ramp of steps
                  up the front to a shrine whose dark doorway (7 wide) lets the rolling boulder out.
                  The steps run from 17 in front of the middle (on the ground) to 6.5 in front of
                  it (at the top, 16 up); the doorway's face is 1 in front of the middle
                  (src/shared/FilmScenes.luau walks the explorer up them).
  IdolPedestal    a carved stone pillar, 1.6 high, for the golden idol
  JungleTree      a big rainforest tree with buttress roots and hanging vines
  JunglePalm      a leaning palm with big fronds
  JungleFern      a clump of big leaves
  JungleTorch     a bamboo torch with a burning flame (lit by the game)
  JungleRuin      a broken carved column, mossy

Chunky low-poly toy style (ART_STYLE.md): mossy stone, gold, bold greens. Blender axes, in
studs: Z up, the model faces -Y, standing on Z = 0.
"""

from kitdsl import B, C, E, K, L, W, ring, shade  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.15, neon=False):
    return B(at, size, color, rot, bevel, neon)


STONE = "#A9A28E"
STONE_DARK = "#857E6A"
MOSS = "#5E9E3E"
VINE = "#3E8A2E"


def jungle_temple():
    s = []
    # Four stepped tiers, each 4 high and 7 narrower than the one below.
    for i in range(4):
        w = 34 - 7 * i
        z = 4 * i + 2
        s += [
            BV((0, 0, z), (w, w, 4), STONE if i % 2 == 0 else shade(STONE, 0.06), bevel=0.2),
            B((0, 0, z + 1.65), (w + 0.3, w + 0.3, 0.3), STONE_DARK),  # a band just under the top, not level with it
            # Moss creeping over each ledge.
            B((-w / 4, -w / 2 + 0.6, z + 2.05), (w / 3, 1.4, 0.2), MOSS),
            B((w / 3, w / 2 - 0.8, z + 2.05), (w / 4, 1.8, 0.2), MOSS),
        ]
        # Carved faces on the front of the lower tiers, either side of the steps.
        if i < 2:
            for x in (-1, 1):
                fx = x * (w / 2 - 4.5)
                s += [
                    BV((fx, -w / 2 - 0.2, z), (3.0, 0.4, 3.0), STONE_DARK, bevel=0.1),
                    B((fx - 0.6, -w / 2 - 0.45, z + 0.4), (0.6, 0.2, 0.5), "#2E2C34"),
                    B((fx + 0.6, -w / 2 - 0.45, z + 0.4), (0.6, 0.2, 0.5), "#2E2C34"),
                    B((fx, -w / 2 - 0.45, z - 0.7), (1.6, 0.2, 0.3), "#2E2C34"),
                ]
    # The steps: one ramp (players and the boulder roll on it) with step edges on top.
    s.append(W((0, -11.75, 8.0), (8.0, 10.5, 16.0), STONE, rot=(0, 0, 0)))
    for k in range(16):
        f = (k + 0.5) / 16
        s.append(B((0, -17 + 10.5 * f, 16 * f - 0.05), (8.2, 0.4, 0.25), STONE_DARK))
    for x in (-4.4, 4.4):
        s.append(W((x, -11.75, 8.2), (0.8, 10.5, 16.4), STONE_DARK))
    # The shrine on top: a stone hut with a big dark doorway and a gold crest.
    s += [
        BV((-4.6, 2.0, 20.5), (1.8, 6.0, 9.0), STONE, bevel=0.15),
        BV((4.6, 2.0, 20.5), (1.8, 6.0, 9.0), STONE, bevel=0.15),
        BV((0, 4.2, 20.5), (11.0, 1.6, 9.0), STONE, bevel=0.15),
        BV((0, 2.0, 25.7), (11.6, 6.6, 1.6), STONE_DARK, bevel=0.15),
        B((0, 2.6, 20.0), (7.4, 3.0, 8.0), "#1A1714"),
        BV((0, -1.15, 24.4), (7.8, 0.4, 0.7), "Gold", bevel=0.08),
        K((0, 2.0, 27.6), 3.2, 0.8, 2.2, STONE, seg=4, rot=(0, 0, 45)),
        E((0, 2.0, 29.0), (0.7, 0.7, 0.7), "Gold"),
        # Vines hanging over the doorway and down the sides.
        B((-3.4, -1.2, 22.6), (0.3, 0.2, 4.0), VINE),
        B((3.0, -1.2, 23.0), (0.3, 0.2, 3.0), VINE),
        B((-16.8, -6.0, 4.0), (0.3, 0.3, 7.0), VINE),
        B((16.8, 4.0, 4.5), (0.3, 0.3, 8.0), VINE),
        B((-13.3, 2.0, 9.5), (0.3, 0.3, 6.0), VINE),
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


KIT = [
    ("JungleTemple", jungle_temple),
    ("IdolPedestal", idol_pedestal),
    ("JungleTree", jungle_tree),
    ("JunglePalm", jungle_palm),
    ("JungleFern", jungle_fern),
    ("JungleTorch", jungle_torch),
    ("JungleRuin", jungle_ruin),
]

LINEUPS = {
    "jungle_kit.png": (["IdolPedestal", "JungleFern", "JungleTorch", "JungleRuin", "JunglePalm", "JungleTree"], ["JungleTemple"]),
}
