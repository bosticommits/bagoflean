"""Actors v2: the polished figurine kit and the first three approval drafts
(Nervous Intern, Werewolf Pup, Captain Squawk). Design: docs/design/actors-v2.md, taste rules:
vault `Movie Mogul/Actor References.md`.

Everything shared lives at the top of this file so the other 27 actors reuse it:
  Fig            one actor: a bmesh per rig piece (Body, Head, ArmL, ArmR, Base), vertex colours painted
                 per face while building, shapes in studs (rbox, rcyl, ball, disc, torus, spike, leaf)
  kid / hero bodies, face helpers (eyes, brows, blush, mouths), plinth() for every tier
  finish()       -> Blender objects: one colour attribute "Col", AO bake (Cycles, vertex colours) +
                 warm top rim, smooth-by-angle, tidy
  qa()           numbers: tris, n-gons, loose/floating islands, flipped shells, bounds, scale
  render helpers front / 3-4 / back / silhouette / 64 px / game distance / compare sheets

Run live (MCP for Blender, the add-on's execute_blender_code):
  import importlib.util as u; s = u.spec_from_file_location("actors_v2", PATH); m = u.module_from_spec(s)
  s.loader.exec_module(m); m.main()          # builds scene "ActorsV2", renders to OUT_DIR

Coordinates are studs (1 stud = 0.28 m): Z up, the actor faces -Y, feet on Z = 0, the actor's own left is
+X. Shapes are built in studs and scaled to metres when the objects are made. Blender 5.x API: no
use_auto_smooth (shade_smooth_by_angle instead), no face maps.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

STUD = 0.28
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.expanduser("~/Desktop/bagoflean/art/drafts")
PREVIEW_DIR = os.path.join(REPO, "art", "previews")
SCENE_NAME = "ActorsV2"
PIECES = ("Body", "Head", "ArmL", "ArmR", "Base")
SMOOTH_ANGLE = 50  # degrees: 2-segment bevel faces (45 deg apart) blend, real corners stay hard


# --- colour helpers ---------------------------------------------------------------------------


def lin(hex_color, a=1.0):
    h = hex_color.lstrip("#")
    srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb) + (a,)


def shade(hex_color, k):
    """Multiply an sRGB hex by k (k<1 darker, >1 lighter, clamped)."""
    h = hex_color.lstrip("#")
    c = [min(255, max(0, round(int(h[i : i + 2], 16) * k))) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(c)


def mix(a, b, t):
    ha, hb = a.lstrip("#"), b.lstrip("#")
    c = [round(int(ha[i : i + 2], 16) * (1 - t) + int(hb[i : i + 2], 16) * t) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(c)


def M(at=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    return (
        Matrix.Translation(Vector(at))
        @ Euler([math.radians(r) for r in rot], "XYZ").to_matrix().to_4x4()
        @ Matrix.Diagonal(Vector((*scale, 1)))
    )


# --- the figure -------------------------------------------------------------------------------


class Fig:
    """One actor. Shapes take studs; inside `with f.at(...)` they are relative to it, inside
    `with f.piece(...)` they belong to that rig piece. Colour is a hex string, or a function of the
    face (bmesh face, local coords) returning a hex string."""

    def __init__(self, name, tier="Newcomer"):
        self.name, self.tier = name, tier
        self.bms = {p: bmesh.new() for p in PIECES}
        self.lay = {p: self.bms[p].loops.layers.float_color.new("Cf") for p in PIECES}
        self.stack = [Matrix.Identity(4)]
        self.pieces = [None]
        self.log = []  # (piece, shape kind, triangles) for the budget table
        self.float = False  # hovers (no feet on the ground)
        self.wave = None
        self.objs = {}
        self.shoulders = {}  # {"ArmL"/"ArmR": (x, z)}: where each arm() really hangs from (actor space, studs)
        self.neck_z = None  # where the head sits on the body (first head_box base + 0.25)

    class _Push:
        def __init__(self, stack, item):
            self.stack, self.item = stack, item

        def __enter__(self):
            self.stack.append(self.item)

        def __exit__(self, *exc):
            self.stack.pop()

    def at(self, at=(0, 0, 0), rot=(0, 0, 0)):
        return Fig._Push(self.stack, self.stack[-1] @ M(at, rot))

    def at_matrix(self, m):
        return Fig._Push(self.stack, self.stack[-1] @ m)

    def piece(self, name):
        return Fig._Push(self.pieces, name)

    # -- shape plumbing

    def _place(self, bm, at, rot, color, scale=(1, 1, 1)):
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        # colours are chosen on the local shape (before it is moved), so colour functions see local coords
        hexes = {face: (color(face) if callable(color) else color) for face in bm.faces}
        bmesh.ops.transform(bm, matrix=self.stack[-1] @ M(at, rot, scale), verts=bm.verts)
        piece = self.pieces[-1] or "Body"
        target, lay = self.bms[piece], self.lay[piece]
        self.log.append((piece, sys._getframe(1).f_code.co_name, sum(max(1, len(fc.verts) - 2) for fc in bm.faces)))
        vmap = {v: target.verts.new(v.co) for v in bm.verts}
        for face in bm.faces:
            c = lin(hexes[face])
            try:
                nf = target.faces.new([vmap[v] for v in face.verts])
            except ValueError:
                continue
            for loop in nf.loops:
                loop[lay] = c
        bm.free()

    @staticmethod
    def _bevel(bm, offset, segs, min_angle):
        if offset <= 0:
            return
        edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(min_angle)]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=offset, segments=segs, affect="EDGES", profile=0.5, clamp_overlap=True, loop_slide=True)

    # -- shapes

    def rbox(self, at, size, color, rot=(0, 0, 0), bevel=0.1, segs=1, taper=1.0, cuts=0, min_angle=40):
        """Rounded box, centred. taper scales the top relative to the bottom (linear)."""
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        if cuts:
            bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
        for v in bm.verts:
            k = 1 + (taper - 1) * (v.co.z + 0.5)
            v.co.x *= size[0] * k
            v.co.y *= size[1] * k
            v.co.z *= size[2]
        self._bevel(bm, min(bevel, min(size) * 0.45), segs, min_angle)
        self._place(bm, at, rot, color)

    def rcyl(self, at, r1, r2, length, color, rot=(0, 0, 0), seg=8, bevel=0.05, segs=1, squash=1.0, min_angle=60):
        """Tapered cylinder along Z, centred (r1 bottom, r2 top), bevelled cap rims."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=length)
        for v in bm.verts:
            v.co.y *= squash
        if min(r1, r2) > 0:
            self._bevel(bm, min(bevel, min(r1, r2) * 0.5, length * 0.45), segs, min_angle)
        self._place(bm, at, rot, color)

    def lathe(self, at, profile, colors, rot=(0, 0, 0), seg=6, scale=(1, 1, 1)):
        """Revolve a profile [(radius, z), ...] about Z; colors has one hex per band (len(profile)-1), the
        bottom cap takes the first and the top cap the last. Cheap cups, jars, hats, bulbs."""
        bm = bmesh.new()
        rings = [[bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)] for r, z in profile]
        for k in range(len(rings) - 1):
            for i in range(seg):
                fc = bm.faces.new((rings[k][i], rings[k][(i + 1) % seg], rings[k + 1][(i + 1) % seg], rings[k + 1][i]))
                fc.material_index = k
        if profile[0][0] > 0:
            bm.faces.new(rings[0][::-1]).material_index = 0
        if profile[-1][0] > 0:
            bm.faces.new(rings[-1]).material_index = (len(colors) - 1) if not callable(colors) else 0
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._place(bm, at, rot, colors if callable(colors) else (lambda face: colors[face.material_index]), scale)

    def ball(self, at, radii, color, rot=(0, 0, 0), seg=8, rings=5):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
        bmesh.ops.scale(bm, vec=radii, verts=bm.verts)
        self._place(bm, at, rot, color)

    def disc(self, at, w, h, thick, color, seg=10, bevel=0.0, rot=(0, 0, 0)):
        """An oval plate: w x h across (local X, Y), `thick` deep along local Z, centred on `at`. Face
        features wrap it in `with f.at(pos, (90, 0, 0))` so local +Z points out of the face (-Y)."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=1.0, radius2=1.0, depth=1.0)
        for v in bm.verts:
            v.co.x *= w / 2
            v.co.y *= h / 2
            v.co.z *= thick
        if bevel > 0:
            self._bevel(bm, min(bevel, thick * 0.45), 1, 50)
        self._place(bm, at, rot, color)

    def spike(self, at, r, h, color, rot=(0, 0, 0), seg=4, squash=1.0, r2=0.0):
        """A cone/pyramid from the base (at) up +Z to the tip."""
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r2, depth=h)
        for v in bm.verts:
            v.co.y *= squash
            v.co.z += h / 2
        self._place(bm, at, rot, color)

    def torus(self, at, R, r, color, rot=(0, 0, 0), major=10, minor=4, sx=1.0, sz=1.0):
        """A ring lying in the XZ plane (faces -Y), centre line radius R, tube radius r."""
        bm = bmesh.new()
        verts = []
        for i in range(major):
            a = 2 * math.pi * i / major
            row = []
            for j in range(minor):
                b = 2 * math.pi * j / minor + math.pi / minor
                rr = R + r * math.cos(b)
                row.append(bm.verts.new((rr * math.cos(a) * sx, r * math.sin(b), rr * math.sin(a) * sz)))
            verts.append(row)
        for i in range(major):
            for j in range(minor):
                bm.faces.new((verts[i][j], verts[(i + 1) % major][j], verts[(i + 1) % major][(j + 1) % minor], verts[i][(j + 1) % minor]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        self._place(bm, at, rot, color)

    def leaf(self, at, rot, length, width, thick, color, tip=0.3, widest=0.45, tip_color=None, tip_from=0.7):
        """A feather/blade: base at `at`, runs along +Z, widest part near `widest`, blunt tip."""
        bm = bmesh.new()
        prof = [(0.0, 0.62, 0.8), (widest, 1.0, 1.0), (1.0, tip, 0.45)]
        rings = []
        for t, wk, tk in prof:
            hw, ht = width * wk / 2, thick * tk / 2
            rings.append([bm.verts.new(p) for p in ((-hw, -ht, t * length), (hw, -ht, t * length), (hw, ht, t * length), (-hw, ht, t * length))])
        for a, b in zip(rings, rings[1:]):
            for i in range(4):
                bm.faces.new((a[i], a[(i + 1) % 4], b[(i + 1) % 4], b[i]))
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if tip_color:
            col = lambda face: tip_color if face.calc_center_median().z > tip_from * length else color  # noqa: E731
        else:
            col = color
        self._place(bm, at, rot, col)

    # -- objects

    def finish_objects(self, offset=(0, 0, 0)):
        """Make one Blender mesh per non-empty piece (scaled to metres, colours in the Col attribute)."""
        mat = game_material()
        for piece in PIECES:
            bm = self.bms[piece]
            if not bm.faces:
                bm.free()
                continue
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
            big = [f for f in bm.faces if len(f.verts) > 4]
            if big:
                bmesh.ops.triangulate(bm, faces=big)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bmesh.ops.scale(bm, vec=(STUD, STUD, STUD), verts=bm.verts)
            mesh = bpy.data.meshes.new(f"{self.name}_{piece}")
            bm.to_mesh(mesh)
            bm.free()
            cf = mesh.color_attributes["Cf"]
            n = len(mesh.loops)
            buf = np.empty(n * 4, dtype=np.float32)
            cf.data.foreach_get("color", buf)
            col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
            col.data.foreach_set("color", buf)
            mesh.color_attributes.remove(cf)
            mesh.materials.append(mat)
            obj = bpy.data.objects.new(f"{self.name}_{piece}", mesh)
            obj.location = Vector(offset) * STUD
            bpy.context.scene.collection.objects.link(obj)
            self.objs[piece] = obj
        self.bms = {}
        return self.objs


def game_material():
    m = bpy.data.materials.get("A2_Vertex")
    if m:
        return m
    m = bpy.data.materials.new("A2_Vertex")
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    for name in ("Specular IOR Level",):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = 0.25
    return m


# --- finishing: AO, rim, smooth ---------------------------------------------------------------


def _col_array(mesh):
    a = np.empty(len(mesh.loops) * 4, dtype=np.float32)
    mesh.color_attributes["Col"].data.foreach_get("color", a)
    return a.reshape(-1, 4)


def _set_col(mesh, arr):
    mesh.color_attributes["Col"].data.foreach_set("color", arr.astype(np.float32).ravel())


def bake_ao(objs, samples=48, distance=0.4, strength=0.62, rim=0.14, floor=None):
    """Cycles AO into vertex colours (all pieces in the scene occlude each other), then
    Col = base * lerp(1, ao, strength) with a warm tint on up-facing normals. Returns True if baked."""
    sc = bpy.context.scene
    prev_engine = sc.render.engine
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.render.bake.target = "VERTEX_COLORS"
    if sc.world is None:
        sc.world = bpy.data.worlds.new("A2_World")
    sc.world.light_settings.distance = distance * 1.0
    ok = True
    for o in objs:
        me = o.data
        ao = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
        me.color_attributes.active_color = ao
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        try:
            bpy.ops.object.bake(type="AO")
        except Exception as e:  # noqa: BLE001
            print("AO bake failed:", e)
            ok = False
            me.color_attributes.remove(ao)
            break
        buf = np.empty(len(me.loops) * 4, dtype=np.float32)
        ao.data.foreach_get("color", buf)
        av = buf.reshape(-1, 4)[:, 0]
        me.color_attributes.active_color = me.color_attributes["Col"]
        col = _col_array(me)
        k = 1.0 - strength * (1.0 - np.clip(av, 0, 1))
        col[:, :3] *= k[:, None]
        # warm top rim: up-facing normals get a little lighter and warmer
        nrm = np.empty(len(me.loops) * 3, dtype=np.float32)
        me.corner_normals.foreach_get("vector", nrm)
        up = np.clip(nrm.reshape(-1, 3)[:, 2], 0, 1) ** 1.5
        col[:, 0] *= 1 + rim * 1.0 * up
        col[:, 1] *= 1 + rim * 0.75 * up
        col[:, 2] *= 1 + rim * 0.35 * up
        _set_col(me, np.clip(col, 0, 1))
        me.color_attributes.remove(ao)
    sc.render.engine = prev_engine
    return ok


def smooth(objs, angle=SMOOTH_ANGLE):
    for o in objs:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))


# --- QA ---------------------------------------------------------------------------------------


def qa(fig_name, objs, intended_floating=()):
    """Numbers + manual checklist from blender-asset-qa: tris, n-gons, islands, floating islands,
    flipped shells, duplicate verts, scale, bounds. Returns dict."""
    report = {"tris": 0, "ngons": 0, "issues": []}
    all_islands = []
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for piece, o in objs.items():
        me = o.data
        report["tris"] += sum(len(p.vertices) - 2 for p in me.polygons)
        report["ngons"] += sum(1 for p in me.polygons if len(p.vertices) > 4)
        if tuple(o.scale) != (1, 1, 1) or any(abs(r) > 1e-6 for r in o.rotation_euler):
            report["issues"].append(f"{piece}: unapplied transform")
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        seen = set()
        for v in bm.verts:
            if v in seen:
                continue
            stack, isl = [v], []
            seen.add(v)
            while stack:
                x = stack.pop()
                isl.append(x)
                for e in x.link_edges:
                    y = e.other_vert(x)
                    if y not in seen:
                        seen.add(y)
                        stack.append(y)
            co = [x.co for x in isl]
            mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
            mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
            fs = {f for x in isl for f in x.link_faces}
            vol = 0.0
            for f in fs:
                vs = [l.vert.co for l in f.loops]
                for i in range(1, len(vs) - 1):
                    vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
            all_islands.append((piece, mn, mx, vol, len(fs)))
        bm.free()
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(lo.x, *(b.x for b in bb)), min(lo.y, *(b.y for b in bb)), min(lo.z, *(b.z for b in bb))))
        hi = Vector((max(hi.x, *(b.x for b in bb)), max(hi.y, *(b.y for b in bb)), max(hi.z, *(b.z for b in bb))))
    report["islands"] = len(all_islands)
    report["flipped"] = sum(1 for i in all_islands if i[3] < 0)
    tol = 0.02 * STUD * 5
    floating = []
    for i, (p, mn, mx, vol, nf) in enumerate(all_islands):
        touching = False
        for j, (p2, mn2, mx2, vol2, nf2) in enumerate(all_islands):
            if i == j:
                continue
            if all(mn[k] - tol <= mx2[k] and mx[k] + tol >= mn2[k] for k in range(3)):
                touching = True
                break
        if not touching:
            floating.append((p, tuple(round(c / STUD, 2) for c in mn), nf))
    report["floating"] = floating
    report["size_studs"] = tuple(round((hi[k] - lo[k]) / STUD, 2) for k in range(3))
    report["min_z"] = round(lo.z / STUD, 2)
    report["max_z"] = round(hi.z / STUD, 2)
    report["x_range"] = (round(lo.x / STUD, 2), round(hi.x / STUD, 2))
    report["y_range"] = (round(lo.y / STUD, 2), round(hi.y / STUD, 2))
    if report["flipped"]:
        report["issues"].append(f"{report['flipped']} shells with inward normals")
    return report


# --- shared body kit --------------------------------------------------------------------------

HEAD_W, HEAD_D, HEAD_H, HEAD_Z0 = 2.5, 2.2, 2.5, 2.35
FACE_Y = -HEAD_D / 2  # front of the head
EYE_Z = HEAD_Z0 + 0.45 * HEAD_H  # eyes set low
SHOULDER_Z = 2.4
EYE_DARK = "#161220"


HEAD = {"w": HEAD_W, "d": HEAD_D, "h": HEAD_H, "z0": HEAD_Z0, "r": 0.95}


def head_box(f, skin, r=0.95, cuts=0, w=HEAD_W, d=HEAD_D, h=HEAD_H, z0=HEAD_Z0, segs=3):
    """Soft rounded-cube head (round 2: user wants no sharp box): a rounded box whose corner radius r is
    ~29% of the head width, 3 segments, so it reads as a pill/pillow but keeps a flat-ish face centre. The
    shape is analytic, so face features can sit exactly on its surface (see head_surf / head_at)."""
    HEAD.update(w=w, d=d, h=h, z0=z0, r=r)
    if f.neck_z is None:
        f.neck_z = float((f.stack[-1] @ Vector((0, 0, z0))).z) + 0.25
    with f.piece("Head"):
        f.rbox((0, 0, z0 + h / 2), (w, d, h), skin, bevel=r, segs=segs, cuts=cuts, min_angle=30)


def head_surf(x, z):
    """Front surface of the rounded-box head at (x, z): returns (y, pitch_deg, yaw_deg) so a feature can sit
    on it, turned to follow the curve (local -Y = outward normal)."""
    hd = HEAD
    r = hd["r"]
    zc = hd["z0"] + hd["h"] / 2
    ix, iz = hd["w"] / 2 - r, hd["h"] / 2 - r
    dx = max(abs(x) - ix, 0.0) * (1 if x >= 0 else -1)
    dz = max(abs(z - zc) - iz, 0.0) * (1 if z >= zc else -1)
    t = max(r * r - dx * dx - dz * dz, 1e-4)
    ny = -math.sqrt(t)
    y = -(hd["d"] / 2 - r) + ny
    n = Vector((dx, ny, dz)) / r
    pitch = math.degrees(math.asin(max(-1, min(1, -n.z))))
    yaw = math.degrees(math.asin(max(-1, min(1, n.x / max(math.cos(math.radians(pitch)), 1e-3)))))
    return y, pitch, yaw


def head_normal(x, z):
    hd = HEAD
    r = hd["r"]
    zc = hd["z0"] + hd["h"] / 2
    ix, iz = hd["w"] / 2 - r, hd["h"] / 2 - r
    dx = max(abs(x) - ix, 0.0) * (1 if x >= 0 else -1)
    dz = max(abs(z - zc) - iz, 0.0) * (1 if z >= zc else -1)
    t = max(r * r - dx * dx - dz * dz, 1e-4)
    return Vector((dx, -math.sqrt(t), dz)) / r


def head_patch(f, cx, cz, rx, rz, out, color, seg=12, rings=2):
    """A solid cap that follows the head surface (a face plate / muzzle): an oval of radii rx, rz centred on
    (cx, cz), standing `out` studs proud of the head, with a wall that sinks into it."""
    bm = bmesh.new()
    prof = [k / rings for k in range(rings + 1)]
    top = [[None] * seg for _ in prof]
    bot = [None] * seg
    for j in range(seg):
        a = 2 * math.pi * j / seg
        for i, k in enumerate(prof):
            x, z = cx + rx * k * math.cos(a), cz + rz * k * math.sin(a)
            y, _, _ = head_surf(x, z)
            n = head_normal(x, z)
            bulge = out * (1.0 - 0.35 * k * k)  # a soft dome: the edge sits a little lower than the middle
            top[i][j] = bm.verts.new(Vector((x, y, z)) + n * bulge) if i or j == 0 else top[0][0]
        x, z = cx + rx * math.cos(a), cz + rz * math.sin(a)
        y, _, _ = head_surf(x, z)
        bot[j] = bm.verts.new(Vector((x, y, z)) - head_normal(x, z) * 0.06)
    for j in range(seg):
        j2 = (j + 1) % seg
        bm.faces.new((top[0][0], top[1][j2], top[1][j]))
        for i in range(1, rings):
            bm.faces.new((top[i][j], top[i][j2], top[i + 1][j2], top[i + 1][j]))
        bm.faces.new((top[rings][j], top[rings][j2], bot[j2], bot[j]))
    bm.faces.new(bot[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f._place(bm, (0, 0, 0), (0, 0, 0), color)


def head_ring(f, cx, cz, rx, rz, tube, out, color, major=14, minor=4, flat=1.0):
    """A fur ring / trim lying on the head surface (torus whose centre line follows the curve)."""
    bm = bmesh.new()
    rows = []
    for i in range(major):
        a = 2 * math.pi * i / major
        x, z = cx + rx * math.cos(a), cz + rz * math.sin(a)
        y, _, _ = head_surf(x, z)
        n = head_normal(x, z)
        c = Vector((x, y, z)) + n * out
        u = Vector((math.cos(a), 0, math.sin(a)))
        u = (u - n * u.dot(n)).normalized()
        row = []
        for j in range(minor):
            b = 2 * math.pi * j / minor + math.pi / minor
            row.append(bm.verts.new(c + (n * math.cos(b) * tube * flat + u * math.sin(b) * tube)))
        rows.append(row)
    for i in range(major):
        for j in range(minor):
            bm.faces.new((rows[i][j], rows[(i + 1) % major][j], rows[(i + 1) % major][(j + 1) % minor], rows[i][(j + 1) % minor]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f._place(bm, (0, 0, 0), (0, 0, 0), color)


def head_at(f, x, z, out=0.0):
    """Context: origin on the head surface at (x, z) (pushed `out` studs outward), axes turned to follow
    the surface. Inside it local -Y is outward, +Z up, +X the actor's left."""
    y, pitch, yaw = head_surf(x, z)
    return f.at((x, y - out, z), (pitch, 0, yaw))


