"""Studio mascots: six chunky toy companions that follow their owner around town (cosmetic only).

  popcorn_pup.fbx     Popcorn Pup       a puppy wearing a popcorn bucket
  clapper_croc.fbx    Clapper Croc      a crocodile whose mouth is a clapperboard
  reel_kitty.fbx      Reel Kitty        a cat with film reels for ears
  camera_bot.fbx      Camera Bot        a hovering film-camera robot
  spotlight_owl.fbx   Spotlight Owl     an owl whose eyes are spotlights
  premiere_dragon.fbx Premiere Dragon   a baby dragon in red-carpet colours

Each mascot is built from rounded shapes in the Roblox front-page toy style: big heads, glossy
eyes and a thick dark outline (an "inverted hull": a slightly bigger copy of each big shape, turned
inside out, which Roblox draws only from behind, so it shows as a rim round the model).

The same shapes are also written to src/shared/Models/MascotShapes.luau, which the game uses to
build a part version of each mascot until the meshes are imported (art/README.md). So the Blender
design is the one source for both: edit the shapes here and run this script again.

Run from the repo root with Blender, or with the `bpy` package (see mmkit.py):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/mascots.py
Writes art/exports/<mascot>.fbx, art/previews/mascots.png (the line-up) and one
art/previews/mascot_<name>.png each. Set MASCOT_SAMPLES for quicker test renders.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

STUD = mmkit.STUD
OUTLINE = 0.09  # outline thickness, studs
INK = "#1E1630"
LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "MascotShapes.luau")
SAMPLES = int(os.environ.get("MASCOT_SAMPLES", "64"))

# --- Shapes ----------------------------------------------------------------------------------
# Blender coordinates in studs: Z up, the mascot faces -Y, feet on Z = 0.


def E(at, radii, color, rot=(0, 0, 0), outline=None, neon=False):
    """Ellipsoid centred on `at` with half-sizes `radii`. Outlined if it is big enough."""
    if outline is None:
        outline = min(radii) >= 0.12 and max(radii) >= 0.2
    return {"kind": "ball", "at": at, "size": tuple(2 * r for r in radii), "color": color, "rot": rot, "outline": outline, "neon": neon}


def B(at, size, color, rot=(0, 0, 0), bevel=0.12, outline=True, neon=False):
    """Rounded box centred on `at`."""
    return {"kind": "box", "at": at, "size": size, "color": color, "rot": rot, "bevel": bevel, "outline": outline, "neon": neon}


def C(at, radius, length, color, rot=(0, 0, 0), outline=True, neon=False):
    """Cylinder centred on `at`, its axis along local Z (rotate it to point elsewhere)."""
    return {"kind": "cyl", "at": at, "size": (2 * radius, 2 * radius, length), "color": color, "rot": rot, "outline": outline, "neon": neon}


def G(at, rot, *children):
    """A group: its children's positions and rotations are relative to it."""
    return {"kind": "group", "at": at, "rot": rot, "children": children}


def mirror(shape):
    """The same shape on the other side (x -> -x), for ears, legs and eyes."""
    if shape["kind"] == "group":
        rx, ry, rz = shape["rot"]
        return {**shape, "at": (-shape["at"][0], *shape["at"][1:]), "rot": (rx, -ry, -rz), "children": tuple(mirror(c) for c in shape["children"])}
    rx, ry, rz = shape["rot"]
    return {**shape, "at": (-shape["at"][0], *shape["at"][1:]), "rot": (rx, -ry, -rz)}


def pair(*shapes):
    out = list(shapes)
    out += [mirror(s) for s in shapes]
    return out


def eye(at, size=1.0, iris=None, look=(0, 0)):
    """A big glossy cartoon eye: white, a dark pupil (or a coloured iris) and a sparkle."""
    x, y, z = at
    lx, lz = look
    white = E((x, y, z), (0.2 * size, 0.1 * size, 0.24 * size), "#FFFFFF", outline=True)
    parts = [white]
    if iris:
        parts.append(E((x + lx, y - 0.075 * size, z + lz), (0.14 * size, 0.06 * size, 0.18 * size), iris, outline=False))
    parts.append(E((x + lx, y - 0.1 * size, z + lz - 0.01), (0.1 * size, 0.06 * size, 0.14 * size), "#161220", outline=False))
    parts.append(E((x + lx - 0.045 * size, y - 0.15 * size, z + lz + 0.06 * size), (0.045 * size, 0.025 * size, 0.05 * size), "#FFFFFF", outline=False))
    return parts


