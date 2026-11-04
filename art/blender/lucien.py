"""Director Lucien Vale, the tutorial's host, as an R15 rig: fifteen body pieces plus his cane.

  LucienLowerTorso   hips and the jacket's skirt (the rig's root, at the hip joint)
  LucienUpperTorso   velvet tuxedo jacket, white shirt front, burgundy lapels piped in gold,
                     a bow tie and a gold star pin
  LucienHead         silver swept-back hair, a trimmed white beard and moustache, gold-rimmed
                     glasses with pale blue lenses
  Lucien<Side>UpperArm, Lucien<Side>LowerArm (white cuff, gold link), Lucien<Side>Hand
  Lucien<Side>UpperLeg, Lucien<Side>LowerLeg (satin stripe), Lucien<Side>Foot
  LucienCane         black cane with a gold knob and tip, held at the knob

Every piece keeps its own joint at the origin (like crew_kit.py): the legs and arms hang down
from the hip, knee, shoulder, elbow and wrist, the torso pieces and the head stand up from the
hip, waist and neck, and the cane hangs from the grip in the right hand.
src/shared/Models/LucienRig.luau puts the pieces together at the joints below (JOINTS, the same
numbers) and turns them for his walk-in, wave, cane twirl, talk gestures and idle.

Written in the map kit's shape language (kitdsl.py) and built with map_kit.py's mesh code, into
its own files: art/exports/lucien.fbx (upload/import once, drop the model into
ReplicatedStorage > LotMeshes as `lucien_kit`) and src/shared/Models/LucienShapes.luau, which the
game builds as parts until the meshes are imported. Colors follow the Figma intro mockups
(navy coat, burgundy lapels, white beard, blue lenses). Blender axes, in studs: Z up, the model
faces -Y, Roblox x = -Blender x, so the figure's right hand is Blender -X.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/lucien.py
KIT_NO_RENDER=1 skips the preview (art/previews/director_lucien_vale.png).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, S, shade  # noqa: E402

NAVY = "#25306A"
TROUSER = "#1B1D2C"
SATIN = "#121218"
BURGUNDY = "#8A1F35"
SILVER = "#E6E8F0"
SKIN = "#E8B48A"
GOLD = "#F5B82E"
LENS = "#A2D6F4"
SHIRT = "#FAF6EC"
INK = "#2E2C34"

# Roblox space joints (studs, feet at y = 0): piece -> (parent, joint offset from the parent's
# joint). Same table as LucienRig.Joints.
JOINTS = {
    "LowerTorso": (None, (0, 2.0, 0)),
    "UpperTorso": ("LowerTorso", (0, 0.55, 0)),
    "Head": ("UpperTorso", (0, 1.45, 0)),
    "RightUpperArm": ("UpperTorso", (1.27, 1.3, 0)),
    "RightLowerArm": ("RightUpperArm", (0, -0.85, 0)),
    "RightHand": ("RightLowerArm", (0, -0.75, 0)),
    "LeftUpperArm": ("UpperTorso", (-1.27, 1.3, 0)),
    "LeftLowerArm": ("LeftUpperArm", (0, -0.85, 0)),
    "LeftHand": ("LeftLowerArm", (0, -0.75, 0)),
    "RightUpperLeg": ("LowerTorso", (0.47, 0, 0)),
    "RightLowerLeg": ("RightUpperLeg", (0, -0.95, 0)),
    "RightFoot": ("RightLowerLeg", (0, -0.75, 0)),
    "LeftUpperLeg": ("LowerTorso", (-0.47, 0, 0)),
    "LeftLowerLeg": ("LeftUpperLeg", (0, -0.95, 0)),
    "LeftFoot": ("LeftLowerLeg", (0, -0.75, 0)),
    "Cane": ("RightHand", (0, -0.25, -0.05)),
}


def BV(at, size, color, rot=(0, 0, 0), bevel=0.08):
    return B(at, size, color, rot, bevel)


def lower_torso():
    return [
        BV((0, 0, 0.22), (1.92, 1.02, 0.72), NAVY, bevel=0.12),
        B((0, 0, -0.1), (1.74, 0.9, 0.12), TROUSER),
        # The jacket opens over the shirt down to the hem, edged by the lapels' burgundy.
        B((0, -0.5, 0.36), (0.46, 0.06, 0.44), SHIRT),
        B((0, -0.52, 0.1), (0.5, 0.06, 0.06), shade(NAVY, 0.25)),
        B((0, -0.53, 0.42), (0.1, 0.04, 0.1), GOLD),
    ]


def upper_torso():
    s = [
        BV((0, 0, 0.72), (2.0, 1.02, 1.46), NAVY, bevel=0.16),
        B((0, -0.5, 0.72), (0.62, 0.06, 1.4), SHIRT),
        # Bow tie and shirt studs.
        B((0, -0.56, 1.3), (0.14, 0.06, 0.14), SATIN),
        B((0, -0.53, 0.86), (0.08, 0.04, 0.08), GOLD),
        B((0, -0.53, 0.56), (0.08, 0.04, 0.08), GOLD),
        S((0.62, -0.55, 1.0), 0.15, 0.05, GOLD),
    ]
    for side in (-1, 1):
        s += [
            BV((side * 0.43, -0.52, 0.76), (0.26, 0.06, 1.34), BURGUNDY, rot=(0, side * -4, 0), bevel=0.03),
            B((side * 0.58, -0.54, 0.76), (0.04, 0.04, 1.3), GOLD, rot=(0, side * -4, 0)),
            B((side * 0.17, -0.56, 1.3), (0.26, 0.05, 0.22), SATIN, rot=(0, side * 12, 0)),
            # Shoulders rounded off over the arms.
            BV((side * 0.98, 0, 1.3), (0.42, 0.98, 0.34), NAVY, bevel=0.14),
        ]
    return s


def head():
    s = [
        C((0, 0, 0.08), 0.34, 0.24, SKIN, seg=10),
        BV((0, 0, 0.86), (1.44, 1.34, 1.44), SKIN, bevel=0.2),
        # Silver hair swept up at the brow and back, short at the sides.
        BV((0, 0.1, 1.62), (1.54, 1.42, 0.34), SILVER, bevel=0.12),
        BV((0, -0.42, 1.74), (1.36, 0.52, 0.3), SILVER, rot=(-14, 0, 0), bevel=0.12),
        BV((0, 0.62, 1.08), (1.52, 0.24, 1.0), SILVER, bevel=0.08),
        # Trimmed white beard round the jaw, a full moustache, and a nose.
        BV((0, -0.62, 0.42), (1.3, 0.22, 0.6), SILVER, bevel=0.08),
        BV((0, -0.66, 0.2), (0.82, 0.26, 0.32), SILVER, bevel=0.1),
        BV((0, -0.74, 0.62), (0.8, 0.12, 0.15), SILVER, bevel=0.05),
        BV((0, -0.74, 0.78), (0.22, 0.14, 0.24), shade(SKIN, 0.08), bevel=0.05),
        # Gold-rimmed glasses with pale blue lenses, eyes behind them.
        BV((0, -0.72, 0.96), (1.24, 0.05, 0.38), GOLD, bevel=0.03),
    ]
    for side in (-1, 1):
        s += [
            BV((side * 0.75, 0.18, 1.08), (0.12, 0.8, 0.62), SILVER, bevel=0.04),
            B((side * 0.3, -0.75, 0.96), (0.44, 0.03, 0.26), LENS),
            B((side * 0.3, -0.77, 0.94), (0.12, 0.02, 0.14), INK),
            B((side * 0.33, -0.73, 1.22), (0.4, 0.06, 0.09), SILVER, rot=(0, side * -6, 0)),
            E((side * 0.74, 0.02, 0.86), (0.08, 0.17, 0.22), shade(SKIN, 0.05)),
        ]
    return s


def upper_arm():
    return [BV((0, 0, -0.38), (0.62, 0.7, 0.98), NAVY, bevel=0.12)]


def lower_arm(outer):
    return [
        BV((0, 0, -0.34), (0.58, 0.66, 0.76), NAVY, bevel=0.1),
        B((0, 0, -0.7), (0.62, 0.7, 0.14), SHIRT),
        B((outer * 0.32, 0, -0.7), (0.05, 0.16, 0.08), GOLD),
    ]


def hand(inner):
    return [
        BV((0, 0, -0.24), (0.46, 0.5, 0.48), SKIN, bevel=0.14),
        BV((inner * 0.21, -0.16, -0.16), (0.14, 0.16, 0.26), SKIN, bevel=0.05),
    ]


def upper_leg():
    return [BV((0, 0, -0.45), (0.8, 0.86, 1.02), TROUSER, bevel=0.1)]


def lower_leg(outer):
    return [
        BV((0, 0, -0.37), (0.74, 0.8, 0.8), TROUSER, bevel=0.08),
        B((outer * 0.375, 0, -0.37), (0.03, 0.22, 0.8), SATIN),
    ]


def foot():
    return [
        BV((0, -0.14, -0.15), (0.8, 1.16, 0.32), SATIN, bevel=0.13),
        B((0, -0.55, -0.02), (0.5, 0.2, 0.04), shade(SATIN, -0.25)),
    ]


def cane():
    return [
        E((0, 0, 0.12), (0.17, 0.17, 0.17), GOLD),
        C((0, 0, -0.05), 0.09, 0.1, GOLD, seg=8),
        C((0, 0, -1.0), 0.065, 1.9, SATIN, seg=8),
        C((0, 0, -1.98), 0.075, 0.1, GOLD, seg=8),
    ]


# The figure's right is Blender -X: a right arm's outer side is -X, its thumb (inner) +X.
KIT = [
    ("LucienLowerTorso", lower_torso),
    ("LucienUpperTorso", upper_torso),
    ("LucienHead", head),
    ("LucienRightUpperArm", upper_arm),
    ("LucienRightLowerArm", lambda: lower_arm(-1)),
    ("LucienRightHand", lambda: hand(1)),
    ("LucienLeftUpperArm", upper_arm),
    ("LucienLeftLowerArm", lambda: lower_arm(1)),
    ("LucienLeftHand", lambda: hand(-1)),
    ("LucienRightUpperLeg", upper_leg),
    ("LucienRightLowerLeg", lambda: lower_leg(-1)),
    ("LucienRightFoot", foot),
    ("LucienLeftUpperLeg", upper_leg),
    ("LucienLeftLowerLeg", lambda: lower_leg(1)),
    ("LucienLeftFoot", foot),
    ("LucienCane", cane),
]

LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "LucienShapes.luau")
FBX_OUT = os.path.join(mmkit.EXPORTS, "lucien.fbx")
MAX_TRIS = 1500  # per piece; the whole figure is drawn alone in a ViewportFrame


def rest_location(piece):
    """The piece's joint in Blender space, standing at rest."""
    x, y, z = 0.0, 0.0, 0.0
    while piece is not None:
        parent, (ox, oy, oz) = JOINTS[piece]
        x, y, z = x + ox, y + oy, z + oz
        piece = parent
    return (-x, z, y)


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    results, objs, total = [], [], 0
    for name, builder in KIT:
        obj, flat = map_kit.build(name, builder, lift_to_ground=False)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        total += tris
        print(f"{name}: {tris} tris")
        assert tris <= MAX_TRIS, f"{name} is over its triangle budget"
        results.append((name, flat, map_kit.bounds(obj)))
        mmkit.bake_vertex_colors(obj.data)
        objs.append(obj)
    print("total tris", total)
    map_kit.LUAU_OUT = LUAU_OUT
    map_kit.write_luau(results)
    with open(LUAU_OUT) as f:
        text = f.read()
    text = text.replace("MapKitShapes", "LucienShapes").replace(
        "GENERATED by art/blender/map_kit.py from the Blender map kit (map_kit.py and town_kit.py).",
        "GENERATED by art/blender/lucien.py (Director Lucien Vale's R15 pieces and cane).",
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
    """Two Luciens side by side: standing at rest, and waving with the cane out."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = dict(KIT)
    shown = []
    # Joint turns (degrees, Blender axes) for the waving pose: left arm up and out, forearm
    # bent, the right arm forward on the cane.
    wave = {
        "LeftUpperArm": (0, -150, 0),
        "LeftLowerArm": (0, -25, 0),
        "RightUpperArm": (-20, 0, 0),
        "Head": (0, 6, 0),
    }
    for offset, pose in ((-2.4, {}), (2.4, wave)):
        frames = {}
        for name, _ in KIT:
            piece = name[len("Lucien"):]
            parent, (ox, oy, oz) = JOINTS[piece]
            from mathutils import Euler, Matrix

            local = Matrix.Translation((-ox * mmkit.STUD, oz * mmkit.STUD, oy * mmkit.STUD))
            rx, ry, rz = pose.get(piece, (0, 0, 0))
            local = local @ Euler((math.radians(rx), math.radians(ry), math.radians(rz))).to_matrix().to_4x4()
            frames[piece] = (frames[parent] @ local) if parent else Matrix.Translation((offset * mmkit.STUD, 0, 0)) @ local
            obj, _ = map_kit.build(name + str(offset), kit[name], lift_to_ground=False)
            obj.matrix_world = frames[piece]
            shown.append(obj)
    map_kit.stage(shown, "director_lucien_vale.png", 1200, 1000, 1.05, 12)


if __name__ == "__main__":
    main()
