"""FounderStar v4: the Founding Tester's Walk of Fame tile, laid flush with the lot ground.

Our own take on a Walk of Fame star (not a replica, no official emblems/wording):
  - a 3.6 x 3.6 stud charcoal terrazzo tile with a rounded edge and a shallow seam groove,
  - a coral-pink five-point star with CRISP tips and valleys (tiny fillets, inner/outer 0.42), edged by a raised, half-round brass rim that thins toward the tips,
  - a flat, chip-free name band across the star (the SurfaceGui draws the name there),
  - a flat chip-free strip, 1.2 x 0.17 studs, in the notch between the star's lower legs (the SurfaceGui draws "Founding Tester" there),
  - a round brass emblem (raised ring, dark field) with our own little clapperboard,
  - ~2,900 flat terrazzo chips (mostly single-triangle sand-fine ones on the charcoal) sit just above the faces.
Everything is smooth-shaded (auto-smooth by angle), colours are baked as vertex colours.
Tip toward +Y (top of the screen from above), model facing -Y, ~0.17 stud tall.

Built LIVE in Blender through the MCP for Blender (execute_blender_code), or run directly:
  exec(open("<repo>/art/blender/founder_star.py").read())     # inside Blender
  blender --python art/blender/founder_star.py                 # GUI
It makes its own scene "FounderStarV4" (never touches other scenes), renders previews to
art/drafts/founder_star_v4_{top,34,game,side}.png and exports art/exports/founder_star.fbx (+ a copy in
art/drafts/founder_star_v4.fbx). Mesh/object name: FounderStar. In Studio: LotMeshes.FounderStar.

Proportions from real stars (Wikimedia Commons "Carmen Miranda Hollywood Walk of Fame Star.jpg"
CC BY 2.0, "Stan Freberg Walk of fame.jpg" public domain; https://en.wikipedia.org/wiki/Hollywood_Walk_of_Fame):
star tip to tip ~80-90% of the square, inner/outer radius ~0.46, thin brass outline, name across the
upper arms, round emblem in the middle.
"""

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:  # exec'd inside the live Blender: set FOUNDER_STAR_DIR to this folder first
    HERE = os.environ["FOUNDER_STAR_DIR"]
sys.path.insert(0, HERE)
import mmkit  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
DRAFTS = os.path.join(REPO, "art", "drafts")
EXPORTS = os.path.join(REPO, "art", "exports")
STUD = mmkit.STUD
S = mmkit.studs
TAU = math.tau

# ---- layout (studs; tile centre is the origin, +Y is the star's tip) -------------------------------
TILE = 3.6
SLAB_Z = 0.10  # terrazzo top
CORAL_Z = 0.13  # coral face top
RIM_TOP = 0.17  # brass rim crest
RIM_HW = 0.042  # half width of the rim (it narrows toward the tips and valleys)
STAR_EXT = 1.68  # rim outer edge, centre to tip (tip to tip = 3.36 of 3.6)
STAR_RHO = 0.42  # inner / outer radius of the star polygon (real star ~0.40; 0.42 keeps the 1.9 stud name band inside)
TIP_R, VAL_R = 0.05, 0.05  # tiny fillets on the star's tips and valleys (centre line of the rim)
NAME_HW, NAME_Y0, NAME_Y1 = 0.95, -0.10, 0.28  # name band: 1.9 x 0.38 centred 0.09 above tile centre
EMB_R, EMB_Y = 0.30, -0.46
STRIP_HW, STRIP_Y0_DEFAULT, STRIP_Y1_DEFAULT = 0.60, -1.55, -1.38  # "Founding Tester" strip, between the lower legs (placed by build())
CHIP_LIFT = 0.010  # chips float this far above the face they sit on (no z-fight, invisible from the side)
TRI_BUDGET = 3950
CORAL_TRIS = 1500  # budget for the coral-star speckle (the rest of the budget goes to the charcoal)

C = {
    "slab": "#1E1C24", "terr": "#33313E", "seam": "#17161C", "coral": "#F4806F", "brass": "#F5B82E",
    "field": "#2E2C34", "cream": "#FAF6EC", "strip": "#3B3946",
}
TERR_CHIPS = ["#F2EFE6"] * 4 + ["#C9CDD9"] * 2 + ["#9AA0B4"] * 2 + ["#6F7488"]
CORAL_CHIPS = ["#FFF6EE"] * 3 + ["#FFE1D3"] * 2 + ["#FFC4B4"] + ["#D9484F"] * 2 + ["#B93C46"]


