"""Actors v2, batch 1 of the old 21: the first seven old actors polished to the approved style bible
(Nervous Intern A, Werewolf Pup, Captain Squawk). Same characters, costumes and colours as the in-game
versions in actors.py; rebuilt with the v2 kit (actors_v2.py): pill head with face parts on its surface,
two-segment bevels, vertex-colour AO, tier plinth.

  Stunt Double, Zombie Extra (Newcomer) - Soap Opera Star, Hot Dog Mascot, Robot Sidekick (Rising)
  Commando, Ventriloquist (Pro)

Run live (MCP for Blender): see load() below; finalize_b1() builds, QAs, renders everything and exports
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
from actors_v2 import (  # noqa: E402
    EYE_DARK,
    EYE_Z,
    HEAD_Z0,
    M,
    head_at,
    head_box,
    head_patch,
    legs_kid,
    arm,
    shade,
    torso,
)

WHITE = "#FFFFFF"
MOUTH = "#7A2836"
PINK = "#F29A9A"


# --- small shared helpers ---------------------------------------------------------------------


def eye1(f, skin, x, z, k=1.0, kx=None, color=EYE_DARK, socket=True, spec=True, out=0.0, sock=None):
    """One tall-oval eye (see face_eyes), so actors can have uneven or covered eyes."""
    kx = kx or k
    with f.piece("Head"), head_at(f, x, z, out), f.at((0, 0, 0), (90, 0, 0)):
        if socket:
            f.disc((0, 0.0, 0.0), 0.7 * kx, 0.86 * k, 0.05, sock or shade(skin, 0.86), seg=8)
        f.disc((0, 0.0, 0.035), 0.5 * kx, 0.64 * k, 0.05, color, seg=10)
        if spec:
            f.disc((-0.1 * kx, 0.14 * k, 0.07), 0.17 * kx, 0.19 * k, 0.04, WHITE, seg=5)


def brow1(f, color, x, z, length=0.95, thick=0.2, angle=0, out=0.0):
    with f.piece("Head"), head_at(f, x, z, out):
        f.rbox((0, -0.02, 0), (length, 0.11, thick), color, rot=(0, angle, 0), bevel=0.0)


def mouth_grin(f, z, w, h, teeth=True, gaps=True, dark=MOUTH, x=0.0):
    """Dark mouth patch with a white teeth patch (hugs the chin curve, like Squawk's grin)."""
    with f.piece("Head"):
        head_patch(f, x, z, w, h, 0.05, dark, seg=8, rings=1)
        if teeth:
            head_patch(f, x, z + h * 0.1, w * 0.86, h * 0.62, 0.075, WHITE, seg=8, rings=1)
            if gaps:
                for g in (-w * 0.3, w * 0.3):
                    with head_at(f, x + g, z + h * 0.1, 0.1):
                        f.rbox((0, 0, 0), (0.05, 0.04, h * 1.1), dark, bevel=0.0)


def mouth_o(f, z, rx, rz, dark=MOUTH, tongue="#E86A7A"):
    with f.piece("Head"):
        head_patch(f, 0, z, rx, rz, 0.05, dark, seg=10, rings=1)
        head_patch(f, 0, z - rz * 0.35, rx * 0.62, rz * 0.5, 0.075, tongue, seg=8, rings=1)


def ears(f, skin, ez, x=1.22, k=1.0):
    with f.piece("Head"):
        for s_ in (-1, 1):
            f.ball((s_ * x, 0.05, ez + 0.05), (0.2 * k, 0.3 * k, 0.38 * k), shade(skin, 0.94), seg=6, rings=3)


def along(p0, p1):
    """Matrix placing a Z-aligned shape's centre at the midpoint of p0..p1 with +Z along p0->p1; returns (matrix, length)."""
    a, b = Vector(p0), Vector(p1)
    d = b - a
    q = d.to_track_quat("Z", "Y")
    return Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), d.length


def tube(f, p0, p1, r1, r2, color, seg=8, bevel=0.0):
    m, ln = along(p0, p1)
    with f.at_matrix(m):
        f.rcyl((0, 0, 0), r1, r2, ln, color, seg=seg, bevel=bevel)


def dome(f, at, profile, color, scale=(1, 1, 1), seg=10, rot=(0, 0, 0)):
    """A lathed cap (helmet, hat) from profile [(r, z)...]; colour one hex, a list per band, or a function of the face."""
    n = len(profile) - 1
    cols = color if (callable(color) or isinstance(color, (list, tuple))) else [color] * n
    f.lathe(at, profile, cols if callable(cols) else list(cols), rot=rot, seg=seg, scale=scale)


# --- 1. Stunt Double (Newcomer, Action) -------------------------------------------------------


