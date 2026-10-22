"""Crew kit: the film crew and actors who shoot scenes on the film sets, and the gate that keeps a
film set closed until it is bought. map_kit.py builds them into the one map_kit.fbx and the one
MapKitShapes.luau with the rest of the map kit, so run that file, not this one.

  Rig pieces   Crew<Who><Part>: Head, Torso, Arm, Leg (used for both sides) for each of the six people
               (Director, Clapper, Operator, Sheriff, Outlaw, Stunt). src/shared/Models/CrewRig.luau
               puts the pieces together and turns them at their joints, so the same six puppets
               act out every scene (src/shared/FilmScenes.luau).
  Props        PropMegaphone, PropRevolver, PropClapper (spot Board: the scene and the film's
               title), PropClapperStick (the hinged top that snaps shut)
  Gate         SetGate (striped posts, a lit sign: spots Sign and Price), SetGateArm (the boom that
               lifts for owners)

Every rig piece and prop keeps its own joint at the origin (map_kit.py does not lift them onto the
ground): a leg or an arm hangs down from its hip or shoulder, the head and the torso stand up from
the neck and the hips, and a prop sits in the hand with the arm's direction along -Z. Faces and
fronts face -Y like every kit model. Chunky toy style to match the actors (ART_STYLE.md):
blocky heads, bevelled outfits, a few bold details that say who they are.
Blender axes, in studs: Z up, the model faces -Y.
"""

from kitdsl import B, C, E, K, S, T, shade  # noqa: F401


def BV(at, size, color, rot=(0, 0, 0), bevel=0.08, neon=False):
    return B(at, size, color, rot, bevel, neon)


# Body sizes (studs). Hips 2.0 up, shoulders 3.85 up, the head on the neck at 4.1 (CrewRig.luau
# uses the same numbers).
LEG = 2.0
ARM = 1.8
SKIN = {
    "light": "#FFDEBE",
    "fair": "#F0C49C",
    "tan": "#D6A06E",
    "brown": "#A56C44",
    "deep": "#70462C",
}

# Who wears what: skin, shirt, sleeves, pants, shoes.
PEOPLE = {
    "Director": {"skin": "fair", "shirt": "#2E2C34", "sleeve": "#2E2C34", "pants": "#C8B48C", "shoes": "#5A3A24"},
    "Clapper": {"skin": "brown", "shirt": "#9AA0AA", "sleeve": "#9AA0AA", "pants": "#3E5C8A", "shoes": "#F4F4F4"},
    "Operator": {"skin": "tan", "shirt": "#2E86DE", "sleeve": "#2E86DE", "pants": "#3E5C8A", "shoes": "#2E2C34"},
    "Sheriff": {"skin": "fair", "shirt": "#E8D9B0", "sleeve": "#E8D9B0", "pants": "#6A5440", "shoes": "#7A5434"},
    "Outlaw": {"skin": "light", "shirt": "#3A3440", "sleeve": "#3A3440", "pants": "#2E2C34", "shoes": "#2A1E18"},
    "Stunt": {"skin": "deep", "shirt": "#FF8C28", "sleeve": "#FF8C28", "pants": "#FF8C28", "shoes": "#2E2C34"},
}


def leg(who):
    """A leg hanging from the hip joint: trousers, a cuff and a chunky shoe pointing forward."""
    p = PEOPLE[who]
    s = [
        BV((0, 0, -0.8), (0.82, 0.9, 1.6), p["pants"]),
        B((0, 0, -1.55), (0.86, 0.94, 0.1), shade(p["pants"], 0.15)),
        BV((0, -0.15, -1.8), (0.86, 1.2, 0.4), p["shoes"], bevel=0.12),
    ]
    if who == "Sheriff" or who == "Outlaw":
        # Cowboy boots up the shin, with a stitched top.
        s += [BV((0, 0, -1.3), (0.9, 0.98, 0.7), p["shoes"]), B((0, -0.5, -1.0), (0.5, 0.06, 0.1), "Gold")]
    if who == "Stunt":
        s.append(BV((0, -0.48, -0.9), (0.6, 0.08, 0.45), "#2E2C34"))  # knee pad
    return s