def face_eyes(f, skin, spread=0.6, k=1.0, kx=None, color=EYE_DARK, glow=None, out=0.0, z=EYE_Z, socket=True):
    """Tall-oval eyes (20% of head width each) in a darker socket, one white specular dot each.
    Faces -Y, so every disc is turned 90 deg about X."""
    kx = kx or k
    for s in (-1, 1):
        with f.piece("Head"), head_at(f, s * spread, z, out), f.at((0, 0, 0), (90, 0, 0)):
            if socket:
                f.disc((0, 0.0, 0.0), 0.7 * kx, 0.86 * k, 0.05, shade(skin, 0.86), seg=8)
            f.disc((0, 0.0, 0.035), 0.5 * kx, 0.64 * k, 0.05, color, seg=10)
            f.disc((-0.1 * kx, 0.14 * k, 0.07), 0.17 * kx, 0.19 * k, 0.04, "#FFFFFF", seg=5)
            if glow:
                f.disc((0.0, 0.0, 0.05), 0.3 * kx, 0.4 * k, 0.03, glow, seg=10)


def face_brows(f, color, length=0.95, thick=0.2, angle=14, x=0.62, z=EYE_Z + 0.68, worried=True, out=0.0, lift=(0, 0)):
    """Thick angled brows. Worried: inner ends up."""
    for s in (-1, 1):
        a = s * angle if worried else -s * angle
        with f.piece("Head"), head_at(f, s * x, z + (lift[0] if s < 0 else lift[1]), out):
            f.rbox((0, -0.02, 0), (length, 0.11, thick), color, rot=(0, a, 0), bevel=0.0)


