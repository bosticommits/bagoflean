"""Lot cinema kit: the studio lot's cinema as Blender meshes, one look per Cinema Size level (0-6).

  LotCinema<N>        the building at level N, white-lit baked vertex colors (MeshPart Color white)
  LotCinema<N>Accent  the lot-colored pieces (marquee canopy, wing awnings), modelled WHITE so the
                      game tints them per lot through the MeshPart's Color (LotService LOT_COLORS)

The looks grow today's four part-built tiers (LotModels.cinemaTier) one level at a time:
0 small, 1 a bit bigger with side windows, 2 adds the CINEMA blade sign and a third headboard
step, 3 bigger with upper windows and two posters a side, 4 columns and side wings, 5 wing
awnings and a bulb-lit roofline, 6 the gold dome and rooftop searchlights.

What glows or carries text stays a plain part, placed by LotModels.cinema from a table this
script writes into src/shared/Models/LotModels.luau (between the "lot_cinema_kit" markers):
the marquee board (studio name), the blade face (CINEMA), posters, the headboard star and a few
neon bulb strips. Their shapes are drawn in the preview only, not exported.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/lot_cinema_kit.py
Writes art/exports/lot_cinema_kit.fbx and art/previews/lot_kit_cinema.png. KIT_NO_RENDER=1 skips
the render. Blender axes, studs: Z up, the cinema faces -Y, origin at the bottom centre of its
front wall (it grows backward, +Y), like LotModels.cinema.
"""

import math
import os
import re
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E, K  # noqa: E402
from mascots import flatten, num, stage  # noqa: E402

STUD = mmkit.STUD
P = map_kit.P
LUAU = os.path.join(mmkit.REPO, "src", "shared", "Models", "LotModels.luau")
MAX_TRIS = 5000  # ART_STYLE hero object (cinema facade)

# Per level: size and which features it has (today's tiers: 0-1, 2-3, 4-5, 6).
LEVELS = [
    dict(w=16, h=9, d=12, steps=2, door=6, posters=1, board=2.4),
    dict(w=18, h=10.5, d=13, steps=2, door=6, posters=1, board=2.4, side_windows=True),
    dict(w=20, h=12, d=14, steps=3, door=6, posters=1, board=3, side_windows=True, blade=True),
    dict(w=22, h=13.5, d=15, steps=3, door=7, posters=2, board=3, side_windows=True, blade=True, windows=True),
    dict(w=24, h=15, d=16, steps=3, door=8, posters=2, board=3, side_windows=True, blade=True, windows=True, columns=True),
    dict(w=24, h=15, d=16, steps=3, door=8, posters=2, board=3, side_windows=True, blade=True, windows=True, columns=True, awnings=True, roof_bulbs=True),
    dict(w=24, h=15, d=16, steps=3, door=8, posters=2, board=3, side_windows=True, blade=True, windows=True, columns=True, awnings=True, roof_bulbs=True, dome=True),
]


def BV(at, size, color, bevel=0.15, rot=(0, 0, 0)):
    return B(at, size, color, rot, bevel)


def part(name, s, hit=False):
    """A shape the game builds as a plain part (glow, text) or an invisible hitbox."""
    s["name"] = name
    s["hit"] = hit
    return s


