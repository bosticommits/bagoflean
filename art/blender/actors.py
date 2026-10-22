"""The 21 castable actors (Shared/Actors) as low-poly Blender models, in the style Bosti picked
in the 2026-10 actor overhaul: faceted, flat shaded, no outline, a big-headed toy body shared by the
whole cast, and a hex base in the rarity color. Only three are spooky (Zombie Extra, the vampire
and the Phantom Auteur); the rest are everyday film people with a silly twist.

Each actor is split into rig pieces that the game moves on its own (ActorLife idles, bobs and
waves them): Body, Head, ArmL and ArmR (the actor's left and right arms, with whatever they hold)
and Base. One file, art/exports/actors.fbx, holds every piece as its own mesh named
<ActorId>_<Piece>, e.g. NervousIntern_Head; import it once with "Merge meshes" off and drop the
imported model into ReplicatedStorage > LotMeshes (art/README.md).

The same shapes are written to src/shared/Models/ActorShapes.luau, which the game builds as parts
until the meshes are imported, so this file is the one source for both.

Run from the repo root with Blender, or with the `bpy` package (see mmkit.py):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/actors.py
Writes art/exports/actors.fbx, the Luau file and art/previews/actors_blender.png (the whole cast,
three rows of seven). ACTOR_SAMPLES sets render samples, ACTOR_NO_RENDER=1 skips the render.

Coordinates are studs: Z up, the actor faces -Y, feet on Z = 0 (the base sits below that).
The actor's own left is +X.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402
from mascots import P, num  # noqa: E402

STUD = mmkit.STUD
LUAU_OUT = os.path.join(mmkit.REPO, "src", "shared", "Models", "ActorShapes.luau")
SAMPLES = int(os.environ.get("ACTOR_SAMPLES", "40"))
MAX_TRIS = 2500
PIECES = ("Body", "Head", "ArmL", "ArmR", "Base")


def lin(hex_color):
    h = hex_color.lstrip("#")
    srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb) + (1.0,)


def M(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return (
        Matrix.Translation(Vector(at))
        @ Euler([math.radians(r) for r in rot], "XYZ").to_matrix().to_4x4()
        @ Matrix.Diagonal(Vector((*scale, 1)))
    )


class Actor:
    """One actor: a bmesh per rig piece, plus every shape as a record for the Luau part version.
    Shapes take studs. Inside `with a.at(...)` they are relative to it; inside `with a.piece(...)`
    they belong to that piece. Shapes outside any piece go to the Head when they sit up by the
    head, else to the Body."""

    def __init__(self, name):
        self.name = name
        self.bms = {p: bmesh.new() for p in PIECES}
        self.mats = {}
        self.order = []
        self.stack = [Matrix.Identity(4)]
        self.pieces = [None]
        self.shapes = []  # (piece, kind, matrix without size, size, color, emit, top)
        self.wave = None  # the free arm that waves hello ("ArmL"/"ArmR"), if any
        self.float = False  # hovers (no feet on the ground): bobs higher

    class _Push:
        def __init__(self, stack, item):
            self.stack, self.item = stack, item

        def __enter__(self):
            self.stack.append(self.item)

        def __exit__(self, *exc):
            self.stack.pop()

    def at(self, at=(0, 0, 0), rot=(0, 0, 0)):
        return Actor._Push(self.stack, self.stack[-1] @ M(at, rot))

    def piece(self, name):
        return Actor._Push(self.pieces, name)

    def mat(self, color, emit=0.0, metal=0.0):
        key = (color, emit, metal)
        if key not in self.mats:
            self.mats[key] = len(self.order)
            self.order.append(key)
        return self.mats[key]

    def _put(self, bm_src, local, size, kind, color, emit, metal, top=None):
        """Move a unit shape (already sized) into its piece's bmesh."""
        world = self.stack[-1] @ local
        piece = self.pieces[-1]
        if piece is None:
            c = world.translation
            piece = "Head" if c.z > SHOULDER + 0.45 and abs(c.x) < 1.15 else "Body"
        bmesh.ops.transform(bm_src, matrix=Matrix.Scale(STUD, 4) @ world, verts=bm_src.verts)
        idx = self.mat(color, emit, metal)
        bm = self.bms[piece]
        vs = {v: bm.verts.new(v.co) for v in bm_src.verts}
        for f in bm_src.faces:
            bm.faces.new([vs[v] for v in f.verts]).material_index = idx
        bm_src.free()
        self.shapes.append((piece, kind, world, size, color, emit, top))

    def ball(self, at, radii, color, rot=(0, 0, 0), seg=8, rings=6, emit=0.0, metal=0.0):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
        self._put(bm, M(at, rot), tuple(2 * r for r in radii), "ball", color, emit, metal)

    def gem(self, at, radius, color, rot=(0, 0, 0), emit=0.0):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
        self._put(bm, M(at, rot), (2 * radius,) * 3, "ball", color, emit, 0.0)

    def box(self, at, size, color, rot=(0, 0, 0), chamfer=0.12, emit=0.0, metal=0.0, taper=1.0):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            if taper != 1.0 and v.co.z > 0:
                v.co.x *= taper
                v.co.y *= taper
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
        if chamfer > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(chamfer, min(size) * 0.45), segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
        # The part version has no taper: a box of the average width.
        k = (1 + taper) / 2
        self._put(bm, M(at, rot), (size[0] * k, size[1] * k, size[2]), "box", color, emit, metal)

    def cyl(self, at, r1, r2, length, color, rot=(0, 0, 0), seg=6, emit=0.0, metal=0.0, squash=1.0):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length)
        for v in bm.verts:
            v.co.y *= squash
        r = max(r1, r2)
        top = None if abs(r1 - r2) < 1e-6 else (r2 / r1 if r1 > 0 else 99.0)
        # Size is the widest end; `top` is the top's width over the bottom's.
        self._put(bm, M(at, rot), (2 * r, 2 * r * squash, length), "cyl", color, emit, metal, top=(r1, r2) if top is not None else None)

    def objects(self, offset=(0, 0, 0)):
        """One mesh object per non-empty piece, named <name>_<Piece>."""
        out = {}
        for piece in PIECES:
            bm = self.bms[piece]
            if not bm.faces:
                bm.free()
                continue
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            mesh = bpy.data.meshes.new(f"{self.name}_{piece}")
            bm.to_mesh(mesh)
            bm.free()
            for color, emit, metal in self.order:
                m = bpy.data.materials.new(f"Mat_{color.lstrip('#')}_{emit}_{metal}")
                m.use_nodes = True
                bsdf = m.node_tree.nodes["Principled BSDF"]
                bsdf.inputs["Base Color"].default_value = lin(color)
                bsdf.inputs["Roughness"].default_value = 0.42 if metal == 0 else 0.3
                bsdf.inputs["Metallic"].default_value = metal
                if emit > 0:
                    bsdf.inputs["Emission Color"].default_value = lin(color)
                    bsdf.inputs["Emission Strength"].default_value = emit
                m.diffuse_color = lin(color)
                mesh.materials.append(m)
            for p in mesh.polygons:
                p.use_smooth = False
            obj = bpy.data.objects.new(f"{self.name}_{piece}", mesh)
            obj.location = Vector(offset) * STUD
            bpy.context.scene.collection.objects.link(obj)
            out[piece] = obj
        return out


# --- The shared base body ----------------------------------------------------------------------
# Total height about 5.4 studs, like the current actors. Head is about 40% of it so faces read
# on a phone. Landmarks:
HIP = 1.25
SHOULDER = 2.75
HEAD_Z = 3.85  # head centre
HEAD = (1.12, 1.0, 1.05)  # head half-sizes


def legs(a, pants, shoes, spread=0.36):
    for s in (-1, 1):
        a.cyl((s * spread, 0, HIP / 2 + 0.15), 0.3, 0.34, HIP - 0.1, pants, seg=6)
        a.box((s * spread, -0.1, 0.17), (0.62, 0.85, 0.36), shoes, chamfer=0.12)


def torso(a, shirt, wide=1.0):
    a.cyl((0, 0, (HIP + SHOULDER) / 2), 0.72 * wide, 0.9 * wide, SHOULDER - HIP + 0.2, shirt, seg=8, squash=0.72)


def arm(a, side, sleeve, skin, rot=(0, 0, 0), held=None):
    """An arm hanging from the shoulder; `rot` swings it (X forward/back, Y out). `held` is a
    function drawing a prop in the hand's frame."""
    sx = side * 0.98
    name = "ArmL" if side > 0 else "ArmR"
    if held is None and -60 <= rot[0] <= 20 and a.wave is None:
        a.wave = name
    with a.piece(name), a.at((sx, 0, SHOULDER - 0.12), (rot[0], -side * rot[1], rot[2])):
        a.ball((0, 0, 0), (0.3, 0.3, 0.3), sleeve, seg=6, rings=4)
        a.cyl((0, 0, -0.55), 0.24, 0.29, 1.0, sleeve, seg=6)
        a.ball((0, 0, -1.15), (0.27, 0.27, 0.27), skin, seg=6, rings=4)
        if held:
            with a.at((0, 0, -1.15)):
                held(a)


def head(a, skin, eyes="#161220", mouth="smile", brows=None, blush=True, iris=None, shape="ball", eye_scale=(1, 1)):
    with a.piece("Head"):
        _head(a, skin, eyes, mouth, brows, blush, iris, shape, eye_scale)


