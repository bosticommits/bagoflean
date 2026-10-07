"""Shared helpers for the store art: logo, thumbnails and icon (art/blender/store/).

The scenes reuse the game's own part-built models. `dump()` runs art/preview/dump.luau with
Lune to get a model's parts as JSON, and `import_parts()` turns them into bevelled Blender
objects, so the store art always matches what players see in the game.

Run a store script from the repo root with the `bpy` package (Python 3.11) and Lune on PATH
(or LUNE=/path/to/lune):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" \
      art/blender/store/thumbnail.py
Renders go to $STORE_OUT (default /tmp/store). They render with Cycles on the CPU.
"""

import json
import math
import os
import random
import shutil
import subprocess

import bmesh
import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.environ.get("STORE_OUT", "/tmp/store")
DUMPS = os.path.join(OUT, "dumps")

# Roblox is Y-up with models facing -Z. Blender is Z-up; this maps a Roblox frame so models
# face -Y (towards a camera placed on the -Y side), without mirroring.
ROBLOX_TO_BLENDER = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4))


def lin(rgb):
    return tuple(srgb_to_linear(c) for c in rgb)


# ---------------------------------------------------------------------------------------------
# Scene and render setup


def new_scene(width, height, samples=96, transparent=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = int(os.environ.get("STORE_SAMPLES", samples))
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 16
    scene.cycles.caustics_reflective = False
    scene.cycles.caustics_refractive = False
    scene.cycles.blur_glossy = 1.0
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = int(os.environ.get("STORE_SCALE", "100"))
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.view_settings.view_transform = "Khronos PBR Neutral"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    return scene


def sky(top="#3B6FD8", middle="#7FB2F0", horizon="#FFC98A", glow="#FF8FB1", strength=1.0, light_strength=None):
    """Gradient sky by elevation. `light_strength` lets the sky light the scene less than it shows."""
    world = bpy.context.scene.world
    nt = world.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    bg = nt.nodes.new("ShaderNodeBackground")
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    remap = nt.nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -0.15
    remap.inputs["From Max"].default_value = 0.75
    nt.links.new(sep.outputs["Z"], remap.inputs["Value"])
    nt.links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*hex_rgb(glow), 1)
    els[1].position, els[1].color = 1.0, (*hex_rgb(top), 1)
    e = els.new(0.2)
    e.color = (*hex_rgb(horizon), 1)
    e = els.new(0.5)
    e.color = (*hex_rgb(middle), 1)
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength
    if light_strength is None:
        nt.links.new(bg.outputs[0], out.inputs["Surface"])
    else:
        # Camera rays see the full sky, everything else gets a dimmer version.
        lp = nt.nodes.new("ShaderNodeLightPath")
        bg2 = nt.nodes.new("ShaderNodeBackground")
        nt.links.new(ramp.outputs["Color"], bg2.inputs["Color"])
        bg2.inputs["Strength"].default_value = light_strength
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
        nt.links.new(bg2.outputs[0], mix.inputs[1])
        nt.links.new(bg.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])


def flat_world(color="#FFFFFF", strength=1.0):
    nt = bpy.context.scene.world.node_tree
    nt.nodes["Background"].inputs["Color"].default_value = (*hex_rgb(color), 1)
    nt.nodes["Background"].inputs["Strength"].default_value = strength


def glare(threshold=1.0, size=7, mix=0.0, streaks=False):
    """Soft bloom on bright things (neon, sparkles, highlights)."""
    scene = bpy.context.scene
    scene.use_nodes = True
    nt = scene.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new("CompositorNodeRLayers")
    comp = nt.nodes.new("CompositorNodeComposite")
    g = nt.nodes.new("CompositorNodeGlare")
    g.glare_type = "FOG_GLOW"
    g.quality = "HIGH"
    g.threshold = threshold
    g.size = size
    g.mix = mix
    nt.links.new(rl.outputs["Image"], g.inputs["Image"])
    last = g
    if streaks:
        s = nt.nodes.new("CompositorNodeGlare")
        s.glare_type = "STREAKS"
        s.quality = "HIGH"
        s.streaks = 4
        s.angle_offset = math.radians(45)
        s.threshold = threshold * 2.5
        s.fade = 0.88
        s.mix = -0.6
        nt.links.new(g.outputs["Image"], s.inputs["Image"])
        last = s
    nt.links.new(last.outputs["Image"], comp.inputs["Image"])
    if "Alpha" in rl.outputs and "Alpha" in comp.inputs:
        nt.links.new(rl.outputs["Alpha"], comp.inputs["Alpha"])


def camera(location, target, lens=35, focus=None, fstop=None, shift=(0, 0)):
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.data.lens = lens
    cam.data.clip_end = 2000
    cam.data.shift_x, cam.data.shift_y = shift
    cam.location = Vector(location)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    if focus is not None:
        cam.data.dof.use_dof = True
        cam.data.dof.focus_distance = (Vector(focus) - cam.location).length
        cam.data.dof.aperture_fstop = fstop or 2.8
    return cam


