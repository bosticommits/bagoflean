"""Lot kit: the lot's dressing (LotModels hedges, gate, lamp, kiosk, stanchions, billboard, trophy
case and pedestal) as Blender meshes. Same shapes and colors as the part build, with bevels,
trims and small details.

  LotHedgeSide   one side hedge (front corner to back corner) with its three cream pillars
  LotHedge       a plain hedge run (back and front runs); the game stretches it to each run's length
  LotGatePost    one gate post (the game places it on both sides)
  LotLamp        lamp post with a lantern cage (the glowing head stays a part)
  LotKiosk       the BOX OFFICE booth
  LotStanchions  both rows of gold stanchions with sagging velvet ropes; stretched to the carpet
  LotBillboard   the billboard frame on its posts (the board itself stays a part, for the portrait)
  LotTrophyCase  the trophy cabinet (stretched to fit the trophies shown)
  LotPedestal    the top star's pedestal (the glow ring stays a part)

Signs and glows stay small parts placed by the game: gate lamps and number badges, the lamp
heads, the kiosk sign and topper, the billboard board and spotlights, the pedestal ring.
Blender axes, in studs: Z up, faces -Y, standing on Z = 0 (Roblox x = -Blender x, Roblox z =
Blender y). Every piece is symmetric left to right.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/lot_dressing_kit.py
Writes art/exports/lot_dressing_kit.fbx and art/previews/lot_kit_dressing.png, and prints each
mesh's bounds in Roblox axes for DRESS_MESH in src/shared/Models/LotModels.luau.
KIT_SAMPLES for quicker renders, KIT_NO_RENDER=1 to skip the render.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, K, S, W, shade  # noqa: E402
from mascots import stage  # noqa: E402

STUD = mmkit.STUD
MAX_TRIS = 1000  # per mesh; the whole dressing should stay well under a lot's 12,000

# Lot layout (LotModels.Layout): size 56, so a side hedge runs 54.2 between corner pillars.
SIDE = 56 - 1.8
HEDGE = 27.1  # LotHedge's own length; the game stretches it per run
H = 2.6  # hedge height


def BV(at, size, color, bevel=0.1):
    return B(at, size, color, bevel=bevel)


def hedge_run(length, along_y=False):
    def at(u, v, z):
        return (v, u, z) if along_y else (u, v, z)

    def size(lu, lv, lz):
        return (lv, lu, lz) if along_y else (lu, lv, lz)

    return [
        B(at(0, 0, 0.1), size(length + 0.2, 2.0, 0.2), shade("DarkGreen", 0.35)),
        BV(at(0, 0, H / 2), size(length, 1.8, H), "DarkGreen", 0.3),
        BV(at(0, 0, H + 0.25), size(length + 0.2, 2.0, 0.5), "Green", 0.2),
        B(at(0, 0, H + 0.53), size(length - 0.4, 1.0, 0.1), "LeafLight"),
    ]


def pillar(y):
    s = [
        B((0, y, 0.2), (2.7, 2.7, 0.4), shade("Cream", 0.12)),
        BV((0, y, 2.1), (2.4, 2.4, 4.2), "Cream", 0.12),
        B((0, y, 3.75), (2.5, 2.5, 0.18), "Gold"),
        BV((0, y, 4.5), (2.8, 2.8, 0.6), "Burgundy", 0.12),
        K((0, y, 5.05), 0.6, 0.12, 0.5, "Gold", seg=6),
    ]
    for x in (-1, 1):  # recessed panels on the faces you see from the lot and the path
        s.append(B((x * 1.21, y, 2.0), (0.04, 1.5, 2.6), shade("Cream", 0.08)))
    return s


def hedge_side():
    s = hedge_run(SIDE, along_y=True)
    for y in (-SIDE / 2, 0, SIDE / 2):
        s += pillar(y)
    return s


def hedge():
    return hedge_run(HEDGE)


def gate_post():
    s = [
        BV((0, 0, 1.0), (3.4, 3.4, 2.0), "Burgundy", 0.12),
        B((0, 0, 2.05), (3.5, 3.5, 0.2), "Gold"),
        BV((0, 0, 5.5), (2.6, 2.6, 7.0), "Cream", 0.1),
        B((0, 0, 8.7), (2.9, 2.9, 0.3), shade("Cream", 0.1)),
        BV((0, 0, 9.4), (3.2, 3.2, 0.8), "Burgundy", 0.12),
        C((0, 0, 9.95), 0.6, 0.3, "Gold", seg=10),
        B((0, -1.35, 6.0), (2.4, 0.2, 2.4), "Burgundy"),  # frame behind the gold number badge
    ]
    for x in (-1, 1):  # side panels and a gold pinstripe
        s.append(B((x * 1.31, 0, 5.3), (0.04, 1.8, 5.0), shade("Cream", 0.08)))
    s.append(B((0, 1.31, 5.3), (1.8, 0.04, 5.0), shade("Cream", 0.08)))
    s.append(B((0, -1.32, 3.2), (1.8, 0.04, 0.12), "Gold"))
    return s


def lamp():
    h = 9
    s = [
        BV((0, 0, 0.5), (1.4, 1.4, 1.0), "Charcoal", 0.1),
        K((0, 0, 1.3), 0.45, 0.25, 0.6, "Charcoal", seg=8),
        C((0, 0, h / 2), 0.25, h, "Charcoal", seg=8),
        C((0, 0, 3.0), 0.33, 0.25, "Gold", seg=8),
        C((0, 0, h - 0.1), 0.4, 0.3, "Charcoal", seg=8),
        B((0, 0, h + 0.2), (1.5, 1.5, 0.2), "Charcoal"),
        B((0, 0, h + 2.1), (1.6, 1.6, 0.4), "Charcoal"),
        K((0, 0, h + 2.55), 0.75, 0.1, 0.5, "Charcoal", rot=(0, 0, 45), seg=4),
    ]
    for x in (-1, 1):  # lantern cage round the glowing head
        for y in (-1, 1):
            s.append(B((x * 0.66, y * 0.66, h + 1.1), (0.14, 0.14, 1.8), "Charcoal"))
    return s


def kiosk():
    s = [
        BV((0, 0, 0.5), (3.6, 3.0, 1.0), "Burgundy", 0.1),
        BV((0, 0, 2.5), (3.2, 2.6, 3.0), "Cream", 0.08),
        B((0, -1.31, 2.8), (2.4, 0.06, 1.6), "Gold"),
        B((0, -1.35, 2.8), (2.2, 0.06, 1.4), "Glass"),
        B((0, -1.39, 2.8), (0.08, 0.04, 1.4), "OffWhite"),
        BV((0, -1.5, 2.1), (2.6, 0.6, 0.2), "Wood", 0.05),
        B((0, -1.42, 1.85), (2.2, 0.3, 0.3), shade("Wood", 0.2)),
        W((0, -0.9, 4.6), (4.0, 1.8, 1.2), "Carpet"),
        W((0, 0.9, 4.6), (4.0, 1.8, 1.2), "Carpet", rot=(0, 0, 180)),
        B((0, 0, 5.22), (4.1, 0.3, 0.14), "Gold"),
        C((0, 0, 5.25), 0.25, 0.3, "Gold", seg=8),
        B((0, 1.31, 2.1), (1.1, 0.06, 2.1), "Wood"),  # back door
    ]
    for y in (-1, 1):
        s.append(B((0, y * 1.82, 4.03), (4.1, 0.16, 0.16), "Burgundy"))  # eaves
    for x in (-1, 1):
        s.append(B((x * 1.61, 0, 2.5), (0.04, 1.6, 2.0), shade("Cream", 0.08)))
        for y in (-1, 1):
            s.append(B((x * 1.6, y * 1.3, 2.5), (0.22, 0.22, 3.0), "Burgundy"))
    return s


STAN_LEN = 15  # LotModels.Layout: stanchions from z -13 to 2
STAN_X = 3.8


def stanchions():
    s = []
    posts = [-STAN_LEN / 2 + i * 5 for i in range(4)]
    for x in (-STAN_X, STAN_X):
        for y in posts:
            s += [
                K((x, y, 0.1), 0.4, 0.28, 0.2, "Gold", seg=8),
                C((x, y, 1.15), 0.16, 1.9, "Gold", seg=6),
                C((x, y, 2.12), 0.24, 0.12, "Gold", seg=6),
                K((x, y, 2.4), 0.3, 0.06, 0.45, "Gold", seg=6),
            ]
        for a, b in zip(posts, posts[1:]):
            half = (b - a) / 2
            sag = 0.3
            tilt = math.degrees(math.atan2(sag, half))
            length = math.hypot(half, sag) + 0.1
            for k, sign in ((0, -1), (1, 1)):
                y = a + half * (k + 0.5)
                s.append(B((x, y, 1.9 - sag / 2), (0.22, length, 0.22), "Burgundy", rot=(sign * tilt, 0, 0)))
    return s


LIFT = 8  # LotModels.Layout.billboardLift


def billboard():
    up = LIFT
    s = []
    for x in (-4.5, 4.5):
        s += [
            BV((x, 0.4, 0.5), (1.8, 1.8, 1.0), "Charcoal", 0.1),
            B((x, 0.4, 7 + up / 2), (0.9, 0.9, 12 + up), "Steel"),
        ]
    # Cross bracing between the posts.
    rise, span = 12, 9
    ang = math.degrees(math.atan2(rise, span))
    for sign in (-1, 1):
        s.append(B((0, 0.4, 3 + rise / 2), (math.hypot(rise, span), 0.25, 0.25), "Steel", rot=(0, sign * ang, 0)))
    # Ladder up the left post (Roblox +x).
    for x in (-4.5 - 0.35, -4.5 + 0.35):
        s.append(B((x, -0.25, 3 + (up + 7.9) / 2), (0.1, 0.1, up + 7.9), "Charcoal"))
    for k in range(8):
        s.append(B((-4.5, -0.25, 2.5 + k * 2), (0.8, 0.08, 0.08), "Charcoal"))
    # Catwalk with a rail.
    s += [
        B((0, -0.6, 10.9 + up), (13, 1.6, 0.3), "Steel"),
        B((0, -1.35, 11.9 + up), (13, 0.1, 0.1), "Charcoal"),
    ]
    for x in (-6.4, -2.1, 2.1, 6.4):
        s.append(B((x, -1.35, 11.45 + up), (0.1, 0.1, 0.9), "Charcoal"))
    # Burgundy back frame with a gold border round the board, and a gold star on top.
    s.append(BV((0, 0.4, 15.5 + up), (14, 0.6, 9), "Burgundy", 0.12))
    for z in (11.25 + up, 19.75 + up):
        s.append(B((0, 0.05, z), (13.8, 0.12, 0.2), "Gold"))
    for x in (-6.75, 6.75):
        s.append(B((x, 0.05, 15.5 + up), (0.2, 0.12, 8.6), "Gold"))
    s.append(S((0, 0.4, 20.75 + up), 1.0, 0.3, "Gold"))
    # Spotlight arms and housings (the lenses are glowing parts).
    for x in (-4, 4):
        s += [
            B((x, -0.8, 20.3 + up), (0.3, 2.0, 0.3), "Charcoal"),
            B((x, -1.65, 20.3 + up), (1.4, 0.4, 1.0), "Charcoal"),
        ]
    return s


CASE_W = 2 + 5 * 1.5  # five trophies shown; the game stretches it for fewer


def trophy_case():
    w = CASE_W
    return [
        B((0, 0, 0.125), (w - 0.2, 2.2, 0.25), shade("Wood", 0.3)),
        BV((0, 0, 0.875), (w, 2.4, 1.25), "Wood", 0.06),
        B((0, -1.21, 0.85), (w - 1.0, 0.04, 0.8), shade("Wood", 0.15)),
        B((0, -1.23, 0.85), (w - 1.3, 0.04, 0.5), shade("Wood", -0.08)),
        B((0, -1.22, 1.38), (w - 0.6, 0.05, 0.08), "Gold"),
        BV((0, 0, 1.65), (w + 0.2, 2.6, 0.3), "Burgundy", 0.06),
    ]


def pedestal():
    return [
        K((0, 0, 0.3), 3.1, 2.95, 0.6, "Burgundy", seg=20),
        C((0, 0, 0.62), 2.98, 0.06, "Gold", seg=20),
        C((0, 0, 1.3), 2.5, 0.6, "Cream", seg=20),
        C((0, 0, 1.06), 2.56, 0.12, "Gold", seg=20),
        S((0, 0, 1.6), 1.3, 0.04, "Gold", rot=(90, 0, 0)),
    ]


KIT = [
    ("LotHedgeSide", hedge_side),
    ("LotHedge", hedge),
    ("LotGatePost", gate_post),
    ("LotLamp", lamp),
    ("LotKiosk", kiosk),
    ("LotStanchions", stanchions),
    ("LotBillboard", billboard),
    ("LotTrophyCase", trophy_case),
    ("LotPedestal", pedestal),
]


# Preview only: the small parts the game puts on each mesh (glows, signs, the billboard board).
def preview_parts(name):
    glow, gold, navy = "Light", "Gold", "Navy"
    return {
        "LotGatePost": [E((0, 0, 10.6), (0.9, 0.9, 0.9), glow, neon=True), B((0, -1.4, 6.0), (2, 0.4, 2), gold)],
        "LotLamp": [B((0, 0, 10.1), (1.2, 1.2, 1.6), glow, neon=True)],
        "LotKiosk": [E((0, 0, 5.5), (0.45, 0.45, 0.45), gold, neon=True), B((0, -1.35, 3.65), (3, 0.2, 0.8), navy)],
        "LotBillboard": [B((0, 0, 15.5 + LIFT), (13, 0.4, 8), navy)]
        + [B((x, -1.9, 20.3 + LIFT), (1.2, 0.8, 0.8), glow, neon=True) for x in (-4, 4)],
        "LotPedestal": [C((0, 0, 0.8), 2.8, 0.4, "#9B59B6", seg=20, neon=True)],
    }.get(name, [])


def roblox_bounds(obj):
    lo, hi = map_kit.bounds(obj)
    size = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    center = (-(lo.x + hi.x) / 2, (lo.z + hi.z) / 2, (lo.y + hi.y) / 2)
    return size, center


def main():
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    total = 0
    for name, builder in KIT:
        obj, _ = map_kit.build(name, builder, lift_to_ground=False)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        total += tris
        size, center = roblox_bounds(obj)
        r = lambda t: ", ".join(f"{v:g}" for v in (round(x, 3) for x in t))  # noqa: E731
        print(f"{name}: {tris} tris\t{name} = {{ size = v({r(size)}), center = v({r(center)}) }},")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    print("total tris", total)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(mmkit.EXPORTS, "lot_dressing_kit.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, global_scale=1 / (STUD * 100), apply_unit_scale=True,
        bake_space_transform=True, colors_type="SRGB", axis_forward="-Y", axis_up="Z",
        mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    print("Exported", path)
    if os.environ.get("KIT_NO_RENDER"):
        return

    # Preview: a side hedge along the back, a front hedge run, and the props in a row in front
    # (gate posts as a pair, 12 apart like the lot gate), with their parts.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shown = []

    def place(name, builder, x, y, turn=0.0):
        for n, b in ((name, builder), (name + "Parts", lambda: preview_parts(name))):
            if not b():
                continue
            o, _ = map_kit.build(n, b, lift_to_ground=False)
            o.location = (STUD * x, STUD * y, 0)
            o.rotation_euler = (0, 0, math.radians(turn))
            shown.append(o)

    kit = dict(KIT)
    place("LotHedgeSide", kit["LotHedgeSide"], 0, 14, 90)
    place("LotHedge", kit["LotHedge"], -14, 8)
    place("LotBillboard", kit["LotBillboard"], 19, 10)
    place("LotGatePost", kit["LotGatePost"], -24.4, -6)
    place("LotGatePost", kit["LotGatePost"], -9.6, -6)
    place("LotLamp", kit["LotLamp"], -3, -6)
    place("LotKiosk", kit["LotKiosk"], 2, -6)
    place("LotStanchions", kit["LotStanchions"], 10, -5, 30)
    place("LotTrophyCase", kit["LotTrophyCase"], 25, -6)
    place("LotPedestal", kit["LotPedestal"], 34, -6)
    stage(shown, "lot_kit_dressing.png", 2000, 1100, 1.12, 18)


if __name__ == "__main__":
    main()
