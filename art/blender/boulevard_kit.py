"""Boulevard kit: the tall buildings that line Hollywood Boulevard. map_kit.py builds them together
with its own models and town_kit.py's into the one map_kit.fbx and the one MapKitShapes.luau, so
run that file, not this one.

  Narrow (16 wide, 20 deep; they stand in pairs at the front of each path between the lots)
    Apartments<Color>   four floors, a shop on the ground floor, a billboard and a water tank on
                        the roof. Spots: Shop, Billboard
    CostumeShop<Color>  three floors, big display windows, a bulb-lit blade sign. Spots: Shop,
                        Blade and BladeBack (its two faces)
    RadioStation        three floors with an art deco top and a lattice mast with a red beacon.
                        Spot: Sign
    StarCafe            two floors, a striped awning, a tall googie pylon sign on the roof.
                        Spots: Shop, Pylon
  Wide (30 wide, 24 deep; they close each end of the boulevard)
    HotelStardust       five floors with two side wings, an entrance canopy and a bulb-lit
                        rooftop sign. Spots: Canopy, Roof
    SunsetTower         a stepped art deco tower with gold fins and a spire. Spot: Sign

Chunky low-poly toy style (ART_STYLE.md): bevelled main blocks, cream and gold trim, glowing
bulbs, flat shading, the game palette. Words are never modelled: each sign has a named spot (T)
where the game letters it. Blender axes, in studs: Z up, the model faces -Y, standing on Z = 0.
Every building is a closed, solid block: players walk round them, not into them.
"""

from kitdsl import B, C, G, K, L, S, T, shade  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.15, neon=False):
    return B(at, size, color, rot, bevel, neon)


def window(x, y, z, w, h, frame="Cream", glass="Glass", sill=True):
    """A window on a front wall whose face is at `y` (facing -Y): frame, glass and a sill."""
    s = [
        B((x, y - 0.15, z), (w + 0.7, 0.3, h + 0.7), frame),
        B((x, y - 0.25, z), (w, 0.3, h), glass),
        B((x, y - 0.27, z), (0.25, 0.3, h), frame),
    ]
    if sill:
        s.append(BV((x, y - 0.45, z - h / 2 - 0.45), (w + 1.2, 0.9, 0.35), frame, bevel=0.06))
    return s


def side_window(x, y, z, w, h, frame="Cream", glass="Glass"):
    """A window on a side wall whose face is at `x` (either side; the sign of x picks it)."""
    out = 1 if x > 0 else -1
    return [
        B((x + out * 0.15, y, z), (0.3, w + 0.7, h + 0.7), frame),
        B((x + out * 0.25, y, z), (0.3, w, h), glass),
    ]


def back_window(x, y, z, w, h, frame="Cream", glass="Glass"):
    """A plain window on a back wall whose face is at `y` (facing +Y)."""
    return [
        B((x, y + 0.15, z), (w + 0.7, 0.3, h + 0.7), frame),
        B((x, y + 0.25, z), (w, 0.3, h), glass),
    ]


def bulbs(x0, x1, y, z, n, neon=True):
    step = (x1 - x0) / (n - 1)
    return [BV((x0 + i * step, y, z), (0.42, 0.3, 0.42), "Light", bevel=0.07, neon=neon) for i in range(n)]


def awning(x, y, z, w, depth, color, stripes):
    """A striped shop awning on a front wall at `y`, its top edge at height `z`."""
    s = []
    for i in range(stripes):
        sx = x - w / 2 + (i + 0.5) * w / stripes
        col = color if i % 2 == 0 else "OffWhite"
        s.append(B((sx, y - depth / 2, z - 0.6), (w / stripes, depth + 0.4, 0.3), col, rot=(-18, 0, 0)))
        s.append(B((sx, y - depth - 0.1, z - 1.6), (w / stripes, 0.2, 1.0), "OffWhite" if i % 2 == 0 else color))
    return s


