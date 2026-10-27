"""Lot kit: the sound stage (LotModels.soundStage) as Blender meshes, one look for every lot.

  LotStage        the hangar: plinth, cream walls with pilasters, burgundy bands and roof ribs,
                  the navy sliding door with gold stripes, side door, louvres, downpipes, a ladder
                  up the back, and rooftop clutter (vent fan, AC unit, exhaust pipes, a dish)
  LotStageAccent  the barrel roof and the side door's canopy, modelled WHITE: the game tints it
                  per lot (LOT_COLORS), and tints both meshes grey on a free lot

Signs stay small parts placed by the game: the gold number plate, the side numbers, ON AIR and
the neon light strip over the door. Same footprint and colors as the part build (12 x 14 plinth,
11 x 13 walls, 7 tall, roof radius 5.7). Blender axes, in studs: Z up, faces -Y, standing on Z = 0
(Roblox x = -Blender x, so the side door at Roblox +x is at Blender -x here).

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/lot_stage_kit.py
Writes art/exports/lot_stage_kit.fbx and art/previews/lot_kit_stage.png, and prints each mesh's
bounds in Roblox axes for STAGE_MESH in src/shared/Models/LotModels.luau.
KIT_SAMPLES for quicker renders, KIT_NO_RENDER=1 to skip the render.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, K, shade  # noqa: E402
from mascots import stage  # noqa: E402

STUD = mmkit.STUD
MAX_TRIS = 1500  # per mesh; five stages share a lot's 12,000

W, D, H = 11, 13, 7
TOP = 0.6 + H  # wall top, roof axis height
R = 5.7  # roof radius
FRONT = -D / 2
WHITE = "#FFFFFF"


def BV(at, size, color, bevel=0.1):
    return B(at, size, color, bevel=bevel)


def louvre(x, y, z):
    out = 1 if x > 0 else -1
    s = [B((x + out * 0.08, y, z), (0.16, 1.4, 0.9), "Steel")]
    for k in range(2):
        s.append(B((x + out * 0.2, y, z - 0.18 + k * 0.36), (0.1, 1.2, 0.1), "Charcoal"))
    return s


def stage_body():
    s = [
        B((0, 0, 0.3), (W + 1, D + 1, 0.6), "Paving"),
        B((0, 0, 0.6 + H / 2), (W, D, H), "Cream"),
        BV((0, 0, 1.1), (W + 0.3, D + 0.3, 1), "Burgundy"),
        BV((0, 0, TOP - 0.4), (W + 0.4, D + 0.4, 0.8), "Burgundy"),
        B((0, 0, TOP - 0.9), (W + 0.16, D + 0.16, 0.2), "OffWhite"),
    ]
    # Roof ribs.
    for y in (FRONT + 0.2, 0, -FRONT - 0.2):
        s.append(C((0, y, TOP), R + 0.2, 0.5, "Burgundy", rot=(90, 0, 0), seg=14))
    s.append(B((0, 0, TOP + R + 0.05), (0.7, D - 0.6, 0.2), "Steel"))  # ridge cap
    # Pilasters on the corners and the side walls.
    pil = shade("Cream", 0.08)
    for x in (-1, 1):
        for y in (FRONT + 0.4, -FRONT - 0.4, 1.5):
            s.append(B((x * (W / 2 + 0.1), y, 4.2), (0.25, 0.7, 5.2), pil))
        s += louvre(x * W / 2, 4.0, 6.0)
        # Downpipes at the front and back corners.
        for y in (FRONT + 1.0,):
            s.append(C((x * (W / 2 + 0.25), y, 3.8), 0.14, 6.4, "Steel", seg=6))
    # Big sliding door.
    s += [
        BV((0, FRONT - 0.1, 3.8), (7.2, 0.3, 6.4), "Burgundy", 0.08),
        B((0, FRONT - 0.25, 3.5), (6.4, 0.3, 5.8), "Navy"),
        B((0, FRONT - 0.42, 3.5), (0.12, 0.1, 5.8), "Charcoal"),
        B((0, FRONT - 0.4, 6.72), (8.0, 0.2, 0.2), "Steel"),  # track
    ]
    for i in (1, 2, 3):
        s.append(B((0, FRONT - 0.45, 0.6 + i * 1.45), (6.4, 0.1, 0.25), "Gold"))
    for x in (-0.35, 0.35):
        s.append(B((x, FRONT - 0.5, 3.2), (0.18, 0.2, 0.9), "Steel"))
    # Wall lamps either side of the door.
    for x in (-4.6, 4.6):
        s += [
            B((x, FRONT - 0.2, 5.0), (0.2, 0.4, 0.2), "Steel"),
            B((x, FRONT - 0.45, 4.8), (0.5, 0.4, 0.4), "Light"),
        ]
    # Number plate frame on the roof front (the gold plate itself is a part).
    s.append(B((0, FRONT - 0.15, TOP + 2.3), (4.1, 0.2, 4.1), "Burgundy"))
    s.append(B((0, FRONT - 0.25, TOP + 0.05), (9.6, 0.4, 0.15), "Steel"))  # light strip ledge
    # Side door (Roblox +x) with a step.
    s += [
        B((-W / 2 - 0.05, 3, 2.4), (0.25, 2.5, 3.9), "Burgundy"),
        B((-W / 2 - 0.17, 3, 2.3), (0.2, 2.0, 3.4), "Navy"),
        B((-W / 2 - 0.35, 2.4, 2.2), (0.15, 0.15, 0.5), "Gold"),
        BV((-W / 2 - 0.6, 3, 0.75), (1.0, 2.6, 0.3), shade("Paving", 0.1), 0.05),
    ]
    # Back wall: ladder to the roof and a breaker box.
    for x in (2.6, 3.6):
        s.append(B((x, -FRONT + 0.35, 4.9), (0.12, 0.12, 6.6), "Steel"))
    for k in range(5):
        s.append(B((3.1, -FRONT + 0.35, 2.2 + k * 1.3), (1.0, 0.1, 0.1), "Steel"))
    s += [
        B((-3.0, -FRONT + 0.2, 2.8), (1.6, 0.4, 1.8), "Steel"),
        B((-3.0, -FRONT + 0.42, 2.8), (1.2, 0.05, 1.3), "Charcoal"),
    ]
    # Rooftop clutter.
    s += [
        B((2.5, 2.6, 12.4), (2, 2, 1.3), "Steel"),
        C((2.5, 2.6, 13.1), 0.75, 0.15, "Charcoal", seg=10),
        B((2.5, 2.6, 13.2), (1.5, 0.12, 0.08), "Steel"),
        B((-2.3, -2.6, 12.9), (1.8, 1.4, 1.0), "OffWhite"),
        B((-2.3, -3.32, 12.9), (1.3, 0.05, 0.7), "Charcoal"),
        C((-0.6, 4.6, 13.6), 0.2, 1.2, "Steel", seg=6),
        K((-0.6, 4.6, 14.3), 0.32, 0.05, 0.3, "Steel", seg=6),
        C((-2.6, 4.2, 13.0), 0.08, 1.2, "Steel", seg=6),
        K((-2.6, 4.0, 13.7), 0.6, 0.15, 0.3, "OffWhite", rot=(-60, 0, 0), seg=10),
    ]
    return s


def stage_accent():
    return [
        C((0, 0, TOP), R, D + 0.4, WHITE, rot=(90, 0, 0), seg=20),
        BV((-W / 2 - 0.7, 3, 4.2), (1.4, 2.8, 0.3), WHITE, 0.06),
    ]


KIT = [("LotStage", stage_body), ("LotStageAccent", stage_accent)]


def roblox_bounds(obj):
    lo, hi = map_kit.bounds(obj)
    size = (hi.x - lo.x, hi.z - lo.z, hi.y - lo.y)
    center = (-(lo.x + hi.x) / 2, (lo.z + hi.z) / 2, (lo.y + hi.y) / 2)
    return size, center


def tint(obj, color):
    """Preview only: multiply every material by a color (what MeshPart.Color does in Roblox)."""
    for mat in obj.data.materials:
        base = mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
        base.default_value = [a * b for a, b in zip(base.default_value[:3], color)] + [1]


def main():
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    for name, builder in KIT:
        obj, _ = map_kit.build(name, builder, lift_to_ground=False)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        size, center = roblox_bounds(obj)
        print(f"{name}: {tris} tris, size {tuple(round(v, 3) for v in size)}, center {tuple(round(v, 3) for v in center)}")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(mmkit.EXPORTS, "lot_stage_kit.fbx")
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, global_scale=1 / (STUD * 100), apply_unit_scale=True,
        bake_space_transform=True, colors_type="SRGB", axis_forward="-Y", axis_up="Z",
        mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    print("Exported", path)
    if os.environ.get("KIT_NO_RENDER"):
        return

    # Preview: a red owned stage, a blue one from the back, and a free one (grey, steel roof).
    import math

    bpy.ops.wm.read_factory_settings(use_empty=True)
    grey = mmkit.hex_to_linear("#A7A9AC")[:3]
    looks = [("#C8202F", None, -30), ("#2E86DE", None, 150), (None, grey, -30)]
    shown = []
    for k, (accent, all_tint, turn) in enumerate(looks):
        for name, builder in KIT:
            o, _ = map_kit.build(name, builder, lift_to_ground=False)
            if all_tint is not None:
                tint(o, all_tint if name == "LotStage" else mmkit.hex_to_linear("#6E7078")[:3])
            elif name == "LotStageAccent":
                tint(o, mmkit.hex_to_linear(accent)[:3])
            o.location = (STUD * (k - 1) * 19, 0, 0)
            o.rotation_euler = (0, 0, math.radians(turn))
            shown.append(o)
    stage(shown, "lot_kit_stage.png", 1800, 900, 0.95, 18)


if __name__ == "__main__":
    main()
