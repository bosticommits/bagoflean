"""Actors v2, batch 2 of the old 21: the next seven old actors polished to the approved style bible
(Nervous Intern A, Werewolf Pup, Captain Squawk, plus batch 1). Same characters, costumes, colours and props
as the in-game versions in actors.py; rebuilt with the v2 kit (actors_v2.py): pill head with face parts on its
surface (costume actors: box head + face plate), two-segment bevels, vertex-colour AO, tier plinth.

  Night Shift Villain (Pro) - Teen Heartthrob, Method Knight, Alien Captain (Star)
  Box Office King, Scream Queen, Cupid (Superstar)

Run live (MCP for Blender): see load() at the bottom; finalize_b2() builds, QAs, renders everything and exports
the draft FBX files (1/28). Taste rules: vault `Movie Mogul/Actor References.md`.
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import actors_v2 as K  # noqa: E402
from actors_v2 import EYE_DARK, EYE_Z, HEAD_Z0, head_at, head_box, head_patch, legs_kid, arm, shade, mix, torso  # noqa: E402
from actors_v2_b1 import MOUTH, PINK, WHITE, along, brow1, dome, ears, eye1, mouth_grin, mouth_o, tube  # noqa: E402

HOT_PINK = "#FF5FA8"


def heart(f, at, s=1.0, color=HOT_PINK, rot=(0, 0, 0)):
    """A chunky 3D heart facing the camera: two plump lobes and a point."""
    with f.at(at, rot):
        for sx in (-1, 1):
            f.ball((sx * 0.21 * s, 0, 0.14 * s), (0.27 * s, 0.17 * s, 0.27 * s), color, seg=6, rings=4)
        f.spike((0, 0, 0.1 * s), 0.46 * s, 0.7 * s, color, rot=(180, 0, 0), seg=4, squash=0.38)


def sparkle(f, at, s=1.0, color="#FFFFFF"):
    """Four-point shine facing the camera (two crossed diamonds)."""
    with f.at(at, (90, 0, 0)):
        f.disc((0, 0, 0), 0.16 * s, 0.62 * s, 0.05, color, seg=4)
        f.disc((0, 0, 0), 0.62 * s, 0.16 * s, 0.05, color, seg=4)


# --- 1. Night Shift Villain (Pro, Horror) -----------------------------------------------------


def night_villain(f):
    """Pro (Horror). A vampire actor on the night shift: pale face, glowing red eyes, slicked widow's-peak hair,
    a lopsided fanged smirk, a huge flared collar and a bat-hem cape that flares out past both shoulders,
    purple-black suit with a red-lilac ruffled front, and a glowing lantern in one hand, the other hand a spooky claw."""
    skin, suit, suit_lt, pants, shoes = "#D6DBEA", "#2B1F48", "#43306E", "#1E1A2E", "#2E2C34"
    red, red_dk, gold, hair, ruffle = "#C8202F", "#8E1624", "#F5B82E", "#161220", "#EDE6F6"
    RAISE = 0.3
    with f.piece("Body"):  # cape first (behind everything): outer purple, red lining shows at the flared sides
        f.rbox((0, 1.05, 2.25), (4.25, 0.2, 3.5), suit, bevel=0.0, taper=0.55, rot=(8, 0, 0))
        f.rbox((0, 0.9, 2.25), (4.08, 0.16, 3.36), red, bevel=0.0, taper=0.55, rot=(8, 0, 0))
        for x in (-1.5, 0.0, 1.5):  # bat-wing scallops along the hem
            f.spike((x, 1.15, 0.55), 0.75, 0.55, suit, rot=(180, 0, 0), seg=4, squash=0.25)
        for s_ in (-1, 1):  # tall flared collar blades behind the head
            f.rbox((s_ * 1.5, 0.6, 3.95), (1.25, 0.2, 2.3), lambda fc: red if fc.normal.y < -0.5 else red_dk, rot=(0, s_ * 16, 0), bevel=0.0, taper=0.14)
    legs_kid(f, pants, shoes, "#14121C")
    torso(f, suit, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), pants, bevel=0.1)
        f.rbox((0, 0, 1.62), (1.92, 1.44, 0.12), "#14121C", bevel=0.0)
        f.rbox((0, -0.71, 1.62), (0.3, 0.08, 0.2), gold, bevel=0.0)
        f.rbox((0, -0.69, 2.2), (0.8, 0.08, 1.3), ruffle, bevel=0.0, taper=1.5)  # ruffled shirt front
        for i in range(3):  # ruffle frills
            f.ball((0, -0.76, 2.0 + i * 0.32), (0.34, 0.14, 0.15), "#FFFFFF", seg=5, rings=3)
        for s_ in (-1, 1):  # lapels + gold cape clasps on the shoulders
            f.rbox((s_ * 0.55, -0.71, 2.3), (0.36, 0.08, 1.2), suit_lt, rot=(0, s_ * 16, 0), bevel=0.0)
            with f.at((s_ * 0.85, -0.55, 2.75), (90, 0, 0)):
                f.disc((0, 0, 0), 0.32, 0.32, 0.08, gold, seg=6)
        f.ball((0, -0.78, 2.72), (0.2, 0.1, 0.22), "#E8283E", seg=5, rings=3)  # blood-red brooch

    def lantern(f):
        f.rcyl((0, 0, -0.3), 0.05, 0.05, 0.5, "#2E2C34", seg=4, bevel=0.0)  # chain
        f.rcyl((0, 0, -0.62), 0.3, 0.46, 0.22, "#2E2C34", seg=6, bevel=0.0)  # cap
        f.rcyl((0, 0, -1.1), 0.58, 0.5, 0.75, "#FFE27A", seg=6, bevel=0.04)  # glowing glass
        f.rcyl((0, 0, -1.55), 0.58, 0.58, 0.18, "#2E2C34", seg=6, bevel=0.0)  # base

    arm(f, 1, suit, skin, rot=(-30, 58, 0), held=lantern, upright=True, shoulder_z=2.55, sleeve_r=0.34)
    arm(f, -1, suit, skin, rot=(-72, 44, 0), shoulder_z=2.55, sleeve_r=0.34)
    with f.piece("ArmR"), f.at((-1.1, 0, 2.55), (-72, -44, 0)):  # white cuff + three clawed fingers
        f.rcyl((0, 0, -0.78), 0.4, 0.34, 0.2, ruffle, seg=7, bevel=0.0)
        for i, ang in enumerate((-35, 0, 35)):
            f.spike((0, 0, -1.2), 0.1, 0.5, "#E8E4F4", rot=(180, ang, 0), seg=4)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22, k=1.15)
        for s_ in (-1, 1):  # pointed ears: a little spike each
            with f.piece("Head"):
                f.spike((s_ * 1.28, 0.05, ez + 0.1), 0.2, 0.55, shade(skin, 0.94), rot=(0, s_ * 40, 0), seg=4, squash=0.6)
        K.face_eyes(f, skin, spread=0.6, k=1.0, z=ez, color="#E8283E", socket=True)
        with f.piece("Head"):  # dark eye shadow under the glowing eyes
            for s_ in (-1, 1):
                head_patch(f, s_ * 0.6, ez - 0.55, 0.36, 0.1, 0.03, "#8A86A8", seg=6, rings=1)
        K.face_brows(f, "#161220", length=1.0, thick=0.22, angle=18, x=0.62, z=ez + 0.72, worried=False, lift=(0.0, 0.1))
        # a lopsided smirk: one corner pulled up, two fangs of different lengths
        with f.piece("Head"):
            head_patch(f, 0.12, ez - 0.72, 0.5, 0.17, 0.05, "#5A1626", seg=8, rings=1)
            head_patch(f, 0.58, ez - 0.6, 0.15, 0.1, 0.05, "#5A1626", seg=6, rings=1)  # raised corner
            for x, h in ((-0.1, 0.34), (0.38, 0.26)):
                with head_at(f, x, ez - 0.6, 0.02):
                    f.spike((0, 0, 0.0), 0.1, h, WHITE, rot=(180, 0, 0), seg=4)
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), hair, seg=8, rings=5)  # slicked cap
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            with head_at(f, 0, top - 0.78, 0.05):  # widow's peak
                f.spike((0, 0, 0.0), 0.34, 0.5, hair, rot=(180, 0, 0), seg=3)


# --- 2. Teen Heartthrob (Star, Romance) -------------------------------------------------------


def heartthrob(f):
    """Star (Romance). The teen heartthrob: a towering swept pompadour, a wink with a shine, a lopsided open grin,
    red letterman jacket with white sleeves, collar and a gold letter patch, jeans and white sneakers, a
    blue guitar held up high, and fan hearts floating round him."""
    skin, red, white, jeans, hair, hair_lt = "#E8B98A", "#C8202F", "#FAF6EC", "#3A5A9A", "#1A1626", "#5C5078"
    gold, blue, wood = "#F5B82E", "#2E86DE", "#9A6434"
    RAISE = 0.3
    legs_kid(f, jeans, white, "#C8C2B4", r=0.38)
    torso(f, red, h=1.7, z=2.0, w=1.95)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.0, 1.46, 0.4), red, bevel=0.1)
        f.rbox((0, 0, 1.16), (2.04, 1.5, 0.22), white, bevel=0.04)  # ribbed hem
        f.rbox((0, -0.69, 2.0), (0.52, 0.08, 1.55), white, bevel=0.0)  # front placket
        for z in (1.6, 2.0, 2.4):
            with f.at((0.0, -0.76, z), (90, 0, 0)):
                f.disc((0, 0, 0), 0.2, 0.2, 0.07, gold, seg=6)  # snap buttons
        with f.at((-0.62, -0.7, 2.4), (90, 0, 0)):  # gold letter patch
            f.disc((0, 0, 0), 0.62, 0.62, 0.07, gold, seg=8)
            for s_ in (-1, 1):
                f.rbox((s_ * 0.14, -0.05, 0), (0.1, 0.06, 0.4), red, bevel=0.0)
            f.rbox((0, -0.05, 0), (0.3, 0.06, 0.1), red, bevel=0.0)
        f.rbox((0, 0.0, 2.95), (1.5, 1.2, 0.2), white, bevel=0.06)  # collar band

    def guitar(f):  # tall in the world, held at the waist: body low, neck + headstock rising past the shoulder
        with f.at((0.25, -0.35, 0.3), (0, 24, 0)):
            f.ball((0, 0, 0.0), (0.7, 0.2, 0.62), blue, seg=8, rings=5)
            f.ball((0, 0, 0.55), (0.45, 0.2, 0.42), blue, seg=8, rings=4)  # waist of the guitar
            with f.at((0, -0.2, 0.0), (90, 0, 0)):
                f.disc((0, 0, 0), 0.5, 0.5, 0.06, "#161220", seg=8)  # sound hole
                f.disc((0.0, -0.05, -0.55), 0.7, 0.14, 0.06, white, seg=6)  # pickguard
            f.rbox((0, -0.05, 1.45), (0.2, 0.12, 1.5), "#7A5434", bevel=0.03)  # neck
            f.rbox((0, -0.05, 2.4), (0.34, 0.14, 0.5), "#161220", bevel=0.05)  # headstock

    arm(f, 1, white, skin, rot=(-42, 22, 0), held=guitar, upright=True, shoulder_z=2.55, x=1.2, sleeve_r=0.34)
    arm(f, -1, white, skin, rot=(-30, 24, 0), shoulder_z=2.55, x=1.2, sleeve_r=0.34)
    with f.piece("ArmR"), f.at((-1.2, 0, 2.55), (-30, -24, 0)):
        f.rcyl((0, 0, -0.78), 0.4, 0.36, 0.14, red, seg=7, bevel=0.0)
    with f.piece("ArmL"), f.at((1.2, 0, 2.55), (-42, -22, 0)):
        f.rcyl((0, 0, -0.78), 0.4, 0.36, 0.14, red, seg=7, bevel=0.0)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        eye1(f, skin, 0.6, ez, k=1.05)  # open eye (actor's left)
        with f.piece("Head"), head_at(f, -0.6, ez, 0.0):  # winking eye: a happy arc
            for x, z, a in ((-0.3, -0.06, 36), (0.0, 0.1, 0), (0.3, -0.06, -36)):
                f.rbox((x, 0.0, z), (0.42, 0.1, 0.17), "#241710", rot=(0, a, 0), bevel=0.0)
        K.face_brows(f, "#161220", length=1.0, thick=0.22, angle=8, x=0.62, z=ez + 0.72, worried=False, lift=(0.3, 0.0))
        K.face_blush(f, x=0.92, z=ez - 0.34, seg=6)
        with f.piece("Head"):  # lopsided open grin: dark mouth, top teeth, tongue, dimple
            head_patch(f, 0.0, ez - 0.76, 0.66, 0.3, 0.05, MOUTH, seg=8, rings=1)
            head_patch(f, 0.0, ez - 0.6, 0.6, 0.11, 0.075, WHITE, seg=8, rings=1)
            head_patch(f, 0.18, ez - 0.92, 0.28, 0.1, 0.075, "#E86A7A", seg=6, rings=1)
            with head_at(f, 0.78, ez - 0.62, 0.04):
                f.rbox((0, 0, 0), (0.07, 0.05, 0.22), shade(skin, 0.7), rot=(0, 24, 0), bevel=0.0)
        with f.piece("Head"):
            # tight dark cap, clear forehead
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            # the pompadour, a swept curl: a rolled slab over the brow, a tilted leaf that sweeps up and back off it,
            # and a lighter highlight leaf on top (low and wide, so it never reads as a tall black block)
            f.rcyl((-0.1, -0.3, top + 0.02), 0.58, 0.58, 1.9, hair, rot=(0, 90, -18), seg=8, bevel=0.2, segs=2)  # the roll
            f.leaf((-1.0, -0.25, top + 0.0), (-14, 62, 0), 2.7, 1.1, 0.8, hair, tip=0.2, widest=0.4)  # sweeps up and over, tip high on the right
            f.leaf((-0.75, -0.62, top + 0.3), (-14, 62, 0), 2.2, 0.5, 0.22, hair_lt, tip=0.45, widest=0.45)  # highlight along the sweep
            for s_ in (-1, 1):  # sideburns
                f.rbox((s_ * 1.2, -0.15, top - 1.2), (0.2, 0.5, 0.65), hair, bevel=0.05)
    with f.piece("Body"):  # fan hearts floating by
        heart(f, (-2.25, 0.2, 3.9), 1.0)
        heart(f, (2.3, 0.5, 5.6), 0.8)


# --- 3. Method Knight (Star, Horror) ----------------------------------------------------------


def method_knight(f):
    """Star (Horror). A method actor who has not taken his knight armour off in three months: steel great helm
    (box head + dark face plate: tired side-eyes in the slit, nasal bar, breathing holes), a huge red plume,
    round pauldrons, maroon tabard with a gold gem, a long sword held up high and a blue shield with a gold film-reel crest."""
    steel, steel2, dark, tabard, gold = "#C9CED9", "#8D94A6", "#23202E", "#7A1F2B", "#F5B82E"
    red = "#E8333A"
    RAISE = 0.2
    legs_kid(f, steel2, steel, "#6E7486", spread=0.5, r=0.4)
    torso(f, steel, h=1.7, z=2.0, w=2.1, d=1.5)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.1, 1.52, 0.4), steel2, bevel=0.1)
        f.rbox((0, -0.05, 2.0), (2.0, 1.56, 1.25), tabard, bevel=0.1, segs=1, taper=0.9)  # tabard
        f.rbox((0, -0.8, 1.55), (1.7, 0.1, 0.18), "#4A1018", bevel=0.0)  # belt
        with f.at((0, -0.82, 2.25), (90, 0, 0)):
            f.disc((0, 0, 0), 0.52, 0.52, 0.08, gold, seg=6)
            f.disc((0, -0.01, 0.06), 0.26, 0.26, 0.06, "#E8283E", seg=6)
        for s_ in (-1, 1):  # big round pauldrons
            f.ball((s_ * 1.4, 0, 2.85), (0.8, 0.8, 0.55), steel, seg=8, rings=4)
            f.rcyl((s_ * 1.4, 0, 3.1), 0.3, 0.3, 0.16, gold, seg=6, bevel=0.0)

    def sword(f):  # point up, held like a salute
        f.rbox((0, 0, 0.0), (0.2, 0.18, 0.6), "#7A5434", bevel=0.04)  # grip
        f.ball((0, 0, -0.34), (0.18, 0.18, 0.18), gold, seg=6, rings=3)  # pommel
        f.rbox((0, 0, 0.36), (0.95, 0.2, 0.16), gold, bevel=0.04)  # guard
        f.rbox((0, 0, 1.9), (0.5, 0.14, 3.2), "#E6EAF2", bevel=0.04, taper=0.5)  # blade
        f.rbox((0, -0.08, 1.7), (0.1, 0.05, 2.6), "#9AA4BC", bevel=0.0)  # fuller

    def shield(f):  # a heater shield held in front, face to camera
        with f.at((-0.35, -0.45, 0.35)):
            f.rbox((0, 0, 0.0), (1.4, 0.2, 2.0), "#2E86DE", bevel=0.14, segs=1, taper=1.5)
            f.rbox((0, -0.05, 0.0), (1.55, 0.14, 2.15), gold, bevel=0.0, taper=1.5)
            f.rbox((0, -0.1, 0.0), (1.2, 0.14, 1.75), "#2E86DE", bevel=0.0, taper=1.5)
            f.spike((0, 0, -0.95), 0.62, 0.7, gold, rot=(180, 0, 0), seg=4, squash=0.3)  # pointed foot
            with f.at((0, -0.2, 0.25), (90, 0, 0)):  # film-reel crest
                f.disc((0, 0, 0), 0.9, 0.9, 0.08, gold, seg=8)
                f.disc((0, 0, 0.06), 0.28, 0.28, 0.06, dark, seg=6)
                for k in range(5):
                    a = math.radians(90 + k * 72)
                    f.disc((0.27 * math.cos(a), 0.27 * math.sin(a), 0.06), 0.18, 0.18, 0.06, dark, seg=5)

    arm(f, 1, steel2, steel, rot=(-30, 40, 0), held=sword, upright=True, shoulder_z=2.55, x=1.5, sleeve_r=0.4)
    arm(f, -1, steel2, steel, rot=(-50, 14, 0), held=shield, upright=True, shoulder_z=2.55, x=1.5, sleeve_r=0.4)
    HW, HD, HH, Z0 = 2.8, 2.35, 2.6, HEAD_Z0 + 0.1
    with f.at((0, 0, RAISE)):
        head_box(f, steel, r=0.5, w=HW, d=HD, h=HH, z0=Z0, segs=2)
        zc = Z0 + HH / 2
        top = Z0 + HH
        with f.piece("Head"):
            f.rbox((0, -HD / 2 - 0.02, zc + 0.2), (1.9, 0.14, 0.95), dark, bevel=0.14, segs=1)  # eye slit plate
            f.rbox((0, -HD / 2 - 0.1, zc - 0.25), (0.3, 0.16, 1.6), steel2, bevel=0.05, segs=1)  # nasal bar
            for s_ in (-1, 1):  # frowning brow ridge
                f.rbox((s_ * 0.6, -HD / 2 - 0.08, zc + 0.78), (0.95, 0.2, 0.2), steel2, rot=(0, s_ * 12, 0), bevel=0.04)
            for s_ in (-1, 1):  # breathing holes
                for i in range(3):
                    for j in range(2):
                        f.rbox((s_ * (0.45 + i * 0.28), -HD / 2 - 0.02, zc - 0.5 - j * 0.34), (0.16, 0.1, 0.16), dark, bevel=0.0)
            f.rbox((0, 0.0, top + 0.04), (0.36, 2.2, 0.3), steel2, bevel=0.1, segs=1)  # crest
            f.rcyl((0, 0.55, top + 0.15), 0.46, 0.5, 0.35, gold, seg=6, bevel=0.0)  # plume holder
            for s_ in (-1, 1):  # side rivets
                f.rcyl((s_ * (HW / 2 + 0.02), 0.0, zc), 0.2, 0.2, 0.1, gold, rot=(0, 90, 0), seg=5, bevel=0.0)
            # the red plume: a fan of feathers, up and back
            for i, (rx, ry, ln, c) in enumerate(((-6, -42, 1.4, red), (-12, 0, 1.7, red), (-6, 42, 1.4, red), (-34, -20, 1.5, shade(red, 0.75)), (-30, 20, 1.5, shade(red, 0.75)))):
                f.leaf((0, 0.55, top + 0.35), (rx, ry, 0), ln, 0.7, 0.16, c, tip=0.3, widest=0.5)
        K.HEAD.update(z0=Z0, h=HH, w=HW, d=HD, r=0.5)
        for s_ in (-1, 1):  # tired side-eyes in the slit
            with f.piece("Head"), head_at(f, s_ * 0.5, zc + 0.2, 0.1), f.at((0, 0, 0), (90, 0, 0)):
                f.disc((0, 0, 0.0), 0.62, 0.72, 0.06, WHITE, seg=10)
                f.disc((-0.12, -0.05, 0.05), 0.34, 0.42, 0.05, EYE_DARK, seg=8)
                f.disc((-0.2, 0.06, 0.09), 0.1, 0.12, 0.04, WHITE, seg=4)


# --- 4. Alien Captain (Star, Sci-Fi) ----------------------------------------------------------


def alien_captain(f):
    """Star (Sci-Fi). An alien captain: a tall egg-shaped lime-green head with THREE eyes, two antennae with
    glowing pink bulbs, a tiny knowing smile, purple uniform with huge gold shoulder pads, a cyan chest
    gem, a royal-blue cape, white boots and a red ray gun raised on the right."""
    skin, suit, blue, gold, white = "#7BE07B", "#3B2470", "#2E86DE", "#F5B82E", "#FAF6EC"
    cyan, pink = "#5CF2FF", "#FF6FD8"
    RAISE = 0.1
    with f.piece("Body"):  # cape
        f.rbox((0, 1.0, 2.15), (3.0, 0.2, 2.8), blue, bevel=0.0, taper=0.6, rot=(8, 0, 0))
        f.rbox((0, 1.16, 0.95), (2.6, 0.24, 0.16), gold, bevel=0.0, taper=1.0, rot=(8, 0, 0))
    legs_kid(f, "#2A1856", white, "#C9A24A", r=0.36)
    torso(f, suit, h=1.7, z=2.0, w=1.9)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.95, 1.42, 0.4), "#2A1856", bevel=0.1)
        f.rbox((0, 0, 1.62), (1.98, 1.46, 0.14), gold, bevel=0.0)
        f.rbox((0, -0.72, 1.62), (0.4, 0.08, 0.24), cyan, bevel=0.0)
        f.rbox((0, -0.69, 2.2), (0.22, 0.07, 1.2), gold, bevel=0.0)  # gold zip-trim
        with f.at((0.0, -0.78, 2.3), (90, 0, 0)):
            f.disc((0, 0, 0), 0.7, 0.7, 0.08, gold, seg=6)
            f.disc((0, 0, 0.06), 0.46, 0.46, 0.08, cyan, seg=6)
        for s_ in (-1, 1):  # huge gold shoulder pads
            f.rbox((s_ * 1.25, 0.0, 2.9), (1.05, 1.15, 0.4), gold, rot=(0, s_ * -12, 0), bevel=0.14, segs=1)
            f.rbox((s_ * 1.25, 0.0, 3.14), (0.5, 0.6, 0.2), shade(gold, 1.12), rot=(0, s_ * -12, 0), bevel=0.06)

    def ray_gun(f):  # held up and outward, world upright, tip tilted out a little
        with f.at((0.1, -0.1, 0.4), (0, 32, 0)):
            f.rbox((0, 0, 0.0), (0.4, 0.5, 0.8), "#E8333A", bevel=0.1, segs=1)  # handle + body
            f.rbox((0, 0, 0.6), (0.34, 0.4, 0.5), "#B8222B", bevel=0.06)
            for z in (0.8, 1.1):  # coil fins
                f.rcyl((0, 0, z), 0.34, 0.34, 0.14, "#8A8F9C", seg=6, bevel=0.0)
            f.rcyl((0, 0, 1.3), 0.26, 0.16, 0.5, "#E8333A", seg=6, bevel=0.0)
            f.ball((0, 0, 1.65), (0.3, 0.3, 0.3), cyan, seg=6, rings=4)
            f.rbox((0, -0.3, 0.1), (0.14, 0.3, 0.36), "#7A1019", bevel=0.0)  # trigger guard

    arm(f, 1, suit, skin, rot=(-30, 62, 0), held=ray_gun, upright=True, shoulder_z=2.65, x=1.2, sleeve_r=0.35)
    arm(f, -1, suit, skin, rot=(-8, 24, 0), shoulder_z=2.65, x=1.2, sleeve_r=0.35)
    HW, HD, HH, Z0 = 2.7, 2.35, 3.0, HEAD_Z0
    with f.at((0, 0, RAISE)):
        head_box(f, skin, r=0.95, w=HW, d=HD, h=HH, z0=Z0, segs=2)
        top = Z0 + HH
        ez = Z0 + 0.4 * HH
        K.face_eyes(f, shade(skin, 1.0), spread=0.62, k=1.12, z=ez, color="#2A1450")
        eye1(f, skin, 0.0, ez + 1.05, k=0.8, socket=True, color="#2A1450")  # the third eye
        K.face_blush(f, x=0.98, z=ez - 0.35, w=0.34, h=0.22, color="#4FC86A")
        with f.piece("Head"):  # tiny knowing smile + two dimples
            with head_at(f, 0.05, ez - 0.74, 0.05):  # a wide, closed, upturned smile
                for x, z, a in ((-0.42, 0.1, 34), (-0.22, -0.02, 14), (0.0, -0.06, 0), (0.22, -0.02, -14), (0.42, 0.1, -34)):
                    f.rbox((x, 0, z), (0.26, 0.07, 0.12), "#1F5A2E", rot=(0, a, 0), bevel=0.0)
            for s_ in (-1, 1):  # antennae: stalks with glowing pink bulbs
                f.rcyl((s_ * 0.55, 0.1, top + 0.4), 0.08, 0.1, 1.0, shade(skin, 0.85), rot=(0, s_ * 22, 0), seg=5, bevel=0.0)
                f.ball((s_ * 0.55 + s_ * 0.4, 0.1, top + 1.0), (0.38, 0.38, 0.38), pink, seg=7, rings=4)
            f.rbox((0, 0.0, top - 0.5), (0.5, 0.6, 0.3), shade(skin, 0.92), bevel=0.1)  # gentle brain ridge


# --- 5. Box Office King (Superstar, Action) ---------------------------------------------------


def box_office_king(f):
    """Superstar (Action). Gold is the reward colour: gold suit (deeper gold toward the hem), red cape with an
    ermine collar, a tall gold crown with gems, black wraparound shades, a big open laugh, and a fat stack of cash
    held up high."""
    skin, gold, gold_dk, red, white = "#C68A5A", "#F5B82E", "#D08A18", "#C8202F", "#FAF6EC"
    hair = "#161220"
    RAISE = 0.3
    with f.piece("Body"):  # cape
        f.rbox((0, 1.05, 2.2), (4.5, 0.22, 3.5), red, bevel=0.0, taper=0.6, rot=(8, 0, 0))
        f.rbox((0, 0.95, 0.62), (4.4, 0.24, 0.3), white, bevel=0.0, rot=(8, 0, 0))  # ermine hem
        for x in (-1.7, -0.6, 0.6, 1.7):
            f.ball((x, 0.92, 0.66), (0.22, 0.14, 0.12), "#161220", seg=4, rings=3)
    legs_kid(f, "#2E2C34", gold, "#8A5A10", spread=0.55, r=0.4)
    torso(f, lambda fc: mix(gold_dk, "#FFD04A", min(1.0, max(0.0, fc.calc_center_median().z / 1.7 + 0.5))), h=1.7, z=2.0, w=2.3, d=1.55)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.3, 1.62, 0.4), "#2E2C34", bevel=0.1)
        f.rbox((0, 0, 1.64), (2.34, 1.66, 0.16), "#7A1F2B", bevel=0.0)  # belt
        f.rbox((0, -0.84, 1.64), (0.62, 0.1, 0.34), "#FFE58A", bevel=0.04)  # buckle
        f.rbox((0, -0.78, 2.3), (0.34, 0.07, 0.9), "#FFF1B0", bevel=0.0, taper=2.0)  # shirt flash
        for i in range(11):  # fur collar, a plump ring of white ermine round the shoulders
            a = math.radians(-165 + i * 33)
            f.ball((math.sin(a) * 1.55, math.cos(a) * 0.95 + 0.05, 2.78), (0.5, 0.46, 0.4), white, seg=6, rings=3)
        for i in (1, 3, 5, 7, 9):
            a = math.radians(-165 + i * 33)
            f.ball((math.sin(a) * 1.55, math.cos(a) * 0.95 - 0.1, 3.02), (0.12, 0.1, 0.1), "#161220", seg=4, rings=3)

    def money(f):
        with f.at((0.0, -0.05, 0.62), (0, 0, 16)):
            for i in range(5):
                f.rbox((0, 0, i * 0.19), (1.15, 0.66, 0.18), "#5BBF5A" if i % 2 else "#78D668", rot=(0, 0, i * 4), bevel=0.0)
            f.rbox((0, 0, 0.45), (0.34, 0.7, 1.0), gold, bevel=0.0)  # band
            with f.at((0, -0.37, 0.45), (90, 0, 0)):
                f.disc((0, 0, 0), 0.2, 0.26, 0.05, "#7A5A10", seg=4)

    arm(f, 1, gold, skin, rot=(-62, 24, 0), held=money, upright=True, shoulder_z=2.6, x=1.4, sleeve_r=0.38)
    arm(f, -1, gold, skin, rot=(-8, 34, 0), shoulder_z=2.6, x=1.4, sleeve_r=0.38)
    for sd in (-1, 1):  # chunky red cuffs
        with f.piece("ArmL" if sd > 0 else "ArmR"), f.at((sd * 1.4, 0, 2.6), ((-62, 0, 0) if sd > 0 else (-8, 0, 0))):
            pass
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        # wraparound sunglasses: two dark lenses on the surface, a bridge, glints
        with f.piece("Head"):
            for s_ in (-1, 1):
                head_patch(f, s_ * 0.62, ez, 0.56, 0.4, 0.1, "#161220", seg=10, rings=1)
                K.head_ring(f, s_ * 0.62, ez, 0.58, 0.42, 0.075, 0.1, gold, major=12, minor=4)  # gold rims
                with head_at(f, s_ * 0.62 - 0.16, ez + 0.08, 0.16), f.at((0, 0, 0), (90, 0, 0)):
                    f.rbox((0, 0, 0), (0.12, 0.24, 0.36), "#8A90B0", rot=(0, 0, 28), bevel=0.0)
            with head_at(f, 0, ez + 0.05, 0.12):
                f.rbox((0, 0, 0), (0.34, 0.1, 0.12), gold, bevel=0.0)
        with f.piece("Head"):  # a huge open laugh: dark mouth, top teeth, tongue
            head_patch(f, 0, ez - 0.8, 0.72, 0.34, 0.05, MOUTH, seg=10, rings=1)
            head_patch(f, 0, ez - 0.62, 0.64, 0.12, 0.075, WHITE, seg=8, rings=1)
            head_patch(f, 0, ez - 0.98, 0.34, 0.12, 0.075, "#E86A7A", seg=6, rings=1)
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), hair, seg=8, rings=5)  # slicked hair
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            # the crown: a band + five tall points with gems, one red gem on the front point
            f.rcyl((0, 0.0, top + 0.12), 1.12, 1.18, 0.42, gold, seg=10, bevel=0.06)
            f.rcyl((0, 0.0, top + 0.12), 1.2, 1.2, 0.1, "#FFE58A", seg=10, bevel=0.0)
            for i in range(5):
                a = math.radians(-90 + (i - 2) * 56)
                x, y = 1.0 * math.cos(a), 1.0 * math.sin(a) * 0.95
                tall = 1.05 if i == 2 else 0.85
                f.spike((x, y, top + 0.3), 0.34, tall, gold, seg=4, squash=1.0)
                f.ball((x, y, top + 0.3 + tall + 0.08), (0.17, 0.17, 0.17), red if i == 2 else "#5CF2FF", seg=5, rings=3)
            for s_ in (-1, 1):  # gem studs on the band
                with f.at((s_ * 0.5, -1.1, top + 0.14)):
                    f.ball((0, 0, 0), (0.16, 0.1, 0.16), red, seg=5, rings=3)


# --- 6. Scream Queen (Superstar, Horror) ------------------------------------------------------


def scream_queen(f):
    """Superstar (Horror). The queen of horror films, mid-scream: huge round eyes with tiny pupils, high arched
    brows, a big O mouth, a red-orange ponytail streaming up and out, one hand up by her cheek, a flashlight
    with a starburst in the other, red jacket with a gold star, white shirt, black pants, white sneakers."""
    skin, hair, hair_lt = "#F2C9A8", "#D2501E", "#EE7432"
    red, white, gold = "#C8202F", "#FAF6EC", "#F5B82E"
    RAISE = 0.3
    legs_kid(f, "#2E2C34", white, "#B8B2A4")
    torso(f, red, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), "#2E2C34", bevel=0.1)
        f.rbox((0, 0, 1.62), (1.94, 1.46, 0.14), shade(red, 0.7), bevel=0.0)
        f.rbox((0, -0.69, 2.1), (0.62, 0.08, 1.3), white, bevel=0.0, taper=1.3)  # open front: white shirt
        for s_ in (-1, 1):
            f.rbox((s_ * 0.5, -0.7, 2.4), (0.34, 0.08, 1.0), shade(red, 0.82), rot=(0, s_ * 14, 0), bevel=0.0)
        with f.at((0.62, -0.74, 2.45), (90, 0, 0)):  # gold star patch
            f.disc((0, 0, 0), 0.46, 0.46, 0.07, gold, seg=5, rot=(0, 0, 0))
            f.disc((0, 0, 0), 0.46, 0.46, 0.08, gold, seg=5, rot=(0, 0, 36))

    def flashlight(f):  # held in the fist, pointing out along the arm; a bright lens + starburst
        f.rcyl((0, 0, -0.35), 0.22, 0.22, 0.9, "#2E2C34", seg=6, bevel=0.0)
        f.rcyl((0, 0, -1.05), 0.46, 0.32, 0.55, "#8A8F9C", seg=6, bevel=0.0)
        f.rcyl((0, 0, -1.36), 0.4, 0.4, 0.1, "#FFF6C0", seg=6, bevel=0.0)
        for ang in (0, 72, 144, 216, 288):
            with f.at((0, 0, -1.38), (0, 0, ang)):
                f.spike((0.4, 0, 0), 0.11, 0.7, "#FFE86A", rot=(0, 70, 0), seg=3)

    arm(f, 1, red, skin, rot=(-12, 78, 0), held=flashlight, shoulder_z=2.55, sleeve_r=0.34)
    arm(f, -1, red, skin, rot=(-150, 42, 0), shoulder_z=2.55, sleeve_r=0.34)  # hand up by the cheek
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.2
        ears(f, skin, ez - 0.1, x=1.22)
        for s_ in (-1, 1):  # huge round scared eyes: white ring, tiny pupil, specular
            with f.piece("Head"), head_at(f, s_ * 0.6, ez, 0.0), f.at((0, 0, 0), (90, 0, 0)):
                f.disc((0, 0, 0.0), 0.98, 1.1, 0.06, shade(skin, 0.86), seg=10)
                f.disc((0, 0, 0.035), 0.82, 0.94, 0.06, WHITE, seg=10)
                f.disc((s_ * -0.02, 0.03, 0.07), 0.46, 0.56, 0.05, "#3A2418", seg=8)
                f.disc((s_ * -0.02, 0.03, 0.1), 0.3, 0.38, 0.05, EYE_DARK, seg=8)
                f.disc((-0.1, 0.16, 0.13), 0.14, 0.15, 0.04, WHITE, seg=5)
        K.face_brows(f, "#7A2A12", length=1.1, thick=0.24, angle=14, x=0.64, z=ez + 0.8, worried=True, lift=(0.14, 0.14))
        mouth_o(f, ez - 0.74, 0.46, 0.48, dark="#4A1020", tongue="#E86A7A")  # screaming O mouth
        K.face_blush(f, x=1.0, z=ez - 0.5, w=0.36, h=0.22)
        with f.piece("Head"):
            # tight side-parted cap + back mass; clear forehead
            f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.3, 0.95, 1.25), hair, seg=8, rings=5)
            f.ball((-0.5, -0.5, top - 0.2), (0.7, 0.5, 0.3), hair_lt, rot=(-10, 0, 20), seg=6, rings=3)  # side-swept lock
            f.ball((0.06, 0.3, top + 0.14), (0.5, 0.4, 0.28), hair_lt, seg=6, rings=3)
            # the ponytail: a yellow scrunchie high at the back, a streaming tail up and out to the actor's left
            f.rcyl((0.7, 0.62, top + 0.08), 0.34, 0.34, 0.28, "#FFD21A", rot=(0, 30, 0), seg=6, bevel=0.0)
            f.leaf((0.9, 0.62, top + 0.15), (0, 38, 0), 2.7, 1.1, 0.75, hair, tip=0.25, widest=0.35)
            f.leaf((0.95, 0.4, top + 0.2), (0, 62, 0), 2.5, 0.8, 0.5, hair_lt, tip=0.25, widest=0.4)
            f.leaf((0.9, 0.7, top + 0.1), (4, 19, 0), 2.1, 0.7, 0.5, hair, tip=0.25, widest=0.4)


# --- 7. Cupid (Superstar, Romance) ------------------------------------------------------------


def cupid(f):
    """Superstar (Romance). A cherub actor: soft golden curls with a halo, big sparkly eyes and a cat smile,
    a rosy blush, little white wings fanned behind, pink tunic with a gold sash, white shorts, golden sandals,
    a golden bow in one hand, and a heart held out in the other with more hearts floating by."""
    skin, gold, pink, pink_lt, white = "#F7D2B5", "#F5B82E", "#FF9AC4", "#FFC4DE", "#FFFFFF"
    hair, hair_lt = "#F5C94A", "#FFDE7A"
    RAISE = 0.3
    with f.piece("Body"):  # wings: two fans of feathers, white with pink tips
        for side, jx in ((1, 0.8), (-1, 0.8)):
            for i, (a, ln, wd) in enumerate(((8, 2.4, 0.8), (28, 2.3, 0.8), (50, 2.0, 0.76), (72, 1.5, 0.7))):
                f.leaf((side * jx, 1.0 + 0.03 * i, 2.75), (0, side * a, 0), ln, wd, 0.14, "#FFFFFF", tip_color="#FFD0E4", tip_from=0.6, tip=0.5, widest=0.5)
    legs_kid(f, white, gold, "#B8801C", r=0.38)
    torso(f, pink, h=1.7, z=2.0, w=1.9)
    with f.piece("Body"):
        f.rbox((0, 0, 1.42), (2.0, 1.48, 0.4), white, bevel=0.1)  # fluffy shorts
        f.rbox((0, 0, 1.64), (2.0, 1.5, 0.2), gold, bevel=0.0)  # gold sash
        f.rbox((0, -0.78, 1.64), (0.4, 0.1, 0.3), "#FFE58A", bevel=0.04)
        f.rbox((0, -0.64, 2.3), (1.0, 0.08, 0.3), pink_lt, bevel=0.0, rot=(0, 0, 0))  # tunic neckline
        for s_ in (-1, 1):
            f.rbox((s_ * 0.5, -0.64, 2.0), (0.4, 0.07, 0.07), "#FFFFFF", rot=(0, s_ * 20, 0), bevel=0.0)
        heart(f, (0, -0.82, 2.2), 0.7, color="#FFFFFF")  # a heart on the tunic

    def bow(f):  # a golden bow, upright, curving out; string on the inner side
        pts = []
        for i in range(7):
            t = -1.0 + i / 3.0
            pts.append((0.0 + 0.6 * (1 - t * t) * 1.0, 0, 0.3 + 1.15 * t))
        for a, b in zip(pts, pts[1:]):
            tube(f, a, b, 0.12, 0.12, gold, seg=5)
        tube(f, pts[0], pts[-1], 0.025, 0.025, "#FFFFFF", seg=3)
        f.rcyl((0.6, 0, 0.3), 0.14, 0.14, 0.4, "#B8801C", seg=5, bevel=0.0)  # grip wrap
        with f.at((pts[-1][0], 0, pts[-1][2] + 0.0)):
            f.ball((0, 0, 0), (0.14, 0.14, 0.14), "#FFE58A", seg=5, rings=3)

    def heart_in_hand(f):
        heart(f, (0.0, -0.05, 0.7), 1.0)

    arm(f, 1, skin, skin, rot=(-30, 36, 0), held=bow, upright=True, shoulder_z=2.55, sleeve_r=0.3)
    arm(f, -1, skin, skin, rot=(-40, 78, 0), held=heart_in_hand, upright=True, shoulder_z=2.55, sleeve_r=0.3)
    for sd, rot in ((1, (-30, 0, 0)), (-1, (-40, 0, 0))):
        with f.piece("ArmL" if sd > 0 else "ArmR"), f.at((sd * 1.1, 0, 2.55), (rot[0], -sd * (36 if sd > 0 else 78), 0)):
            f.rcyl((0, 0, -0.62), 0.38, 0.34, 0.18, gold, seg=7, bevel=0.0)  # gold arm band
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, skin, spread=0.6, k=1.12, z=ez)
        for s_ in (-1, 1):  # extra sparkle + three lashes at the outer corners
            with f.piece("Head"), head_at(f, s_ * 0.6, ez, 0.0), f.at((0, 0, 0), (90, 0, 0)):
                f.disc((0.12 * s_, -0.12, 0.09), 0.1, 0.1, 0.04, WHITE, seg=4)
            with f.piece("Head"), head_at(f, s_ * 0.98, ez + 0.3, 0.02):
                for ang, dz in ((-50, 0.0), (-20, 0.16)):
                    f.rbox((0, 0.02, dz), (0.34, 0.07, 0.09), "#7A4A22", rot=(0, s_ * ang, 0), bevel=0.0)
        K.face_brows(f, "#C88A3A", length=0.85, thick=0.17, angle=8, x=0.62, z=ez + 0.8, worried=False, lift=(0.1, 0.1))
        K.face_blush(f, x=0.95, z=ez - 0.32, w=0.52, h=0.34, color="#FF8AA0")
        with f.piece("Head"):  # a small open happy mouth
            head_patch(f, 0, ez - 0.72, 0.3, 0.2, 0.05, MOUTH, seg=8, rings=1)
            head_patch(f, 0, ez - 0.82, 0.18, 0.09, 0.075, "#E86A7A", seg=6, rings=1)
        with f.piece("Head"):  # golden curls: tight cap + a ring of curls
            f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.3, 0.95, 1.25), hair, seg=8, rings=5)
            for i, (x, y, z, r) in enumerate(((0.0, -0.1, top + 0.15, 0.55), (-0.85, 0.0, top + 0.0, 0.5), (0.85, 0.0, top + 0.0, 0.5), (-1.35, 0.25, top - 0.7, 0.48), (1.35, 0.25, top - 0.7, 0.48), (-1.4, 0.35, top - 1.5, 0.42), (1.4, 0.35, top - 1.5, 0.42))):
                f.ball((x, y, z), (r, r * 0.9, r), hair if i % 2 == 0 else hair_lt, seg=6, rings=3)
            # halo held up on a little stem
            f.rbox((0, 0.55, top + 0.4), (0.12, 0.12, 0.8), gold, bevel=0.0)
            with f.at((0, 0.0, top + 0.85), (90, 0, 0)):
                f.torus((0, 0, 0), 0.8, 0.16, "#FFE070", rot=(0, 0, 0), major=10, minor=4, sx=1.0, sz=0.85)
    with f.piece("Body"):
        heart(f, (-2.3, -0.2, 5.2), 0.75, color="#FF9AC4")
        heart(f, (2.4, 0.0, 4.6), 0.6)


# Names are the in-game actor ids (src/shared/Actors.luau), so the FBX pieces drop straight into LotMeshes.
BUILDS = {
    "villain": ("NightShiftVillain", "Pro", night_villain),
    "heart": ("TeenHeartthrob", "Star", heartthrob),
    "knight": ("MethodActor", "Star", method_knight),
    "alien": ("SpaceCaptain", "Star", alien_captain),
    "king": ("BoxOfficeKing", "Superstar", box_office_king),
    "scream": ("ScreamQueen", "Superstar", scream_queen),
    "cupid": ("RomComSweetheart", "Superstar", cupid),
}
K.ACTORS.update(BUILDS)
B2_KEYS = tuple(BUILDS)
OLD_FN = {  # the in-game versions (art/blender/actors.py)
    "villain": "night_villain",
    "heart": "heartthrob",
    "knight": "method_knight",
    "alien": "alien_captain",
    "king": "box_office_king",
    "scream": "scream_queen",
    "cupid": "cupid",
}
APPROVED = ("intern", "pup", "squawk")
LINEUP = ("intern", "pup", "squawk", "villain", "heart", "knight", "alien", "king", "scream", "cupid")
OUT = K.OUT_DIR


def build_all(keys=None):
    keys = list(keys or (list(APPROVED) + list(B2_KEYS)))
    return K.main(tuple(keys))


def objs_of(built, key):
    return list(built[key][1].values())


def render_one(sc, built, key, res=720):
    """Sheet + views + FBX for one actor (files actors_v2_b2_<key>_*)."""
    ol = objs_of(built, key)
    K.floor_for(sc, x=0)
    paths = K.render_set(sc, key, ol, f"b2_{key}", res=res)
    old = {o: o.location.copy() for o in ol}
    for o in ol:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    K.export_fbx(ol, os.path.join(OUT, f"actors_v2_b2_{key}.fbx"))
    for o, l in old.items():
        o.location = l
    bpy.context.view_layer.update()
    return paths


def compare_one(sc, built, key, res=900, gap=7.0):
    """The in-game version (left) next to the new one (right), front and 3/4, same light and camera."""
    import importlib

    old = importlib.import_module("actors")
    new_objs = objs_of(built, key)
    x0 = new_objs[0].location.x / K.STUD
    a = old.make(BUILDS[key][0], BUILDS[key][1], getattr(old, OLD_FN[key]))
    a.name = f"OLD_{key}"
    oo = a.objects((x0 - gap, 0, -0.23))
    both = list(oo.values()) + new_objs
    tiles = []
    for name, az, el in (("front", 0, 18), ("34", 32, 20)):
        p = K.shoot(sc, both, f"/tmp/b2_cmp_{key}_{name}.png", az=az, el=el, res=res, hide_others=False, margin=1.25, lens=120, samples=40)
        tiles.append(K.load_img(p))
    for o in oo.values():
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    out = os.path.join(OUT, f"actors_v2_b2_{key}_compare.png")
    K.save_img(K.hstack(tiles, pad=8), out)
    return out


def lineup(sc, built, path=None, res=360):
    """All ten side by side (two rows of five, same camera scale). The three approved actors get a green bar."""
    path = path or os.path.join(OUT, "actors_v2_b2_lineup.png")
    tiles = []
    for key in LINEUP:
        ol = objs_of(built, key)
        x = ol[0].location.x
        ctr = Vector((x, 0, 3.2 * K.STUD))
        t = K.load_img(K.shoot(sc, ol, f"/tmp/b2_lu_{key}.png", az=22, el=12, res=res, center=ctr, radius=5.4 * K.STUD, margin=1.0, samples=32, lens=70))
        t[:10, :, :3] = np.array(K.lin("#4CC764")[:3] if key in APPROVED else K.lin("#E9E4D8")[:3])
        tiles.append(t)
    K.save_img(K.vstack([K.hstack(tiles[:5], pad=4), K.hstack(tiles[5:], pad=4)], pad=4), path)
    return path


def silhouettes(sc, built, path=None):
    path = path or os.path.join(OUT, "actors_v2_b2_silhouettes_64.png")
    K.silhouette_strip(sc, [objs_of(built, k) for k in LINEUP], path)
    return path


def run_qa_gate(built, key):
    """blender-asset-qa script (game profile) on one actor's objects; returns (pass, errors, warnings)."""
    qd = os.path.expanduser("~/.claude/skills/blender-asset-qa/scripts")
    if qd not in sys.path:
        sys.path.insert(0, qd)
    import importlib

    import qa_check

    importlib.reload(qa_check)
    r = qa_check.run(objects=[o.name for o in objs_of(built, key)], profile="game")
    return r["pass"], r["errors"], r["warnings"]


def finalize_b2(render=True, keys=None):
    """Build the 7 + the 3 approved, QA, render every sheet as actors_v2_b2_*, compares, lineup, silhouettes, FBX."""
    sc, built, report = build_all()
    out = {"qa": {k: report[k] for k in B2_KEYS}}
    if not render:
        return sc, built, out
    for key in keys or B2_KEYS:
        out[key] = render_one(sc, built, key)
    for key in keys or B2_KEYS:
        compare_one(sc, built, key)
    lineup(sc, built)
    silhouettes(sc, built)
    return sc, built, out