def light(kind, location, energy, color="#FFFFFF", target=None, size=1.0, angle=None, name=None):
    data = bpy.data.lights.new(name or kind, kind)
    data.energy = energy
    data.color = hex_rgb(color)
    if kind == "AREA":
        data.size = size
    elif kind in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    elif kind == "SUN":
        data.angle = math.radians(angle or 3)
    if kind == "SPOT" and angle is not None:
        data.spot_size = math.radians(angle)
        data.spot_blend = 0.4
    obj = bpy.data.objects.new(name or kind, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(location)
    if target is not None:
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("Rendered", path)


# ---------------------------------------------------------------------------------------------
# Materials

_materials = {}


def material(color, kind="SmoothPlastic", transparency=0.0, emission=None):
    """A material in the game's style. `color` is linear RGB or a hex string."""
    if isinstance(color, str):
        color = hex_rgb(color)
    key = (tuple(round(c, 3) for c in color), kind, round(transparency, 2), emission)
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new(f"{kind}_{len(_materials)}")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    out = nt.nodes["Material Output"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    if kind == "Neon" and transparency > 0:
        # Glowing see-through beams: add light, block nothing.
        nt.nodes.remove(bsdf)
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = (emission or 3.0) * (1 - transparency)
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        add = nt.nodes.new("ShaderNodeAddShader")
        nt.links.new(em.outputs[0], add.inputs[0])
        nt.links.new(tr.outputs[0], add.inputs[1])
        nt.links.new(add.outputs[0], out.inputs["Surface"])
    elif kind == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission or 3.0
        bsdf.inputs["Roughness"].default_value = 0.4
    elif kind in ("Metal", "Foil", "DiamondPlate"):
        bsdf.inputs["Metallic"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.22 if kind != "Foil" else 0.12
    elif kind == "Glass":
        bsdf.inputs["Transmission Weight"].default_value = 1.0
        bsdf.inputs["Roughness"].default_value = 0.03
        bsdf.inputs["IOR"].default_value = 1.4
    elif kind in ("Fabric", "Grass", "Sand", "Ground"):
        bsdf.inputs["Roughness"].default_value = 0.85
        bsdf.inputs["Sheen Weight"].default_value = 0.4 if kind == "Fabric" else 0.0
    else:  # SmoothPlastic and friends: glossy toy plastic.
        bsdf.inputs["Roughness"].default_value = 0.38
        bsdf.inputs["Coat Weight"].default_value = 0.35
        bsdf.inputs["Coat Roughness"].default_value = 0.12
    if emission and kind != "Neon":
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emission
    if transparency > 0 and not (kind == "Neon"):
        bsdf.inputs["Alpha"].default_value = 1 - transparency * (0.6 if kind == "Glass" else 1.0)
    mat.diffuse_color = (*color, 1)
    _materials[key] = mat
    return mat


# ---------------------------------------------------------------------------------------------
# Meshes in Roblox part space (centred on the part, size in studs)


def _box_geom():
    v = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, f


def _wedge_geom():
    v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)]
    f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return v, f


def _corner_wedge_geom():
    # Roblox CornerWedgePart: full bottom, peak above the +X,-Z corner... close enough for props.
    v = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0.5, 0.5, -0.5)]
    f = [(0, 1, 2, 3), (0, 4, 1), (1, 4, 2), (2, 4, 3), (3, 4, 0)]
    return v, f


def _cylinder_geom(seg=24):
    v, f = [], []
    for x in (-0.5, 0.5):
        for i in range(seg):
            a = 2 * math.pi * i / seg
            v.append((x, 0.5 * math.cos(a), 0.5 * math.sin(a)))
    for i in range(seg):
        j = (i + 1) % seg
        f.append((i, j, seg + j, seg + i))
    f.append(tuple(range(seg - 1, -1, -1)))
    f.append(tuple(range(seg, 2 * seg)))
    return v, f


def _star_geom(points=5, inner=0.45):
    """A flat star facing -Z (Roblox front), filling the unit box."""
    v = []
    for z in (-0.5, 0.5):
        for i in range(points * 2):
            a = math.pi / 2 + math.pi * i / points
            r = 0.5 if i % 2 == 0 else 0.5 * inner
            v.append((r * math.cos(a), r * math.sin(a), z))
    n = points * 2
    f = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, j, n + j, n + i))
    return v, f


def _mesh(name, geom, size, smooth=False, sphere=False):
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    if sphere:
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=size / 2)
    else:
        verts, faces = geom
        vs = [bm.verts.new(Vector((v[0] * size[0], v[1] * size[1], v[2] * size[2]))) for v in verts]
        for face in faces:
            bm.faces.new([vs[i] for i in face])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = smooth or sphere
    return mesh