def arm(who):
    """An arm hanging from the shoulder joint: sleeve, cuff and hand (a glove for the stunt double)."""
    p = PEOPLE[who]
    hand = "#2E2C34" if who == "Stunt" else SKIN[p["skin"]]
    return [
        BV((0, 0, -0.65), (0.6, 0.7, 1.3), p["sleeve"]),
        B((0, 0, -1.28), (0.64, 0.74, 0.12), shade(p["sleeve"], 0.15)),
        BV((0, 0, -1.58), (0.55, 0.62, 0.5), hand, bevel=0.12),
    ]


def torso(who):
    """The body from the hips up to the neck, with what the person wears on it."""
    p = PEOPLE[who]
    skin = SKIN[p["skin"]]
    s = [
        BV((0, 0, 1.0), (1.8, 1.0, 1.7), p["shirt"], bevel=0.12),
        BV((0, 0, 0.15), (1.84, 1.04, 0.3), shade(p["pants"], 0.1)),
        C((0, 0, 1.97), 0.3, 0.3, skin, seg=8),
    ]
    if who == "Director":
        # A gold scarf and a turtleneck collar.
        s += [
            C((0, 0, 1.86), 0.48, 0.18, "#2E2C34", seg=10),
            BV((0, -0.42, 1.5), (1.0, 0.3, 0.5), "Gold"),
            BV((0.25, -0.55, 1.05), (0.35, 0.12, 0.9), "Gold", rot=(0, 8, 0)),
            B((0, 0, 0.15), (1.86, 1.06, 0.32), "#2E2C34"),
        ]
    elif who == "Clapper":
        # A crew tee with a lanyard and a walkie on the belt.
        s += [
            BV((0, -0.52, 1.25), (0.9, 0.06, 0.5), "#2E2C34"),
            B((0, -0.52, 1.25), (0.8, 0.07, 0.4), "Gold"),
            BV((0.75, -0.3, 0.45), (0.3, 0.35, 0.55), "#2E2C34"),
            C((0.75, -0.3, 0.9), 0.05, 0.4, "#2E2C34", seg=6),
        ]
    elif who == "Operator":
        # A padded jacket with a zip and a pocket.
        s += [
            B((0, -0.51, 1.0), (0.12, 0.05, 1.6), "Chrome"),
            BV((-0.5, -0.53, 0.75), (0.45, 0.06, 0.4), shade(p["shirt"], 0.2)),
            BV((0, 0, 1.75), (1.6, 0.9, 0.2), shade(p["shirt"], 0.2)),
        ]
    elif who == "Sheriff":
        # A leather vest, the star badge and a gun belt.
        for x in (-0.55, 0.55):
            s.append(BV((x, -0.04, 1.05), (0.62, 1.04, 1.6), "#8A5A34"))
        s += [
            S((-0.55, -0.6, 1.35), 0.32, 0.12, "Gold"),
            BV((0, 0, 0.15), (1.9, 1.08, 0.34), "#5A3A24"),
            BV((0, -0.56, 0.15), (0.4, 0.06, 0.28), "Gold"),
            BV((0.95, 0, 0.0), (0.3, 0.5, 0.6), "#5A3A24"),
        ]
    elif who == "Outlaw":
        # A red bandana knotted at the neck and a belt of shells.
        s += [
            K((0, -0.25, 1.62), 0.5, 0.1, 0.5, "Carpet", rot=(180, 0, 0), seg=4),
            C((0, 0, 1.86), 0.42, 0.16, "Carpet", seg=10),
            BV((0, 0, 0.15), (1.9, 1.08, 0.34), "#2A1E18"),
        ]
        s += [B((-0.6 + i * 0.3, -0.55, 0.15), (0.12, 0.06, 0.24), "Gold") for i in range(5)]
    elif who == "Stunt":
        # A racing jumpsuit with white stripes down the front.
        s += [B((x, -0.51, 1.0), (0.18, 0.05, 1.6), "OffWhite") for x in (-0.3, 0.3)]
        s.append(BV((0, 0, 0.15), (1.86, 1.06, 0.32), "#2E2C34"))
    return s


