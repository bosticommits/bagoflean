"""The little shape language the map kit is written in (map_kit.py, town_kit.py).

A model is a list of shapes in studs, Blender axes: Z up, the model faces -Y, standing on Z = 0.
map_kit.py turns each list into one flat-shaded low-poly mesh (exported to map_kit.fbx) and into
src/shared/Models/MapKitShapes.luau, which the game builds as parts until the meshes are imported.

  B box, C cylinder, K cone, E smooth ellipsoid, L faceted blob, W wedge, S star, H hill,
  G group (moves and turns its children), T a named spot the game uses (sign text, effects).
"""

import math

# Colors: the game palette (Build.Palette) plus the outer ring's and the town's own.
COL = {
    "Cream": "#F4E7CF",
    "Burgundy": "#7A1F2B",
    "Carpet": "#C8202F",
    "Gold": "#F5B82E",
    "Blue": "#2E86DE",
    "Navy": "#1B2340",
    "Green": "#5BBF5A",
    "DarkGreen": "#388C46",
    "Charcoal": "#2E2C34",
    "Steel": "#6E7078",
    "Bark": "#7A5434",
    "Wood": "#96623C",
    "Light": "#FFECBE",
    "OffWhite": "#FAF6EC",
    "Glass": "#96CDF0",
    "Paving": "#D6C8B0",
    "Asphalt": "#8C8A86",
    "Leaf": "#4FB548",
    "LeafDark": "#2F8F3E",
    "LeafLight": "#7ED35F",
    "Pine": "#24704A",
    "PineDark": "#1B5A3C",
    "Blossom": "#FFA0CD",
    "BlossomDark": "#F27BB4",
    "Cactus": "#46AF50",
    "CactusDark": "#368C40",
    "Sand": "#F0CD8C",
    "Dust": "#DEAA6E",
    "Rock": "#D67C48",
    "RockDark": "#B5613A",
    "RockLight": "#E89A62",
    "Stone": "#B0B6C2",
    "Iron": "#2A3A34",
    "ParkGreen": "#2F6B4F",
    "Flame": "#FFB347",
    "Water": "#40C4F0",
    "WaterLight": "#82DEFA",
    "Pink": "#FF78AA",
    "Teal": "#20B2BE",
    "Purple": "#A04DFF",
    "Chroma": "#28C85A",
    "Chrome": "#D7DAE1",
    "Duck": "#FFD63C",
    "Orange": "#FF8C28",
    "DoorGlass": "#3A5A8C",
}


def shade(hex_color, amount):
    """Darker (amount > 0) or lighter (amount < 0) version of a hex color."""
    h = COL.get(hex_color, hex_color).lstrip("#")
    rgb = [int(h[i : i + 2], 16) for i in (0, 2, 4)]
    if amount >= 0:
        rgb = [round(v * (1 - amount)) for v in rgb]
    else:
        rgb = [round(v + (255 - v) * -amount) for v in rgb]
    return "#" + "".join(f"{v:02X}" for v in rgb)


def c(name):
    return COL.get(name, name)


def B(at, size, color, rot=(0, 0, 0), bevel=0.0, neon=False):
    """Box centred on `at`. A bevel rounds its edges (the mesh only; parts stay square)."""
    return {"kind": "box", "at": at, "size": size, "color": c(color), "rot": rot, "bevel": bevel, "neon": neon}


def C(at, radius, length, color, rot=(0, 0, 0), seg=12, neon=False):
    """Cylinder centred on `at`, its axis along local Z."""
    return {"kind": "cyl", "at": at, "size": (2 * radius, 2 * radius, length), "color": c(color), "rot": rot, "seg": seg, "neon": neon}


def K(at, r_bottom, r_top, length, color, rot=(0, 0, 0), seg=8, neon=False):
    """Cone (or tapered cylinder) centred on `at`, axis along local Z, wide end down."""
    return {
        "kind": "cone", "at": at, "size": (2 * r_bottom, 2 * r_bottom, length), "top": r_top / r_bottom,
        "color": c(color), "rot": rot, "seg": seg, "neon": neon,
    }


def E(at, radii, color, rot=(0, 0, 0), neon=False):
    """Smooth ellipsoid centred on `at` with half-sizes `radii`."""
    return {"kind": "ball", "at": at, "size": tuple(2 * r for r in radii), "color": c(color), "rot": rot, "neon": neon}


def L(at, radii, color, rot=(0, 0, 0), jitter=0.07):
    """Faceted low-poly blob (foliage, rocks); a ball in the part version. Its facets take
    slightly different shades of the color, so it reads as low-poly from any side."""
    return {"kind": "blob", "at": at, "size": tuple(2 * r for r in radii), "color": c(color), "rot": rot, "neon": False, "jitter": jitter}


def W(at, size, color, rot=(0, 0, 0)):
    """Wedge like a Roblox WedgePart: tall side at local +Y (the back), slope facing -Y and up."""
    return {"kind": "wedge", "at": at, "size": size, "color": c(color), "rot": rot, "neon": False}


def S(at, radius, depth, color, rot=(0, 0, 0), neon=False):
    """Five-point star standing up, facing -Y, `depth` thick. Two crossed squares in the part
    version."""
    return {"kind": "star", "at": at, "size": (2 * radius, depth, 2 * radius), "color": c(color), "rot": rot, "neon": neon}


def H(at, radius, color, jitter=0.05):
    """A big faceted hill (a finely cut sphere, so the ground height stays close to a true
    sphere's), sunk into the ground by the caller."""
    return {"kind": "hill", "at": at, "size": (2 * radius,) * 3, "color": c(color), "rot": (0, 0, 0), "neon": False, "jitter": jitter}


def T(at, size, name, rot=(0, 0, 0)):
    """A named spot (not drawn): a thin board the game letters a sign on (its front faces -Y),
    or a place for an effect. Written to MapKitShapes.Spots."""
    return {"kind": "spot", "at": at, "size": size, "name": name, "color": "#FFFFFF", "rot": rot, "neon": False}


def G(at, rot, *children):
    return {"kind": "group", "at": at, "rot": rot, "children": children}


def mirror_x(shapes):
    out = []
    for s in shapes:
        rx, ry, rz = s["rot"]
        m = {**s, "at": (-s["at"][0], *s["at"][1:]), "rot": (rx, -ry, -rz)}
        if s["kind"] == "group":
            m["children"] = tuple(mirror_x(list(s["children"])))
        out.append(m)
    return out


def ring(n, radius, z, make, start=0.0):
    """`make(x, y, angle_deg)` for n points round a circle."""
    out = []
    for i in range(n):
        a = start + i * 360 / n
        out.append(make(math.sin(math.radians(a)) * radius, math.cos(math.radians(a)) * radius, a))
    return out