def part_object(p, collection, parent=None, bevel=0.07):
    shape = p.get("shape", "Block")
    sx, sy, sz = p["size"]
    if shape == "Ball":
        mesh = _mesh(p["name"], None, min(sx, sy, sz), sphere=True)
    elif shape == "Cylinder":
        # Roblox cylinders are round; our own face parts may ask for an oval ("oval": True).
        d = min(sy, sz)
        mesh = _mesh(p["name"], _cylinder_geom(), (sx, sy, sz) if p.get("oval") else (sx, d, d))
    elif shape == "Wedge":
        mesh = _mesh(p["name"], _wedge_geom(), (sx, sy, sz))
    elif shape == "CornerWedge":
        mesh = _mesh(p["name"], _corner_wedge_geom(), (sx, sy, sz))
    elif shape == "Star":  # not a Roblox shape: a flat star for our own decorations
        mesh = _mesh(p["name"], _star_geom(), (sx, sy, sz))
    else:
        mesh = _mesh(p["name"], _box_geom(), (sx, sy, sz))
    color = p.get("linear") or lin(p["color"])
    mesh.materials.append(material(color, p.get("material", "SmoothPlastic"), p.get("transparency", 0.0), p.get("emission")))
    obj = bpy.data.objects.new(p["name"], mesh)
    collection.objects.link(obj)
    c = p["cframe"]
    m = Matrix(((c[3], c[4], c[5], c[0]), (c[6], c[7], c[8], c[1]), (c[9], c[10], c[11], c[2]), (0, 0, 0, 1)))
    obj.matrix_world = ROBLOX_TO_BLENDER @ m
    if parent is not None:
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
    thin = min(sx, sy, sz)
    width = min(bevel, thin * 0.3)
    if width > 0.01 and shape != "Ball":
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = width
        mod.segments = 3 if shape != "Cylinder" else 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = False
    if shape == "Cylinder":
        # Smooth round sides, flat caps.
        for poly in obj.data.polygons:
            poly.use_smooth = len(poly.vertices) == 4
    return obj


# ---------------------------------------------------------------------------------------------
# Game models


def dump(scene, arg=None):
    """Run art/preview/dump.luau and return the part list (cached per run)."""
    os.makedirs(DUMPS, exist_ok=True)
    out = os.path.join(DUMPS, f"{scene}_{arg or 'all'}.json".replace(":", "_"))
    if not os.path.exists(out):
        lune = os.environ.get("LUNE") or shutil.which("lune")
        assert lune, "Lune is needed to read the game's models (set LUNE or put lune on PATH)"
        cmd = [lune, "run", "art/preview/dump.luau", scene, out] + ([arg] if arg else [])
        subprocess.run(cmd, cwd=REPO, check=True, capture_output=True)
    with open(out) as f:
        return json.load(f)


def import_parts(parts, name, location=(0, 0, 0), yaw=0.0, scale=1.0, bevel=0.07):
    """Make the parts under one empty. `yaw` turns the model in degrees (0 faces -Y)."""
    coll = bpy.context.scene.collection
    root = bpy.data.objects.new(name, None)
    coll.objects.link(root)
    for p in parts:
        part_object(p, coll, parent=root, bevel=bevel)
    root.location = Vector(location)
    root.rotation_euler = (0, 0, math.radians(yaw))
    root.scale = (scale, scale, scale)
    return root


def drop(parts, *names):
    return [p for p in parts if not any(p["name"].startswith(n) for n in names)]


def recolor(parts, name, hex_color, material_kind=None):
    for p in parts:
        if p["name"] == name:
            p["linear"] = hex_rgb(hex_color)
            if material_kind:
                p["material"] = material_kind
    return parts


def rotate_parts(parts, select, pivot, axis, degrees):
    """Turn the selected parts about a pivot, all in Roblox model space (Y up, front -Z)."""
    r = Matrix.Rotation(math.radians(degrees), 3, axis)
    pv = Vector(pivot)
    for p in parts:
        if not select(p):
            continue
        c = p["cframe"]
        pos = Vector(c[0:3])
        rot = Matrix(((c[3], c[4], c[5]), (c[6], c[7], c[8]), (c[9], c[10], c[11])))
        pos = pv + r @ (pos - pv)
        rot = r @ rot
        p["cframe"] = [pos.x, pos.y, pos.z, *rot[0], *rot[1], *rot[2]]
    return parts


def block(name, size, at, color, kind="SmoothPlastic", rot=None, transparency=0.0, emission=None, shape="Block"):
    """A new part in Roblox model space, for props and face tweaks."""
    r = rot or Matrix.Identity(3)
    return {
        "name": name,
        "shape": shape,
        "size": list(size),
        "cframe": [*at, *r[0], *r[1], *r[2]],
        "linear": hex_rgb(color) if isinstance(color, str) else color,
        "material": kind,
        "transparency": transparency,
        "emission": emission,
    }


def side(p):
    """+1 for the model's right side (Roblox +X), -1 for its left."""
    return 1 if p["cframe"][0] > 0 else -1


# ---------------------------------------------------------------------------------------------
# Props made here (not in the game)