def popcorn_pup():
    tan, cream, brown = "#EDB872", "#FFF1D6", "#A8693B"
    red, white, corn = "#E8333A", "#FFF8EE", "#FFE58A"
    shapes = [
        E((0, 0.3, 1.0), (0.72, 0.9, 0.68), tan),
        E((0, -0.18, 0.88), (0.5, 0.45, 0.5), cream),
        *pair(
            E((0.42, -0.32, 0.3), (0.24, 0.27, 0.3), tan),
            E((0.45, 0.82, 0.3), (0.25, 0.3, 0.3), tan),
            E((0.42, -0.4, 0.08), (0.22, 0.28, 0.1), cream, outline=False),
            E((0.82, -0.42, 2.02), (0.22, 0.3, 0.55), brown, rot=(0, -22, 0)),
        ),
        E((0, 1.25, 1.45), (0.15, 0.15, 0.38), tan, rot=(-35, 0, 0)),
        E((0, -0.55, 2.02), (0.86, 0.76, 0.76), tan),
        E((0, -1.18, 1.82), (0.42, 0.3, 0.3), cream),
        E((0, -1.46, 1.95), (0.17, 0.1, 0.12), "#3A2A2A", outline=False),
        E((0, -1.33, 1.6), (0.13, 0.06, 0.1), "#FF7A8A", outline=False),
        *eye((0.32, -1.17, 2.24)),
        *eye((-0.32, -1.17, 2.24)),
        # The popcorn bucket hat, tipped a little to one side.
        G(
            (0.12, -0.5, 2.88),
            (-8, 12, 0),
            C((0, 0, 0), 0.46, 0.62, red),
            *[B((0.465 * math.cos(a), 0.465 * math.sin(a), 0), (0.16, 0.05, 0.6), white, rot=(0, 0, math.degrees(a) + 90), bevel=0.02, outline=False) for a in (i * math.pi / 4 for i in range(8))],
            C((0, 0, 0.33), 0.5, 0.1, white),
            E((0, 0, 0.42), (0.22, 0.22, 0.2), corn),
            E((0.24, 0.1, 0.42), (0.18, 0.18, 0.16), corn),
            E((-0.22, 0.12, 0.44), (0.18, 0.18, 0.17), corn),
            E((0.05, -0.25, 0.43), (0.18, 0.18, 0.16), corn),
            E((-0.08, 0.26, 0.47), (0.17, 0.17, 0.16), corn),
            E((0.05, 0.02, 0.6), (0.16, 0.16, 0.15), corn),
        ),
    ]
    return shapes


def clapper_croc():
    green, light, dark = "#4CC764", "#C9F29B", "#2F8F45"
    board, white = "#2E2C34", "#FAF6EC"
    stripes = [B((x, -0.72, 0.35), (0.2, 1.5, 0.03), white, rot=(0, 0, 32), bevel=0.01, outline=False) for x in (-0.36, 0.0, 0.36)]
    return [
        E((0, 0.45, 0.85), (0.7, 1.05, 0.58), green),
        E((0, 0.25, 0.62), (0.55, 0.85, 0.36), light),
        *pair(
            E((0.58, -0.25, 0.3), (0.22, 0.26, 0.3), green),
            E((0.58, 1.05, 0.3), (0.22, 0.26, 0.3), green),
            E((0.3, 0.55, 1.4), (0.12, 0.14, 0.1), dark, outline=False),
        ),
        E((0, 0.05, 1.42), (0.12, 0.14, 0.1), dark, outline=False),
        E((0, 1.1, 1.3), (0.12, 0.14, 0.1), dark, outline=False),
        E((0, 1.75, 0.65), (0.32, 0.75, 0.3), green, rot=(12, 0, 0)),
        E((0, 2.35, 0.48), (0.16, 0.38, 0.15), green, rot=(12, 0, 0)),
        # Head: a green lower jaw with teeth, and a clapperboard for the top jaw, held open.
        B((0, -0.9, 1.18), (1.2, 1.5, 0.42), green, bevel=0.18),
        B((0, -0.98, 1.38), (1.0, 1.3, 0.05), "#C8202F", bevel=0.02, outline=False),
        *[B((x, -1.55, 1.46), (0.13, 0.1, 0.16), white, bevel=0.03, outline=False) for x in (-0.36, -0.12, 0.12, 0.36)],
        G(
            (0, -0.2, 1.48),
            (16, 0, 0),
            B((0, -0.72, 0.17), (1.22, 1.44, 0.34), board, bevel=0.08),
            *stripes,
            C((0, 0.0, 0.17), 0.12, 1.3, "#9AA0AA", rot=(0, 90, 0), outline=False),
        ),
        *pair(
            E((0.36, -0.35, 2.0), (0.26, 0.26, 0.3), green),
            *eye((0.36, -0.5, 2.08), size=0.95),
        ),
    ]