def stunt_double(f):
    """Newcomer (Action). One stunt too many: red crash helmet with a white stripe and a flipped-up visor,
    plaster on the cheek, orange jumpsuit with reflective stripes, one arm in a white cast and a sling, the
    other giving a big thumbs up; knee pad, yellow boots."""
    skin, suit, pants, shoes, sole = "#7A4A2E", "#FF8A1F", "#2E86DE", "#F5B82E", "#3A2A20"
    white, helmet, strap = "#FAF6EC", "#E8333A", "#4A88D8"
    RAISE = 0.3
    legs_kid(f, pants, shoes, sole)
    torso(f, suit, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), pants, bevel=0.1)  # waist
        f.rbox((0, 0, 1.62), (1.92, 1.44, 0.12), sole, bevel=0.0)  # belt
        f.rbox((0, -0.7, 1.62), (0.34, 0.08, 0.2), "#F5B82E", bevel=0.0)  # buckle
        for z in (1.98, 2.34):  # reflective stripes
            f.rbox((0, -0.68, z), (1.8, 0.07, 0.17), white, bevel=0.0, taper=0.94)
        f.rbox((0.55, -0.45, 1.05), (0.74, 0.2, 0.58), white, bevel=0.09, segs=1)  # knee pad
        f.rbox((-0.1, -0.66, 2.3), (0.3, 0.07, 1.9), strap, rot=(0, -34, 0), bevel=0.0)  # sling strap

    def thumb(f):
        f.rbox((0.0, -0.1, 0.38), (0.32, 0.34, 0.66), skin, bevel=0.08, segs=1)

    arm(f, 1, suit, skin, rot=(-25, 62, 0), held=thumb, upright=True, shoulder_z=2.55)
    arm(f, -1, white, white, rot=(-55, -52, 0), shoulder_z=2.55, sleeve_r=0.42, length=0.95)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, skin, spread=0.6, z=ez)
        K.face_brows(f, "#1E1612", length=1.0, thick=0.22, angle=10, x=0.62, z=ez + 0.7, worried=False, lift=(0.0, 0.0))
        K.face_blush(f, x=0.9, z=ez - 0.34, seg=6)
        mouth_grin(f, ez - 0.72, 0.62, 0.24, gaps=False)
        with f.piece("Head"):
            with head_at(f, 0.92, ez - 0.52, 0.1):  # plaster cross on the cheek
                f.rbox((0, 0, 0), (0.56, 0.06, 0.2), "#F2C49C", rot=(0, 30, 0), bevel=0.0)
                f.rbox((0, 0, 0), (0.2, 0.06, 0.56), "#F2C49C", rot=(0, 30, 0), bevel=0.0)
            # crash helmet: a lathed shell over the dome, rim just above the brows, ear flaps, stripe, visor up
            def helmet_col(face):  # white centre stripe front to back, painted on the shell
                c = face.calc_center_median()
                return white if face.normal.z > 0.15 and abs(c.x) < 0.05 else helmet

            dome(f, (0, 0.05, 4.46), [(1.0, 0.0), (1.06, 0.2), (1.0, 0.55), (0.84, 0.9), (0.5, 1.2), (0.0, 1.32)], helmet_col, scale=(1.36, 1.22, 1.0), seg=14)
            for s_ in (-1, 1):
                f.rbox((s_ * 1.3, 0.2, 4.1), (0.34, 1.4, 1.0), helmet, bevel=0.1, segs=1)  # ear flaps
                f.rbox((s_ * 1.5, 0.15, 4.5), (0.14, 0.5, 0.44), "#F5B82E", bevel=0.04)  # side badge
            f.rbox((0, -1.0, 5.3), (1.75, 0.14, 0.85), "#5CF2FF", rot=(-62, 0, 0), bevel=0.04)  # visor flipped up
            f.rbox((0, -0.8, 5.0), (1.9, 0.3, 0.14), shade(helmet, 0.8), bevel=0.0)  # visor hinge


# --- 2. Zombie Extra (Newcomer, Romance) ------------------------------------------------------