def shopfront(w, front, color, door_x=0.0):
    """The ground floor of a narrow building: a big window either side of a door, a sign board
    above (spot Shop) and an awning."""
    s = [
        BV((0, front - 0.2, 0.5), (w + 0.4, 0.8, 1.0), "Burgundy", bevel=0.08),
        B((0, front - 0.1, 4.2), (w - 1.6, 0.3, 6.4), "Navy"),
        BV((door_x, front - 0.3, 3.4), (3.2, 0.4, 6.0), "Gold", bevel=0.06),
        B((door_x, front - 0.45, 3.2), (2.6, 0.3, 5.4), "DoorGlass"),
    ]
    for side in (-1, 1):
        wx = door_x + side * (w / 4 + 1.0)
        s += [
            BV((wx, front - 0.3, 3.9), (w / 2 - 3.4, 0.4, 4.6), "Gold", bevel=0.06),
            B((wx, front - 0.45, 3.9), (w / 2 - 4.0, 0.3, 4.0), "Glass"),
        ]
    s += [
        BV((0, front - 0.5, 8.4), (w - 1.0, 1.0, 2.4), color, bevel=0.12),
        B((0, front - 1.05, 8.4), (w - 2.0, 0.2, 1.8), "Navy"),
        T((0, front - 1.2, 8.4), (w - 2.4, 0.05, 1.6), "Shop"),
    ]
    s += awning(0, front, 7.0, w - 2.0, 2.6, color, 6)
    return s


def body(w, d, h, color, z0=0.0):
    """The main block, with a cream base course and corner pilasters."""
    return [
        BV((0, 0, z0 + h / 2), (w, d, h), color, bevel=0.3),
        BV((-w / 2 + 0.6, -d / 2 + 0.2, z0 + h / 2), (1.6, 0.8, h), shade(color, 0.12), bevel=0.12),
        BV((w / 2 - 0.6, -d / 2 + 0.2, z0 + h / 2), (1.6, 0.8, h), shade(color, 0.12), bevel=0.12),
    ]


def cornice(w, d, z, color="Cream", trim="Gold"):
    return [
        BV((0, 0, z + 0.5), (w + 1.2, d + 1.2, 1.0), color, bevel=0.12),
        B((0, 0, z + 0.05), (w + 0.6, d + 0.6, 0.3), trim),
        BV((0, 0, z + 1.4), (w + 0.4, d + 0.4, 0.8), shade(color, 0.08), bevel=0.1),
    ]


def floor_bands(w, d, zs, color):
    """A thin trim band round the building at each floor line."""
    return [B((0, 0, z), (w + 0.3, d + 0.3, 0.45), color) for z in zs]


def upper_floors(w, d, z0, floors, height, cols, color, frame="Cream", side_cols=2):
    """Rows of windows on the front, the back and both sides, `floors` floors of `height` from z0."""
    s = []
    front = -d / 2
    pitch = w / cols
    for f in range(floors):
        z = z0 + f * height + height * 0.52
        for i in range(cols):
            s += window(-w / 2 + (i + 0.5) * pitch, front, z, pitch * 0.48, height * 0.5, frame)
            s += back_window(-w / 2 + (i + 0.5) * pitch, d / 2, z, pitch * 0.48, height * 0.5, frame)
        for side in (-1, 1):
            for j in range(side_cols):
                y = -d / 2 + (j + 0.5) * d / side_cols
                s += side_window(side * w / 2, y, z, d / side_cols * 0.42, height * 0.48, frame)
    s += floor_bands(w, d, [z0 + f * height for f in range(1, floors)], shade(color, 0.15))
    return s


def water_tank(x, y, z):
    s = [C((x, y, z + 6.2), 2.4, 4.2, "Wood", seg=10), K((x, y, z + 9.1), 2.6, 0.3, 1.6, "Burgundy", seg=10)]
    for dx in (-1.6, 1.6):
        for dy in (-1.6, 1.6):
            s.append(C((x + dx, y + dy, z + 2.1), 0.22, 4.2, "Iron", seg=6))
    s.append(C((x, y, z + 4.2), 2.6, 0.3, "Iron", seg=10))
    return s