def face_blush(f, color="#F29A9A", x=0.88, z=EYE_Z - 0.38, w=0.4, h=0.26, out=0.0, seg=8):
    for s in (-1, 1):
        with f.piece("Head"), head_at(f, s * x, z, out), f.at((0, 0, 0), (90, 0, 0)):
            f.disc((0, 0, 0.0), w, h, 0.05, color, seg=seg)


def legs_kid(f, pants, shoes, sole, spread=0.5, hip=1.45, long=0.0, r=0.36):
    """Short chunky legs, wide boots. `long` stretches legs (Lanky template)."""
    top = hip + long
    for s in (-1, 1):
        with f.piece("Body"):
            f.rcyl((s * spread, 0, 0.45 + (top - 0.45) / 2), r, r + 0.06, top - 0.45, pants, seg=8, bevel=0.0)
            f.rbox((s * spread, -0.15, 0.29), (0.92, 1.32, 0.58), shoes, bevel=0.14, segs=1)
            f.rbox((s * spread, -0.15, 0.07), (0.97, 1.37, 0.14), sole, bevel=0.0)


def torso(f, color, w=1.75, d=1.35, h=1.5, z=1.95, taper=0.9, bevel=0.14):
    with f.piece("Body"):
        f.rbox((0, 0, z), (w, d, h), color, bevel=bevel, segs=2, taper=taper)


def arm(f, side, sleeve, skin, rot=(0, 0, 0), held=None, x=1.1, length=0.95, mitt=None, sleeve_r=0.3, shoulder_z=SHOULDER_Z, upright=False):
    """An arm from the shoulder. rot swings it (X forward/back, Y out, Z twist). `held` draws a prop in the
    hand's frame (z=0 at the hand centre). mitt = hand colour override."""
    name = "ArmL" if side > 0 else "ArmR"
    if name not in f.shoulders:  # the real shoulder (current frame included, e.g. a hovering actor)
        sh = f.stack[-1] @ Vector((side * x, 0, shoulder_z))
        f.shoulders[name] = (float(sh.x), float(sh.z))
    with f.piece(name), f.at((side * x, 0, shoulder_z), (rot[0], -side * rot[1], rot[2])):
        f.rcyl((0, 0, -length / 2 + 0.1), sleeve_r, sleeve_r * 0.92, length + 0.2, sleeve, seg=7, bevel=0.0)
        f.ball((0, 0, -length - 0.1), (0.32, 0.3, 0.32), mitt or skin, seg=7, rings=4)
        if held:
            with f.at((0, 0, -length - 0.1)):
                if upright:  # undo the arm's swing so the prop stands straight in the world
                    arm_rot = M((0, 0, 0), (rot[0], -side * rot[1], rot[2]))
                    with f.at_matrix(arm_rot.inverted()):
                        held(f)
                else:
                    held(f)


# --- plinth -----------------------------------------------------------------------------------

TIER = {
    "Newcomer": {"top": "#A7A9AC", "glow": "#A7A9AC"},
    "Rising": {"top": "#4CC764", "glow": "#4CC764"},
    "Pro": {"top": "#3A8DFF", "glow": "#3A8DFF"},
    "Star": {"top": "#A04DFF", "glow": "#A04DFF"},
    "Superstar": {"top": "#FFC21A", "glow": "#FFC21A"},
    "Legend": {"top": "#FF5A2E", "glow": "#FF5A2E"},
    "Icon": {"top": "#FF5FD2", "glow": "#FF5FD2"},
}
PLINTH_BOTTOM = -0.68
PLINTH_TOP = 0.07


def _hex_prism(r, z0, z1, flat=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=r, radius2=r, depth=z1 - z0)
    c, sn = math.cos(math.radians(30)), math.sin(math.radians(30))
    for v in bm.verts:  # flat side to the front (-Y)
        v.co.x, v.co.y = v.co.x * c - v.co.y * sn, v.co.x * sn + v.co.y * c
        v.co.z += (z0 + z1) / 2
    return bm