def _head(a, skin, eyes, mouth, brows, blush, iris, shape, eye_scale):
    if shape == "box":
        a.box((0, 0, HEAD_Z), (2.0, 1.9, 2.1), skin, chamfer=0.22)
        fy = -0.97
    else:
        a.ball((0, 0, HEAD_Z), HEAD, skin, seg=10, rings=7)
        fy = -HEAD[1] * 0.9
    for s in (-1, 1):
        k = eye_scale[0] if s < 0 else eye_scale[1]
        with a.at((s * 0.4, fy, HEAD_Z + 0.02), (0, 0, s * -14)):
            a.ball((0, 0, 0), (0.17 * k, 0.08, 0.25 * k), eyes, seg=6, rings=4, emit=1.5 if iris else 0)
            a.ball((-0.05, -0.06, 0.09), (0.06, 0.03, 0.07), "#FFFFFF", seg=4, rings=3)
        if brows:
            a.box((s * 0.42, fy - 0.02, HEAD_Z + 0.38), (0.34, 0.08, 0.09), brows, rot=(0, s * 10 if mouth != "evil" else s * -22, 0), chamfer=0.03)
        if blush:
            a.ball((s * 0.72, fy + 0.22, HEAD_Z - 0.22), (0.17, 0.05, 0.09), "#F08A8A", seg=5, rings=3)
    z = HEAD_Z - 0.38
    if mouth == "smile":
        a.box((0, fy + 0.04, z), (0.32, 0.08, 0.1), "#7A2836", chamfer=0.03)
        for s in (-1, 1):
            a.box((s * 0.18, fy + 0.04, z + 0.05), (0.08, 0.08, 0.1), "#7A2836", chamfer=0.02)
    elif mouth == "nervous":
        for i in range(4):
            a.box((-0.2 + i * 0.13, fy + 0.04, z + (0.04 if i % 2 else -0.02)), (0.12, 0.08, 0.06), "#7A2836", chamfer=0.01)
    elif mouth == "grin":
        a.box((0, fy + 0.05, z), (0.48, 0.08, 0.18), "#FFFFFF", chamfer=0.04)
    elif mouth == "evil":
        a.box((0, fy + 0.04, z), (0.42, 0.08, 0.08), "#7A2836", rot=(0, 6, 0), chamfer=0.02)
        for s in (-1, 1):
            a.cyl((s * 0.11, fy + 0.03, z - 0.08), 0.04, 0.0, 0.12, "#FFFFFF", rot=(180, 0, 0), seg=4)


# --- Seven sample actors -----------------------------------------------------------------------


def nervous_intern(a):
    """Newcomer: plain clothes, one prop. A wobbly tower of coffee cups."""
    skin = "#F2C49C"
    legs(a, "#C9A86A", "#7A5434")
    torso(a, "#9CC9F0")
    a.box((0, -0.62, 2.2), (0.16, 0.06, 0.7), "#D83A3A", chamfer=0.02, taper=0.6)  # tie

    def cups(a):
        with a.at((0, -0.3, 0.1), (30, 0, 0)):
            for i in range(4):
                with a.at((math.sin(i * 1.7) * 0.08, 0, 0.18 + i * 0.42), (0, (i - 1.5) * 6, 0)):
                    a.cyl((0, 0, 0), 0.2, 0.26, 0.4, "#FFFFFF", seg=7)
                    a.cyl((0, 0, 0.02), 0.25, 0.25, 0.14, "#B87333", seg=7)

    def clipboard(a):
        a.box((0, -0.28, -0.25), (0.65, 0.08, 0.85), "#96623C", rot=(10, 0, 0), chamfer=0.04)
        a.box((0, -0.34, -0.22), (0.5, 0.04, 0.6), "#FAF6EC", rot=(10, 0, 0), chamfer=0.0)

    arm(a, 1, "#9CC9F0", skin, rot=(-30, 18, 0), held=cups)
    arm(a, -1, "#9CC9F0", skin, rot=(-18, 10, 0), held=clipboard)
    head(a, skin, mouth="nervous", brows="#5A3A22")
    # messy hair: a few facets sticking out
    a.ball((0, 0.12, HEAD_Z + 0.55), (1.15, 0.98, 0.6), "#6B4226", seg=7, rings=4)
    for i, (x, rz) in enumerate(((-0.6, 25), (0.1, -10), (0.65, -30))):
        a.cyl((x, -0.15, HEAD_Z + 1.0), 0.18, 0.0, 0.5, "#6B4226", rot=(-25, rz, 0), seg=4)
    # glasses
    for s in (-1, 1):
        a.cyl((s * 0.4, -HEAD[1] * 0.98, HEAD_Z + 0.02), 0.27, 0.27, 0.06, "#2E2C34", rot=(90, 0, 0), seg=8)
        a.cyl((s * 0.4, -HEAD[1] * 0.99, HEAD_Z + 0.02), 0.21, 0.21, 0.07, "#DDEFFF", rot=(90, 0, 0), seg=8)
    a.ball((1.05, -0.45, HEAD_Z + 0.4), (0.09, 0.06, 0.15), "#8FD6FF", seg=5, rings=3)  # sweat drop


def night_villain(a):
    """Pro: a costume that breaks the outline. Vampire with a huge spiky collar."""
    skin = "#D9DCE8"
    legs(a, "#1E1A2E", "#2E2C34")
    torso(a, "#2B1F48")
    a.box((0, -0.62, 2.3), (0.5, 0.06, 0.6), "#C8202F", chamfer=0.04, taper=0.2)
    # cape: a long tapered slab behind, flaring out at the bottom
    a.box((0, 0.6, 1.6), (2.4, 0.18, 2.6), "#C8202F", rot=(8, 0, 0), chamfer=0.05, taper=0.55)
    a.box((0, 0.5, 1.6), (2.3, 0.16, 2.5), "#2B1F48", rot=(8, 0, 0), chamfer=0.05, taper=0.55)
    # collar spikes
    for s in (-1, 1):
        for i, (h, r) in enumerate(((1.4, 10), (1.1, 35))):
            a.cyl((s * (0.55 + i * 0.3), 0.35, SHOULDER + 0.6), 0.28, 0.0, h, "#C8202F", rot=(-10, s * r, 0), seg=4)

    def lantern(a):
        a.cyl((0, 0, -0.35), 0.03, 0.03, 0.4, "#2E2C34", seg=4)
        a.cyl((0, 0, -0.75), 0.26, 0.22, 0.45, "#F5B82E", seg=6, emit=4)
        a.cyl((0, 0, -0.48), 0.1, 0.3, 0.12, "#2E2C34", seg=6)
        a.cyl((0, 0, -1.02), 0.3, 0.3, 0.08, "#2E2C34", seg=6)

    arm(a, 1, "#2B1F48", skin, rot=(-25, 22, 0), held=lantern)
    arm(a, -1, "#2B1F48", skin, rot=(-70, 40, 0))
    head(a, skin, eyes="#FF2E4A", mouth="evil", brows="#161220", blush=False, iris=True)
    # slicked hair with a widow's peak
    a.ball((0, 0.12, HEAD_Z + 0.42), (1.15, 1.0, 0.7), "#161220", seg=8, rings=4)
    a.cyl((0, -0.92, HEAD_Z + 0.45), 0.25, 0.0, 0.5, "#161220", rot=(180, 0, 0), seg=3)


def box_office_king(a):
    """Superstar: gold is the reward colour. Gold suit, cape, crown, shades, money stack."""
    skin = "#C68A5A"
    legs(a, "#2E2C34", "#F5B82E")
    torso(a, "#F5B82E", wide=1.12)
    a.box((0, -0.62, 1.4), (1.5, 0.12, 0.28), "#7A1F2B", chamfer=0.05)  # belt
    a.box((0, -0.7, 1.4), (0.5, 0.1, 0.4), "#FFE58A", chamfer=0.05, metal=0.5)  # buckle
    # cape and fur collar
    a.box((0, 0.65, 1.5), (2.7, 0.18, 2.9), "#C8202F", rot=(10, 0, 0), chamfer=0.05, taper=0.65)
    for i in range(9):
        ang = math.radians(-120 + i * 30)
        a.gem((math.sin(ang) * 0.95, math.cos(ang) * 0.55 + 0.1, SHOULDER + 0.1), 0.32, "#FAF6EC")

    def money(a):
        with a.at((0, -0.25, 0.25), (0, 0, 20)):
            for i in range(4):
                a.box((0, 0, i * 0.17), (0.9, 0.5, 0.16), "#5BBF5A", rot=(0, 0, i * 7), chamfer=0.03)
            a.box((0, 0, 0.3), (0.2, 0.52, 0.7), "#F5B82E", chamfer=0.0)

    arm(a, 1, "#F5B82E", skin, rot=(-60, 25, 0), held=money)
    arm(a, -1, "#F5B82E", skin, rot=(10, 35, 0))
    head(a, skin, mouth="grin")
    a.ball((0, 0.2, HEAD_Z + 0.5), (1.14, 0.9, 0.62), "#161220", seg=8, rings=4)
    # sunglasses
    a.box((0, -1.0, HEAD_Z + 0.05), (1.5, 0.12, 0.38), "#161220", chamfer=0.06)
    a.box((-0.35, -1.06, HEAD_Z + 0.12), (0.3, 0.04, 0.08), "#6E7078", chamfer=0.0)
    # crown: a ring of spikes with gems
    a.cyl((0, 0.05, HEAD_Z + 1.0), 0.75, 0.82, 0.36, "#F5B82E", seg=8, metal=0.5)
    for i in range(8):
        ang = i * math.pi / 4
        a.cyl((math.cos(ang) * 0.75, math.sin(ang) * 0.75 + 0.05, HEAD_Z + 1.4), 0.16, 0.0, 0.5, "#F5B82E", seg=4, metal=0.5)
    a.gem((0, -0.78, HEAD_Z + 1.0), 0.15, "#C8202F")


