"""Crew kit: the film crew and actors who shoot scenes on the film sets, and the gate that keeps a
film set closed until it is bought. map_kit.py builds them into the one map_kit.fbx and the one
MapKitShapes.luau with the rest of the map kit, so run that file, not this one.

  Rig pieces   Crew<Who><Part>: Head, Torso, Arm, Leg (used for both sides) for each person: the
               crew (Director, Clapper, Operator, Boom, Gaffer, Makeup) and the actors (Sheriff,
               Outlaw, Stunt, Astronaut, Alien, Explorer, Guide). src/shared/Models/CrewRig.luau
               puts the pieces together and turns them at their joints, so the same puppets act
               out every scene (src/shared/FilmScenes.luau).
  Props        PropMegaphone, PropRevolver, PropClapper (spot Board: the scene and the film's
               title), PropClapperStick (the hinged top that snaps shut), PropBoomPole (the boom
               mic on its pole), PropMakeupBrush, PropFlag, PropIdol, PropTorch, PropBoulder
  Camera rig   CrewDollyTrack (rails on the ground), CrewDolly (the cart that rolls on them, with a
               post), CrewJibArm (the crane arm, hinged on the post), CrewCameraHead (the camera
               hanging at the arm's tip); FilmScenes moves the last three
  Set gear     CrewLightStand and CrewLightHead (the lamp the lighting tech turns), CrewMakeupKit
               (a table with the make-up case and a mirror), CrewOpenDoor and CrewBalconyDoor
               (open doorways the stunt double walks through on the hotel)
  Gate         SetGate (striped posts, a lit sign: spots Sign and Price), SetGateArm (the boom that
               lifts for owners)

Every rig piece and prop keeps its own joint at the origin (map_kit.py does not lift them onto the
ground): a leg or an arm hangs down from its hip or shoulder, the head and the torso stand up from
the neck and the hips, and a prop sits in the hand with the arm's direction along -Z. Faces and
fronts face -Y like every kit model. Chunky toy style to match the actors (ART_STYLE.md):
blocky heads, bevelled outfits, a few bold details that say who they are.
Blender axes, in studs: Z up, the model faces -Y.
"""

import math

from kitdsl import B, C, E, G, K, L, S, T, shade  # noqa: F401


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
    "alien": "#7CD65A",
}