def face(skin, mouth="smile", eyes="#2E2C34"):
    s = [BV((0, 0, 0.75), (1.5, 1.4, 1.5), skin, bevel=0.18)]
    for x in (-0.35, 0.35):
        s += [
            B((x, -0.71, 0.85), (0.22, 0.06, 0.36), eyes),
            B((x - 0.04, -0.74, 0.95), (0.08, 0.04, 0.08), "OffWhite"),
        ]
    if mouth == "grin":
        s += [B((0, -0.71, 0.42), (0.6, 0.06, 0.2), "OffWhite"), B((0, -0.72, 0.31), (0.64, 0.06, 0.05), "#782832")]
    elif mouth == "flat":
        s.append(B((0, -0.71, 0.4), (0.45, 0.06, 0.09), "#782832"))
    else:
        s += [B((0, -0.71, 0.4), (0.42, 0.06, 0.09), "#782832"), B((0.24, -0.71, 0.45), (0.1, 0.06, 0.1), "#782832")]
    return s


def head(who):
    """The head standing on the neck, with each person's hair, hat or helmet."""
    p = PEOPLE[who]
    skin = SKIN[p["skin"]]
    if who == "Director":
        s = face(skin, "grin")
        s += [
            # Dark sunglasses over the eyes and a red beret tipped to one side.
            BV((0, -0.74, 0.88), (1.2, 0.08, 0.38), "#2E2C34", bevel=0.05),
            K((0.12, 0.05, 1.62), 0.92, 0.7, 0.32, "Carpet", rot=(0, 10, 0), seg=10),
            C((0.12, 0.05, 1.82), 0.08, 0.16, "Carpet", seg=6),
            BV((0, 0.35, 1.3), (1.56, 0.8, 0.5), "#3A2A22"),
        ]
    elif who == "Clapper":
        s = face(skin, "smile")
        s += [
            # A cap worn backwards.
            BV((0, 0, 1.58), (1.56, 1.46, 0.36), "Teal", bevel=0.15),
            BV((0, 0.95, 1.45), (1.0, 0.7, 0.12), "Teal"),
            C((0, 0, 1.78), 0.12, 0.08, "OffWhite", seg=6),
        ]
    elif who == "Operator":
        s = face(skin, "flat")
        s += [
            # Short hair under big headphones.
            BV((0, 0.1, 1.55), (1.56, 1.3, 0.25), "#2A1E18"),
            B((0, 0, 1.72), (1.7, 0.2, 0.15), "#2E2C34"),
        ]
        for x in (-0.82, 0.82):
            s += [C((x, 0, 0.95), 0.38, 0.28, "#2E2C34", rot=(0, 90, 0), seg=10), B((x, 0, 1.4), (0.12, 0.2, 0.75), "#2E2C34")]
    elif who == "Sheriff":
        s = face(skin, "flat")
        s += [
            # A big mustache and a tan ten-gallon hat.
            BV((0, -0.74, 0.55), (0.8, 0.1, 0.2), "#7A5434"),
            C((0, 0, 1.58), 1.25, 0.12, "#C89A5A", seg=14),
            BV((0, 0, 1.98), (1.4, 1.24, 0.8), "#C89A5A", bevel=0.2),
            B((0, 0, 1.68), (1.44, 1.28, 0.18), "#7A5434"),
        ]
    elif who == "Outlaw":
        s = face(skin, "grin")
        s += [
            # A black hat with a pinched crown and a scar of stubble.
            C((0, 0, 1.58), 1.2, 0.12, "#2E2C34", seg=14),
            BV((0, 0, 1.95), (1.36, 1.2, 0.74), "#2E2C34", bevel=0.2),
            B((0, 0, 1.68), (1.4, 1.24, 0.16), "Carpet"),
            BV((0, -0.73, 0.25), (0.9, 0.05, 0.25), shade(skin, 0.2)),
        ]
    else:  # Stunt
        s = face(skin, "smile")
        s += [
            # A racing helmet with the visor up and a stripe over the top.
            BV((0, 0.1, 1.0), (1.7, 1.55, 1.7), "#FF8C28", bevel=0.4),
            B((0, 0.1, 1.86), (0.4, 1.4, 0.06), "OffWhite"),
            BV((0, -0.55, 1.55), (1.3, 0.3, 0.45), "#2E86DE", bevel=0.1, rot=(-25, 0, 0)),
        ]
        # The face shows through the helmet's open front.
        s.append(B((0, -0.73, 0.75), (1.2, 0.04, 1.0), skin))
        for x in (-0.35, 0.35):
            s.append(B((x, -0.76, 0.85), (0.22, 0.04, 0.36), "#2E2C34"))
        s.append(B((0, -0.76, 0.42), (0.42, 0.04, 0.09), "#782832"))
    return s


