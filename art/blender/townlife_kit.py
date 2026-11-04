"""Town Life kit: the townsfolk and props that make the boulevard feel lived in
(src/client/TownLife.luau moves them, on each player's own screen). The bus stops are the map
kit's own (town_kit.py); the townsfolk only wait at them.

  People   TownFanA..TownFanD, TownVendor, TownPhotog, TownMime, each as rig pieces Head, Torso,
           Arm, Leg (the film crew's body from crew_kit.py: the arm and leg serve both sides, and
           each piece keeps its joint at its origin, so TownLife turns them like CrewRig does)
  Props    HotDogCart (spot Sign), PaparazziCamera (its flash glows),
           FanSign (a star placard on a stick, held up: the stick runs down from the grip along -Z),
           Guitar (held across the body), TipHat (a top hat on the ground with a few coins)

Written in the map kit's shape language (kitdsl.py), built with map_kit.py's mesh code, into its own
files: art/exports/townlife_kit.fbx (import once, drop the model into ReplicatedStorage > LotMeshes)
and src/shared/Models/TownLifeShapes.luau, which the game builds as parts until the meshes are
imported. Chunky toy style (ART_STYLE.md). Blender axes, in studs: Z up, the model faces -Y.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/townlife_kit.py
KIT_NO_RENDER=1 skips the preview (art/previews/townlife_kit.png).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import crew_kit  # noqa: E402
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, K, S, T, shade  # noqa: E402

INK = "#2E2C34"

# Townsfolk outfits, in crew_kit's PEOPLE format (skin, shirt, sleeve, pants, shoes), plus hair.
FOLK = {
    "FanA": {"skin": "light", "shirt": "#FF78AA", "sleeve": "#FF78AA", "pants": "#3E5C8A", "shoes": "#F4F4F4", "hair": "#F2C75C", "style": "bun"},
    "FanB": {"skin": "brown", "shirt": "#FFD63C", "sleeve": "#FFD63C", "pants": "#2E2C34", "shoes": "#C8202F", "hair": "#2A1E18", "style": "cap", "cap": "#2E86DE"},
    "FanC": {"skin": "deep", "shirt": "#20B2BE", "sleeve": "#20B2BE", "pants": "#C8B48C", "shoes": "#2E2C34", "hair": "#2A1E18", "style": "puffs"},
    "FanD": {"skin": "tan", "shirt": "#A04DFF", "sleeve": "#A04DFF", "pants": "#3E5C8A", "shoes": "#F4F4F4", "hair": "#7A3A1E", "style": "spiky"},
    "Vendor": {"skin": "fair", "shirt": "#FAF6EC", "sleeve": "#FAF6EC", "pants": "#C8202F", "shoes": "#2E2C34", "hair": "#5A3A24", "style": "chef"},
    "Photog": {"skin": "tan", "shirt": "#6A5440", "sleeve": "#E8D9B0", "pants": "#2E2C34", "shoes": "#5A3A24", "hair": "#2A1E18", "style": "flatcap"},
    "Mime": {"skin": "light", "shirt": "#FAF6EC", "sleeve": "#FAF6EC", "pants": "#2E2C34", "shoes": "#2E2C34", "hair": "#2E2C34", "style": "beret"},
}
crew_kit.PEOPLE.update(FOLK)


def torso(who):
    s = crew_kit.torso(who)
    if who == "Vendor":
        # A red-and-white apron with a hot dog on the pocket.
        s += [
            B((0, -0.52, 0.8), (1.3, 0.06, 1.3), "#C8202F"),
            B((0, -0.55, 0.7), (0.7, 0.04, 0.3), "#E89A62"),
            B((0, -0.565, 0.7), (0.6, 0.04, 0.1), "#C8202F"),
        ]
    elif who == "Photog":
        # A many-pocket vest over a cream shirt, a camera strap across it.
        for x in (-0.55, 0.55):
            s += [B((x, -0.04, 1.0), (0.62, 1.06, 1.6), "#6A5440"), B((x, -0.56, 0.75), (0.36, 0.06, 0.32), shade("#6A5440", 0.2))]
        s.append(B((0, -0.56, 1.1), (0.16, 0.06, 1.9), INK, rot=(0, -38, 0)))
    elif who == "Mime":
        # Black and white stripes and red braces.
        s += [B((0, 0, 0.45 + i * 0.4), (1.84, 1.04, 0.16), INK) for i in range(4)]
        s += [B((x, -0.52, 1.0), (0.14, 0.06, 1.7), "#C8202F") for x in (-0.45, 0.45)]
    elif who == "FanB":
        s.append(S((0, -0.53, 1.15), 0.42, 0.08, "#C8202F"))  # a star on the tee
    elif who == "FanD":
        s.append(B((0, -0.52, 1.2), (1.0, 0.05, 0.25), "OffWhite"))  # a stripe
    return s


def head(who):
    p = FOLK[who]
    skin = "#FAF6EC" if who == "Mime" else crew_kit.SKIN[p["skin"]]
    s = crew_kit.face(skin, "grin" if who.startswith("Fan") else "smile")
    hair, style = p["hair"], p["style"]
    if style == "bun":
        s += [crew_kit.BV((0, 0.1, 1.55), (1.56, 1.36, 0.3), hair), E((0, 0.2, 1.95), (0.38, 0.38, 0.32), hair)]
    elif style == "cap":
        s += [crew_kit.BV((0, 0, 1.58), (1.56, 1.46, 0.36), p["cap"], bevel=0.15), crew_kit.BV((0, -0.95, 1.45), (1.0, 0.7, 0.12), p["cap"])]
    elif style == "puffs":
        s += [crew_kit.BV((0, 0.1, 1.55), (1.56, 1.36, 0.28), hair)] + [E((x, 0.1, 1.75), (0.42, 0.42, 0.42), hair) for x in (-0.7, 0.7)]
    elif style == "spiky":
        s.append(crew_kit.BV((0, 0.1, 1.55), (1.56, 1.36, 0.3), hair))
        s += [K((x, 0.1, 1.85), 0.25, 0.02, 0.5, hair, seg=4) for x in (-0.5, 0, 0.5)]
    elif style == "chef":
        s += [C((0, 0, 1.65), 0.72, 0.4, "OffWhite", seg=12), E((0, 0, 2.15), (0.85, 0.85, 0.45), "OffWhite")]
    elif style == "flatcap":
        s += [crew_kit.BV((0, 0.05, 1.58), (1.58, 1.46, 0.3), "#6A5440", bevel=0.12), crew_kit.BV((0, -0.85, 1.5), (1.2, 0.5, 0.1), "#6A5440")]
    elif style == "beret":
        s += [K((0.1, 0, 1.62), 0.92, 0.75, 0.3, INK, rot=(0, 12, 0), seg=10), B((0, -0.72, 0.4), (0.45, 0.06, 0.1), "#C8202F")]
        s += [B((x, -0.72, 0.85), (0.06, 0.05, 0.5), INK) for x in (-0.35, 0.35)]  # painted lashes
    return s


def hot_dog_cart():
    """A street cart with a striped umbrella; its sign board (spot Sign) faces the street."""
    s = [
        crew_kit.BV((0, 0, 1.9), (4.6, 2.4, 2.0), "#C8202F", bevel=0.15),
        B((0, -1.21, 1.9), (4.2, 0.06, 1.2), "OffWhite"),
        B((0, -1.25, 1.9), (2.8, 0.04, 0.7), "#FFD63C"),
        T((0, -1.29, 1.9), (2.6, 0.04, 0.6), "Sign"),
        crew_kit.BV((0, 0, 3.0), (4.8, 2.6, 0.2), "Chrome"),
        # A hot dog on the counter, and the steamer lids.
        E((-1.2, 0, 3.25), (0.75, 0.28, 0.2), "#F0CD8C"),
        E((-1.2, 0, 3.32), (0.7, 0.13, 0.13), "#C8602F"),
        B((-1.2, 0, 3.47), (1.0, 0.05, 0.05), "#FFD63C"),
        C((0.6, 0.2, 3.2), 0.45, 0.3, "Chrome", seg=10),
        C((1.6, 0.2, 3.2), 0.45, 0.3, "Chrome", seg=10),
        # Wheels and a handle.
        C((-1.6, -1.25, 0.65), 0.65, 0.25, INK, rot=(90, 0, 0), seg=12),
        C((-1.6, 1.25, 0.65), 0.65, 0.25, INK, rot=(90, 0, 0), seg=12),
        C((-1.6, -1.4, 0.65), 0.25, 0.1, "Chrome", rot=(90, 0, 0), seg=8),
        C((-1.6, 1.4, 0.65), 0.25, 0.1, "Chrome", rot=(90, 0, 0), seg=8),
        B((1.8, 0, 0.45), (0.3, 1.6, 0.9), INK),
        C((2.7, 0, 2.5), 0.1, 2.2, "Chrome", rot=(90, 0, 0), seg=6),
        # The umbrella pole and its striped canopy.
        C((0, 0.6, 4.6), 0.08, 3.2, "Chrome", seg=6),
    ]
    for i in range(8):
        a = i * 45
        col = "#C8202F" if i % 2 == 0 else "#FFD63C"
        s.append(K((0, 0.6, 6.3), 3.0, 0.1, 0.9, col, rot=(0, 0, a), seg=3))
    s.append(E((0, 0.6, 6.8), (0.18, 0.18, 0.18), "#FFD63C"))
    return s


def paparazzi_camera():
    """A press camera with a big flash gun on top, centred on the grip, lens along -Y."""
    return [
        crew_kit.BV((0, 0, 0), (1.3, 0.8, 0.9), INK, bevel=0.1),
        C((0, -0.6, -0.05), 0.35, 0.6, "Steel", rot=(90, 0, 0), seg=12),
        C((0, -0.92, -0.05), 0.25, 0.06, "#96CDF0", rot=(90, 0, 0), seg=12),
        B((0.45, 0, 0.5), (0.2, 0.3, 0.2), "Steel"),
        crew_kit.BV((0.45, -0.1, 0.9), (0.55, 0.45, 0.6), INK, bevel=0.06),
        B((0.45, -0.34, 0.95), (0.45, 0.04, 0.4), "#FFFFFF", neon=True),
        B((-0.4, -0.42, 0.25), (0.2, 0.04, 0.12), "Carpet"),
    ]


def fan_sign():
    """A star placard on a stick, held up overhead: the grip is the origin and the stick runs
    down the arm's direction (-Z) to the board. Painted on both faces."""
    s = [C((0, 0, -1.4), 0.08, 2.8, "Wood", seg=6), crew_kit.BV((0, 0, -3.2), (2.4, 0.12, 1.6), "OffWhite", bevel=0.05)]
    s += [S((0, y, -3.2), 0.55, 0.04, "Gold", rot=(0, 180, 0) if y > 0 else (0, 0, 0)) for y in (-0.08, 0.08)]
    s += [B((0, y, -2.55), (1.8, 0.03, 0.15), "Carpet") for y in (-0.08, 0.08)]
    return s