# ---- tiny mesh builder ----------------------------------------------------------------------------
class Mesh:
    def __init__(self):
        self.v, self.f, self.c = [], [], []

    def vert(self, x, y, z):
        self.v.append((S(x), S(y), S(z)))
        return len(self.v) - 1

    def face(self, idx, col):
        self.f.append(tuple(idx))
        self.c.append(col)

    def tris(self):
        return sum(len(f) - 2 for f in self.f)


def v2(p):
    return Vector((p[0], p[1]))


def round_poly(pts, radii, seg, mins=None):
    """Fillet every corner of a CCW polygon (list of Vector2) with an arc of the given radius.
    Returns (points, widths): widths is a per-point rim-width factor (1 on straights, `mins[i]` at the apex)."""
    n, out, wid = len(pts), [], []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        a, b = (p0 - p1).normalized(), (p2 - p1).normalized()
        ang = a.angle(b)
        r = radii[i]
        c = p1 + (a + b).normalized() * (r / math.sin(ang / 2))
        pa, pb = p1 + a * (r / math.tan(ang / 2)), p1 + b * (r / math.tan(ang / 2))
        a0 = math.atan2(pa.y - c.y, pa.x - c.x)
        a1 = math.atan2(pb.y - c.y, pb.x - c.x)
        d = (a1 - a0 + math.pi) % TAU - math.pi
        for k in range(seg[i] + 1):
            t = a0 + d * k / seg[i]
            out.append(Vector((c.x + math.cos(t) * r, c.y + math.sin(t) * r)))
            wid.append(1.0 if mins is None else 0.9 - (0.9 - mins[i]) * math.sin(math.pi * k / seg[i]))
    return out, wid


def sweep(m, path, profile, cols, widths=None):
    """Sweep a (inward offset, z) profile along a CCW closed path. Returns the rows of vertex ids."""
    n = len(path)
    rows = [[] for _ in profile]
    for i in range(n):
        t0 = (path[i] - path[i - 1]).normalized()
        t1 = (path[(i + 1) % n] - path[i]).normalized()
        n0, n1 = Vector((-t0.y, t0.x)), Vector((-t1.y, t1.x))
        nm = (n0 + n1).normalized()
        k = min(1.6, 1.0 / max(0.4, nm.dot(n0)))
        for j, (d, z) in enumerate(profile):
            w = 1.0 if widths is None else widths[i]
            rows[j].append(m.vert(path[i].x + nm.x * d * k * w, path[i].y + nm.y * d * k * w, z))
    for j in range(len(profile) - 1):
        for i in range(n):
            k = (i + 1) % n
            m.face((rows[j][i], rows[j][k], rows[j + 1][k], rows[j + 1][i]), cols[j])
    return rows


def fan_top(m, row, centre, z, col):
    c = m.vert(centre[0], centre[1], z)
    for i in range(len(row)):
        m.face((row[i], row[(i + 1) % len(row)], c), col)


def lathe(m, cx, cy, prof, cols, seg=20):
    """Revolve (radius, z) points, outer wall first and finishing on the axis (r = 0)."""
    angs = [TAU * i / seg for i in range(seg)]
    rows, centre = [], None
    for r, z in prof:
        if r == 0:
            centre = m.vert(cx, cy, z)
        else:
            rows.append([m.vert(cx + math.cos(a) * r, cy + math.sin(a) * r, z) for a in angs])
    for j in range(len(rows) - 1):
        for i in range(seg):
            k = (i + 1) % seg
            m.face((rows[j][i], rows[j][k], rows[j + 1][k], rows[j + 1][i]), cols[j])
    for i in range(seg):
        m.face((rows[-1][i], rows[-1][(i + 1) % seg], centre), cols[-1])


