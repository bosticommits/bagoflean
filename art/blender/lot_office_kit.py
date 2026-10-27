"""Lot office kit: the producer's office as Blender meshes, one look per Offline Earnings level (0-5).

  LotOffice<N>        the building at level N, white-lit baked vertex colors (MeshPart Color white)
  LotOffice<N>Accent  the lot-colored pieces (trailer stripe and awning, entrance canopy), modelled
                      WHITE so the game tints them per lot through the MeshPart's Color (LOT_COLORS)

The looks keep today's part-built office (LotModels.office) and add detail: 0 the star trailer on
blocks, 1 a two-floor cream office, 2 the same with a roof unit and antenna, 3-5 a glass tower of
3, 4 and 5 floors (5 carries the gold film reel logo, which stays its own FilmReelLogo mesh).

What glows stays a plain part, placed by LotModels.office from a table this script writes into
src/shared/Models/LotModels.luau (between the "lot_office_kit" markers): the trailer's door star
and the antenna light, plus an invisible hitbox (the mesh doesn't collide).

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/lot_office_kit.py
Writes art/exports/lot_office_kit.fbx and art/previews/lot_kit_office.png. KIT_NO_RENDER=1 skips
the render. Blender axes, studs: Z up, the office faces -Y, origin at the bottom centre of its
footprint like LotModels.office. Blender +X is the game's -X (map_kit.P mirrors it).
"""

import math
import os
import re
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_kit  # noqa: E402
import mmkit  # noqa: E402
from kitdsl import B, C, E  # noqa: E402
from mascots import flatten, num, stage  # noqa: E402

STUD = mmkit.STUD
P = map_kit.P
LUAU = os.path.join(mmkit.REPO, "src", "shared", "Models", "LotModels.luau")
MAX_TRIS = 2000  # ART_STYLE prop limit
LEVELS = 6
FLOOR_H = 4.2  # same floor height and footprint as the part office, so the logo sits the same
W = D = 9


def BV(at, size, color, bevel=0.12, rot=(0, 0, 0)):
    return B(at, size, color, rot, bevel)


def part(name, s, hit=False):
    """A shape the game builds as a plain part (glow) or an invisible hitbox."""
    s["name"] = name
    s["hit"] = hit
    return s


def trailer(tint):
    """Level 0: the star trailer on blocks. Door on the game's left (Blender +X)."""
    body = [
        BV((0, 0, 3.2), (9, 5, 4), "OffWhite", 0.45),
        BV((0, 0, 5.45), (9.4, 5.4, 0.5), "Steel", 0.15),
        # Door with a frame and handle, window with a frame and sill, a porch light.
        B((2.2, -2.52, 2.9), (2.1, 0.12, 3.5), "Steel"),
        B((2.2, -2.58, 2.9), (1.8, 0.12, 3.2), "Burgundy"),
        B((1.55, -2.66, 2.7), (0.15, 0.1, 0.5), "Gold"),
        B((-1.8, -2.52, 3.8), (3.3, 0.12, 1.7), "Steel"),
        B((-1.8, -2.58, 3.8), (3.0, 0.12, 1.4), "Glass"),
        B((-1.8, -2.58, 3.8), (0.15, 0.14, 1.4), "Steel"),
        B((-1.8, -2.7, 3.0), (3.4, 0.3, 0.15), "Steel"),
        B((0.7, -2.62, 4.6), (0.35, 0.2, 0.35), "Light"),
        # Side windows, a back hatch, the hitch and the roof clutter.
        B((4.52, 0, 3.8), (0.12, 2.2, 1.2), "Glass"),
        B((-4.52, 0, 3.8), (0.12, 2.2, 1.2), "Glass"),
        B((0, 2.52, 2.6), (2.6, 0.12, 1.4), "Steel"),
        BV((-4.9, 0, 1.4), (1.4, 0.6, 0.4), "Charcoal", 0.08),
        BV((-1.5, 0.6, 6.2), (2.4, 2.2, 1.0), "Steel", 0.12),
        C((-1.5, 0.6, 6.75), 0.7, 0.12, "Charcoal", seg=10),
        C((2.5, 1.2, 5.9), 0.3, 0.5, "Charcoal", seg=8),
        # Steps and the awning's poles.
        BV((2.2, -3.2, 0.9), (2, 1.2, 0.6), "Steel", 0.08),
        BV((2.2, -3.1, 0.35), (2.2, 1.4, 0.4), "Charcoal", 0.05),
    ]
    for x in (1.0, 3.4):
        body.append(C((x, -4.0, 2.6), 0.08, 4.8, "Steel", seg=6))
    for x in (-3, 3):  # blocks with a wheel between
        body.append(BV((x, 0, 0.6), (1.2, 4, 1.2), "Charcoal", 0.1))
    for y in (-2.0, 2.0):
        body.append(C((0, y, 1.0), 0.9, 0.5, "Charcoal", rot=(90, 0, 0), seg=12))
        body.append(C((0, y * 1.02, 1.0), 0.45, 0.52, "Steel", rot=(90, 0, 0), seg=8))
    accent = [
        BV((0, 0, 2.6), (9.1, 5.1, 0.7), tint, 0.1),
        BV((0, 0, 4.8), (9.06, 5.06, 0.18), tint, 0.04),  # thin pin stripe under the roof
        BV((2.2, -3.2, 5.0), (3, 1.8, 0.2), tint, 0.06),
    ]
    parts = [
        part("Hitbox", B((0, 0, 2.85), (9.4, 5.4, 5.7), "#FFFFFF"), hit=True),
        part("TrailerStar", B((2.2, -2.7, 3.9), (0.9, 0.1, 0.9), "Gold", rot=(0, 45, 0), neon=True)),
    ]
    return body, accent, parts