def zombie_extra(f):
    """Newcomer (Romance). A lovesick zombie extra: green pill head with mismatched eyes, a wobbly toothy
    grimace and a stitched forehead, messy hair with a flower, torn beige shirt (hole, stain, ragged hem),
    bandaged shoulder, arms out holding a wilted rose."""
    skin, shirt, pants, shoes = "#9CC77A", "#C9B48A", "#5A5F7A", "#5A4636"
    hair, hair_lt, stitch = "#3B2A1E", "#5A402E", "#3E5A2E"
    RAISE = 0.25
    legs_kid(f, pants, shoes, "#2E221A")
    torso(f, shirt, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), pants, bevel=0.1)
        f.rbox((0, 0, 1.62), (1.92, 1.44, 0.12), "#4A3022", bevel=0.0)
        for i, x in enumerate((-0.7, -0.35, 0.0, 0.35, 0.7)):  # ragged hem
            f.spike((x, -0.5 + (0.1 if i % 2 else 0), 1.78), 0.22, 0.42, shirt, rot=(180, 0, 0), seg=4, squash=0.6)
        for x in (-0.6, 0.0, 0.6):
            f.spike((x, 0.55, 1.78), 0.22, 0.4, shirt, rot=(180, 0, 0), seg=4, squash=0.6)
        with f.at((0.4, -0.66, 2.05), (90, 0, 0)):
            f.disc((0, 0, 0), 0.62, 0.55, 0.06, skin, seg=7)  # hole in the shirt, green skin showing
        f.rbox((-0.45, -0.69, 2.4), (0.62, 0.07, 0.18), "#7A1F2B", rot=(0, -14, 0), bevel=0.0)  # stain

    def rose(f):  # the wilted rose, stands up in the hand
        f.rcyl((0, -0.05, 0.5), 0.07, 0.07, 0.8, "#4F7A3A", seg=5, bevel=0.0)
        for s_ in (-1, 1):
            f.leaf((s_ * 0.04, -0.05, 0.3), (0, s_ * 70, 0), 0.5, 0.3, 0.07, "#4F7A3A", tip=0.3)
        with f.at((0.1, -0.05, 0.98), (0, 24, 0)):  # bud: drooping head
            f.ball((0, 0, 0), (0.33, 0.3, 0.28), "#B5283A", seg=7, rings=4)
            f.ball((0.0, -0.05, 0.12), (0.2, 0.18, 0.15), "#7A1F2B", seg=6, rings=3)

    arm(f, 1, shirt, skin, rot=(-62, 58, 0), held=rose, upright=True, shoulder_z=2.55)
    arm(f, -1, shirt, skin, rot=(-66, 46, 0), shoulder_z=2.55)
    with f.piece("ArmR"), f.at((-1.1, 0, 2.55), (-66, -46, 0)):  # bandage round the sleeve
        f.rcyl((0, 0, -0.35), 0.36, 0.36, 0.34, "#FAF6EC", seg=7, bevel=0.0)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.08
        ears(f, skin, ez, x=1.22)
        eye1(f, skin, -0.6, ez, k=0.82, sock=shade(skin, 0.7), out=0.0)
        eye1(f, skin, 0.6, ez - 0.02, k=1.2, sock=shade(skin, 0.7), out=0.0)
        brow1(f, "#2E3A24", -0.62, ez + 0.58, 0.9, 0.2, angle=-14)
        brow1(f, "#2E3A24", 0.62, ez + 0.74, 0.95, 0.2, angle=14)
        # wobbly lopsided mouth: dark patch with three wonky teeth
        with f.piece("Head"):
            head_patch(f, 0.05, ez - 0.76, 0.56, 0.22, 0.05, "#4A1E2A", seg=8, rings=1)
            for x, hh in ((-0.28, 0.2), (0.0, 0.14), (0.3, 0.22)):
                with head_at(f, x + 0.05, ez - 0.7, 0.1):
                    f.rbox((0, 0, 0), (0.2, 0.05, hh), "#F4EFD2", bevel=0.0)
            # stitches: a diagonal scar across the brow with cross-stitches
            with head_at(f, 0.82, ez + 0.98, 0.04):
                f.rbox((0, 0, 0), (0.95, 0.06, 0.1), stitch, rot=(0, 22, 0), bevel=0.0)
                for i in range(3):
                    f.rbox((-0.3 + i * 0.3, 0, -0.08 + i * 0.1), (0.07, 0.07, 0.3), stitch, rot=(0, 22, 0), bevel=0.0)
        with f.piece("Head"):  # messy hair: tight cap + tufts, a red flower
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            for x, y, rz, h in ((-0.7, -0.05, 22, 0.8), (0.1, 0.0, -8, 0.95), (0.8, 0.1, -26, 0.7), (-0.2, 0.55, 16, 0.7)):
                f.spike((x, y, top - 0.1), 0.3, h, hair_lt if x < 0 else hair, rot=(-14, rz, 0), seg=4, squash=0.7)
            with f.at((0.55, -0.1, top + 0.55)):
                for k in range(4):
                    f.ball((0.22 * math.cos(k * 1.57), 0, 0.22 * math.sin(k * 1.57)), (0.18, 0.08, 0.18), "#E8333A", seg=5, rings=3)
                f.ball((0, -0.05, 0), (0.12, 0.08, 0.12), "#FFD21A", seg=5, rings=3)


# --- 3. Soap Opera Star (Rising, Romance) -----------------------------------------------------


def soap_star(f):
    """Rising (Romance). Mid-gasp drama queen: a huge halo of chestnut curls with sunglasses pushed up on
    top, wide eyes and an O mouth, gold hoops, puff-sleeved pink dress-top over white trousers, red shoes,
    a phone with the shocking text in one hand and the other arm thrown up."""
    skin, hair, hair_lt = "#D9A27A", "#7A3A1A", "#9A5028"
    pink, white, red, gold = "#FF5FD2", "#FAF6EC", "#C8202F", "#F5B82E"
    RAISE = 0.3
    legs_kid(f, white, red, "#7A1019")
    torso(f, pink, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.42), (1.92, 1.44, 0.4), shade(pink, 0.82), bevel=0.1)  # flared hem of the top
        f.rbox((0, -0.69, 2.7), (0.9, 0.1, 0.22), white, bevel=0.0, taper=1.5)  # white collar
        f.rbox((0, -0.7, 2.58), (0.3, 0.1, 0.18), gold, bevel=0.0)  # brooch
        f.rbox((0, 0, 1.62), (1.93, 1.45, 0.1), gold, bevel=0.0)  # belt

    def phone(f):
        with f.at((0.05, -0.2, 0.28), (14, 0, 0)):
            f.rbox((0, 0, 0), (0.46, 0.1, 0.8), "#2E2C34", bevel=0.05, segs=1)
            f.rbox((0, -0.06, 0.0), (0.36, 0.05, 0.64), "#9FE8FF", bevel=0.0)

    for s_ in (-1, 1):  # puff sleeves
        with f.piece("ArmL" if s_ > 0 else "ArmR"):
            pass
    arm(f, 1, pink, skin, rot=(-52, 24, 0), held=phone, upright=True, shoulder_z=2.55, sleeve_r=0.4)
    arm(f, -1, pink, skin, rot=(-158, -30, 0), shoulder_z=2.55, sleeve_r=0.4)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, skin, spread=0.6, k=1.12, z=ez)
        K.face_brows(f, "#3A2016", length=0.95, thick=0.2, angle=8, x=0.62, z=ez + 0.78, worried=False, lift=(0.1, 0.1))
        K.face_blush(f, x=0.92, z=ez - 0.4, w=0.42, h=0.26)
        mouth_o(f, ez - 0.78, 0.3, 0.3)
        with f.piece("Head"):
            for s_ in (-1, 1):  # gold hoops
                with head_at(f, s_ * 1.22, ez - 0.3, 0.0):
                    f.torus((0, 0, 0), 0.22, 0.05, gold, major=8, minor=3)
            # hair: a halo of curls round the face, clear forehead
            f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), hair, seg=8, rings=5)
            f.ball((0, 0.65, top - 1.1), (1.5, 1.05, 1.5), hair, seg=8, rings=5)
            for s_ in (-1, 1):
                f.ball((s_ * 1.3, 0.15, top - 0.5), (0.62, 0.62, 0.62), hair, seg=7, rings=4)
                f.ball((s_ * 1.45, 0.3, top - 1.35), (0.62, 0.6, 0.62), hair_lt, seg=7, rings=4)
                f.ball((s_ * 0.8, 0.05, top + 0.12), (0.62, 0.55, 0.5), hair_lt if s_ < 0 else hair, seg=7, rings=4)
            f.ball((0, 0.2, top + 0.3), (0.6, 0.55, 0.5), hair, seg=7, rings=4)
            f.ball((-0.2, -0.45, top - 0.1), (0.5, 0.35, 0.3), hair_lt, seg=6, rings=3)  # little side curl above the brow
            # sunglasses pushed up on the curls
            with f.at((0.05, -0.55, top + 0.35), (-24, 0, 0)):
                f.rbox((0, 0, 0), (1.6, 0.16, 0.5), "#161220", bevel=0.07, segs=1)
                f.rbox((0, -0.06, 0.0), (0.14, 0.1, 0.12), "#161220", bevel=0.0)
                for s_ in (-1, 1):
                    f.rbox((s_ * 0.42, -0.09, 0.0), (0.58, 0.06, 0.34), "#4A5BA8", bevel=0.0)