def phantom_auteur(a):
    """Icon: a one-of-a-kind silhouette. Floats on a ghost tail, film strip circling him."""
    a.float = True
    skin = "#ECECE4"
    # ghostly robe instead of legs, curling to a point, hovering
    a.cyl((0, 0.1, 1.3), 0.95, 0.75, 1.0, "#3B2470", seg=8, squash=0.8)
    a.cyl((0.15, 0.3, 0.55), 0.3, 0.95, 0.7, "#3B2470", rot=(10, 0, 0), seg=8, squash=0.8)
    a.cyl((0.4, 0.55, 0.15), 0.0, 0.3, 0.5, "#3B2470", rot=(25, 20, 0), seg=6)
    torso(a, "#3B2470")
    # cloak with a prismatic lining
    a.box((0, 0.6, 2.2), (2.5, 0.16, 2.2), "#161220", rot=(6, 0, 0), chamfer=0.05, taper=0.7)
    for i, c in enumerate(("#FF5FD2", "#A04DFF", "#3A8DFF", "#4CC764", "#FFC21A")):
        a.box((-1.0 + i * 0.5, 0.5, 2.1), (0.48, 0.05, 1.9), c, rot=(6, 0, 0), chamfer=0.0, emit=1.5)

    def megaphone(a):
        with a.at((0, -0.2, 0.0), (100, 0, 0)):
            a.cyl((0, 0, 0.4), 0.12, 0.4, 0.8, "#F5B82E", seg=8, metal=0.4)
            a.cyl((0, 0, 0.8), 0.42, 0.42, 0.06, "#161220", seg=8)

    arm(a, 1, "#3B2470", skin, rot=(-95, 20, 0), held=megaphone)
    arm(a, -1, "#3B2470", skin, rot=(-40, 50, 0))
    head(a, skin, eyes="#B6FF5C", mouth="evil", blush=False, iris=True, brows="#161220")
    # white half mask on the left of the face
    a.ball((-0.42, -0.72, HEAD_Z + 0.1), (0.62, 0.32, 0.75), "#FAF6EC", seg=8, rings=5)
    a.ball((-0.4, -1.02, HEAD_Z + 0.08), (0.16, 0.05, 0.22), "#161220", rot=(0, 0, 14), seg=6, rings=4)
    # tall crooked top hat
    with a.at((0.1, 0.05, HEAD_Z + 0.85), (0, 10, 0)):
        a.cyl((0, 0, 0), 1.2, 1.2, 0.12, "#161220", seg=10)
        a.cyl((0, 0, 0.75), 0.72, 0.8, 1.4, "#161220", seg=8)
        a.cyl((0, 0, 0.25), 0.82, 0.82, 0.24, "#FF5FD2", seg=8, emit=2)
    # film strip orbiting him
    n = 14
    for i in range(n):
        ang = 2 * math.pi * i / n
        x, y = math.cos(ang) * 2.1, math.sin(ang) * 1.3
        z = 2.6 + math.sin(ang * 2) * 0.35
        a.box((x, y, z), (0.55, 0.06, 0.4), "#2E2C34", rot=(0, 0, math.degrees(ang) + 90), chamfer=0.0)
        a.box((x, y, z), (0.4, 0.08, 0.26), ("#FF5FD2", "#3A8DFF", "#FFC21A", "#4CC764")[i % 4], rot=(0, 0, math.degrees(ang) + 90), chamfer=0.0, emit=2.5)


def zombie_extra(a):
    """Newcomer (Romance): a lovesick zombie extra, arms out, holding a wilted rose."""
    skin = "#9CC77A"
    legs(a, "#5A5F7A", "#5A4636")
    torso(a, "#C9B48A")
    a.box((0.35, -0.6, 1.6), (0.4, 0.06, 0.35), "#9CC77A", rot=(0, 20, 0), chamfer=0.0)  # hole in the shirt
    a.box((-0.3, -0.6, 2.4), (0.5, 0.06, 0.12), "#7A1F2B", rot=(0, -12, 0), chamfer=0.0)  # stain

    def rose(a):
        with a.at((0, -0.25, 0.0), (90, 0, 0)):
            a.cyl((0, 0, 0.35), 0.04, 0.04, 0.8, "#4F7A3A", seg=4)
            with a.at((0, 0, 0.75), (60, 0, 0)):
                a.gem((0, 0, 0), 0.2, "#7A1F2B")

    arm(a, 1, "#C9B48A", skin, rot=(-88, 6, 0), held=rose)
    arm(a, -1, "#C9B48A", skin, rot=(-80, -4, 0))
    a.box((-0.98, -0.75, SHOULDER - 0.1), (0.62, 0.3, 0.2), "#FAF6EC", chamfer=0.04)  # bandage
    head(a, skin, mouth="nervous", blush=False, eye_scale=(0.75, 1.2))
    a.box((0.55, -0.98, HEAD_Z + 0.55), (0.5, 0.06, 0.06), "#3E5A2E", rot=(0, 25, 0), chamfer=0.0)  # stitches
    for i in range(3):
        a.box((0.38 + i * 0.16, -0.99, HEAD_Z + 0.53 + i * 0.07), (0.05, 0.07, 0.2), "#3E5A2E", rot=(0, 25, 0), chamfer=0.0)
    for x, z, r in ((-0.5, 0.75, 0.4), (0.25, 0.85, 0.45), (0.75, 0.55, 0.3), (-0.1, 0.6, 0.55)):
        a.gem((x, 0.2, HEAD_Z + z), r, "#3B2A1E")
    with a.at((0.3, 0.0, HEAD_Z + 1.2), (0, 0, 0)):
        a.gem((0, 0, 0), 0.22, "#E8333A")  # a little heart-ish flower in the hair


def robot_sidekick(a):
    """Rising (Sci-Fi): a boxy robot buddy with a screen face and a spring antenna."""
    metal, trim = "#BFC6D6", "#2E86DE"
    for s in (-1, 1):
        a.cyl((s * 0.38, 0, 0.75), 0.22, 0.22, 1.2, "#6E7078", seg=6, metal=0.4)
        a.box((s * 0.38, -0.1, 0.2), (0.7, 0.95, 0.4), trim, chamfer=0.1)
    a.box((0, 0, 2.0), (1.9, 1.3, 1.6), metal, chamfer=0.18, metal=0.3)
    a.cyl((0, -0.68, 2.1), 0.32, 0.32, 0.1, "#F5B82E", rot=(90, 0, 0), seg=8, emit=1.0)  # chest dial
    for i, c in enumerate(("#E8333A", "#4CC764", "#F5B82E")):
        a.box((-0.55 + i * 0.22, -0.66, 1.5), (0.14, 0.06, 0.14), c, chamfer=0.0, emit=2.0)

    def claw(a):
        for s in (-1, 1):
            a.box((s * 0.14, -0.05, -0.25), (0.1, 0.18, 0.4), "#6E7078", rot=(0, s * -15, 0), chamfer=0.03)

    arm(a, 1, trim, "#6E7078", rot=(-40, 20, 0), held=claw)
    arm(a, -1, trim, "#6E7078", rot=(150, 25, 0), held=claw)  # waving hello
    a.box((0, 0, HEAD_Z), (2.2, 1.7, 1.7), metal, chamfer=0.2, metal=0.3)
    a.box((0, -0.82, HEAD_Z), (1.8, 0.1, 1.25), "#1B2340", chamfer=0.06)  # screen
    for s in (-1, 1):
        a.box((s * 0.42, -0.89, HEAD_Z + 0.12), (0.3, 0.06, 0.42), "#5CF2FF", chamfer=0.05, emit=4)
    a.box((0, -0.89, HEAD_Z - 0.32), (0.55, 0.06, 0.1), "#5CF2FF", chamfer=0.02, emit=4)
    for s in (-1, 1):
        a.cyl((s * 1.18, 0, HEAD_Z), 0.3, 0.3, 0.2, trim, rot=(0, 90, 0), seg=8)  # ear bolts
    for i in range(4):
        a.cyl((0.4, 0, HEAD_Z + 0.95 + i * 0.16), 0.1, 0.1, 0.1, "#6E7078", seg=6)
    a.gem((0.4, 0, HEAD_Z + 1.65), 0.2, "#E8333A", emit=3)


