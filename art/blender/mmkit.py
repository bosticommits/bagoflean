"""Shared helpers for the Movie Mogul Blender models (ART_STYLE.md section 12).

Each model script builds its mesh with these helpers, then calls `finish(obj, name)` which
bakes vertex colors, prints the triangle count and size, renders two preview PNGs into
art/previews/ and exports art/exports/<name>.fbx in studs.

Run any model script from the repo root, with Blender:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
      --python art/blender/palm_tree.py
or with the `bpy` Python package (Python 3.11, `pip install bpy`):
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" art/blender/palm_tree.py

Previews render with Cycles on the CPU, so they also work on machines without a GPU.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREVIEWS = os.path.join(REPO, "art", "previews")
EXPORTS = os.path.join(REPO, "art", "exports")

STUD = 0.28  # metres per stud

# ART_STYLE.md section 3, plus the supporting shades used by the part-built models.
PALETTE = {
    "Cream": "#F4E7CF",
    "Burgundy": "#7A1F2B",
    "Carpet": "#C8202F",
    "Gold": "#F5B82E",
    "Blue": "#2E86DE",
    "Navy": "#1B2340",
    "Green": "#5BBF5A",
    "DarkGreen": "#388C46",
    "Asphalt": "#8C8A86",
    "Charcoal": "#2E2C34",
    "Steel": "#6E7078",
    "Bark": "#7A5434",
    "Wood": "#96623C",
    "Light": "#FFECBE",
    "OffWhite": "#FAF6EC",
}


def studs(x):
    """Studs -> metres (Blender units)."""
    return x * STUD


def hex_to_linear(hex_color):
    hex_color = hex_color.lstrip("#")
    srgb = [int(hex_color[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, 1.0)


class Model:
    """A bmesh plus a material list. Shapes take sizes and positions in studs."""

    def __init__(self, name):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.name = name
        self.bm = bmesh.new()
        self.materials = []
        self.index = {}

    def mat(self, color_name, metallic=0.0, roughness=0.5, emission=0.0):
        key = (color_name, metallic, emission)
        if key in self.index:
            return self.index[key]
        hex_color = PALETTE.get(color_name, color_name)
        mat = bpy.data.materials.new(f"Mat_{color_name.lstrip('#')}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = hex_to_linear(hex_color)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0:
            bsdf.inputs["Emission Color"].default_value = hex_to_linear(hex_color)
            bsdf.inputs["Emission Strength"].default_value = emission
        mat.diffuse_color = hex_to_linear(hex_color)
        self.materials.append(mat)
        self.index[key] = len(self.materials) - 1
        return self.index[key]

    def _add(self, verts, faces, mat, matrix):
        vs = [self.bm.verts.new(matrix @ Vector(v)) for v in verts]
        for f in faces:
            face = self.bm.faces.new([vs[i] for i in f])
            face.material_index = mat

    def box(self, size, at=(0, 0, 0), mat=0, matrix=None, taper=1.0):
        """Box in studs, centred on `at`. `taper` scales the top face (1 = plain box)."""
        sx, sy, sz = (studs(s) / 2 for s in size)
        verts = []
        for z in (-1, 1):
            k = taper if z > 0 else 1
            for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                verts.append((x * sx * k, y * sy * k, z * sz))
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        m = (matrix or Matrix.Identity(4)) @ Matrix.Translation(Vector([studs(c) for c in at]))
        self._add(verts, faces, mat, m)

    def lathe(self, profile, mat=0, segments=10, matrix=None):
        """Spin a [(radius, z), ...] profile (studs) around Z. Radius 0 makes a pole."""
        rings = []
        for r, z in profile:
            if r == 0:
                rings.append([(0, 0, studs(z))])
            else:
                rings.append(
                    [
                        (studs(r) * math.cos(a), studs(r) * math.sin(a), studs(z))
                        for a in (2 * math.pi * i / segments for i in range(segments))
                    ]
                )
        verts, faces, starts = [], [], []
        for ring in rings:
            starts.append(len(verts))
            verts.extend(ring)
        for k in range(len(rings) - 1):
            lo, hi = rings[k], rings[k + 1]
            a, b = starts[k], starts[k + 1]
            for i in range(segments):
                j = (i + 1) % segments
                if len(lo) == 1:
                    faces.append((a, b + i, b + j))
                elif len(hi) == 1:
                    faces.append((a + i, a + j, b))
                else:
                    faces.append((a + i, a + j, b + j, b + i))
        # Cap open ends.
        if len(rings[0]) > 1:
            faces.append(tuple(reversed(range(starts[0], starts[0] + segments))))
        if len(rings[-1]) > 1:
            faces.append(tuple(range(starts[-1], starts[-1] + segments)))
        self._add(verts, faces, mat, matrix or Matrix.Identity(4))

    def cylinder(self, radius, length, at=(0, 0, 0), mat=0, segments=10, matrix=None, axis="Z"):
        """Cylinder in studs centred on `at` with its axis along X, Y or Z."""
        rot = {"Z": Matrix.Identity(4), "X": Matrix.Rotation(math.pi / 2, 4, "Y"), "Y": Matrix.Rotation(math.pi / 2, 4, "X")}[axis]
        m = (matrix or Matrix.Identity(4)) @ Matrix.Translation(Vector([studs(c) for c in at])) @ rot
        self.lathe([(radius, -length / 2), (radius, length / 2)], mat, segments, m)

    def obj(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in self.materials:
            mesh.materials.append(mat)
        for poly in mesh.polygons:
            poly.use_smooth = False
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def bake_vertex_colors(mesh):
    """Roblox ignores solid-color FBX materials, so copy each face's material color into
    vertex colors (shown on a MeshPart whose Color is white)."""
    colors = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly in mesh.polygons:
        color = mesh.materials[poly.material_index].diffuse_color
        for loop in poly.loop_indices:
            colors.data[loop].color = color


def _setup_scene(height):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = hex_to_linear("#BFD9F2")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.95, 0.85)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    floor = bpy.data.objects.new("Floor", bpy.data.meshes.new("Floor"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=max(2.0, height * 3))
    fb.to_mesh(floor.data)
    fb.free()
    fmat = bpy.data.materials.new("Mat_Floor")
    fmat.use_nodes = True
    fmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = hex_to_linear("#F4E7CF")
    floor.data.materials.append(fmat)
    scene.collection.objects.link(floor)
    cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    cam.data.lens = 60
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.image_settings.file_format = "PNG"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.view_settings.view_transform = "Standard"
    return cam


def _render_view(cam, name, view, azimuth_deg, elevation_deg, size):
    height = size.z
    radius = max(size.x, size.y, size.z) * 0.62
    target = Vector((0, 0, height / 2))
    az, el = math.radians(azimuth_deg), math.radians(elevation_deg)
    distance = radius / math.tan(cam.data.angle / 2) * 1.15
    # Azimuth 0 looks from -Y (the model's front).
    cam.location = target + distance * Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(PREVIEWS, f"{name}_{view}.png")
    bpy.ops.render.render(write_still=True)


def _export(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(EXPORTS, f"{name}.fbx"),
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


def finish(obj, file_name, max_tris=2000):
    """Bake colors, check the budget, render previews and export the FBX."""
    os.makedirs(PREVIEWS, exist_ok=True)
    os.makedirs(EXPORTS, exist_ok=True)
    bake_vertex_colors(obj.data)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    xs, ys, zs = zip(*(obj.matrix_world @ Vector(c) for c in obj.bound_box))
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    print(
        f"{obj.name}: {tris} tris, {size.x / STUD:.1f} x {size.y / STUD:.1f} x {size.z / STUD:.1f} studs, "
        f"min z {min(zs) / STUD:.2f}"
    )
    assert tris <= max_tris, f"{obj.name} is over its {max_tris} triangle budget"
    cam = _setup_scene(size.z)
    _render_view(cam, file_name, "front", 0, 12, size)
    _render_view(cam, file_name, "34", 40, 25, size)
    _export(obj, file_name)
    print("Exported", os.path.join(EXPORTS, f"{file_name}.fbx"))