# --- 4. Hot Dog Mascot (Rising, Comedy) -------------------------------------------------------


def hotdog_mascot(f):
    """Rising (Comedy). The ad model who only ever gets cast as the hot dog: two tall bun halves wrapped round
    a sausage costume, mustard squiggles, face in the hole (skin face plate on the sausage head, box-head
    costume template), white gloves waving a sign."""
    skin, bun, bun_in, saus, saus_lt = "#F0C49C", "#E8A85A", "#F8DDA0", "#C8502F", "#DE6A3C"
    must = "#FFD21A"
    RAISE = 0.15
    legs_kid(f, "#C8202F", "#FAF6EC", "#B8B2A4", spread=0.5)
    torso(f, saus, w=2.3, d=1.9, h=2.1, z=2.0, taper=1.0, bevel=0.5)  # one tall sausage: body and head
    with f.piece("Body"):
        for i in range(5):  # mustard squiggle down the front
            f.rbox(((-1) ** i * 0.22, -0.96, 1.1 + i * 0.3), (0.8, 0.1, 0.17), must, rot=(0, (-1) ** i * 24, 0), bevel=0.0)

        def bun_col(s_):
            def c(face):
                if face.normal.x * s_ < -0.55:
                    return bun_in
                return shade(bun, 0.82) if face.normal.z > 0.6 else bun

            return c

        for s_ in (-1, 1):  # tall bun halves hugging the sausage, up past the face
            f.rbox((s_ * 1.5, 0.15, 2.85), (0.85, 1.9, 3.9), bun_col(s_), bevel=0.4, segs=2, taper=0.9)

    def sign(f):
        f.rcyl((0, -0.1, 0.8), 0.07, 0.07, 1.9, "#96623C", seg=5, bevel=0.0)
        with f.at((0.0, -0.12, 2.0)):
            f.rbox((0, 0, 0), (1.15, 0.1, 0.9), "#FAF6EC", bevel=0.05, segs=1)
            f.rbox((0, -0.07, 0.2), (0.95, 0.05, 0.25), "#C8202F", bevel=0.0)
            for i in range(3):
                f.rbox((-0.31 + i * 0.31, -0.07, -0.17), (0.34, 0.05, 0.1), must, rot=(0, (-1) ** i * 28, 0), bevel=0.0)

    arm(f, 1, bun, "#FAF6EC", rot=(-8, 24, 0), held=sign, upright=True, shoulder_z=2.45, x=1.8, sleeve_r=0.3)
    arm(f, -1, bun, "#FAF6EC", rot=(-12, 14, 0), shoulder_z=2.45, x=1.8, sleeve_r=0.3)
    with f.at((0, 0, RAISE)):
        head_box(f, saus, r=0.95, w=2.3, d=1.9, h=2.6, segs=2)  # the sausage end: a round pill
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        OUT = 0.1
        head_patch(f, 0, ez + 0.1, 0.92, 1.02, 0.08, skin, seg=14, rings=2)  # the hole: a skin face plate
        with f.piece("Head"):
            K.head_ring(f, 0, ez + 0.1, 0.96, 1.06, 0.12, 0.04, saus_lt, major=14, minor=4)
            for i, (x, z, rr) in enumerate(((-0.5, 0.0, 34), (0.0, 0.0, -34), (0.5, 0.0, 34))):  # a curl of mustard on top
                f.rbox((x, 0.0, top - 0.02), (0.6, 0.34, 0.2), must, rot=(0, 0, rr), bevel=0.0)
        K.face_eyes(f, skin, spread=0.5, k=1.0, z=ez + 0.15, out=OUT)
        K.face_brows(f, "#5A3A22", length=0.8, thick=0.18, angle=8, x=0.52, z=ez + 0.85, worried=False, out=OUT, lift=(0.0, 0.06))
        K.face_blush(f, x=0.76, z=ez - 0.25, out=OUT, w=0.36, h=0.22)
        mouth_grin(f, ez - 0.56, 0.6, 0.24, gaps=False)