def star_mesh(name, outer=1.0, inner=0.45, depth=0.25, points=5):
    """A puffy 5-point star, lying in the XZ plane (facing -Y)."""
    bm = bmesh.new()
    ring = []
    for i in range(points * 2):
        a = math.pi / 2 + math.pi * i / points
        r = outer if i % 2 == 0 else inner
        ring.append(bm.verts.new((r * math.cos(a), 0, r * math.sin(a))))
    face = bm.faces.new(ring)
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, depth, 0))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, -depth / 2, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def sparkle_mesh(name, size=1.0):
    """A flat 4-point twinkle (for glints and sparkles)."""
    bm = bmesh.new()
    pts = []
    for i in range(8):
        a = math.pi * i / 4
        r = size if i % 2 == 0 else size * 0.16
        pts.append(bm.verts.new((r * math.cos(a), 0, r * math.sin(a))))
    bm.faces.new(pts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return mesh


def add_object(name, mesh, mat, location, rotation=(0, 0, 0), scale=1.0, bevel=0.0):
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        mesh.materials.append(mat)
    obj.location = Vector(location)
    obj.rotation_euler = tuple(math.radians(r) for r in rotation)
    obj.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    return obj


def primitive(kind, name, location, size, mat, rotation=(0, 0, 0), bevel=0.0, segments=32):
    """kind: cube | cylinder | sphere | cone | torus. `size` is (x, y, z) dimensions."""
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add()
    elif kind == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=segments)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=segments // 2)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=segments, radius1=1, radius2=0)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_segments=segments, minor_segments=12)
    obj = bpy.context.active_object
    obj.name = name
    obj.location = Vector(location)
    obj.rotation_euler = tuple(math.radians(r) for r in rotation)
    obj.dimensions = size
    # Bake the size into the mesh so bevels and object-space patterns are in real units.
    obj.data.transform(Matrix.Diagonal((*obj.scale, 1.0)))
    obj.scale = (1, 1, 1)
    obj.data.materials.append(mat)
    if kind in ("sphere", "cylinder", "torus", "cone"):
        for p in obj.data.polygons:
            p.use_smooth = True
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    return obj


def beam(name, base, top, radius_base, radius_top, color, strength=2.0, falloff=True):
    """A glowing see-through light shaft (cone frustum) from `base` to `top`."""
    base, top = Vector(base), Vector(top)
    length = (top - base).length
    bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=radius_base, radius2=radius_top, depth=length, end_fill_type="NOTHING")
    obj = bpy.context.active_object
    obj.name = name
    obj.location = (base + top) / 2
    obj.rotation_euler = (top - base).to_track_quat("Z", "Y").to_euler()
    for p in obj.data.polygons:
        p.use_smooth = True
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*hex_rgb(color), 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    # Fade along the beam (generated Z runs 0 at the base to 1 at the top) and at grazing edges.
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    fade = nt.nodes.new("ShaderNodeMapRange")
    fade.inputs["From Min"].default_value = 0.0
    fade.inputs["From Max"].default_value = 1.0
    fade.inputs["To Min"].default_value = 1.0
    fade.inputs["To Max"].default_value = 0.0 if falloff else 1.0
    nt.links.new(sep.outputs["Z"], fade.inputs["Value"])
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    edge = nt.nodes.new("ShaderNodeMath")
    edge.operation = "SUBTRACT"
    edge.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs["Facing"], edge.inputs[1])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(fade.outputs["Result"], mul.inputs[0])
    nt.links.new(edge.outputs[0], mul.inputs[1])
    strength_node = nt.nodes.new("ShaderNodeMath")
    strength_node.operation = "MULTIPLY"
    strength_node.inputs[1].default_value = strength
    nt.links.new(mul.outputs[0], strength_node.inputs[0])
    nt.links.new(strength_node.outputs[0], em.inputs["Strength"])
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    obj.data.materials.append(mat)
    obj.visible_shadow = False
    obj.visible_diffuse = False
    obj.visible_glossy = False
    return obj


def confetti(count, center, spread, colors, seed=1, size=(0.5, 0.18, 0.9), emission=0.6):
    rnd = random.Random(seed)
    objs = []
    for i in range(count):
        c = colors[i % len(colors)]
        loc = Vector(center) + Vector((rnd.uniform(-1, 1) * spread[0], rnd.uniform(-1, 1) * spread[1], rnd.uniform(-1, 1) * spread[2]))
        obj = primitive("cube", f"Confetti{i}", loc, size, material(c, "SmoothPlastic", emission=emission), rotation=(rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)))
        objs.append(obj)
    return objs


# ---------------------------------------------------------------------------------------------
# Titles: chunky 3D text with a thick outline, like Roblox front-page art

FONTS = os.environ.get("STORE_FONTS", os.path.join(REPO, "art", "fonts"))


def font(name="LuckiestGuy.ttf"):
    return bpy.data.fonts.load(os.path.join(FONTS, name), check_existing=True)