# --- Narrow buildings ---------------------------------------------------------------------------


def apartments(color, accent):
    """Four floors over a shop: the boulevard's everyday building. Spots: Shop (the sign over the
    shop), Billboard (the movie poster on the roof)."""
    w, d = 16, 20
    front = -d / 2
    h = 10 + 3 * 8
    s = body(w, d, h, color)
    s += shopfront(w, front, accent)
    s += upper_floors(w, d, 10, 3, 8, 2, color)
    # Little balconies with gold railings on the middle floor.
    for x in (-4, 4):
        s += [
            BV((x, front - 1.2, 19.2), (5.4, 2.4, 0.5), "Cream", bevel=0.08),
            B((x, front - 2.3, 20.2), (5.4, 0.2, 0.2), "Gold"),
        ]
        s += [B((x - 2.5 + k * 1.0, front - 2.3, 19.8), (0.18, 0.18, 0.9), "Gold") for k in range(6)]
    s += cornice(w, d, h)
    # Roof: a billboard on legs facing the street and a studio water tank behind it.
    roof = h + 1.8
    s += [
        C((-4.5, front + 5, roof + 2.0), 0.25, 4.0, "Iron", seg=6),
        C((4.5, front + 5, roof + 2.0), 0.25, 4.0, "Iron", seg=6),
        BV((0, front + 4.8, roof + 7.6), (13.4, 0.8, 7.4), "Burgundy", bevel=0.12),
        B((0, front + 4.3, roof + 7.6), (12.4, 0.3, 6.4), accent),
        T((0, front + 4.12, roof + 7.6), (12.0, 0.05, 6.0), "Billboard"),
        B((0, front + 3.5, roof + 3.8), (13.4, 1.2, 0.3), "Iron"),
    ]
    s += bulbs(-6.2, 6.2, front + 4.1, roof + 11.5, 7)
    s += water_tank(3.0, 5.0, roof - 0.4)
    return s


def costume_shop(color):
    """Three floors of costume and wig shop with tall display windows and a bulb-lit blade sign
    on the corner. Spots: Shop, Blade."""
    w, d = 16, 20
    front = -d / 2
    h = 12 + 2 * 9
    s = body(w, d, h, color)
    # Ground floor: one tall display window either side of the door, with mannequins behind.
    s += [
        BV((0, front - 0.2, 0.5), (w + 0.4, 0.8, 1.0), "Burgundy", bevel=0.08),
        BV((0, front - 0.3, 4.0), (3.4, 0.4, 7.0), "Gold", bevel=0.06),
        B((0, front - 0.45, 3.8), (2.8, 0.3, 6.4), "DoorGlass"),
    ]
    for side in (-1, 1):
        x = side * 4.6
        s += [
            BV((x, front - 0.3, 4.8), (5.0, 0.4, 7.4), "Gold", bevel=0.06),
            B((x, front - 0.45, 4.8), (4.4, 0.3, 6.8), "Glass"),
            # A mannequin in a gown (seen through the glass, standing just in front of it).
            K((x, front - 0.9, 3.2), 1.0, 0.35, 2.8, shade(color, -0.3), seg=8),
            C((x, front - 0.9, 5.1), 0.35, 1.2, "Cream", seg=6),
            BV((x, front - 0.9, 6.0), (0.7, 0.6, 0.7), "Cream", bevel=0.2),
        ]
    s += [
        BV((0, front - 0.5, 10.3), (w - 1.0, 1.0, 2.6), "Burgundy", bevel=0.12),
        B((0, front - 1.05, 10.3), (w - 2.0, 0.2, 2.0), "Navy"),
        T((0, front - 1.2, 10.3), (w - 2.4, 0.05, 1.8), "Shop"),
    ]
    s += bulbs(-6.8, 6.8, front - 1.1, 11.9, 9)
    s += upper_floors(w, d, 12, 2, 9, 2, color)
    s += cornice(w, d, h)
    # A stepped parapet with a gold star.
    s += [
        BV((0, front + 1.0, h + 3.2), (8, 1.6, 2.6), shade(color, 0.12), bevel=0.12),
        S((0, front + 0.1, h + 5.6), 1.7, 0.6, "Gold"),
    ]
    # Blade sign standing out from the right corner (the game's -X side is Blender +X).
    bx = w / 2 - 1.2
    s += [
        BV((bx, front - 2.6, 20.0), (1.2, 4.4, 14.0), "Gold", bevel=0.12),
        B((bx - 0.55, front - 2.6, 20.0), (0.3, 3.6, 13.0), "Navy"),
        T((bx - 0.72, front - 2.6, 20.0), (0.05, 3.4, 12.4), "Blade", rot=(0, 0, -90)),
        B((bx + 0.55, front - 2.6, 20.0), (0.3, 3.6, 13.0), "Navy"),
        T((bx + 0.72, front - 2.6, 20.0), (0.05, 3.4, 12.4), "BladeBack", rot=(0, 0, 90)),
        B((bx, front - 0.5, 14.0), (0.4, 1.6, 0.4), "Iron"),
        B((bx, front - 0.5, 26.0), (0.4, 1.6, 0.4), "Iron"),
    ]
    s += [BV((bx, front - 4.85, 13.6 + k * 1.6), (0.42, 0.42, 0.42), "Light", bevel=0.07, neon=True) for k in range(9)]
    return s