# --- Props (held in the hand: the arm points along -Z) ------------------------------------------


def megaphone():
    return [
        BV((0, 0.2, -0.05), (0.22, 0.5, 0.3), "#2E2C34"),
        C((0, 0, -0.35), 0.22, 0.5, "OffWhite", seg=10),
        K((0, 0, -1.0), 0.62, 0.24, 0.9, "Carpet", rot=(180, 0, 0), seg=12),
        C((0, 0, -1.46), 0.64, 0.08, "Gold", seg=12),
    ]


def revolver():
    return [
        BV((0, 0.25, 0.05), (0.24, 0.55, 0.32), "#7A5434", rot=(-15, 0, 0)),
        C((0, 0, -0.35), 0.2, 0.4, "#6E7078", seg=8),
        C((0, -0.08, -0.9), 0.08, 0.9, "#6E7078", seg=6),
        B((0, -0.18, -1.3), (0.06, 0.08, 0.1), "#6E7078"),
    ]


def clapper():
    """The slate held up to the camera: a black board with chalk lines (spot Board for the scene,
    take and the film's title). The hinged top is PropClapperStick."""
    s = [
        BV((0, -1.0, -0.3), (2.4, 1.8, 0.15), "#2E2C34", bevel=0.04),
        B((0, -1.0, -0.39), (2.2, 0.04, 0.05), "OffWhite"),
        B((0, -0.55, -0.39), (2.2, 0.04, 0.05), "OffWhite"),
        T((0, -1.0, -0.4), (2.2, 1.6, 0.05), "Board", rot=(90, 0, 0)),
        B((0, -1.95, -0.3), (2.4, 0.15, 0.15), "OffWhite"),
    ]
    s += [B((-0.9 + i * 0.6, -1.95, -0.39), (0.3, 0.15, 0.04), "#2E2C34") for i in range(4)]
    return s


def clapper_stick():
    """The top of the slate, hinged at its left end (the origin), black and white stripes."""
    s = [BV((-1.2, 0, 0.17), (2.4, 0.15, 0.32), "OffWhite", bevel=0.03)]
    s += [B((-0.3 - i * 0.6, -0.09, 0.17), (0.3, 0.04, 0.34), "#2E2C34", rot=(0, 30, 0)) for i in range(4)]
    s.append(C((0, 0, 0.17), 0.1, 0.25, "Gold", rot=(90, 0, 0), seg=8))
    return s


# --- Gate ---------------------------------------------------------------------------------------