def ramp_material(name, stops, axis="Y", coords="Generated", metallic=0.0, roughness=0.3, coat=0.6, emission=0.0):
    """Colour runs through `stops` [(position 0-1, hex)] along one axis of the object's box."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs[coords], sep.inputs[0])
    nt.links.new(sep.outputs[axis], ramp.inputs["Fac"])
    els = ramp.color_ramp.elements
    for i, (pos, hex_color) in enumerate(stops):
        e = els[i] if i < 2 else els.new(pos)
        e.position = pos
        e.color = (*hex_rgb(hex_color), 1)
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    if emission:
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*hex_rgb(stops[0][1]), 1)
    return mat


def text3d(body, size=1.0, font_name="LuckiestGuy.ttf", extrude=0.1, bevel=0.03, offset=0.0, spacing=1.0, mat=None, name=None):
    """Flat text object in its own XY plane (front is +Z), centred on its origin."""
    curve = bpy.data.curves.new(name or body, "FONT")
    curve.body = body
    curve.font = font(font_name)
    curve.size = size
    curve.extrude = extrude
    curve.bevel_depth = bevel
    curve.bevel_resolution = 4
    curve.offset = offset
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.space_character = spacing
    curve.resolution_u = 16
    obj = bpy.data.objects.new(name or body, curve)
    bpy.context.scene.collection.objects.link(obj)
    if mat is not None:
        curve.materials.append(mat)
    return obj


def _glyph_shape(body, size, font_name, spacing):
    """The words' outline as a shapely shape, in the text plane."""
    from shapely.geometry import Polygon
    from shapely.ops import unary_union

    flat = text3d(body, size, font_name, extrude=0.0, bevel=0.0, spacing=spacing, name=f"{body}_flat")
    mesh = bpy.data.meshes.new_from_object(flat.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    pieces = []
    for poly in mesh.polygons:
        pts = [tuple(mesh.vertices[i].co[:2]) for i in poly.vertices]
        pieces.append(Polygon(pts).buffer(0))
    bpy.data.objects.remove(flat)
    bpy.data.meshes.remove(mesh)
    return unary_union(pieces).buffer(size * 0.002)


def _slab(name, shape, z0, z1, mat, bevel=0.0):
    """Extrude a shapely shape between z0 and z1 (text-plane coordinates) into a mesh object."""
    from mathutils.geometry import tessellate_polygon

    bm = bmesh.new()
    polys = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
    for poly in polys:
        if poly.is_empty or poly.geom_type != "Polygon":
            continue
        rings = [list(poly.exterior.coords)[:-1]] + [list(r.coords)[:-1] for r in poly.interiors]
        tris = tessellate_polygon([[Vector((x, y, 0)) for x, y in ring] for ring in rings])
        flat = [pt for ring in rings for pt in ring]
        front = [bm.verts.new((x, y, z1)) for x, y in flat]
        back = [bm.verts.new((x, y, z0)) for x, y in flat]
        for a, b, c in tris:
            bm.faces.new((front[a], front[b], front[c]))
            bm.faces.new((back[c], back[b], back[a]))
        k = 0
        for ring in rings:
            n = len(ring)
            for i in range(n):
                j = (i + 1) % n
                f = bm.faces.new((back[k + i], back[k + j], front[k + j], front[k + i]))
                f.smooth = True
            k += n
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.set_sharp_from_angle(angle=math.radians(35))
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(50)
    return obj


def _bend(x, y, radius):
    """Map a point of flat words onto an arch of `radius` (the middle stays put)."""
    a = x / radius
    return (radius + y) * math.sin(a), (radius + y) * math.cos(a) - radius


def _bent_mesh_object(obj, radius):
    """Replace a text object with a mesh copy bent along an arch."""
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    for v in mesh.vertices:
        x, y = _bend(v.co.x, v.co.y, radius)
        v.co.x, v.co.y = x, y
    mesh.shade_smooth()
    mesh.set_sharp_from_angle(angle=math.radians(35))
    new = bpy.data.objects.new(obj.name, mesh)
    bpy.context.scene.collection.objects.link(new)
    new.location = obj.location
    bpy.data.objects.remove(obj)
    return new


def title(body, size, fill, outline, location=(0, 0, 0), rotation=(0, 0, 0), thickness=0.11, depth=0.45,
          font_name="LuckiestGuy.ttf", spacing=1.0, outline2=None, thickness2=0.05, arc=None):
    """Outlined 3D words standing up and facing -Y. `thickness` is the outline width and
    `depth` how far the outline block sticks out behind, both as a fraction of `size`.
    `outline2` adds a second, outer outline; `arc` bends the words along an arch of that
    radius. Returns the parent empty.

    Outlines are the letters grown with round corners (shapely buffer) and extruded, since
    Blender's own font offset and bevel make spikes at sharp inside corners."""
    import shapely
    from shapely.ops import transform

    root = bpy.data.objects.new(f"Title_{body}", None)
    bpy.context.scene.collection.objects.link(root)
    face = 0.05 * size
    fill_obj = text3d(body, size, font_name, extrude=face, bevel=0.022 * size, spacing=spacing, mat=fill, name=f"{body}_fill")
    fill_obj.data.bevel_resolution = 3
    if arc:
        fill_obj = _bent_mesh_object(fill_obj, arc)
    parts = [fill_obj]
    shape = _glyph_shape(body, size, font_name, spacing)
    layers = [(outline, thickness)]
    if outline2 is not None:
        layers.append((outline2, thickness + thickness2))
    front = face + 0.022 * size
    for i, (mat, grow) in enumerate(layers):
        z1 = front - 0.025 * size * (i + 1)
        grown = shape.buffer(grow * size, join_style="round", quad_segs=10)
        if arc:
            # Bend the outline before it is filled with triangles, so none of them fold over.
            grown = transform(lambda x, y, z=None: _bend(x, y, arc), shapely.segmentize(grown, 0.03 * size))
        parts.append(_slab(f"{body}_outline{i}", grown, z1 - depth * size, z1, mat, bevel=0.018 * size))
    for p in parts:
        p.parent = root
    root.location = Vector(location)
    root.rotation_euler = (math.radians(90 + rotation[0]), math.radians(rotation[1]), math.radians(rotation[2]))
    return root


def shape_title(name, shape, fill, outline, location=(0, 0, 0), rotation=(0, 0, 0), thickness=0.085, depth=0.4,
                outline2=None, thickness2=0.04):
    """Like title(), for a flat shapely shape (in the XY plane, about one unit tall) instead of words."""
    root = bpy.data.objects.new(f"Title_{name}", None)
    bpy.context.scene.collection.objects.link(root)
    face = 0.05
    parts = [_slab(f"{name}_fill", shape, -face, face, fill, bevel=0.03)]
    layers = [(outline, thickness)]
    if outline2 is not None:
        layers.append((outline2, thickness + thickness2))
    for i, (mat, grow) in enumerate(layers):
        z1 = face - 0.025 * (i + 1)
        grown = shape.buffer(grow, join_style="round", quad_segs=10)
        parts.append(_slab(f"{name}_outline{i}", grown, z1 - depth, z1, mat, bevel=0.018))
    for p in parts:
        p.parent = root
    root.location = Vector(location)
    root.rotation_euler = (math.radians(90 + rotation[0]), math.radians(rotation[1]), math.radians(rotation[2]))
    return root


# ---------------------------------------------------------------------------------------------
# Small props: dice, coins, cash, stars, sparkles


def _empty(name, location, rotation=(0, 0, 0), scale=1.0):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = Vector(location)
    e.rotation_euler = tuple(math.radians(r) for r in rotation)
    e.scale = (scale, scale, scale)
    return e


def _child(obj, parent):
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    return obj


PIPS = {
    1: [(0, 0)],
    2: [(-1, -1), (1, 1)],
    3: [(-1, -1), (0, 0), (1, 1)],
    4: [(-1, -1), (-1, 1), (1, -1), (1, 1)],
    5: [(-1, -1), (-1, 1), (0, 0), (1, -1), (1, 1)],
    6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)],
}