def radio_station():
    """KRNG radio: three floors with a stepped art deco top, a glowing sign band and a lattice
    mast with a red beacon. Spot: Sign."""
    w, d = 16, 20
    front = -d / 2
    color = "#7EC8C8"
    h = 10 + 2 * 9
    s = body(w, d, h, color)
    s += [
        BV((0, front - 0.2, 0.5), (w + 0.4, 0.8, 1.0), "Navy", bevel=0.08),
        BV((0, front - 0.3, 3.6), (4.4, 0.4, 6.2), "Gold", bevel=0.06),
        B((0, front - 0.45, 3.4), (3.8, 0.3, 5.6), "DoorGlass"),
        # Round porthole windows either side of the door.
        C((-4.6, front - 0.2, 4.4), 1.9, 0.4, "Gold", rot=(90, 0, 0), seg=12),
        C((-4.6, front - 0.3, 4.4), 1.5, 0.4, "Glass", rot=(90, 0, 0), seg=12),
        C((4.6, front - 0.2, 4.4), 1.9, 0.4, "Gold", rot=(90, 0, 0), seg=12),
        C((4.6, front - 0.3, 4.4), 1.5, 0.4, "Glass", rot=(90, 0, 0), seg=12),
        # The lit sign band over the door.
        BV((0, front - 0.6, 8.4), (w - 0.6, 1.2, 2.6), "Navy", bevel=0.12),
        B((0, front - 1.25, 8.4), (w - 1.6, 0.2, 2.0), "Teal", neon=True),
        T((0, front - 1.4, 8.4), (w - 2.0, 0.05, 1.8), "Sign"),
    ]
    s += upper_floors(w, d, 10, 2, 9, 3, color, frame="OffWhite")
    # Gold fins up the front between the windows.
    s += [BV((x, front - 0.5, 19.0), (0.6, 1.0, 18.0), "Gold", bevel=0.08) for x in (-2.7, 2.7)]
    s += cornice(w, d, h, color="OffWhite")
    # Stepped deco crown.
    s += [
        BV((0, 0, h + 3.4), (11, 14, 2.8), color, bevel=0.2),
        B((0, 0, h + 4.9), (11.4, 14.4, 0.3), "Gold"),
        BV((0, 0, h + 6.0), (6, 8, 2.2), shade(color, 0.12), bevel=0.15),
    ]
    # Lattice mast: four legs tapering in, cross braces, a red beacon.
    base = h + 7.1
    top = base + 16
    for dx in (-1, 1):
        for dy in (-1, 1):
            s.append(K((dx * 1.2, dy * 1.2, base + 8), 0.22, 0.12, 16, "Carpet", rot=(dy * 4, -dx * 4, 0), seg=6))
    for k in range(4):
        z = base + 2 + k * 4
        r = 1.15 - k * 0.22
        s.append(B((0, 0, z), (2 * r + 0.3, 2 * r + 0.3, 0.25), "OffWhite" if k % 2 == 0 else "Carpet"))
    s += [
        C((0, 0, top + 0.6), 0.15, 2.0, "Carpet", seg=6),
        C((0, 0, top + 1.8), 0.6, 0.6, "Carpet", seg=10, neon=True),
    ]
    return s


