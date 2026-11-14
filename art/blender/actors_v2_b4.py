"""Actors v2, batch 4 = the 7 NEW actors (design: docs/design/actors-v2.md, PR #150), built to the approved
style bible (Nervous Intern A, Werewolf Pup, Captain Squawk + batches 1-3). Same kit (actors_v2.py): pill head
with face parts on its surface, two-segment bevels, vertex-colour AO, tier plinth.

  Cardboard Astronaut (Newcomer, Sci-Fi) - Rodeo Rookie, Wobbly Witch (Rising, Action/Horror)
  Lagoon Mermaid, Time Tourist (Pro, Romance/Sci-Fi) - Captain Kapow, Inspector Whoops (Star, Action/Comedy)

Run live (MCP for Blender): finalize_b4() builds, QAs, renders everything and exports the draft FBX files (1/28).
Taste rules: vault `Movie Mogul/Actor References.md`. Tri caps: Newcomer/Rising 1,900, Pro 2,000, Star 2,200
(decided 2026-11-14). Width <= 4.6 (prop-heavy/winged <= 5.8), depth <= 3.9.
"""

import math
import os
import sys
from contextlib import ExitStack

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import actors_v2 as K  # noqa: E402
from actors_v2 import EYE_DARK, EYE_Z, HEAD_Z0, head_at, head_box, head_patch, head_ring, legs_kid, arm, shade, mix, torso  # noqa: E402
from actors_v2_b1 import MOUTH, PINK, WHITE, along, brow1, dome, ears, eye1, tube  # noqa: E402
import actors_v2_b2 as B2  # noqa: E402
import actors_v2_b3 as B3  # noqa: E402
from actors_v2_b2 import heart, sparkle  # noqa: E402

GOLD = "#F5B82E"


# --- shared helpers ---------------------------------------------------------------------------


def sweep(f, pts, radii, color, seg=8, squash=1.0, wdir=None, caps=True):
    """A smooth tube (or flat ribbon when wdir is given) through the points: one ring per point, `radii` per
    point, `squash` thins the ring across the second axis. color = hex or function(face) (face.material_index =
    the ring segment index). Everything goes into the current piece."""
    bm = bmesh.new()
    P = [Vector(p) for p in pts]
    n = len(P)
    t0 = (P[1] - P[0]).normalized()
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    nrm = (ref - t0 * ref.dot(t0)).normalized()
    prev = t0
    rings = []
    for i, p in enumerate(P):
        t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        if wdir is not None:
            w = Vector(wdir)
            nrm = (w - t * w.dot(t)).normalized()
        else:
            ax = prev.cross(t)
            if ax.length > 1e-6:
                nrm = Matrix.Rotation(prev.angle(t), 3, ax.normalized()) @ nrm
            nrm = (nrm - t * nrm.dot(t)).normalized()
        prev = t
        b = t.cross(nrm)
        r = radii[i]
        rings.append([bm.verts.new(p + nrm * math.cos(2 * math.pi * j / seg) * r + b * math.sin(2 * math.pi * j / seg) * r * squash) for j in range(seg)])
    for i in range(n - 1):
        for j in range(seg):
            fc = bm.faces.new((rings[i][j], rings[i][(j + 1) % seg], rings[i + 1][(j + 1) % seg], rings[i + 1][j]))
            fc.material_index = i
    if caps:
        bm.faces.new(rings[0][::-1]).material_index = 0
        bm.faces.new(rings[-1]).material_index = n - 2
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    f._place(bm, (0, 0, 0), (0, 0, 0), color if callable(color) else (lambda face: color))


def burst(f, at, n, ro, ri, depth, color, color2=None, rot=(0, 0, 0), jitter=0.0, seed=1):
    """A star-burst prism ('pow' shape, no lettering): n points, outer/inner radius, in the local XY plane,
    extruded along Z (front face +Z); turn it with rot=(90,0,0) to face -Y."""
    bm = bmesh.new()
    rnd = np.random.RandomState(seed)
    pts = []
    for i in range(2 * n):
        a = math.pi / 2 + i * math.pi / n
        rr = (ro * (1 + jitter * (rnd.rand() - 0.5)) if i % 2 == 0 else ri)
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    fr = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
    bk = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
    bm.faces.new(fr).material_index = 0
    bm.faces.new(bk[::-1]).material_index = 2
    for i in range(2 * n):
        bm.faces.new((fr[i], bk[i], bk[(i + 1) % (2 * n)], fr[(i + 1) % (2 * n)])).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    c2 = color2 or shade(color, 0.8)
    f._place(bm, at, rot, lambda face: (color, c2, c2)[face.material_index])


def prism(f, at, pts, depth, color, color2=None, rot=(0, 0, 0)):
    """A flat extruded outline (fins, flukes): polygon `pts` (local XY, counter-clockwise) extruded along Z."""
    bm = bmesh.new()
    fr = [bm.verts.new((x, y, depth / 2)) for x, y in pts]
    bk = [bm.verts.new((x, y, -depth / 2)) for x, y in pts]
    bm.faces.new(fr).material_index = 0
    bm.faces.new(bk[::-1]).material_index = 2
    n = len(pts)
    for i in range(n):
        bm.faces.new((fr[i], bk[i], bk[(i + 1) % n], fr[(i + 1) % n])).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    c2 = color2 or shade(color, 0.8)
    f._place(bm, at, rot, lambda face: (color, c2, c2)[face.material_index])


def arm_to(f, side, sleeve, skin, hand, x=1.1, shoulder_z=K.SHOULDER_Z, length=0.95, rz=0, **kw):
    """arm() posed so the hand ends on `hand` (studs, current frame): grid search over the swing angles."""
    base = Vector((side * x, 0, shoulder_z))
    tgt = Vector(hand) - base
    best = None
    for rx in range(-150, 56, 5):
        for ry in range(-70, 181, 5):
            m = Euler((math.radians(rx), math.radians(-side * ry), math.radians(rz)), "XYZ").to_matrix()
            d = (m @ Vector((0, 0, -(length + 0.1))) - tgt).length
            if best is None or d < best[0]:
                best = (d, rx, ry)
    arm(f, side, sleeve, skin, rot=(best[1], best[2], rz), x=x, length=length, shoulder_z=shoulder_z, **kw)
    return best


def legs_pair(f, a, b, r1, r2, color, seg=7):
    for s in (-1, 1):
        tube(f, (s * a[0], a[1], a[2]), (s * b[0], b[1], b[2]), r1, r2, color, seg=seg)


def closed_eye(f, x, z, color=EYE_DARK, w=0.32, r=0.46, thick=0.13, lash=False, side=1):
    """A happy closed eye: an arch of three short bars, with a small lash flick at the outer end."""
    with f.piece("Head"), head_at(f, x, z, 0.04):
        for t in (-44, 0, 44):
            f.rbox((r * math.sin(math.radians(t)), 0, -0.25 + r * math.cos(math.radians(t)) - r * 0.6), (w, 0.07, thick), color, rot=(0, t, 0), bevel=0.0)
        if lash:
            f.rbox((side * 0.58, 0, -0.08), (0.3, 0.07, 0.13), color, rot=(0, -side * 40, 0), bevel=0.0)


# --- 1. Cardboard Astronaut (Newcomer, Sci-Fi) -----------------------------------------------


