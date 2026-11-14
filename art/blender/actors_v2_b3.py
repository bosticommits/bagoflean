"""Actors v2, batch 3 = the LAST six of the old 21, the top tiers, built to the approved style bible
(Nervous Intern A, Werewolf Pup, Captain Squawk + batches 1 and 2). Same characters, costumes, colours
and props as the in-game versions in actors.py; rebuilt with the v2 kit (actors_v2.py): pill head with face
parts on its surface (costume actors: box head + face plate), two-segment bevels, vertex-colour AO, tier plinth.

  Showgirl Diva, Silent Film Clown, Brain in a Jar (Legend) - Golden Muse, Mech Hero, Phantom Auteur (Icon)

Also re-renders the batch-2 Teen Heartthrob with its fixed pompadour (actors_v2_b2.heartthrob).
Run live (MCP for Blender): finalize_b3() builds, QAs, renders everything and exports the draft FBX files (1/28).
Taste rules: vault `Movie Mogul/Actor References.md`. Legend/Icon cap: the note gives none, so 2,500 tris is used.
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
import actors_v2_b2 as B2  # noqa: E402
from actors_v2_b2 import heart, sparkle  # noqa: E402

GOLD = "#F5B82E"


# --- shared helpers ---------------------------------------------------------------------------


def hoop(f, ctr, rx, ry, rz, phi, n, r, color, t0=0, t1=180, seg=4):
    """A thin arch (dome frame): points on an ellipse arc, from +side over the top to -side, in a plane turned
    `phi` degrees about Z. Built from tube() pieces."""
    p = math.radians(phi)
    pts = []
    for i in range(n + 1):
        t = math.radians(t0 + (t1 - t0) * i / n)
        pts.append((ctr[0] + rx * math.cos(t) * math.cos(p), ctr[1] - ry * math.cos(t) * math.sin(p), ctr[2] + rz * math.sin(t)))
    for a, b in zip(pts, pts[1:]):
        tube(f, a, b, r, r, color, seg=seg)


def icon_base(f, crystal="#FF5FD2", lite="#FFC4EE"):
    """Icon plinth extra: six tall tier-colour crystals leaning out of the hex corners (the Icon base shape)."""
    with f.piece("Base"):
        for i in range(6):
            a = math.radians(60 * i)  # hex corners (flat side faces the front); kept inside the 3.6 depth cap
            R = 2.0 if i in (0, 3) else 1.74
            x, y = R * math.cos(a), R * math.sin(a)
            tall = 1.25 if i in (0, 3) else 0.9
            f.spike((x, y, -0.28), 0.24, tall, crystal if i % 2 else lite, rot=(0, (math.degrees(math.cos(a)) * 0.18), 0), seg=4)


def stars(f, pts, color="#FFFFFF", s=0.8):
    with f.piece("Body"):
        for p in pts:
            sparkle(f, p, s, color)


# --- 1. Showgirl Diva (Legend, Romance) -------------------------------------------------------


def showgirl(f):
    """Legend (Romance). A golden-age diva in full showgirl glory: a huge fan of orange/gold/pink feathers over a
    gold band, a sweeping side curl, winged-liner eyes, ruby lips mid-song, long white opera gloves, a pink feather
    boa, a lilac sequin mermaid gown flaring wide to the floor and a vintage microphone held up, one arm flung high."""
    skin, hair = "#8A5230", "#17101A"
    gown, gown_lt, gown_dk = "#9AA8E8", "#C4CFF8", "#7482C8"
    pink, pink_lt, orange, yel = "#FF7FB6", "#FFB6D6", "#FF5A2E", "#FFC21A"
    glove = "#FAF6EC"
    RAISE = 0.3
    prof = [(2.15, 0.02), (2.2, 0.3), (1.78, 0.78), (1.32, 1.2), (1.05, 1.56)]

    def r_at(z):
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return prof[-1][0]

    def gown_col(face):
        if face.material_index == 0:
            return GOLD
        c = face.calc_center_median()
        k = int((math.atan2(c.y, c.x) + math.pi) / (2 * math.pi) * 10) % 2
        return gown_lt if k else gown

    with f.piece("Body"):
        f.lathe((0, 0, 0), prof, gown_col, seg=10, scale=(1, 0.8, 1))
        for s_ in (-1, 1):  # gold shoe toes peeking out of the hem
            f.rbox((s_ * 0.62, -1.55, 0.28), (0.7, 0.7, 0.4), GOLD, bevel=0.12, segs=1)
        for i, (th, z) in enumerate(((-60, 0.55), (-20, 0.45), (20, 0.5), (60, 0.6), (-40, 1.0), (0, 0.95), (40, 1.0), (-85, 0.95), (85, 0.9))):
            a = math.radians(th - 90)
            rr = r_at(z) * 1.0
            f.ball((rr * math.cos(a), rr * 0.8 * math.sin(a) - 0.02, z), (0.17, 0.12, 0.17), WHITE, seg=4, rings=2)  # sequins
    torso(f, gown, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.45), (1.95, 1.44, 0.34), GOLD, bevel=0.1)  # sash
        f.ball((0.85, -0.7, 1.5), (0.34, 0.2, 0.3), "#FF5A2E", seg=5, rings=3)  # bow knot
        f.rbox((0, -0.69, 2.35), (1.1, 0.07, 0.5), gown_lt, bevel=0.0, taper=1.5)  # sweetheart panel
        for x in (-0.4, 0.0, 0.4):
            f.ball((x, -0.74, 2.0), (0.12, 0.1, 0.12), WHITE, seg=4, rings=2)
        for i in range(7):  # feather boa round the shoulders
            a = math.radians(-135 + i * 45)
            f.ball((math.sin(a) * 1.5, math.cos(a) * 0.9 + 0.05, 2.9), (0.46, 0.42, 0.36), pink if i % 2 else pink_lt, seg=6, rings=3)
        for i in range(2):  # a tail of the boa hanging down in front
            f.ball((1.25 + 0.06 * i, -0.45, 2.3 - 0.45 * i), (0.36, 0.34, 0.34), pink if i % 2 else pink_lt, seg=5, rings=3)

    def mic(f):  # vintage mic, stands up in the hand
        f.rcyl((0, 0, 0.1), 0.07, 0.1, 0.8, "#2E2C34", seg=5, bevel=0.0)
        f.ball((0, 0, 0.72), (0.3, 0.3, 0.34), "#AEB3C2", seg=7, rings=4)
        f.torus((0, -0.0, 0.72), 0.3, 0.05, "#2E2C34", rot=(0, 0, 0), major=8, minor=4)

    ROT_M, ROT_F = (-35, 68, 0), (-10, 138, 0)
    arm(f, -1, glove, glove, rot=ROT_M, held=mic, upright=True, shoulder_z=2.55, sleeve_r=0.34, x=1.2, length=1.15)
    arm(f, 1, glove, glove, rot=ROT_F, shoulder_z=2.55, sleeve_r=0.34, x=1.2, length=1.15)  # flung high
    for sd in (-1, 1):  # gold bracelets
        rot = ROT_M if sd < 0 else ROT_F
        with f.piece("ArmL" if sd > 0 else "ArmR"), f.at((sd * 1.2, 0, 2.55), (rot[0], -sd * rot[1], rot[2])):
            f.rcyl((0, 0, -0.62), 0.4, 0.36, 0.14, GOLD, seg=7, bevel=0.0)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        with f.piece("Head"):
            for s_ in (-1, 1):
                f.ball((s_ * 1.27, 0.05, ez - 0.4), (0.15, 0.15, 0.17), GOLD, seg=5, rings=3)  # ear studs
        K.face_eyes(f, shade(skin, 1.2), spread=0.62, k=1.12, z=ez, color="#241410")
        for s_ in (-1, 1):  # liner flick at the outer corner
            with f.piece("Head"), head_at(f, s_ * 1.02, ez + 0.2, 0.02):
                for ang, dz in ((38, 0.0), (8, 0.15)):
                    f.rbox((0, 0.02, dz), (0.36, 0.07, 0.09), "#1A0F0A", rot=(0, s_ * ang, 0), bevel=0.0)
        K.face_brows(f, "#1A0F0A", length=1.0, thick=0.2, angle=12, x=0.64, z=ez + 0.82, worried=False, lift=(0.06, 0.0))
        K.face_blush(f, color="#E2766A", x=0.96, z=ez - 0.38, w=0.46, h=0.3)
        with f.piece("Head"):  # ruby lips, singing: open with teeth
            head_patch(f, 0, ez - 0.78, 0.76, 0.38, 0.05, "#D81E3C", seg=10, rings=1)
            head_patch(f, 0, ez - 0.8, 0.54, 0.22, 0.075, MOUTH, seg=8, rings=1)
            head_patch(f, 0, ez - 0.66, 0.46, 0.08, 0.1, WHITE, seg=8, rings=1)
            with head_at(f, 0.98, ez - 0.55, 0.03), f.at((0, 0, 0), (90, 0, 0)):
                f.disc((0, 0, 0), 0.14, 0.14, 0.04, "#1A0F0A", seg=5)  # beauty mark
        with f.piece("Head"):  # glossy black hair: tight cap, a side-swept curl (rolled slab + tilted leaf), pin curls
            f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.3, 0.95, 1.25), hair, seg=8, rings=5)
            f.rcyl((-0.35, 0.0, top + 0.12), 0.46, 0.46, 1.2, hair, rot=(0, 90, -22), seg=7, bevel=0.1)  # rolled sweep
            f.leaf((-0.95, -0.15, top + 0.0), (8, -148, 0), 1.9, 0.85, 0.4, "#2A1C30", tip=0.35, widest=0.4)  # curl sweeping down the side
            for s_ in (-1, 1):
                f.rcyl((s_ * 1.32, 0.15, top - 1.55), 0.36, 0.36, 0.5, hair, rot=(90, 0, 0), seg=7, bevel=0.06)  # pin curls
            # headdress: a gold band and a fan of tall feathers
            f.rcyl((0, 0.08, top - 0.66), 1.24, 1.24, 0.3, GOLD, seg=10, squash=0.9, bevel=0.05)
            f.ball((0, -1.0, top - 0.66), (0.2, 0.12, 0.2), orange, seg=5, rings=3)
            for i, (ang, ln) in enumerate(zip((-76, -57, -38, -19, 0, 19, 38, 57, 76), (2.2, 2.6, 3.0, 3.3, 3.6, 3.3, 3.0, 2.6, 2.2))):
                col = (orange, yel, pink)[i % 3]
                f.leaf((0, 0.5, top - 0.45), (-8, ang, 0), ln, 0.85, 0.18, col, tip_color="#FFF1B0", tip_from=0.78, tip=0.45, widest=0.5)
    stars(f, ((-2.4, 0.0, 5.0), (2.4, 0.0, 6.6), (-2.5, 0.5, 1.2)), "#FFC21A", 1.1)


# --- 2. Silent Film Clown (Legend, Comedy) ----------------------------------------------------


def silent_clown(f):
    """Legend (Comedy). Straight out of a silent film, only blacks, whites and greys: a colossal two-layer pleated
    ruffle, round pom-pom buttons, splayed long clown shoes, a crooked little bowler, wild grey side tufts, a painted
    white face with a sad pout, a teardrop and arched brows, a big grey flower in one glove and the other glove waving."""
    W, L, M, D = "#F4F4F4", "#B8B8B8", "#6E6E6E", "#262626"
    RAISE = 0.45
    for s_ in (-1, 1):
        with f.piece("Body"):
            f.rcyl((s_ * 0.55, 0, 0.8), 0.46, 0.52, 1.3, L, seg=8, bevel=0.0)  # baggy trousers
            with f.at((s_ * 0.8, -0.35, 0.28), (0, 0, s_ * 26)):  # long splayed shoes
                f.rbox((0, 0, 0), (1.0, 2.1, 0.56), D, bevel=0.16, segs=1)
                f.rbox((0, 0, -0.26), (1.04, 2.14, 0.1), "#8A8A8A", bevel=0.0)
                f.ball((0, -1.0, 0.1), (0.5, 0.4, 0.3), D, seg=6, rings=3)  # round toe
                f.ball((0, -0.45, 0.4), (0.3, 0.3, 0.24), W, seg=6, rings=3)  # pom on the shoe
    torso(f, W, h=1.75, z=2.0, w=2.1, d=1.55, bevel=0.2)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.0, 1.5, 0.4), L, bevel=0.1)
        for z in (1.65, 2.15):
            f.ball((0, -0.78, z), (0.2, 0.14, 0.2), D, seg=6, rings=3)  # pom-pom buttons
        for i in range(16):  # the big ruffle: two layers of pleats
            a = 2 * math.pi * i / 16
            x, y = math.cos(a), math.sin(a)
            f.spike((x * 1.15, y * 0.9 + 0.05, 2.7), 0.5, 1.15 - 0.45 * max(0.0, -y), L if i % 2 else W, rot=(-y * 76, x * 76, 0), seg=4)
        for i in range(12):
            a = 2 * math.pi * (i + 0.5) / 12
            x, y = math.cos(a), math.sin(a)
            f.spike((x * 0.8, y * 0.62 + 0.05, 2.88), 0.4, 0.8 - 0.4 * max(0.0, -y), M if i % 2 else L, rot=(-y * 56, x * 56, 0), seg=4)

    def flower(f):
        f.rcyl((0, -0.05, 0.4), 0.06, 0.06, 0.9, M, seg=4, bevel=0.0)
        for i in range(5):
            a = 2 * math.pi * i / 5 + 0.3
            f.ball((math.cos(a) * 0.42, -0.12, 1.0 + math.sin(a) * 0.42), (0.3, 0.12, 0.3), L if i % 2 else W, seg=5, rings=3)
        f.ball((0, -0.24, 1.0), (0.24, 0.12, 0.24), D, seg=5, rings=3)

    arm(f, -1, W, W, rot=(-15, 38, 0), held=flower, upright=True, shoulder_z=2.55, sleeve_r=0.36, x=1.2)
    arm(f, 1, W, W, rot=(-5, 140, 0), shoulder_z=2.55, sleeve_r=0.36, x=1.2)  # big wave
    for sd, rot in ((-1, (-15, 38, 0)), (1, (-5, 140, 0))):
        with f.piece("ArmL" if sd > 0 else "ArmR"), f.at((sd * 1.2, 0, 2.55), (rot[0], -sd * rot[1], rot[2])):
            f.rcyl((0, 0, -0.78), 0.42, 0.36, 0.16, D, seg=7, bevel=0.0)  # dark cuff
            f.ball((0, 0, -1.07), (0.52, 0.34, 0.52), W, seg=7, rings=4)  # puffy glove
    with f.at((0, 0, RAISE)):
        head_box(f, W, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        with f.piece("Head"):
            for s_ in (-1, 1):  # wild grey side tufts: three fat locks fanning out
                for j, (ang, h, c) in enumerate(((75, 1.1, L), (102, 1.1, M), (130, 1.0, L))):
                    f.leaf((s_ * 1.2, 0.2, ez + 0.4 - j * 0.34), (0, s_ * ang, 0), h, 0.46, 0.4, c, tip=0.4, widest=0.55)
        K.face_eyes(f, "#D6D6D6", spread=0.6, k=1.0, z=ez, color=D)
        for s_ in (-1, 1):
            with f.piece("Head"), head_at(f, s_ * 0.6, ez - 0.62, 0.05):  # painted lower lash line
                f.rbox((0, 0, 0), (0.5, 0.06, 0.07), D, rot=(0, s_ * 10, 0), bevel=0.0)
        with f.piece("Head"), head_at(f, 0.6, ez - 0.95, 0.06), f.at((0, 0, 0), (90, 0, 0)):  # one painted teardrop
            f.disc((0, 0, 0), 0.2, 0.34, 0.05, D, seg=5)
        K.face_brows(f, D, length=0.95, thick=0.16, angle=26, x=0.6, z=ez + 0.95, worried=True, lift=(0.1, -0.1))  # high, arched, sad
        K.face_blush(f, color="#C8C8C8", x=1.0, z=ez - 0.42, w=0.5, h=0.34)
        with f.piece("Head"):
            head_patch(f, 0, ez - 0.1, 0.17, 0.15, 0.1, M, seg=6, rings=1)  # round nose
            head_patch(f, 0, ez - 0.86, 0.34, 0.17, 0.05, D, seg=8, rings=1)  # small painted pout
            head_patch(f, 0, ez - 0.82, 0.12, 0.06, 0.075, "#8A8A8A", seg=5, rings=1)
        with f.piece("Head"):  # cap of dark hair under a tiny crooked bowler
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), D, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), D, seg=8, rings=5)
            dome(f, (0.25, 0.05, top - 0.2), [(1.0, 0.0), (1.02, 0.14), (0.72, 0.3), (0.7, 0.7), (0.45, 0.98)], ["#1A1A1A", "#1A1A1A", "#3A3A3A", "#1A1A1A"], seg=10, rot=(0, 14, 0))
            f.rcyl((0.25, 0.05, top + 0.18), 0.74, 0.74, 0.14, "#9A9A9A", seg=10, bevel=0.0, rot=(0, 14, 0))  # hat band
    with f.piece("Body"):  # an intertitle card floating by
        f.rbox((-1.95, 0, 5.5), (1.4, 0.12, 0.95), D, rot=(0, -8, 0), bevel=0.0)
        f.rbox((-1.95, -0.08, 5.5), (1.14, 0.1, 0.7), W, rot=(0, -8, 0), bevel=0.0)
        f.rbox((-1.95, -0.14, 5.5), (0.76, 0.08, 0.14), M, rot=(0, -8, 0), bevel=0.0)
    stars(f, ((2.3, 0.0, 6.0), (2.4, 0.5, 1.4)), "#8A8A8A", 1.0)


# --- 3. Brain in a Jar (Legend, Sci-Fi) -------------------------------------------------------


def brain_jar(f):
    """Legend (Sci-Fi). A giant glowing pink brain in a glass dome (cyan frame ribs) walking on stubby robot legs: lumpy
    two-tone lobes round a big smug face, a sprung antenna spark, side electrodes, a steel jar-base body with a
    cyan heartbeat screen, orange boots, one claw holding up a glowing idea bulb, the other waving."""
    metal, dark, orange, cyan = "#AEB3C2", "#6E7078", "#FF5A2E", "#5CF2FF"
    brain, brain_dk, brain_lt = "#FF8FB8", "#E8588A", "#FFB8D2"
    RAISE = 0.25
    legs_kid(f, dark, orange, "#B8431F", spread=0.55, r=0.3, hip=1.35)
    torso(f, metal, w=2.5, d=1.8, h=1.7, z=1.95, taper=0.92, bevel=0.3)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.3, 1.7, 0.36), dark, bevel=0.1)
        f.rbox((0, 0, 2.85), (2.4, 1.7, 0.26), orange, bevel=0.1)  # top tray under the dome
        with f.at((0, -0.92, 2.0), (90, 0, 0)):  # heartbeat screen
            f.rbox((0, 0, 0), (1.7, 1.0, 0.1), "#1B2340", bevel=0.1, segs=1)
            for i, h in enumerate((0.3, 0.55, 0.8, 0.45, 0.62, 0.28)):
                f.rbox((-0.62 + i * 0.25, 0, 0.07), (0.15, h, 0.07), cyan, bevel=0.0)
        for i in range(4):  # rivets
            f.ball((-0.9 + i * 0.6, -0.8, 1.45), (0.1, 0.08, 0.1), cyan, seg=4, rings=2)

    def bulb(f):  # an idea!
        f.rcyl((0, 0, 0.0), 0.16, 0.2, 0.28, "#6E7078", seg=6, bevel=0.0)
        f.ball((0, 0, 0.42), (0.38, 0.38, 0.42), "#FFF08A", seg=7, rings=4)
        for a in (-50, 0, 50):
            f.spike((math.sin(math.radians(a)) * 0.4, 0, 0.42 + math.cos(math.radians(a)) * 0.4), 0.07, 0.4, "#FFE27A", rot=(0, a, 0), seg=3)

    def claw(f):
        for s_ in (-1, 1):
            f.rbox((s_ * 0.17, -0.05, -0.28), (0.14, 0.22, 0.46), dark, rot=(0, s_ * -14, 0), bevel=0.03)

    arm(f, -1, metal, dark, rot=(-20, 64, 0), held=bulb, upright=True, shoulder_z=2.5, x=1.4, sleeve_r=0.36)
    arm(f, 1, metal, dark, rot=(0, 92, 0), held=claw, shoulder_z=2.5, x=1.4, sleeve_r=0.36)
    HW, HD, HH, Z0 = 3.3, 2.6, 2.4, HEAD_Z0 + 0.4
    with f.at((0, 0, RAISE)):
        head_box(f, brain, r=1.1, w=HW, d=HD, h=HH, z0=Z0, segs=2)
        top = Z0 + HH
        zc = Z0 + HH / 2
        ez = Z0 + 0.45 * HH
        with f.piece("Head"):  # lumpy lobes
            for i, (x, y, z, r, c) in enumerate(((-0.85, 0.0, top - 0.05, 0.95, brain_lt), (0.85, 0.0, top - 0.05, 0.95, brain_dk), (0.0, 0.7, top - 0.2, 0.85, brain),
                                                  (-1.7, 0.1, top - 0.65, 0.8, brain_dk), (1.7, 0.1, top - 0.65, 0.8, brain_lt),
                                                  (-1.85, 0.3, zc - 0.25, 0.62, brain), (1.85, 0.3, zc - 0.25, 0.62, brain_dk),
                                                  (0.0, 1.1, zc + 0.3, 0.8, brain_dk), (-0.8, 0.9, zc + 0.9, 0.55, brain_lt), (0.8, 0.9, zc + 0.9, 0.55, brain_lt))):
                f.ball((x, y, z), (r, r, r * 0.9), c, seg=7, rings=4)
        K.face_eyes(f, shade(brain, 0.9), spread=0.72, k=1.2, z=ez, color="#241410")
        K.face_brows(f, "#7A1F44", length=1.1, thick=0.24, angle=14, x=0.74, z=ez + 0.8, worried=False, lift=(0.0, 0.18))  # one raised: smug
        K.face_blush(f, color="#FF5A78", x=1.18, z=ez - 0.3, w=0.4, h=0.26)
        with f.piece("Head"):  # a lopsided know-it-all smirk
            with head_at(f, 0.15, ez - 0.72, 0.05):
                f.rbox((0, 0, 0), (0.9, 0.08, 0.17), "#7A1F44", rot=(0, -9, 0), bevel=0.0)
                f.rbox((0.5, 0, 0.12), (0.2, 0.08, 0.2), "#7A1F44", rot=(0, -40, 0), bevel=0.0)
        # the glass dome: a cyan base ring, three ribs and a top spark
        base = (0, 0, Z0 - 0.05)
        with f.piece("Head"):
            f.torus(base, 2.15, 0.14, cyan, rot=(90, 0, 0), major=12, minor=4, sx=1.0, sz=0.82)
            for phi in (0, 34, -34):
                hoop(f, (0, 0, Z0 + 0.0), 2.15, 1.5, HH + 0.95, phi, 10, 0.08, cyan)
            f.rcyl((0, 0, top + 0.95 + 0.0), 0.2, 0.28, 0.28, "#6E7078", seg=6, bevel=0.0)
            f.rcyl((0, 0, top + 1.28), 0.06, 0.06, 0.5, dark, seg=4, bevel=0.0)
            f.ball((0, 0, top + 1.62), (0.28, 0.28, 0.28), cyan, seg=6, rings=3)
            for s_ in (-1, 1):  # side electrodes
                f.rcyl((s_ * 2.35, 0, zc - 0.2), 0.12, 0.12, 1.2, cyan, seg=4, bevel=0.0)
                f.ball((s_ * 2.35, 0, zc + 0.45), (0.2, 0.2, 0.2), "#FFFFFF", seg=5, rings=3)
    stars(f, ((-2.55, 0.0, 6.8), (2.55, 0.0, 7.1)), cyan, 1.0)


# --- 4. Golden Muse (Icon, Romance) -----------------------------------------------------------


def golden_muse(f):
    """Icon (Romance). A living gold award statue: a pleated Grecian gown with a sash, tall gold wings, a swept-up
    honey updo (rolled bun + tilted leaf) with a laurel wreath, serene lashes and a gentle smile, one arm
    raised holding a big radiant star torch, a floating halo and a ring of prismatic gems drifting round her."""
    skin, gold, gold_lt, cream, honey = "#F4C77C", "#F5B82E", "#FFD866", "#FFF1B0", "#C98A1E"
    RAISE = 0.3
    prof = [(1.75, 0.02), (1.78, 0.28), (1.4, 0.8), (1.1, 1.2), (0.95, 1.56)]

    def pleats(face):
        i = face.material_index
        if i == 0:
            return gold
        c = face.calc_center_median()
        k = int((math.atan2(c.y, c.x) + math.pi) / (2 * math.pi) * 12) % 2
        return cream if k else gold_lt

    with f.piece("Body"):  # wings behind: two tiers of feathers per side
        for side in (1, -1):
            for i, (a, ln) in enumerate(((22, 2.6), (44, 2.4), (66, 2.1))):
                f.leaf((side * 0.8, 0.95 + 0.04 * i, 2.7), (-6, side * a, 0), ln, 0.82, 0.16, gold_lt if i % 2 else cream, tip_color=gold, tip_from=0.68, tip=0.5, widest=0.5)
            for i, (a, ln) in enumerate(((60, 1.9), (84, 1.5))):
                f.leaf((side * 0.8, 0.85 + 0.04 * i, 2.5), (-6, side * a, 0), ln, 0.78, 0.15, cream if i % 2 else gold_lt, tip_color=gold, tip_from=0.68, tip=0.5, widest=0.5)
        f.lathe((0, 0, 0), prof, pleats, seg=12, scale=(1, 0.86, 1))
        f.rcyl((0, 0, 0.2), 1.9, 1.9, 0.2, "#D99A1C", seg=12, squash=0.86, bevel=0.04)  # hem trim
        for s_ in (-1, 1):
            f.rbox((s_ * 0.55, -1.3, 0.28), (0.8, 0.9, 0.46), "#D99A1C", bevel=0.12, segs=1)  # sandal toes
    torso(f, cream, h=1.7, z=2.0, w=1.8)
    with f.piece("Body"):
        f.rbox((0, 0, 1.46), (1.95, 1.44, 0.3), gold, bevel=0.08)  # sash
        f.rbox((-0.1, -0.69, 2.1), (0.34, 0.07, 1.9), gold_lt, rot=(0, -36, 0), bevel=0.0)  # diagonal strap
        f.rcyl((0.0, -0.74, 1.46), 0.34, 0.34, 0.12, "#FF5FD2", seg=6, rot=(90, 0, 0), bevel=0.0)  # jewel
        f.ball((0.0, -0.8, 1.46), (0.2, 0.1, 0.2), "#FFFFFF", seg=5, rings=3)
        for s_ in (-1, 1):  # shoulder clasps
            f.ball((s_ * 0.85, -0.5, 2.78), (0.26, 0.2, 0.22), gold_lt, seg=5, rings=3)

    def torch(f):  # a radiant star on a stem, stands up in the hand
        f.rcyl((0, 0, 0.3), 0.07, 0.1, 0.8, gold, seg=5, bevel=0.0)
        with f.at((0, -0.06, 1.1), (90, 0, 0)):
            pts = []
            bm = bmesh.new()
            ring = []
            for i in range(10):
                a = math.pi / 2 + i * math.pi / 5
                rr = 0.82 if i % 2 == 0 else 0.34
                ring.append((rr * math.cos(a), rr * math.sin(a)))
            top_v = [bm.verts.new((x, y, 0.1)) for x, y in ring]
            bot_v = [bm.verts.new((x, y, -0.1)) for x, y in ring]
            bm.faces.new(top_v)
            bm.faces.new(bot_v[::-1])
            for i in range(10):
                bm.faces.new((top_v[i], top_v[(i + 1) % 10], bot_v[(i + 1) % 10], bot_v[i]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            f._place(bm, (0, 0, 0), (0, 0, 0), lambda fc: "#FFFFFF" if fc.normal.z > 0.5 else gold_lt)
            f.ball((0, 0, 0.1), (0.2, 0.2, 0.12), "#FF5FD2", seg=5, rings=3)

    arm(f, 1, cream, skin, rot=(-5, 128, 0), held=torch, upright=True, shoulder_z=2.55, sleeve_r=0.3)
    arm(f, -1, cream, skin, rot=(-26, 34, 0), shoulder_z=2.55, sleeve_r=0.3)
    for sd, rot in ((1, (-5, 128, 0)), (-1, (-26, 34, 0))):
        with f.piece("ArmL" if sd > 0 else "ArmR"), f.at((sd * 1.1, 0, 2.55), (rot[0], -sd * rot[1], rot[2])):
            f.rcyl((0, 0, -0.62), 0.38, 0.34, 0.16, gold, seg=7, bevel=0.0)  # gold arm band
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, shade(skin, 1.0), spread=0.6, k=1.08, z=ez, color="#3A2010")
        for s_ in (-1, 1):  # long lashes sweeping out
            with f.piece("Head"), head_at(f, s_ * 0.98, ez + 0.25, 0.02):
                for ang, dz in ((-46, 0.0), (-16, 0.16)):
                    f.rbox((0, 0.02, dz), (0.34, 0.07, 0.09), "#7A4A22", rot=(0, s_ * ang, 0), bevel=0.0)
        K.face_brows(f, honey, length=0.9, thick=0.17, angle=8, x=0.6, z=ez + 0.8, worried=False, lift=(0.08, 0.08))
        K.face_blush(f, color="#FF8A78", x=0.96, z=ez - 0.34, w=0.5, h=0.32)
        with head_at(f, 0, ez - 0.75, 0.05), f.piece("Head"):  # a serene closed smile: a gentle arc
            for x, z, a in ((-0.34, 0.1, 28), (-0.14, -0.02, 10), (0.14, -0.02, -10), (0.34, 0.1, -28)):
                f.rbox((x, 0, z), (0.24, 0.07, 0.12), "#A8442E", rot=(0, a, 0), bevel=0.0)
        with f.piece("Head"):  # swept-up honey hair: tight cap, a rolled bun slab and a tilted leaf, laurel wreath
            f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), honey, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.3, 0.95, 1.25), honey, seg=8, rings=5)
            f.rcyl((0.2, 0.2, top + 0.5), 0.55, 0.55, 1.3, honey, rot=(0, 90, -26), seg=8, bevel=0.22, segs=2)  # rolled updo slab
            f.leaf((-0.2, 0.0, top + 0.2), (-60, -40, 0), 1.5, 0.7, 0.3, "#E2A83A", tip=0.4, widest=0.45)  # swept lock sweeping back
            for i in range(9):  # laurel leaves round the head, tilted out
                a = math.radians(-100 + i * 25)
                f.leaf((math.sin(a) * 1.05, math.cos(a) * 0.9 - 0.05, top - 0.55), (62, 0, -math.degrees(a)), 0.7, 0.32, 0.08, "#E8C84A" if i % 2 else gold_lt, tip=0.3, widest=0.5)
            f.torus((0, 0.3, top + 1.35), 0.8, 0.13, "#FFFFFF", rot=(70, 0, 0), major=10, minor=4)  # floating halo
    gems = ("#FF5FD2", "#A04DFF", "#3A8DFF", "#4CC764", "#FFC21A")
    with f.piece("Body"):
        for i, c in enumerate(gems):  # a ring of prismatic gems drifting round
            a = 2 * math.pi * i / 5 + 0.4
            p = (math.cos(a) * 2.5, math.sin(a) * 0.6, 3.1 + math.sin(a * 2) * 0.9)
            f.ball((p[0], p[1], p[2]), (0.32, 0.32, 0.55), c, seg=4, rings=2)  # an octahedron gem
    stars(f, ((-2.4, 0.0, 6.2), (2.4, 0.0, 6.9)), "#FF9AE0", 1.2)


# --- 5. Mech Hero (Icon, Action) --------------------------------------------------------------


def mech_hero(f):
    """Icon (Action). A tiny action hero piloting a huge red mech suit: chunky steel legs with hazard-stripe feet, a
    wide red hull with a gold star badge, giant fists (one raised, ready to punch), shoulder jets with flames, and the
    hero in the cockpit under a cyan-framed canopy: red headband with tails, spiky hair, fierce brows, a set jaw."""
    red, red_dk, steel, steel_dk, dark = "#C8202F", "#8E1624", "#AEB3C2", "#6E7078", "#2E2C34"
    skin, cyan = "#C68A5A", "#9FE8FF"
    RAISE = 0.7
    for s_ in (-1, 1):  # chunky mech legs
        with f.piece("Body"):
            f.rbox((s_ * 0.95, 0, 0.95), (1.25, 1.2, 1.5), steel, bevel=0.16, segs=1)
            f.rbox((s_ * 0.95, -0.62, 1.05), (0.9, 0.2, 0.6), red, bevel=0.06)  # knee armour
            f.rbox((s_ * 0.95, -0.2, 0.28), (1.4, 1.7, 0.56), dark, bevel=0.14, segs=1)  # foot
            for i in range(2):
                f.rbox((s_ * 0.95 - 0.3 + i * 0.6, -1.06, 0.3), (0.26, 0.06, 0.5), "#F5B82E", rot=(0, 0, 0), bevel=0.0)  # hazard toe bars
    torso(f, red, w=3.0, d=1.9, h=1.7, z=2.3, taper=0.9, bevel=0.3)
    with f.piece("Body"):
        f.rbox((0, 0, 1.5), (2.6, 1.7, 0.4), steel_dk, bevel=0.1)  # hip block
        f.rbox((0, -0.96, 2.35), (1.5, 0.1, 0.5), "#F5B82E", bevel=0.05)  # hazard plate
        for i in range(3):
            f.rbox((-0.45 + i * 0.45, -1.02, 2.35), (0.2, 0.06, 0.5), dark, rot=(0, 0, 0), bevel=0.0)
        with f.at((0, -0.97, 2.9), (90, 0, 0)):  # gold hero star badge
            f.disc((0, 0, 0), 0.7, 0.7, 0.08, "#F5B82E", seg=5)
            f.disc((0, 0, 0), 0.7, 0.7, 0.1, "#FFD866", seg=5, rot=(0, 0, 36))
        f.rbox((0, -0.95, 1.95), (0.3, 0.07, 0.5), "#FFFFFF", bevel=0.0)  # racing stripe
        for s_ in (-1, 1):  # huge shoulder pauldrons
            f.rbox((s_ * 1.8, 0, 3.0), (1.2, 1.3, 0.9), steel, bevel=0.2, segs=1)
            f.rbox((s_ * 1.8, 0, 3.4), (0.95, 1.05, 0.2), red, bevel=0.06)
            with f.at((s_ * 2.25, 0.5, 2.55), (0, s_ * 20, 0)):  # jet boosters, flames pointing down
                f.rcyl((0, 0, 0), 0.34, 0.4, 1.3, steel_dk, seg=6, bevel=0.0)
                f.rcyl((0, 0, 0.7), 0.4, 0.4, 0.14, "#F5B82E", seg=6, bevel=0.0)
                f.leaf((0, 0, -0.6), (180, 0, 0), 1.5, 0.62, 0.28, "#FF8A2E", tip_color="#FFE27A", tip_from=0.5, tip=0.2, widest=0.3)

    def fist(f):  # giant knuckled fist
        f.rbox((0, 0, -0.3), (1.15, 1.05, 0.95), dark, bevel=0.18, segs=1)
        f.rbox((0, -0.5, -0.1), (1.05, 0.2, 0.3), red, bevel=0.05)  # knuckle plate
        f.rbox((0, 0, 0.3), (1.0, 0.9, 0.18), "#F5B82E", bevel=0.0)  # cuff stripe

    arm(f, -1, red, steel, rot=(-95, 8, 0), held=fist, shoulder_z=3.05, x=1.8, sleeve_r=0.48, length=1.0)
    arm(f, 1, red, steel, rot=(-25, 14, 0), held=fist, shoulder_z=3.05, x=1.8, sleeve_r=0.48, length=1.0)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, skin, spread=0.6, k=1.0, z=ez)
        K.face_brows(f, "#1A1210", length=1.1, thick=0.26, angle=22, x=0.62, z=ez + 0.62, worried=False)  # fierce
        K.face_blush(f, x=0.95, z=ez - 0.4, w=0.36, h=0.22)
        with f.piece("Head"):  # a set jaw: a firm flat mouth, chin dimple, stubble line
            with head_at(f, 0, ez - 0.74, 0.05):  # a scowl: flat bar, ends turned down
                f.rbox((0, 0, 0), (0.7, 0.07, 0.15), "#5A1A26", bevel=0.0)
                for s_ in (-1, 1):
                    f.rbox((s_ * 0.5, 0, -0.1), (0.34, 0.07, 0.15), "#5A1A26", rot=(0, s_ * 30, 0), bevel=0.0)
        with f.piece("Head"):  # spiky black hair swept back under a red headband with tails
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), "#161220", seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), "#161220", seg=8, rings=5)
            for x, y, h, tilt in ((-0.7, 0.25, 0.9, -20), (0.0, 0.3, 1.1, 0), (0.7, 0.25, 0.9, 20), (0.0, 0.75, 0.8, 0)):
                f.spike((x, y, top - 0.15), 0.4, h, "#161220", rot=(-16, tilt, 0), seg=4)
            f.rcyl((0, 0.08, top - 0.72), 1.26, 1.26, 0.3, red, seg=10, squash=0.88, bevel=0.04)
            for s_, rx in ((-1, 12), (1, -10)):
                f.leaf((s_ * 0.3, 1.1, top - 0.72), (100, s_ * 24, 0), 1.8, 0.5, 0.1, red, tip=0.45, widest=0.4)
        # canopy: a dark collar, a cyan base ring and arches
        with f.piece("Head"):
            f.rcyl((0, 0, HEAD_Z0 - 0.45), 2.0, 1.85, 0.34, dark, seg=8, squash=0.86, bevel=0.06)
            for phi in (34, -34):
                hoop(f, (0, 0, HEAD_Z0 - 0.3), 1.85, 1.5, K.HEAD_H + 0.7, phi, 6, 0.14, cyan)
            f.ball((0, 0, top + 0.72), (0.22, 0.22, 0.22), "#FFC21A", seg=5, rings=3)  # beacon
    stars(f, ((-2.5, 0.0, 7.0), (2.5, 0.0, 6.8)), "#FFC21A", 1.0)


# --- 6. The Phantom Auteur (Icon, Horror) -----------------------------------------------------


def phantom(f):
    with f.at((0, 0, 0.6)):  # hovers: the whole ghost floats above the plinth
        _phantom(f)


def _phantom(f):
    """Icon (Horror). A one-of-a-kind ghost director: hovers on a curling ghost tail, a tall crooked top hat with a
    glowing magenta band, a white half-mask over a pale face with glowing lime eyes and a wide jagged grin, a golden
    megaphone, a skeletal glove, a spray of prismatic ribbons streaming off one shoulder and a tilted film strip
    orbiting him."""
    skin, mask, robe, robe_lt, dark = "#C9C4E0", "#FFFFFF", "#3B2470", "#5A3AA0", "#161220"
    glow, pink = "#B6FF5C", "#FF5FD2"
    RAISE = 0.5
    with f.piece("Body"):
        # prismatic ribbons streaming off the actor's left shoulder (behind)
        for i, c in enumerate(("#FF5FD2", "#A04DFF", "#3A8DFF", "#4CC764", "#FFC21A")):
            f.leaf((0.6, 0.9, 3.0 - i * 0.1), (-8 - i * 4, 32 + i * 8, 0), 2.2 - i * 0.1, 0.65, 0.12, c, tip=0.3, widest=0.45)
        f.rbox((0, 0.85, 2.55), (2.4, 0.2, 2.6), dark, bevel=0.0, taper=0.7, rot=(6, 0, 0))  # dark cape back
        # ghost tail: robe skirt then a curl
        f.rcyl((0, 0.05, 1.25), 1.25, 1.0, 1.15, robe, seg=8, squash=0.82, bevel=0.0)
        for i in range(8):  # tattered hem tips
            a = 2 * math.pi * i / 8
            f.spike((math.cos(a) * 0.95, math.sin(a) * 0.8 + 0.05, 0.7), 0.3, 0.55, robe_lt if i % 2 else robe, rot=(180, 0, 0), seg=3)
        f.rcyl((0.3, 0.2, 0.55), 0.7, 0.9, 0.8, robe, rot=(0, 8, 0), seg=7, squash=0.85, bevel=0.0)
        f.spike((0.7, 0.2, 0.55), 0.65, 1.1, robe, rot=(180, -10, 0), seg=6, squash=0.85)
        f.spike((1.2, 0.15, 0.2), 0.32, 0.9, robe_lt, rot=(180, -45, 0), seg=5)  # curl tip
    torso(f, robe, h=1.7, z=2.15, w=1.9)
    with f.piece("Body"):
        f.rbox((0, -0.7, 2.2), (1.0, 0.07, 1.3), robe_lt, bevel=0.0, taper=1.3)  # waistcoat
        for i, z in enumerate((1.8, 2.2, 2.6)):
            f.ball((0, -0.78, z), (0.14, 0.1, 0.14), GOLD, seg=4, rings=2)
        for s_ in (-1, 1):  # popped collar points
            f.rbox((s_ * 0.75, -0.2, 3.2), (0.7, 0.2, 0.8), dark, rot=(0, s_ * 14, 0), bevel=0.0, taper=1.5)
        # film strip orbit: one connected ribbon ring, tilted (low in front)
        n = 12
        for i in range(n):
            t = 2 * math.pi * i / n
            x, y, z = 2.1 * math.cos(t), 1.4 * math.sin(t), 2.75 + 0.8 * math.sin(t)
            ang = math.degrees(t) + 90
            tilt = -math.degrees(math.atan2(0.8 * math.cos(t), 2.35 * -math.sin(t) + 1e-6)) * 0.0
            with f.at((x, y, z), (0, 0, ang)):
                f.rbox((0, 0, 0), (1.15, 0.07, 0.62), dark, bevel=0.0)
                f.rbox((0, -0.05, 0.0), (0.7, 0.08, 0.38), (pink, "#3A8DFF", "#FFC21A", "#4CC764")[i % 4], bevel=0.0)

    def megaphone(f):  # golden director's megaphone, pointing up and out
        with f.at((0, -0.1, 0.1), (0, -32, 0)):
            f.rcyl((0, 0, 0.4), 0.14, 0.5, 0.9, GOLD, seg=8, bevel=0.0)
            f.rcyl((0, 0, 0.88), 0.55, 0.55, 0.1, dark, seg=8, bevel=0.0)
            f.rcyl((0, 0, 0.0), 0.2, 0.2, 0.24, dark, seg=6, bevel=0.0)

    arm(f, -1, robe, "#F2F0F8", rot=(-30, 52, 0), held=megaphone, upright=True, shoulder_z=2.7, sleeve_r=0.34, x=1.2)
    arm(f, 1, robe, "#F2F0F8", rot=(-146, -22, 0), shoulder_z=2.7, sleeve_r=0.34)
    with f.piece("ArmL"), f.at((1.1, 0, 2.7), (-146, 22, 0)):  # skeletal fingers
        for i, ang in enumerate((-40, -13, 13, 40)):
            f.spike((0, 0, -1.2), 0.08, 0.55, "#F2F0F8", rot=(180, ang, 0), seg=4)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        with f.piece("Head"):  # the white half-mask on the actor's right (viewer left) with gold trim
            head_patch(f, -0.62, ez + 0.1, 0.92, 1.22, 0.05, mask, seg=14, rings=2)
            K.head_ring(f, -0.62, ez + 0.1, 0.94, 1.24, 0.06, 0.06, GOLD, major=14, minor=4)
        K.face_eyes(f, "#3B2470", spread=0.6, k=1.1, z=ez, color=glow, glow="#EFFFB0", out=0.07)
        K.face_brows(f, dark, length=1.1, thick=0.24, angle=24, x=0.62, z=ez + 0.78, worried=False, out=0.07)
        with f.piece("Head"):  # a wide jagged grin: dark crescent, a row of zig-zag teeth
            head_patch(f, 0, ez - 0.74, 0.98, 0.34, 0.05, "#2A1236", seg=10, rings=1)
            for i in range(7):
                x = -0.78 + i * 0.26
                with head_at(f, x, ez - 0.6, 0.06):
                    f.spike((0, 0, 0.0), 0.1, 0.3 if i % 2 == 0 else 0.22, WHITE, rot=(180, 0, 0), seg=3)
        with f.piece("Head"):  # tall crooked top hat with a glowing band
            dome(f, (0.1, 0.05, top - 0.18), [(1.45, 0.0), (1.48, 0.16), (0.82, 0.22), (0.9, 0.7), (0.9, 1.1), (0.78, 1.9)], [dark, dark, dark, dark, dark], seg=10, rot=(0, 10, 0))
            f.rcyl((0.1 + 0.18, 0.05, top + 0.45), 0.95, 0.95, 0.4, pink, seg=10, rot=(0, 10, 0), bevel=0.0)
            f.rbox((0.1 + 0.18, -0.9, top + 0.45), (0.34, 0.1, 0.5), GOLD, rot=(0, 10, 0), bevel=0.0)  # buckle
            for s_ in (-1, 1):  # pale side locks
                f.ball((s_ * 1.3, 0.2, ez + 0.4), (0.3, 0.4, 0.7), "#9A94B8", seg=5, rings=3)
    stars(f, ((-2.5, 0.0, 7.0), (2.5, 0.0, 6.4)), "#B6FF5C", 1.1)


# Names are the in-game actor ids (src/shared/Actors.luau), so the FBX pieces drop straight into LotMeshes.
STATE = {}  # live handles kept between MCP calls: scene + built figures


BUILDS = {
    "diva": ("GoldenAgeDiva", "Legend", showgirl),
    "clown": ("SilentEraClown", "Legend", silent_clown),
    "brain": ("SciFiVisionary", "Legend", brain_jar),
    "muse": ("MogulsMuse", "Icon", golden_muse),
    "mech": ("LastActionHero", "Icon", mech_hero),
    "phantom": ("PhantomAuteur", "Icon", phantom),
}
K.ACTORS.update(BUILDS)
B3_KEYS = tuple(BUILDS)
OLD_FN = {  # the in-game versions (art/blender/actors.py)
    "diva": "showgirl_diva",
    "clown": "silent_clown",
    "brain": "brain_jar",
    "muse": "golden_muse",
    "mech": "mech_hero",
    "phantom": "phantom_auteur",
    "heart": "heartthrob",
}
APPROVED = ("intern", "pup", "squawk")
LINEUP = ("heart", "diva", "clown", "brain", "muse", "mech", "phantom", "intern", "pup", "squawk")
OUT = K.OUT_DIR
CAPS = {"Legend": 2500, "Icon": 2500, "Star": 2200}


def build(key, index=0, with_ao=True):  # replaces K.build so Icon actors get the Icon base crystals
    name, tier, fn = K.ACTORS[key]
    f = K.Fig(name, tier)
    fn(f)
    K.plinth(f, tier)
    if tier == "Icon":
        icon_base(f)
    objs = f.finish_objects(offset=(index * K.GAP, 0, 0))
    return f, objs


K.build = build


def build_all(keys=None):
    keys = list(keys or (list(B3_KEYS) + ["heart"] + list(APPROVED)))
    sc, built, report = K.main(tuple(keys))
    STATE.update(sc=sc, built=built, report=report)
    return sc, built, report


def objs_of(built, key):
    return list(built[key][1].values())


def render_one(sc, built, key, res=720, tag=None):
    """Sheet + views + FBX for one actor (files actors_v2_b3_<key>_*)."""
    tag = tag or f"b3_{key}"
    ol = objs_of(built, key)
    K.floor_for(sc, x=0)
    paths = K.render_set(sc, key, ol, tag, res=res)
    old = {o: o.location.copy() for o in ol}
    for o in ol:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    K.export_fbx(ol, os.path.join(OUT, f"actors_v2_{tag}.fbx"))
    for o, l in old.items():
        o.location = l
    bpy.context.view_layer.update()
    return paths


def compare_one(sc, built, key, res=900, gap=7.0, tag=None):
    """The in-game version (left) next to the new one (right), front and 3/4, same light and camera."""
    import importlib

    old = importlib.import_module("actors")
    new_objs = objs_of(built, key)
    x0 = new_objs[0].location.x / K.STUD
    name, tier, _ = K.ACTORS[key]
    a = old.make(name, tier, getattr(old, OLD_FN[key]))
    a.name = f"OLD_{key}"
    oo = a.objects((x0 - gap, 0, -0.23))
    both = list(oo.values()) + new_objs
    tiles = []
    for nm, az, el in (("front", 0, 18), ("34", 32, 20)):
        p = K.shoot(sc, both, f"/tmp/b3_cmp_{key}_{nm}.png", az=az, el=el, res=res, hide_others=False, margin=1.25, lens=120, samples=40)
        tiles.append(K.load_img(p))
    for o in oo.values():
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    out = os.path.join(OUT, f"actors_v2_{tag or 'b3_' + key}_compare.png")
    K.save_img(K.hstack(tiles, pad=8), out)
    return out


def lineup(sc, built, path=None, res=360):
    """Batch 3 + the fixed Heartthrob + the three approved (green bar), two rows of five."""
    path = path or os.path.join(OUT, "actors_v2_b3_lineup.png")
    tiles = []
    for key in LINEUP:
        ol = objs_of(built, key)
        x = ol[0].location.x
        ctr = Vector((x, 0, 3.6 * K.STUD))
        t = K.load_img(K.shoot(sc, ol, f"/tmp/b3_lu_{key}.png", az=22, el=12, res=res, center=ctr, radius=6.2 * K.STUD, margin=1.0, samples=32, lens=70))
        t[:10, :, :3] = np.array(K.lin("#4CC764")[:3] if key in APPROVED else K.lin("#E9E4D8")[:3])
        tiles.append(t)
    K.save_img(K.vstack([K.hstack(tiles[:5], pad=4), K.hstack(tiles[5:], pad=4)], pad=4), path)
    return path


def silhouettes(sc, built, path=None):
    path = path or os.path.join(OUT, "actors_v2_b3_silhouettes_64.png")
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


def quick3(keys, res=520, tag="b3q"):
    """Fast iteration: rebuild the given actors, front | 3/4 | back each, one PNG per actor in /tmp."""
    sc, built, report = K.main(tuple(keys))
    outs = []
    for key in keys:
        f, objs = built[key]
        ol = list(objs.values())
        shots = [K.load_img(K.shoot(sc, ol, f"/tmp/a2_{tag}_{i}.png", az=az, el=el, res=res, margin=1.3, samples=24)) for i, (az, el) in enumerate(((0, 12), (38, 16), (180, 12)))]
        out = f"/tmp/{tag}_{key}.png"
        K.save_img(K.hstack(shots, pad=4), out)
        by = {}
        for p, k_, t in f.log:
            by[p] = by.get(p, 0) + t
        print(key, "tris", report[key]["tris"], by, "size", report[key]["size_studs"], "xr", report[key]["x_range"])
        outs.append(out)
    return sc, built, outs


def finalize_b3(render=True, keys=None):
    """Build all, QA, render every sheet as actors_v2_b3_*, compares, lineup, silhouettes, FBX."""
    sc, built, report = build_all()
    out = {"qa": {k: report[k] for k in list(B3_KEYS) + ["heart"]}}
    if not render:
        return sc, built, out
    for key in keys or B3_KEYS:
        out[key] = render_one(sc, built, key)
        compare_one(sc, built, key)
    out["heart"] = render_one(sc, built, "heart", tag="b3_heart")
    compare_one(sc, built, "heart", tag="b3_heart")
    lineup(sc, built)
    silhouettes(sc, built)
    return sc, built, out
