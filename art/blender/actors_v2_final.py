"""Actors v2 FINAL: build all 30 approved actors, QA them, export one FBX per actor (five rig pieces named
<ActorId>_<Body|Head|ArmL|ArmR|Base>, 1/28 scale, baked vertex colours) and write the rig data the game needs.

Approved sources (every actor was user-approved on the Command Center 2026-11-14):
  actors_v2.py     Nervous Intern (variant A), Werewolf Pup, Captain Squawk
  actors_v2_b1..b4 the other 27 (b4 = the 9 new ones need only 7 here: Pup + Squawk are in actors_v2.py)
  actors_v2_fix.py overrides Hot Dog Mascot (variant A), Teen Heartthrob, Brain in a Jar

Run live in Blender (MCP execute_blender_code), a few actors per call because of the AO bake:
  import importlib.util as u; s = u.spec_from_file_location("fin", PATH); m = u.module_from_spec(s)
  s.loader.exec_module(m); m.run_chunk(m.KEYS[0:6])
Each chunk writes art/exports/actors_v2/<ActorId>.fbx and merges its numbers into art/actors_v2_rigs.json.
Then, with plain python (no Blender):  python3 art/blender/actors_v2_final.py   -> src/shared/Models/ActorShapes.luau

Coordinates: studs, Z up, the actor faces -Y, feet on Z = 0 (the plinth sits below), own left is +X. Roblox space
is (-x, z, y): ActorShapes values are in that space like the 21-actor file (art/blender/actors.py) wrote them.
"""

import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
EXPORT_DIR = os.path.join(REPO, "art", "exports", "actors_v2")
RIGS_JSON = os.path.join(REPO, "art", "actors_v2_rigs.json")
LUAU_OUT = os.path.join(REPO, "src", "shared", "Models", "ActorShapes.luau")
STUD = 0.28
PIECES = ("Body", "Head", "ArmL", "ArmR", "Base")
NEW9 = ("WerewolfPup", "PirateCaptain", "CardboardAstronaut", "RodeoRookie", "WobblyWitch", "LagoonMermaid", "TimeTourist", "CaptainKapow", "InspectorWhoops")

# The final registry: key in actors_v2.ACTORS -> built by the module that holds the approved version.
KEYS = (
    ["intern", "pup", "squawk"]
    + ["stunt", "zombie", "soap", "hotdog", "robot", "commando", "vent"]  # b1 (hotdog = fix variant A)
    + ["villain", "heart", "knight", "alien", "king", "scream", "cupid"]  # b2 (heart = fix)
    + ["diva", "clown", "brain", "muse", "mech", "phantom"]  # b3 (brain = fix)
    + ["astro", "rodeo", "witch", "mermaid", "tourist", "kapow", "inspector"]  # b4
)

CAPS = {"Newcomer": 1900, "Rising": 1900, "Pro": 2000, "Star": 2200, "Superstar": 2500, "Legend": 2500, "Icon": 2500}


# --- Blender side -----------------------------------------------------------------------------


def _modules():
    sys.path.insert(0, HERE)
    import actors_v2 as K
    import actors_v2_b1, actors_v2_b2, actors_v2_b3, actors_v2_b4  # noqa: F401
    import actors_v2_fix  # noqa: F401  (last: overrides hotdog / heart / brain in K.ACTORS)

    K.INTERN_VARIANT = "A"
    return K


def _srgb_hex(lin_rgb):
    out = []
    for c in lin_rgb[:3]:
        c = max(0.0, min(1.0, float(c)))
        s = c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
        out.append(round(max(0.0, min(1.0, s)) * 255))
    return "%02X%02X%02X" % tuple(out)


def _piece_data(K, obj):
    """Bounds, vertices (studs, Blender space) and per-corner colours for one piece."""
    import numpy as np

    me = obj.data
    n = len(me.vertices)
    co = np.empty(n * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) / STUD
    return co


def _roblox(p):
    return (-p[0], p[2], p[1])


def _bounds(co):
    lo, hi = co.min(axis=0), co.max(axis=0)
    size = (float(hi[0] - lo[0]), float(hi[2] - lo[2]), float(hi[1] - lo[1]))  # Roblox size: x, y(up), z(depth)
    ctr_b = ((lo + hi) / 2).tolist()
    return size, _roblox(ctr_b), lo.tolist(), hi.tolist()