def astronaut(f):
    """Newcomer (Sci-Fi), very wide. A kid in a spacesuit built from a fridge box: a huge cardboard torso with
    taped seams, a drawn-on control panel and star, foil leggings, a box helmet with a face window framed in marker
    blue, a kitchen-whisk antenna, paper-tube jetpack, and a paper-tube rocket held up ready for launch. Buck teeth."""
    card, card_dk, card_lt = "#C9A86A", "#A58446", "#E2C792"
    foil, foil_dk, blue, tape = "#BFC6D6", "#8A94AD", "#2E86DE", "#F4E7CF"
    skin = "#F2C49C"
    RAISE = 0.95
    legs_kid(f, foil, card_dk, "#6E5430", spread=0.85, hip=1.25, r=0.42)
    with f.piece("Body"):
        f.rbox((0, 0, 2.25), (3.3, 2.5, 2.6), card, bevel=0.16, segs=1)
        f.rbox((0, -1.27, 1.95), (0.55, 0.06, 2.0), tape, bevel=0.0)  # taped seam
        f.rbox((-0.85, -1.28, 2.2), (1.4, 0.05, 1.1), foil, bevel=0.0)  # drawn control panel
        for x, c in ((-1.25, blue), (-0.85, tape), (-0.45, blue)):
            with f.at((x, -1.32, 2.5), (90, 0, 0)):
                f.disc((0, 0, 0), 0.26, 0.26, 0.05, c, seg=6)
        f.rbox((-0.85, -1.32, 1.95), (1.0, 0.05, 0.12), blue, bevel=0.0)
        K._star_inlay(f, 0.9, -1.29, 2.3, 0.58, blue, card)  # a star drawn in marker
        for s_ in (-1, 1):  # top flaps folded out like shoulder pads
            f.rbox((s_ * 1.5, 0, 3.64), (0.9, 2.2, 0.14), card_lt, rot=(0, -s_ * 22, 0), bevel=0.0)
        for s_ in (-1, 1):  # paper-tube jetpack
            f.rcyl((s_ * 0.65, 1.35, 2.3), 0.5, 0.5, 2.3, card_dk, seg=6, bevel=0.0)
            f.rcyl((s_ * 0.65, 1.35, 3.5), 0.54, 0.54, 0.2, foil, seg=6, bevel=0.0)
            f.rcyl((s_ * 0.65, 1.35, 1.1), 0.42, 0.52, 0.5, foil_dk, seg=6, bevel=0.0)

    def rocket(f):
        f.rcyl((0, 0, 1.1), 0.36, 0.36, 2.0, card_lt, seg=7, bevel=0.0)
        f.rcyl((0, 0, 0.7), 0.4, 0.4, 0.3, blue, seg=7, bevel=0.0)
        f.spike((0, 0, 2.06), 0.36, 0.9, foil, seg=7, r2=0.03)
        for ang in (0, 120, 240):
            with f.at((0, 0, 0.2), (0, 0, ang)):
                f.rbox((0.42, 0, 0.1), (0.4, 0.08, 0.7), blue, rot=(0, -18, 0), bevel=0.0)

    def thumb(f):
        f.rbox((0, -0.05, 0.36), (0.3, 0.32, 0.62), tape, bevel=0.08, segs=1)

    arm_to(f, -1, foil_dk, tape, (-2.0, -1.35, 3.3), x=1.8, shoulder_z=3.0, length=1.2, sleeve_r=0.34, held=rocket, upright=True)
    arm_to(f, 1, foil_dk, tape, (2.1, -0.95, 2.55), x=1.8, shoulder_z=3.0, length=1.0, sleeve_r=0.34, held=thumb, upright=True)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        with f.piece("Head"):  # the box helmet: top, sides, back, and a frame round the face window
            f.rbox((0, 0.1, top + 0.12), (3.2, 2.8, 0.5), card, bevel=0.14, segs=1)
            for s_ in (-1, 1):
                f.rbox((s_ * 1.47, 0.1, 3.55), (0.5, 2.8, 2.7), card, bevel=0.1, segs=1)
            f.rbox((0, 1.4, 3.55), (3.2, 0.5, 2.7), card_dk, bevel=0.0)
            f.rbox((0, -1.13, top - 0.1), (3.2, 0.3, 0.75), card, bevel=0.1, segs=1)
            f.rbox((0, -1.13, 2.3), (3.2, 0.3, 0.5), card, bevel=0.1, segs=1)
            f.rbox((0, 0.1, top + 0.38), (0.5, 2.82, 0.07), tape, bevel=0.0)  # tape across the top
            f.rbox((0, -1.3, 4.42), (2.5, 0.06, 0.15), blue, bevel=0.0)  # visor drawn in marker
            f.rbox((0, -1.3, 2.58), (2.5, 0.06, 0.15), blue, bevel=0.0)
            for s_ in (-1, 1):
                f.rbox((s_ * 1.25, -1.3, 3.5), (0.15, 0.06, 1.99), blue, bevel=0.0)
            with f.at((0.8, 0.1, top + 0.37), (0, 12, 0)):  # whisk antenna
                f.rcyl((0, 0, 0.55), 0.12, 0.12, 1.1, foil_dk, seg=5, bevel=0.0)
                for yaw in (0, 60, 120):
                    f.torus((0, 0, 1.95), 0.42, 0.07, foil, rot=(0, 0, yaw), major=6, minor=3, sz=1.9)
        K.face_eyes(f, skin, spread=0.6, k=1.12, z=ez)
        K.face_brows(f, "#4A2F1C", length=0.95, thick=0.2, angle=14, x=0.64, z=ez + 0.72, worried=True)  # hopeful
        K.face_blush(f, x=0.92, z=ez - 0.34, seg=6)
        with f.piece("Head"):  # closed grin with two big buck teeth
            head_patch(f, 0, ez - 0.66, 0.74, 0.16, 0.05, MOUTH, seg=8, rings=1)
            for s_ in (-1, 1):
                with head_at(f, s_ * 0.15, ez - 0.78, 0.1):
                    f.rbox((0, 0, 0), (0.28, 0.07, 0.42), WHITE, bevel=0.0)


# --- 2. Rodeo Rookie (Rising, Action) --------------------------------------------------------