def star_cafe():
    """Two floors of cafe with a striped awning, patio windows and a tall googie pylon sign on the
    roof: a boomerang board on a pole with a spinning-star top. Spots: Shop, Pylon."""
    w, d = 16, 20
    front = -d / 2
    color = "#FFB8C8"
    h = 10 + 9
    s = body(w, d, h, color)
    s += shopfront(w, front, "Teal")
    s += upper_floors(w, d, 10, 1, 9, 2, color)
    s += cornice(w, d, h)
    roof = h + 1.8
    s += [
        C((0, front + 4, roof + 8), 0.5, 16, "OffWhite", seg=8),
        BV((0, front + 4, roof + 1), (3, 3, 2), "Teal", bevel=0.15),
        # The pylon board, tilted a little, edged in teal.
        BV((0, front + 3.6, roof + 11), (9.0, 0.9, 5.0), "Teal", rot=(0, -8, 0), bevel=0.15),
        B((0, front + 3.1, roof + 11), (8.0, 0.3, 4.0), "OffWhite", rot=(0, -8, 0)),
        T((0, front + 2.92, roof + 11), (7.6, 0.05, 3.6), "Pylon", rot=(0, -8, 0)),
        S((0, front + 4, roof + 17.6), 2.2, 0.7, "Gold"),
        C((0, front + 4, roof + 15.8), 0.9, 0.5, "Pink", seg=10),
    ]
    s += bulbs(-4.0, 4.0, front + 3.0, roof + 13.8, 6)
    s += bulbs(-4.0, 4.0, front + 3.0, roof + 8.2, 6)
    # Rooftop patio rail and two umbrellas.
    s += [B((0, front + 0.8, roof + 0.6), (w - 1.0, 0.2, 0.2), "Gold")]
    for x, col in ((-5, "Teal"), (5, "Pink")):
        s += [
            C((x, front + 7, roof + 1.8), 0.12, 3.6, "OffWhite", seg=6),
            K((x, front + 7, roof + 3.9), 2.4, 0.2, 1.0, col, seg=8),
        ]
    return s


# --- Wide buildings -----------------------------------------------------------------------------