def _free_arm(co, lo, hi):
    """A plain hanging arm: short, hangs below its shoulder. Returns the shoulder pivot (Blender xyz) or None."""
    import numpy as np

    if hi[2] - lo[2] > 1.9 or (hi[0] - lo[0]) > 1.2 or (hi[1] - lo[1]) > 1.3:
        return None
    top = co[co[:, 2] >= hi[2] - 0.35]
    return (float(top[:, 0].mean()), 0.0, float(hi[2]) - 0.2)


def _voxel_boxes(obj, limit=60):
    """A coarse coloured-box version of one piece (ActorShapes fallback until the mesh is in LotMeshes):
    surface samples of the mesh binned on a grid that grows until it needs at most `limit` boxes, runs of
    equal colour merged along the actor's depth. Roblox space, studs."""
    import numpy as np

    me = obj.data
    me.calc_loop_triangles()
    nv = len(me.vertices)
    co = np.empty(nv * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3) / STUD
    ncl = len(me.loops)
    col = np.empty(ncl * 4, dtype=np.float32)
    me.color_attributes["Col"].data.foreach_get("color", col)
    col = col.reshape(-1, 4)[:, :3]
    tris = me.loop_triangles
    tv = np.array([t.vertices[:] for t in tris])
    tl = np.array([t.loops[:] for t in tris])
    a, b, c = co[tv[:, 0]], co[tv[:, 1]], co[tv[:, 2]]
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1) / 2
    rng = np.random.default_rng(7)
    boxes = []
    cell = 0.45
    while True:
        per = np.maximum(1, np.ceil(area / (cell * cell) * 3).astype(int))
        idx = np.repeat(np.arange(len(tv)), per)
        r1, r2 = rng.random(len(idx)), rng.random(len(idx))
        flip = r1 + r2 > 1
        r1[flip], r2[flip] = 1 - r1[flip], 1 - r2[flip]
        w0, w1, w2 = 1 - r1 - r2, r1, r2
        pts = a[idx] * w0[:, None] + b[idx] * w1[:, None] + c[idx] * w2[:, None]
        cols = col[tl[idx, 0]] * w0[:, None] + col[tl[idx, 1]] * w1[:, None] + col[tl[idx, 2]] * w2[:, None]
        cells = np.floor(pts / cell).astype(int)
        acc = {}
        for k, cc in zip(map(tuple, cells), cols):
            e = acc.get(k)
            if e is None:
                acc[k] = [cc.astype(np.float64), 1]
            else:
                e[0] += cc
                e[1] += 1
        grid = {}
        for k, (s, n) in acc.items():
            q = tuple(int(round(int(_srgb_hex([x, x, x])[:2], 16) / 255 * 11)) for x in (s / n))  # 12 sRGB levels
            grid[k] = q
        # merge runs along Blender Y (the actor's depth), same quantised colour
        used, runs = set(), []
        for k in sorted(grid, key=lambda t: (t[0], t[2], t[1])):
            if k in used:
                continue
            j = k[1]
            while (k[0], j + 1, k[2]) in grid and grid[(k[0], j + 1, k[2])] == grid[k] and (k[0], j + 1, k[2]) not in used:
                j += 1
            for jj in range(k[1], j + 1):
                used.add((k[0], jj, k[2]))
            runs.append((k[0], k[1], j, k[2], grid[k]))
        if len(runs) <= limit or cell > 3.0:
            break
        cell *= 1.18
    for x, j0, j1, z, q in runs:
        hexq = "%02X%02X%02X" % tuple(round(v / 11 * 255) for v in q)
        lo = np.array([x * cell, j0 * cell, z * cell])
        hi = np.array([(x + 1) * cell, (j1 + 1) * cell, (z + 1) * cell])
        ctr = (lo + hi) / 2
        size = (float(hi[0] - lo[0]), float(hi[2] - lo[2]), float(hi[1] - lo[1]))  # Roblox x, y, z
        boxes.append({"cf": [round(v, 3) for v in _roblox(ctr)], "size": [round(v, 3) for v in size], "hex": hexq})
    return boxes