def plinth(f, tier, name_plate=True):
    """Two-step chamfered hex plinth (12-15% of figure height), inset rim, nameplate notch on the front,
    tier colour + tier details (Superstar: gold bulb ring; Legend: third step; Star: star inlay;
    Pro: rim stripe; Rising: chamfered green; Newcomer: plain)."""
    top = TIER[tier]["top"]
    side = shade(top, 0.74)
    lite = shade(top, 1.14)
    deep = shade(top, 0.6)
    z_low0, z_low1 = PLINTH_BOTTOM, -0.30
    z_up1 = PLINTH_TOP
    with f.piece("Base"):
        # lower step
        bm = _hex_prism(2.05, z_low0, z_low1)
        f._bevel(bm, 0.13, 1, 50)

        def c_low(face, z1=z_low1):
            n = face.normal
            if n.z > 0.9:
                return top
            if n.z > 0.3:
                return lite
            return side if n.z > -0.5 else deep

        f._place(bm, (0, 0, 0), (0, 0, 0), c_low)
        # upper step with an inset top (rim)
        bm = _hex_prism(1.72, z_low1 - 0.02, z_up1)
        f._bevel(bm, 0.11, 1, 50)
        topf = max((fc for fc in bm.faces if fc.normal.z > 0.9), key=lambda fc: fc.calc_center_median().z)
        res = bmesh.ops.inset_region(bm, faces=[topf], thickness=0.2, depth=-0.06, use_even_offset=True)
        floor_z = PLINTH_TOP - 0.06

        def c_up(face):
            n = face.normal
            cz = face.calc_center_median().z
            if n.z > 0.9:
                return shade(top, 1.06) if cz < z_up1 - 0.02 else top
            if n.z > 0.3:
                return lite
            if n.z > -0.5:
                return shade(top, 0.82)
            return deep

        f._place(bm, (0, 0, 0), (0, 0, 0), c_up)
        # nameplate: a dark plate set into the front of the lower step
        if name_plate:
            fy = -(0.866 * 2.05)
            f.rbox((0, fy + 0.02, (z_low0 + z_low1) / 2), (1.2, 0.1, 0.22), "#2A2733", bevel=0.04, segs=1)
        # tier details
        if tier == "Pro":
            bm = _hex_prism(2.06, z_low0 + 0.12, z_low0 + 0.2)
            f._place(bm, (0, 0, 0), (0, 0, 0), "#FFFFFF")
        if tier == "Star":
            _star_inlay(f, 0.0, -(0.866 * 2.05) - 0.01, -0.12, 0.34, "#FFE58A", top)
        if tier == "Superstar":
            for i in range(12):  # bulbs on the lower step's top, round its hex outline (corners + edge middles)
                a = math.radians(30 * i)
                r = 1.9 if i % 2 == 0 else 1.64 / math.cos(math.radians(0))
                f.ball((r * math.cos(a), r * math.sin(a), z_low1 + 0.09), (0.14, 0.14, 0.14), "#FFF6C8", seg=5, rings=2)
        if tier in ("Legend", "Icon"):
            bm = _hex_prism(1.3, z_up1 - 0.03, z_up1 + 0.2)
            f._bevel(bm, 0.08, 1, 50)
            f._place(bm, (0, 0, 0), (0, 0, 0), lambda face: lite if face.normal.z > 0.5 else side)


def _star_inlay(f, x, y, z, r, color, base):
    bm = bmesh.new()
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(bm.verts.new((rr * math.cos(a), -0.04, rr * math.sin(a))))
    back = [bm.verts.new((v.co.x, 0.04, v.co.z)) for v in pts]
    bm.faces.new(pts)
    bm.faces.new(back[::-1])
    for i in range(10):
        bm.faces.new((pts[i], pts[(i + 1) % 10], back[(i + 1) % 10], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f._place(bm, (x, y, z), (0, 0, 0), color)


# --- actors -----------------------------------------------------------------------------------


def nervous_intern(f):
    """Newcomer, Kid template. Shy, sweaty intern: round glasses, tie + badge, a wobbling tower of coffee cups
    (hero, rises past the head) and a small clipboard held low. Round 2: pill head, soft messy hair (no
    spikes), head raised so the shirt, tie and badge read."""
    skin, shirt, tie, pants = "#F2C49C", "#8FC3EE", "#D83A3A", "#C9A86A"
    shoes, sole, hair = "#7A5434", "#3A2A20", "#6B4226"
    hair_dk, hair_lt = "#523219", "#8A5C34"
    frame = "#2A3350"
    RAISE = 0.3  # head lifts off the shoulders so the shirt and tie show
    legs_kid(f, pants, shoes, sole)
    torso(f, shirt, h=1.7, z=2.0, w=1.8)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), pants, bevel=0.1)  # trousers waist
        f.rbox((0, 0, 1.62), (1.94, 1.46, 0.12), "#4A3022", bevel=0.0)  # belt
        for s_ in (-1, 1):  # collar
            f.rbox((s_ * 0.3, -0.62, 2.78), (0.5, 0.2, 0.3), "#F4F7FA", rot=(0, 0, s_ * -28), bevel=0.0)
        f.rbox((0, -0.7, 2.74), (0.24, 0.12, 0.2), tie, bevel=0.0)
        f.rbox((0, -0.72, 2.22), (0.3, 0.1, 0.95), tie, bevel=0.0, taper=1.7)
        f.rbox((0.52, -0.71, 2.2), (0.42, 0.08, 0.52), "#FFFFFF", bevel=0.0)  # id badge
        f.rbox((0.52, -0.76, 2.28), (0.42, 0.04, 0.16), "#3A8DFF", bevel=0.0)

    def cups(f):
        # five wobbly cups: lean and offset grow with height
        cup = [(k * 1.2, z * 1.2) for k, z in ((0.27, 0.0), (0.34, 0.2), (0.37, 0.4), (0.41, 0.54), (0.41, 0.62))]
        cols = ["#FFFFFF", "#B87333", "#FFFFFF", "#3A2A20"]
        with f.at((0.04, -0.05, 0.12), (-6, 6, 0)):
            for i in range(4):
                wob = math.sin(i * 1.9) * 0.14
                with f.at((wob, 0, i * 0.6), (math.sin(i * 1.3) * 7, math.cos(i * 1.1) * 8, 0)):
                    f.lathe((0, 0, 0), cup, cols, seg=6)

    def clipboard(f):  # small, hanging low by his thigh
        with f.at((-0.05, -0.12, -0.5), (6, 0, -8)):
            f.rbox((0, 0, 0), (0.7, 0.09, 0.9), "#96623C", bevel=0.0)
            f.rbox((0, -0.06, -0.03), (0.56, 0.05, 0.68), "#FAF6EC", bevel=0.0)
            f.rbox((0, -0.07, 0.42), (0.3, 0.08, 0.12), "#F5B82E", bevel=0.0)

    arm(f, 1, shirt, skin, rot=(-50, 58, 0), held=cups, upright=True, shoulder_z=2.55)
    arm(f, -1, shirt, skin, rot=(-6, 16, 0), held=clipboard, shoulder_z=2.55, x=1.14)
    with f.at((0, 0, RAISE)):
        INTERN_HEADS[INTERN_VARIANT](f, skin, hair, hair_dk, hair_lt, frame)


# --- Nervous Intern head variants (round 3: which head/face shape reads best next to Squawk) ---------------
INTERN_VARIANT = "A"


def _intern_face_common(f, skin, ez, spread=0.6, k=1.0, glass_r=0.44, glass_tube=0.065, brow_z=0.72, brow_len=0.95, blush_x=0.9):
    face_eyes(f, skin, spread=spread, k=k, z=ez)
    face_brows(f, "#4A2F1C", length=brow_len, thick=0.2, angle=15, x=spread + 0.04, z=ez + brow_z, lift=(0.04, -0.03))
    face_blush(f, x=blush_x, z=ez - 0.3, seg=6)
    with f.piece("Head"):  # round glasses: thin ring + bridge
        for s_ in (-1, 1):
            with head_at(f, s_ * spread, ez, 0.1):
                f.torus((0, 0, 0), glass_r * k, glass_tube, "#2A3350", major=8, minor=3)
        with head_at(f, 0, ez + 0.08, 0.1):
            f.rbox((0, 0, 0), (0.3, 0.1, 0.09), "#2A3350", bevel=0.0)


def _intern_mouth(f, z, w=0.5, h=0.2, teeth=True):
    """Small clenched-teeth grimace that hugs the chin curve (same trick as Squawk's grin): thin dark lip
    border, a big white teeth patch with two dark gaps, so it reads as gritted teeth, not lipstick."""
    with f.piece("Head"):
        head_patch(f, 0, z, w, h, 0.05, "#7A2836", seg=8, rings=1)
        if teeth:
            head_patch(f, 0, z + 0.01, w * 0.86, h * 0.72, 0.075, "#FFFFFF", seg=8, rings=1)
            for x in (-w * 0.3, w * 0.3):
                with head_at(f, x, z + 0.01, 0.1):
                    f.rbox((0, 0, 0), (0.05, 0.04, h * 1.2), "#7A2836", bevel=0.0)


def _intern_ears_sweat(f, skin, ez, x=1.2):
    with f.piece("Head"):
        for s_ in (-1, 1):
            f.ball((s_ * x, 0.05, ez + 0.05), (0.2, 0.3, 0.38), shade(skin, 0.94), seg=6, rings=3)
    with f.piece("Head"), head_at(f, 1.12, ez + 0.45, 0.06):
        f.ball((0, 0, 0), (0.2, 0.15, 0.3), "#8FD6FF", rot=(0, 0, 14), seg=5, rings=3)


def _intern_head_A(f, skin, hair, hair_dk, hair_lt, frame):
    """A: Squawk's head (same pill, same eye height/spread, grin-style chin mouth). Hair is a tight cap that
    hugs the dome and stops above the brows (clear forehead), no overhang."""
    head_box(f, skin, segs=2)
    top = HEAD_Z0 + HEAD_H
    ez = EYE_Z + 0.1
    with f.piece("Head"):
        f.ball((0, 0.12, top - 0.28), (1.29, 1.02, 0.62), hair, seg=8, rings=5)  # dome cap
        f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)  # back mass
        f.ball((-0.42, -0.25, top + 0.22), (0.8, 0.6, 0.42), hair_lt, rot=(0, 16, 26), seg=7, rings=4)  # swept tuft
        f.ball((0.6, -0.05, top + 0.1), (0.6, 0.5, 0.34), hair, rot=(0, -22, -30), seg=6, rings=4)
        for s_ in (-1, 1):  # side locks like Squawk's, short
            f.ball((s_ * 1.2, 0.3, top - 0.85), (0.3, 0.55, 0.62), hair, seg=6, rings=3)
    _intern_face_common(f, skin, ez)
    _intern_mouth(f, ez - 0.74, w=0.52, h=0.21)
    _intern_ears_sweat(f, skin, ez, x=1.22)