def alien_captain(a):
    """Star (Sci-Fi): an alien captain. Huge head, three eyes, antennae, cape and shoulder pads."""
    skin = "#7BE07B"
    legs(a, "#3B2470", "#FAF6EC")
    torso(a, "#3B2470", wide=1.05)
    a.box((0, 0.6, 1.7), (2.5, 0.16, 2.4), "#2E86DE", rot=(8, 0, 0), chamfer=0.05, taper=0.6)  # cape
    for s in (-1, 1):
        a.box((s * 1.08, 0, SHOULDER + 0.1), (0.8, 1.0, 0.35), "#F5B82E", rot=(0, s * -15, 0), chamfer=0.12)
    a.gem((0, -0.68, 2.4), 0.22, "#5CF2FF", emit=2)

    def ray_gun(a):
        with a.at((0, -0.2, -0.05), (90, 0, 0)):
            a.cyl((0, 0, 0.15), 0.14, 0.1, 0.8, "#E8333A", seg=6)
            a.ball((0, 0, -0.2), (0.25, 0.25, 0.25), "#E8333A", seg=6, rings=4)
            a.gem((0, 0, 0.6), 0.12, "#5CF2FF", emit=4)

    arm(a, 1, "#3B2470", skin, rot=(-80, 10, 0), held=ray_gun)
    arm(a, -1, "#3B2470", skin, rot=(-10, 30, 0))
    # big bulb head, taller than the shared one
    a.ball((0, 0, HEAD_Z + 0.25), (1.2, 1.05, 1.3), skin, seg=10, rings=7)
    for x, z, k in ((-0.45, 0.1, 1.0), (0.45, 0.1, 1.0), (0, 0.65, 0.8)):
        with a.at((x, -0.98, HEAD_Z + z)):
            a.ball((0, 0, 0), (0.22 * k, 0.1, 0.27 * k), "#161220", seg=6, rings=4)
            a.ball((-0.06, -0.07, 0.1), (0.07, 0.03, 0.08), "#FFFFFF", seg=4, rings=3)
    a.box((0, -1.0, HEAD_Z - 0.45), (0.35, 0.08, 0.1), "#2E4A22", chamfer=0.03)
    for s in (-1, 1):
        a.cyl((s * 0.5, 0, HEAD_Z + 1.65), 0.05, 0.05, 0.9, skin, rot=(0, s * 20, 0), seg=4)
        a.gem((s * 0.66, 0, HEAD_Z + 2.08), 0.17, "#FF5FD2", emit=3)



def commando(a):
    """Pro (Action): eyepatch, red bandana, chunky vest and a big bazooka on the shoulder."""
    skin = "#C68A5A"
    legs(a, "#5B6B3A", "#2E2C34")
    for s in (-1, 1):
        a.box((s * 0.36, -0.1, 0.3), (0.7, 0.95, 0.55), "#3A2E22", chamfer=0.1)
    torso(a, "#6B7A44", wide=1.15)
    a.box((0, -0.05, 2.1), (1.85, 1.35, 1.1), "#4A5530", chamfer=0.12)  # vest
    for x in (-0.45, 0.0, 0.45):
        a.box((x, -0.72, 1.85), (0.32, 0.12, 0.42), "#3A4426", chamfer=0.05)
    a.box((0, -0.05, 1.3), (1.8, 1.3, 0.25), "#3A2E22", chamfer=0.05)
    # bazooka over the left shoulder
    with a.piece("Body"), a.at((0.9, 0.2, SHOULDER + 0.35), (0, 0, 0)):
        a.cyl((0, 0, 0), 0.32, 0.32, 3.0, "#5B6B3A", rot=(80, 0, 0), seg=8)
        a.cyl((0, -1.5, 0.27), 0.42, 0.36, 0.4, "#3A4426", rot=(80, 0, 0), seg=8)
        a.cyl((0, 1.5, -0.27), 0.36, 0.42, 0.4, "#3A4426", rot=(80, 0, 0), seg=8)
    arm(a, 1, skin, skin, rot=(-170, -10, 0))
    arm(a, -1, skin, skin, rot=(-20, 20, 0))
    head(a, skin, mouth="grin", brows="#2A1A12", eye_scale=(0.01, 1.0))
    a.cyl((-0.4, -0.98, HEAD_Z + 0.02), 0.27, 0.27, 0.1, "#161220", rot=(90, 0, 0), seg=6)  # eyepatch
    a.box((0, -0.05, HEAD_Z + 0.2), (2.3, 2.1, 0.12), "#161220", rot=(0, -14, 0), chamfer=0.0)
    a.ball((0, 0.12, HEAD_Z + 0.5), (1.15, 1.0, 0.6), "#2A1A12", seg=8, rings=4)
    a.box((0, 0.0, HEAD_Z + 0.58), (2.3, 2.1, 0.32), "#E8333A", chamfer=0.1)  # bandana
    for s in (-1, 1):
        a.box((0.3 + s * 0.2, 1.15, HEAD_Z + 0.4), (0.25, 0.5, 0.12), "#E8333A", rot=(s * 25, 0, 0), chamfer=0.03)
    a.box((-0.5, -1.0, HEAD_Z - 0.55), (0.06, 0.06, 0.45), "#A0603A", rot=(0, 25, 0), chamfer=0.0)  # scar


def cupid(a):
    """Superstar (Romance): a cherub actor with little wings, a heart bow and floating hearts."""
    skin = "#F7D2B5"
    legs(a, "#FAF6EC", "#F5B82E")
    torso(a, "#FF9AC4")
    a.box((0, -0.05, 1.3), (1.75, 1.3, 0.3), "#F5B82E", chamfer=0.06, metal=0.4)
    for s in (-1, 1):  # wings, three feathers each
        for i in range(3):
            with a.piece("Body"):
                a.ball((s * (0.65 + i * 0.35), 0.75, 2.6 + i * 0.12), (0.4, 0.12, 0.55 - i * 0.08), "#FFFFFF", rot=(0, s * (40 - i * 15), 0), seg=6, rings=4)

    def bow(a):
        with a.at((0, -0.2, 0), (0, 0, 0)):
            for s in (-1, 1):
                a.cyl((0, 0, s * 0.55), 0.06, 0.04, 1.1, "#F5B82E", rot=(s * 20, 0, 0), seg=4, metal=0.4)
            a.cyl((0, -0.55, 0), 0.03, 0.03, 1.1, "#C8202F", rot=(90, 0, 0), seg=4)
            a.gem((0, -1.1, 0), 0.15, "#FF5FD2", emit=2)

    arm(a, 1, "#FF9AC4", skin, rot=(-85, 10, 0), held=bow)
    arm(a, -1, "#FF9AC4", skin, rot=(-85, -25, 0))
    head(a, skin, brows="#C88A3A")
    for x, z, r in ((0, 0.75, 0.5), (-0.6, 0.55, 0.42), (0.6, 0.55, 0.42), (-0.85, 0.05, 0.35), (0.85, 0.05, 0.35), (0, 0.4, 0.6)):
        a.gem((x, 0.25, HEAD_Z + z), r, "#F5C94A")  # golden curls
    a.cyl((0, 0.1, HEAD_Z + 1.45), 0.65, 0.65, 0.1, "#FFE58A", seg=10, emit=3)  # halo
    for x, z in ((-2.0, 4.4), (1.9, 5.0), (-1.8, 2.3)):
        with a.at((x, 0, z), (0, 0, 0)):
            for s in (-1, 1):
                a.ball((s * 0.12, 0, 0.08), (0.17, 0.08, 0.17), "#FF5FD2", seg=6, rings=4, emit=1.5)
            a.cyl((0, 0, -0.08), 0.24, 0.0, 0.26, "#FF5FD2", rot=(180, 0, 45), seg=4, emit=1.5)


def silent_clown(a):
    """Legend (Comedy): straight out of a silent film, all black, white and grey. Huge ruffle."""
    W, L, M, D = "#F2F2F2", "#B8B8B8", "#6E6E6E", "#262626"
    legs(a, W, D)
    for s in (-1, 1):
        a.box((s * 0.38, -0.35, 0.18), (0.7, 1.4, 0.36), D, chamfer=0.14)  # long shoes
    torso(a, W, wide=1.2)
    for z in (1.6, 2.1):
        a.gem((0, -0.75, z), 0.17, D)  # pom-pom buttons
    for i in range(12):  # big ruffle collar
        ang = 2 * math.pi * i / 12
        a.cyl((math.cos(ang) * 0.9, math.sin(ang) * 0.75, SHOULDER + 0.05), 0.0, 0.42, 0.3, L if i % 2 else W, rot=(math.sin(ang) * -70, math.cos(ang) * 70, 0), seg=4)

    def flower(a):
        a.cyl((0, -0.1, 0.35), 0.04, 0.04, 0.7, M, seg=4)
        for i in range(5):
            ang = 2 * math.pi * i / 5
            a.ball((math.cos(ang) * 0.2, -0.1, 0.75 + math.sin(ang) * 0.2), (0.14, 0.06, 0.14), W, seg=5, rings=3)
        a.gem((0, -0.15, 0.75), 0.1, D)

    arm(a, 1, W, W, rot=(-60, 25, 0), held=flower)
    arm(a, -1, W, W, rot=(-140, 45, 0))  # big wave
    head(a, W, eyes=D, brows=D, blush=False, mouth="smile")
    for s in (-1, 1):
        a.box((s * 0.4, -0.96, HEAD_Z + 0.45), (0.06, 0.05, 0.35), D, chamfer=0.0)  # eye lines
        a.gem((s * 1.0, 0.2, HEAD_Z + 0.3), 0.32, L)  # side tufts
    a.box((0, -0.97, HEAD_Z - 0.38), (0.8, 0.05, 0.22), D, chamfer=0.06)
    a.gem((0, -1.05, HEAD_Z - 0.05), 0.18, M)  # nose
    a.cyl((0.15, 0.1, HEAD_Z + 1.05), 0.6, 0.6, 0.12, D, seg=8)
    a.cyl((0.15, 0.1, HEAD_Z + 1.35), 0.35, 0.4, 0.6, D, rot=(0, 10, 0), seg=8)  # tiny hat
    for x, z in ((-1.9, 4.6), (1.8, 5.3), (-1.7, 2.3), (2.0, 2.7)):
        a.gem((x, 0, z), 0.13, "#FFFFFF", emit=4)  # film grain sparkles