def collect(K, key, objs, fig):
    """Numbers for one built actor (objects still in actor space + offset)."""
    import numpy as np

    name, tier, _fn = K.ACTORS[key]
    data = {"key": key, "id": name, "tier": tier, "float": bool(getattr(fig, "float", False)), "pieces": {}}
    tris = 0
    for piece, o in objs.items():
        tris += sum(len(p.vertices) - 2 for p in o.data.polygons)
        co = _piece_data(K, o)
        size, ctr, lo, hi = _bounds(co)
        rec = {"size": [round(v, 3) for v in size], "center": [round(v, 3) for v in ctr], "lo": [round(v, 3) for v in lo], "hi": [round(v, 3) for v in hi]}
        if piece == "Head":
            col = co[(np.abs(co[:, 0]) < 0.8) & (np.abs(co[:, 1]) < 0.8)]
            zmin = float(col[:, 2].min()) if len(col) else lo[2]
            rec["neck_z"] = round(zmin + 0.25, 3)
        if piece in ("ArmL", "ArmR"):
            rec["free_pivot"] = _free_arm(co, lo, hi)
        if piece == "Base" or name in NEW9:
            pass
        if name in NEW9 and piece != "Base":
            rec["voxel"] = _voxel_boxes(o)
        data["pieces"][piece] = rec
        data["tris_" + piece] = sum(len(p.vertices) - 2 for p in o.data.polygons)
    data["tris"] = tris
    data["cap"] = CAPS[tier]
    return data


def export_actor(K, objs, name):
    import bpy

    os.makedirs(EXPORT_DIR, exist_ok=True)
    ol = list(objs.values())
    old = {o: o.location.copy() for o in ol}
    for o in ol:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    path = os.path.join(EXPORT_DIR, f"{name}.fbx")
    K.export_fbx(ol, path)
    for o, loc in old.items():
        o.location = loc
    bpy.context.view_layer.update()
    return path


def run_chunk(keys, export=True):
    """Build `keys` (a few at a time), AO + smooth + QA via actors_v2.main, export one FBX each, merge rig data."""
    K = _modules()
    sc, built, report = K.main(tuple(keys))
    out = {}
    for key in keys:
        fig, objs = built[key]
        d = collect(K, key, objs, fig)
        r = report[key]
        d["qa"] = {"ngons": r["ngons"], "flipped": r["flipped"], "issues": r["issues"], "floating": [list(map(str, f)) for f in r["floating"]], "size_studs": r["size_studs"]}
        names = sorted(o.name for o in objs.values())
        d["objects"] = names
        if export:
            d["fbx"] = export_actor(K, objs, d["id"])
        out[d["id"]] = d
    allr = {}
    if os.path.exists(RIGS_JSON):
        allr = json.load(open(RIGS_JSON))
    allr.update(out)
    json.dump(allr, open(RIGS_JSON, "w"), indent=1, sort_keys=True)
    return {k: (v["tris"], v["cap"], v["qa"]["flipped"], v["qa"]["ngons"], v["qa"]["issues"], v["objects"]) for k, v in out.items()}


# --- plain python side: ActorShapes.luau ------------------------------------------------------


def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def vec(v):
    return "Vector3.new(" + ", ".join(num(c) for c in v) + ")"


def old_shape_blocks(text):
    """{actorId: {piece: 'shapes block text'}, wave: {...}} parsed out of the existing 21-actor file."""
    blocks, waves = {}, {}
    for m in re.finditer(r"^ActorShapes\.Actors\.(\w+) = \{\n(.*?)^\}\n", text, re.S | re.M):
        aid, body = m.group(1), m.group(2)
        w = re.search(r'^\twave = "(\w+)"', body, re.M)
        waves[aid] = w.group(1) if w else None
        blocks[aid] = {}
        for pm in re.finditer(r"^\t\t(\w+) = \{\n(.*?)^\t\t\},\n", body, re.S | re.M):
            sm = re.search(r"^\t\t\tshapes = \{\n(.*?)^\t\t\t\},\n", pm.group(2), re.S | re.M)
            blocks[aid][pm.group(1)] = sm.group(1) if sm else ""
    return blocks, waves


def pivots(rec_pieces, flt, name):
    """Pivots in Roblox space (the point each piece turns about), from the final meshes."""
    out = {}
    body = rec_pieces["Body"]
    hip = 1.45
    if flt:
        hip = body["center"][1]
    out["Body"] = (0.0, round(min(max(hip, body["lo"][2] + 0.5), body["hi"][2]), 3), 0.0)
    head = rec_pieces["Head"]
    out["Head"] = (0.0, head.get("neck_z", 2.5), 0.0)
    for arm, sign in (("ArmL", 1), ("ArmR", -1)):  # Blender +X = the actor's left
        rec = rec_pieces[arm]
        fp = rec.get("free_pivot")
        if fp is not None:
            out[arm] = (round(-fp[0], 3), round(fp[2], 3), 0.0)
        else:
            out[arm] = (round(-sign * 1.1, 3), 2.4, 0.0)
    out["Base"] = (0.0, 0.0, 0.0)
    return out


