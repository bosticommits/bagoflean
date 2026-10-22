"""Mystery Crate: the special event's loot crate, in two meshes so the lid can flip open.

  mystery_crate.fbx      the box, 5 x 4.4 x 5 studs, bottom centre at the origin
  mystery_crate_lid.fbx  the lid with its gold star, bottom centre at the origin
  crate_parachute.fbx    its red and white parachute canopy, 15 studs across, rim at the origin

A purple crate with a gold frame, chunky gold corners and rivets, and a big gold "?" with a dark
outline on every side, like the mystery boxes on Roblox's front page. In Studio, name the
MeshParts "MysteryCrate", "MysteryCrateLid" and "CrateParachute" (art/README.md). Until they are imported the
game builds a part version with the same look (src/shared/Models/EventModels.luau).

Also renders art/previews/mystery_crate_open.png, the two together with the lid open.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402

FONT = os.path.join(mmkit.REPO, "art", "fonts", "LuckiestGuy.ttf")

SIZE = 5.0  # crate width (studs), as EventModels' CRATE
HEIGHT = 4.4  # box height; the lid sits on top
LID = 0.7  # lid slab thickness

COLORS = {
    "Violet": "#A04DFF",  # the game's event purple
    "VioletLight": "#B46BFF",
    "VioletDark": "#5B2BB5",
    "VioletDeep": "#3A1D78",
    "Gold": "#F5B82E",
    "GoldLight": "#FFD447",
    "GoldDark": "#C98A12",
    "Ink": "#1B1240",
}


def mats(m):
    return {name: m.mat(hex_color, metallic=0.3 if "Gold" in name else 0.0) for name, hex_color in COLORS.items()}


def T(x, y, z):
    return Matrix.Translation(Vector((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z))))


def rbox(m, size, at, mat, bevel=0.12, segments=1, matrix=None):
    """Box in studs centred on `at`, with its edges bevelled (chamfered at one segment)."""
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.scale(tmp, vec=Vector([mmkit.studs(s) for s in size]), verts=tmp.verts)
    if bevel > 0:
        bmesh.ops.bevel(
            tmp, geom=list(tmp.edges), offset=mmkit.studs(bevel), segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True
        )
    _merge(m, tmp, mat, (matrix or Matrix.Identity(4)) @ T(*at))


def _merge(m, tmp, mat, matrix):
    vs = {v: m.bm.verts.new(matrix @ v.co) for v in tmp.verts}
    for f in tmp.faces:
        face = m.bm.faces.new([vs[v] for v in f.verts])
        face.material_index = mat
    tmp.free()


def slab(m, shape, z0, z1, mat, matrix):
    """Extrude a flat shapely shape (studs, its own XY plane) between z0 and z1 along its Z."""
    tmp = bmesh.new()
    polys = list(shape.geoms) if hasattr(shape, "geoms") else [shape]
    for poly in polys:
        if poly.is_empty or poly.geom_type != "Polygon":
            continue
        rings = [list(poly.exterior.coords)[:-1]] + [list(r.coords)[:-1] for r in poly.interiors]
        tris = tessellate_polygon([[Vector((x, y, 0)) for x, y in ring] for ring in rings])
        flat = [pt for ring in rings for pt in ring]
        front = [tmp.verts.new((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z1))) for x, y in flat]
        back = [tmp.verts.new((mmkit.studs(x), mmkit.studs(y), mmkit.studs(z0))) for x, y in flat]
        for a, b, c in tris:
            tmp.faces.new((front[a], front[b], front[c]))
            tmp.faces.new((back[c], back[b], back[a]))
        k = 0
        for ring in rings:
            n = len(ring)
            for i in range(n):
                j = (i + 1) % n
                tmp.faces.new((back[k + i], back[k + j], front[k + j], front[k + i]))
            k += n
    _merge(m, tmp, mat, matrix)


def glyph(char, height):
    """A letter of the game's title font as a shapely shape, `height` studs tall, centred."""
    from shapely import affinity
    from shapely.geometry import Polygon
    from shapely.ops import unary_union

    curve = bpy.data.curves.new("Glyph", "FONT")
    curve.body = char
    curve.font = bpy.data.fonts.load(FONT, check_existing=True)
    curve.resolution_u = 4  # few points along each curve keeps the triangle count low
    obj = bpy.data.objects.new("Glyph", curve)
    bpy.context.scene.collection.objects.link(obj)
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    shape = unary_union([Polygon([tuple(mesh.vertices[i].co[:2]) for i in p.vertices]).buffer(0) for p in mesh.polygons])
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(mesh)
    minx, miny, maxx, maxy = shape.bounds
    k = height / (maxy - miny)
    shape = affinity.scale(shape, k, k, origin=(0, 0))
    minx, miny, maxx, maxy = shape.bounds
    return affinity.translate(shape, -(minx + maxx) / 2, -(miny + maxy) / 2).simplify(0.02)