def tbox(m, cx, cy, w, h, z0, z1, col, rot=0.0, inset=0.008):
    """A small box with a tapered (chamfered) top, optionally rotated about its own centre."""
    cs, sn = math.cos(rot), math.sin(rot)

    def pt(x, y):
        return cx + x * cs - y * sn, cy + x * sn + y * cs

    base = [pt(sx * w / 2, sy * h / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    top = [pt(sx * (w / 2 - inset), sy * (h / 2 - inset)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    b = [m.vert(x, y, z0) for x, y in base]
    t = [m.vert(x, y, z1) for x, y in top]
    for i in range(4):
        k = (i + 1) % 4
        m.face((b[i], b[k], t[k], t[i]), col)
    m.face((t[0], t[1], t[2], t[3]), col)


# ---- 2D helpers ------------------------------------------------------------------------------------
def inside(poly, x, y):
    c = False
    for i in range(len(poly)):
        a, b = poly[i], poly[i - 1]
        if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x:
            c = not c
    return c


def dist_poly(poly, x, y):
    best = 9e9
    for i in range(len(poly)):
        a, b = poly[i - 1], poly[i]
        dx, dy = b.x - a.x, b.y - a.y
        t = max(0.0, min(1.0, ((x - a.x) * dx + (y - a.y) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.hypot(x - a.x - t * dx, y - a.y - t * dy))
    return best


def dist_rect(x, y, x0, x1, y0, y1):
    return math.hypot(max(x0 - x, 0, x - x1), max(y0 - y, 0, y - y1))


def star_polygon(R, cy):
    pts = []
    for k in range(10):
        r = R if k % 2 == 0 else R * STAR_RHO
        a = math.pi / 2 + math.pi * k / 5
        pts.append(Vector((math.cos(a) * r, cy + math.sin(a) * r)))
    return pts


def chip_shape(rng, cx, cy, r):
    """A random small flat shard (triangle, quad or pentagon), CCW, as (points, triangle index list)."""
    n = 3 if r < 0.028 else rng.choices((3, 4, 5), (50, 35, 15))[0]  # the tiny ones are single triangles
    a0 = rng.uniform(0, TAU)
    angs = [a0 + (k + rng.uniform(-0.22, 0.22)) * TAU / n for k in range(n)]
    pts = [(cx + math.cos(a) * r * rng.uniform(0.62, 1.0), cy + math.sin(a) * r * rng.uniform(0.62, 1.0)) for a in angs]
    if n > 3:  # a non-convex shard falls back to a triangle
        for i in range(n):
            (x0, y0), (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
            if (x1 - x0) * (y2 - y1) - (y1 - y0) * (x2 - x1) <= 0:
                return pts[:3], [(0, 1, 2)]
    return pts, [(0, k, k + 1) for k in range(1, n - 1)]


# ---- the model --------------------------------------------------------------------------------------
def build():
    m = Mesh()

    # Star outline (centre line of the brass rim), rounded. Pre-round radius is chosen so that the
    # rim's OUTER edge reaches STAR_EXT at the tips.
    probe = star_polygon(1.0, 0.0)
    tip_half = (probe[1] - probe[0]).angle(probe[9] - probe[0]) / 2
    r_pre = STAR_EXT + (TIP_R / math.sin(tip_half) - TIP_R) - RIM_HW
    cy = -STAR_EXT * (1 - math.cos(math.radians(36))) / 2  # whole star centred in the tile
    spts = star_polygon(r_pre, cy)
    path, pw = round_poly(spts, [TIP_R if k % 2 == 0 else VAL_R for k in range(10)], [3 if k % 2 == 0 else 2 for k in range(10)],
                          [0.6 if k % 2 == 0 else 0.8 for k in range(10)])

    # 1. Tile body: rounded square, rounded top edge, shallow seam groove, terrazzo top.
    h = TILE / 2
    sq = [Vector((-h, -h)), Vector((h, -h)), Vector((h, h)), Vector((-h, h))]  # CCW
    rsq, _ = round_poly(sq, [0.22] * 4, [2] * 4)
    prof = [(0, 0), (0, 0.055), (0.014, 0.085), (0.055, SLAB_Z), (0.068, 0.092), (0.082, 0.092), (0.095, SLAB_Z), (0.14, SLAB_Z)]
    cols = [C["slab"], C["slab"], C["terr"], C["seam"], C["seam"], C["terr"], C["terr"]]
    rows = sweep(m, rsq, prof, cols)
    fan_top(m, rows[-1], (0, 0), SLAB_Z, C["terr"])
    cb = m.vert(0, 0, 0)  # bottom
    for i in range(len(rows[0])):
        m.face((rows[0][(i + 1) % len(rows[0])], rows[0][i], cb), C["slab"])

    # 2. Coral star face + half-round brass rim along the rounded star outline.
    rim = [(-RIM_HW * 1.0, SLAB_Z)]
    for deg in (-60, -30, 0, 30, 60):
        rim.append((RIM_HW * math.sin(math.radians(deg)), SLAB_Z + (RIM_TOP - SLAB_Z) * math.cos(math.radians(deg))))
    rim.append((RIM_HW + 0.008, CORAL_Z))
    rows = sweep(m, path, rim, [C["brass"]] * (len(rim) - 1), pw)
    fan_top(m, rows[-1], (0, cy), CORAL_Z, C["coral"])

    # 3. Emblem: brass disc with a raised ring round a dark field, and our own clapperboard.
    lathe(m, 0, EMB_Y, [(EMB_R, 0.125), (EMB_R, 0.152), (EMB_R - 0.012, 0.172), (EMB_R - 0.034, 0.182), (EMB_R - 0.064, 0.180), (EMB_R - 0.080, 0.158), (0, 0.158)],
          [C["brass"], C["brass"], C["brass"], C["brass"], C["brass"], C["field"]], seg=20)
    zc = 0.158
    ex, ey = 0.0, EMB_Y
    tbox(m, ex, ey - 0.050, 0.27, 0.150, zc, zc + 0.026, C["brass"], inset=0.010)  # board
    for k in range(2):  # two "text" lines on the board
        tbox(m, ex + 0.01, ey - 0.030 - k * 0.055, 0.20 - k * 0.07, 0.016, zc + 0.026, zc + 0.032, C["field"], inset=0.003)
    arm_ang = math.radians(14)
    hinge = (ex - 0.135, ey + 0.025)  # arm pivots on the board's top-left
    aw, ah = 0.27, 0.056
    ac = (hinge[0] + math.cos(arm_ang) * aw / 2 - math.sin(arm_ang) * ah / 2, hinge[1] + math.sin(arm_ang) * aw / 2 + math.cos(arm_ang) * ah / 2)
    tbox(m, ac[0], ac[1], aw, ah, zc + 0.018, zc + 0.046, C["cream"], rot=arm_ang, inset=0.008)
    for k in range(3):
        off = -aw / 2 + 0.055 + k * 0.080
        px = ac[0] + math.cos(arm_ang) * off
        py = ac[1] + math.sin(arm_ang) * off
        tbox(m, px, py, 0.030, ah - 0.012, zc + 0.046, zc + 0.052, C["field"], rot=arm_ang, inset=0.003)

    # 4. Flat strip for the "Founding Tester" text, under the star.
    strip_y0, strip_y1 = STRIP_Y0_DEFAULT, STRIP_Y1_DEFAULT
    sh = strip_y1 - strip_y0
    for y1 in [-0.9 - 0.01 * k for k in range(80)]:  # highest spot in the notch where the strip clears the rim
        if all(not inside(path, sx * STRIP_HW, y) and dist_poly(path, sx * STRIP_HW, y) >= RIM_HW + 0.03 for sx in (-1, 1) for y in (y1, y1 - sh)) and y1 - sh >= -1.64:
            strip_y1, strip_y0 = y1 - 0.04, y1 - 0.04 - sh
            break
    print(f"strip {2 * STRIP_HW:.2f} x {sh:.2f} at y {strip_y0:.2f}..{strip_y1:.2f}")
    tbox(m, 0, (strip_y0 + strip_y1) / 2, STRIP_HW * 2, sh, SLAB_Z - 0.004, SLAB_Z + 0.008, C["strip"], inset=0.012)

    body_tris = m.tris()

    # 5. Terrazzo speckle: flat shards, seeded so the tile is always identical.
    # Name band must stay clean: shrink it if the real star outline cannot hold it.
    corners = [(sx * NAME_HW, y) for sx in (-1, 1) for y in (NAME_Y0, NAME_Y1)]
    band_margin = min(dist_poly(path, x, y) for x, y in corners)
    band_ok = all(inside(path, x, y) for x, y in corners) and band_margin >= RIM_HW + 0.004
    print(f"name band 1.9 x {NAME_Y1 - NAME_Y0:.2f} fits: {band_ok} (corner clearance to rim centre line {band_margin:.3f}, rim hw {RIM_HW})")

    rng = random.Random(28)
    grid, placed = {}, []

    def free(x, y, r):
        gx, gy = int(math.floor(x / 0.2)), int(math.floor(y / 0.2))
        for ix in range(gx - 1, gx + 2):
            for iy in range(gy - 1, gy + 2):
                for qx, qy, qr in grid.get((ix, iy), ()):
                    if math.hypot(x - qx, y - qy) < r + qr + 0.006:
                        return False
        return True

    def reserve(x, y, r):
        grid.setdefault((int(math.floor(x / 0.2)), int(math.floor(y / 0.2))), []).append((x, y, r))

    def put(pts, tri, z, col):
        ids = [m.vert(x, y, z) for x, y in pts]
        for a, b, c in tri:
            m.face((ids[a], ids[b], ids[c]), col)

    chips_t = chips_c = 0
    for coral, cap in ((True, body_tris + CORAL_TRIS), (False, TRI_BUDGET)):
        tries = 0
        while m.tris() < cap and tries < 120000:
            tries += 1
            if coral:
                r = 0.013 + 0.050 * rng.random() ** 2.6  # finer chips on the star, like the real one
                x, y = rng.uniform(-1.6, 1.6), rng.uniform(-1.4, 1.5)
                if not inside(path, x, y) or dist_poly(path, x, y) < RIM_HW + r + 0.014:
                    continue
                if dist_rect(x, y, -NAME_HW, NAME_HW, NAME_Y0, NAME_Y1) < r + 0.012:
                    continue
                if math.hypot(x, y - EMB_Y) < EMB_R + r + 0.03:
                    continue
                z, col = CORAL_Z + CHIP_LIFT, rng.choice(CORAL_CHIPS)
            else:
                r = 0.011 + 0.050 * rng.random() ** 3.4
                x, y = rng.uniform(-1.66, 1.66), rng.uniform(-1.66, 1.66)
                if abs(x) > 1.66 - r or abs(y) > 1.66 - r or (abs(x) > 1.45 and abs(y) > 1.45):
                    continue
                if inside(path, x, y) or dist_poly(path, x, y) < RIM_HW + r + 0.016:
                    continue
                if dist_rect(x, y, -STRIP_HW, STRIP_HW, strip_y0, strip_y1) < r + 0.02:
                    continue
                z, col = SLAB_Z + CHIP_LIFT, rng.choice(TERR_CHIPS)
            if not free(x, y, r):
                continue
            reserve(x, y, r)
            pts, tri = chip_shape(rng, x, y, r)
            put(pts, tri, z, col)
            if coral:
                chips_c += 1
            else:
                chips_t += 1
    print(f"body {body_tris} tris, chips {chips_t} charcoal + {chips_c} coral ({m.tris() - body_tris} tris), "
          f"star centre y {cy:.3f}, pre-round R {r_pre:.3f}")
    return m, path


def make_object(m):
    mesh = bpy.data.meshes.new("FounderStar")
    mesh.from_pydata(m.v, [], m.f)
    mesh.update()
    # smooth shading with sharp edges where faces turn more than 38 degrees (auto-smooth)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.edges.ensure_lookup_table()
    limit = math.radians(38)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0) > limit:
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    # baked vertex colours (Roblox ignores solid-colour FBX materials)
    col = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    for poly, hexcol in zip(mesh.polygons, m.c):
        lin = mmkit.hex_to_linear(hexcol)
        for li in poly.loop_indices:
            col.data[li].color = lin
    mat = bpy.data.materials.new("FounderStar_Vertex")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.45
    mesh.materials.append(mat)
    obj = bpy.data.objects.new("FounderStar", mesh)
    return obj


# ---- scene, previews, export ----------------------------------------------------------------------
def fresh_scene():
    old = bpy.data.scenes.get("FounderStarV4")
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    sc = bpy.data.scenes.new("FounderStarV4")
    try:
        bpy.context.window.scene = sc
    except Exception as exc:  # no window (background run)
        print("could not switch window to the new scene:", exc)
    return sc


def setup_render(sc, obj):
    sc.collection.objects.link(obj)
    world = bpy.data.worlds.new("FounderStarWorld")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = mmkit.hex_to_linear("#BFD9F2")
    bg.inputs["Strength"].default_value = 0.9
    sc.world = world
    sun = bpy.data.objects.new("FS_Sun", bpy.data.lights.new("FS_Sun", "SUN"))
    sun.data.energy = 3.5
    sun.data.color = (1.0, 0.95, 0.85)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
    sc.collection.objects.link(sun)
    floor = bpy.data.objects.new("FS_Floor", bpy.data.meshes.new("FS_Floor"))
    fb = bmesh.new()
    bmesh.ops.create_grid(fb, x_segments=1, y_segments=1, size=40.0)
    fb.to_mesh(floor.data)
    fb.free()
    fm = bpy.data.materials.new("FS_FloorMat")
    fm.use_nodes = True
    next(n for n in fm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = mmkit.hex_to_linear("#9C9A94")
    floor.data.materials.append(fm)
    sc.collection.objects.link(floor)
    cam = bpy.data.objects.new("FS_Cam", bpy.data.cameras.new("FS_Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.image_settings.file_format = "PNG"
    for eng in ("CYCLES", "BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            continue
    if sc.render.engine == "CYCLES":
        sc.cycles.device = "CPU"
        sc.cycles.samples = 48
        sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Standard"
    return cam


def shoot(sc, cam, name, az, el, dist, lens=60, ortho=None, res=(900, 900)):
    sc.render.resolution_x, sc.render.resolution_y = res
    target = Vector((0, 0, S(0.1)))
    a, e = math.radians(az), math.radians(el)
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens
    cam.location = target + dist * Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = os.path.join(DRAFTS, f"founder_star_v4_{name}.png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=sc.name)
    return path


def side_by_side(top_png, ref_png, out_png):
    import numpy as np

    def load(p):
        im = bpy.data.images.load(p)
        w, h = im.size
        arr = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        bpy.data.images.remove(im)
        return arr

    ref_full = load(ref_png)
    ref = ref_full[:, : ref_full.shape[1] * 960 // 1724]  # left panel: the real Carmen Miranda star
    mine = load(top_png)
    H = ref.shape[0]
    im = bpy.data.images.new("fs_resize", mine.shape[1], mine.shape[0], alpha=True)
    im.pixels = mine.ravel()
    im.scale(int(mine.shape[1] * H / mine.shape[0]), H)
    mine2 = np.array(im.pixels[:], dtype=np.float32).reshape(H, im.size[0], 4)
    bpy.data.images.remove(im)
    out = np.concatenate([ref, mine2], axis=1)
    o = bpy.data.images.new("fs_compare", out.shape[1], out.shape[0], alpha=True)
    o.pixels = out.ravel()
    o.filepath_raw = out_png
    o.file_format = "PNG"
    o.save()
    bpy.data.images.remove(o)


def export(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    smooth_items = [i.identifier for i in bpy.ops.export_scene.fbx.get_rna_type().properties["mesh_smooth_type"].enum_items]
    normals_only = "OFF" if "OFF" in smooth_items else smooth_items[0]
    os.makedirs(EXPORTS, exist_ok=True)
    for dest in (os.path.join(EXPORTS, "founder_star.fbx"), os.path.join(DRAFTS, "founder_star_v4.fbx")):
        bpy.ops.export_scene.fbx(
            filepath=dest, use_selection=True,
            global_scale=1 / (STUD * 100),  # Roblox reads FBX cm as studs, so write the model in studs
            apply_unit_scale=True, bake_space_transform=True, colors_type="SRGB",
            axis_forward="-Y", axis_up="Z", mesh_smooth_type=normals_only, add_leaf_bones=False,
        )
        print("exported", dest, "(smoothing:", normals_only, ")")


def main():
    os.makedirs(DRAFTS, exist_ok=True)
    m, _ = build()
    tris = m.tris()
    obj = make_object(m)
    xs, ys, zs = zip(*obj.bound_box)
    print(f"FounderStar: {tris} tris, {(max(xs) - min(xs)) / STUD:.2f} x {(max(ys) - min(ys)) / STUD:.2f} x {(max(zs) - min(zs)) / STUD:.3f} studs")
    assert tris <= 4000, "over the triangle budget"
    sc = fresh_scene()
    cam = setup_render(sc, obj)
    shoot(sc, cam, "top", 0, 90, 3.0, ortho=1.12)
    shoot(sc, cam, "34", 28, 38, 2.0, lens=70)
    shoot(sc, cam, "game", 0, 55, 10 * STUD, lens=25.7, res=(1280, 720))  # ~10 studs away, Roblox 70 deg FOV
    shoot(sc, cam, "side", 8, 14, 1.6, lens=70)
    ref = os.path.join(DRAFTS, "founder_star_v2_compare_reference.png")
    if not os.path.exists(ref):
        ref = os.path.join(os.path.expanduser("~/Desktop/bagoflean/art/drafts/founder_star_v2_compare_reference.png"))
    side_by_side(os.path.join(DRAFTS, "founder_star_v4_top.png"), ref, os.path.join(DRAFTS, "founder_star_v4_compare_reference.png"))
    export(obj)
    return obj


obj = main()