def rodeo(f):
    """Rising (Action), huge-prop template. Never been on a real horse but twirls a lasso like a champion: a huge
    caramel hat with curled brim (1.6x head width), a rope loop spinning over it on a strand from one raised fist,
    red bandana, brown vest with a star badge, denim, bow-legged stance, boots with spurs, freckles and a
    concentrating tongue poking out the corner of the mouth."""
    skin, hat, hat_dk, red, denim, boots = "#E3A877", "#B9773C", "#8F5528", "#D83A3A", "#3A6EA5", "#7A5434"
    rope, cream, hair = "#E8D29A", "#F4E7CF", "#B8541E"
    RAISE = 0.3
    legs_kid(f, denim, boots, "#3A2A20", spread=0.82, hip=1.45, r=0.4)
    with f.piece("Body"):
        for s_ in (-1, 1):  # jeans cuffs + spurs
            f.rcyl((s_ * 0.82, 0, 0.74), 0.46, 0.46, 0.3, shade(denim, 1.25), seg=8, bevel=0.0)
            f.spike((s_ * 0.82, 0.58, 0.28), 0.14, 0.4, "#D9DCE6", rot=(-80, 0, 0), seg=4)
    torso(f, cream, h=1.7, z=2.0, w=1.85)
    with f.piece("Body"):
        f.rbox((0, 0, 1.4), (1.9, 1.42, 0.4), denim, bevel=0.1)
        f.rbox((0, 0, 1.62), (1.94, 1.46, 0.14), "#4A3022", bevel=0.0)  # belt
        f.rbox((0, -0.74, 1.62), (0.5, 0.08, 0.32), GOLD, bevel=0.0)  # big buckle
        for s_ in (-1, 1):  # leather vest panels
            f.rbox((s_ * 0.62, -0.69, 2.1), (0.72, 0.1, 1.5), boots, bevel=0.0, taper=0.92)
            f.rbox((s_ * 0.98, -0.1, 2.15), (0.16, 1.2, 1.5), boots, bevel=0.0)
        K._star_inlay(f, -0.62, -0.78, 2.3, 0.3, GOLD, boots)  # badge
        f.rbox((0, -0.72, 2.7), (0.95, 0.13, 0.95), red, rot=(0, 45, 0), bevel=0.0)  # bandana
        f.ball((0, 0.55, 2.85), (0.34, 0.3, 0.3), red, seg=5, rings=3)  # knot at the back

    def lasso(f):
        # the rope strand rises from the fist to the loop's knot, the loop spins over the hat
        knot = (0.55, 0.0, 3.35)
        sweep(f, [(0, 0, 0.1), (0.12, -0.05, 0.9), (0.4, 0.0, 1.9), knot], [0.12, 0.12, 0.12, 0.12], rope, seg=5)
        f.ball(knot, (0.3, 0.3, 0.26), shade(rope, 0.82), seg=6, rings=3)  # honda knot
        f.torus((knot[0] - 1.9, 0, knot[2] + 0.05), 1.9, 0.14, rope, rot=(58, 0, -8), major=18, minor=4)

    arm_to(f, 1, cream, skin, (1.75, -0.2, 3.55), x=1.1, shoulder_z=2.55, length=1.2, sleeve_r=0.31, held=lasso, upright=True)
    arm(f, -1, cream, skin, rot=(-10, 24, 0), shoulder_z=2.55)
    with f.at((0, 0, RAISE)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        with f.piece("Head"):  # ginger hair showing under the hat: side tufts and a back mass
            f.ball((0, 0.55, top - 1.05), (1.28, 0.95, 1.1), hair, seg=8, rings=4)
            for s_ in (-1, 1):
                f.ball((s_ * 1.18, 0.15, top - 1.0), (0.34, 0.6, 0.78), hair, seg=6, rings=3)
        K.face_eyes(f, skin, spread=0.6, k=1.0, z=ez)
        K.face_brows(f, "#6A3010", length=1.05, thick=0.24, angle=16, x=0.62, z=ez + 0.7, worried=False)
        K.face_blush(f, x=0.95, z=ez - 0.4, w=0.36, h=0.22)
        with f.piece("Head"):
            for s_ in (-1, 1):  # freckles
                for dx, dz in ((0.0, 0.0), (0.22, 0.12), (-0.2, 0.1)):
                    with head_at(f, s_ * (0.96 + dx), ez - 0.18 + dz, 0.02), f.at((0, 0, 0), (90, 0, 0)):
                        f.disc((0, 0, 0), 0.11, 0.11, 0.03, shade(skin, 0.7), seg=4)
            with head_at(f, -0.1, ez - 0.74, 0.04):  # concentrating mouth: a firm slanted line ...
                f.rbox((0, 0, 0), (0.8, 0.07, 0.15), MOUTH, rot=(0, 8, 0), bevel=0.0)
            with head_at(f, 0.3, ez - 0.92, 0.06):  # ... with the tongue sticking out of the corner
                f.ball((0, 0, 0), (0.26, 0.14, 0.38), "#E86A7A", seg=5, rings=3)
        with f.piece("Head"):  # the hat: wide curled brim, crown with a dent and band
            f.rcyl((0, 0.0, top - 0.55), 2.0, 2.0, 0.22, hat, seg=10, squash=0.9, bevel=0.05, rot=(0, 0, 0))
            for s_ in (-1, 1):  # brim curled up at the sides
                f.rbox((s_ * 1.55, 0.0, top - 0.42), (0.85, 3.0, 0.18), hat, rot=(0, -s_ * 16, 0), bevel=0.0)
            dome(f, (0, 0.0, top - 0.5), [(1.32, 0.0), (1.3, 0.35), (1.08, 1.0), (0.82, 1.3)], [hat_dk, hat, hat], seg=10)
            f.rcyl((0, 0.0, top - 0.3), 1.32, 1.32, 0.3, boots, seg=10, bevel=0.0)  # hatband


# --- 3. Wobbly Witch (Rising, Horror) --------------------------------------------------------


def witch(f):
    """Rising (Horror), very tall Lanky template. A trainee witch whose spells only ever make bubbles: a towering
    crooked plum hat that bends at the tip, striped lime stockings on long legs, a tattered plum dress, two
    stubby braids, a broom taller than she is standing at her side, and a chain of cyan bubbles rising off her
    free hand. Wobbly zig-zag mouth, one eye bigger than the other, one brow high."""
    skin, plum, lime, cyan, straw = "#E8B08A", "#6B3FA0", "#9BE564", "#7FE3FF", "#E8C15A"
    plum_dk, plum_lt, hair = "#4E2D78", "#8A5CC4", "#2A1F3D"
    U = 1.25  # the long-legged upper body is lifted by this much
    with f.piece("Body"):
        for s_ in (-1, 1):  # striped stockings
            for i, (z0, z1) in enumerate(((0.5, 1.15), (1.15, 1.8), (1.8, 2.5))):
                f.rcyl((s_ * 0.5, 0, (z0 + z1) / 2), 0.3 + 0.012 * (i % 2), 0.3 + 0.012 * (i % 2), z1 - z0, lime if i % 2 == 0 else plum_dk, seg=6, bevel=0.0)  # radii differ a hair so stacked bands never share vertices
            f.rbox((s_ * 0.5, -0.2, 0.3), (0.84, 1.3, 0.56), plum_dk, bevel=0.14, segs=1)  # boots
            f.rbox((s_ * 0.5, -0.2, 0.07), (0.9, 1.36, 0.14), "#2A1F3D", bevel=0.0)
            f.spike((s_ * 0.5, -0.78, 0.28), 0.34, 0.75, plum_dk, rot=(66, 0, 0), seg=4, squash=0.8)  # curled toe
        # tattered dress: a flared skirt with jagged hem tips
        f.lathe((0, 0, 0), [(1.45, 2.35), (1.4, 2.7), (0.78, 3.4)], [plum, plum], seg=8, scale=(1, 0.85, 1))
        for i in range(8):
            a = 2 * math.pi * i / 8
            f.spike((math.cos(a) * 1.28, math.sin(a) * 1.08, 2.42), 0.36, 0.55, plum_lt if i % 2 else plum_dk, rot=(180, 0, 0), seg=3)
    torso(f, plum, h=1.5, z=2.0 + U + 0.05, w=1.5, d=1.15, taper=0.88)
    with f.piece("Body"):
        f.ball((0, -0.6, 3.5), (0.22, 0.1, 0.22), cyan, seg=5, rings=3)  # a bubble charm
        f.rbox((0, 0, 3.0), (1.58, 1.22, 0.24), lime, bevel=0.0)  # lime sash
        f.rbox((-0.3, -0.62, 2.95), (0.3, 0.1, 0.3), GOLD, bevel=0.0)

    # the broom stands at her right (viewer left): handle through the fist, straw bristles on the plinth
    bx = -1.7
    with f.piece("ArmR"):
        f.rcyl((bx, 0.0, 4.6), 0.14, 0.14, 9.4, shade(straw, 0.78), seg=5, bevel=0.0)
        f.ball((bx, 0.0, 9.35), (0.2, 0.2, 0.2), shade(straw, 0.78), seg=5, rings=3)
        f.lathe((bx, 0.0, -0.3), [(0.72, 0.0), (0.76, 0.35), (0.5, 1.45), (0.18, 2.0)], [straw, straw, straw], seg=7)
        f.rcyl((bx, 0.0, 1.4), 0.5, 0.5, 0.3, lime, seg=7, bevel=0.0)
    arm_to(f, -1, plum, skin, (bx + 0.1, 0.0, 3.1), x=1.05, shoulder_z=2.55 + U, length=1.0, sleeve_r=0.3)
    arm_to(f, 1, plum, skin, (1.8, -0.45, 3.9), x=1.05, shoulder_z=2.55 + U, length=1.0, sleeve_r=0.3)
    with f.piece("ArmL"):  # bubbles rising off the free hand
        for (x, y, z, r) in ((1.95, -0.45, 4.55, 0.48), (1.85, -0.35, 5.5, 0.34), (2.1, -0.25, 6.35, 0.58)):
            f.ball((x, y, z), (r, r, r), cyan, seg=8, rings=4)
            with f.at((x - r * 0.35, y - r * 0.82, z + r * 0.35), (90, 0, 30)):
                f.disc((0, 0, 0), r * 0.55, r * 0.3, 0.05, "#E6FBFF", seg=4)
    with f.at((0, 0, U + 0.1)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        eye1(f, skin, -0.6, ez, k=0.95)
        eye1(f, skin, 0.62, ez + 0.04, k=1.22)  # one eye bigger
        brow1(f, "#2A1F3D", -0.62, ez + 0.72, length=0.95, thick=0.2, angle=-14)
        brow1(f, "#2A1F3D", 0.64, ez + 0.98, length=0.95, thick=0.2, angle=-26)  # one brow high
        K.face_blush(f, color="#F08AA0", x=0.95, z=ez - 0.38, w=0.4, h=0.24, seg=6)
        with f.piece("Head"):  # wobbly zig-zag mouth with one tooth
            for i, (x, dz, ang) in enumerate(((-0.42, 0.1, 38), (-0.14, -0.1, -38), (0.14, 0.1, 38), (0.42, -0.1, -38))):
                with head_at(f, x, ez - 0.82 + dz, 0.05):
                    f.rbox((0, 0, 0), (0.4, 0.07, 0.24), "#5A1A26", rot=(0, ang, 0), bevel=0.0)
            with head_at(f, -0.14, ez - 0.88, 0.08):
                f.rbox((0, 0, 0), (0.22, 0.05, 0.24), WHITE, bevel=0.0)
        with f.piece("Head"):  # hair: fringe, back mass, two stubby braids with lime bows
            f.ball((0, 0.45, top - 1.0), (1.32, 1.0, 1.2), hair, seg=7, rings=4)
            f.ball((0, -0.3, top - 0.55), (1.3, 0.98, 0.5), hair, seg=7, rings=3)
            for s_ in (-1, 1):
                for i in range(2):
                    f.ball((s_ * (1.4 + 0.1 * i), 0.35, top - 1.5 - i * 0.85), (0.44 - 0.06 * i, 0.4, 0.5), hair, seg=6, rings=3)
                f.ball((s_ * 1.5, 0.35, top - 3.0), (0.3, 0.2, 0.22), lime, seg=5, rings=3)
        with f.piece("Head"):  # the hat
            f.rcyl((0, 0.0, top - 0.55), 1.95, 1.95, 0.2, plum, seg=9, squash=0.92, bevel=0.0, rot=(0, -5, 4))
            f.rcyl((0, 0.0, top - 0.3), 1.3, 1.3, 0.34, lime, seg=8, bevel=0.0)
            f.rbox((0, -1.3, top - 0.3), (0.4, 0.1, 0.42), GOLD, bevel=0.0)
            pts, rad = [], []
            x = y = 0.0
            z = top - 0.45
            n = 9
            for i in range(n + 1):
                t = i / n
                phi = math.radians(70 * t ** 1.6)
                pts.append((x, y, z))
                rad.append(1.22 * (1 - t) + 0.05)
                step = 4.2 / n
                x += math.sin(phi) * step
                y += -0.12 * step * t
                z += math.cos(phi) * step
            sweep(f, pts, rad, lambda fc: plum if fc.material_index % 3 else plum_lt, seg=7)


# --- 4. Lagoon Mermaid (Pro, Romance) --------------------------------------------------------


def curve(keys, radii, sub=2):
    """Catmull-Rom through the key points, `sub` points per span, radii interpolated linearly."""
    P = [Vector(k) for k in keys]
    n = len(P)
    pts, rad = [], []
    for i in range(n - 1):
        p0, p1, p2, p3 = P[max(i - 1, 0)], P[i], P[i + 1], P[min(i + 2, n - 1)]
        for j in range(sub):
            t = j / sub
            pts.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
            rad.append(radii[i] * (1 - t) + radii[i + 1] * t)
    pts.append(P[-1])
    rad.append(radii[-1])
    return pts, rad


def mermaid(f):
    """Pro (Romance), no legs. Sings love songs to every boat, sitting on a lagoon rock with her coral tail
    curled round the base and the lilac fin flicked up beside her; a seashell microphone held to her lips, closed
    happy eyes, pucker 'ooh' lips, long navy hair with a starfish clip, lilac shell top, a pearl, floating hearts."""
    skin, coral, coral_lt, lilac, navy = "#B97A52", "#FF7F6A", "#FFA08E", "#B79CFF", "#2B3A67"
    pearl, rock = "#FAF6EC", "#6E7078"
    U = 0.95
    with f.piece("Base"):  # the lagoon rock (grows out of the plinth top)
        f.ball((-0.2, 0.6, 0.7), (1.5, 1.2, 0.95), rock, seg=7, rings=3)
        f.ball((-1.25, 0.3, 0.4), (0.7, 0.7, 0.5), shade(rock, 1.15), seg=6, rings=3)
    with f.piece("Body"):
        # the tail: from the hips down the front of the rock, across the plinth and up the right side
        keys = [(0.0, 0.35, 2.2), (0.15, -0.45, 1.6), (0.3, -1.0, 0.95), (0.55, -1.2, 0.6), (1.1, -1.1, 0.55), (1.55, -0.65, 0.8), (1.85, -0.05, 1.45), (1.95, 0.4, 2.15), (1.95, 0.6, 2.7)]
        pts, rad = curve(keys, [0.85, 0.8, 0.72, 0.62, 0.55, 0.46, 0.4, 0.32, 0.24], sub=2)
        sweep(f, pts, rad, lambda fc: mix(coral, lilac, min(1.0, max(0.0, (fc.material_index - 6) / 10.0))), seg=7, squash=0.95)  # coral to lilac ombre
        # the fin: two big lobes and a middle one, flicked up and facing the viewer
        half = [(0.0, 0.0), (0.3, 0.25), (0.75, 0.7), (1.2, 1.3), (1.5, 2.0), (1.45, 2.55), (1.05, 2.8), (0.6, 2.55), (0.2, 2.0), (0.0, 1.6)]
        fin = [(x * 0.68, y * 0.68) for x, y in half] + [(-x * 0.68, y * 0.68) for x, y in reversed(half[1:-1])]
        prism(f, (1.95, 0.6, 2.65), fin, 0.14, lilac, color2=shade(lilac, 0.85), rot=(90, 22, 0))  # the fin, flicked up
        prism(f, (1.95, 0.52, 2.78), [(x * 0.68, y * 0.72 + 0.1) for x, y in fin], 0.1, shade(lilac, 1.2), color2=lilac, rot=(90, 22, 0))
    with f.at((0, 0.3, 0)):
        torso(f, skin, h=1.55, z=2.75, w=1.55, d=1.15, taper=0.9)
        with f.piece("Body"):
            for s_ in (-1, 1):  # lilac scallop shell top
                f.ball((s_ * 0.42, -0.42, 3.15), (0.52, 0.3, 0.46), lilac, seg=6, rings=3)
            f.ball((0, -0.52, 3.15), (0.16, 0.12, 0.16), pearl, seg=5, rings=3)
            f.rbox((0, -0.55, 2.1), (1.5, 0.12, 0.3), coral, bevel=0.0)  # waist band into the tail

        def shell_mic(f):  # a seashell on a stalk, held up and leaning in to the lips
            with f.at((0, 0, 0), (0, 38, 0)):
                f.rcyl((0, 0, 0.25), 0.1, 0.1, 0.7, pearl, seg=5, bevel=0.0)
                with f.at((0, 0, 0.85), (90, 0, 0)):  # scallop shell: a round plate with pink ribs
                    f.disc((0, 0, 0), 0.8, 0.7, 0.2, "#FFB6C8", seg=8)
                    for rx in (-0.24, 0.0, 0.24):
                        f.disc((rx, 0.0, -0.12), 0.1, 0.55, 0.06, pearl, seg=4)

        def pearl_(f):
            f.ball((0, -0.1, 0.3), (0.3, 0.3, 0.3), pearl, seg=7, rings=4)

        arm_to(f, -1, skin, skin, (-1.1, -1.0, 3.05), x=1.05, shoulder_z=3.4, length=1.0, sleeve_r=0.26, held=shell_mic, upright=True)
        arm_to(f, 1, skin, skin, (0.9, -0.8, 2.8), x=1.05, shoulder_z=3.4, length=1.0, sleeve_r=0.26, held=pearl_, upright=True)
        with f.at((0, 0, U)):
            head_box(f, skin, segs=2)
            top = HEAD_Z0 + K.HEAD_H
            ez = EYE_Z + 0.1
            with f.piece("Head"):  # long navy hair: back mass, swoop and long side locks
                f.ball((0, 0.55, top - 1.1), (1.35, 1.05, 1.4), navy, seg=7, rings=4)
                f.ball((0, 0.1, top - 0.28), (1.34, 1.05, 0.66), navy, seg=7, rings=4)
                f.ball((-0.5, -0.45, top - 0.15), (0.95, 0.6, 0.42), shade(navy, 1.5), rot=(0, 18, 20), seg=6, rings=3)  # swoop
                f.ball((0, 0.85, top - 3.0), (1.15, 0.8, 1.3), navy, seg=6, rings=3)  # long back hair
                for s_ in (-1, 1):
                    f.ball((s_ * 1.3, 0.35, top - 1.3), (0.42, 0.75, 1.0), navy, seg=6, rings=3)
                    f.ball((s_ * 1.25, 0.45, top - 2.5), (0.45, 0.55, 0.75), shade(navy, 1.25), seg=6, rings=3)
                with head_at(f, 1.0, top - 0.7, 0.12):  # starfish clip
                    for i in range(5):
                        f.spike((0, 0, 0), 0.17, 0.42, coral, rot=(90, 0, i * 72), seg=4, squash=0.6)
                    f.ball((0, -0.05, 0), (0.17, 0.1, 0.17), pearl, seg=5, rings=3)
            closed_eye(f, -0.6, ez, side=-1)
            closed_eye(f, 0.6, ez, side=1)
            K.face_blush(f, color="#FF8FA3", x=0.95, z=ez - 0.38, w=0.46, h=0.3, seg=6)
            with f.piece("Head"):  # pucker lips: a pink pad round a small dark 'ooh'
                head_patch(f, 0, ez - 0.74, 0.34, 0.3, 0.07, "#F0607A", seg=8, rings=1)
                head_patch(f, 0, ez - 0.74, 0.17, 0.15, 0.1, "#7A2836", seg=6, rings=1)
    with f.piece("Body"):
        heart(f, (-1.65, -0.4, 6.3), 0.95, "#FF9FC0")
        heart(f, (2.0, -0.4, 5.9), 0.75, "#C9B3FF")


# --- 5. Time Tourist (Pro, Sci-Fi) -----------------------------------------------------------


def tourist(f):
    """Pro (Sci-Fi), tiny on a mount. Took a wrong turn in a time machine and rides home on a round spotted baby
    dinosaur (original: big eyes, little back plates, curled tail), snapping photos: pink flower shirt, khaki
    shorts, sandals, messy copper hair, time-goggles pushed up on the forehead with glowing cyan lenses and a chunky
    camera held at the chest. A big open-mouthed 'wow'."""
    green, green_lt, green_dk, spot = "#54B860", "#8AD694", "#3B8F48", "#FFD84A"
    skin, pink, khaki, cyan, hair = "#D39A6E", "#FF6FA8", "#C9A86A", "#7FE3FF", "#C8581E"
    cam, cam_lt = "#3A3F55", "#BFC6D6"
    with f.piece("Body"):
        f.ball((0, 0.1, 1.95), (1.55, 1.3, 1.3), green, seg=8, rings=4)  # round body
        f.ball((0, -0.25, 1.45), (1.05, 0.9, 0.8), green_lt, seg=7, rings=3)  # belly
        for sx, sy in ((-1.0, -0.65), (1.0, -0.65), (-0.95, 0.85), (0.95, 0.85)):  # stubby legs with big toe pads
            f.rcyl((sx, sy, 0.62), 0.52, 0.5, 1.1, green, seg=6, bevel=0.0)
            f.ball((sx, sy - 0.15, 0.2), (0.62, 0.72, 0.28), green_dk, seg=6, rings=3)
        f.ball((0, -0.95, 2.65), (0.95, 0.9, 0.85), green, seg=8, rings=4)  # head
        f.ball((0, -1.5, 2.45), (0.58, 0.45, 0.4), green_lt, seg=6, rings=3)  # snout
        for s_ in (-1, 1):
            with f.at((s_ * 0.5, -1.55, 2.95), (90, 0, 0)):  # big eyes
                f.disc((0, 0, 0), 0.62, 0.75, 0.06, EYE_DARK, seg=8)
                f.disc((-0.1, 0.12, 0.05), 0.2, 0.22, 0.05, WHITE, seg=4)
            f.rbox((s_ * 0.55, -1.52, 3.4), (0.55, 0.1, 0.14), green_dk, rot=(0, s_ * 14, 0), bevel=0.0)  # brow
        with f.at((0, -1.89, 2.2)):
            f.rbox((0, 0, 0), (0.7, 0.07, 0.12), MOUTH, bevel=0.0)  # smile
        for s_ in (-1, 1):  # round yellow spots on the flanks
            with f.at((s_ * 1.5, 0.2, 2.2), (0, 90, 0)):
                f.disc((0, 0, 0), 0.55, 0.55, 0.14, spot, seg=6)
        with f.at((0, 0.1, 3.18), (0, 0, 0)):
            f.disc((0.7, 0.5, 0), 0.5, 0.5, 0.12, spot, seg=6)
        # tail: sweeps out of the back to the actor's left and curls up, with plates along it
        sweep(f, [(0.1, 0.95, 1.55), (0.8, 1.3, 1.3), (1.6, 1.3, 1.25), (2.3, 0.95, 1.55), (2.55, 0.45, 2.2)], [0.7, 0.58, 0.5, 0.4, 0.18], green, seg=6)
        for (x, y, z) in ((0.0, 1.05, 3.05), (0.1, 1.4, 2.45), (1.1, 1.55, 1.75)):
            f.spike((x, y, z), 0.3, 0.5, spot, seg=4, squash=0.5)
    # the tourist, seated on the dino's back (upper body lifted a little so the dino's face shows under the camera)
    TZ = 0.3
    with f.piece("Body"):
        for s_ in (-1, 1):
            tube(f, (s_ * 0.6, 0.4, 3.55 + TZ), (s_ * 1.5, -0.05, 2.7), 0.42, 0.4, khaki, seg=6)  # shorts
            tube(f, (s_ * 1.5, -0.05, 2.7), (s_ * 1.72, -0.35, 1.9), 0.26, 0.28, skin, seg=6)  # shins
            f.rbox((s_ * 1.78, -0.55, 1.65), (0.62, 1.1, 0.34), "#7A5434", bevel=0.0)  # sandals
    torso(f, pink, h=1.5, z=4.3 + TZ, w=1.75, d=1.3, taper=0.92, bevel=0.14)
    with f.piece("Body"):
        f.rbox((0, 0.45, 3.5 + TZ), (1.8, 1.34, 0.4), khaki, bevel=0.0)
        for (x, z) in ((-0.55, 4.9), (0.6, 5.0), (-0.3, 4.15)):  # white flowers
            with f.at((x, -0.69, z), (90, 0, 0)):
                f.disc((0, 0, 0), 0.4, 0.4, 0.06, WHITE, seg=6)
                f.disc((0, 0, 0.04), 0.16, 0.16, 0.05, spot, seg=4)
        f.rbox((0, -0.02, 5.2), (1.85, 1.34, 0.18), shade(pink, 0.85), bevel=0.0, taper=0.9)  # collar
    # camera: body box, silver top, flash, big lens with cyan glass, held at the chest
    with f.piece("Body"):
        f.rbox((0, -0.95, 4.15), (1.6, 0.8, 0.9), cam, bevel=0.0)
        f.rbox((0, -0.95, 4.65), (1.6, 0.8, 0.16), cam_lt, bevel=0.0)
        f.rbox((-0.5, -1.05, 4.85), (0.38, 0.2, 0.26), "#FFF1A8", bevel=0.0)  # flash
        with f.at((0, -1.4, 4.15), (90, 0, 0)):
            f.rcyl((0, 0, 0.0), 0.5, 0.5, 0.6, "#2A2D3E", seg=8, bevel=0.0)
            f.disc((0, 0, 0.32), 0.62, 0.62, 0.1, cyan, seg=8)
    arm_to(f, 1, pink, skin, (0.95, -0.9, 4.0), x=1.05, shoulder_z=5.05, length=1.0, sleeve_r=0.3)
    arm_to(f, -1, pink, skin, (-0.95, -0.9, 4.0), x=1.05, shoulder_z=5.05, length=1.0, sleeve_r=0.3)
    U = 2.75
    with f.at((0, 0.45, U)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        K.face_eyes(f, skin, spread=0.6, k=1.12, z=ez, socket=False)
        K.face_brows(f, "#5A2E12", length=0.9, thick=0.2, angle=14, x=0.62, z=ez + 0.62, worried=False, lift=(0.06, 0.06))
        with f.piece("Head"):  # big open 'wow' smile: a half-disc mouth with a tongue
            head_patch(f, 0, ez - 0.78, 0.62, 0.38, 0.05, MOUTH, seg=8, rings=1)
            head_patch(f, 0, ez - 0.97, 0.38, 0.17, 0.075, "#E86A7A", seg=6, rings=1)
            head_patch(f, 0, ez - 0.57, 0.5, 0.1, 0.075, WHITE, seg=6, rings=1)
        with f.piece("Head"):  # messy copper hair
            f.ball((0, 0.38, top - 1.1), (1.32, 0.95, 1.3), hair, seg=7, rings=4)
            f.ball((0, 0.1, top - 0.32), (1.34, 1.04, 0.62), hair, seg=7, rings=4)
            for x, h_, t in ((-0.7, 0.8, -26), (0.1, 0.95, 4), (0.8, 0.75, 28)):
                f.spike((x, 0.0, top - 0.15), 0.42, h_, hair, rot=(-12, t, 0), seg=4)
        with f.piece("Head"):  # time-goggles pushed up on the forehead, lenses glow cyan
            for s_ in (-1, 1):
                with head_at(f, s_ * 0.6, top - 0.38, 0.14):
                    f.torus((0, 0, 0), 0.42, 0.1, GOLD, major=8, minor=3)
                    with f.at((0, -0.02, 0), (90, 0, 0)):
                        f.disc((0, 0, 0), 0.66, 0.66, 0.07, cyan, seg=8)
            with head_at(f, 0, top - 0.38, 0.14):
                f.rbox((0, 0, 0), (0.3, 0.1, 0.12), GOLD, bevel=0.0)


# --- 6. Captain Kapow (Star, Action) ---------------------------------------------------------


def kapow(f):
    """Star (Action), floating hero. A big-hearted superhero hovering above her plinth, leaning into flight, cape
    streaming out to one side in a cobalt wave, one fist punched high through a star-burst 'pow' (no lettering),
    white domino mask, red suit with a gold star-burst emblem, white gloves and boots, bold black comma curl and a
    confident smirk."""
    f.float = True
    skin, red, cobalt, gold, white, hair = "#E0A878", "#D83A3A", "#2E5BDB", "#F5B82E", "#FAF6EC", "#1E1620"
    cob_dk, cob_lt = "#2246B0", "#5C86F2"
    HOV, RAISE = 1.05, 0.25
    with f.at((0, 0, HOV + 1.7), (-8, 0, 0)), f.at((0, 0, -1.7)):  # lean forward about the hips
        with f.piece("Body"):
            for s_ in (-1, 1):  # legs spread a little, white boots
                tube(f, (s_ * 0.5, 0, 1.75), (s_ * 0.8, 0.0, 0.65), 0.48, 0.44, red, seg=6)
                f.rbox((s_ * 0.85, -0.25, 0.4), (0.95, 1.4, 0.8), white, bevel=0.14, segs=1)
                f.rbox((s_ * 0.85, -0.25, 0.9), (1.0, 1.1, 0.3), red, bevel=0.0, taper=1.06)  # boot top cuff
        torso(f, red, w=2.3, d=1.5, h=1.8, z=2.55, taper=0.82, bevel=0.15)
        with f.piece("Body"):
            f.rbox((0, 0, 1.72), (2.0, 1.34, 0.36), gold, bevel=0.06)  # belt
            f.rbox((0, -0.7, 1.72), (0.5, 0.08, 0.34), white, bevel=0.0)
            burst(f, (0, -0.8, 2.75), 8, 0.72, 0.38, 0.1, gold, rot=(90, 0, 0))  # star-burst emblem
            f.rbox((0, 0.7, 3.2), (2.4, 0.3, 0.4), cobalt, bevel=0.08)  # cape yoke
            # cape: a long wavy ribbon off the shoulders streaming to +X, a shorter one under it, a drape behind
            for keys, rads, col in (
                ([(0.8, 0.9, 3.35), (1.5, 1.2, 3.65), (2.2, 1.25, 4.05), (2.9, 0.95, 4.55)], [0.7, 0.65, 0.5, 0.1], cob_lt),
                ([(0.8, 0.9, 3.1), (1.6, 1.3, 3.1), (2.4, 1.3, 3.15), (3.1, 1.0, 3.25)], [0.9, 0.8, 0.6, 0.1], cobalt),
                ([(0.8, 0.9, 2.85), (1.5, 1.2, 2.6), (2.2, 1.2, 2.25), (2.8, 0.9, 1.85)], [0.7, 0.6, 0.45, 0.1], cob_dk),
            ):
                pts, rad = curve(keys, rads, sub=2)
                sweep(f, pts, rad, col, seg=4, squash=0.16, wdir=(0, 0, 1))
            f.rbox((0, 0.95, 2.1), (2.2, 0.2, 2.6), cobalt, bevel=0.0, taper=1.15, rot=(-4, 0, 0))

        def pow_(f):  # the star-burst 'pow': the fist punches through it
            with f.at((0.0, 0.5, 0.45)):
                burst(f, (0, 0, 0), 10, 1.2, 0.72, 0.2, "#FFD84A", color2="#E8A31E", rot=(90, 0, 0), jitter=0.28)
                burst(f, (0, -0.17, 0), 10, 0.78, 0.46, 0.1, "#FFF1A8", rot=(90, 0, 0), jitter=0.2, seed=4)

        arm(f, -1, red, white, rot=(-8, 168, 0), x=1.35, length=1.0, shoulder_z=3.15, sleeve_r=0.44, held=pow_, upright=True)
        arm(f, 1, red, white, rot=(0, 36, 0), x=1.35, length=1.0, shoulder_z=3.15, sleeve_r=0.44)
        with f.at((0, 0, RAISE)):
            head_box(f, skin, segs=2)
            top = HEAD_Z0 + K.HEAD_H
            ez = EYE_Z + 0.1
            with f.piece("Head"):  # white domino mask with pointed outer corners
                head_patch(f, 0, ez + 0.02, 1.18, 0.52, 0.05, white, seg=12, rings=1)
                for s_ in (-1, 1):
                    with head_at(f, s_ * 1.14, ez + 0.36, 0.07):
                        f.spike((0, 0, 0), 0.16, 0.38, white, rot=(0, s_ * 34, 0), seg=3, squash=0.5)
            K.face_eyes(f, skin, spread=0.6, k=1.0, z=ez, out=0.06)
            K.face_brows(f, "#1E1620", length=1.1, thick=0.26, angle=-18, x=0.62, z=ez + 0.98, worried=False)
            K.face_blush(f, x=0.98, z=ez - 0.5, w=0.36, h=0.22, seg=6)
            with f.piece("Head"):  # confident smirk: a lopsided curve, a dimple, a flash of teeth
                head_patch(f, 0.1, ez - 0.78, 0.66, 0.3, 0.05, "#7A2836", seg=10, rings=1)
                head_patch(f, 0.1, ez - 0.66, 0.54, 0.1, 0.075, WHITE, seg=8, rings=1)
                with head_at(f, 0.86, ez - 0.66, 0.05):  # dimple on the smirking side
                    f.rbox((0, 0, 0), (0.1, 0.06, 0.3), "#7A2836", rot=(0, -20, 0), bevel=0.0)
            with f.piece("Head"):  # glossy black hair with a bold comma curl on the forehead
                f.ball((0, 0.12, top - 0.28), (1.32, 1.04, 0.64), hair, seg=7, rings=4)
                f.ball((0, 0.62, top - 1.2), (1.3, 0.95, 1.25), hair, seg=7, rings=4)
                f.ball((-0.35, -0.3, top - 0.05), (0.8, 0.55, 0.5), shade(hair, 1.6), rot=(0, 14, 28), seg=6, rings=3)
                f.spike((0.3, -0.75, top - 0.35), 0.38, 1.0, hair, rot=(-112, 10, 0), seg=4, squash=0.6)  # forehead curl
                for s_ in (-1, 1):
                    f.ball((s_ * 1.2, 0.3, top - 0.9), (0.3, 0.55, 0.6), hair, seg=6, rings=3)
    with f.piece("Base"):  # a flat cobalt ring on the plinth under the hover
        f.torus((0, 0, 0.14), 1.45, 0.1, cob_lt, rot=(90, 0, 0), major=14, minor=4)


# --- 7. Inspector Whoops (Star, Comedy) ------------------------------------------------------


def inspector(f):
    """Star (Comedy), huge prop, Lanky template. A detective who solves every case by accident: a tan trench coat
    with popped collar, belt and brass buttons, a deerstalker with a brown/cream check and a tied-up bow, a bushy
    handlebar moustache over a tiny 'oh!', a brass magnifying glass bigger than his head held to one eye with a GIANT
    eye looking out of it, and a rubber duck held up as 'evidence'."""
    skin, tan, tan_dk, brass, lens = "#F5CFA8", "#C9A86A", "#A8884A", GOLD, "#BFE9FF"
    check1, check2, trousers, shoes, mus = "#7A5434", "#F4E7CF", "#4A4036", "#2E241C", "#5A3A22"
    U = 1.35
    brown = "#7A5434"
    with f.piece("Body"):
        for s_ in (-1, 1):
            f.rcyl((s_ * 0.55, 0, 1.2), 0.36, 0.38, 1.8, trousers, seg=7, bevel=0.0)
            f.rbox((s_ * 0.55, -0.2, 0.3), (0.95, 1.4, 0.6), shoes, bevel=0.14, segs=1)
            f.rbox((s_ * 0.55, -0.2, 0.07), (1.0, 1.45, 0.14), "#14100C", bevel=0.0)
        f.rbox((0, 0, 2.3), (2.4, 1.7, 1.5), tan, bevel=0.12, taper=0.86)  # long coat skirt (flares out low)
        f.rbox((0, 0, 1.58), (2.5, 1.78, 0.14), tan_dk, bevel=0.0, taper=0.99)  # hem band
        f.rbox((0, 0.86, 2.2), (0.12, 0.12, 1.6), tan_dk, bevel=0.0)  # back vent
    torso(f, tan, h=1.75, z=2.0 + U + 0.12, w=2.05, d=1.5, taper=0.9)
    with f.piece("Body"):
        f.rbox((0, 0, 3.05), (2.1, 1.54, 0.3), brown, bevel=0.06)  # belt
        f.rbox((0, -0.78, 3.05), (0.5, 0.08, 0.34), brass, bevel=0.0)
        f.rbox((0, -0.76, 3.9), (0.5, 0.08, 1.7), tan_dk, bevel=0.0, taper=2.0)  # lapel V
        for s_ in (-1, 1):
            f.rbox((s_ * 0.55, -0.74, 3.95), (0.6, 0.12, 1.6), tan_dk, bevel=0.0, rot=(0, s_ * 18, 0))  # lapels
            f.rbox((s_ * 0.8, -0.3, 4.5), (0.9, 0.7, 0.55), tan_dk, rot=(0, 0, s_ * -16), bevel=0.05)  # popped collar
            f.rbox((s_ * 1.0, 0.0, 4.4), (0.5, 0.9, 0.12), brown, bevel=0.0)  # epaulet
            f.ball((s_ * 0.34, -0.78, 3.75), (0.14, 0.09, 0.14), brass, seg=5, rings=3)

    def duck(f):  # rubber duck held up as evidence
        f.ball((0, -0.1, 0.45), (0.5, 0.45, 0.38), "#FFD84A", seg=7, rings=4)
        f.ball((0.1, -0.22, 0.95), (0.34, 0.32, 0.34), "#FFD84A", seg=7, rings=4)
        f.ball((0.1, -0.52, 0.9), (0.2, 0.2, 0.1), "#F08A2E", seg=5, rings=3)
        for s_ in (-1, 1):
            f.ball((0.1 + s_ * 0.14, -0.5, 1.02), (0.06, 0.04, 0.07), EYE_DARK, seg=4, rings=2)

    lx, lz = -1.3, 5.9
    arm_to(f, 1, tan, skin, (1.85, -0.85, 3.55), x=1.2, shoulder_z=2.55 + U, length=1.1, sleeve_r=0.33, held=duck, upright=True)
    arm_to(f, -1, tan, skin, (-1.6, -1.7, 3.4), x=1.2, shoulder_z=2.55 + U, length=1.5, sleeve_r=0.33)
    with f.piece("ArmR"):  # the magnifying glass: handle from the fist up to a huge brass ring round a giant eye
        tube(f, (-1.6, -1.7, 3.4), (-1.2, -1.87, 4.4), 0.17, 0.17, shade(brass, 0.7), seg=6)
        f.torus((lx, -1.9, lz), 1.5, 0.17, brass, major=12, minor=4)
        f.torus((lx, -1.9, lz), 1.27, 0.05, lens, major=12, minor=3)
        f.rbox((lx + 0.1, -1.91, lz - 1.5), (0.3, 0.14, 0.3), brass, bevel=0.0)  # ring collar to handle
        for a in (122, 136):  # glints on the glass
            r_ = 1.05
            with f.at((lx + r_ * math.cos(math.radians(a)), -1.95, lz + r_ * math.sin(math.radians(a))), (0, -(a - 90), 0)):
                f.rbox((0, 0, 0), (0.14, 0.06, 0.55 if a == 122 else 0.3), WHITE, bevel=0.0)
        with f.at((lx, -1.72, lz), (90, 0, 0)):  # the GIANT eye (behind the glass)
            f.disc((0, 0, 0), 2.1, 2.5, 0.1, WHITE, seg=12)
            f.disc((0.1, 0.05, 0.08), 1.25, 1.35, 0.1, "#5A3A22", seg=10)
            f.disc((0.1, 0.05, 0.14), 0.7, 0.75, 0.1, EYE_DARK, seg=8)
            f.disc((-0.2, 0.35, 0.18), 0.32, 0.36, 0.08, WHITE, seg=6)
            f.disc((0.3, -0.2, 0.18), 0.14, 0.16, 0.06, WHITE, seg=5)
        f.rbox((lx, -1.76, lz + 1.18), (1.9, 0.2, 0.34), mus, rot=(0, 10, 0), bevel=0.0)  # a bushy brow over it
    with f.at((0, 0, U + 0.12)):
        head_box(f, skin, segs=2)
        top = HEAD_Z0 + K.HEAD_H
        ez = EYE_Z + 0.1
        ears(f, skin, ez, x=1.22)
        eye1(f, skin, 0.72, ez, k=1.0)  # the only small eye (the other is the giant one)
        brow1(f, mus, 0.74, ez + 0.76, length=1.0, thick=0.24, angle=-14)
        K.face_blush(f, x=0.96, z=ez - 0.38, w=0.4, h=0.24)
        with f.piece("Head"):
            with head_at(f, 0, ez - 0.42, 0.14):  # nose
                f.ball((0, 0, 0), (0.28, 0.2, 0.24), shade(skin, 0.92), seg=6, rings=3)
            with head_at(f, 0, ez - 0.95, 0.06), f.at((0, 0, 0), (90, 0, 0)):  # tiny 'oh!'
                f.disc((0, 0, 0), 0.34, 0.4, 0.06, MOUTH, seg=8)
            for s_ in (-1, 1):  # bushy handlebar moustache with curled ends
                with head_at(f, s_ * 0.42, ez - 0.55, 0.12):
                    f.ball((0, 0, 0), (0.5, 0.2, 0.22), mus, rot=(0, s_ * 22, s_ * -18), seg=6, rings=3)
                with head_at(f, s_ * 0.9, ez - 0.5, 0.1):
                    f.ball((0, 0, 0), (0.22, 0.17, 0.3), mus, rot=(0, 0, s_ * 24), seg=5, rings=3)
        with f.piece("Head"):  # deerstalker: check crown, front and back peaks, tied-up ear flaps and a bow
            def chk(face):
                c = face.calc_center_median()
                k = (int((math.atan2(c.y, c.x) + math.pi) / (2 * math.pi) * 10) + face.material_index) % 2
                return check2 if k else check1

            f.lathe((0, 0.0, top - 0.45), [(1.5, 0.0), (1.48, 0.45), (1.3, 0.95), (0.9, 1.35), (0.4, 1.5)], chk, seg=10, scale=(1, 0.88, 1))
            f.rbox((0, -1.3, top - 0.25), (1.4, 0.6, 0.16), check1, rot=(-12, 0, 0), bevel=0.0, taper=0.8)  # front peak
            f.rbox((0, 1.3, top - 0.25), (1.6, 0.8, 0.16), check1, rot=(12, 0, 0), bevel=0.0, taper=0.8)  # back peak
            for s_ in (-1, 1):
                f.rbox((s_ * 1.5, 0.0, top + 0.2), (0.3, 1.5, 0.9), check1, rot=(0, s_ * -24, 0), bevel=0.04)  # flaps tied up
            f.ball((0, 0.0, top + 1.1), (0.34, 0.3, 0.28), check1, seg=6, rings=3)  # tie bow
            f.rcyl((0, 0, top + 0.55), 0.16, 0.16, 0.4, check1, seg=5, bevel=0.0)
            with f.at((0, 0.0, top - 0.35)):  # a band
                f.rcyl((0, 0, 0.0), 1.5, 1.5, 0.22, check1, seg=10, squash=0.88, bevel=0.0)


# --- build, render, QA ------------------------------------------------------------------------

STATE = {}
BUILDS = {
    "astro": ("CardboardAstronaut", "Newcomer", astronaut),
    "rodeo": ("RodeoRookie", "Rising", rodeo),
    "witch": ("WobblyWitch", "Rising", witch),
    "mermaid": ("LagoonMermaid", "Pro", mermaid),
    "tourist": ("TimeTourist", "Pro", tourist),
    "kapow": ("CaptainKapow", "Star", kapow),
    "inspector": ("InspectorWhoops", "Star", inspector),
}
K.ACTORS.update(BUILDS)
B4_KEYS = tuple(BUILDS)
APPROVED = ("pup", "squawk")
LINEUP = B4_KEYS + APPROVED
ALL30 = ("intern", "pup", "squawk") + tuple(B3.B1.BUILDS if hasattr(B3, "B1") else ())
OUT = K.OUT_DIR
CAPS = {"Newcomer": 1900, "Rising": 1900, "Pro": 2000, "Star": 2200, "Superstar": 2500, "Legend": 2500, "Icon": 2500}
K.build = B3.build  # Icon base crystals (not used here, but keep the shared builder)


def all_keys():
    import actors_v2_b1 as B1

    return ["intern", "pup", "squawk"] + list(B1.BUILDS) + list(B2.BUILDS) + list(B3.BUILDS) + list(B4_KEYS)


def build_all(keys=None):
    keys = list(keys or (list(B4_KEYS) + list(APPROVED)))
    sc, built, report = K.main(tuple(keys))
    STATE.update(sc=sc, built=built, report=report)
    return sc, built, report


def objs_of(built, key):
    return list(built[key][1].values())


def tri_report(report):
    out = {}
    for k, r in report.items():
        tier = K.ACTORS[k][1]
        out[k] = (r["tris"], CAPS[tier], "OK" if r["tris"] <= CAPS[tier] else "OVER", r["size_studs"], r["floating"])
    return out


def render_one(sc, built, key, res=720, tag=None):
    tag = tag or f"b4_{key}"
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


def quick4(keys, res=520, tag="b4q"):
    """Fast iteration: rebuild the given actors, front | 3/4 | back each (one PNG per actor in /tmp)."""
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
        print(key, "tris", report[key]["tris"], "cap", CAPS[K.ACTORS[key][1]], by, "size", report[key]["size_studs"], "x", report[key]["x_range"], "y", report[key]["y_range"], "float", report[key]["floating"])
        outs.append(out)
    return sc, built, outs


def lineup(sc, built, path=None, res=360):
    """The 7 new + the two approved (green bar): row of 5 + row of 4."""
    path = path or os.path.join(OUT, "actors_v2_b4_lineup.png")
    tiles = []
    for key in LINEUP:
        ol = objs_of(built, key)
        pts = [o.matrix_world @ Vector(c) for o in ol for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        ctr = Vector(((lo.x + hi.x) / 2, 0, 4.7 * K.STUD))
        t = K.load_img(K.shoot(sc, ol, f"/tmp/b4_lu_{key}.png", az=22, el=12, res=res, center=ctr, radius=7.4 * K.STUD, margin=1.0, samples=32, lens=70))
        t[:10, :, :3] = np.array(K.lin("#4CC764")[:3] if key in APPROVED else K.lin("#E9E4D8")[:3])
        tiles.append(t)
    blank = np.ones_like(tiles[0])
    K.save_img(K.vstack([K.hstack(tiles[:5], pad=4), K.hstack(tiles[5:] + [blank], pad=4)], pad=4), path)
    return path


def silhouettes(sc, built, keys, path=None, per_row=15):
    path = path or os.path.join(OUT, "actors_v2_b4_silhouettes_64.png")
    tiles = []
    for k in keys:
        p = K.shoot(sc, objs_of(built, k), "/tmp/b4_sil_t.png", az=0, el=0, res=256, sil=True)
        t = np.repeat(np.repeat(K.box_down(K.load_img(p), 4), 4, 0), 4, 1)
        tiles.append(t)
    rows = [K.hstack(tiles[i : i + per_row], pad=8) for i in range(0, len(tiles), per_row)]
    w = max(r.shape[1] for r in rows)
    rows = [np.concatenate([r, np.ones((r.shape[0], w - r.shape[1], 4), dtype=np.float32)], axis=1) for r in rows]
    K.save_img(K.vstack(rows, pad=8), path)
    return path


def run_qa_gate(built, key):
    qd = os.path.expanduser("~/.claude/skills/blender-asset-qa/scripts")
    if qd not in sys.path:
        sys.path.insert(0, qd)
    import importlib

    import qa_check

    importlib.reload(qa_check)
    r = qa_check.run(objects=[o.name for o in objs_of(built, key)], profile="game")
    return r["pass"], r["errors"], r["warnings"]


def finalize_b4(render=True):
    """Build the 7 + Pup + Squawk, QA, render every sheet as actors_v2_b4_*, lineup, FBX; then the 30-actor silhouettes."""
    sc, built, report = build_all()
    out = {"qa": tri_report(report)}
    if not render:
        return sc, built, out
    for key in B4_KEYS:
        out[key] = render_one(sc, built, key)
    lineup(sc, built)
    silhouettes(sc, built, list(B4_KEYS) + list(APPROVED), path=os.path.join(OUT, "actors_v2_b4_silhouettes_9.png"), per_row=9)
    return sc, built, out