def reel_kitty():
    blue, belly, pink, reel, steel, gold = "#8EC5FF", "#EAF4FF", "#FF8FB1", "#2E2C34", "#B8BEC8", "#F5B82E"

    def reel_ear():
        holes = [C((0.22 * math.cos(a), 0.22 * math.sin(a), 0.0), 0.08, 0.22, steel, outline=False) for a in (i * 2 * math.pi / 5 + 0.3 for i in range(5))]
        return G(
            (0.55, -0.3, 2.72),
            (90, 0, -20),
            C((0, 0, 0), 0.44, 0.18, reel),
            *holes,
            C((0, 0, 0), 0.12, 0.24, gold, outline=False),
        )

    return [
        E((0, 0.35, 0.92), (0.66, 0.82, 0.68), blue),
        E((0, -0.05, 0.85), (0.45, 0.45, 0.5), belly),
        *pair(
            E((0.4, -0.3, 0.3), (0.22, 0.25, 0.3), blue),
            E((0.43, 0.8, 0.3), (0.23, 0.28, 0.3), blue),
            E((0.4, -0.38, 0.08), (0.2, 0.25, 0.1), belly, outline=False),
            reel_ear(),
            B((0.55, -1.12, 1.82), (0.36, 0.02, 0.03), "#5A6A80", rot=(0, -12, 0), bevel=0.0, outline=False),
            B((0.55, -1.12, 1.72), (0.36, 0.02, 0.03), "#5A6A80", rot=(0, 8, 0), bevel=0.0, outline=False),
        ),
        C((0, -0.35, 1.52), 0.62, 0.16, gold),
        E((0.35, 1.2, 1.25), (0.14, 0.14, 0.5), blue, rot=(-35, 0, -10)),
        E((0.5, 1.45, 1.75), (0.16, 0.16, 0.2), belly),
        E((0, -0.4, 2.02), (0.86, 0.74, 0.72), blue),
        E((0, -1.02, 1.82), (0.42, 0.22, 0.24), belly),
        E((0, -1.2, 1.94), (0.1, 0.06, 0.07), pink, outline=False),
        *eye((0.33, -1.02, 2.22), iris="#3FCF6A"),
        *eye((-0.33, -1.02, 2.22), iris="#3FCF6A"),
    ]


def camera_bot():
    purple, light, charcoal, gold, glass, steel = "#A04DFF", "#C99BFF", "#2E2C34", "#F5B82E", "#7FD8FF", "#9AA0AA"

    def reel(x):
        return G(
            (x, 0.1, 2.55),
            (90, 0, 0),
            C((0, 0, 0), 0.46, 0.22, charcoal),
            *[C((0.24 * math.cos(a), 0.24 * math.sin(a), 0), 0.09, 0.26, steel, outline=False) for a in (i * 2 * math.pi / 5 for i in range(5))],
            C((0, 0, 0), 0.12, 0.28, gold, outline=False),
        )

    return [
        B((0, 0.05, 1.62), (1.45, 1.25, 1.12), purple, bevel=0.3),
        B((0, 0.05, 1.62), (1.5, 0.5, 0.5), light, bevel=0.12, outline=False),
        reel(-0.42),
        reel(0.42),
        C((0, -0.72, 1.62), 0.42, 0.42, charcoal, rot=(90, 0, 0)),
        C((0, -0.95, 1.62), 0.5, 0.12, gold, rot=(90, 0, 0)),
        E((0, -0.99, 1.62), (0.34, 0.07, 0.34), glass, outline=False, neon=True),
        E((0, -1.04, 1.62), (0.15, 0.04, 0.15), "#161220", outline=False),
        E((-0.07, -1.07, 1.7), (0.06, 0.02, 0.06), "#FFFFFF", outline=False),
        E((0.52, -0.63, 2.0), (0.09, 0.05, 0.09), "#FF3040", outline=False, neon=True),
        *pair(
            E((0.9, -0.05, 1.42), (0.17, 0.17, 0.34), light, rot=(0, -28, 0)),
            E((1.04, -0.1, 1.1), (0.16, 0.16, 0.14), "#FFFFFF"),
        ),
        C((0, 0.05, 0.92), 0.42, 0.24, steel),
        E((0, 0.05, 0.62), (0.3, 0.3, 0.26), glass, outline=False, neon=True),
    ]