def look(lv, accent_preview=None):
    """(body shapes, accent shapes, part shapes, searchlight spots) for one level."""
    L = LEVELS[lv]
    w, h, d = L["w"], L["h"], L["d"]
    yc = d / 2
    body, accent, parts, lights = [], [], [], []
    tint = accent_preview or "#FFFFFF"

    # Shell: plinth, walls, cornice and parapet, bevelled like the boulevard buildings.
    body += [
        BV((0, yc, h / 2), (w, d, h), "Cream", 0.12),
        BV((0, yc, 0.7), (w + 0.4, d + 0.4, 1.4), "Burgundy", 0.12),
        BV((0, yc, h + 0.5), (w + 1, d + 1, 1), "Burgundy", 0.15),
        BV((0, yc, h + 1.4), (w + 0.4, d + 0.4, 0.8), "Cream", 0.1),
        B((0, yc, h - 1.2), (w + 0.2, d + 0.2, 0.35), "Gold"),  # gold band under the cornice
    ]
    parts.append(part("Hitbox", B((0, yc, (h + 1.8) / 2), (w + 0.4, d + 0.4, h + 1.8), "#FFFFFF"), hit=True))
    # Front pilasters with gold caps and bases.
    for x in (-w / 2 + 0.6, w / 2 - 0.6):
        body += [
            BV((x, -0.2, h / 2), (1.4, 0.5, h), "Burgundy", 0.08),
            BV((x, -0.35, h - 0.4), (1.7, 0.6, 0.6), "Gold", 0.08),
            BV((x, -0.35, 1.6), (1.7, 0.6, 0.5), "Gold", 0.08),
        ]

    # Stepped headboard over the roofline; each step has a bulb strip along its top edge.
    for i in range(1, L["steps"] + 1):
        sw = w * (0.75 - (i - 1) * 0.2)
        z = h + 1 + (i - 0.5) * 1.8
        body.append(BV((0, 0.4, z), (sw, 1, 1.8), "Burgundy" if i % 2 == 1 else "Cream", 0.1))
        parts.append(part("HeadboardBulbs", B((0, -0.15, z + 0.7), (sw - 0.8, 0.3, 0.35), "Gold", neon=True)))
    star_z = h + 1 + L["steps"] * 1.8 + 1.4
    body.append(B((0, 0.6, star_z - 1.3), (0.5, 0.5, 1.2), "Gold"))  # the star's stalk
    parts.append(part("HeadboardStar", B((0, 0.4, star_z), (2.2, 0.6, 2.2), "Gold", rot=(0, 45, 0), neon=True)))

    # Entrance: glass doors in a burgundy frame with a gold transom and handles, a low step.
    dw = L["door"]
    body += [
        BV((0, -0.15, 3.2), (dw + 1.2, 0.4, 6.4), "Burgundy", 0.08),
        B((0, -0.3, 2.9), (dw, 0.3, 5.4), "DoorGlass"),
        B((0, -0.45, 5.9), (dw, 0.2, 0.3), "Gold"),
        B((0, -0.48, 2.9), (0.25, 0.1, 5.4), "Gold"),
    ]
    for k in range(1, int(dw // 2)):
        x = -dw / 2 + k * dw / int(dw // 2)
        body.append(B((x, -0.42, 2.9), (0.18, 0.1, 5.4), "Burgundy"))
    for x in (-0.5, 0.5):
        body.append(B((x, -0.6, 2.8), (0.15, 0.2, 1.4), "Gold"))
    body.append(BV((0, -0.9, 1.5), (dw + 2.4, 1.6, 0.2), "Paving", 0.05))

    # Poster cases either side of the doors (frame in the mesh, lit poster a part).
    poster_colors = ["Blue", "Carpet", "accent", "Gold"]
    for side in (-1, 1):
        for i in range(1, L["posters"] + 1):
            x = side * (dw / 2 + 1.6 + (i - 1) * 3.2)
            body += [
                BV((x, -0.2, 3.4), (2.6, 0.3, 3.8), "Burgundy", 0.06),
                B((x, -0.36, 5.4), (2.0, 0.2, 0.3), "Gold"),
            ]
            col = poster_colors[(i + (side + 1)) % 4]
            parts.append(part("Poster", B((x, -0.4, 3.4), (2.1, 0.1, 3.2), col, neon=True)))

    # Marquee canopy (accent) on a burgundy edge with a bulb strip; the name board stands on it.
    cw = min(w - 2, dw + 8)
    cy = 6.8
    accent.append(BV((0, -2, cy), (cw, 4, 1), tint, 0.12))
    body += [
        BV((0, -2, cy - 0.6), (cw + 0.4, 4.4, 0.4), "Burgundy", 0.06),
        B((0, -4.25, cy - 0.6), (cw + 0.2, 0.12, 0.15), "Gold"),
    ]
    for x in (-cw / 2 + 0.6, cw / 2 - 0.6):  # chains up to the wall
        body.append(B((x, -2.4, cy + 1.4), (0.15, 3.4, 0.15), "Steel", rot=(-38, 0, 0)))
    parts.append(part("CanopyBulbs", B((0, -4.15, cy - 0.9), (cw, 0.4, 0.4), "Gold", neon=True)))
    bh = L["board"]
    bz = cy + 0.5 + bh / 2
    body.append(BV((0, -3.3, bz), (cw - 0.4, 0.4, bh + 0.6), "Gold", 0.08))
    parts.append(part("MarqueeSign", B((0, -3.6, bz), (cw - 1, 0.6, bh), "Navy")))

    # Upper front windows (framed) where the wall is tall enough.
    if L.get("windows"):
        rz = cy + bh + 2.2
        if rz + 1 < h:
            for i in (-1, 0, 1):
                body += [
                    B((i * 4.5, -0.1, rz), (3.0, 0.2, 2.6), "Cream"),
                    B((i * 4.5, -0.2, rz), (2.4, 0.2, 2.0), "Glass"),
                    B((i * 4.5, -0.25, rz), (0.18, 0.2, 2.0), "Cream"),
                    BV((i * 4.5, -0.35, rz - 1.4), (3.2, 0.6, 0.25), "Burgundy", 0.05),
                ]

    # Side walls: tall arched-look windows between ribs.
    if L.get("side_windows"):
        n = 2 if d < 15 else 3
        for side in (-1, 1):
            x = side * w / 2
            for k in range(n):
                y = d * (k + 1) / (n + 1)
                body += [
                    B((x + side * 0.1, y, h * 0.55), (0.2, 2.0, h * 0.42), "Burgundy"),
                    B((x + side * 0.18, y, h * 0.55), (0.2, 1.4, h * 0.36), "Glass"),
                ]
    else:
        for side in (-1, 1):  # plain ribs on the small cinema
            for y in (d / 3, 2 * d / 3):
                body.append(B((side * (w / 2 + 0.1), y, h / 2), (0.2, 0.8, h - 2), "Burgundy"))

    # Back: exit door with a light over it.
    body += [
        B((w / 4, d + 0.1, 2.6), (2.4, 0.3, 4.2), "Steel"),
        B((w / 4, d + 0.3, 5.1), (1.2, 0.3, 0.5), "Light"),
    ]

    # Roof clutter: air handlers and a hatch.
    vents = [(-w / 2 + 3, d - 3)] + ([(w / 2 - 4, d - 4)] if lv >= 2 else [])
    for vx, vy in vents:
        if L.get("dome"):
            vy = 2.5
        body += [
            BV((vx, vy, h + 1.9), (2.2, 2.2, 1.4), "Steel", 0.1),
            C((vx, vy, h + 2.7), 0.7, 0.3, "Charcoal", seg=10),
        ]
    body.append(BV((w / 4, d / 2, h + 1.25), (1.6, 1.6, 0.5), "Steel", 0.06))

    # Level 2+: the tall CINEMA blade sign on the front corner (game's right).
    if L.get("blade"):
        bl = h + 6
        bx = -(w / 2 - 2)
        bzc = h - 6 + bl / 2
        body += [
            BV((bx, -1.6, bzc), (1, 3, bl), "Burgundy", 0.1),
            B((bx, -1.6, h - 6 - 0.3), (0.6, 1.6, 0.6), "Gold"),
            B((bx, 0.0, bzc - 2), (0.3, 1.4, 0.3), "Steel"),
            B((bx, 0.0, bzc + 3), (0.3, 1.4, 0.3), "Steel"),
        ]
        parts.append(part("BladeFace", B((bx, -1.6, bzc), (1.2, 2.2, bl - 1.5), "Navy")))
        parts.append(part("BladeBulbs", B((bx, -3.2, (h - 5 + h + bl - 6.5) / 2), (0.45, 0.45, bl - 1.5), "Gold", neon=True)))
        parts.append(part("BladeTop", E((bx, -1.6, h - 6 + bl + 0.6), (0.8, 0.8, 0.8), "Gold", neon=True)))

    # Level 4+: columns either side of the entrance and side wings.
    if L.get("columns"):
        for x in (-w / 2 + 1.5, w / 2 - 1.5):
            body += [
                C((x, -0.9, (h - 1) / 2 + 1), 0.8, h - 1, "OffWhite", seg=12),
                BV((x, -0.9, h + 0.2), (2.2, 2.2, 0.6), "Gold", 0.08),
                BV((x, -0.9, 1.2), (2.0, 2.0, 0.5), "Gold", 0.08),
            ]
        for side in (-1, 1):
            wx = side * (w / 2 + 1)
            body += [
                BV((wx, d / 2 + 1, (h - 4) / 2), (2, d - 4, h - 4), "Cream", 0.1),
                BV((wx, d / 2 + 1, h - 4), (2.4, d - 3.6, 0.8), "Burgundy", 0.08),
                B((wx, 3 - 0.12, 2.6), (1.2, 0.2, 3.6), "Burgundy"),  # wing door
            ]
            if L.get("awnings"):
                accent.append(BV((wx, 2.2, 5.2), (2.2, 1.8, 0.35), tint, 0.08))
        parts.append(part("Hitbox", B((0, d / 2 + 1, (h - 4) / 2), (w + 4.4, d - 4, h - 4), "#FFFFFF"), hit=True))

    # Level 5+: a bulb strip along the parapet's front edge.
    if L.get("roof_bulbs"):
        parts.append(part("RoofBulbs", B((0, -0.3, h + 1.9), (w, 0.45, 0.45), "Gold", neon=True)))

    # Level 6: grand premiere theatre with a gold dome and two rooftop searchlights.
    if L.get("dome"):
        body += [
            C((0, d / 2 + 2, h + 2.6), 4, 1.4, "Burgundy", seg=16),
            B((0, d / 2 + 2, h + 3.35), (8.2, 8.2, 0.2), "Gold"),
            E((0, d / 2 + 2, h + 3.3), (3.5, 3.5, 3.5), "Gold"),
            C((0, d / 2 + 2, h + 8), 0.25, 3, "Gold", seg=8),
        ]
        parts.append(part("DomeTop", E((0, d / 2 + 2, h + 9.8), (0.6, 0.6, 0.6), "Gold", neon=True)))
        for x in (w / 2 - 2, -w / 2 + 2):  # game's left first (LotModels turns it -25 degrees)
            lights.append((x, d - 2, h + 1.8))
    return body, accent, parts, lights


def build_shapes(name, shapes):
    return map_kit.build(name, lambda: shapes, lift_to_ground=False)[0]


def roblox_bounds(obj):
    lo, hi = map_kit.bounds(obj)
    a, b = P @ lo, P @ hi
    mn = Vector([min(x, y) for x, y in zip(a, b)])
    mx = Vector([max(x, y) for x, y in zip(a, b)])
    return (mn + mx) / 2, mx - mn


def vec(v):
    return f"Vector3.new({', '.join(num(c) for c in v)})"


def luau_table(rows):
    out = ["local CINEMA_MESH: { [number]: CinemaMesh } = {"]
    for lv, body, accent, parts, lights in rows:
        out.append(f"\t[{lv}] = {{")
        for key, obj in (("body", body), ("accent", accent)):
            c, s = roblox_bounds(obj)
            out.append(f"\t\t{key} = {{ center = {vec(c)}, size = {vec(s)} }},")
        out.append("\t\tparts = {")
        for s, m, _ in flatten(parts, []):
            _, _, size = map_kit.to_roblox(s, m)
            hex_ = "hitbox" if s["hit"] else ("accent" if s["color"] == "accent" else s["color"].lstrip("#"))
            ball = "true" if s["kind"] == "ball" else "false"
            neon = "true" if s["neon"] else "false"
            out.append(
                f"\t\t\t{{ name = \"{s['name']}\", cf = CFrame.new({map_kit.cframe(s, m)}), size = {vec(size)}, color = \"{hex_}\", neon = {neon}, ball = {ball} }},"
            )
        out.append("\t\t},")
        out.append("\t\tlights = { " + ", ".join(vec(P @ Vector(p)) for p in lights) + " },")
        out.append("\t},")
    out.append("}")
    return out


def write_luau(rows):
    with open(LUAU) as f:
        src = f.read()
    begin = "-- BEGIN lot_cinema_kit (generated by art/blender/lot_cinema_kit.py; do not edit by hand)\n"
    end = "-- END lot_cinema_kit\n"
    block = begin + "\n".join(luau_table(rows)) + "\n" + end
    pattern = re.compile(re.escape(begin) + ".*?" + re.escape(end), re.S)
    assert pattern.search(src), "LotModels.luau is missing the lot_cinema_kit markers"
    with open(LUAU, "w") as f:
        f.write(pattern.sub(lambda _: block, src))
    print("Wrote", LUAU)


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def main():
    os.makedirs(mmkit.EXPORTS, exist_ok=True)
    os.makedirs(mmkit.PREVIEWS, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows, objs = [], []
    for lv in range(len(LEVELS)):
        body_s, accent_s, parts_s, lights = look(lv)
        body = build_shapes(f"LotCinema{lv}", body_s)
        accent = build_shapes(f"LotCinema{lv}Accent", accent_s)
        t = tris(body) + tris(accent)
        c, s = roblox_bounds(body)
        print(f"LotCinema{lv}: {t} tris ({tris(accent)} accent), {s.x:.1f} x {s.y:.1f} x {s.z:.1f} studs, {len(parts_s)} parts")
        assert t <= MAX_TRIS, f"LotCinema{lv} is over its triangle budget"
        for o in (body, accent):
            mmkit.bake_vertex_colors(o.data)
            objs.append(o)
        rows.append((lv, body, accent, parts_s, lights))
    write_luau(rows)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = os.path.join(mmkit.EXPORTS, "lot_cinema_kit.fbx")
    bpy.ops.export_scene.fbx(
        filepath=out, use_selection=True, global_scale=1 / (STUD * 100), apply_unit_scale=True,
        bake_space_transform=True, colors_type="SRGB", axis_forward="-Y", axis_up="Z",
        mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    print("Exported", out)
    if not os.environ.get("KIT_NO_RENDER"):
        preview()


def preview():
    """All seven looks side by side, with the accent tinted lot red and the game's parts drawn."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shown = []
    x = 0.0
    for lv in range(len(LEVELS)):
        body_s, accent_s, parts_s, _ = look(lv, accent_preview="#C8202F")
        drawn = [dict(s, color="#C8202F" if s["color"] == "accent" else s["color"]) for s in parts_s if not s["hit"]]
        group = [build_shapes(f"P{lv}{k}", sh) for k, sh in (("b", body_s), ("a", accent_s), ("p", drawn))]
        wd = LEVELS[lv]["w"] + (4.4 if LEVELS[lv].get("columns") else 0.4)
        x += wd / 2
        for o in group:
            o.location = (STUD * x, 0, 0)
            o.rotation_euler = (0, 0, math.radians(-14))
            shown.append(o)
        x += wd / 2 + 5
    for o in shown:
        o.location.x -= STUD * x / 2
    stage(shown, "lot_kit_cinema.png", 2400, 1000, 1.15, 20)


if __name__ == "__main__":
    main()
