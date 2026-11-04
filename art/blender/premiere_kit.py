"""Premiere kit: the pieces for the red-carpet premiere show at the Grand Premiere Theatre
(src/client/PremiereShow.luau plays the show on each player's own screen; the velvet ropes stand
on the theatre forecourt for everyone, TownSets.theatre).

  VelvetRopePost    a gold stanchion (about 2.8 studs tall); the rope hooks sit 2.3 up
  VelvetRopeSpan    a sagging burgundy rope between two posts 4 studs apart, its ends at the
                    origin's x = +-2 and 2.3 up (place it midway between two posts)
  FanSignHeart      a heart placard on a stick, held like townlife_kit's FanSign (grip at the origin)
  FanSignBlank      a blank placard (spot Sign) the game letters the studio's name on
  MarqueeFlipBoard  the theatre marquee's result board, centred on the origin so it can spin about
                    its long axis; spots Front (faces -Y) and Back (faces +Y)
  GrandTrophy       the Masterpiece trophy on its plinth (about 6.5 studs tall)
  FireworkMortar    three firework tubes on a crate, set on the theatre roof
  RainCloud         a grumpy little raincloud for a Flop (hangs in the air; origin at its middle)

Written in the map kit's shape language (kitdsl.py), built with map_kit.py's mesh code, into its own
files: art/exports/premiere_kit.fbx (import once, drop the model into ReplicatedStorage > LotMeshes
as PremiereKit) and src/shared/Models/PremiereShapes.luau, which the game builds as parts until the
meshes are imported. Chunky toy style (ART_STYLE.md). Blender axes, in studs: Z up, the model faces -Y.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/premiere_kit.py
KIT_NO_RENDER=1 skips the preview (art/previews/premiere_kit.png).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import crew_kit  # noqa: E402
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, K, L, S, T, shade  # noqa: E402

INK = "#2E2C34"
VELVET = "#8E1C2C"
HOOK = 2.3  # rope hook height on a post
SPAN = 4.0  # post spacing the rope span is made for


def rope_post():
    return [
        C((0, 0, 0.12), 0.75, 0.24, "Gold", seg=14),
        C((0, 0, 0.3), 0.45, 0.14, shade("Gold", 0.15), seg=12),
        C((0, 0, 1.4), 0.16, 2.1, "Gold", seg=8),
        C((0, 0, HOOK), 0.24, 0.16, shade("Gold", 0.15), seg=10),
        E((0, 0, 2.62), (0.32, 0.32, 0.32), "Gold"),
    ]


def rope_span():
    """Five straight pieces along a gentle sag, ends at x = +-SPAN/2 (inside the post hooks)."""
    s = []
    n, sag, half = 5, 0.55, SPAN / 2 - 0.2
    pts = [(-half + 2 * half * i / n, HOOK - sag * (1 - (2 * i / n - 1) ** 2)) for i in range(n + 1)]
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        length = math.hypot(x1 - x0, z1 - z0)
        tilt = math.degrees(math.atan2(z1 - z0, x1 - x0))
        s.append(C(((x0 + x1) / 2, 0, (z0 + z1) / 2), 0.13, length + 0.08, VELVET, rot=(0, 90 - tilt, 0), seg=6))
    s += [B((x, 0, HOOK - 0.05), (0.14, 0.14, 0.3), "Gold") for x in (-half, half)]  # the clips
    return s


def fan_sign_heart():
    s = [C((0, 0, -1.4), 0.08, 2.8, "Wood", seg=6), crew_kit.BV((0, 0, -3.2), (2.4, 0.12, 1.6), "OffWhite", bevel=0.05)]
    for y in (-0.08, 0.08):
        s += [
            # Held up, -Z is up: the lobes sit high and the point hangs toward the stick.
            E((-0.3, y, -3.4), (0.38, 0.03, 0.38), "Carpet"),
            E((0.3, y, -3.4), (0.38, 0.03, 0.38), "Carpet"),
            B((0, y, -3.1), (0.68, 0.03, 0.68), "Carpet", rot=(0, 45, 0)),
        ]
    return s


def fan_sign_blank():
    return [
        C((0, 0, -1.4), 0.08, 2.8, "Wood", seg=6),
        crew_kit.BV((0, 0, -3.2), (3.0, 0.12, 1.7), "OffWhite", bevel=0.05),
        B((0, -0.07, -2.47), (2.9, 0.03, 0.12), "Gold"),
        B((0, -0.07, -3.93), (2.9, 0.03, 0.12), "Gold"),
        T((0, -0.08, -3.2), (2.7, 0.02, 1.3), "Sign"),
    ]


def marquee_flip_board():
    """The marquee's result board (the theatre's Marquee spot is 23 x 2.4): front and back faces
    lettered by the game, a chunky gold frame with bulbs round both faces."""
    w, h, d = 23.6, 3.0, 0.5
    s = [
        crew_kit.BV((0, 0, 0), (w, d, h), "Burgundy", bevel=0.12),
        B((0, 0, h / 2 + 0.12), (w + 0.3, d + 0.12, 0.24), "Gold"),
        B((0, 0, -h / 2 - 0.12), (w + 0.3, d + 0.12, 0.24), "Gold"),
        B((w / 2 + 0.12, 0, 0), (0.24, d + 0.12, h + 0.48), "Gold"),
        B((-w / 2 - 0.12, 0, 0), (0.24, d + 0.12, h + 0.48), "Gold"),
        T((0, -d / 2 - 0.01, 0), (w - 0.8, 0.02, h - 0.6), "Front"),
        T((0, d / 2 + 0.01, 0), (w - 0.8, 0.02, h - 0.6), "Back", rot=(0, 0, 180)),
    ]
    for side in (-1, 1):
        for i in range(12):
            x = -w / 2 + 1 + i * (w - 2) / 11
            s += [B((x, side * (d / 2 + 0.06), z), (0.28, 0.08, 0.28), "Light", neon=True) for z in (h / 2 - 0.12, -h / 2 + 0.12)]
    return s


def grand_trophy():
    s = [
        crew_kit.BV((0, 0, 0.6), (3.6, 3.6, 1.2), "Burgundy", bevel=0.12),
        B((0, -1.81, 0.6), (2.6, 0.05, 0.5), "Gold"),
        crew_kit.BV((0, 0, 1.35), (2.6, 2.6, 0.3), "Gold", bevel=0.08),
        C((0, 0, 1.75), 0.9, 0.5, shade("Gold", 0.12), seg=14),
        K((0, 0, 2.45), 0.55, 0.25, 0.9, "Gold", seg=12),
        C((0, 0, 3.05), 0.38, 0.3, shade("Gold", 0.12), seg=12),
        # The cup: wide at the rim, narrowing to the stem.
        K((0, 0, 4.15), 0.5, 1.35, 1.9, "Gold", seg=16),
        C((0, 0, 5.1), 1.4, 0.18, shade("Gold", -0.25), seg=16),
        S((0, -0.3, 6.0), 0.75, 0.3, "Gold"),
        S((0, -0.47, 6.0), 0.4, 0.06, "Light", neon=True),
    ]
    # Two chunky handles, three blocks each, curling out from the cup.
    for side in (-1, 1):
        s += [
            B((side * 1.45, 0, 4.75), (0.8, 0.32, 0.3), "Gold"),
            B((side * 1.75, 0, 4.25), (0.3, 0.32, 1.0), "Gold"),
            B((side * 1.3, 0, 3.75), (0.9, 0.32, 0.3), "Gold"),
        ]
    return s


def firework_mortar():
    s = [crew_kit.BV((0, 0, 0.45), (2.4, 1.6, 0.9), "Wood", bevel=0.06), B((0, -0.81, 0.45), (2.0, 0.04, 0.3), "Carpet")]
    for x, color, tall in ((-0.7, "Carpet", 1.6), (0.05, "Blue", 2.0), (0.75, "Gold", 1.4)):
        s += [
            C((x, 0, 0.9 + tall / 2), 0.32, tall, color, seg=10),
            C((x, 0, 0.9 + tall - 0.1), 0.34, 0.12, "OffWhite", seg=10),
            C((x, 0, 0.9 + tall + 0.02), 0.22, 0.06, INK, seg=8),
        ]
    s.append(C((0.05, -0.2, 3.25), 0.03, 0.5, INK, rot=(20, 0, 0), seg=4))  # a fuse
    return s


def rain_cloud():
    grey, dark = "#7A869C", "#5E687C"
    return [
        L((0, 0, 0), (2.2, 1.4, 1.1), grey),
        L((-1.7, 0.1, -0.2), (1.4, 1.1, 0.85), grey),
        L((1.8, 0, -0.15), (1.5, 1.15, 0.9), grey),
        L((0.5, 0.2, 0.75), (1.3, 1.0, 0.8), shade(grey, -0.1)),
        B((0, 0, -0.85), (4.6, 1.6, 0.5), dark),
        # A grumpy face on the front.
        B((-0.55, -1.38, 0.15), (0.32, 0.06, 0.12), INK, rot=(0, 15, 0)),
        B((0.55, -1.38, 0.15), (0.32, 0.06, 0.12), INK, rot=(0, -15, 0)),
        B((0, -1.38, -0.35), (0.6, 0.06, 0.1), INK),
    ]


KIT = [
    ("VelvetRopePost", rope_post),
    ("VelvetRopeSpan", rope_span),
    ("FanSignHeart", fan_sign_heart),
    ("FanSignBlank", fan_sign_blank),
    ("MarqueeFlipBoard", marquee_flip_board),
    ("GrandTrophy", grand_trophy),
    ("FireworkMortar", firework_mortar),
    ("RainCloud", rain_cloud),
]
# Held signs keep the grip, the span its hook height, the board and cloud their middle.
GROUNDED = {"VelvetRopePost", "GrandTrophy", "FireworkMortar"}

LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "PremiereShapes.luau")
FBX_OUT = os.path.join(mmkit.EXPORTS, "premiere_kit.fbx")
MAX_TRIS = 1500


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    results, objs = [], []
    for name, builder in KIT:
        obj, flat = map_kit.build(name, builder, lift_to_ground=name in GROUNDED)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lo, hi = map_kit.bounds(obj)
        size = hi - lo
        print(f"{name}: {tris} tris, {size.x:.1f} x {size.y:.1f} x {size.z:.1f} studs")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        results.append((name, flat, (lo, hi)))
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    map_kit.LUAU_OUT = LUAU_OUT
    map_kit.write_luau(results)
    with open(LUAU_OUT) as f:
        text = f.read()
    text = text.replace("MapKitShapes", "PremiereShapes").replace(
        "GENERATED by art/blender/map_kit.py from the Blender map kit (map_kit.py and town_kit.py).",
        "GENERATED by art/blender/premiere_kit.py (the premiere show's props and the forecourt ropes).",
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
        preview()


def preview():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = dict(KIT)
    shown = []

    def put(name, x, y, z=None, rot=(0, 0, 0)):
        o = map_kit.build(name, kit[name], lift_to_ground=name in GROUNDED)[0]
        lo, _ = map_kit.bounds(o)
        lift = z if z is not None else (0 if name in GROUNDED else -lo.z + 0.2)
        o.location = (mmkit.STUD * x, mmkit.STUD * y, mmkit.STUD * lift)
        o.rotation_euler = tuple(math.radians(r) for r in rot)
        shown.append(o)

    for i in range(3):
        put("VelvetRopePost", -14 + i * SPAN, -6)
    for i in range(2):
        put("VelvetRopeSpan", -12 + i * SPAN, -6, 0)
    put("MarqueeFlipBoard", 0, 8, 9)
    put("GrandTrophy", 0, -2)
    put("FireworkMortar", 7, -2)
    put("RainCloud", 9, 4, 8)
    put("FanSignHeart", -4, -7, 4.2, (180, 0, 0))
    put("FanSignBlank", -1, -7.5, 4.2, (180, 0, 0))
    map_kit.stage(shown, "premiere_kit.png", 1600, 1000, 0.95, 16)


if __name__ == "__main__":
    main()