def spotlight_owl():
    gold, belly, dark, orange, charcoal, light = "#E8A63A", "#FFE7B0", "#B9761F", "#FF8C2E", "#2E2C34", "#FFF1A8"

    def lamp(x):
        return G(
            (x, -0.62, 2.42),
            (90, 0, 0),
            C((0, 0, 0), 0.34, 0.38, charcoal),
            C((0, 0, 0.2), 0.38, 0.1, "#F5B82E"),
            E((0, 0, 0.24), (0.28, 0.28, 0.06), light, outline=False, neon=True),
            E((0, 0, 0.29), (0.11, 0.11, 0.03), "#161220", outline=False),
            E((-0.05, 0.06, 0.31), (0.04, 0.04, 0.015), "#FFFFFF", outline=False),
        )

    return [
        E((0, 0.08, 1.25), (0.95, 0.85, 1.12), gold),
        E((0, -0.38, 1.08), (0.62, 0.45, 0.78), belly),
        E((0, -0.02, 2.42), (0.92, 0.8, 0.66), gold),
        lamp(0.38),
        lamp(-0.38),
        E((0, -0.86, 2.08), (0.13, 0.12, 0.2), orange),
        *pair(
            E((0.6, 0.0, 3.0), (0.15, 0.15, 0.36), dark, rot=(0, -25, 0)),
            E((0.95, 0.12, 1.32), (0.24, 0.55, 0.75), dark, rot=(0, -14, 0)),
            E((0.3, -0.42, 0.12), (0.22, 0.26, 0.12), orange),
        ),
        *[E((x, -0.78, z), (0.09, 0.03, 0.07), "#F0C870", outline=False) for x, z in ((-0.2, 1.25), (0.2, 1.25), (0, 1.0), (-0.22, 0.8), (0.22, 0.8))],
    ]


def premiere_dragon():
    red, belly, wing, gold = "#FF5A2E", "#FFD36B", "#C8202F", "#F5B82E"
    return [
        E((0, 0.35, 1.05), (0.74, 0.92, 0.78), red),
        E((0, -0.12, 0.92), (0.52, 0.55, 0.62), belly),
        *pair(
            E((0.45, -0.3, 0.3), (0.24, 0.27, 0.3), red),
            E((0.48, 0.85, 0.3), (0.25, 0.3, 0.3), red),
            E((0.45, -0.38, 0.08), (0.22, 0.26, 0.1), belly, outline=False),
            G(
                (0.72, 0.62, 1.85),
                (20, 0, -35),
                E((0, 0, 0), (0.07, 0.42, 0.62), wing),
                E((0, -0.05, 0.55), (0.1, 0.1, 0.12), gold),
            ),
            E((0.34, -0.38, 2.88), (0.1, 0.1, 0.32), gold, rot=(18, -16, 0)),
            E((0.22, -1.48, 2.12), (0.05, 0.04, 0.05), "#7A1F2B", outline=False),
        ),
        *[E((0, y, z), (0.08, 0.14, 0.16), gold, rot=(-20, 0, 0)) for y, z in ((0.1, 1.86), (0.55, 1.78), (1.0, 1.55))],
        E((0, 1.4, 0.72), (0.24, 0.72, 0.24), red, rot=(18, 0, 0)),
        E((0, 2.05, 0.55), (0.24, 0.26, 0.07), gold, rot=(12, 0, 0)),
        E((0, -0.55, 2.25), (0.76, 0.7, 0.66), red),
        E((0, -1.15, 2.02), (0.46, 0.38, 0.32), red),
        E((0, -1.2, 1.88), (0.38, 0.3, 0.16), belly, outline=False),
        *eye((0.32, -1.08, 2.42), iris="#FFB020"),
        *eye((-0.32, -1.08, 2.42), iris="#FFB020"),
    ]