# --- 5. Robot Sidekick (Rising, Sci-Fi) -------------------------------------------------------


def robot_sidekick(f):
    """Rising (Sci-Fi). A boxy robot buddy: pale steel body and boxy head (costume template: flat screen face
    plate), glowing cyan eyes and smile, blue shoulders and boots, yellow chest dial with LEDs, a claw hand
    waving hello and a sprung antenna with a red bulb."""
    metal, trim, dark, screen = "#C4CBDB", "#2E86DE", "#6E7078", "#1B2340"
    cyan, yel = "#5CF2FF", "#F5B82E"
    RAISE = 0.2
    legs_kid(f, dark, trim, "#1F4E8C", spread=0.5, r=0.3)
    torso(f, metal, w=2.15, d=1.55, h=1.7, z=2.0, taper=0.95, bevel=0.26)
    with f.piece("Body"):
        f.rbox((0, 0, 1.42), (2.0, 1.42, 0.34), dark, bevel=0.1)  # waist joint
        with f.at((0, -0.8, 2.15), (90, 0, 0)):
            f.disc((0, 0, 0), 0.78, 0.78, 0.07, "#8A8F9C", seg=8)  # dial ring
            f.disc((0, 0, 0.05), 0.58, 0.58, 0.07, yel, seg=8)  # chest dial
            f.rbox((0, 0.0, 0.1), (0.1, 0.05, 0.4), "#7A5A10", rot=(0, 0, 30), bevel=0.0)
        for i, c in enumerate(("#E8333A", "#4CC764", "#F5B82E")):
            f.rbox((-0.5 + i * 0.5, -0.8, 1.55), (0.28, 0.07, 0.2), c, bevel=0.0)
        f.rbox((0.0, -0.78, 2.7), (1.3, 0.07, 0.12), "#8A8F9C", bevel=0.0)  # panel line

    def claw(f):
        for s_ in (-1, 1):
            f.rbox((s_ * 0.17, -0.05, -0.28), (0.14, 0.22, 0.46), dark, rot=(0, s_ * -14, 0), bevel=0.03)

    arm(f, 1, trim, dark, rot=(-38, 22, 0), held=claw, shoulder_z=2.5, x=1.3, sleeve_r=0.36)
    arm(f, -1, trim, dark, rot=(0, 136, 0), held=claw, shoulder_z=2.5, x=1.3, sleeve_r=0.36)
    HW, HD, HH, Z0 = 2.7, 2.1, 2.1, HEAD_Z0 + 0.1
    with f.at((0, 0, RAISE)):
        head_box(f, metal, r=0.4, w=HW, d=HD, h=HH, z0=Z0, segs=2)
        zc = Z0 + HH / 2
        with f.piece("Head"):
            f.rbox((0, -HD / 2 - 0.02, zc), (2.12, 0.14, 1.52), screen, bevel=0.14, segs=1)  # screen
            for s_ in (-1, 1):  # ear bolts
                f.rcyl((s_ * (HW / 2 + 0.12), 0.0, zc), 0.42, 0.42, 0.3, trim, rot=(0, 90, 0), seg=8, bevel=0.04)
                f.rcyl((s_ * (HW / 2 + 0.3), 0.0, zc), 0.2, 0.2, 0.1, "#1F4E8C", rot=(0, 90, 0), seg=6, bevel=0.0)
        K.HEAD.update(z0=Z0, h=HH, w=HW, d=HD, r=0.4)
        for s_ in (-1, 1):
            with f.piece("Head"), head_at(f, s_ * 0.5, zc + 0.12, 0.1), f.at((0, 0, 0), (90, 0, 0)):
                f.disc((0, 0, 0.0), 0.5, 0.66, 0.06, cyan, seg=10)  # glowing eye
                f.disc((-0.1, 0.13, 0.05), 0.15, 0.17, 0.04, WHITE, seg=5)
            with f.piece("Head"), head_at(f, s_ * 0.5, zc + 0.62, 0.1):
                f.rbox((0, 0, 0), (0.6, 0.08, 0.15), cyan, rot=(0, s_ * 6, 0), bevel=0.0)  # brow bar
        with f.piece("Head"), head_at(f, 0, zc - 0.5, 0.1):
            for i, (x, z, rr) in enumerate(((-0.36, 0.06, 20), (-0.12, -0.02, 6), (0.12, -0.02, -6), (0.36, 0.06, -20))):
                f.rbox((x, 0, z), (0.28, 0.08, 0.15), cyan, rot=(0, rr, 0), bevel=0.0)  # smile segments
        top = Z0 + HH
        with f.piece("Head"):  # sprung antenna, off to one side
            prof = []
            for i in range(9):
                prof.append((0.2 if i % 2 == 0 else 0.11, i * 0.12))
            f.lathe((0.5, 0.0, top - 0.05), prof, ["#9A9FAC"] * 8, seg=6)
            f.rcyl((0.5, 0, top + 0.0), 0.3, 0.3, 0.14, dark, seg=6, bevel=0.0)
            f.ball((0.5, 0.0, top + 1.28), (0.3, 0.3, 0.3), "#E8333A", seg=7, rings=4)