def window(x, y, z, face, w=2.0, h=1.8):
    """A framed window with a sill on the face pointing `face` (-1 front, 1 back, 'L'/'R' sides)."""
    if face in (-1, 1):
        o = face * (D / 2)
        return [
            B((x, y + o + face * 0.06, z), (w + 0.4, 0.12, h + 0.4), "Burgundy"),
            B((x, y + o + face * 0.12, z), (w, 0.12, h), "Glass"),
            B((x, y + o + face * 0.14, z), (0.15, 0.12, h), "Cream"),
            B((x, y + o + face * 0.25, z - h / 2 - 0.2), (w + 0.6, 0.4, 0.2), "Cream"),
        ]
    s = 1 if face == "L" else -1
    o = s * (W / 2)
    return [
        B((o + s * 0.06, y, z), (0.12, w + 0.4, h + 0.4), "Burgundy"),
        B((o + s * 0.12, y, z), (0.12, w, h), "Glass"),
        B((o + s * 0.25, y, z - h / 2 - 0.2), (0.4, w + 0.6, 0.2), "Cream"),
    ]


def office(lv, tint):
    """Levels 1-5: two cream floors (1-2) or a glass tower of `lv` floors (3-5)."""
    floors = 2 if lv <= 2 else lv
    glass = lv >= 3
    body, accent = [], []
    body += [
        BV((0, 0, 0.5), (W + 0.6, D + 0.6, 1), "Burgundy", 0.1),
        B((0, 0, 1.05), (W + 0.8, D + 0.8, 0.1), "Gold"),
    ]
    for f in range(floors):
        z = 1 + f * FLOOR_H
        if glass:
            body += [
                B((0, 0, z + (FLOOR_H - 0.6) / 2), (W, D, FLOOR_H - 0.6), "Glass"),
                BV((0, 0, z + FLOOR_H - 0.3), (W + 0.4, D + 0.4, 0.6), "Cream", 0.1),
            ]
            for x in (-W / 2, W / 2):
                for y in (-D / 2, D / 2):
                    body.append(B((x, y, z + (FLOOR_H - 0.6) / 2), (0.6, 0.6, FLOOR_H - 0.6), "Cream"))
            # Thin mullions split each face in three; the ground floor's front is the lobby.
            for k in (-1.5, 1.5):
                if f > 0:
                    body.append(B((k, -D / 2 - 0.05, z + (FLOOR_H - 0.6) / 2), (0.22, 0.2, FLOOR_H - 0.6), "Cream"))
                body.append(B((k, D / 2 + 0.05, z + (FLOOR_H - 0.6) / 2), (0.22, 0.2, FLOOR_H - 0.6), "Cream"))
                body.append(B((W / 2 + 0.05, k, z + (FLOOR_H - 0.6) / 2), (0.2, 0.22, FLOOR_H - 0.6), "Cream"))
                body.append(B((-W / 2 - 0.05, k, z + (FLOOR_H - 0.6) / 2), (0.2, 0.22, FLOOR_H - 0.6), "Cream"))
            if f > 0:  # a light-blue transom band halfway up each upper floor
                body.append(B((0, -D / 2 - 0.04, z + 2.6), (W - 0.6, 0.12, 0.14), "Cream"))
        else:
            body.append(BV((0, 0, z + FLOOR_H / 2), (W, D, FLOOR_H), "Cream", 0.08))
            mid = z + FLOOR_H / 2 + 0.3
            for i in (-1, 0, 1):
                if f > 0 or i != 0:  # the ground floor's middle is the door
                    body += window(i * 2.8, 0, mid, -1)
                body += window(i * 2.8, 0, mid, 1)
            for i in (-1, 1):
                body += window(0, i * 2.2, mid, "L", 1.6)
                body += window(0, i * 2.2, mid, "R", 1.6)
            body.append(BV((0, 0, z + FLOOR_H), (W + 0.2, D + 0.2, 0.4), "Burgundy", 0.06))
        for x in (-W / 2, W / 2):  # corner pilasters on the cream office
            if not glass:
                for y in (-D / 2, D / 2):
                    body.append(B((x, y, z + FLOOR_H / 2), (0.5, 0.5, FLOOR_H), "Cream"))
    top = 1 + floors * FLOOR_H
    body += [
        BV((0, 0, top + 0.4), (W + 0.8, D + 0.8, 0.8), "Burgundy", 0.15),
        B((0, 0, top + 0.02), (W + 0.9, D + 0.9, 0.15), "Gold"),
    ]
    # Parapet lip round the roof.
    for y in (-(D + 0.8) / 2 + 0.2, (D + 0.8) / 2 - 0.2):
        body.append(B((0, y, top + 1.0), (W + 0.8, 0.4, 0.4), "Cream"))
    for x in (-(W + 0.8) / 2 + 0.2, (W + 0.8) / 2 - 0.2):
        body.append(B((x, 0, top + 1.0), (0.4, D, 0.4), "Cream"))

    # Entrance: framed glass door, steps, a canopy (accent) on a burgundy fascia with two lamps.
    body += [
        B((0, -D / 2 - 0.1, 2.75), (3.2, 0.2, 3.5), "Cream"),
        B((0, -D / 2 - 0.25, 2.6), (2.6, 0.3, 3.2), "DoorGlass"),
        B((0, -D / 2 - 0.42, 2.6), (0.15, 0.1, 3.2), "Gold"),
        BV((0, -D / 2 - 0.9, 1.1), (4.4, 1.6, 0.2), "Paving", 0.05),
        B((0, -D / 2 - 1.0, 4.15), (4.6, 2.1, 0.12), "Burgundy"),
        B((0, -D / 2 - 2.0, 4.4), (4.5, 0.12, 0.45), "Burgundy"),
    ]
    for x in (-1.9, 1.9):
        body.append(B((x, -D / 2 - 0.15, 3.0), (0.3, 0.3, 0.5), "Light"))
    accent.append(BV((0, -D / 2 - 1, 4.4), (4.4, 2, 0.4), tint, 0.08))
    accent.append(B((0, -(D + 0.8) / 2 - 0.06, top + 0.4), (W + 0.2, 0.14, 0.35), tint))  # roof stripe

    parts = [part("Hitbox", B((0, 0, (top + 0.8) / 2), (W + 0.8, D + 0.8, top + 0.8), "#FFFFFF"), hit=True)]
    # Roof clutter: a hatch on the small office, AC unit + antenna from level 2, logo at 5.
    if lv == 1:
        body += [
            BV((2.2, 2.2, top + 1.05), (1.6, 1.6, 0.5), "Steel", 0.06),
            C((-2.5, 2.5, top + 1.0), 0.35, 0.4, "Charcoal", seg=8),
        ]
    elif lv < 5:
        body += [
            BV((-2, 2, top + 1.5), (2.4, 2.4, 1.4), "Steel", 0.12),
            C((-2, 2, top + 2.25), 0.75, 0.12, "Charcoal", seg=10),
            BV((-2, 2.2, top + 0.9), (2.6, 2.6, 0.2), "Charcoal", 0.04),
            C((2.5, 2.5, top + 2.8), 0.15, 4, "Steel", seg=6),
            C((2.5, 2.5, top + 1.0), 0.45, 0.4, "Charcoal", seg=8),
            B((2.5, 2.5, top + 3.6), (1.2, 0.1, 0.1), "Steel"),
        ]
        parts.append(part("AntennaLight", E((2.5, 2.5, top + 4.9), (0.3, 0.3, 0.3), "Carpet", neon=True)))
    else:
        body += [
            BV((2.6, 2.6, top + 1.3), (1.8, 1.8, 1.0), "Steel", 0.1),
            BV((-2.6, 2.8, top + 1.15), (1.6, 1.4, 0.7), "Steel", 0.08),
        ]
    return body, accent, parts


