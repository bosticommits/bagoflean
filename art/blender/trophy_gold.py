"""Trophy_Gold: small award trophy for the lot's trophy shelf.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
      --python art/blender/trophy_gold.py

Writes art/previews/trophy_gold_front.png, art/previews/trophy_gold_34.png
and art/exports/trophy_gold.fbx. Style rules: ART_STYLE.md section 12.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREVIEWS = os.path.join(REPO, "art", "previews")
EXPORTS = os.path.join(REPO, "art", "exports")

STUD = 0.28  # metres per stud
HEIGHT = 2.0 * STUD  # trophy is about 2 studs tall
SEGMENTS = 12  # low poly round parts


def hex_to_linear(hex_color):
    hex_color = hex_color.lstrip("#")
    srgb = [int(hex_color[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


def make_material(name, hex_color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hex_to_linear(hex_color)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = hex_to_linear(hex_color)
    return mat


def bake_vertex_colors(mesh):
    """Roblox ignores solid-color FBX materials, so copy each face's material color into
    vertex colors (shown on a MeshPart whose Color is white)."""
    colors = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in mesh.polygons:
        color = mesh.materials[poly.material_index].diffuse_color
        for loop in poly.loop_indices:
            colors.data[loop].color = color


def lathe(bm, profile, mat_index):
    """Spin a (radius, z) profile around Z. Radius 0 points become single poles."""
    rings = []
    for r, z in profile:
        if r == 0:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append(
                [
                    bm.verts.new((r * math.cos(a), r * math.sin(a), z))
                    for a in (2 * math.pi * i / SEGMENTS for i in range(SEGMENTS))
                ]
            )
    for lower, upper in zip(rings, rings[1:]):
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            if len(lower) == 1:
                verts = (lower[0], upper[j], upper[i])
            elif len(upper) == 1:
                verts = (lower[i], lower[j], upper[0])
            else:
                verts = (lower[i], lower[j], upper[j], upper[i])
            bm.faces.new(verts).material_index = mat_index


def box(bm, center, size, mat_index):
    cx, cy, cz = center
    sx, sy, sz = (s / 2 for s in size)
    v = [
        bm.verts.new((cx + x * sx, cy + y * sy, cz + z * sz))
        for x in (-1, 1)
        for y in (-1, 1)
        for z in (-1, 1)
    ]
    for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([v[i] for i in idx]).material_index = mat_index


def handle(bm, side, mat_index):
    """Chunky C-shaped handle on the +X (side=1) or -X (side=-1) of the cup."""
    major, minor = 0.055, 0.016
    cx, cz = side * 0.125, 0.42
    arc = [math.radians(a) for a in range(-100, 101, 25)]  # open toward the cup
    rings = []
    for a in arc:
        center = Vector((cx + side * major * math.cos(a), 0, cz + major * math.sin(a)))
        out = Vector((side * math.cos(a), 0, math.sin(a)))
        rings.append(
            [
                bm.verts.new(center + minor * (math.cos(b) * out + math.sin(b) * Vector((0, 1, 0))))
                for b in (2 * math.pi * k / 6 for k in range(6))
            ]
        )
    for lower, upper in zip(rings, rings[1:]):
        for k in range(6):
            n = (k + 1) % 6
            bm.faces.new((lower[k], lower[n], upper[n], upper[k])).material_index = mat_index
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring).material_index = mat_index


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    gold = make_material("Mat_AwardGold", "#F5B82E", metallic=0.35, roughness=0.35)
    burgundy = make_material("Mat_StudioTrim", "#7A1F2B", metallic=0.0, roughness=0.5)
    cream = make_material("Mat_WarmCream", "#F4E7CF", metallic=0.0, roughness=0.5)

    bm = bmesh.new()
    # Plinth: two chunky burgundy steps.
    box(bm, (0, 0, 0.035), (0.26, 0.26, 0.07), 1)
    box(bm, (0, 0, 0.09), (0.2, 0.2, 0.04), 1)
    # Name plate on the front (-Y) so the facing is obvious.
    box(bm, (0, -0.131, 0.035), (0.14, 0.006, 0.04), 2)
    # Gold stem, knot and cup as one lathed shape (outer wall up, inner wall down).
    lathe(
        bm,
        [
            (0, 0.11),
            (0.07, 0.11),
            (0.07, 0.13),
            (0.03, 0.15),
            (0.025, 0.2),
            (0.045, 0.22),
            (0.025, 0.24),
            (0.04, 0.27),
            (0.1, 0.32),
            (0.13, 0.4),
            (0.145, 0.5),
            (0.155, 0.535),
            (0.155, HEIGHT),
            (0.13, HEIGHT),
            (0.12, 0.5),
            (0.1, 0.41),
            (0, 0.37),
        ],
        0,
    )
    handle(bm, 1, 0)
    handle(bm, -1, 0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new("Trophy_Gold")
    bm.to_mesh(mesh)
    bm.free()
    for mat in (gold, burgundy, cream):
        mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = False
    bake_vertex_colors(mesh)

    obj = bpy.data.objects.new("Trophy_Gold", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def setup_scene():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hex_to_linear("#BFD9F2")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world

    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.95, 0.85)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)

    floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=2)
    fb.to_mesh(floor.data)
    fb.free()
    floor.data.materials.append(make_material("Mat_Floor", "#F4E7CF", 0, 0.8))
    scene.collection.objects.link(floor)

    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 70
    scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.image_settings.file_format = "PNG"
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = next(e for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH") if e in engines)
    if hasattr(scene, "view_settings"):
        scene.view_settings.view_transform = "Standard"
    return cam


def render_view(cam, name, azimuth_deg, elevation_deg, distance=1.9):
    target = Vector((0, 0, HEIGHT / 2))
    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    # Azimuth 0 looks from -Y (the model's front).
    cam.location = target + distance * Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(PREVIEWS, f"trophy_gold_{name}.png")
    bpy.ops.render.render(write_still=True)


def export(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORTS, "trophy_gold.fbx"),
        use_selection=True,
        # Roblox reads FBX units (cm) as studs, so write the model in studs.
        global_scale=1 / (STUD * 100),
        apply_unit_scale=True,
        bake_space_transform=True,
        colors_type="SRGB",
        axis_forward="-Y",
        axis_up="Z",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
    )


def main():
    os.makedirs(PREVIEWS, exist_ok=True)
    os.makedirs(EXPORTS, exist_ok=True)
    obj = build()
    xs, ys, zs = zip(*(obj.matrix_world @ Vector(c) for c in obj.bound_box))
    print(
        f"Trophy_Gold: {triangle_count(obj)} tris, "
        f"size {max(xs) - min(xs):.3f} x {max(ys) - min(ys):.3f} x {max(zs) - min(zs):.3f} m "
        f"({(max(zs) - min(zs)) / STUD:.2f} studs tall), min z {min(zs):.3f}"
    )
    cam = setup_scene()
    render_view(cam, "front", 0, 12)
    render_view(cam, "34", 40, 25)
    export(obj)
    print("Engine:", bpy.context.scene.render.engine)
    print("Done:", os.path.join(EXPORTS, "trophy_gold.fbx"))


main()