# --- 6. Commando (Pro, Action) ----------------------------------------------------------------


def commando(f):
    """Pro (Action). Eyepatch, red bandana with tails, chunky olive vest with pockets and a brass bandolier, a
    big bazooka shouldered on one side, scar and a gritted grin."""
    skin, pants, boots = "#C68A5A", "#5B6B3A", "#3A2E22"
    shirt, vest, vest_dk, red = "#6B7A44", "#4A5530", "#3A4426", "#E8333A"
    hair, tube_c, brass = "#2A1A12", "#5B6B3A", "#F5B82E"
    RAISE = 0.25
    legs_kid(f, pants, boots, "#241A14", spread=0.5, r=0.38)
    torso(f, shirt, h=1.7, z=2.0, w=2.05, d=1.5)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (2.1, 1.56, 0.4), pants, bevel=0.1)
        f.rbox((0, 0, 1.62), (2.14, 1.6, 0.14), "#3A2E22", bevel=0.0)  # belt
        f.rbox((0, -0.8, 1.62), (0.4, 0.08, 0.22), brass, bevel=0.0)
        f.rbox((0, -0.1, 2.15), (2.15, 1.58, 1.1), vest, bevel=0.14, segs=1, taper=0.92)  # vest
        for x in (-0.55, 0.0, 0.55):  # pockets
            f.rbox((x, -0.84, 1.9), (0.44, 0.14, 0.5), vest_dk, bevel=0.04, segs=1)
            f.rbox((x, -0.92, 2.1), (0.44, 0.06, 0.1), shade(vest_dk, 0.8), bevel=0.0)
        tube_pts = ((-0.9, -0.82, 2.65), (0.9, -0.82, 1.7))  # bandolier strap
        tube(f, tube_pts[0], tube_pts[1], 0.15, 0.15, "#3A2E22", seg=4)
        for i in range(4):
            t = (i + 0.5) / 4
            p = Vector(tube_pts[0]).lerp(Vector(tube_pts[1]), t)
            f.rcyl((p.x, p.y - 0.1, p.z), 0.11, 0.11, 0.26, brass, seg=5, bevel=0.0)
    # bazooka resting on the actor's left shoulder, muzzle forward: a big dark ring from the front, a long tube in 3/4
    p_rear, p_front = (2.05, 1.2, 3.5), (2.2, -1.25, 3.3)
    with f.piece("Body"):
        tube(f, p_rear, p_front, 0.4, 0.4, tube_c, seg=8, bevel=0.0)
        tube(f, (p_front[0], p_front[1] - 0.05, p_front[2]), (p_front[0] + 0.02, p_front[1] - 0.45, p_front[2] - 0.02), 0.58, 0.5, "#2A2E1E", seg=8)  # muzzle
        tube(f, (p_rear[0], p_rear[1], p_rear[2]), (p_rear[0] - 0.02, p_rear[1] + 0.4, p_rear[2] + 0.02), 0.5, 0.64, "#2A2E1E", seg=8)  # rear flare
        f.rbox((2.1, -0.1, 4.0), (0.22, 0.8, 0.16), brass, bevel=0.0)  # sight
        f.rbox((2.1, 0.5, 3.0), (0.2, 0.2, 0.5), "#3A2E22", bevel=0.0)  # grip
        f.rbox((2.2, -0.9, 3.35), (0.84, 0.16, 0.14), red, bevel=0.0)  # red warning stripe
    arm(f, 1, shirt, skin, rot=(-22, 110, 0), shoulder_z=2.55, x=1.2, sleeve_r=0.36)
    arm(f, -1, shirt, skin, rot=(-16, 16, 0), shoulder_z=2.55, x=1.2, sleeve_r=0.36)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        eye1(f, skin, 0.6, ez, k=1.0)
        # eyepatch over the actor's right eye (-X) with a short strap to the side of the head
        with f.piece("Head"):
            head_patch(f, -0.6, ez, 0.33, 0.39, 0.1, "#161220", seg=8, rings=1)
            with head_at(f, -1.0, ez + 0.2, 0.0):
                f.rbox((0, 0, 0), (0.6, 0.07, 0.12), "#161220", rot=(0, -28, 0), bevel=0.0)
        brow1(f, "#241710", 0.62, ez + 0.66, 1.0, 0.24, angle=-14)  # a fierce brow
        brow1(f, "#241710", -0.62, ez + 0.76, 0.9, 0.24, angle=14)
        K.face_blush(f, x=0.9, z=ez - 0.34, seg=6)
        mouth_grin(f, ez - 0.74, 0.64, 0.26)
        with f.piece("Head"):
            with head_at(f, -0.95, ez - 0.55, 0.04):  # scar
                f.rbox((0, 0, 0), (0.07, 0.05, 0.62), "#E4B890", rot=(0, 24, 0), bevel=0.0)
                for z_ in (-0.15, 0.1):
                    f.rbox((0, 0, z_), (0.3, 0.05, 0.06), "#E4B890", rot=(0, 24, 0), bevel=0.0)
            # short dark hair peeking above a red bandana, knot and two tails at the back
            f.ball((0, 0.12, top + 0.02), (1.2, 1.0, 0.62), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            f.rcyl((0, 0.02, 4.48), 1.24, 1.14, 0.42, red, seg=10, squash=0.9, bevel=0.0)  # bandana band
            with f.at((0.0, 1.0, 4.5)):
                f.ball((0, 0, 0), (0.34, 0.24, 0.3), red, seg=6, rings=3)  # knot
                for s_ in (-1, 1):
                    f.leaf((s_ * 0.1, 0.15, 0.0), (140, s_ * 30, 0), 1.25, 0.45, 0.09, red, tip=0.4)


# --- 7. Ventriloquist (Pro, Comedy) -----------------------------------------------------------


def ventriloquist(f):
    """Pro (Comedy). A ventriloquist and her cheeky dummy, who gets all the laughs: warm frozen smile, afro
    puffs with a gold-banded high bun, blue blazer with white shirt and gold bow tie; the dummy (red suit,
    hinged jaw dropped, tiny top hat) sits on her raised arm."""
    skin, hair, hair_lt = "#5A3420", "#2A1E16", "#4A362A"
    blue, navy, shoe, gold, white = "#2E86DE", "#1B2340", "#2E2C34", "#F5B82E", "#FAF6EC"
    RAISE = 0.3
    legs_kid(f, navy, shoe, "#16161C")
    torso(f, blue, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), navy, bevel=0.1)
        f.rbox((0, 0, 1.62), (1.94, 1.46, 0.12), "#16161C", bevel=0.0)
        f.rbox((0, -0.69, 2.2), (0.62, 0.08, 1.2), white, bevel=0.0, taper=1.6)  # shirt V
        for s_ in (-1, 1):  # lapels
            f.rbox((s_ * 0.5, -0.7, 2.28), (0.34, 0.08, 1.15), shade(blue, 0.8), rot=(0, s_ * 16, 0), bevel=0.0)
        for s_ in (-1, 1):  # gold bow tie
            f.spike((s_ * 0.06, -0.78, 2.78), 0.2, 0.34, gold, rot=(0, s_ * 90, 0), seg=4, squash=0.5)
        f.ball((0, -0.8, 2.78), (0.14, 0.1, 0.14), shade(gold, 0.8), seg=5, rings=3)
        f.rbox((0.55, -0.72, 2.25), (0.22, 0.07, 0.2), white, rot=(0, 0, 8), bevel=0.0)  # pocket square

    def dummy(f):
        """The dummy, standing on the hand (world-upright), facing her."""
        pale, wood, suit, hat = "#F7D2B5", "#C99568", "#C8202F", "#2E2C34"
        with f.at((0, -0.05, 0.0), (0, 0, -18)):
            f.rbox((0, 0, 0.55), (1.0, 0.72, 0.95), suit, bevel=0.0)  # little red suit body
            f.rbox((0, -0.37, 0.62), (0.3, 0.05, 0.6), white, bevel=0.0, taper=1.7)
            f.rbox((0, -0.4, 0.88), (0.34, 0.06, 0.14), gold, bevel=0.0)  # bow tie
            for s_ in (-1, 1):  # dangling legs and shoes
                f.rcyl((s_ * 0.24, -0.12, -0.2), 0.12, 0.12, 0.7, hat, rot=(-22, 0, 0), seg=5, bevel=0.0)
                f.rbox((s_ * 0.24, -0.34, -0.5), (0.3, 0.46, 0.2), "#16161C", bevel=0.0)
            f.rbox((0, -0.05, 1.62), (1.6, 1.2, 1.35), pale, bevel=0.24, segs=1)  # big head
            f.rbox((0, -0.08, 0.98), (1.18, 1.0, 0.3), shade(pale, 0.9), bevel=0.08, segs=1)  # jaw dropped open
            f.rbox((0, -0.62, 1.12), (0.82, 0.06, 0.24), "#7A2836", bevel=0.0)  # open mouth
            with f.at((0, -0.7, 1.7), (90, 0, 0)):
                for s_ in (-1, 1):
                    f.disc((s_ * 0.38, 0.0, 0.0), 0.44, 0.52, 0.05, WHITE, seg=7)
                    f.disc((s_ * 0.38, -0.02, 0.04), 0.24, 0.32, 0.05, EYE_DARK, seg=7)
                    f.disc((s_ * 0.38 - 0.05, 0.07, 0.07), 0.09, 0.1, 0.04, WHITE, seg=4)
                    f.disc((s_ * 0.5, -0.3, 0.0), 0.32, 0.2, 0.05, "#F08A8A", seg=6)
            f.rbox((0, -0.5, 2.18), (1.4, 0.3, 0.14), "#A06830", bevel=0.0)  # painted hair
            f.ball((0, 0.1, 2.28), (0.9, 0.6, 0.3), "#A06830", seg=6, rings=3)
            with f.at((0.28, 0.0, 2.45), (0, 14, 0)):  # tiny top hat
                f.rcyl((0, 0, 0.0), 0.62, 0.62, 0.1, hat, seg=8, bevel=0.0)
                f.rcyl((0, 0, 0.3), 0.36, 0.34, 0.5, hat, seg=8, bevel=0.0)
                f.rcyl((0, 0, 0.14), 0.37, 0.37, 0.12, gold, seg=8, bevel=0.0)

    arm(f, -1, blue, skin, rot=(-24, 64, 0), held=dummy, upright=True, shoulder_z=2.55, x=1.1, sleeve_r=0.34)
    arm(f, 1, blue, skin, rot=(-30, 40, 0), shoulder_z=2.55, x=1.1, sleeve_r=0.34)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        K.face_eyes(f, skin, spread=0.6, z=ez)
        K.face_brows(f, "#1E1612", length=0.95, thick=0.2, angle=8, x=0.62, z=ez + 0.72, worried=False, lift=(0.0, 0.1))
        K.face_blush(f, x=0.92, z=ez - 0.34, seg=6, color="#D87068")
        with f.piece("Head"):  # frozen, perfectly still closed smile
            head_patch(f, 0, ez - 0.76, 0.52, 0.1, 0.05, "#6E2431", seg=8, rings=1)
            for s_ in (-1, 1):  # smile creases
                with head_at(f, s_ * 0.62, ez - 0.6, 0.04):
                    f.rbox((0, 0, 0), (0.07, 0.05, 0.22), shade(skin, 0.7), rot=(0, s_ * -20, 0), bevel=0.0)
        with f.piece("Head"):
            f.ball((0, 0.12, top - 0.28), (1.3, 1.03, 0.62), hair, seg=8, rings=5)
            f.ball((0, 0.62, top - 1.2), (1.28, 0.95, 1.25), hair, seg=8, rings=5)
            f.ball((0, 0.3, top + 0.0), (0.9, 0.8, 0.5), hair_lt, seg=7, rings=4)  # raised crown
            for s_ in (-1, 1):  # two soft puffs at the ears
                f.ball((s_ * 1.3, 0.3, top - 1.05), (0.5, 0.55, 0.62), hair_lt, seg=6, rings=3)
            f.ball((0, 0.3, top + 0.75), (0.68, 0.64, 0.68), hair, seg=7, rings=4)  # high bun
            f.rcyl((0, 0.3, top + 0.3), 0.74, 0.7, 0.16, gold, seg=8, bevel=0.0)  # hair band