def guitar():
    """An acoustic guitar, centred, neck along +X, top facing -Y."""
    return [
        E((-0.5, 0, 0), (0.75, 0.22, 0.65), "#E09A10"),
        E((0.25, 0, 0.05), (0.55, 0.22, 0.5), "#E09A10"),
        C((-0.25, -0.2, 0.0), 0.2, 0.05, INK, rot=(90, 0, 0), seg=10),
        B((1.35, 0, 0.05), (1.8, 0.14, 0.2), "#7A5434"),
        B((2.35, 0, 0.05), (0.4, 0.16, 0.3), INK),
        B((-0.8, -0.2, 0), (0.12, 0.05, 0.4), INK),
    ]


def tip_hat():
    """A top hat upside down on the pavement with a few gold coins in it."""
    s = [C((0, 0, 0.06), 0.85, 0.12, INK, seg=14), C((0, 0, 0.55), 0.55, 0.9, INK, seg=12), C((0, 0, 0.3), 0.57, 0.12, "Carpet", seg=12)]
    s += [C((x, y, 1.02), 0.18, 0.06, "Gold", rot=(rx, 0, 0), seg=8) for x, y, rx in ((-0.15, 0.1, 10), (0.2, -0.1, -15), (0.0, 0.25, 25))]
    return s