# Who wears what: skin, shirt, sleeves, pants, shoes.
PEOPLE = {
    "Director": {"skin": "fair", "shirt": "#2E2C34", "sleeve": "#2E2C34", "pants": "#C8B48C", "shoes": "#5A3A24"},
    "Clapper": {"skin": "brown", "shirt": "#9AA0AA", "sleeve": "#9AA0AA", "pants": "#3E5C8A", "shoes": "#F4F4F4"},
    "Operator": {"skin": "tan", "shirt": "#2E86DE", "sleeve": "#2E86DE", "pants": "#3E5C8A", "shoes": "#2E2C34"},
    "Sheriff": {"skin": "fair", "shirt": "#E8D9B0", "sleeve": "#E8D9B0", "pants": "#6A5440", "shoes": "#7A5434"},
    "Outlaw": {"skin": "light", "shirt": "#3A3440", "sleeve": "#3A3440", "pants": "#2E2C34", "shoes": "#2A1E18"},
    "Stunt": {"skin": "deep", "shirt": "#FF8C28", "sleeve": "#FF8C28", "pants": "#FF8C28", "shoes": "#2E2C34", "hand": "#2E2C34"},
    # The Moon Base set.
    "Astronaut": {"skin": "tan", "shirt": "#F2F2F0", "sleeve": "#F2F2F0", "pants": "#F2F2F0", "shoes": "#9AA0AA", "hand": "#F2F2F0"},
    "Alien": {"skin": "alien", "shirt": "#7CD65A", "sleeve": "#7CD65A", "pants": "#5BB040", "shoes": "#3E8A2E"},
    # The Jungle Temple set.
    "Explorer": {"skin": "fair", "shirt": "#D8C49A", "sleeve": "#D8C49A", "pants": "#8A6A44", "shoes": "#5A3A24"},
    "Guide": {"skin": "brown", "shirt": "#5BBF5A", "sleeve": "#5BBF5A", "pants": "#C8B48C", "shoes": "#5A3A24"},
    # More crew: the boom mic operator, the lighting tech (gaffer) and the make-up artist.
    "Boom": {"skin": "light", "shirt": "#6B7F3A", "sleeve": "#6B7F3A", "pants": "#3A3440", "shoes": "#5A3A24"},
    "Gaffer": {"skin": "deep", "shirt": "#C8202F", "sleeve": "#C8202F", "pants": "#5A4A3A", "shoes": "#2A1E18", "hand": "#2E2C34"},
    "Makeup": {"skin": "fair", "shirt": "#FF78AA", "sleeve": "#FF78AA", "pants": "#2E2C34", "shoes": "#FAF6EC"},
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
    if who == "Astronaut":
        # Chunky moon boots with an orange band.
        s += [BV((0, 0, -1.45), (0.98, 1.06, 0.9), "#D7DAE1", bevel=0.14), B((0, 0, -1.05), (1.0, 1.08, 0.14), "Orange")]
    if who == "Explorer":
        s.append(BV((0, 0, -1.35), (0.92, 1.0, 0.6), "#5A3A24"))  # lace-up boots
    return s


def arm(who):
    """An arm hanging from the shoulder joint: sleeve, cuff and hand (a glove for the stunt double)."""
    p = PEOPLE[who]
    hand = p.get("hand", SKIN[p["skin"]])
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
    elif who == "Astronaut":
        # A chest control box with lights, a mission patch, and an air pack on the back.
        s += [
            BV((0, -0.56, 1.2), (0.9, 0.18, 0.6), "#9AA0AA"),
            E((-0.25, -0.66, 1.25), (0.08, 0.04, 0.08), "Carpet", neon=True),
            E((0.0, -0.66, 1.25), (0.08, 0.04, 0.08), "Light", neon=True),
            E((0.25, -0.66, 1.25), (0.08, 0.04, 0.08), "Teal", neon=True),
            C((-0.6, -0.52, 1.55), 0.16, 0.06, "Blue", rot=(90, 0, 0), seg=10),
            BV((0, 0.75, 1.05), (1.4, 0.6, 1.5), "#D7DAE1", bevel=0.12),
            C((0.4, 0.75, 1.9), 0.1, 0.3, "#9AA0AA", seg=6),
            BV((0, 0, 0.15), (1.86, 1.06, 0.32), "#9AA0AA"),
        ]
    elif who == "Alien":
        # A shiny silver collar and belt: a costume from the props department.
        s += [
            C((0, 0, 1.86), 0.6, 0.16, "Chrome", seg=12),
            BV((0, 0, 0.15), (1.86, 1.06, 0.32), "Chrome"),
            E((0, -0.53, 1.1), (0.25, 0.05, 0.25), "Purple", neon=True),
        ]
    elif who == "Explorer":
        # A leather jacket over the shirt, a satchel strap and a coiled whip on the belt.
        for x in (-0.6, 0.6):
            s.append(BV((x, -0.03, 1.0), (0.62, 1.08, 1.7), "#7A5434"))
        s += [
            B((0, -0.56, 1.0), (0.2, 0.06, 1.9), "#5A3A24", rot=(0, 40, 0)),
            BV((0, 0, 0.15), (1.9, 1.08, 0.34), "#5A3A24"),
            C((-0.98, 0, 0.25), 0.32, 0.2, "#5A3A24", rot=(0, 90, 0), seg=10),
        ]
    elif who == "Boom":
        # A sound vest full of pockets, the recorder bag on a strap across the chest.
        s += [BV((x, -0.53, 0.95), (0.42, 0.08, 0.4), shade(p["shirt"], 0.25)) for x in (-0.45, 0.45)]
        s += [
            B((0, -0.55, 1.05), (0.18, 0.06, 1.9), "#2E2C34", rot=(0, -40, 0)),
            BV((-0.98, -0.1, 0.45), (0.3, 0.8, 0.6), "#2E2C34"),
            E((-1.0, -0.52, 0.55), (0.06, 0.03, 0.06), "Carpet", neon=True),
            BV((0, 0, 0.15), (1.86, 1.06, 0.32), "#2E2C34"),
        ]
    elif who == "Gaffer":
        # A checked work shirt and a tool belt with a roll of gaffer tape and a wrench.
        s += [B((x, -0.51, 1.0), (0.1, 0.05, 1.6), shade(p["shirt"], 0.3)) for x in (-0.45, 0.0, 0.45)]
        s += [B((0, -0.51, z), (1.7, 0.05, 0.1), shade(p["shirt"], 0.3)) for z in (0.6, 1.1, 1.6)]
        s += [
            BV((0, 0, 0.15), (1.9, 1.08, 0.34), "#5A3A24"),
            C((0.98, 0, 0.2), 0.3, 0.22, "Chrome", rot=(0, 90, 0), seg=10),
            BV((-0.98, -0.15, 0.1), (0.18, 0.3, 0.7), "Steel"),
        ]
    elif who == "Makeup":
        # A black apron with brushes in its pocket.
        s += [
            BV((0, -0.5, 0.75), (1.4, 0.08, 1.3), "#2E2C34"),
            B((0, -0.55, 0.55), (1.0, 0.06, 0.4), shade("#2E2C34", -0.2)),
        ]
        s += [C((-0.3 + i * 0.2, -0.56, 0.85), 0.05, 0.4, c, seg=5) for i, c in enumerate(["Gold", "Pink", "Teal", "Purple"])]
        s.append(BV((0, 0, 0.15), (1.86, 1.06, 0.32), "#2E2C34"))
    elif who == "Guide":
        # A many-pocket vest and a water flask.
        s += [
            BV((x, -0.53, 0.9), (0.4, 0.08, 0.35), "#3E8A2E") for x in (-0.45, 0.45)
        ] + [
            BV((0, 0, 0.15), (1.86, 1.06, 0.32), "#7A5434"),
            C((0.98, 0, 0.45), 0.25, 0.6, "Steel", seg=8),
        ]
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
    elif who == "Astronaut":
        s = face(skin, "smile")
        s += [
            # A round helmet with a gold visor (raised a little, so the face shows) and an
            # antenna.
            E((0, 0.05, 0.85), (1.05, 1.0, 1.05), "#F2F2F0"),
            BV((0, -0.82, 0.8), (1.3, 0.12, 1.0), "Navy", bevel=0.1),
            BV((0, -0.86, 1.45), (1.3, 0.16, 0.35), "Gold", bevel=0.08, rot=(-20, 0, 0)),
            C((0.7, 0.2, 1.9), 0.05, 0.6, "#9AA0AA", seg=6),
            E((0.7, 0.2, 2.25), (0.1, 0.1, 0.1), "Carpet", neon=True),
        ]
        # The face shows through the visor's open window.
        s.append(B((0, -0.89, 0.8), (1.0, 0.04, 0.75), skin))
        for x in (-0.3, 0.3):
            s.append(B((x, -0.92, 0.88), (0.2, 0.04, 0.3), "#2E2C34"))
        s.append(B((0, -0.92, 0.55), (0.4, 0.04, 0.08), "#782832"))
    elif who == "Alien":
        # A big green head with huge black eyes and two bobbly antennae.
        s = [
            BV((0, 0, 0.9), (1.7, 1.5, 1.8), skin, bevel=0.35),
            BV((0, 0, 0.25), (1.2, 1.1, 0.5), skin, bevel=0.15),
        ]
        for x in (-0.42, 0.42):
            s += [
                E((x, -0.7, 1.05), (0.34, 0.1, 0.42), "#14121A", rot=(0, x * -40, 0)),
                E((x - 0.1, -0.78, 1.2), (0.08, 0.04, 0.08), "OffWhite"),
                C((x, 0, 2.05), 0.05, 0.6, skin, rot=(0, x * 30, 0), seg=6),
                E((x * 1.5, 0, 2.35), (0.16, 0.16, 0.16), "Purple", neon=True),
            ]
        s.append(B((0, -0.74, 0.45), (0.35, 0.06, 0.07), "#2E5A22"))
    elif who == "Explorer":
        s = face(skin, "grin")
        s += [
            # A battered brown fedora and a bit of stubble.
            C((0, 0, 1.56), 1.15, 0.1, "#7A5434", seg=14),
            BV((0, 0, 1.9), (1.3, 1.2, 0.66), "#7A5434", bevel=0.2),
            B((0, 0, 1.66), (1.34, 1.24, 0.16), "#2E2C34"),
            BV((0, -0.73, 0.28), (0.9, 0.05, 0.22), shade(skin, 0.18)),
        ]
    elif who == "Guide":
        s = face(skin, "smile")
        s += [
            # A cork safari helmet.
            C((0, 0, 1.56), 1.1, 0.1, "#E8D9B0", seg=14),
            E((0, 0, 1.7), (0.82, 0.78, 0.55), "#E8D9B0"),
            B((0, 0, 1.62), (1.5, 1.42, 0.14), "#7A5434"),
        ]
    elif who == "Boom":
        s = face(skin, "smile")
        s += [
            # A knitted beanie under big headphones.
            BV((0, 0.05, 1.6), (1.6, 1.5, 0.45), "#E87A2E", bevel=0.18),
            B((0, 0.05, 1.42), (1.62, 1.52, 0.14), shade("#E87A2E", 0.2)),
            E((0, 0.05, 1.9), (0.18, 0.18, 0.14), "OffWhite"),
            B((0, 0, 1.76), (1.74, 0.22, 0.16), "#2E2C34"),
        ]
        for x in (-0.84, 0.84):
            s += [C((x, 0, 0.95), 0.4, 0.3, "#2E2C34", rot=(0, 90, 0), seg=10), B((x, 0, 1.4), (0.12, 0.22, 0.75), "#2E2C34")]
    elif who == "Gaffer":
        s = face(skin, "grin")
        s += [
            # A yellow cap with a little lamp clipped to it, and a beard.
            BV((0, 0.05, 1.6), (1.56, 1.46, 0.36), "Duck", bevel=0.15),
            BV((0, -0.95, 1.47), (1.1, 0.7, 0.12), "Duck"),
            E((0, -0.76, 1.66), (0.14, 0.06, 0.12), "Light", neon=True),
            BV((0, -0.72, 0.28), (1.2, 0.1, 0.42), "#2A1E18"),
        ]
    elif who == "Makeup":
        s = face(skin, "smile")
        s += [
            # Pink hair in a high ponytail, with a headband and rosy cheeks.
            BV((0, 0.15, 1.5), (1.6, 1.3, 0.4), "#C24F8E", bevel=0.15),
            BV((0, 0.62, 1.0), (1.56, 0.3, 1.2), "#C24F8E", bevel=0.12),
            B((0, 0, 1.52), (1.64, 1.44, 0.14), "Teal"),
            E((0, 0.8, 1.6), (0.32, 0.32, 0.3), "#C24F8E"),
            K((0, 0.95, 1.1), 0.28, 0.08, 0.9, "#C24F8E", rot=(160, 0, 0), seg=6),
        ]
        s += [B((x, -0.72, 0.62), (0.22, 0.04, 0.12), "#FF9CB8") for x in (-0.5, 0.5)]
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


def flag():
    """A flag on a pole, held by the pole's foot (the pole runs along -Z, the arm's way)."""
    return [
        C((0, 0, -2.5), 0.07, 5.0, "Chrome", seg=6),
        BV((-1.2, 0, -4.4), (2.4, 0.06, 1.5), "Carpet", bevel=0.02),
        B((-1.2, -0.04, -4.4), (2.2, 0.04, 0.3), "OffWhite"),
        S((-0.6, -0.05, -4.75), 0.22, 0.04, "OffWhite"),
        E((0, 0, -5.05), (0.12, 0.12, 0.12), "Gold"),
    ]


def idol():
    """The golden idol: a squat statue with a big head, held from below (it sits along -Z)."""
    return [
        BV((0, 0, -0.25), (0.6, 0.6, 0.3), "Gold"),
        BV((0, 0, -0.65), (0.5, 0.45, 0.5), "Gold"),
        BV((0, 0, -1.15), (0.75, 0.65, 0.6), "Gold", bevel=0.12),
        E((-0.15, -0.34, -1.2), (0.07, 0.03, 0.07), "Carpet", neon=True),
        E((0.15, -0.34, -1.2), (0.07, 0.03, 0.07), "Carpet", neon=True),
    ]


def torch():
    """A burning torch, held by the handle; the flame is at the far end (-Z)."""
    return [
        C((0, 0, -0.9), 0.1, 1.8, "#7A5434", seg=6),
        K((0, 0, -1.85), 0.12, 0.22, 0.3, "#5A3A24", seg=8),
        K((0, 0, -2.3), 0.22, 0.02, 0.7, "Flame", rot=(180, 0, 0), seg=8, neon=True),
    ]


def boulder():
    """The rolling boulder, centred on the origin (FilmSetWorld rolls it about its middle)."""
    return [
        L((0, 0, 0), (3.2, 3.2, 3.2), "#8C8478", jitter=0.06),
        L((1.2, -2.3, 1.2), (0.9, 0.9, 0.8), "#6E675E", jitter=0.08),
        L((-1.6, 1.0, -1.8), (0.8, 0.9, 0.8), "#6E675E", jitter=0.08),
    ]


def boom_pole():
    """The boom mic: a long pole held at its foot (the pole runs along -Z, the way it points) with
    a furry windshield hanging under the far end."""
    return [
        C((0, 0, -0.3), 0.14, 0.6, "#2E2C34", seg=8),
        C((0, 0, -5.0), 0.08, 9.4, "Steel", seg=6),
        C((0, 0, -9.7), 0.11, 0.2, "#2E2C34", seg=8),
        C((0, 0.25, -9.75), 0.05, 0.5, "#2E2C34", rot=(90, 0, 0), seg=6),
        L((0, 0.62, -9.75), (0.32, 0.3, 0.75), "#9AA0AA", rot=(0, 0, 0), jitter=0.12),
    ]


def makeup_brush():
    """A fat make-up brush, held by the handle (the bristles at the far end, -Z)."""
    return [
        C((0, 0, -0.35), 0.07, 0.7, "#2E2C34", seg=6),
        C((0, 0, -0.78), 0.09, 0.18, "Chrome", seg=6),
        E((0, 0, -1.05), (0.17, 0.17, 0.26), "Pink"),
    ]


# --- The camera rig (the dolly rolls on its track; FilmScenes moves the dolly, arm and camera) ---

RAIL_X = 1.1  # the rails either side of the track's middle
TRACK_LONG = 14.0


def dolly_track():
    """Two steel rails on wooden sleepers, TRACK_LONG studs along the model's Y (game Z)."""
    s = []
    n = 10
    for i in range(n):
        y = -TRACK_LONG / 2 + (i + 0.5) * TRACK_LONG / n
        s.append(BV((0, y, 0.1), (3.2, 0.5, 0.2), "Wood", bevel=0.04))
    for x in (-RAIL_X, RAIL_X):
        s += [
            B((x, 0, 0.3), (0.22, TRACK_LONG, 0.2), "Steel"),
            B((x, 0, 0.43), (0.12, TRACK_LONG, 0.06), "Chrome"),
        ]
        for y in (-TRACK_LONG / 2, TRACK_LONG / 2):
            s.append(BV((x, y, 0.45), (0.4, 0.3, 0.5), "Carpet", bevel=0.05))
    return s


def dolly():
    """The dolly cart: a platform on four wheels that sit on the rails (the track runs along Y),
    a push bar at the back and a post up the middle with a turntable for the jib arm (its hinge
    4.6 above the origin, which is the ground under the cart's middle)."""
    s = [
        BV((0, 0, 0.82), (3.6, 3.6, 0.32), "#2E2C34", bevel=0.08),
        B((0, 0, 1.0), (3.3, 3.3, 0.06), "#4A4852"),
        BV((0, 0, 0.6), (2.6, 3.2, 0.2), "Steel"),
    ]
    for x in (-RAIL_X, RAIL_X):
        for y in (-1.2, 1.2):
            s += [
                C((x, y, 0.62), 0.22, 0.2, "#14121A", rot=(0, 90, 0), seg=10),
                C((x, y, 0.62), 0.1, 0.24, "Chrome", rot=(0, 90, 0), seg=6),
            ]
    # The push bar at the back (+Y), the post and the turntable.
    for x in (-1.3, 1.3):
        s.append(C((x, 1.65, 1.6), 0.07, 1.3, "Chrome", seg=6))
    s += [
        C((0, 1.65, 2.25), 0.08, 2.7, "Chrome", rot=(0, 90, 0), seg=6),
        C((0, 0, 1.4), 0.5, 0.7, "#2E2C34", seg=10),
        C((0, 0, 2.8), 0.22, 2.4, "Chrome", seg=8),
        C((0, 0, 4.1), 0.42, 0.25, "Gold", seg=10),
        BV((0, 0, 4.4), (0.5, 0.7, 0.4), "#2E2C34"),
    ]
    return s


JIB_FRONT = 6.5  # the camera hangs this far in front of the hinge


def jib_arm():
    """The crane arm, hinged at the origin: a yellow truss JIB_FRONT studs forward (-Y), and
    just behind the hinge the counterweights, with the handle bar hanging under the back end for
    the operator, who stands behind it on the dolly."""
    s = [
        BV((0, -JIB_FRONT / 2 + 0.4, 0), (0.42, JIB_FRONT + 0.8, 0.42), "Gold", bevel=0.06),
        B((0, -JIB_FRONT / 2 + 0.4, 0.28), (0.16, JIB_FRONT, 0.12), "#2E2C34"),
        BV((0, 0.5, 0), (0.42, 1.0, 0.42), "Gold", bevel=0.06),
        C((0, 0, 0), 0.18, 0.9, "#2E2C34", rot=(0, 90, 0), seg=8),
        BV((0, -JIB_FRONT, -0.05), (0.6, 0.5, 0.5), "#2E2C34"),
    ]
    s += [C((0, 0.55 + i * 0.27, 0), 0.48, 0.22, "#14121A", rot=(90, 0, 0), seg=12) for i in range(2)]
    s += [
        C((0, 0.98, -0.47), 0.06, 0.95, "Chrome", seg=6),
        C((0, 0.98, -0.95), 0.07, 1.4, "#2E2C34", rot=(0, 90, 0), seg=6),
    ]
    return s


def camera_head():
    """The film camera hanging under the arm's tip (the origin): a stem, the camera with its
    lens and matte box toward -Y, a film magazine on top and a little monitor at the back."""
    s = [
        C((0, 0, -0.3), 0.12, 0.6, "#2E2C34", seg=8),
        BV((0, 0, -1.25), (1.1, 1.9, 1.2), "#2E2C34", bevel=0.1),
        C((0, -1.25, -1.25), 0.36, 0.7, "#14121A", rot=(90, 0, 0), seg=12),
        C((0, -1.62, -1.25), 0.4, 0.06, "Glass", rot=(90, 0, 0), seg=12),
        BV((0, -1.75, -1.25), (1.0, 0.25, 0.9), "#2E2C34", bevel=0.04),
        C((0, 0.35, -0.42), 0.5, 0.3, "#2E2C34", rot=(0, 90, 0), seg=12),
        C((0, -0.45, -0.42), 0.5, 0.3, "#2E2C34", rot=(0, 90, 0), seg=12),
        BV((0.5, 0.95, -1.1), (0.08, 0.5, 0.4), "#14121A"),
        E((0.0, 0.0, -1.0), (0.05, 0.05, 0.05), "Carpet", neon=True),
    ]
    s.append(B((0.0, 0.97, -1.15), (0.6, 0.04, 0.4), "Glass"))
    return s


def light_stand():
    """A tripod stand for the lamp: three legs and a pole up to the lamp's hinge (4.8 up)."""
    s = [C((0, 0, 2.6), 0.1, 4.4, "#2E2C34", seg=6), C((0, 0, 1.1), 0.16, 0.5, "Steel", seg=8)]
    tilt = math.degrees(math.atan2(0.9, 1.1))
    length = math.hypot(0.9, 1.1)
    for a in (0, 120, 240):
        s.append(G((0, 0, 0), (0, 0, a), C((0, 0.45, 0.55), 0.06, length, "#2E2C34", rot=(tilt, 0, 0), seg=5), E((0, 0.9, 0.05), (0.14, 0.14, 0.06), "#14121A")))
    s.append(C((0, 0, 4.7), 0.14, 0.2, "Steel", seg=8))
    return s


def light_head():
    """The film lamp, turned about its hinge (the origin): a black housing with a glowing lens
    toward -Y, four barn doors round it, a yoke down to the stand and a handle on top."""
    s = [
        BV((0, 0.1, 0.55), (1.4, 1.5, 1.3), "#2E2C34", bevel=0.1),
        C((0, -0.68, 0.55), 0.5, 0.08, "Light", rot=(90, 0, 0), seg=12, neon=True),
        B((0, -0.95, 1.28), (1.4, 0.5, 0.06), "#14121A", rot=(-25, 0, 0)),
        B((0, -0.95, -0.18), (1.4, 0.5, 0.06), "#14121A", rot=(25, 0, 0)),
        B((0.75, -0.95, 0.55), (0.06, 0.5, 1.3), "#14121A", rot=(0, 0, -25)),
        B((-0.75, -0.95, 0.55), (0.06, 0.5, 1.3), "#14121A", rot=(0, 0, 25)),
        C((0, 0.1, 1.35), 0.06, 0.8, "Chrome", rot=(0, 90, 0), seg=6),
        BV((0, 0.85, 0.55), (0.9, 0.12, 0.7), "#4A4852"),
    ]
    for x in (-0.8, 0.8):
        s.append(B((x, 0.1, 0.25), (0.1, 0.3, 0.7), "Steel"))
    s.append(B((0, 0.1, -0.08), (1.7, 0.3, 0.1), "Steel"))
    return s


def makeup_kit():
    """The make-up table: a little folding table with an open case of colours and brushes, a
    mirror ringed with bulbs, and a stool."""
    s = [BV((0, 0, 2.0), (2.4, 1.4, 0.15), "#E8D9B0", bevel=0.04)]
    for x in (-1.0, 1.0):
        for y in (-0.55, 0.55):
            s.append(C((x, y, 1.0), 0.06, 2.0, "Steel", seg=5))
    s += [
        BV((-0.35, -0.05, 2.25), (1.3, 0.8, 0.35), "#2E2C34", bevel=0.05),
        BV((-0.35, 0.38, 2.75), (1.3, 0.1, 0.8), "#2E2C34", bevel=0.04, rot=(-15, 0, 0)),
    ]
    for i, c in enumerate(["Carpet", "Pink", "Gold", "Teal", "Purple", "#A56C44"]):
        s.append(B((-0.8 + (i % 3) * 0.45, -0.2 + (i // 3) * 0.32, 2.45), (0.34, 0.24, 0.06), c))
    s += [
        BV((0.75, 0.3, 2.95), (0.9, 0.1, 1.5), "#E8D9B0", bevel=0.05),
        B((0.75, 0.24, 2.95), (0.7, 0.04, 1.3), "Glass"),
        C((0.75, 0.3, 2.1), 0.05, 0.3, "Steel", seg=5),
    ]
    for z in (2.4, 2.95, 3.5):
        for x in (0.25, 1.25):
            s.append(E((x, 0.22, z), (0.08, 0.06, 0.08), "Light", neon=True))
    for x in (0.4, 0.75, 1.1):
        s.append(E((x, 0.22, 3.72), (0.08, 0.06, 0.08), "Light", neon=True))
    s += [C((0.75, -0.3, 2.2), 0.04, 0.4, c, seg=5) for c in ("Gold",)]
    # A round stool beside the table.
    s += [C((-1.9, -0.6, 1.4), 0.5, 0.18, "Carpet", seg=10), C((-1.9, -0.6, 0.7), 0.07, 1.3, "Chrome", seg=6), C((-1.9, -0.6, 0.06), 0.4, 0.1, "Chrome", seg=10)]
    return s


def open_door(width, height, leaf=True):
    """An open doorway to stand against a wall (its back at y = 0): a frame round a dark opening,
    and the door leaf swung right back against the wall beside it."""
    t = 0.32
    s = [
        B((0, -t / 2, height / 2), (width, t * 0.5, height), "#14121A"),
        BV((-(width / 2 + 0.2), -t / 2, height / 2 + 0.1), (0.4, t, height + 0.2), "Cream", bevel=0.05),
        BV((width / 2 + 0.2, -t / 2, height / 2 + 0.1), (0.4, t, height + 0.2), "Cream", bevel=0.05),
        BV((0, -t / 2, height + 0.2), (width + 0.8, t, 0.4), "Cream", bevel=0.05),
        B((0, -t * 0.4, 0.04), (width, t * 0.6, 0.08), "Bark"),
    ]
    if leaf:
        lx = -(width / 2 + 0.4 + width / 2)
        s += [
            BV((lx, -0.12, height / 2), (width - 0.1, 0.18, height - 0.1), "Bark", bevel=0.04),
            B((lx, -0.23, height * 0.72), (width - 0.6, 0.04, height * 0.3), shade(COL_BARK, 0.15)),
            B((lx, -0.23, height * 0.3), (width - 0.6, 0.04, height * 0.3), shade(COL_BARK, 0.15)),
            E((lx - width / 2 + 0.4, -0.27, height * 0.48), (0.14, 0.08, 0.14), "Gold"),
        ]
    return s


COL_BARK = "#7A5434"


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
    ("PropFlag", flag),
    ("PropIdol", idol),
    ("PropTorch", torch),
    ("PropBoulder", boulder),
    ("PropBoomPole", boom_pole),
    ("PropMakeupBrush", makeup_brush),
    ("CrewDollyTrack", dolly_track),
    ("CrewDolly", dolly),
    ("CrewJibArm", jib_arm),
    ("CrewCameraHead", camera_head),
    ("CrewLightStand", light_stand),
    ("CrewLightHead", light_head),
    ("CrewMakeupKit", makeup_kit),
    ("CrewOpenDoor", _v(open_door, 3.8, 7.0)),
    ("CrewBalconyDoor", _v(open_door, 3.2, 6.2, False)),
    ("SetGate", set_gate),
    ("SetGateArm", set_gate_arm),
]

# Set gear that stands on the ground like any kit model; everything else (rig pieces, props and
# the moving parts of the camera rig and the lamp) keeps its own origin as its joint.
GROUNDED = {"SetGate", "CrewDollyTrack", "CrewLightStand", "CrewMakeupKit", "CrewOpenDoor", "CrewBalconyDoor"}
NO_LIFT = {name for name, _ in KIT if name not in GROUNDED}

LINEUPS = {
    "map_kit_crew.png": (
        [f"Crew{who}{part}" for who in ("Director", "Clapper", "Operator") for part in RIG_PARTS],
        [f"Crew{who}{part}" for who in ("Sheriff", "Outlaw", "Stunt") for part in RIG_PARTS]
        + ["PropMegaphone", "PropRevolver", "PropClapper", "PropClapperStick"],
    ),
    "map_kit_crew_sets.png": (
        [f"Crew{who}{part}" for who in ("Astronaut", "Alien") for part in RIG_PARTS],
        [f"Crew{who}{part}" for who in ("Explorer", "Guide") for part in RIG_PARTS] + ["PropFlag", "PropIdol", "PropTorch", "PropBoulder"],
    ),
    "map_kit_crew_more.png": (
        [f"Crew{who}{part}" for who in ("Boom", "Gaffer", "Makeup") for part in RIG_PARTS] + ["PropBoomPole", "PropMakeupBrush"],
        ["CrewDollyTrack", "CrewDolly", "CrewJibArm", "CrewCameraHead", "CrewLightStand", "CrewLightHead", "CrewMakeupKit", "CrewOpenDoor", "CrewBalconyDoor"],
    ),
    "map_kit_set_gate.png": (["SetGate"], ["SetGateArm"]),
}