def brain_jar(a):
    """Legend (Sci-Fi): a giant glowing brain in a glass dome, walking on stubby robot legs."""
    metal = "#AEB3C2"
    for s in (-1, 1):
        a.cyl((s * 0.6, 0, 0.7), 0.16, 0.16, 1.1, "#6E7078", seg=6, metal=0.5)
        a.ball((s * 0.6, 0, 1.15), (0.25, 0.25, 0.25), metal, seg=6, rings=4, metal=0.5)
        a.box((s * 0.6, -0.1, 0.15), (0.8, 1.0, 0.3), "#FF5A2E", chamfer=0.1)
    a.cyl((0, 0, 1.55), 1.25, 1.35, 0.8, metal, seg=10, metal=0.5)  # base
    for i in range(6):
        ang = 2 * math.pi * i / 6
        a.gem((math.cos(ang) * 1.3, math.sin(ang) * 1.3, 1.55), 0.12, ("#FF5A2E", "#5CF2FF")[i % 2], emit=3)
    a.cyl((0, 0, 2.05), 1.35, 1.35, 0.2, "#FF5A2E", seg=10)
    # brain: lumpy pink gems
    for x, y, z, r in ((0, 0, 3.0, 0.95), (-0.55, -0.2, 3.3, 0.6), (0.55, -0.2, 3.3, 0.6), (-0.5, 0.3, 2.7, 0.6), (0.5, 0.3, 2.7, 0.6), (0, -0.45, 2.75, 0.55), (0, 0.1, 3.6, 0.55)):
        a.gem((x, y, z), r, "#FF8FB8", emit=0.4)
    for s in (-1, 1):
        a.ball((s * 0.35, -0.95, 2.85), (0.16, 0.07, 0.22), "#161220", seg=6, rings=4)
        a.ball((s * 0.35 - 0.05, -1.0, 2.95), (0.05, 0.03, 0.06), "#FFFFFF", seg=4, rings=3)
    # glass dome: a few thin glowing ribs instead of glass, so it reads in Roblox
    for i in range(6):
        ang = 180 * i / 6
        a.cyl((0, 0, 2.15), 1.32, 1.32, 0.05, "#5CF2FF", rot=(90, 0, ang), seg=12, emit=2) if False else None
    a.cyl((0, 0, 4.4), 0.6, 0.6, 0.15, metal, seg=10, metal=0.5)
    a.cyl((0, 0, 4.75), 0.06, 0.06, 0.6, "#6E7078", seg=4)
    a.gem((0, 0, 5.1), 0.2, "#5CF2FF", emit=4)
    for s in (-1, 1):
        a.box((s * 1.3, 0, 3.2), (0.1, 0.1, 2.3), "#5CF2FF", emit=2, chamfer=0.0)
    # sparks
    for x, z in ((-1.9, 4.2), (1.8, 4.8)):
        a.gem((x, 0, z), 0.16, "#5CF2FF", emit=5)


def golden_muse(a):
    """Icon (Romance): a living gold award statue, wings and halo, standing on a mini plinth."""
    gold, gold2 = "#F5B82E", "#FFD866"
    a.cyl((0, 0, 0.9), 1.25, 0.75, 1.8, gold, seg=10, squash=0.85, metal=0.2)  # gown
    for i in range(6):
        a.box((math.cos(i) * 0.0 + (i - 2.5) * 0.4, -0.95 + abs(i - 2.5) * 0.1, 0.9), (0.08, 0.08, 1.7), gold2, rot=(0, (i - 2.5) * -6, 0), chamfer=0.0, metal=0.2)
    torso(a, gold)
    for s in (-1, 1):  # big wings
        for i in range(4):
            with a.piece("Body"):
                a.ball((s * (0.75 + i * 0.38), 0.75, 3.1 + i * 0.12), (0.42, 0.12, 0.75 - i * 0.12), gold2 if i % 2 else "#FFE9A0", rot=(0, s * (45 - i * 12), 0), seg=6, rings=4)

    def star(a):
        a.cyl((0, -0.1, 0.4), 0.05, 0.05, 0.8, gold, seg=4, metal=0.2)
        a.gem((0, -0.1, 0.95), 0.35, "#FFFFFF", emit=4)

    arm(a, 1, gold, gold, rot=(-175, -8, 0), held=star)
    arm(a, -1, gold, gold, rot=(-20, 25, 0))
    head(a, gold2, eyes="#7A4A10", brows="#B8860B", blush=False)
    for x, y, z, r in ((0, 0.25, 0.6, 0.85), (-0.9, 0.3, -0.1, 0.55), (0.9, 0.3, -0.1, 0.55), (0, 0.65, -0.5, 0.6)):
        a.gem((x, y, HEAD_Z + z), r, gold)
    a.cyl((0, 0.15, HEAD_Z + 1.5), 0.75, 0.75, 0.1, "#FFFFFF", seg=12, emit=4)
    for i, c in enumerate(("#FF5FD2", "#A04DFF", "#3A8DFF", "#4CC764", "#FFC21A")):
        ang = 2 * math.pi * i / 5
        a.gem((math.cos(ang) * 2.0, math.sin(ang) * 0.8, 3.0 + math.sin(ang * 2) * 0.8), 0.18, c, emit=4)


def mech_hero(a):
    """Icon (Action): a tiny action hero piloting a huge mech suit with jet flames."""
    red, steel, dark = "#C8202F", "#AEB3C2", "#2E2C34"
    for s in (-1, 1):  # chunky mech legs
        a.box((s * 0.75, 0, 0.9), (0.8, 0.9, 1.4), steel, chamfer=0.15, metal=0.4)
        a.box((s * 0.75, -0.15, 0.2), (1.0, 1.3, 0.4), dark, chamfer=0.12)
        a.cyl((s * 0.75, 0.3, 0.0), 0.0, 0.35, 0.5, "#FF8A2E", rot=(0, 0, 0), seg=6, emit=6) if False else None
    a.box((0, 0, 2.4), (2.8, 1.8, 1.8), red, chamfer=0.25, metal=0.3)  # hull
    a.box((0, -0.92, 2.35), (1.3, 0.1, 0.5), "#F5B82E", chamfer=0.05, emit=1.0)
    for s in (-1, 1):
        a.box((s * 1.75, 0, 3.0), (0.9, 1.3, 0.9), steel, chamfer=0.2, metal=0.4)  # shoulders
        with a.at((s * 1.75, -0.2, 2.2), (-30, 0, 0)):
            a.box((0, 0, -0.5), (0.7, 0.7, 1.4), red, chamfer=0.15)
            a.box((0, 0, -1.35), (0.9, 0.9, 0.5), dark, chamfer=0.1)  # fists
        a.cyl((s * 0.85, 1.1, 2.5), 0.3, 0.35, 1.0, steel, seg=7, metal=0.5)  # jets
        a.cyl((s * 0.85, 1.1, 1.65), 0.3, 0.0, 0.8, "#FF8A2E", rot=(180, 0, 0), seg=6, emit=6)
    # cockpit dome with the tiny pilot inside
    a.cyl((0, 0, 3.35), 1.0, 1.0, 0.15, dark, seg=10)
    with a.at((0, -0.05, 2.6), (0, 0, 0)):
        a.ball((0, 0, HEAD_Z - 2.85), (0.55, 0.5, 0.52), "#C68A5A", seg=8, rings=6)
        for s in (-1, 1):
            a.ball((s * 0.2, -0.45, HEAD_Z - 2.8), (0.09, 0.05, 0.13), "#161220", seg=5, rings=3)
        a.box((0, -0.05, HEAD_Z - 2.55), (1.15, 1.05, 0.2), red, chamfer=0.05)  # headband
        a.box((0, -0.5, HEAD_Z - 3.08), (0.25, 0.05, 0.06), "#7A2836", chamfer=0.0)
    a.ball((0, 0, 3.6), (1.0, 0.95, 0.95), "#9FE8FF", seg=10, rings=5, emit=0.4)  # glass
    for i in range(5):
        ang = math.pi * i / 4
        a.box((math.cos(ang) * 0.98, -0.1, 3.4 + math.sin(ang) * 0.95), (0.12, 0.2, 0.3), dark, rot=(0, -math.degrees(ang) + 90, 0), chamfer=0.0)
    a.gem((0, 0, 4.7), 0.2, "#FFC21A", emit=3)


def stunt_double(a):
    """Newcomer (Action): a stunt double who has clearly done one stunt too many. Helmet, sling,
    plasters, still giving a big thumbs up."""
    skin = "#7A4A2E"
    legs(a, "#2E86DE", "#F5B82E")
    a.box((0.36, -0.36, 0.9), (0.66, 0.1, 0.5), "#FAF6EC", chamfer=0.04)  # knee pad
    torso(a, "#FF8A1F")
    a.box((0, -0.62, 2.1), (1.2, 0.06, 0.18), "#FAF6EC", chamfer=0.0)
    a.box((0, -0.62, 1.8), (1.2, 0.06, 0.18), "#FAF6EC", chamfer=0.0)
    arm(a, 1, "#FF8A1F", skin, rot=(-70, 25, 0), held=lambda a: a.box((0, -0.05, 0.25), (0.14, 0.16, 0.4), skin, chamfer=0.04))
    arm(a, -1, "#FAF6EC", "#FAF6EC", rot=(-60, -5, 0))  # arm in a cast
    a.box((-0.6, -0.55, 2.2), (1.2, 0.15, 0.2), "#4A88D8", rot=(0, 30, 0), chamfer=0.04)  # sling strap
    head(a, skin, mouth="grin", brows="#161220")
    a.box((0.55, -0.95, HEAD_Z - 0.15), (0.35, 0.06, 0.14), "#F2C49C", rot=(0, 30, 0), chamfer=0.02)  # plaster
    a.box((0.55, -0.96, HEAD_Z - 0.15), (0.14, 0.06, 0.35), "#F2C49C", rot=(0, 30, 0), chamfer=0.02)
    a.ball((0, 0.1, HEAD_Z + 0.55), (1.2, 1.08, 0.75), "#E8333A", seg=10, rings=4)  # crash helmet
    a.box((0, 0.1, HEAD_Z + 1.2), (0.3, 2.0, 0.2), "#FAF6EC", chamfer=0.05)
    a.box((0, -0.6, HEAD_Z + 0.95), (1.4, 0.7, 0.12), "#5CF2FF", rot=(-25, 0, 0), chamfer=0.05, emit=0.5)  # visor up
    a.box((1.1, -0.6, HEAD_Z + 0.75), (0.3, 0.1, 0.25), "#F5B82E", chamfer=0.04)