def hotel_stardust():
    """Hotel Stardust: a five-floor middle block between two four-floor wings, a long canopy over
    the entrance and a bulb-lit sign on the roof. Spots: Canopy (on the canopy's front), Roof (the
    rooftop sign)."""
    w, d = 30, 24
    front = -d / 2
    color = "#F4E7CF"
    accent = "Carpet"
    mid_w, mid_h = 14, 10 + 4 * 8
    wing_w, wing_h = (w - mid_w) / 2, 10 + 3 * 8
    s = [BV((0, 0, mid_h / 2), (mid_w, d, mid_h), color, bevel=0.3)]
    for side in (-1, 1):
        x = side * (mid_w / 2 + wing_w / 2)
        s.append(G((x, 1, 0), (0, 0, 0), *(
            [BV((0, 0, wing_h / 2), (wing_w, d - 2, wing_h), shade(color, 0.06), bevel=0.3)]
            + upper_floors(wing_w, d - 2, 10, 3, 8, 2, shade(color, 0.06), frame="Burgundy", side_cols=3)
            + cornice(wing_w, d - 2, wing_h, color="Burgundy")
            + [
                # Ground floor: arched windows.
                *window(-2, -(d - 2) / 2, 4.6, 2.6, 4.6, frame="Burgundy"),
                *window(2, -(d - 2) / 2, 4.6, 2.6, 4.6, frame="Burgundy"),
                BV((0, -(d - 2) / 2 - 0.2, 0.5), (wing_w + 0.4, 0.8, 1.0), "Burgundy", bevel=0.08),
            ]
        )))
    s += upper_floors(mid_w, d, 10, 4, 8, 3, color, frame="Burgundy", side_cols=0)
    s += cornice(mid_w, d, mid_h, color="Burgundy")
    # The entrance: revolving door, gold columns and a deep canopy reaching over the sidewalk.
    s += [
        BV((0, front - 0.2, 0.5), (mid_w + 0.4, 0.8, 1.0), "Burgundy", bevel=0.08),
        BV((0, front - 0.3, 3.6), (6.0, 0.4, 6.4), "Gold", bevel=0.06),
        B((0, front - 0.45, 3.4), (5.2, 0.3, 5.8), "DoorGlass"),
        C((0, front - 1.0, 3.2), 1.6, 5.6, "Glass", seg=10),
        BV((0, front - 4.0, 7.6), (10, 8, 1.2), accent, bevel=0.2),
        BV((0, front - 4.0, 8.4), (10.4, 8.4, 0.4), "Gold", bevel=0.08),
        B((0, front - 8.1, 7.6), (9.4, 0.3, 1.0), "Navy"),
        T((0, front - 8.28, 7.6), (9.0, 0.05, 0.9), "Canopy"),
    ]
    for x in (-4.4, 4.4):
        s.append(C((x, front - 7.4, 3.6), 0.3, 7.2, "Gold", seg=8))
    s += bulbs(-4.6, 4.6, front - 8.1, 6.85, 7)
    # Carpet and topiaries at the door.
    s += [B((0, front - 4.0, 0.03), (3.6, 8.0, 0.06), accent)]
    for x in (-6, 6):
        s += [
            K((x, front - 1.4, 0.6), 0.9, 0.75, 1.2, "Burgundy", seg=8),
            L((x, front - 1.4, 2.2), (1.1, 1.1, 1.3), "LeafDark"),
            L((x, front - 1.4, 3.7), (0.8, 0.8, 0.9), "Leaf"),
        ]
    # The rooftop sign: a tall lit board on a steel frame, ringed with bulbs, a star on top.
    roof = mid_h + 1.8
    s += [
        B((-5.5, front + 6, roof + 2), (0.5, 0.5, 4), "Iron"),
        B((5.5, front + 6, roof + 2), (0.5, 0.5, 4), "Iron"),
        BV((0, front + 6, roof + 7.2), (14, 1.0, 6.6), "Navy", bevel=0.15),
        B((0, front + 5.4, roof + 7.2), (13, 0.3, 5.6), "Burgundy"),
        T((0, front + 5.22, roof + 7.2), (12.6, 0.05, 5.2), "Roof"),
        S((0, front + 6, roof + 12.6), 2.4, 0.8, "Gold"),
    ]
    s += bulbs(-6.6, 6.6, front + 5.3, roof + 10.7, 10)
    s += bulbs(-6.6, 6.6, front + 5.3, roof + 3.7, 10)
    # Flags on the wing roofs.
    for side in (-1, 1):
        x = side * (mid_w / 2 + wing_w / 2)
        s += [
            C((x, front + 3, wing_h + 5.5), 0.15, 8, "OffWhite", seg=6),
            B((x + side * 1.6, front + 3, wing_h + 8.2), (3.0, 0.15, 1.8), accent),
        ]
    return s


