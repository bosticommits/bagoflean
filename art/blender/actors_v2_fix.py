"""Actors v2, approval fixes for three actors (user notes from the Command Center, 2026-11-14):

  Hot Dog Mascot   (b1) - taller and slimmer like the in-game original, ONE clean face-opening rim, better
                          bun / sausage / mustard shapes (two variants built side by side: hotdogA, hotdogB)
  Teen Heartthrob  (b2) - the scribbly wink (arc built from three stacked boxes + brow) redone as one smooth bold arch
  Brain in a Jar   (b3) - smaller pink brain head, and a real glass dome shell (pale cyan panels, a front window,
                          highlight strips) instead of cage hoops + side electrodes (which read as headphones)

Each fixed actor replaces the old function under the same game id; the old versions stay in actors_v2_b1/b2/b3.py
(keys hotdog_old / heart_old / brain_old are built from them for the compare sheets). finalize_fix() builds,
QAs, renders everything and exports the draft FBX files (1/28). Taste rules: vault `Movie Mogul/Actor References.md`.
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
from actors_v2 import EYE_DARK, EYE_Z, HEAD_Z0, head_at, head_box, head_patch, head_ring, legs_kid, arm, shade, mix, torso  # noqa: E402
import actors_v2_b1 as B1  # noqa: E402
from actors_v2_b1 import MOUTH, PINK, WHITE, along, brow1, dome, ears, eye1, mouth_grin, mouth_o, tube  # noqa: E402
import actors_v2_b2 as B2  # noqa: E402
import actors_v2_b3 as B3  # noqa: E402
import actors_v2_b4 as B4  # noqa: E402
from actors_v2_b2 import heart, sparkle  # noqa: E402

GOLD = "#F5B82E"
OUT = K.OUT_DIR


# --- 1. Hot Dog Mascot (Rising, Comedy) -------------------------------------------------------

HD_CFG = {
    # head (w, d, h, z0) | sausage body half-width/depth | bun centre x, half-width, depth, z0, z1 | face plate rx, rz, centre z
    "A": dict(head=(2.55, 2.2, 2.8, 3.3), body=(1.1, 0.95), bun=(1.45, 0.52, 0.9, 1.5, 5.3), face=(1.06, 0.98, 4.65), tip=True, swing=18),
    "B": dict(head=(2.7, 2.35, 2.8, 3.05), body=(0.98, 0.88), bun=(1.3, 0.46, 0.8, 1.5, 4.7), face=(1.12, 1.02, 4.5), tip=False, swing=14),
}


def hotdog_fix(f, v="A"):
    """Rising (Comedy). Tall slim hot dog costume (in-game proportions): a sausage that is body and head in one
    pill, two tall bun halves hugging it (pale inside), a single clean rim round the skin face opening, a
    mustard squiggle, white gloves and the sign."""
    cfg = HD_CFG[v]
    skin, bun, bun_in, saus, saus_lt = "#F0C49C", "#E8A85A", "#F8DDA0", "#C8502F", "#E27A48"
    must = "#FFD21A"
    hw, hd, hh, z0 = cfg["head"]
    bsx, bsy = cfg["body"]
    bx, bhw, bhd, bz0, bz1 = cfg["bun"]
    frx, frz, ez = cfg["face"]
    legs_kid(f, "#C8202F", "#FAF6EC", "#B8B2A4", spread=0.5)
    with f.piece("Body"):
        # sausage body: a capsule from just above the boots up under the head
        prof = [(0.0, 1.22), (0.55, 1.27), (0.86, 1.42), (1.0, 1.7), (1.0, z0 + 0.5)]
        f.lathe((0, 0, 0), prof, [shade(saus, 0.8), shade(saus, 0.9), saus, saus], seg=12, scale=(bsx, bsy, 1.0))

        def bun_col(s_):
            def c(face):
                if face.normal.x * s_ < -0.5:
                    return bun_in
                return shade(bun, 1.1) if face.normal.z > 0.5 else (shade(bun, 0.8) if face.normal.z < -0.5 else bun)

            return c

        L = bz1 - bz0
        bprof = [(0.0, 0.0), (0.55, 0.03), (0.88, 0.12), (1.0, 0.3), (1.0, 0.7), (0.88, 0.88), (0.55, 0.97), (0.0, 1.0)]
        for s_ in (-1, 1):  # bun halves: soft capsules, pale inside faces the sausage
            f.lathe((s_ * bx, 0.12, bz0), bprof, bun_col(s_), seg=10, scale=(bhw, bhd, L))
        # mustard squiggle down the sausage belly, one smooth swept tube hugging the surface
        pts = []
        N = 17
        for i in range(N):
            t = i / (N - 1)
            x = 0.5 * math.sin(t * math.pi * 3.0) * (1 - 0.0 * t)
            z = 3.15 - t * 1.45
            y = -bsy * math.sqrt(max(1 - (x / bsx) ** 2, 0.0)) - 0.03
            pts.append((x, y, z))
        B4.sweep(f, pts, [0.06 if i in (0, N - 1) else 0.14 for i in range(N)], must, seg=5, squash=0.7)

    def sign(f):
        f.rcyl((0, -0.1, 0.8), 0.07, 0.07, 1.9, "#96623C", seg=5, bevel=0.0)
        with f.at((0.0, -0.12, 2.0)):
            f.rbox((0, 0, 0), (1.15, 0.1, 0.9), "#FAF6EC", bevel=0.05, segs=1)
            f.rbox((0, -0.07, 0.2), (0.95, 0.05, 0.25), "#C8202F", bevel=0.0)
            for i in range(3):
                f.rbox((-0.31 + i * 0.31, -0.07, -0.17), (0.34, 0.05, 0.1), must, rot=(0, (-1) ** i * 28, 0), bevel=0.0)

    sh = z0 + 0.15
    arm(f, 1, bun, "#FAF6EC", rot=(-8, cfg["swing"], 0), held=sign, upright=True, shoulder_z=sh, x=bx + bhw - 0.1, sleeve_r=0.3)
    arm(f, -1, bun, "#FAF6EC", rot=(-12, cfg["swing"] - 4, 0), shoulder_z=sh, x=bx + bhw - 0.1, sleeve_r=0.3)
    head_box(f, saus, r=min(1.0, hw * 0.42), w=hw, d=hd, h=hh, z0=z0, segs=2)  # the sausage end: a round pill
    top = z0 + hh
    with f.piece("Head"):
        if cfg["tip"]:  # the twisted sausage tip on top
            f.spike((0, 0.0, top - 0.12), 0.3, 0.62, shade(saus, 0.85), seg=6)
        # the opening: a skin plate, then ONE rim ring that sits exactly on its edge (hides the plate wall)
        head_patch(f, 0, ez, frx, frz, 0.05, skin, seg=16, rings=2)
        K.head_ring(f, 0, ez, frx + 0.02, frz + 0.02, 0.1, 0.03, saus_lt, major=20, minor=4)
    K.face_eyes(f, skin, spread=0.5, k=1.05, z=ez + 0.1, out=0.04, socket=False)
    K.face_brows(f, "#5A3A22", length=0.72, thick=0.17, angle=8, x=0.5, z=ez + 0.68, worried=False, out=0.04, lift=(0.0, 0.06))
    K.face_blush(f, x=0.8, z=ez - 0.25, out=0.04, w=0.34, h=0.22)
    mouth_grin(f, ez - 0.56, 0.58, 0.24, gaps=False)


def hotdog_fixA(f):
    hotdog_fix(f, "A")


def hotdog_fixB(f):
    hotdog_fix(f, "B")


# --- 2. Teen Heartthrob (Star, Romance) -------------------------------------------------------


def wink_eye(f, cx, cz, w=0.84, h=0.34, color="#161220"):
    """A closed happy eye: one smooth bold arch (a swept tube, thick in the middle, tapered ends) lying on the
    head surface, clear of the brow."""
    pts, rad = [], []
    N = 9
    for i in range(N):
        t = -1 + 2 * i / (N - 1)
        x, z = cx + t * w / 2, cz + h * (1 - t * t)
        y, _, _ = K.head_surf(x, z)
        n = K.head_normal(x, z)
        pts.append(tuple(Vector((x, y, z)) + n * 0.03))
        rad.append(0.065 + 0.085 * (1 - t * t))
    with f.piece("Head"):
        B4.sweep(f, pts, rad, color, seg=5, squash=0.6)


def heartthrob_fix(f):
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
        wink_eye(f, -0.6, ez - 0.12)  # winking eye: ONE smooth bold arch (no stacked boxes), well clear of the brow
        K.face_brows(f, "#161220", length=0.95, thick=0.22, angle=8, x=0.62, z=ez + 0.72, worried=False, lift=(0.12, 0.0))
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


# --- 3. Brain in a Jar (Legend, Sci-Fi) -------------------------------------------------------

GLASS_BANDS = ("#6FDDEF", "#86E6F4", "#A0EEF9", "#BDF5FC", "#D6FAFF")  # pale cyan, lighter towards the top
GLASS_EDGE, GLASS_GLINT = "#4FDDEE", "#FFFFFF"


def glass_dome(f, ctr, rx, ry, rz, t=0.12, cols=16, elev=(0, 22, 42, 60, 76), window=None, streaks=()):
    """A thin glass dome shell (half an ellipsoid, outer + inner wall, closed edges) in pale cyan panels, with an
    optional front window (half-angle deg, last band index) and white highlight strips (list of (column, band)).
    Vertex colours only: the 'glass' is the lighter-than-everything panel colour, the white glints and the
    saturated cut edge."""
    bm = bmesh.new()
    R = len(elev)
    ang = [2 * math.pi * i / cols for i in range(cols)]

    def ring(rx_, ry_, rz_):
        rows = []
        for e in elev:
            ce, se = math.cos(math.radians(e)), math.sin(math.radians(e))
            rows.append([bm.verts.new((ctr[0] + rx_ * math.cos(a) * ce, ctr[1] + ry_ * math.sin(a) * ce, ctr[2] + rz_ * se)) for a in ang])
        return rows, bm.verts.new((ctr[0], ctr[1], ctr[2] + rz_))

    O, Op = ring(rx, ry, rz)
    I, Ip = ring(rx - t, ry - t, rz - t)

    def present(k, i):
        if k < 0 or k >= R:
            return False
        if window:
            half, kmax = window
            c = math.degrees(ang[i] + math.pi / cols)  # cell centre azimuth (deg from +X)
            d = abs(((c - 270 + 180) % 360) - 180)  # distance from the front (-Y)
            if d <= half and k <= kmax:
                return False
        return True

    def cell_verts(W, Wp, k, i):
        j = (i + 1) % cols
        if k < R - 1:
            return [W[k][i], W[k][j], W[k + 1][j], W[k + 1][i]]
        return [W[k][i], W[k][j], Wp]

    def mk(vs, mi):
        try:
            fc = bm.faces.new(vs)
            fc.material_index = mi
        except ValueError:
            pass

    for k in range(R):
        for i in range(cols):
            if not present(k, i):
                continue
            mi = k * 3 + (2 if (i, k) in streaks else (1 if i % 2 else 0))
            mk(cell_verts(O, Op, k, i), mi)
            mk(cell_verts(I, Ip, k, i)[::-1], mi)
    # edge strips where a present cell meets an absent one (and the open bottom rim)
    for k in range(R):
        for i in range(cols):
            if not present(k, i):
                continue
            j = (i + 1) % cols
            if not present(k - 1, i):  # bottom edge of the cell
                mk([O[k][i], O[k][j], I[k][j], I[k][i]], 100)
            if k < R - 1 and not present(k + 1, i):  # top edge
                mk([O[k + 1][i], I[k + 1][i], I[k + 1][j], O[k + 1][j]], 100)
            if not present(k, (i - 1) % cols):  # left edge
                if k < R - 1:
                    mk([O[k][i], I[k][i], I[k + 1][i], O[k + 1][i]], 100)
                else:
                    mk([O[k][i], I[k][i], Ip, Op], 100)
            if not present(k, j):  # right edge
                if k < R - 1:
                    mk([O[k][j], O[k + 1][j], I[k + 1][j], I[k][j]], 100)
                else:
                    mk([O[k][j], Op, Ip, I[k][j]], 100)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")  # window-interior grid verts

    def col(face):
        m = face.material_index
        if m == 100:
            return GLASS_EDGE
        k, kind = divmod(m, 3)
        return GLASS_GLINT if kind == 2 else (shade(GLASS_BANDS[k], 1.0) if kind == 0 else mix(GLASS_BANDS[k], "#FFFFFF", 0.3))

    f._place(bm, (0, 0, 0), (0, 0, 0), col)


def brain_fix(f, win=(58, 2), streaks=((8, 0), (8, 1), (8, 2), (8, 3), (9, 3), (14, 1), (14, 2), (14, 3), (3, 2), (3, 3)), s=0.78):
    """Legend (Sci-Fi). A glowing pink brain (smaller head) inside a glass dome (pale cyan panels, front window,
    white glints, saturated cut edge, jar rim on the orange tray) on a steel jar-base body with a heartbeat
    screen; orange boots, one claw holding an idea bulb, the other waving."""
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

    arm(f, -1, metal, dark, rot=(-20, 52, 0), held=bulb, upright=True, shoulder_z=2.5, x=1.4, sleeve_r=0.36)
    arm(f, 1, metal, dark, rot=(0, 76, 0), held=claw, shoulder_z=2.5, x=1.4, sleeve_r=0.36)
    HW, HD, HH, Z0 = 3.3 * s, 2.6 * s, 2.4 * s, HEAD_Z0 + 0.4
    with f.at((0, 0, RAISE)):
        head_box(f, brain, r=1.1 * s, w=HW, d=HD, h=HH, z0=Z0, segs=2)
        top = Z0 + HH
        zc = Z0 + HH / 2
        ez = Z0 + 0.45 * HH
        zc_old, top_old = Z0 + 1.2, Z0 + 2.4
        lobes = ((-0.85, 0.0, top_old - 0.05, 0.95, brain_lt), (0.85, 0.0, top_old - 0.05, 0.95, brain_dk), (0.0, 0.7, top_old - 0.2, 0.85, brain),
                 (-1.7, 0.1, top_old - 0.65, 0.8, brain_dk), (1.7, 0.1, top_old - 0.65, 0.8, brain_lt),
                 (-1.85, 0.3, zc_old - 0.25, 0.62, brain), (1.85, 0.3, zc_old - 0.25, 0.62, brain_dk),
                 (0.0, 1.1, zc_old + 0.3, 0.8, brain_dk), (-0.8, 0.9, zc_old + 0.9, 0.55, brain_lt), (0.8, 0.9, zc_old + 0.9, 0.55, brain_lt))
        with f.piece("Head"):  # lumpy lobes (same layout as before, all scaled down round the head centre)
            for x, y, z, r, c in lobes:
                f.ball((x * s, y * s, zc + (z - zc_old) * s), (r * s, r * s, r * s * 0.9), c, seg=7, rings=4)
        K.face_eyes(f, shade(brain, 0.9), spread=0.6, k=1.0, z=ez, color="#241410")
        K.face_brows(f, "#7A1F44", length=0.95, thick=0.22, angle=14, x=0.62, z=ez + 0.68, worried=False, lift=(0.0, 0.16))  # one raised: smug
        K.face_blush(f, color="#FF5A78", x=1.0, z=ez - 0.28, w=0.36, h=0.24)
        with f.piece("Head"):  # a lopsided know-it-all smirk
            with head_at(f, 0.12, ez - 0.62, 0.05):
                f.rbox((0, 0, 0), (0.78, 0.08, 0.16), "#7A1F44", rot=(0, -9, 0), bevel=0.0)
                f.rbox((0.43, 0, 0.1), (0.18, 0.08, 0.18), "#7A1F44", rot=(0, -40, 0), bevel=0.0)
        base = (0, 0, Z0 - 0.15)
        dh = top - Z0 + 0.45 * s + 0.35  # dome height above its base
        with f.piece("Head"):
            glass_dome(f, base, 2.5, 1.78, 3.45, t=0.12, window=win, streaks=streaks)
            f.torus((0, 0, Z0 - 0.15), 2.5, 0.17, "#8FEFFA", rot=(90, 0, 0), major=14, minor=4, sx=1.0, sz=0.71)  # jar rim
            f.rcyl((0, 0, base[2] + 3.45 + 0.05), 0.24, 0.32, 0.3, "#6E7078", seg=6, bevel=0.0)  # lid knob
            f.ball((0, 0, base[2] + 3.45 + 0.42), (0.27, 0.27, 0.27), cyan, seg=6, rings=3)
    B3.stars(f, ((-2.3, 0.0, 6.9), (2.3, 0.0, 7.3)), cyan, 0.9)


# --- registry, renders, compares --------------------------------------------------------------

BUILDS = {
    "hotdog": ("AdModel", "Rising", hotdog_fixA),
    "hotdogA": ("AdModel", "Rising", hotdog_fixA),
    "hotdogB": ("AdModel", "Rising", hotdog_fixB),
    "heart": ("TeenHeartthrob", "Star", heartthrob_fix),
    "brain": ("SciFiVisionary", "Legend", brain_fix),
    # the drafts being replaced, rebuilt from their own scripts for the compare sheets
    "hotdog_old": ("AdModel", "Rising", B1.hotdog_mascot),
    "heart_old": ("TeenHeartthrob", "Star", B2.heartthrob),
    "brain_old": ("SciFiVisionary", "Legend", B3.brain_jar),
}
K.ACTORS.update(BUILDS)
FIXED = ("hotdog", "heart", "brain")
OLDKEY = {"hotdog": "hotdog_old", "heart": "heart_old", "brain": "brain_old", "hotdogA": "hotdog_old", "hotdogB": "hotdog_old"}
APPROVED = ("intern", "pup", "squawk")
CAPS = {"Rising": 1900, "Star": 2200, "Legend": 2500}
STATE = {}


def build_all(keys):
    sc, built, report = K.main(tuple(keys))
    STATE.update(sc=sc, built=built, report=report)
    return sc, built, report


def objs_of(built, key):
    return list(built[key][1].values())


def quick(keys, res=520, tag="fq", views=((0, 12), (38, 16), (180, 12))):
    """Fast iteration: rebuild, one PNG per actor in /tmp (front | 3/4 | back), tri counts printed."""
    sc, built, report = build_all(keys)
    outs = []
    for key in keys:
        f, objs = built[key]
        ol = list(objs.values())
        shots = [K.load_img(K.shoot(sc, ol, f"/tmp/{tag}_{i}.png", az=az, el=el, res=res, margin=1.3, samples=24)) for i, (az, el) in enumerate(views)]
        out = f"/tmp/{tag}_{key}.png"
        K.save_img(K.hstack(shots, pad=4), out)
        by = {}
        for p, k_, t in f.log:
            by[p] = by.get(p, 0) + t
        print(key, "tris", report[key]["tris"], by, "size", report[key]["size_studs"], "xr", report[key]["x_range"])
        outs.append(out)
    return sc, built, outs


def render_one(sc, built, key, res=720):
    """Sheet + views + FBX for one fixed actor (files actors_v2_fix_<key>_*)."""
    ol = objs_of(built, key)
    K.floor_for(sc, x=0)
    paths = K.render_set(sc, key, ol, f"fix_{key}", res=res)
    old = {o: o.location.copy() for o in ol}
    for o in ol:
        o.location = (0, 0, 0)
    bpy.context.view_layer.update()
    K.export_fbx(ol, os.path.join(OUT, f"actors_v2_fix_{key}.fbx"))
    for o, l in old.items():
        o.location = l
    bpy.context.view_layer.update()
    return paths


def compare_one(sc, built, key, old_key=None, res=900, gap=7.0, path=None, views=(("front", 0, 18), ("34", 32, 20))):
    """Current draft (left) next to the fixed one (right), front and 3/4, same light and camera."""
    old_key = old_key or OLDKEY[key]
    new_objs, old_objs = objs_of(built, key), objs_of(built, old_key)
    shift = (new_objs[0].location.x - old_objs[0].location.x) - gap * K.STUD
    for o in old_objs:
        o.location.x += shift
    both = old_objs + new_objs
    tiles = [K.load_img(K.shoot(sc, both, f"/tmp/fix_cmp_{key}_{nm}.png", az=az, el=el, res=res, hide_others=True, margin=1.25, lens=120, samples=40)) for nm, az, el in views]
    for o in old_objs:
        o.location.x -= shift
    out = path or os.path.join(OUT, f"actors_v2_fix_{key}_compare.png")
    K.save_img(K.hstack(tiles, pad=8), out)
    return out


def lineup(sc, built, keys, path=None, res=360):
    """The fixed actors (grey bar) next to the approved Intern / Pup / Squawk (green bar), one row."""
    path = path or os.path.join(OUT, "actors_v2_fix_lineup.png")
    tiles = []
    for key in keys:
        ol = objs_of(built, key)
        x = ol[0].location.x
        ctr = Vector((x, 0, 3.6 * K.STUD))
        t = K.load_img(K.shoot(sc, ol, f"/tmp/fix_lu_{key}.png", az=22, el=12, res=res, center=ctr, radius=6.2 * K.STUD, margin=1.0, samples=32, lens=70))
        t[:10, :, :3] = np.array(K.lin("#4CC764")[:3] if key in APPROVED else K.lin("#E9E4D8")[:3])
        tiles.append(t)
    K.save_img(K.hstack(tiles, pad=4), path)
    return path


def silhouettes(sc, built, keys, path=None):
    path = path or os.path.join(OUT, "actors_v2_fix_silhouettes_64.png")
    K.silhouette_strip(sc, [objs_of(built, k) for k in keys], path)
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


def finalize_fix(hotdog="hotdog", render=True):
    """Build the three fixed actors + the approved three (+ the old drafts for the compares), QA, render, export."""
    keys = list(FIXED) + [OLDKEY[k] for k in FIXED] + list(APPROVED)
    sc, built, report = build_all(keys)
    out = {"qa": {k: report[k] for k in FIXED}}
    for k in FIXED:
        out["gate_" + k] = run_qa_gate(built, k)
    if not render:
        return sc, built, out
    for k in FIXED:
        out[k] = render_one(sc, built, k)
        compare_one(sc, built, k)
    order = list(FIXED) + list(APPROVED)
    lineup(sc, built, order)
    silhouettes(sc, built, order)
    return sc, built, out


def hotdog_variants(res=700):
    """Current draft | variant A (picked: tall slim, hood tip) | variant B (big-head hooded kid), front + 3/4."""
    sc, built, _ = build_all(["hotdog_old", "hotdogA", "hotdogB"])
    K.floor_for(sc, x=0)
    objs = [objs_of(built, k) for k in ("hotdog_old", "hotdogA", "hotdogB")]
    base = objs[0][0].location.x
    for i, ol in enumerate(objs):  # line them up 8 studs apart for one shot
        shift = base + i * 8 * K.STUD - ol[0].location.x
        for o in ol:
            o.location.x += shift
    allo = [o for ol in objs for o in ol]
    tiles = [K.load_img(K.shoot(sc, allo, f"/tmp/hdv_{n}.png", az=az, el=el, res=res, hide_others=True, margin=1.0, lens=120, samples=40, center=Vector((objs[1][0].location.x, 0, 3.0 * K.STUD)), radius=13.5 * K.STUD)) for n, az, el in (("f", 0, 14), ("t", 28, 18))]
    out = os.path.join(OUT, "actors_v2_fix_hotdog_variants.png")
    K.save_img(K.vstack(tiles, pad=8), out)
    return out
