"""Halloween kit: the Fright Night season's town decor and the Pumpkin Patch event's pumpkins.

  JackOLantern       a big carved pumpkin with a glowing grin (about 3.4 studs tall)
  JackOLanternSmall  a smaller one with a spooky face (the Pumpkin Patch pickups)
  PumpkinPlain       a squat uncarved pumpkin, for piles
  GoldenPumpkin      the Pumpkin Patch event's golden pumpkin (a free cast)
  HalloweenHayBale   a straw bale (the map kit already has a HayBale) with two bands
  Scarecrow          a friendly scarecrow on a post: sack head, witch hat, patched shirt
  CandyBucket        a pumpkin pail full of sweets

Written in the map kit's shape language (kitdsl.py) and built with map_kit.py's mesh code, but
into its own files: art/exports/halloween_kit.fbx (import once, drop the model into
ReplicatedStorage > LotMeshes) and src/shared/Models/HalloweenShapes.luau, which the game builds
as parts until the meshes are imported. Chunky toy style (ART_STYLE.md); glowing faces are Neon.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/halloween_kit.py
KIT_NO_RENDER=1 skips the preview (art/previews/halloween_kit.png).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, K, W, ring  # noqa: E402

ORANGE = "#FF8A1E"
ORANGE_DARK = "#E0661A"
GOLD = "#FFC21A"
GOLD_DARK = "#E09A10"
STEM = "#5E7A2E"
GLOW = "#FFD84A"  # the candle light inside, on Neon
STRAW = "#F2C75C"
STRAW_DARK = "#D9A43E"
SACK = "#E8CFA0"
HAT = "#5A2E8C"
HAT_BAND = "#FF8A1E"
SHIRT = "#C8202F"
PATCH = "#2E86DE"
POST = "#7A5434"
INK = "#2E2C34"


def tri(at, w, h, color, depth=0.35, down=False):
    """A flat triangle facing -Y, apex up (or down): two mirrored wedges, so the part version
    shows the same triangle."""
    x, y, z = at
    flip = 180 if down else 0
    return [
        W((x + w / 4, y, z), (depth, w / 2, h), color, rot=(flip, 0, 90)),
        W((x - w / 4, y, z), (depth, w / 2, h), color, rot=(flip, 0, -90)),
    ]


def pumpkin_body(r, h, color, dark, ribs=7):
    """A ribbed pumpkin r wide (radius) and h tall, standing on z = 0, with its stem."""
    s = ring(ribs, r * 0.42, h / 2, lambda x, y, a: E((x, y, h / 2), (r * 0.5, r * 0.58, h / 2 * 0.97), color if int(a / (360 / ribs)) % 2 == 0 else dark, rot=(0, 0, -a)), start=360 / ribs / 2)
    s += [
        K((0.05 * r, 0, h + 0.12 * h), 0.13 * r, 0.09 * r, 0.42 * h, STEM, rot=(0, 12, 0), seg=6),
        E((0, 0, h - 0.02), (0.22 * r, 0.22 * r, 0.06 * h), dark),
    ]
    return s


def face(r, h, grin, color=GLOW):
    """The carved face, on the front of a pumpkin_body(r, h)."""
    y = -r * 0.92
    z = h * 0.55
    if grin:
        s = tri((-0.36 * r, y + 0.04 * r, z + 0.12 * h), 0.36 * r, 0.26 * h, color)
        s += tri((0.36 * r, y + 0.04 * r, z + 0.12 * h), 0.36 * r, 0.26 * h, color)
        s += tri((0, y - 0.02 * r, z - 0.06 * h), 0.18 * r, 0.12 * h, color)
        # A wide grin: a bar with two teeth left in, curling up at the ends.
        s += [
            B((0, y + 0.03 * r, z - 0.24 * h), (0.78 * r, 0.4, 0.13 * h), color, neon=True),
            B((-0.48 * r, y + 0.1 * r, z - 0.17 * h), (0.22 * r, 0.4, 0.12 * h), color, rot=(0, -30, 18), neon=True),
            B((0.48 * r, y + 0.1 * r, z - 0.17 * h), (0.22 * r, 0.4, 0.12 * h), color, rot=(0, 30, -18), neon=True),
            B((-0.17 * r, y - 0.01 * r, z - 0.205 * h), (0.12 * r, 0.44, 0.06 * h), ORANGE),
            B((0.17 * r, y - 0.01 * r, z - 0.275 * h), (0.12 * r, 0.44, 0.06 * h), ORANGE),
        ]
    else:
        # Spooky (but friendly): slanted eyes, a little round "ooh" mouth.
        s = [
            B((-0.34 * r, y + 0.03 * r, z + 0.12 * h), (0.34 * r, 0.12, 0.16 * h), color, rot=(0, -18, 0), neon=True),
            B((0.34 * r, y + 0.03 * r, z + 0.12 * h), (0.34 * r, 0.12, 0.16 * h), color, rot=(0, 18, 0), neon=True),
            C((0, y - 0.01 * r, z - 0.2 * h), 0.14 * r, 0.12, color, rot=(90, 0, 0), seg=10, neon=True),
        ]
        for i, x in enumerate((-0.4, 0.4)):
            s += [B((x * r, y + 0.04 * r, z + 0.28 * h), (0.3 * r, 0.12, 0.05 * h), ORANGE_DARK, rot=(0, -20 if i == 0 else 20, 0))]
    for p in s:
        p["neon"] = p["color"] == color
    return s


def jack_o_lantern():
    return pumpkin_body(2.0, 3.0, ORANGE, ORANGE_DARK, ribs=7) + face(2.0, 3.0, grin=True)


def jack_o_lantern_small():
    return pumpkin_body(1.25, 1.9, ORANGE, ORANGE_DARK) + face(1.25, 1.9, grin=False)


def pumpkin_plain():
    return pumpkin_body(1.3, 1.5, ORANGE, ORANGE_DARK, ribs=6)


def golden_pumpkin():
    s = pumpkin_body(1.6, 2.4, GOLD, GOLD_DARK) + face(1.6, 2.4, grin=True, color="#FFF6C8")
    # A little gold leaf curl and a star on the stem.
    s += [E((0.5, 0.1, 2.65), (0.35, 0.18, 0.08), "#7ED35F", rot=(0, -20, 30))]
    return s


def hay_bale():
    s = [B((0, 0, 0.9), (3.6, 2.0, 1.8), STRAW, bevel=0.3)]
    for x in (-0.9, 0.9):
        s.append(B((x, 0, 0.9), (0.3, 2.12, 1.92), STRAW_DARK, bevel=0.08))
    # Straw poking out of the top.
    for i, (x, y) in enumerate(((-1.2, -0.4), (0.2, 0.5), (1.3, -0.2), (-0.3, -0.6))):
        s.append(B((x, y, 1.85), (0.08, 0.08, 0.35), STRAW_DARK, rot=(20 - i * 12, 15 * i, 0)))
    return s


def scarecrow():
    s = [
        B((0, 0.25, 2.6), (0.4, 0.4, 5.2), POST),  # the post
        B((0, 0.25, 4.0), (4.2, 0.35, 0.35), POST),  # the crossbar
        # Shirt over the crossbar, with a patch and buttons.
        B((0, 0, 3.4), (1.8, 0.9, 1.9), SHIRT, bevel=0.15),
        B((-1.4, 0, 3.95), (1.4, 0.75, 0.7), SHIRT, bevel=0.12),
        B((1.4, 0, 3.95), (1.4, 0.75, 0.7), SHIRT, bevel=0.12),
        B((0.45, -0.47, 3.05), (0.5, 0.06, 0.5), PATCH, rot=(0, 8, 0)),
        B((0, -0.46, 2.6), (1.84, 0.08, 0.25), POST),  # rope belt
        E((-0.2, -0.47, 3.75), (0.08, 0.04, 0.08), INK),
        E((-0.2, -0.47, 3.35), (0.08, 0.04, 0.08), INK),
        # Straw hands and a straw skirt under the shirt.
        K((-2.25, 0, 3.95), 0.32, 0.12, 0.5, STRAW, rot=(0, -90, 0), seg=6),
        K((2.25, 0, 3.95), 0.32, 0.12, 0.5, STRAW, rot=(0, 90, 0), seg=6),
        K((0, 0, 2.25), 0.5, 0.95, 0.5, STRAW, seg=8),
        # Sack head with a stitched smile.
        E((0, 0, 5.1), (0.85, 0.8, 0.85), SACK),
        E((-0.3, -0.72, 5.25), (0.13, 0.06, 0.13), INK),
        E((0.3, -0.72, 5.25), (0.13, 0.06, 0.13), INK),
        K((0, -0.8, 5.05), 0.12, 0.02, 0.3, ORANGE, rot=(90, 0, 0), seg=6),  # a carrot nose
        B((0, -0.75, 4.8), (0.6, 0.05, 0.06), INK),
        B((-0.18, -0.76, 4.8), (0.04, 0.05, 0.16), INK),
        B((0.18, -0.76, 4.8), (0.04, 0.05, 0.16), INK),
        B((0, 0, 4.4), (0.5, 0.5, 0.25), STRAW),  # straw at the neck
        # A floppy witch hat.
        C((0, 0, 5.75), 1.25, 0.12, HAT, seg=14),
        K((0, 0, 6.35), 0.75, 0.12, 1.2, HAT, seg=10),
        K((0.12, 0.05, 7.05), 0.16, 0.03, 0.45, HAT, rot=(0, 30, 0), seg=6),
        C((0, 0, 5.92), 0.77, 0.2, HAT_BAND, seg=10),
    ]
    return s


def candy_bucket():
    s = pumpkin_body(0.95, 1.2, ORANGE, ORANGE_DARK, ribs=6)
    s = [p for p in s if p["kind"] != "cone"]  # no stem: it's a pail
    s += face(0.95, 1.2, grin=True, color=INK)
    s += [
        C((0, 0, 1.18), 0.72, 0.08, INK, seg=12),  # the open top
        B((-0.82, 0, 1.55), (0.07, 0.07, 0.75), INK),
        B((0.82, 0, 1.55), (0.07, 0.07, 0.75), INK),
        B((0, 0, 1.95), (1.7, 0.07, 0.07), INK),
    ]
    # Sweets heaped in the top.
    for i, (x, y, col) in enumerate(((-0.3, 0.1, "#FF78AA"), (0.25, -0.15, "#20B2BE"), (0.05, 0.3, "#FFD63C"), (0.35, 0.25, "#A04DFF"), (-0.2, -0.3, "#5BBF5A"))):
        s.append(E((x, y, 1.28 + 0.05 * (i % 2)), (0.2, 0.14, 0.14), col, rot=(0, 0, 40 * i)))
    for p in s:
        if p["color"] == INK:
            p["neon"] = False
    return s


KIT = [
    ("JackOLantern", jack_o_lantern),
    ("JackOLanternSmall", jack_o_lantern_small),
    ("PumpkinPlain", pumpkin_plain),
    ("GoldenPumpkin", golden_pumpkin),
    ("HalloweenHayBale", hay_bale),
    ("Scarecrow", scarecrow),
    ("CandyBucket", candy_bucket),
]

LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "HalloweenShapes.luau")
FBX_OUT = os.path.join(mmkit.EXPORTS, "halloween_kit.fbx")
MAX_TRIS = 2000


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    results, objs = [], []
    for name, builder in KIT:
        obj, flat = map_kit.build(name, builder)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lo, hi = map_kit.bounds(obj)
        size = hi - lo
        print(f"{name}: {tris} tris, {size.x:.1f} x {size.y:.1f} x {size.z:.1f} studs")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        results.append((name, flat, (lo, hi)))
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    # map_kit.write_luau writes MapKitShapes; point it at our own file and module name.
    map_kit.LUAU_OUT = LUAU_OUT
    map_kit.write_luau(results)
    with open(LUAU_OUT) as f:
        text = f.read()
    text = text.replace("MapKitShapes", "HalloweenShapes").replace(
        "GENERATED by art/blender/map_kit.py from the Blender map kit (map_kit.py and town_kit.py).",
        "GENERATED by art/blender/halloween_kit.py (the Fright Night decor and Pumpkin Patch pumpkins).",
    )
    with open(LUAU_OUT, "w") as f:
        f.write(text)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=FBX_OUT, use_selection=True, global_scale=1 / (mmkit.STUD * 100), apply_unit_scale=True,
        bake_space_transform=True, colors_type="SRGB", axis_forward="-Y", axis_up="Z",
        mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    print("Exported", FBX_OUT)

    if not os.environ.get("KIT_NO_RENDER"):
        lineup(["CandyBucket", "PumpkinPlain", "JackOLanternSmall", "JackOLantern", "GoldenPumpkin"], ["HalloweenHayBale", "Scarecrow"], "halloween_kit.png")


def lineup(front, back, file_name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = dict(KIT)
    objs = {n: map_kit.build(n, kit[n])[0] for n in front + back}
    import math

    shown, y = [], 0.0
    for row in (front, back):
        widths = [(map_kit.bounds(objs[n])[1] - map_kit.bounds(objs[n])[0]).x for n in row]
        gap = 1.2
        x = -(sum(widths) + gap * (len(row) - 1)) / 2
        depth = max((map_kit.bounds(objs[n])[1] - map_kit.bounds(objs[n])[0]).y for n in row)
        for n, wd in zip(row, widths):
            o = objs[n]
            lo, hi = map_kit.bounds(o)
            o.location = (mmkit.STUD * (x + wd / 2 - (lo.x + hi.x) / 2), mmkit.STUD * (y - (lo.y + hi.y) / 2), 0)
            o.rotation_euler = (0, 0, math.radians(-14))
            shown.append(o)
            x += wd + gap
        y += depth + 2
    map_kit.stage(shown, file_name, 1600, 1000, 0.95, 16)


if __name__ == "__main__":
    main()