def write_luau(rigs, order):
    text = open(LUAU_OUT).read()
    old_blocks, old_waves = old_shape_blocks(text)
    head = text.split("ActorShapes.Actors = {} :: { [string]: Rig }\n")[0] + "ActorShapes.Actors = {} :: { [string]: Rig }\n\n"
    head = head.replace(
        "-- GENERATED by art/blender/actors.py from the Blender actor designs. Do not edit by hand:\n-- change the shapes there and run it again.",
        "-- GENERATED by art/blender/actors_v2_final.py (from the Actors v2 Blender meshes, art/actors_v2_rigs.json). Do not edit by hand:\n-- change the models and run it again. `shapes` is only the part fallback (the 21 original actors keep their\n-- old part shapes; the 9 new actors get a coarse coloured-box version of their mesh).",
    )
    lines = [head.rstrip("\n"), ""]
    for aid in order:
        r = rigs[aid]
        pcs = r["pieces"]
        pv = pivots(pcs, r["float"], aid)
        wave = None
        free = [a for a in ("ArmR", "ArmL") if pcs[a].get("free_pivot") is not None]
        pref = old_waves.get(aid)
        if pref in free:
            wave = pref
        elif free:
            wave = free[0]
        lines.append(f"ActorShapes.Actors.{aid} = {{")
        if wave:
            lines.append(f'\twave = "{wave}",')
        if r["float"]:
            lines.append("\tfloat = true,")
        lines.append("\tpieces = {")
        for piece in PIECES:
            rec = pcs[piece]
            lines.append(f"\t\t{piece} = {{")
            lines.append(f"\t\t\tpivot = {vec(pv[piece])},")
            lines.append(f"\t\t\tsize = {vec(rec['size'])},")
            lines.append(f"\t\t\tcenter = {vec(rec['center'])},")
            lines.append("\t\t\tshapes = {")
            if aid not in NEW9 and aid in old_blocks and piece in old_blocks[aid]:
                lines.append(old_blocks[aid][piece].rstrip("\n"))
            elif piece == "Base":
                hex_top = {"Newcomer": "A7A9AC", "Rising": "4CC764", "Pro": "3A8DFF", "Star": "A04DFF", "Superstar": "FFC21A", "Legend": "FF5A2E", "Icon": "FF5FD2"}[r["tier"]]
                lines.append(f'\t\t\t\tS("cyl", CFrame.new(0, -0.3, 0), Vector3.new(3.5, 0.35, 3.5), "{hex_top}"),')
                lines.append('\t\t\t\tS("cyl", CFrame.new(0, -0.57, 0), Vector3.new(3.7, 0.1, 3.7), "3A2E4A"),')
            else:
                for b in rec.get("voxel", []):
                    lines.append(f'\t\t\t\tS("box", CFrame.new({", ".join(num(c) for c in b["cf"])}), {vec(b["size"])}, "{b["hex"]}"),')
            lines.append("\t\t\t},")
            lines.append("\t\t},")
        lines.append("\t},")
        lines.append("}")
        lines.append("")
    lines.append("return ActorShapes")
    open(LUAU_OUT, "w").write("\n".join(lines) + "\n")
    print("Wrote", LUAU_OUT, len(order), "actors")


ORDER = [
    "NervousIntern", "StuntDouble", "BackgroundExtra", "WerewolfPup", "CardboardAstronaut",
    "SoapRegular", "AdModel", "IndieSidekick", "RodeoRookie", "WobblyWitch",
    "ActionVeteran", "ComedyDuo", "NightShiftVillain", "LagoonMermaid", "TimeTourist",
    "TeenHeartthrob", "MethodActor", "SpaceCaptain", "CaptainKapow", "InspectorWhoops",
    "BoxOfficeKing", "ScreamQueen", "RomComSweetheart", "PirateCaptain",
    "GoldenAgeDiva", "SilentEraClown", "SciFiVisionary",
    "MogulsMuse", "LastActionHero", "PhantomAuteur",
]

if __name__ == "__main__":
    rigs = json.load(open(RIGS_JSON))
    missing = [a for a in ORDER if a not in rigs]
    assert not missing, f"no rig data for {missing}; run run_chunk in Blender first"
    write_luau(rigs, ORDER)