def star(outer, inner, points=5):
    from shapely.geometry import Polygon

    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.pi / 2 + i * math.pi / points
        pts.append((r * math.cos(a), r * math.sin(a)))
    return Polygon(pts)


def badge(m, shape, mat_fill, mat_ink, depth, outline, matrix):
    """A raised, outlined emblem: the shape on a dark slab grown round it (the menus' look)."""
    grown = shape.buffer(outline, join_style="round", quad_segs=3)
    slab(m, grown, 0, depth * 0.55, mat_ink, matrix)
    slab(m, shape, depth * 0.3, depth, mat_fill, matrix)


def rivet(m, at, mat, matrix=None, radius=0.17):
    m.lathe([(radius, 0), (radius * 0.75, 0.11), (0, 0.17)], mat, segments=6, matrix=(matrix or Matrix.Identity(4)) @ T(*at))


FACES = [  # rotations taking the -Y (front) face to each side
    Matrix.Identity(4),
    Matrix.Rotation(math.pi / 2, 4, "Z"),
    Matrix.Rotation(math.pi, 4, "Z"),
    Matrix.Rotation(-math.pi / 2, 4, "Z"),
]


def build_box(m):
    c = mats(m)
    half = SIZE / 2
    # Dark skid under the crate, and the dark core that shows between the planks.
    rbox(m, (SIZE + 0.1, SIZE + 0.1, 0.35), (0, 0, 0.175), c["VioletDeep"], bevel=0.1)
    # (Faces never lie flush with each other: flush faces flicker in Studio and go black in Cycles.)
    core = HEIGHT - 0.12
    rbox(m, (SIZE - 0.5, SIZE - 0.5, core - 0.3), (0, 0, 0.3 + (core - 0.3) / 2), c["VioletDeep"], bevel=0)
    # Gold bands round the bottom and top; the top one is a frame, so the open crate shows its
    # dark inside.
    rbox(m, (SIZE, SIZE, 0.4), (0, 0, 0.55), c["Gold"], bevel=0.12, segments=2)
    for face in FACES:
        rbox(m, (SIZE - 0.9, 0.45, 0.4), (0, -(SIZE / 2 - 0.225), HEIGHT - 0.2), c["Gold"], bevel=0.12, segments=2, matrix=face)
    q = glyph("?", 2.55)
    plank_from, plank_to = 0.8, HEIGHT - 0.42
    rows = 3
    gap = 0.14
    ph = (plank_to - plank_from - gap * (rows - 1)) / rows
    for r, face in enumerate(FACES):
        # Three planks across each side, alternating shades.
        for i in range(rows):
            z = plank_from + ph / 2 + i * (ph + gap)
            shade = c["Violet"] if (i + r) % 2 == 0 else c["VioletLight"]
            rbox(m, (SIZE - 1.3, 0.3, ph), (0, -(half - 0.25), z), shade, bevel=0.07, matrix=face)
        # The big "?" on the planks, gold with a dark outline.
        to_face = face @ T(0, -(half - 0.12), plank_from + (plank_to - plank_from) / 2) @ Matrix.Rotation(math.pi / 2, 4, "X")
        badge(m, q, c["GoldLight"], c["Ink"], 0.34, 0.16, to_face)
        # Rivets on the bands, either side of the "?".
        for x in (-1.5, 1.5):
            for z in (0.55, HEIGHT - 0.2):
                rivet(m, (0, 0, 0), c["GoldDark"], face @ T(x, -half, z) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    # Chunky gold corner posts with rivets.
    for sx in (-1, 1):
        for sy in (-1, 1):
            rbox(m, (0.85, 0.85, HEIGHT - 0.1), (sx * (half - 0.32), sy * (half - 0.32), (HEIGHT - 0.1) / 2 + 0.05), c["Gold"], bevel=0.16, segments=2)
            for z in (1.6, 2.9):
                rivet(m, (0, 0, 0), c["GoldDark"], T(sx * (half + 0.1), sy * (half - 0.32), z) @ Matrix.Rotation(sx * math.pi / 2, 4, "Y"))
                rivet(m, (0, 0, 0), c["GoldDark"], T(sx * (half - 0.32), sy * (half + 0.1), z) @ Matrix.Rotation(-sy * math.pi / 2, 4, "X"))
    return m.obj()


def build_lid(m):
    c = mats(m)
    w = SIZE + 0.4
    rbox(m, (w + 0.1, w + 0.1, 0.28), (0, 0, 0.14), c["Gold"], bevel=0.1, segments=2)
    rbox(m, (w, w, LID), (0, 0, 0.28 + LID / 2 - 0.05), c["Violet"], bevel=0.2, segments=2)
    top = 0.28 + LID - 0.05
    rbox(m, (w - 1.4, w - 1.4, 0.24), (0, 0, top + 0.08), c["VioletDark"], bevel=0.1)
    # Gold corner caps with a rivet each.
    for sx in (-1, 1):
        for sy in (-1, 1):
            at = (sx * (w / 2 - 0.45), sy * (w / 2 - 0.45))
            rbox(m, (1.0, 1.0, LID + 0.35), (at[0], at[1], (LID + 0.35) / 2 + 0.02), c["Gold"], bevel=0.16, segments=2)
            rivet(m, (at[0], at[1], LID + 0.37), c["GoldDark"])
    # A big gold star on top, outlined like the menus' icons.
    badge(m, star(1.75, 0.8), c["GoldLight"], c["Ink"], 0.5, 0.17, T(0, 0, top + 0.18) @ Matrix.Rotation(0, 4, "Z"))
    return m.obj()


def build_parachute(m):
    """A smooth dome of red and white panels, hollow underneath, with a scalloped rim."""
    red, white = m.mat("Carpet"), m.mat("OffWhite")
    seg = 16
    outer = [(7.5, 0), (7.3, 1.3), (6.6, 2.6), (5.3, 3.7), (3.4, 4.5), (1.2, 4.85)]
    inner = [(r - 0.2, z - 0.05) for r, z in outer]
    bm = m.bm

    def ring(profile_point, a, sag=0.0):
        r, z = profile_point
        return Vector((mmkit.studs(r * math.cos(a)), mmkit.studs(r * math.sin(a)), mmkit.studs(z + sag)))

    def surface(profile, flip):
        rows = []
        for k, pt in enumerate(profile):
            row = []
            for i in range(seg * 2):
                a = math.pi * i / seg
                # Each panel's rim bows up a little between the lines: the scalloped edge.
                sag = 0.35 if (k == 0 and i % 2 == 1) else 0.0
                row.append(bm.verts.new(ring(pt, a, sag)))
            rows.append(row)
        for k in range(len(rows) - 1):
            for i in range(seg * 2):
                j = (i + 1) % (seg * 2)
                quad = [rows[k][i], rows[k][j], rows[k + 1][j], rows[k + 1][i]]
                f = bm.faces.new(list(reversed(quad)) if flip else quad)
                f.material_index = red if (i // 2) % 2 == 0 else white
        return rows

    out_rows = surface(outer, False)
    in_rows = surface(inner, True)
    n = seg * 2
    for i in range(n):
        j = (i + 1) % n
        f = bm.faces.new([out_rows[0][i], in_rows[0][i], in_rows[0][j], out_rows[0][j]])
        f.material_index = red if (i // 2) % 2 == 0 else white
    # The vent at the top: a white cap closing the dome.
    top_out, top_in = out_rows[-1], in_rows[-1]
    bm.faces.new(top_out).material_index = white
    bm.faces.new(list(reversed(top_in))).material_index = white
    m.lathe([(1.5, 4.7), (1.5, 5.0), (0, 5.15)], white, segments=12)
    obj = m.obj()
    # recalc_face_normals in obj() can't tell the shell's inside from outside; that is fine for
    # a MeshPart (Roblox draws both sides only if DoubleSided, so the inner wall is real geometry).
    return obj


def preview_open():
    """Box and lid together with the lid flipped open, rendered a little nicer for Bosti."""
    box = build_box(mmkit.Model("MysteryCrate"))
    lm = mmkit.Model.__new__(mmkit.Model)  # second model in the same scene (no factory reset)
    lm.name, lm.bm, lm.materials, lm.index = "MysteryCrateLid", bmesh.new(), [], {}
    lid = build_lid(lm)
    for o in (box, lid):
        mmkit.bake_vertex_colors(o.data)
    hinge = Vector((0, mmkit.studs(SIZE / 2 + 0.2), mmkit.studs(HEIGHT)))
    lid.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(-110), 4, "X") @ Matrix.Translation(-hinge) @ Matrix.Translation(
        (0, 0, mmkit.studs(HEIGHT))
    )
    size = Vector((mmkit.studs(SIZE * 1.6), mmkit.studs(SIZE * 1.6), mmkit.studs(HEIGHT + 4)))
    cam = mmkit._setup_scene(size.z)
    bpy.context.scene.cycles.samples = 48
    mmkit._render_view(cam, "mystery_crate", "open", 35, 24, size)


if __name__ == "__main__":
    mmkit.finish(build_box(mmkit.Model("MysteryCrate")), "mystery_crate", max_tris=4000)
    mmkit.finish(build_lid(mmkit.Model("MysteryCrateLid")), "mystery_crate_lid", max_tris=2000)
    mmkit.finish(build_parachute(mmkit.Model("CrateParachute")), "crate_parachute", max_tris=1500)
    preview_open()