def _intern_head_B(f, skin, hair, hair_dk, hair_lt, frame):
    """B: round-1 head (box with a soft big bevel, flat face), round-1 face, but a bowl-cut hair cap with a
    swept tuft instead of spikes."""
    head_box(f, skin, r=0.55, segs=2)
    top = HEAD_Z0 + HEAD_H
    ez = EYE_Z
    with f.piece("Head"):
        f.rbox((0, 0.0, top - 0.22), (2.58, 2.3, 0.62), hair, bevel=0.3, segs=2)  # cap
        f.rbox((0, 0.98, top - 0.8), (2.5, 0.4, 1.4), hair, bevel=0.12)  # back
        f.ball((-0.35, -0.2, top + 0.22), (0.7, 0.5, 0.34), hair_lt, rot=(0, 16, 26), seg=7, rings=4)
        f.ball((0.55, 0.0, top + 0.12), (0.5, 0.4, 0.28), hair, rot=(0, -22, -30), seg=6, rings=4)
    _intern_face_common(f, skin, ez, glass_r=0.47, glass_tube=0.08)
    with f.piece("Head"), head_at(f, 0, ez - 0.85, 0.03), f.at((0, 0, 0), (0, 4, 0)):  # r1 teeth grimace
        f.rbox((0, 0, 0), (0.9, 0.09, 0.36), "#7A2836", bevel=0.07)
        for i in (-1, 0, 1):
            f.rbox((i * 0.28, -0.04, 0.05), (0.24, 0.06, 0.2), "#FFFFFF", bevel=0.0)
    _intern_ears_sweat(f, skin, ez, x=1.28)


def _intern_head_C(f, skin, hair, hair_dk, hair_lt, frame):
    """C: wider, shorter head with big cheeks and bigger eyes set wide; mouth tucked close under the eyes; a
    single side-swept fringe over the upper forehead."""
    head_box(f, skin, r=0.85, w=2.7, d=2.2, h=2.3, z0=HEAD_Z0 + 0.1, segs=2)
    top = HEAD_Z0 + 0.1 + 2.3
    ez = top - 1.2  # centre-ish
    with f.piece("Head"):
        f.ball((0, 0.1, top - 0.28), (1.4, 1.02, 0.6), hair, seg=8, rings=5)
        f.ball((0, 0.6, top - 1.1), (1.38, 0.95, 1.1), hair, seg=8, rings=5)
        f.ball((-0.5, -0.45, top - 0.5), (0.95, 0.5, 0.3), hair_lt, rot=(0, 24, 20), seg=7, rings=4)  # side-swept fringe
        f.ball((0.5, -0.2, top + 0.12), (0.55, 0.45, 0.3), hair, rot=(0, -22, -30), seg=6, rings=4)
    _intern_face_common(f, skin, ez, spread=0.68, k=1.12, glass_r=0.44, glass_tube=0.06, brow_z=0.78, brow_len=1.0, blush_x=1.02)
    _intern_mouth(f, ez - 0.7, w=0.45, h=0.19)
    _intern_ears_sweat(f, skin, ez, x=1.32)


INTERN_HEADS = {"A": _intern_head_A, "B": _intern_head_B, "C": _intern_head_C}


def mouth_wobble(f, color="#7A2836", z=EYE_Z - 0.85, w=0.9):
    """Nervous grimace (a clenched-teeth mouth, wider than 25% of the head): dark rounded mouth with a
    row of three white teeth."""
    with f.piece("Head"), head_at(f, 0, z, 0.03), f.at((0, 0, 0), (0, 4, 0)):
        f.rbox((0, 0, 0), (w, 0.09, 0.36), color, bevel=0.07)
        for i in (-1, 0, 1):
            f.rbox((i * 0.28, -0.04, 0.05), (0.24, 0.06, 0.2), "#FFFFFF", bevel=0.0)


def werewolf_pup(f):
    """Newcomer (Horror), costume-blob template. A shy understudy in a too-big wolf onesie: hood with two
    big pointed ears and a fur ruff, belly patch, red sneakers. Howls, then says sorry.
    Round 3: back to the ROUND-1 pup (user: 'the first one looks better'): same box-with-soft-bevel head
    (r 0.25), flat face plate + fluffy rim, cheek tufts, ears and crest as in round 1. Only change kept from
    round 2: the big fluffy tail curling out to the actor's left."""
    fur, fur_lt, fur_dk = "#8A8F99", "#B9BEC8", "#5E6370"
    cream, pink, red, dark = "#F4E7CF", "#F08A8A", "#D83A3A", "#3A1F2B"
    legs_kid(f, fur, red, cream, spread=0.62, hip=1.4, r=0.46)
    torso(f, fur, w=2.7, d=2.1, h=1.75, z=1.95, taper=0.92, bevel=0.5)
    with f.piece("Body"):
        with f.at((0, -1.04, 1.8), (90, 0, 0)):
            f.disc((0, 0, 0), 1.5, 1.3, 0.07, cream, seg=12)  # belly patch
        f.rbox((0, 1.04, 2.0), (0.2, 0.07, 2.1), fur_dk, bevel=0.0)  # back zip
        f.rbox((0, 1.07, 1.15), (0.34, 0.09, 0.36), "#F5B82E", bevel=0.0)  # zip pull
        # round-2 tail: base blob, plume sweeping out to the actor's left (+X), cream tip curling up
        f.ball((0.5, 1.15, 1.25), (0.72, 0.62, 0.62), fur, seg=7, rings=4)
        f.ball((1.45, 0.8, 1.05), (0.62, 0.55, 1.15), fur, rot=(0, 78, 0), seg=8, rings=4)
        f.ball((1.45, 0.72, 1.12), (0.46, 0.4, 0.95), fur_lt, rot=(0, 78, 0), seg=6, rings=3)
        f.ball((2.1, 0.62, 1.72), (0.5, 0.44, 0.62), cream, rot=(0, 20, 0), seg=7, rings=4)

    def pad(f):
        with f.at((0, -0.26, 0.0), (90, 0, 0)):
            f.disc((0, -0.03, 0), 0.32, 0.28, 0.05, pink, seg=8)
            for x in (-0.19, 0.0, 0.19):
                f.disc((x, 0.22, 0), 0.12, 0.12, 0.05, pink, seg=5)

    arm(f, 1, fur, fur, rot=(0, 150, 0), held=pad, x=1.5, length=0.8, sleeve_r=0.38)
    arm(f, -1, fur, fur, rot=(-6, 8, 0), held=pad, x=1.5, length=0.8, sleeve_r=0.38)
    head_box(f, fur, r=0.25, segs=2)  # round-1 head: face is flat across the middle, so head_at(out=0.1) == r1 y0
    top = HEAD_Z0 + HEAD_H
    OUT = 0.1
    with f.piece("Head"):
        with f.at((0, FACE_Y - 0.03, 3.45), (90, 0, 0)):
            f.disc((0, 0, 0), 1.9, 2.0, 0.12, "#FFF4E0", seg=14)  # face plate
        f.torus((0, FACE_Y - 0.07, 3.45), 0.98, 0.13, fur_lt, major=14, minor=4, sz=1.02)  # fluffy hood rim
        for s_ in (-1, 1):
            for z, ang in ((3.25, 105), (2.8, 118)):  # cheek tufts
                f.spike((s_ * 1.18, FACE_Y + 0.35, z), 0.26, 0.42, fur_lt, rot=(0, s_ * ang, 0), seg=4, squash=0.5)
            with f.at((s_ * 0.82, 0.05, top - 0.12), (-8, s_ * 16, 0)):  # ears
                f.spike((0, 0, 0), 0.72, 1.25, fur, seg=4, squash=0.55)
                f.spike((0, -0.2, 0.02), 0.44, 0.85, pink, seg=4, squash=0.5)
        f.rbox((0, 0.4, top + 0.02), (0.9, 1.3, 0.14), fur_dk, bevel=0.0)  # hood crest
    face_eyes(f, cream, spread=0.56, k=1.1, out=OUT, z=3.5)
    face_brows(f, "#4E5260", length=0.9, thick=0.2, angle=22, x=0.58, z=3.5 + 0.78, out=OUT)
    face_blush(f, pink, x=0.78, z=3.0, out=OUT, w=0.36, h=0.24)
    with f.piece("Head"):
        with head_at(f, 0, 3.12, OUT + 0.1):
            f.ball((0, 0, 0), (0.26, 0.17, 0.19), EYE_DARK, seg=7, rings=4)  # nose
        with head_at(f, 0, 2.72, OUT), f.at((0, 0, 0), (90, 0, 0)):  # howl mouth: dark O, tongue
            f.disc((0, 0, 0.0), 0.74, 0.54, 0.06, dark, seg=12)
            f.disc((0, -0.12, 0.04), 0.46, 0.24, 0.05, pink, seg=8)
        for s_ in (-1, 1):
            with head_at(f, s_ * 0.22, 2.98, OUT + 0.04):
                f.spike((0, 0, 0), 0.09, 0.2, "#FFFFFF", rot=(180, 0, 0), seg=4)