# Names are the in-game actor ids (src/shared/Actors.luau), so the FBX pieces drop straight into LotMeshes.
BUILDS = {
    "stunt": ("StuntDouble", "Newcomer", stunt_double),
    "zombie": ("BackgroundExtra", "Newcomer", zombie_extra),
    "soap": ("SoapRegular", "Rising", soap_star),
    "hotdog": ("AdModel", "Rising", hotdog_mascot),
    "robot": ("IndieSidekick", "Rising", robot_sidekick),
    "commando": ("ActionVeteran", "Pro", commando),
    "vent": ("ComedyDuo", "Pro", ventriloquist),
}
K.ACTORS.update(BUILDS)
B1_KEYS = tuple(BUILDS)
OLD_FN = {  # the in-game versions (art/blender/actors.py)
    "stunt": "stunt_double",
    "zombie": "zombie_extra",
    "soap": "soap_star",
    "hotdog": "hotdog_mascot",
    "robot": "robot_sidekick",
    "commando": "commando",
    "vent": "ventriloquist",
}
APPROVED = ("intern", "pup", "squawk")
LINEUP = ("intern", "pup", "stunt", "zombie", "soap", "hotdog", "robot", "commando", "vent", "squawk")
OUT = K.OUT_DIR


def build_all(ao=True):
    """All seven batch-1 actors plus the three approved ones (for the lineup), one scene, one AO bake."""
    keys = list(APPROVED) + list(B1_KEYS)
    sc, built, report = K.main(tuple(keys))
    return sc, built, report