def _v(fn, *args):
    return lambda: fn(*args)


PIECES = {"Head": head, "Torso": torso, "Arm": crew_kit.arm, "Leg": crew_kit.leg}
KIT = [(f"Town{who}{part}", _v(make, who)) for who in FOLK for part, make in PIECES.items()] + [
    ("HotDogCart", hot_dog_cart),
    ("PaparazziCamera", paparazzi_camera),
    ("FanSign", fan_sign),
    ("Guitar", guitar),
    ("TipHat", tip_hat),
]
# Rig pieces and held props keep their origin as the joint or grip; the rest stand on the ground.
GROUNDED = {"HotDogCart", "TipHat"}

LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "TownLifeShapes.luau")
FBX_OUT = os.path.join(mmkit.EXPORTS, "townlife_kit.fbx")
MAX_TRIS = 2500


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
    text = text.replace("MapKitShapes", "TownLifeShapes").replace(
        "GENERATED by art/blender/map_kit.py from the Blender map kit (map_kit.py and town_kit.py).",
        "GENERATED by art/blender/townlife_kit.py (the townsfolk and their props).",
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


def person(who, x, y, pose):
    """Puts one townsperson's pieces together at (x, y) in studs (the rig CrewRig and TownLife
    use: hips 2 up, shoulders 1.75 above them and 1.2 out, the neck 2.1 above the hips)."""
    kit = dict(KIT)
    out = []

    def put(part, at, rot=(0, 0, 0)):
        o = map_kit.build(f"Town{who}{part}", kit[f"Town{who}{part}"], lift_to_ground=False)[0]
        o.location = tuple(mmkit.STUD * v for v in (x + at[0], y + at[1], at[2]))
        o.rotation_euler = tuple(math.radians(r) for r in rot)
        out.append(o)
        return o

    put("Torso", (0, 0, 2))
    put("Head", (0, 0, 4.1))
    put("Leg", (-0.45, 0, 2))
    put("Leg", (0.45, 0, 2))
    up = pose == "cheer"
    put("Arm", (-1.2, 0, 3.75), (0, 160 if up else 8, 0) if up else (0, 8, 0))
    put("Arm", (1.2, 0, 3.75), (0, -160, 0) if up else (0, -8, 0))
    return out


def preview():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shown = []
    for i, who in enumerate(FOLK):
        shown += person(who, (i - 3) * 3.2, 0, "cheer" if who.startswith("Fan") else "stand")
    kit = dict(KIT)
    props = [("HotDogCart", -1, 9), ("PaparazziCamera", -6, -5), ("FanSign", -2, -5), ("Guitar", 3, -5), ("TipHat", 8, -5)]
    for name, x, y in props:
        o = map_kit.build(name, kit[name], lift_to_ground=name in GROUNDED)[0]
        lo, hi = map_kit.bounds(o)
        lift = 0 if name in GROUNDED else -lo.z + 0.2
        if name == "FanSign":
            o.rotation_euler = (math.radians(180), 0, 0)
            lift = hi.z + 0.2
        o.location = (mmkit.STUD * x, mmkit.STUD * y, mmkit.STUD * lift)
        shown.append(o)
    for o in shown:
        o.location.rotate(__import__("mathutils").Euler((0, 0, math.radians(-12))))
        o.rotation_euler.z += math.radians(-12)
    map_kit.stage(shown, "townlife_kit.png", 1600, 1000, 0.95, 16)


if __name__ == "__main__":
    main()