def parrot(f, green, belly, blue, yellow, red, beak, cream):
    """The huge parrot, world coordinates (studs): perched on the captain's left shoulder (+X), body behind it,
    head turned outward with a big hooked beak (outside the body outline so it reads at 64 px), two fanned
    wings (blue with yellow tips) spreading out and up, red tail feathers hanging. Everything goes in Body."""
    toe = "#E0A020"
    for dx in (-0.22, 0.22):  # claws gripping the shoulder
        f.rbox((1.35 + dx, -0.12, 2.95), (0.26, 0.8, 0.18), toe, bevel=0.0)
    f.ball((1.6, 0.75, 3.55), (0.85, 0.75, 1.2), green, seg=8, rings=5)  # body behind the shoulder
    f.ball((1.6, 0.3, 3.35), (0.6, 0.4, 0.82), belly, seg=7, rings=4)  # light belly
    # round 3: the head sits further out and back (behind the captain's face plane in the 3/4 view) and is
    # turned outward, with a small hooked beak, so the face stays clear from front and 3/4
    with f.at((2.55, 0.5, 4.0), (0, 0, 48)):
        f.ball((0, 0, 0), (0.8, 0.76, 0.8), green, seg=8, rings=5)
        with f.at((0, -0.64, 0.05), (90, 0, 0)):
            f.disc((0, 0, 0), 1.05, 0.85, 0.08, cream, seg=9)  # pale face patch
            for s_ in (-1, 1):
                f.disc((s_ * 0.27, 0.04, 0.05), 0.33, 0.4, 0.05, EYE_DARK, seg=6)
                f.disc((s_ * 0.27 - 0.06, 0.14, 0.09), 0.11, 0.12, 0.04, "#FFFFFF", seg=4)
        for s_ in (-1, 1):  # bossy brows
            f.rbox((s_ * 0.31, -0.68, 0.4), (0.44, 0.1, 0.15), shade(green, 0.55), rot=(0, -s_ * 22, 0), bevel=0.0)
        f.spike((0, -0.6, -0.04), 0.3, 0.72, beak, rot=(100, 0, 0), seg=5, squash=0.9)  # small upper beak
        f.spike((0, -1.22, -0.14), 0.18, 0.34, shade(beak, 0.82), rot=(180, 0, 0), seg=4)  # the hook
        for i, ry in enumerate((-20, 20)):  # crest
            f.leaf((0, 0.05, 0.64), (-18, ry, 0), 0.85, 0.32, 0.1, red, tip=0.4)
    # wings: fans of long feathers spreading out past her arms
    for side, jx, lens in ((1, 1.95, (1.65, 1.75, 1.5)), (-1, 0.7, (1.8, 1.7, 1.4))):
        f.ball((jx + side * 0.3, 1.3, 3.95), (0.55, 0.2, 0.55), green, seg=6, rings=3)  # coverts
        for i, (a, ln) in enumerate(zip((8, 33, 58), lens)):
            col = blue if i % 2 == 0 else shade(blue, 0.8)
            f.leaf((jx, 1.4 + 0.07 * i, 3.95), (0, side * (90 - a), 0), ln, 0.85, 0.13, col, tip_color=yellow, tip_from=0.64)
    for i, ry in enumerate((-12, 12)):  # tail
        f.leaf((1.35, 1.45, 2.7), (176, ry, 0), 1.7, 0.46, 0.12, red if i == 0 else shade(blue, 0.9), tip_color=yellow if i == 0 else None, tip_from=0.78)


def tricorn(f, hat, trim, cy=-0.05, z=4.78, rh=1.65, ext=0.95, hm=1.2, hc=0.3, thick=0.2, xs=1.3):
    """A real three-cornered pirate hat: one point forward (-Y) and two back, the three brim sides all fold up
    in the middle of each side (corners pinched low, so the classic crescent dips at the front point), gold
    trim round the folded edges. One closed mesh: top sheet, bottom sheet and gold rim walls. Built in the
    Head piece, so call inside `with f.piece("Head")`."""
    bm = bmesh.new()
    angs = [-90, 30, 150]
    V, U = [], []
    for a in angs:
        r = math.radians(a)
        V.append(bm.verts.new((xs * rh * math.cos(r), cy + rh * math.sin(r), 0.0)))
        U.append(bm.verts.new((xs * (rh + 0.1) * math.cos(r), cy + (rh + 0.1) * math.sin(r), hc)))
    M = []
    for k in range(3):
        a = math.radians((angs[k] + (angs[k + 1] if k < 2 else angs[0] + 360)) / 2)
        d = rh * 0.5 + ext
        M.append(bm.verts.new((xs * d * math.cos(a), cy + d * math.sin(a), hm)))
    tops, rims = [], []
    for k in range(3):
        k2 = (k + 1) % 3
        for tri in ((V[k], V[k2], U[k2]), (V[k], U[k2], M[k]), (V[k], M[k], U[k])):
            tops.append(tri)
        rims += [(V[k], V[k2]), (U[k2], M[k]), (M[k], U[k])]
    # the hat's own top surface plus a copy `thick` lower for the underside and rim walls
    bot = {v: bm.verts.new((v.co.x, v.co.y, v.co.z - thick)) for v in V + U + M}
    out = []
    for tri in tops:
        c = sum((v.co for v in tri), Vector()) / 3
        n = (tri[1].co - tri[0].co).cross(tri[2].co - tri[0].co)
        a, b, c3 = tri if n.z > 0 else (tri[0], tri[2], tri[1])
        bm.faces.new((a, b, c3)).material_index = 0
        bm.faces.new((bot[a], bot[c3], bot[b])).material_index = 1
    for a, b in rims:
        cen = (a.co + b.co) / 2
        flat = Vector((cen.x / xs, cen.y - cy, 0))
        w = bm.faces.new((a, b, bot[b], bot[a]))
        w.material_index = 2
        if w.normal.dot(flat) < 0:
            w.normal_flip()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    def col(face):
        return (hat, shade(hat, 0.6), trim)[face.material_index]

    f._place(bm, (0, 0, z), (0, 0, 0), col)


def captain_squawk(f):
    """Superstar (Comedy), Hero template. A pirate captain whose huge parrot gives the orders: a real tricorn
    (three folded sides, gold trim, red plume), burgundy coat with wide cream lapels and big cuffs, teal sash,
    wide-cuffed boots and a peg leg, curly moustache; the parrot perches on her left shoulder with wings
    spread (second silhouette extension, rule 17). Round 2: pirate, not police."""
    skin, coat, coat_dk, gold, teal = "#C68A5A", "#A63446", "#7C2433", "#F5B82E", "#2BA5B8"
    hair, boots, wood, cream = "#3A2218", "#3A2A20", "#9A6434", "#F4E7CF"
    hat, breeches, cuff_tan = "#232640", "#E8DCC0", "#B07A3C"
    green, belly, blue, yellow, pred, beak = "#54B860", "#9BE08F", "#2D7FE0", "#FFD84A", "#E8453C", "#F08A2E"
    with f.piece("Body"):  # legs: breeches, tall wide-cuffed boot on the left, wooden peg on the right
        for s_ in (-1, 1):
            f.rcyl((s_ * 0.55, 0, 0.95), 0.38, 0.44, 1.0, breeches, seg=8, bevel=0.0)
        f.rbox((0.55, -0.15, 0.5), (0.98, 1.34, 1.0), boots, bevel=0.14)
        f.rbox((0.55, -0.15, 0.98), (1.02, 1.38, 0.5), cuff_tan, bevel=0.0, taper=1.18)  # big folded boot cuff
        f.rbox((0.55, -0.15, 0.07), (1.02, 1.38, 0.14), "#241A14", bevel=0.0)
        f.rcyl((-0.55, 0, 0.55), 0.3, 0.42, 1.1, wood, seg=7, bevel=0.0)  # peg leg
        f.rcyl((-0.55, 0, 0.07), 0.34, 0.34, 0.14, "#5A3A1C", seg=7, bevel=0.0)
        f.rcyl((-0.55, 0, 1.0), 0.47, 0.47, 0.2, "#6A4630", seg=7, bevel=0.0)  # strap
        f.rbox((0, 0, 1.55), (2.6, 1.7, 0.95), coat, bevel=0.14, taper=0.82)  # long coat skirt flares over the legs
        f.rbox((0, 0, 1.1), (2.66, 1.76, 0.14), gold, bevel=0.0, taper=0.99)  # hem trim
        for s_ in (-1, 1):  # coat tails at the back
            f.rbox((s_ * 0.7, 0.85, 1.4), (0.95, 0.5, 1.15), coat_dk, rot=(-4, 0, s_ * -6), bevel=0.0, taper=0.7)
    torso(f, coat, w=2.2, d=1.5, h=1.55, z=2.05, taper=0.9, bevel=0.15)
    with f.piece("Body"):
        f.rbox((0, -0.76, 2.35), (0.5, 0.08, 1.2), cream, bevel=0.0, taper=2.2)  # shirt V
        for x in (-0.22, 0.22):  # frilly jabot under the chin
            f.ball((x, -0.84, 2.5), (0.26, 0.17, 0.2), "#FFFFFF", seg=5, rings=3)
        for s_ in (-1, 1):
            f.rbox((s_ * 0.74, -0.78, 2.28), (0.52, 0.09, 1.3), cream, bevel=0.0, rot=(0, s_ * 20, 0))  # wide lapel
            f.rbox((s_ * 0.54, -0.83, 2.28), (0.09, 0.07, 1.3), gold, bevel=0.0, rot=(0, s_ * 20, 0))  # lapel trim
            for z in (1.95,):
                with f.at((s_ * 0.92, -0.76, z), (90, 0, 0)):
                    f.disc((0, 0, 0), 0.22, 0.22, 0.07, gold, seg=5)  # buttons
        f.rbox((0, 0, 1.6), (2.34, 1.62, 0.38), teal, bevel=0.1)  # sash
        f.rbox((0, -0.84, 1.6), (0.5, 0.09, 0.4), gold, bevel=0.0)  # buckle
        f.rbox((-0.95, -0.7, 1.35), (0.34, 0.12, 0.9), teal, rot=(0, 0, -8), bevel=0.0, taper=1.3)
        f.rbox((-0.75, -0.7, 1.37), (0.3, 0.12, 0.75), shade(teal, 0.8), rot=(0, 0, 14), bevel=0.0, taper=1.3)

    def cuff(f):  # wide folded cuff over the wrist
        f.rcyl((0, 0, 0.3), 0.52, 0.44, 0.5, cream, seg=7, bevel=0.0)

    arm(f, -1, coat, skin, rot=(-8, 18, 0), x=1.28, length=0.95, sleeve_r=0.33, shoulder_z=2.55, held=cuff)
    arm(f, 1, coat, skin, rot=(-4, 22, 0), x=1.28, length=0.95, sleeve_r=0.33, shoulder_z=2.55, held=cuff)
    with f.at((0, 0, 0.2)):  # head lifts a little so the jabot and lapels show
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + HEAD_H
        with f.piece("Head"):
            f.ball((0, 0.85, 3.55), (1.3, 0.95, 1.2), hair, seg=8, rings=5)  # long hair mass behind
            for s_ in (-1, 1):
                f.ball((s_ * 1.22, 0.25, 3.3), (0.34, 0.55, 0.85), hair, seg=6, rings=3)  # side locks
        face_eyes(f, skin, spread=0.6, k=1.0, z=EYE_Z + 0.12)
        face_brows(f, "#2A1710", length=1.0, thick=0.22, angle=9, x=0.62, z=EYE_Z + 0.84, worried=False, lift=(0.0, 0.2))
        face_blush(f, z=EYE_Z - 0.26)
        with f.piece("Head"):
            for s_ in (-1, 1):  # curly moustache
                with head_at(f, s_ * 0.33, EYE_Z - 0.33, 0.04):
                    f.ball((0, 0, 0), (0.36, 0.17, 0.15), hair, rot=(0, 0, s_ * 20), seg=6, rings=3)
            # big smug grin with a gold tooth: patches that hug the round chin
            head_patch(f, 0, EYE_Z - 0.6, 0.72, 0.27, 0.05, "#7A2836", seg=8, rings=1)
            head_patch(f, 0, EYE_Z - 0.5, 0.58, 0.11, 0.075, "#FFFFFF", seg=8, rings=1)  # teeth
            head_patch(f, 0.32, EYE_Z - 0.5, 0.11, 0.11, 0.1, gold, seg=4, rings=1)  # gold tooth
            with head_at(f, 1.2, EYE_Z - 0.05, 0.0):  # gold hoop earring
                f.torus((0, 0, 0), 0.24, 0.05, gold, rot=(0, 0, 0), major=8, minor=3)
            tricorn(f, hat, gold)
            with f.at((0, 0.0, 4.78)):  # crown + band + cockade + plume
                f.rcyl((0, 0, 0.75), 1.28, 1.05, 1.5, hat, seg=8, bevel=0.32, segs=1)
                f.rcyl((0, 0, 0.18), 1.34, 1.34, 0.2, gold, seg=8, bevel=0.0)
                f.ball((0, -1.7, 0.4), (0.3, 0.14, 0.3), gold, seg=6, rings=3)  # button at the front point
                f.leaf((-1.0, 0.5, 0.75), (-6, -52, 0), 1.15, 0.5, 0.13, pred, tip=0.35, widest=0.4)
    with f.piece("Body"):
        parrot(f, green, belly, blue, yellow, pred, beak, cream)