# id (the name players and the game use) -> (file name, builder)
MASCOTS = [
    ("PopcornPup", "popcorn_pup", popcorn_pup),
    ("ClapperCroc", "clapper_croc", clapper_croc),
    ("ReelKitty", "reel_kitty", reel_kitty),
    ("CameraBot", "camera_bot", camera_bot),
    ("SpotlightOwl", "spotlight_owl", spotlight_owl),
    ("PremiereDragon", "premiere_dragon", premiere_dragon),
]

# --- Flattening ------------------------------------------------------------------------------


def rotation(rot):
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()


def flatten(shapes, parent=None):
    """[(shape, world matrix in studs)] with groups resolved."""
    parent = parent or Matrix.Identity(4)
    out = []
    for s in shapes:
        m = parent @ Matrix.Translation(Vector(s["at"])) @ rotation(s["rot"])
        if s["kind"] == "group":
            out += flatten(s["children"], m)
        else:
            out.append((s, m))
    return out


# --- Mesh ------------------------------------------------------------------------------------


def unit_shape(kind, size, grow=0.0, bevel=0.0):
    """A bmesh of the shape in studs, centred on the origin, `grow` studs bigger all round."""
    bm = bmesh.new()
    sx, sy, sz = (s + 2 * grow for s in size)
    biggest = max(size)
    if kind == "ball":
        u = 16 if biggest > 1.0 else 12 if biggest > 0.4 else 8
        bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=max(5, u * 2 // 3), radius=0.5)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    elif kind == "cyl":
        seg = 18 if biggest > 0.6 else 12
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=0.5, radius2=0.5, depth=1.0)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
        if biggest > 0.3:
            rim = [e for e in bm.edges if len(e.link_faces) == 2 and abs(e.link_faces[0].normal.z - e.link_faces[1].normal.z) > 0.5]
            bmesh.ops.bevel(bm, geom=rim, offset=min(0.06, sz * 0.25, sx * 0.2), segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    else:
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
        b = min(bevel + grow, min(sx, sy, sz) * 0.45)
        if b > 0.005:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
    return bm


class Mascot:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.index = {}

    def mat(self, color, neon=False, ink=False):
        key = (color, neon, ink)
        if key in self.index:
            return self.index[key]
        mat = bpy.data.materials.new(f"Mat_{'Ink' if ink else color.lstrip('#')}{'_Neon' if neon else ''}")
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        linear = mmkit.hex_to_linear(color)
        bsdf.inputs["Base Color"].default_value = linear
        bsdf.inputs["Roughness"].default_value = 0.38
        bsdf.inputs["Coat Weight"].default_value = 0.35
        if neon:
            bsdf.inputs["Emission Color"].default_value = linear
            bsdf.inputs["Emission Strength"].default_value = 2.5
        if ink:
            # The outline hull: drawn only where its inside faces the camera, like Roblox does.
            out = nodes["Material Output"]
            geo = nodes.new("ShaderNodeNewGeometry")
            mix = nodes.new("ShaderNodeMixShader")
            clear = nodes.new("ShaderNodeBsdfTransparent")
            emit = nodes.new("ShaderNodeEmission")
            emit.inputs["Color"].default_value = linear
            # Seen by the camera only: from inside the hull it would shade the model.
            path = nodes.new("ShaderNodeLightPath")
            either = nodes.new("ShaderNodeMath")
            either.operation = "ADD"
            either.use_clamp = True
            links.new(geo.outputs["Backfacing"], either.inputs[0])
            notcam = nodes.new("ShaderNodeMath")
            notcam.operation = "SUBTRACT"
            notcam.inputs[0].default_value = 1.0
            links.new(path.outputs["Is Camera Ray"], notcam.inputs[1])
            links.new(notcam.outputs[0], either.inputs[1])
            links.new(either.outputs[0], mix.inputs["Fac"])
            links.new(emit.outputs["Emission"], mix.inputs[1])
            links.new(clear.outputs["BSDF"], mix.inputs[2])
            links.new(mix.outputs["Shader"], out.inputs["Surface"])
            mat.blend_method = "HASHED" if hasattr(mat, "blend_method") else None
        mat.diffuse_color = linear
        self.materials.append(mat)
        self.index[key] = len(self.materials) - 1
        return self.index[key]

    def add(self, tmp, matrix, mat, smooth, flip=False):
        vs = {v: self.bm.verts.new(matrix @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            verts = [vs[v] for v in f.verts]
            if flip:
                verts.reverse()
            face = self.bm.faces.new(verts)
            face.material_index = mat
            face.smooth = smooth
        tmp.free()

    def shape(self, s, m):
        scale = Matrix.Scale(STUD, 4)
        world = scale @ m
        smooth = s["kind"] != "box" or s.get("bevel", 0) > 0.05
        self.add(unit_shape(s["kind"], s["size"], 0, s.get("bevel", 0)), world, self.mat(s["color"], s["neon"]), smooth)
        if s["outline"]:
            self.add(unit_shape(s["kind"], s["size"], OUTLINE, s.get("bevel", 0)), world, self.mat(INK, ink=True), True, flip=True)

    def obj(self):
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def build(mascot_id, builder):
    flat = flatten(builder())
    lowest = min(_lowest(s, m) for s, m in flat)
    lift = Matrix.Translation((0, 0, -lowest))
    model = Mascot(mascot_id)
    for s, m in flat:
        model.shape(s, lift @ m)
    return model.obj(), [(s, lift @ m) for s, m in flat]


def _lowest(s, m):
    sx, sy, sz = (v / 2 for v in s["size"])
    corners = [m @ Vector((x * sx, y * sy, z * sz)) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    if s["kind"] == "ball":  # an ellipsoid's lowest point: support function
        r = m.to_3x3() @ Matrix.Diagonal((sx, sy, sz))
        down = Vector((0, 0, -1))
        return m.translation.z - (r.transposed() @ down).length
    return min(c.z for c in corners)


# --- Luau fallback ---------------------------------------------------------------------------

# Blender (x, y, z) -> Roblox (-x, z, y): a proper rotation taking Blender's up (Z) to Roblox's
# up (Y) and Blender's front (-Y) to Roblox's front (-Z).
P = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def to_roblox(s, m):
    pos = P @ m.translation
    rot = P @ m.to_3x3() @ P
    sx, sy, sz = s["size"]
    size = (sx, sz, sy)  # local Blender (x, y, z) -> Roblox local (x, z, y)
    return pos, rot, size


def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def write_luau(results):
    lines = [
        "--!strict",
        "-- GENERATED by art/blender/mascots.py from the Blender mascot designs. Do not edit by hand:",
        "-- change the shapes there and run it again. Each mascot is a list of shapes in studs, feet on",
        "-- y = 0, facing -Z. MascotModels builds them as parts until the Blender meshes are imported.",
        "-- kind: \"ball\" (an ellipsoid), \"box\" or \"cyl\" (its axis along the CFrame's Y).",
        "",
        "export type Shape = { kind: string, cf: CFrame, size: Vector3, color: Color3, neon: boolean?, outline: boolean? }",
        "",
        "local function S(kind: string, cf: CFrame, size: Vector3, hex: string, neon: boolean?, outline: boolean?): Shape",
        "\treturn { kind = kind, cf = cf, size = size, color = Color3.fromHex(hex), neon = neon, outline = outline }",
        "end",
        "",
        "local MascotShapes = {}",
        "",
        "MascotShapes.Shapes = {} :: { [string]: { Shape } }",
        "",
        "-- Each mascot's mesh size and where its centre sits above the feet, for placing the mesh.",
        "MascotShapes.Bounds = {} :: { [string]: { size: Vector3, center: Vector3 } }",
        "",
    ]
    for mascot_id, flat, bounds in results:
        lines.append(f"MascotShapes.Shapes.{mascot_id} = {{")
        for s, m in flat:
            pos, r, size = to_roblox(s, m)
            cf = ", ".join(num(v) for v in (*pos, r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]))
            extra = ""
            if s["neon"] or s["outline"]:
                extra = f", {'true' if s['neon'] else 'nil'}, {'true' if s['outline'] else 'nil'}"
            lines.append(f"\tS(\"{s['kind']}\", CFrame.new({cf}), Vector3.new({', '.join(num(v) for v in size)}), \"{s['color'].lstrip('#')}\"{extra}),")
        lines.append("}")
        (lo, hi) = bounds
        lo_r, hi_r = P @ lo, P @ hi
        mn = [min(a, b) for a, b in zip(lo_r, hi_r)]
        mx = [max(a, b) for a, b in zip(lo_r, hi_r)]
        size = [b - a for a, b in zip(mn, mx)]
        center = [(a + b) / 2 for a, b in zip(mn, mx)]
        lines.append(
            f"MascotShapes.Bounds.{mascot_id} = {{ size = Vector3.new({', '.join(num(v) for v in size)}), center = Vector3.new({', '.join(num(v) for v in center)}) }}"
        )
        lines.append("")
    lines.append("return MascotShapes")
    with open(LUAU_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("Wrote", LUAU_OUT)


# --- Previews --------------------------------------------------------------------------------


def stage(objects, file_name, width, height, distance_scale=1.0, angle=24):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = mmkit.hex_to_linear("#FFE9B8")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world
    for name, energy, rot, color in (("Key", 4.0, (50, 0, -35), (1, 0.95, 0.88)), ("Fill", 1.2, (60, 0, 140), (0.85, 0.9, 1.0))):
        light = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        light.data.energy = energy
        light.data.color = color
        light.data.angle = math.radians(8)
        light.rotation_euler = [math.radians(a) for a in rot]
        scene.collection.objects.link(light)
    rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", "SUN"))
    rim.data.energy = 3.0
    rim.rotation_euler = (math.radians(-60), 0, math.radians(15))
    scene.collection.objects.link(rim)
    # A soft floor that fades into the background colour, so the line-up reads like a store card.
    floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=400)
    fb.to_mesh(floor.data)
    fb.free()
    fmat = bpy.data.materials.new("Mat_Floor")
    fmat.use_nodes = True
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = mmkit.hex_to_linear("#FFD978")
    fmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    floor.data.materials.append(fmat)
    scene.collection.objects.link(floor)

    bpy.context.view_layer.update()
    xs, ys, zs = [], [], []
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            xs.append(w.x)
            ys.append(w.y)
            zs.append(w.z)
    target = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (max(zs)) * 0.48))
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    span = max(max(xs) - min(xs), (max(zs) - min(zs)) * width / height)
    dist = span / 2 / math.tan(cam.data.angle_x / 2) * 1.12 * distance_scale
    el = math.radians(angle)
    cam.location = target + Vector((0, -math.cos(el) * dist, math.sin(el) * dist))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.filepath = os.path.join(mmkit.PREVIEWS, file_name)
    bpy.ops.render.render(write_still=True)
    print("Rendered", scene.render.filepath)


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))) / STUD
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))) / STUD
    return lo, hi


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    only = os.environ.get("MASCOT_ONLY")
    results = []
    for mascot_id, file_name, builder in MASCOTS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        obj, flat = build(mascot_id, builder)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        lo, hi = bounds(obj)
        size = hi - lo
        print(f"{mascot_id}: {tris} tris, {size.x:.1f} x {size.y:.1f} x {size.z:.1f} studs")
        assert tris <= 9000, f"{mascot_id} is over its triangle budget"
        results.append((mascot_id, flat, (lo, hi)))
        if only and only != mascot_id:
            continue
        mmkit.bake_vertex_colors(obj.data)
        mmkit._export(obj, file_name)
        if not os.environ.get("MASCOT_NO_RENDER"):
            obj.rotation_euler = (0, 0, math.radians(-28))
            stage([obj], f"mascot_{file_name}.png", 640, 640, 1.25, 14)
    write_luau(results)

    if not os.environ.get("MASCOT_NO_RENDER") and not only:
        # The line-up: all six side by side, rarest on the right.
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objs = []
        for i, (mascot_id, _, builder) in enumerate(MASCOTS):
            obj, _ = build(mascot_id, builder)
            obj.location = (STUD * (i - 2.5) * 3.4, 0, 0)
            obj.rotation_euler = (0, 0, math.radians(-18 + i * 7))
            objs.append(obj)
        stage(objs, "mascots.png", 1600, 640, 1.0, 12)


if __name__ == "__main__":
    main()