def look(lv, tint="#FFFFFF"):
    return trailer(tint) if lv == 0 else office(lv, tint)


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
    out = ["local OFFICE_MESH: { [number]: OfficeMesh } = {"]
    for lv, body, accent, parts in rows:
        out.append(f"\t[{lv}] = {{")
        for key, obj in (("body", body), ("accent", accent)):
            c, s = roblox_bounds(obj)
            out.append(f"\t\t{key} = {{ center = {vec(c)}, size = {vec(s)} }},")
        out.append("\t\tparts = {")
        for s, m, _ in flatten(parts, []):
            _, _, size = map_kit.to_roblox(s, m)
            hex_ = "hitbox" if s["hit"] else s["color"].lstrip("#")
            ball = "true" if s["kind"] == "ball" else "false"
            neon = "true" if s["neon"] else "false"
            out.append(
                f"\t\t\t{{ name = \"{s['name']}\", cf = CFrame.new({map_kit.cframe(s, m)}), size = {vec(size)}, color = \"{hex_}\", neon = {neon}, ball = {ball} }},"
            )
        out.append("\t\t},")
        out.append("\t},")
    out.append("}")
    return out


def write_luau(rows):
    with open(LUAU) as f:
        src = f.read()
    begin = "-- BEGIN lot_office_kit (generated by art/blender/lot_office_kit.py; do not edit by hand)\n"
    end = "-- END lot_office_kit\n"
    block = begin + "\n".join(luau_table(rows)) + "\n" + end
    pattern = re.compile(re.escape(begin) + ".*?" + re.escape(end), re.S)
    assert pattern.search(src), "LotModels.luau is missing the lot_office_kit markers"
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
    for lv in range(LEVELS):
        body_s, accent_s, parts_s = look(lv)
        body = build_shapes(f"LotOffice{lv}", body_s)
        accent = build_shapes(f"LotOffice{lv}Accent", accent_s)
        t = tris(body) + tris(accent)
        _, s = roblox_bounds(body)
        print(f"LotOffice{lv}: {t} tris ({tris(accent)} accent), {s.x:.1f} x {s.y:.1f} x {s.z:.1f} studs, {len(parts_s)} parts")
        assert t <= MAX_TRIS, f"LotOffice{lv} is over its triangle budget"
        for o in (body, accent):
            mmkit.bake_vertex_colors(o.data)
            objs.append(o)
        rows.append((lv, body, accent, parts_s))
    write_luau(rows)

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    out = os.path.join(mmkit.EXPORTS, "lot_office_kit.fbx")
    bpy.ops.export_scene.fbx(
        filepath=out, use_selection=True, global_scale=1 / (STUD * 100), apply_unit_scale=True,
        bake_space_transform=True, colors_type="SRGB", axis_forward="-Y", axis_up="Z",
        mesh_smooth_type="FACE", add_leaf_bones=False,
    )
    print("Exported", out)
    if not os.environ.get("KIT_NO_RENDER"):
        preview()