# --- scene, build, render ---------------------------------------------------------------------

ACTORS = {
    "intern": ("NervousIntern", "Newcomer", nervous_intern),
    "pup": ("WerewolfPup", "Newcomer", werewolf_pup),
    "squawk": ("PirateCaptain", "Superstar", captain_squawk),
}
GAP = 30  # studs between actors in the scene (so AO never sees a neighbour)


def new_scene():
    old = bpy.data.scenes.get(SCENE_NAME)
    if old:
        for o in list(old.objects):
            data = o.data
            bpy.data.objects.remove(o)
            if data and getattr(data, "users", 1) == 0 and isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)
        w = old.world
        bpy.data.scenes.remove(old)
        if w and w.users == 0:
            bpy.data.worlds.remove(w)
    sc = bpy.data.scenes.new(SCENE_NAME)
    bpy.context.window.scene = sc
    sc.world = bpy.data.worlds.new("A2_World")
    return sc


def build(key, index=0, with_ao=True):
    name, tier, fn = ACTORS[key]
    f = Fig(name, tier)
    fn(f)
    plinth(f, tier)
    objs = f.finish_objects(offset=(index * GAP, 0, 0))
    return f, objs


def stage_lights(sc):
    w = sc.world
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = lin("#F6F0E2")
    bg.inputs["Strength"].default_value = 0.9
    for n in ("A2_Sun", "A2_Fill"):
        if n in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[n])
    sun = bpy.data.objects.new("A2_Sun", bpy.data.lights.new("A2_Sun", "SUN"))
    sun.data.energy = 3.0
    sun.data.angle = math.radians(10)
    sun.data.color = (1.0, 0.95, 0.86)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-32))
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new("A2_Fill", bpy.data.lights.new("A2_Fill", "AREA"))
    fill.data.energy = 220
    fill.data.size = 6
    fill.location = (-2, -5, 2.2)
    fill.rotation_euler = (math.radians(80), 0, math.radians(-20))
    sc.collection.objects.link(fill)


def floor_for(sc, x=0.0, size=400.0):
    if "A2_Floor" in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects["A2_Floor"])
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size)
    me = bpy.data.meshes.new("A2_Floor")
    bm.to_mesh(me)
    bm.free()
    mat = bpy.data.materials.get("A2_FloorMat") or bpy.data.materials.new("A2_FloorMat")
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = lin("#F6F0E2")
    bsdf.inputs["Roughness"].default_value = 0.95
    me.materials.append(mat)
    o = bpy.data.objects.new("A2_Floor", me)
    o.location = (x, 0, -0.68 * STUD)  # the plinth bottom sits on the floor
    sc.collection.objects.link(o)
    return o