def set_gate():
    """A film set gate for a 16-stud path: two striped posts with bulbs, a lit sign across the
    top (spot Sign) and a price board on the right post (spot Price). The boom is SetGateArm."""
    s = []
    for x in (-9.2, 9.2):
        for k in range(7):
            s.append(BV((x, 0, 0.6 + k * 1.2), (1.2, 1.2, 1.2), "Carpet" if k % 2 == 0 else "OffWhite", bevel=0.06))
        s += [
            BV((x, 0, 8.7), (1.6, 1.6, 0.6), "Gold"),
            E((x, 0, 9.4), (0.45, 0.45, 0.45), "Light", neon=True),
        ]
    s += [
        BV((0, 0, 11.6), (20.4, 1.0, 3.4), "Navy", bevel=0.15),
        BV((0, 0, 11.6), (21.0, 0.8, 4.0), "Gold", bevel=0.12),
        B((0, -0.55, 11.6), (19.6, 0.1, 2.8), "Navy"),
        T((0, -0.62, 11.6), (19.0, 0.05, 2.5), "Sign"),
        B((0, 0.55, 11.6), (19.6, 0.1, 2.8), "Navy"),
        T((0, 0.62, 11.6), (19.0, 0.05, 2.5), "SignBack", rot=(0, 0, 180)),
    ]
    s += [E((-9.6 + i * 1.6, -0.6, 13.75), (0.22, 0.22, 0.22), "Light", neon=True) for i in range(13)]
    # The price board on the right post (Blender -X is the game's +X), and the boom's rest.
    s += [
        BV((-9.2, -0.9, 4.8), (3.0, 0.3, 1.8), "Gold"),
        B((-9.2, -1.06, 4.8), (2.7, 0.06, 1.5), "Navy"),
        T((-9.2, -1.1, 4.8), (2.6, 0.05, 1.4), "Price"),
        BV((-9.2, 0, 2.8), (0.6, 1.4, 0.4), "#2E2C34"),
    ]
    return s


def set_gate_arm():
    """The gate's boom, hinged at the origin and reaching 17 studs toward the game's +X (Blender
    -X), striped red and white with a weight behind the hinge."""
    s = [BV((0.9, 0, 0), (1.6, 0.8, 0.8), "#2E2C34")]
    for i in range(8):
        s.append(BV((-1.06 - i * 2.0, 0, 0), (2.0, 0.5, 0.5), "Carpet" if i % 2 == 0 else "OffWhite", bevel=0.04))
    s.append(E((-16.25, 0, 0), (0.4, 0.4, 0.4), "Carpet", neon=True))
    return s


def _v(fn, *args):
    return lambda: fn(*args)


RIG_PARTS = {
    "Head": head,
    "Torso": torso,
    "Arm": arm,  # both arms and both legs use the one piece
    "Leg": leg,
}

KIT = [(f"Crew{who}{part}", _v(make, who)) for who in PEOPLE for part, make in RIG_PARTS.items()] + [
    ("PropMegaphone", megaphone),
    ("PropRevolver", revolver),
    ("PropClapper", clapper),
    ("PropClapperStick", clapper_stick),
    ("SetGate", set_gate),
    ("SetGateArm", set_gate_arm),
]

# Models that keep their own origin as the joint instead of standing on the ground.
NO_LIFT = {name for name, _ in KIT if name != "SetGate"}

LINEUPS = {
    "map_kit_crew.png": (
        [f"Crew{who}{part}" for who in ("Director", "Clapper", "Operator") for part in RIG_PARTS],
        [f"Crew{who}{part}" for who in ("Sheriff", "Outlaw", "Stunt") for part in RIG_PARTS]
        + ["PropMegaphone", "PropRevolver", "PropClapper", "PropClapperStick"],
    ),
    "map_kit_set_gate.png": (["SetGate"], ["SetGateArm"]),
}