def reel(at):
    """The level-5 rooftop film reel, drawn in the preview only (the game uses FilmReelLogo)."""
    x, y, z = at
    out = [B((x, y, z + 1), (1, 1, 2), "Charcoal"), C((x, y, z + 5), 3, 0.8, "Gold", rot=(90, 0, 0), seg=20)]
    out.append(C((x, y - 0.1, z + 5), 0.5, 1.0, "Burgundy", rot=(90, 0, 0), seg=10))
    for i in range(5):
        a = math.radians(i * 72 + 90)
        out.append(C((x + 1.8 * math.cos(a), y - 0.1, z + 5 + 1.8 * math.sin(a)), 0.5, 0.9, "Navy", rot=(90, 0, 0), seg=10))
    return out


def preview():
    """All six looks side by side, accent tinted lot red, the game's glowing parts drawn."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shown = []
    x = 0.0
    for lv in range(LEVELS):
        body_s, accent_s, parts_s = look(lv, "#C8202F")
        drawn = [s for s in parts_s if not s["hit"]]
        if lv == 5:
            drawn += reel((0, 0, 1 + 5 * FLOOR_H + 0.8))
        group = [build_shapes(f"P{lv}{k}", sh) for k, sh in (("b", body_s), ("a", accent_s), ("p", drawn)) if sh]
        wd = 10
        x += wd / 2
        for o in group:
            o.location = (STUD * x, 0, 0)
            o.rotation_euler = (0, 0, math.radians(-20))
            shown.append(o)
        x += wd / 2 + 4
    for o in shown:
        o.location.x -= STUD * x / 2
    stage(shown, "lot_kit_office.png", 2400, 1000, 1.1, 18)


if __name__ == "__main__":
    main()