def _sil_material():
    m = bpy.data.materials.get("A2_Sil") or bpy.data.materials.new("A2_Sil")
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0, 0, 0, 1)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def shoot(sc, objs, path, az=0, el=8, res=900, lens=85, margin=1.32, sil=False, samples=40, floor=True, center=None, radius=None, dist_mul=1.0, hide_others=True):
    """Render `objs` (list of objects) from azimuth az (0 = front, +x side positive) and elevation el."""
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = center or (lo + hi) / 2
    rad = radius or max((hi - lo).length / 2, 0.5)
    cam_d = bpy.data.cameras.new("A2_Cam")
    cam_d.lens = lens
    cam_d.sensor_width = 36
    cam_d.clip_end = 200
    cam = bpy.data.objects.new("A2_Cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    fov = 2 * math.atan(18 / lens)
    dist = rad * margin / math.sin(fov / 2) * dist_mul * 0.78
    a, e = math.radians(az), math.radians(el)
    cam.location = ctr + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    keep = {}
    others = [o for o in sc.objects if o.type == "MESH" and o not in objs and o.name != "A2_Floor"]
    for o in others:
        keep[o] = o.hide_render
        if hide_others:
            o.hide_render = True
    fl = bpy.data.objects.get("A2_Floor")
    if fl:
        keep[fl] = fl.hide_render
        fl.hide_render = bool(sil) or not floor
    mats = {}
    bgc = None
    if sil:
        sm = _sil_material()
        for o in objs:
            mats[o] = [s.material for s in o.material_slots]
            for s in o.material_slots:
                s.material = sm
        bgn = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
        bgc = (tuple(bgn.inputs["Color"].default_value), bgn.inputs["Strength"].default_value)
        bgn.inputs["Color"].default_value = (1, 1, 1, 1)
        bgn.inputs["Strength"].default_value = 1.0
        sc.render.engine = "BLENDER_EEVEE"
        for l in ("A2_Sun", "A2_Fill"):
            if l in bpy.data.objects:
                bpy.data.objects[l].hide_render = True
    else:
        sc.render.engine = "CYCLES"
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
        sc.render.filter_size = 1.2
    bpy.ops.render.render(write_still=True)
    # restore
    for o, h in keep.items():
        o.hide_render = h
    for o, ms in mats.items():
        for s, m in zip(o.material_slots, ms):
            s.material = m
    if bgc:
        bgn.inputs["Color"].default_value = bgc[0]
        bgn.inputs["Strength"].default_value = bgc[1]
        for l in ("A2_Sun", "A2_Fill"):
            if l in bpy.data.objects:
                bpy.data.objects[l].hide_render = False
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(cam_d)
    return path


# -- image helpers (no PIL in Blender): numpy on bpy.data.images


def load_img(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[::-1]  # top-down


def save_img(arr, path):
    arr = np.clip(arr, 0, 1)
    h, w = arr.shape[:2]
    im = bpy.data.images.new("A2_tmp", w, h, alpha=True)
    im.colorspace_settings.name = "sRGB"
    im.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel().astype(np.float32))
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def box_down(a, k):
    h, w = a.shape[:2]
    return a[: h // k * k, : w // k * k].reshape(h // k, k, w // k, k, 4).mean(axis=(1, 3))


def hstack(imgs, pad=12, bg=(1, 1, 1, 1)):
    h = max(i.shape[0] for i in imgs)
    out = []
    for i in imgs:
        canvas = np.ones((h, i.shape[1], 4), dtype=np.float32) * np.array(bg, dtype=np.float32)
        canvas[: i.shape[0]] = i
        out.append(canvas)
        out.append(np.ones((h, pad, 4), dtype=np.float32) * np.array(bg, dtype=np.float32))
    return np.concatenate(out[:-1], axis=1)


def vstack(imgs, pad=12, bg=(1, 1, 1, 1)):
    w = max(i.shape[1] for i in imgs)
    out = []
    for i in imgs:
        canvas = np.ones((i.shape[0], w, 4), dtype=np.float32) * np.array(bg, dtype=np.float32)
        canvas[:, : i.shape[1]] = i
        out.append(canvas)
        out.append(np.ones((pad, w, 4), dtype=np.float32) * np.array(bg, dtype=np.float32))
    return np.concatenate(out[:-1], axis=0)


def render_set(sc, key, objs, tag, res=720):
    """All draft renders of one actor. Returns paths."""
    os.makedirs(OUT_DIR, exist_ok=True)
    base = os.path.join(OUT_DIR, f"actors_v2_{tag}")
    paths = {}
    for name, az, el in (("front", 0, 14), ("34", 35, 16), ("back", 180, 14)):
        paths[name] = shoot(sc, objs, f"{base}_{name}.png", az=az, el=el, res=res)
    sil = shoot(sc, objs, f"{base}_sil_big.png", az=0, el=0, res=512, sil=True)
    paths["sil"] = sil
    # silhouette + 64 px icon + game distance
    s256 = shoot(sc, objs, f"{base}_sil_256.png", az=0, el=0, res=256, sil=True)
    sil64 = box_down(load_img(s256), 4)
    save_img(sil64, f"{base}_sil_64.png")
    c256 = shoot(sc, objs, f"{base}_icon_256.png", az=25, el=16, res=256, samples=32)
    icon64 = box_down(load_img(c256), 4)
    save_img(icon64, f"{base}_icon_64.png")
    game = shoot(sc, objs, f"{base}_game.png", az=30, el=24, res=200, lens=50, dist_mul=2.2, samples=32, margin=1.0)
    paths.update(sil64=f"{base}_sil_64.png", icon64=f"{base}_icon_64.png", game=game)
    for p in (s256, c256):
        os.remove(p)
    # sheet: front | 3/4 | back | silhouette (big) | 64px sil x4 | 64px icon x4 | game
    big = lambda a, k: np.repeat(np.repeat(a, k, 0), k, 1)  # noqa: E731
    row1 = hstack([load_img(paths["front"]), load_img(paths["34"]), load_img(paths["back"])])
    sil_big = load_img(paths["sil"])
    row2 = hstack([sil_big, big(sil64, 4), big(icon64, 4), load_img(paths["game"])])
    sheet = vstack([row1, row2])
    save_img(sheet, f"{base}_sheet.png")
    paths["sheet"] = f"{base}_sheet.png"
    return paths


def silhouette_strip(sc, groups, path):
    """64 px black silhouettes of several actors side by side (x4 for viewing)."""
    tiles = []
    for objs in groups:
        p = shoot(sc, objs, path.replace(".png", "_t.png"), az=0, el=0, res=256, sil=True)
        tiles.append(np.repeat(np.repeat(box_down(load_img(p), 4), 4, 0), 4, 1))
        os.remove(p)
    save_img(hstack(tiles, pad=8), path)


def export_fbx(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        global_scale=1 / (STUD * 100),
        apply_unit_scale=True,
        bake_space_transform=True,
        colors_type="SRGB",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="EDGE",
        add_leaf_bones=False,
    )


def main(keys=("intern", "pup", "squawk"), render=True, ao=True):
    sc = new_scene()
    built = {}
    for i, key in enumerate(keys):
        f, objs = build(key, i)
        built[key] = (f, objs)
    allobjs = [o for _, ob in built.values() for o in ob.values()]
    if ao:
        ok = bake_ao(allobjs)
        print("AO baked:", ok)
    smooth(allobjs)
    stage_lights(sc)
    floor_for(sc, x=0)
    report = {}
    for key, (f, objs) in built.items():
        report[key] = qa(f.name, objs)
        print(key, report[key])
    return sc, built, report


def quick(key, res=480, views=((0, 14), (35, 16), (180, 14)), tag="quick"):
    """Fast iteration: rebuild one actor and save front | 3/4 | back to /tmp."""
    sc, built, report = main((key,))
    f, objs = built[key]
    ol = list(objs.values())
    shots = []
    for i, (az, el) in enumerate(views):
        p = shoot(sc, ol, f"/tmp/a2_{tag}_{i}.png", az=az, el=el, res=res, margin=1.3, samples=24)
        shots.append(load_img(p))
    out = f"/tmp/a2_{tag}_{key}.png"
    save_img(hstack(shots, pad=4), out)
    by, kinds = {}, {}
    for p, k, t in f.log:
        by[p] = by.get(p, 0) + t
        kinds[(p, k)] = kinds.get((p, k), 0) + t
    print("tris by piece:", by)
    print("top kinds:", sorted(kinds.items(), key=lambda kv: -kv[1])[:8])
    return out


def quick4(key, res=520, tag="q4"):
    """Rebuild one actor and save a 2x2 sheet (front, 3/4, side, back) to /tmp for judging the shape."""
    sc, built, report = main((key,))
    f, objs = built[key]
    ol = list(objs.values())
    shots = [load_img(shoot(sc, ol, f"/tmp/a2_{tag}_{i}.png", az=az, el=el, res=res, margin=1.15, samples=24)) for i, (az, el) in enumerate(((0, 8), (40, 14), (90, 8), (180, 10)))]
    out = f"/tmp/a2_{tag}_{key}.png"
    save_img(vstack([hstack(shots[:2], pad=4), hstack(shots[2:], pad=4)], pad=4), out)
    return out


def compare_r1_r2(tag, key_label=""):
    """Round-1 vs round-2 side by side (front + 3/4 of each), r2 tiles get a green top bar."""
    r1 = [load_img(os.path.join(OUT_DIR, f"actors_v2_{tag}_{v}.png")) for v in ("front", "34")]
    r2 = [load_img(os.path.join(OUT_DIR, f"actors_v2_r2_{tag}_{v}.png")) for v in ("front", "34")]
    for a in r2:
        a[:14, :, :3] = np.array(lin("#4CC764")[:3])
    for a in r1:
        a[:14, :, :3] = np.array(lin("#A7A9AC")[:3])
    out = os.path.join(OUT_DIR, f"actors_v2_r2_{tag}_compare.png")
    save_img(hstack([r1[0], r2[0], r1[1], r2[1]], pad=6), out)
    return out


def export_r2(key):
    """FBX of one actor (moved to the origin for the export, then put back)."""
    sc = bpy.data.scenes[SCENE_NAME]
    name = ACTORS[key][0]
    objs = objs_named(name)
    old = {o: o.location.copy() for o in objs}
    for o in objs:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    path = os.path.join(OUT_DIR, f"actors_v2_r2_{key}.fbx")
    export_fbx(objs, path)
    for o, l in old.items():
        o.location = l
    return path


def objs_named(name):
    sc = bpy.data.scenes[SCENE_NAME]
    return [o for o in sc.objects if o.name.startswith(name + "_") and not o.name.startswith(name + "_OLD")]


def render_actor(key, res=720):
    name = ACTORS[key][0]
    sc = bpy.data.scenes[SCENE_NAME]
    bpy.context.window.scene = sc
    objs = objs_named(name)
    floor_for(sc, x=0)
    return render_set(sc, key, objs, key, res=res)


def compare_intern(res=900):
    """Old (current, game) Nervous Intern next to the new one: same light, same camera."""
    import importlib

    sc = bpy.data.scenes[SCENE_NAME]
    bpy.context.window.scene = sc
    sys_path = os.path.join(REPO, "art", "blender")
    if sys_path not in sys.path:
        sys.path.insert(0, sys_path)
    old = importlib.import_module("actors")
    a = old.make("NervousIntern", "Newcomer", old.nervous_intern)
    a.name = "NervousIntern_OLD"
    oo = a.objects((-6.4, 0, -0.23))
    new = objs_named("NervousIntern")
    both = list(oo.values()) + new
    paths = []
    for name, az, el in (("front", 0, 20), ("34", 30, 22)):
        p = shoot(sc, both, os.path.join(OUT_DIR, f"actors_v2_intern_compare_{name}.png"), az=az, el=el, res=res, hide_others=False, margin=1.05, lens=70, samples=40)
        paths.append(p)
    for o in oo.values():
        mesh = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(mesh)
    return paths


# --- round 3 deliverables ---------------------------------------------------------------------


def intern_variants_sheet(path=None, res=640):
    """Three Nervous Intern head/face variants (A = pick, B = round-1 style head, C = wide head), each shown
    front and 3/4, one row per variant. Rebuilds the scene per variant; call finalize_r3() afterwards."""
    path = path or os.path.join(OUT_DIR, "actors_v2_r3_intern_variants.png")
    rows = []
    for v in ("A", "B", "C"):
        global INTERN_VARIANT
        INTERN_VARIANT = v
        sc, built, _ = main(("intern",))
        f, objs = built["intern"]
        ol = list(objs.values())
        tiles = [load_img(shoot(sc, ol, f"/tmp/a2_var_{v}_{i}.png", az=az, el=el, res=res, margin=1.0, samples=40)) for i, (az, el) in enumerate(((0, 14), (35, 16)))]
        # a head close-up too, so the face shape is easy to judge
        pts = [o.matrix_world @ Vector(c) for o in ol if o.name.endswith("_Head") for c in o.bound_box]
        ctr = sum(pts, Vector()) / len(pts)
        tiles.append(load_img(shoot(sc, ol, f"/tmp/a2_var_{v}_2.png", az=0, el=14, res=res, center=ctr, radius=0.55, margin=1.0, samples=40)))
        bar = {"A": "#4CC764", "B": "#A7A9AC", "C": "#A7A9AC"}[v]
        for t in tiles:
            t[:14, :, :3] = np.array(lin(bar)[:3])
        rows.append(hstack(tiles, pad=6))
    INTERN_VARIANT = "A"
    save_img(vstack(rows, pad=8), path)
    return path


def compare_r3(key, prev_prefix, prev_bar="#A7A9AC"):
    """Previous round (grey bar) vs round 3 (green bar): front and 3/4 of each."""
    old = [load_img(os.path.join(OUT_DIR, f"{prev_prefix}_{v}.png")) for v in ("front", "34")]
    new = [load_img(os.path.join(OUT_DIR, f"actors_v2_r3_{key}_{v}.png")) for v in ("front", "34")]
    for a in old:
        a[:14, :, :3] = np.array(lin(prev_bar)[:3])
    for a in new:
        a[:14, :, :3] = np.array(lin("#4CC764")[:3])
    out = os.path.join(OUT_DIR, f"actors_v2_r3_{key}_compare.png")
    save_img(hstack([old[0], new[0], old[1], new[1]], pad=6), out)
    return out


def finalize_r3(render=True):
    """Build all three, QA, render every sheet as actors_v2_r3_*, compares, silhouettes, FBX."""
    global INTERN_VARIANT
    INTERN_VARIANT = "A"
    sc, built, report = main(("intern", "pup", "squawk"))
    out = {"qa": report}
    if not render:
        return sc, built, out
    for key, (f, objs) in built.items():
        ol = list(objs.values())
        out[key] = render_set(sc, key, ol, f"r3_{key}")
        # FBX at the origin
        old = {o: o.location.copy() for o in ol}
        for o in ol:
            o.location = (0, 0, 0)
        bpy.context.view_layer.update()
        export_fbx(ol, os.path.join(OUT_DIR, f"actors_v2_r3_{key}.fbx"))
        for o, l in old.items():
            o.location = l
        bpy.context.view_layer.update()
    silhouette_strip(sc, [list(b[1].values()) for b in built.values()], os.path.join(OUT_DIR, "actors_v2_r3_silhouettes_64.png"))
    compare_r3("intern", "actors_v2_r2_intern")
    compare_r3("squawk", "actors_v2_r2_squawk")
    compare_r3("pup", "actors_v2_pup")  # pup: round 1 vs round 3
    return sc, built, out