def soap_star(a):
    """Rising (Romance): a soap opera star mid-gasp. Huge curly hair, sunglasses on the head,
    hand on the forehead, phone with a shocking text."""
    skin = "#D9A27A"
    legs(a, "#FAF6EC", "#C8202F")
    torso(a, "#FF5FD2")
    for s in (-1, 1):
        a.box((s * 0.95, 0, SHOULDER - 0.05), (0.7, 1.0, 0.45), "#FF5FD2", rot=(0, s * -10, 0), chamfer=0.15)  # puff sleeves

    def phone(a):
        a.box((0, -0.18, 0.2), (0.35, 0.08, 0.6), "#2E2C34", rot=(20, 0, 0), chamfer=0.04)
        a.box((0, -0.24, 0.22), (0.28, 0.04, 0.48), "#9FE8FF", rot=(20, 0, 0), chamfer=0.02, emit=1.5)

    arm(a, 1, "#FF5FD2", skin, rot=(-50, 20, 0), held=phone)
    arm(a, -1, "#FF5FD2", skin, rot=(-160, -30, 0))  # back of the hand on the forehead
    head(a, skin, mouth="grin" if False else "smile", brows="#3A2016")
    a.ball((0, -0.95, HEAD_Z - 0.4), (0.16, 0.06, 0.14), "#7A2836", seg=6, rings=3)  # gasp
    for x, y, z, r in ((0, 0.2, 0.8, 0.8), (-0.85, 0.3, 0.35, 0.6), (0.85, 0.3, 0.35, 0.6), (-1.1, 0.4, -0.35, 0.55),
                       (1.1, 0.4, -0.35, 0.55), (-0.45, -0.3, 0.95, 0.5), (0.45, -0.3, 0.95, 0.5), (0, 0.8, -0.2, 0.7)):
        a.gem((x, y, HEAD_Z + z), r, "#7A3A1A")
    a.box((0, -0.55, HEAD_Z + 1.15), (1.3, 0.25, 0.3), "#161220", rot=(-20, 0, 0), chamfer=0.08)  # sunglasses up top
    for s in (-1, 1):
        a.gem((s * 1.05, -0.1, HEAD_Z - 0.55), 0.13, "#F5B82E")  # earrings


def hotdog_mascot(a):
    """Rising (Comedy): an ad model who only ever gets cast as the hot dog. Bun costume, mustard
    squiggle, face in the hole, waving a sign."""
    skin = "#F0C49C"
    legs(a, "#C8202F", "#FAF6EC")
    # bun: two tall halves around the body, sausage in the middle
    for s in (-1, 1):
        a.ball((s * 0.75, 0.15, 2.6), (0.55, 0.85, 2.15), "#E8A85A", seg=8, rings=6)
    a.ball((0, 0.0, 2.7), (0.75, 0.8, 2.25), "#C8502F", seg=8, rings=6)
    for i in range(6):  # mustard squiggle
        a.box(((-1) ** i * 0.15, -0.8, 1.5 + i * 0.32), (0.5, 0.1, 0.12), "#FFD21A", rot=(0, (-1) ** i * 35, 0), chamfer=0.04)

    def sign(a):
        a.cyl((0, -0.1, 0.6), 0.05, 0.05, 1.4, "#96623C", seg=4)
        a.box((0, -0.12, 1.4), (1.1, 0.08, 0.7), "#FAF6EC", chamfer=0.05)
        a.box((0, -0.18, 1.4), (0.75, 0.04, 0.18), "#C8202F", chamfer=0.0)

    arm(a, 1, "#C8502F", skin, rot=(-30, 50, 0), held=sign)
    arm(a, -1, "#C8502F", skin, rot=(-10, 40, 0))
    # face in the hole: a little head peeking out of the sausage, near the top
    with a.at((0, -0.55, 0.0)):
        a.ball((0, 0, HEAD_Z + 0.1), (0.6, 0.35, 0.65), skin, seg=8, rings=6)
        for s in (-1, 1):
            a.ball((s * 0.22, -0.33, HEAD_Z + 0.18), (0.09, 0.05, 0.14), "#161220", seg=5, rings=3)
        a.box((0, -0.35, HEAD_Z - 0.2), (0.22, 0.06, 0.06), "#7A2836", chamfer=0.02)
        a.box((0, -0.35, HEAD_Z + 0.42), (0.4, 0.06, 0.08), "#5A3A22", rot=(0, 12, 0), chamfer=0.02)


def ventriloquist(a):
    """Pro (Comedy): a ventriloquist and her cheeky dummy, who gets all the laughs."""
    skin = "#5A3420"
    legs(a, "#1B2340", "#2E2C34")
    torso(a, "#2E86DE")
    a.box((0, -0.62, 2.3), (0.5, 0.06, 0.6), "#FAF6EC", chamfer=0.0, taper=0.3)
    a.box((0, -0.66, SHOULDER - 0.15), (0.45, 0.1, 0.2), "#F5B82E", chamfer=0.04, taper=0.5)  # bow tie
    arm(a, 1, "#2E86DE", skin, rot=(-35, 15, 0))
    arm(a, -1, "#2E86DE", skin, rot=(-60, 25, 0))
    head(a, skin, mouth="flat" if False else "smile", brows="#161220")
    a.box((0, -0.97, HEAD_Z - 0.38), (0.3, 0.05, 0.08), "#7A2836", chamfer=0.02)  # lips kept still
    for x, y, z, r in ((0, 0.2, 0.75, 0.7), (-0.75, 0.3, 0.35, 0.5), (0.75, 0.3, 0.35, 0.5)):
        a.gem((x, y, HEAD_Z + z), r, "#161220")
    a.gem((0, 0.6, HEAD_Z + 1.15), 0.55, "#161220")  # high bun
    a.cyl((0, 0.6, HEAD_Z + 0.75), 0.4, 0.4, 0.15, "#F5B82E", seg=8)
    # the dummy sits on her left arm, facing the crowd, mouth wide open
    with a.at((-1.25, -0.6, 1.95)):
        a.box((0, 0, 0.05), (0.85, 0.6, 0.85), "#C8202F", chamfer=0.1)
        for s in (-1, 1):
            a.cyl((s * 0.2, -0.35, -0.55), 0.1, 0.1, 0.8, "#2E2C34", rot=(-70, 0, 0), seg=5)
        a.box((0, 0, 0.95), (0.95, 0.85, 0.85), "#F7D2B5", chamfer=0.15)
        a.box((0, 0, 0.32), (0.75, 0.75, 0.3), "#F7D2B5", chamfer=0.08)  # hinged jaw, dropped
        a.box((0, -0.38, 0.55), (0.5, 0.06, 0.2), "#7A2836", chamfer=0.02)
        for s in (-1, 1):
            a.ball((s * 0.2, -0.43, 1.05), (0.12, 0.05, 0.14), "#161220", seg=5, rings=3)
            a.ball((s * 0.35, -0.43, 0.75), (0.1, 0.04, 0.06), "#F08A8A", seg=5, rings=3)
        a.box((0, 0, 1.45), (1.0, 0.9, 0.2), "#C88A3A", chamfer=0.06)  # painted hair
        a.cyl((0.1, 0, 1.75), 0.35, 0.3, 0.4, "#2E2C34", seg=8)  # tiny top hat


def heartthrob(a):
    """Star (Romance): the teen heartthrob. Huge pompadour, letterman jacket, guitar, fan hearts."""
    skin = "#E8B98A"
    legs(a, "#3A5A9A", "#FAF6EC")
    torso(a, "#C8202F")
    a.box((0, -0.62, 2.0), (0.7, 0.06, 1.4), "#FAF6EC", chamfer=0.0)
    a.box((-0.5, -0.66, 2.35), (0.42, 0.08, 0.45), "#F5B82E", chamfer=0.05)

    def guitar(a):
        with a.at((0.2, -0.35, 0.3), (0, -35, 0)):
            a.ball((0, 0, -0.3), (0.55, 0.18, 0.6), "#2E86DE", seg=8, rings=5)
            a.cyl((0, -0.18, -0.3), 0.15, 0.15, 0.04, "#161220", rot=(90, 0, 0), seg=8)
            a.box((0, 0, 0.75), (0.16, 0.1, 1.5), "#7A5434", chamfer=0.02)
            a.box((0, 0, 1.55), (0.25, 0.12, 0.3), "#161220", chamfer=0.03)

    arm(a, 1, "#FAF6EC", skin, rot=(-40, 20, 0), held=guitar)
    arm(a, -1, "#FAF6EC", skin, rot=(-50, 10, 0))
    head(a, skin, mouth="grin", brows="#161220")
    a.ball((0, 0.1, HEAD_Z + 0.55), (1.15, 1.0, 0.55), "#161220", seg=8, rings=4)
    a.ball((0.1, -0.55, HEAD_Z + 1.0), (0.85, 0.6, 0.45), "#161220", rot=(-25, 0, 0), seg=8, rings=4)  # pompadour
    a.gem((0.6, -0.95, HEAD_Z + 0.15), 0.1, "#FFFFFF", emit=4)  # wink sparkle
    for x, z in ((-1.9, 4.8), (1.9, 4.3), (-2.1, 3.2)):
        with a.at((x, 0, z)):
            for s in (-1, 1):
                a.ball((s * 0.12, 0, 0.08), (0.17, 0.08, 0.17), "#FF5FD2", seg=6, rings=4, emit=1.5)
            a.cyl((0, 0, -0.08), 0.24, 0.0, 0.26, "#FF5FD2", rot=(180, 0, 45), seg=4, emit=1.5)