def objs_of(built, key):
    return list(built[key][1].values())


def render_one(sc, built, key, res=720):
    """Sheet + views + FBX for one actor (files actors_v2_b1_<key>_*)."""
    ol = objs_of(built, key)
    K.floor_for(sc, x=0)
    paths = K.render_set(sc, key, ol, f"b1_{key}", res=res)
    old = {o: o.location.copy() for o in ol}
    for o in ol:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    K.export_fbx(ol, os.path.join(OUT, f"actors_v2_b1_{key}.fbx"))
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
        p = K.shoot(sc, both, f"/tmp/b1_cmp_{key}_{name}.png", az=az, el=el, res=res, hide_others=False, margin=1.25, lens=120, samples=40)
        tiles.append(K.load_img(p))
    for o in oo.values():
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    out = os.path.join(OUT, f"actors_v2_b1_{key}_compare.png")
    K.save_img(K.hstack(tiles, pad=8), out)
    return out


def lineup(sc, built, path=None, res=360):
    """All ten side by side (two rows of five, same camera scale). The three approved actors get a green bar."""
    path = path or os.path.join(OUT, "actors_v2_b1_lineup.png")
    tiles = []
    for key in LINEUP:
        ol = objs_of(built, key)
        x = ol[0].location.x
        ctr = Vector((x, 0, 3.0 * K.STUD))
        t = K.load_img(K.shoot(sc, ol, f"/tmp/b1_lu_{key}.png", az=22, el=12, res=res, center=ctr, radius=5.0 * K.STUD, margin=1.0, samples=32, lens=70))
        t[:10, :, :3] = np.array(K.lin("#4CC764")[:3] if key in APPROVED else K.lin("#E9E4D8")[:3])
        tiles.append(t)
    K.save_img(K.vstack([K.hstack(tiles[:5], pad=4), K.hstack(tiles[5:], pad=4)], pad=4), path)
    return path


def silhouettes(sc, built, path=None):
    path = path or os.path.join(OUT, "actors_v2_b1_silhouettes_64.png")
    K.silhouette_strip(sc, [objs_of(built, k) for k in LINEUP], path)
    return path