def die(name, location, rotation=(0, 0, 0), size=2.0, color="#FF5FD2", pip_color="#FFFFFF", top=6, front=5, right=4):
    """A rounded die. `top`, `front` (-Y) and `right` (+X) pick the faces you see."""
    root = _empty(name, location, rotation)
    body = primitive("cube", f"{name}_body", (0, 0, 0), (size, size, size), material(color))
    mod = body.modifiers.new("Bevel", "BEVEL")
    mod.width = size * 0.16
    mod.segments = 6
    for p in body.data.polygons:
        p.use_smooth = True
    _child(body, root)
    pip_mat = material(pip_color)
    faces = {
        top: (Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
        7 - top: (Vector((0, 0, -1)), Vector((1, 0, 0)), Vector((0, 1, 0))),
        front: (Vector((0, -1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
        7 - front: (Vector((0, 1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1))),
        right: (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
        7 - right: (Vector((-1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))),
    }
    for value, (n, u, v) in faces.items():
        for a, b in PIPS[value]:
            at = n * (size / 2 - size * 0.035) + u * (a * size * 0.27) + v * (b * size * 0.27)
            pip = primitive("sphere", f"{name}_pip", at, (size * 0.19, size * 0.19, size * 0.19), pip_mat, segments=16)
            _child(pip, root)
    return root


def coin(name, location, rotation=(0, 0, 0), radius=0.7, mat=None):
    """A chunky gold coin with a raised star, face towards -Y before rotation."""
    gold = mat or material("#F5B82E", "Metal", emission=0.2)
    root = _empty(name, location, rotation)
    disc = primitive("cylinder", f"{name}_disc", (0, 0, 0), (radius * 2, radius * 2, radius * 0.32), gold, rotation=(90, 0, 0), segments=40)
    for p in disc.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    mod = disc.modifiers.new("Bevel", "BEVEL")
    mod.width = radius * 0.08
    mod.segments = 3
    _child(disc, root)
    for sgn in (-1, 1):
        star = add_object(f"{name}_star", star_mesh(f"{name}_star", radius * 0.55, radius * 0.25, radius * 0.1), material("#FFD45A", "Metal", emission=0.3),
                          (0, sgn * radius * 0.17, 0), bevel=radius * 0.02)
        _child(star, root)
    return root


def cash(name, location, rotation=(0, 0, 0), length=1.6):
    """A green banknote with a dollar sign."""
    root = _empty(name, location, rotation)
    w, h = length, length * 0.46
    note = primitive("cube", f"{name}_note", (0, 0, 0), (w, length * 0.02, h), material("#4FB548"))
    _child(note, root)
    panel = primitive("cube", f"{name}_panel", (0, 0, 0), (w * 0.82, length * 0.024, h * 0.72), material("#8FDB7E"))
    _child(panel, root)
    for sgn in (-1, 1):
        mark = text3d("$", size=h * 0.75, extrude=length * 0.004, mat=material("#2E7D32"), name=f"{name}_mark")
        mark.location = (0, sgn * length * 0.016, 0)
        mark.rotation_euler = (math.radians(90 * -sgn), 0, 0 if sgn < 0 else math.pi)
        _child(mark, root)
    return root


def gold_star(name, location, rotation=(0, 0, 0), size=1.0, color="#F5B82E", emission=0.0):
    obj = add_object(name, star_mesh(name, size, size * 0.46, size * 0.36), material(color, "Metal", emission=emission or None),
                     location, rotation, bevel=size * 0.08)
    obj.modifiers["Bevel"].segments = 3
    return obj


def sparkle(name, location, size=1.0, color="#FFFFFF", strength=12.0, face=None):
    mat = bpy.data.materials.get(f"Sparkle_{color}_{strength}")
    if mat is None:
        mat = bpy.data.materials.new(f"Sparkle_{color}_{strength}")
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.remove(nt.nodes["Principled BSDF"])
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*hex_rgb(color), 1)
        em.inputs["Strength"].default_value = strength
        nt.links.new(em.outputs[0], nt.nodes["Material Output"].inputs["Surface"])
    obj = add_object(name, sparkle_mesh(name, size), mat, location)
    obj.visible_shadow = False
    if face is not None:
        c = obj.constraints.new("DAMPED_TRACK")
        c.target = face
        c.track_axis = "TRACK_NEGATIVE_Y"
    return obj


# ---------------------------------------------------------------------------------------------
# The player: the Nervous Intern restyled as a plain player, with a shocked face and pose

HEAD_PARTS = ("Head", "Hair", "HairBack", "Fringe", "Spike", "Blush", "Sclera", "Pupil", "Shine", "Brow", "MouthOpen", "Tongue", "Teeth",
              "Frown", "Tear", "Shades", "Glint")


def _face_part(name, size, at, color, oval=True, emission=None, rot_z=0.0):
    """A face piece on the front of the head (Roblox space, front is -Z)."""
    r = Matrix.Rotation(math.radians(90), 3, "Y")  # cylinder axis X -> facing out of the face
    if rot_z:
        r = Matrix.Rotation(math.radians(rot_z), 3, "Z") @ r
    p = block(name, size, at, color, shape="Cylinder" if oval else "Block", rot=r if oval else Matrix.Rotation(math.radians(rot_z), 3, "Z"), emission=emission)
    p["oval"] = oval
    return p


DARK = "#1A1420"
BROW = "#3E2412"


def _eyes(look, size=(0.56, 0.46), y=4.82, brow_y=5.19, brow_tilt=-12):
    parts = []
    for sx in (1, -1):
        parts.append(_face_part("Sclera", (0.06, *size), (sx * 0.38, y, -0.77), "#FFFFFF"))
        px, py = sx * 0.38 + look[0], y + 0.02 + look[1]
        parts.append(_face_part("Pupil", (0.05, size[0] * 0.54, size[1] * 0.52), (px, py, -0.805), DARK))
        parts.append(_face_part("Shine", (0.03, 0.10, 0.10), (px + 0.05, py + 0.07, -0.83), "#FFFFFF", emission=0.6))
        parts.append(_face_part("Brow", (0.44, 0.09, 0.07), (sx * 0.38, brow_y, -0.77), BROW, oval=False, rot_z=brow_tilt * sx))
    return parts


def _shocked(look, mouth):
    mh = 0.44 * mouth
    return _eyes(look) + [
        _face_part("MouthOpen", (0.06, mh, 0.50), (0, 4.22, -0.77), "#3A0F1E"),
        _face_part("Tongue", (0.05, 0.16 * mouth, 0.32), (0, 4.22 - mh * 0.32, -0.795), "#F0607A"),
        _face_part("Teeth", (0.34, 0.08, 0.04), (0, 4.22 + mh * 0.36, -0.79), "#FFFFFF", oval=False),
    ]


def _sad(look, mouth):
    return _eyes((look[0], look[1] - 0.07), size=(0.44, 0.40), y=4.78, brow_y=5.08, brow_tilt=-26) + [
        _face_part("Frown", (0.30, 0.09, 0.06), (0, 4.24, -0.775), "#3A0F1E", oval=False),
        _face_part("Frown", (0.16, 0.09, 0.06), (0.21, 4.19, -0.775), "#3A0F1E", oval=False, rot_z=-28),
        _face_part("Frown", (0.16, 0.09, 0.06), (-0.21, 4.19, -0.775), "#3A0F1E", oval=False, rot_z=28),
        block("Tear", (0.2, 0.2, 0.2), (0.27, 4.47, -0.82), "#7CCBFF", emission=0.25, shape="Ball"),
    ]


def _cool(look, mouth):
    parts = []
    for sx in (1, -1):
        parts.append(_face_part("Shades", (0.64, 0.40, 0.08), (sx * 0.37, 4.84, -0.80), "#121218", oval=False))
    parts.append(_face_part("Shades", (0.30, 0.08, 0.06), (0, 4.95, -0.80), "#121218", oval=False))
    parts.append(_face_part("Glint", (0.07, 0.26, 0.02), (0.50, 4.86, -0.846), "#FFFFFF", oval=False, emission=1.5, rot_z=-35))
    parts.append(_face_part("Brow", (0.44, 0.09, 0.07), (0.38, 5.22, -0.77), BROW, oval=False, rot_z=8))
    parts.append(_face_part("Brow", (0.44, 0.09, 0.07), (-0.38, 5.15, -0.77), BROW, oval=False, rot_z=-4))
    parts.append(_face_part("MouthOpen", (0.06, 0.28, 0.66), (0, 4.24, -0.77), "#3A0F1E"))
    parts.append(_face_part("Teeth", (0.56, 0.1, 0.04), (0, 4.31, -0.79), "#FFFFFF", oval=False))
    parts.append(_face_part("Tongue", (0.05, 0.1, 0.3), (0, 4.16, -0.795), "#F0607A"))
    return parts


FACES = {"shocked": _shocked, "sad": _sad, "cool": _cool}


def player(shirt="#2E86DE", pants="#1B2340", hair="#6B4226", look=(-0.07, 0.05), arms=((150, 22), (125, 14)),
           head_turn=12.0, head_tilt=8.0, lean=5.0, roll=0.0, mouth=1.0, expression="shocked"):
    """Parts for the player. `expression` is "shocked", "sad" or "cool" (sunglasses and a grin).
    `arms` is ((raise, splay) right, (raise, splay) left) in degrees, `look` shifts the pupils
    (x towards the player's right, y up)."""
    parts = dump("actor", "NervousIntern:Normal")
    parts = drop(parts, "Eye", "Mouth", "Glasses", "Lanyard", "Coffee", "Clip", "Paper", "Clipboard", "Tie")
    for p in parts:
        n = p["name"]
        if n in ("Torso", "Arm"):
            p["linear"] = hex_rgb(shirt)
        elif n == "Leg":
            p["linear"] = hex_rgb(pants)
        elif n in ("Hair", "HairBack", "Spike", "Fringe"):
            p["linear"] = hex_rgb(hair)
        if n == "Fringe":
            c = p["cframe"]
            p["cframe"] = [c[0], 5.40, c[2], *c[3:]]
            p["size"] = [p["size"][0], 0.22, p["size"][2]]
    parts.append(block("ShirtStar", (0.8, 0.8, 0.1), (0, 3.02, -0.52), "#FFD23F", emission=0.2, shape="Star"))
    parts += FACES[expression](look, mouth)
    is_head = lambda p: p["name"] in HEAD_PARTS  # noqa: E731
    neck = (0, 3.9, 0)
    rotate_parts(parts, is_head, neck, "Y", head_turn)
    rotate_parts(parts, is_head, neck, "X", head_tilt)
    for sx, (lift, splay) in zip((1, -1), arms):
        on_side = lambda p, sx=sx: p["name"] in ("Arm", "Hand") and side(p) == sx  # noqa: E731
        shoulder = (sx * 1.45, 3.75, 0)
        rotate_parts(parts, on_side, shoulder, "X", lift)
        rotate_parts(parts, on_side, shoulder, "Z", -splay * sx)
    rotate_parts(parts, lambda p: True, (0, 0, 0), "X", lean)
    rotate_parts(parts, lambda p: True, (0, 0, 0), "Z", roll)
    return parts


# ---------------------------------------------------------------------------------------------
# Light linking: keep the subjects bright and the background moody


class collect:
    """`with collect() as c: ...` then `c.objects` lists the objects made inside the block."""

    def __enter__(self):
        self._before = set(bpy.data.objects)
        self.objects = []
        return self

    def __exit__(self, *exc):
        self.objects = [o for o in bpy.data.objects if o not in self._before]


def light_only(light_obj, objects, name=None):
    """Make a light shine only on `objects` (Cycles light linking)."""
    coll = bpy.data.collections.new(name or f"{light_obj.name}_receivers")
    for o in objects:
        if o.type in ("MESH", "CURVE", "FONT"):
            coll.objects.link(o)
    light_obj.light_linking.receiver_collection = coll
    return coll


def glow_disc(name, center, radius, color, strength=2.0, facing=None, power=2.0):
    """A soft round glow (bright middle fading to nothing), seen only by the camera."""
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=radius, fill_type="TRIFAN")
    obj = bpy.context.active_object
    obj.name = name
    obj.location = Vector(center)
    if facing is not None:
        obj.rotation_euler = (Vector(facing) - obj.location).to_track_quat("Z", "Y").to_euler()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    dist = nt.nodes.new("ShaderNodeVectorMath")
    dist.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], dist.inputs[0])
    norm = nt.nodes.new("ShaderNodeMath")
    norm.operation = "DIVIDE"
    norm.inputs[1].default_value = radius
    nt.links.new(dist.outputs["Value"], norm.inputs[0])
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    inv.use_clamp = True
    nt.links.new(norm.outputs[0], inv.inputs[1])
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = power
    nt.links.new(inv.outputs[0], pw.inputs[0])
    amount = nt.nodes.new("ShaderNodeMath")
    amount.operation = "MULTIPLY"
    amount.inputs[1].default_value = strength
    nt.links.new(pw.outputs[0], amount.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*hex_rgb(color), 1)
    nt.links.new(amount.outputs[0], em.inputs["Strength"])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    nt.links.new(tr.outputs[0], add.inputs[0])
    nt.links.new(em.outputs[0], add.inputs[1])
    nt.links.new(add.outputs[0], out.inputs["Surface"])
    obj.data.materials.append(mat)
    obj.visible_shadow = False
    obj.visible_diffuse = False
    obj.visible_glossy = False
    obj.visible_transmission = False
    return obj