def method_knight(a):
    """Star (Horror): a method actor who has not taken his knight armour off in three months.
    Plumed helmet, sword, shield with a film reel crest."""
    steel, steel2 = "#C9CED9", "#8D94A6"
    legs(a, steel2, steel)
    torso(a, steel, wide=1.12)
    a.box((0, -0.05, 2.1), (1.95, 1.4, 1.2), "#7A1F2B", chamfer=0.1, taper=0.9)  # tabard
    a.gem((0, -0.75, 2.2), 0.25, "#F5B82E")
    for s in (-1, 1):
        a.ball((s * 1.0, 0, SHOULDER + 0.05), (0.55, 0.6, 0.4), steel, seg=8, rings=4)  # pauldrons

    def sword(a):
        with a.at((0, -0.15, 0), (0, 0, 0)):
            a.box((0, 0, 1.2), (0.22, 0.08, 2.2), "#E6EAF2", chamfer=0.03)
            a.box((0, 0, 0.1), (0.75, 0.15, 0.14), "#F5B82E", chamfer=0.03)
            a.cyl((0, 0, -0.2), 0.08, 0.08, 0.5, "#7A5434", seg=5)

    def shield(a):
        with a.at((-0.15, -0.35, 0.2), (0, 0, 0)):
            a.box((0, 0, 0), (1.3, 0.15, 1.5), "#2E86DE", chamfer=0.2, taper=0.7)
            a.cyl((0, -0.1, 0.1), 0.4, 0.4, 0.06, "#F5B82E", rot=(90, 0, 0), seg=8)
            a.cyl((0, -0.14, 0.1), 0.12, 0.12, 0.06, "#2E2C34", rot=(90, 0, 0), seg=6)

    arm(a, 1, steel, steel2, rot=(-20, 15, 0), held=sword)
    arm(a, -1, steel, steel2, rot=(-50, 10, 0), held=shield)
    # helmet: a round great helm with an eye slit and a red plume
    a.ball((0, 0, HEAD_Z + 0.05), (1.15, 1.05, 1.15), steel, seg=10, rings=7)
    a.box((0, -1.0, HEAD_Z + 0.1), (1.3, 0.1, 0.16), "#2E2C34", chamfer=0.02)
    for s in (-1, 1):
        a.ball((s * 0.35, -1.04, HEAD_Z + 0.1), (0.08, 0.03, 0.05), "#FFFFFF", seg=4, rings=3, emit=2)
    a.box((0, -0.95, HEAD_Z + 0.1), (0.12, 0.25, 1.5), steel2, chamfer=0.03)
    for i in range(5):
        a.box((0, 0.1 + i * 0.25, HEAD_Z + 1.3 - i * 0.12), (0.3, 0.4, 0.5), "#E8333A", rot=(20 + i * 15, 0, 0), chamfer=0.1)


def scream_queen(a):
    """Superstar (Horror): the queen of horror films. Mid-scream, ponytail flying, flashlight,
    a gold star on her jacket."""
    skin = "#F2C9A8"
    legs(a, "#2E2C34", "#FAF6EC")
    torso(a, "#C8202F")
    a.box((0, -0.62, 2.0), (0.6, 0.06, 1.3), "#FAF6EC", chamfer=0.0)
    a.box((0.5, -0.66, 2.4), (0.35, 0.08, 0.35), "#F5B82E", rot=(0, 0, 45), chamfer=0.03)

    def flashlight(a):
        with a.at((0, -0.2, 0.1), (90, 0, 0)):
            a.cyl((0, 0, 0.2), 0.12, 0.12, 0.8, "#2E2C34", seg=6)
            a.cyl((0, 0, 0.65), 0.22, 0.15, 0.25, "#6E7078", seg=6)
            a.cyl((0, 0, 0.79), 0.2, 0.2, 0.04, "#FFF6C0", seg=6, emit=6)

    arm(a, 1, "#C8202F", skin, rot=(-85, 20, 0), held=flashlight)
    arm(a, -1, "#C8202F", skin, rot=(-150, 40, 0))  # hand up by the cheek
    head(a, skin, brows="#7A2A12", blush=False, eye_scale=(1.25, 1.25))
    a.ball((0, -0.95, HEAD_Z - 0.4), (0.22, 0.06, 0.28), "#7A2836", seg=6, rings=4)  # scream
    a.ball((0, 0.12, HEAD_Z + 0.45), (1.18, 1.02, 0.66), "#D2501E", seg=8, rings=4)  # red hair
    a.box((0, -0.85, HEAD_Z + 0.75), (1.6, 0.3, 0.35), "#D2501E", rot=(-10, 0, 0), chamfer=0.1)
    with a.at((0.2, 0.95, HEAD_Z + 0.35), (-50, 25, 0)):
        a.ball((0, 0, 0), (0.18, 0.18, 0.18), "#FFD21A", seg=6, rings=4)
        a.cyl((0, 0, -0.75), 0.35, 0.15, 1.3, "#D2501E", seg=6)


def showgirl_diva(a):
    """Legend (Romance): a golden-age diva in full showgirl glory. Feather headdress, sequin
    gown, long gloves, vintage microphone, spotlight sparkles."""
    skin = "#6B3A22"
    gown = "#B8C4E8"
    a.cyl((0, 0, 0.9), 1.25, 0.7, 1.8, gown, seg=10, squash=0.85)
    for i in range(12):  # sequins
        ang = 2 * math.pi * i / 12
        a.gem((math.cos(ang) * 1.0, math.sin(ang) * 0.85, 0.5 + (i % 3) * 0.35), 0.1, "#FFFFFF", emit=2.5)
    a.cyl((0, 0, 0.12), 1.3, 1.3, 0.12, "#F5B82E", seg=10, squash=0.85)
    torso(a, gown)
    for i in range(7):  # feather boa
        ang = math.radians(-90 + i * 30)
        a.gem((math.sin(ang) * 0.95, math.cos(ang) * 0.6, SHOULDER + 0.05), 0.3, "#FF9AC4")

    def mic(a):
        a.cyl((0, -0.1, 0.0), 0.06, 0.06, 0.4, "#2E2C34", seg=5)
        a.box((0, -0.15, 0.35), (0.35, 0.25, 0.45), "#AEB3C2", chamfer=0.1, metal=0.3)
        for k in range(3):
            a.box((0, -0.28, 0.25 + k * 0.1), (0.3, 0.02, 0.03), "#2E2C34", chamfer=0.0)

    arm(a, 1, "#FAF6EC", "#FAF6EC", rot=(-110, 10, 0), held=mic)
    arm(a, -1, "#FAF6EC", "#FAF6EC", rot=(-150, 55, 0))  # arm flung up
    head(a, skin, brows="#161220", mouth="smile")
    for x, y, z, r in ((0, 0.2, 0.55, 0.85), (-0.8, 0.25, 0.0, 0.55), (0.8, 0.25, 0.0, 0.55)):
        a.gem((x, y, HEAD_Z + z), r, "#161220")
    # headdress: a gold band with a fan of tall feathers
    a.cyl((0, 0.05, HEAD_Z + 0.75), 1.05, 1.05, 0.25, "#F5B82E", seg=10)
    a.gem((0, -0.98, HEAD_Z + 0.75), 0.2, "#FF5A2E", emit=1.5)
    for i in range(7):
        ang = -60 + i * 20
        with a.at((0, 0.3, HEAD_Z + 0.9), (0, ang, 0)):
            a.ball((0, 0, 1.0), (0.22, 0.08, 0.9), "#FF5A2E" if i % 2 else "#FFC21A", seg=6, rings=4)
    for x, z in ((-2.0, 4.8), (2.0, 5.4), (-1.8, 2.3), (2.1, 2.6)):
        a.gem((x, 0, z), 0.16, "#FFE58A", emit=5)