def sunset_tower():
    """Sunset Tower: a stepped art deco tower, three tiers, with gold fins, a lit sign band over the
    doors and a spire. Spot: Sign."""
    w, d = 30, 24
    front = -d / 2
    color = "#F2C9A0"
    dark = shade(color, 0.12)
    s = []
    tiers = ((w, d, 10 + 2 * 8), (22, 18, 2 * 8), (14, 12, 8))
    z = 0.0
    for i, (tw, td, th) in enumerate(tiers):
        tier = [BV((0, 0, z + th / 2), (tw, td, th), color if i % 2 == 0 else dark, bevel=0.3)]
        z0 = z + (10 if i == 0 else 0)
        floors = int((th - (10 if i == 0 else 0)) // 8)
        cols = max(2, int(tw // 6))
        tier += upper_floors(tw, td, z0, floors, 8, cols, color if i % 2 == 0 else dark, frame="Gold", side_cols=2 if tw > 16 else 1)
        tier += [
            BV((0, 0, z + th + 0.4), (tw + 0.8, td + 0.8, 0.8), "Gold", bevel=0.1),
        ]
        # Fins up the front corners of each tier.
        tier += [BV((x, -td / 2 - 0.4, z + th / 2), (0.9, 0.9, th), "Gold", bevel=0.1) for x in (-tw / 2 + 0.4, tw / 2 - 0.4)]
        s += tier
        z += th + 0.8
    # Ground floor: three tall glass doors under a gold frame and the glowing sign band.
    s += [
        BV((0, front - 0.2, 0.5), (w + 0.4, 0.8, 1.0), "Navy", bevel=0.08),
        BV((0, front - 0.3, 3.8), (12, 0.4, 6.8), "Gold", bevel=0.06),
    ]
    for x in (-4, 0, 4):
        s.append(B((x, front - 0.45, 3.6), (3.4, 0.3, 6.2), "DoorGlass"))
    for x in (-11, 11):
        s += window(x, front, 4.6, 4.4, 4.8, frame="Gold")
    s += [
        BV((0, front - 0.7, 8.4), (w - 4, 1.4, 2.6), "Navy", bevel=0.15),
        B((0, front - 1.45, 8.4), (w - 5, 0.2, 2.0), "Purple", neon=True),
        T((0, front - 1.6, 8.4), (w - 6, 0.05, 1.8), "Sign"),
    ]
    # Spire with a gold ball.
    s += [
        K((0, 0, z + 2.5), 3.0, 1.6, 5.0, dark, seg=8),
        K((0, 0, z + 9.0), 1.2, 0.15, 8.0, "Gold", seg=8),
        C((0, 0, z + 5.2), 1.7, 0.4, "Gold", seg=8),
    ]
    s += [BV((-1.4 + k * 0.7, -6.1, z + 0.9), (0.38, 0.3, 0.38), "Light", bevel=0.07, neon=True) for k in range(5)]
    # Planters either side of the doors.
    for x in (-8, 8):
        s += [
            BV((x, front - 1.2, 0.7), (3.6, 1.6, 1.4), "Gold", bevel=0.12),
            L((x, front - 1.2, 2.0), (1.6, 0.8, 0.9), "LeafDark"),
        ]
    return s


def _v(fn, *args):
    return lambda: fn(*args)


APARTMENT_COLORS = {
    "Pink": ("#F7B6C2", "Carpet"),
    "Teal": ("#9ED8D0", "Blue"),
    "Butter": ("#F6DE96", "Purple"),
    "Lilac": ("#C9B6EA", "Teal"),
}
COSTUME_COLORS = {"Purple": "#B58BE8", "Mint": "#9FDDB0"}

KIT = (
    [("Apartments" + name, _v(apartments, col, accent)) for name, (col, accent) in APARTMENT_COLORS.items()]
    + [("CostumeShop" + name, _v(costume_shop, col)) for name, col in COSTUME_COLORS.items()]
    + [
        ("RadioStation", radio_station),
        ("StarCafe", star_cafe),
        ("HotelStardust", hotel_stardust),
        ("SunsetTower", sunset_tower),
    ]
)

LINEUPS = {
    "boulevard_kit.png": (
        ["ApartmentsPink", "CostumeShopPurple", "RadioStation", "StarCafe", "ApartmentsTeal"],
        ["HotelStardust", "SunsetTower"],
    ),
}