CAST = [
    ("NervousIntern", "Newcomer", nervous_intern),
    ("StuntDouble", "Newcomer", stunt_double),
    ("BackgroundExtra", "Newcomer", zombie_extra),
    ("SoapRegular", "Rising", soap_star),
    ("AdModel", "Rising", hotdog_mascot),
    ("IndieSidekick", "Rising", robot_sidekick),
    ("ActionVeteran", "Pro", commando),
    ("ComedyDuo", "Pro", ventriloquist),
    ("NightShiftVillain", "Pro", night_villain),
    ("TeenHeartthrob", "Star", heartthrob),
    ("MethodActor", "Star", method_knight),
    ("SpaceCaptain", "Star", alien_captain),
    ("BoxOfficeKing", "Superstar", box_office_king),
    ("ScreamQueen", "Superstar", scream_queen),
    ("RomComSweetheart", "Superstar", cupid),
    ("GoldenAgeDiva", "Legend", showgirl_diva),
    ("SilentEraClown", "Legend", silent_clown),
    ("SciFiVisionary", "Legend", brain_jar),
    ("MogulsMuse", "Icon", golden_muse),
    ("LastActionHero", "Icon", mech_hero),
    ("PhantomAuteur", "Icon", phantom_auteur),
]

# Rarity colors (ART_STYLE.md section 4) for the bases.
TIER_COLOR = {
    "Newcomer": "#A7A9AC",
    "Rising": "#4CC764",
    "Pro": "#3A8DFF",
    "Star": "#A04DFF",
    "Superstar": "#FFC21A",
    "Legend": "#FF5A2E",
    "Icon": "#FF5FD2",
}
BASE_H = 0.45  # the base's height: the actor stands on it when it is shown

# Where each piece turns (studs, Blender coordinates): the hips, the neck and the shoulders.
PIVOTS = {
    "Body": (0, 0, HIP),
    "Head": (0, 0, SHOULDER + 0.1),
    "ArmL": (0.98, 0, SHOULDER - 0.12),
    "ArmR": (-0.98, 0, SHOULDER - 0.12),
    "Base": (0, 0, 0),
}


def make(actor_id, tier, fn):
    a = Actor(actor_id)
    fn(a)
    with a.piece("Base"):
        a.cyl((0, 0, -0.35 / 2 - 0.1), 1.75, 1.6, 0.35, TIER_COLOR[tier], seg=6, rot=(0, 0, 30))
        a.cyl((0, 0, -0.4), 1.85, 1.85, 0.1, "#3A2E4A", seg=6, rot=(0, 0, 30))
    return a


# --- Luau part version ---------------------------------------------------------------------


def roblox_shape(kind, world, size):
    """(position, rotation rows, size) in Roblox space: x right, y up, the actor faces -Z."""
    pos = P @ world.translation
    rot = P @ world.to_3x3() @ P
    sx, sy, sz = size
    return pos, rot, (sx, sz, sy)


def bounds_of(obj):
    pts = [Vector(v.co) / STUD for v in obj.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    a, b = P @ lo, P @ hi
    mn = [min(x, y) for x, y in zip(a, b)]
    mx = [max(x, y) for x, y in zip(a, b)]
    return [y - x for x, y in zip(mn, mx)], [(x + y) / 2 for x, y in zip(mn, mx)]


def vec(v):
    return f"Vector3.new({', '.join(num(c) for c in v)})"


def write_luau(results):
    lines = [
        "--!strict",
        "-- GENERATED by art/blender/actors.py from the Blender actor designs. Do not edit by hand:",
        "-- change the shapes there and run it again. Each actor is split into rig pieces (Body, Head,",
        "-- ArmL, ArmR, Base), each a list of shapes in studs, feet on y = 0, facing -Z; the Base sits",
        "-- below y = 0. ActorModels builds them as parts until the Blender meshes are imported.",
        "-- kind: \"ball\" (an ellipsoid), \"box\" or \"cyl\" (its axis along the CFrame's Y; a cone when",
        "-- `top` is set: the top's width over the bottom's).",
        "",
        "export type Shape = { kind: string, cf: CFrame, size: Vector3, color: Color3, neon: boolean?, top: number? }",
        "export type Piece = { shapes: { Shape }, pivot: Vector3, size: Vector3, center: Vector3 }",
        "export type Rig = { pieces: { [string]: Piece }, wave: string?, float: boolean? }",
        "",
        "local function S(kind: string, cf: CFrame, size: Vector3, hex: string, neon: boolean?, top: number?): Shape",
        "\treturn { kind = kind, cf = cf, size = size, color = Color3.fromHex(hex), neon = neon, top = top }",
        "end",
        "",
        "local ActorShapes = {}",
        "",
        f"ActorShapes.BaseHeight = {num(BASE_H)}",
        "",
        "-- The pieces in build order.",
        "ActorShapes.Pieces = { " + ", ".join(f'"{p}"' for p in PIECES) + " }",
        "",
        "ActorShapes.Actors = {} :: { [string]: Rig }",
        "",
    ]
    for actor, objs in results:
        lines.append(f"ActorShapes.Actors.{actor.name} = {{")
        if actor.wave:
            lines.append(f"\twave = \"{actor.wave}\",")
        if actor.float:
            lines.append("\tfloat = true,")
        lines.append("\tpieces = {")
        for piece in PIECES:
            if piece not in objs:
                continue
            size, center = bounds_of(objs[piece])
            lines.append(f"\t\t{piece} = {{")
            lines.append(f"\t\t\tpivot = {vec(P @ Vector(PIVOTS[piece]))},")
            lines.append(f"\t\t\tsize = {vec(size)},")
            lines.append(f"\t\t\tcenter = {vec(center)},")
            lines.append("\t\t\tshapes = {")
            for owner, kind, world, shape_size, color, emit, top in actor.shapes:
                if owner != piece:
                    continue
                pos, r, sz = roblox_shape(kind, world, shape_size)
                cf = ", ".join(num(v) for v in (*pos, r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]))
                extra = ""
                if top is not None:
                    r1, r2 = top
                    # Size holds the wider end; flip a cone that narrows downwards.
                    extra = f", {'true' if emit >= 1 else 'nil'}, {num(min(r1, r2) / max(r1, r2))}"
                    if r1 < r2:
                        cf += ""  # handled below by turning the shape over
                elif emit >= 1:
                    extra = ", true"
                if top is not None and top[0] < top[1]:
                    cf_expr = f"CFrame.new({cf}) * CFrame.Angles(math.pi, 0, 0)"
                else:
                    cf_expr = f"CFrame.new({cf})"
                lines.append(f"\t\t\t\tS(\"{kind}\", {cf_expr}, {vec(sz)}, \"{color.lstrip('#')}\"{extra}),")
            lines.append("\t\t\t},")
            lines.append("\t\t},")
        lines.append("\t},")
        lines.append("}")
        lines.append("")
    lines.append("return ActorShapes")
    with open(LUAU_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("Wrote", LUAU_OUT)


# --- Export and preview ----------------------------------------------------------------------


def export_all(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(mmkit.EXPORTS, "actors.fbx"),
        use_selection=True,
        global_scale=1 / (STUD * 100),
        apply_unit_scale=True,
        bake_space_transform=True,
        colors_type="SRGB",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
    )
    print("Exported", os.path.join(mmkit.EXPORTS, "actors.fbx"))


SPACING = 5.6


def scene_setup(count):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = lin("#FFF1C9")
    bg.inputs["Strength"].default_value = 0.55
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.6
    sun.data.angle = math.radians(8)
    sun.data.color = (1.0, 0.95, 0.86)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-28))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 350
    fill.data.size = 12
    fill.location = (0, -18 * STUD * 3, 6)
    fill.rotation_euler = (math.radians(75), 0, 0)
    scene.collection.objects.link(fill)
    fm = bpy.data.meshes.new("Floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60)
    bm.to_mesh(fm)
    bm.free()
    mat = bpy.data.materials.new("Floor")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin("#FFE7A8")
    fm.materials.append(mat)
    floor = bpy.data.objects.new("Floor", fm)
    scene.collection.objects.link(floor)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = count * SPACING * STUD * 1.02
    cam.location = (0, -40, 3.1 * STUD + 40 * math.tan(math.radians(14)))
    cam.rotation_euler = (math.radians(76), 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = 3000
    scene.render.resolution_y = 560
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.render.image_settings.file_format = "PNG"


def render_sheet(path):
    """The whole cast, three rows of seven, standing on their bases."""
    from PIL import Image

    rows = []
    for r in range(3):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        row = CAST[r * 7 : r * 7 + 7]
        scene_setup(len(row))
        for i, (actor_id, tier, fn) in enumerate(row):
            x = (i - (len(row) - 1) / 2) * SPACING
            make(actor_id, tier, fn).objects((x, 0, BASE_H))
        part = path.replace(".png", f"_row{r}.png")
        bpy.context.scene.render.filepath = part
        bpy.ops.render.render(write_still=True)
        rows.append(Image.open(part).convert("RGB"))
        os.remove(part)
    sheet = Image.new("RGB", (rows[0].width, sum(i.height for i in rows)))
    y = 0
    for img in rows:
        sheet.paste(img, (0, y))
        y += img.height
    sheet.save(path)
    print("Wrote", path)


def main():
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    results, every = [], []
    for i, (actor_id, tier, fn) in enumerate(CAST):
        a = make(actor_id, tier, fn)
        objs = a.objects()
        tris = sum(len(p.vertices) - 2 for o in objs.values() for p in o.data.polygons)
        print(f"{actor_id}: {tris} tris, pieces {', '.join(objs)}, waves {a.wave}")
        assert tris <= MAX_TRIS, f"{actor_id} is over its triangle budget"
        for o in objs.values():
            mmkit.bake_vertex_colors(o.data)
            every.append(o)
        results.append((a, objs))
    write_luau(results)
    export_all(every)
    if not os.environ.get("ACTOR_NO_RENDER"):
        render_sheet(os.path.join(mmkit.PREVIEWS, "actors_blender.png"))


if __name__ == "__main__":
    main()
