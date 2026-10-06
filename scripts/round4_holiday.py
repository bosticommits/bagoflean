"""Round 4: illustrated retro Christmas crewnecks with a rubber-hose pickleball mascot.

Usage:
    python scripts/round4_holiday.py                 # all four designs
    python scripts/round4_holiday.py merry badge     # only some (merry, dashing, badge, sweater)
    PREVIEW=1 python scripts/round4_holiday.py       # 1x drawing, faster, for quick looks

Writes designs-round-4/<slug>/ with design.png (4500x5400, 300 DPI, transparent),
mockup.png and listing.json.

How the drawing works
- Everything is drawn on a 2x canvas (9000x10800) and box-downscaled at the end,
  so edges are smooth but colours stay flat. Coordinates in this file are always
  in final print pixels (4500x5400); the Art class multiplies by the scale.
- Shapes are lists of primitives. A "part" is drawn twice: first grown by the
  outline width in ink, then at its true size in its fill colour. Drawing parts
  in back-to-front order gives cartoon linework where parts overlap.
- A character also gets a cream "sticker" contour (everything grown by
  outline + contour width, drawn first) so it reads on black, navy, forest and
  maroon shirts.
- Distress: small irregular specks and a few scratches are punched out of the
  alpha channel with a binary mask (no semi-transparent ink).
"""

from __future__ import annotations

import io
import json
import math
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from etsy_agent.compliance import AI_DISCLOSURE, listing_problems  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from etsy_agent.render import make_mockup  # noqa: E402

OUT = ROOT / "designs-round-4"
FONT_DIR = ROOT / "fonts"
SCALE = 1 if os.environ.get("PREVIEW") else 2
W, H = 4500, 5400

# Palette: screen-print style, five inks max per design.
INK = "#1C1A2B"      # outlines (near-black plum)
CREAM = "#FFF3DC"
LIME = "#D4EE3B"
OLIVE = "#93B41F"    # pickleball holes
RED = "#E0393E"
PINK = "#F49A8C"     # cheeks
GREEN = "#2E9A5C"
GOLD = "#F6C445"

OW = 24   # standard ink outline, print px
CW = 30   # cream sticker contour, print px

SHIRTS = {"Black": "#1B1B1D", "Navy": "#1F2A44", "Forest Green": "#1F4A33", "Maroon": "#5B1F2B"}

FONTS = {
    "lobster": "Lobster-Regular.ttf", "shrikhand": "Shrikhand-Regular.ttf",
    "bowlby": "BowlbyOneSC-Regular.ttf", "alfa": "AlfaSlabOne-Regular.ttf",
    "bungee": "Bungee-Regular.ttf", "racing": "RacingSansOne-Regular.ttf",
    "pacifico": "Pacifico-Regular.ttf", "chewy": "Chewy-Regular.ttf",
    "righteous": "Righteous-Regular.ttf", "rubik": "RubikMonoOne-Regular.ttf",
}


def font(name: str, size: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / FONTS[name]), max(1, int(round(size))))


# ------------------------------------------------------------------ geometry
def bez(p0, p1, p2, p3, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def qbez(p0, p1, p2, n=40):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]))
    return out


def rot(pts, ang, ox=0.0, oy=0.0):
    a = math.radians(ang)
    c, s = math.cos(a), math.sin(a)
    return [(ox + (x - ox) * c - (y - oy) * s, oy + (x - ox) * s + (y - oy) * c) for x, y in pts]


def xf(pts, cx, cy, u, ang=0.0, flip=False):
    """Local unit coords -> print coords: scale by u, optional mirror, rotate, translate."""
    pts = [((-x if flip else x) * u, y * u) for x, y in pts]
    return [(cx + x, cy + y) for x, y in rot(pts, ang)]


def ellipse_pts(cx, cy, rx, ry, ang=0.0, n=90, a0=0.0, a1=360.0):
    pts = [(rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), ry * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
           for i in range(n + (0 if a1 - a0 >= 360 else 1))]
    return [(cx + x, cy + y) for x, y in rot(pts, ang)]


def rrect_pts(cx, cy, w, h, r, ang=0.0, n=10):
    r = min(r, w / 2, h / 2)
    pts = []
    for (qx, qy, a0) in [(w / 2 - r, -h / 2 + r, -90), (w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90),
                         (-w / 2 + r, -h / 2 + r, 180)]:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((qx + r * math.cos(a), qy + r * math.sin(a)))
    return [(cx + x, cy + y) for x, y in rot(pts, ang)]


# ------------------------------------------------------------------ primitives
# ("circle", cx, cy, r) | ("ellipse", cx, cy, rx, ry, ang) | ("poly", pts) | ("line", pts, width)
def circle(cx, cy, r):
    return ("circle", cx, cy, r)


def ell(cx, cy, rx, ry, ang=0.0):
    return ("ellipse", cx, cy, rx, ry, ang)


def poly(pts):
    return ("poly", list(pts))


def line(pts, w):
    return ("line", list(pts), w)


def prim_bbox(p, grow=0.0):
    k = p[0]
    if k == "circle":
        _, cx, cy, r = p
        r += grow
        return cx - r, cy - r, cx + r, cy + r
    if k == "ellipse":
        _, cx, cy, rx, ry, _a = p
        r = max(rx, ry) + grow
        return cx - r, cy - r, cx + r, cy + r
    pts = p[1]
    g = grow + (p[2] / 2 if k == "line" else 0)
    xs, ys = [q[0] for q in pts], [q[1] for q in pts]
    return min(xs) - g, min(ys) - g, max(xs) + g, max(ys) + g


def stroke(d, pts, hw, color, closed=False):
    """Thick polyline as quads + round joints (PIL's wide lines leave slivers at joints)."""
    if closed:
        pts = list(pts) + [pts[0]]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy)
        if ln < 1e-6:
            continue
        nx, ny = -dy / ln * hw, dx / ln * hw
        d.polygon([(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)], fill=color)
    for x, y in pts:
        d.ellipse((x - hw, y - hw, x + hw, y + hw), fill=color)


def draw_prim(d, p, color, grow=0.0, s=1.0, ox=0.0, oy=0.0):
    k = p[0]
    T = lambda pts: [((x - ox) * s, (y - oy) * s) for x, y in pts]  # noqa: E731
    if k == "circle":
        _, cx, cy, r = p
        r += grow
        d.ellipse(((cx - r - ox) * s, (cy - r - oy) * s, (cx + r - ox) * s, (cy + r - oy) * s), fill=color)
    elif k == "ellipse":
        _, cx, cy, rx, ry, a = p
        d.polygon(T(ellipse_pts(cx, cy, rx + grow, ry + grow, a, n=120)), fill=color)
    elif k == "poly":
        pts = p[1]
        d.polygon(T(pts), fill=color)
        if grow > 0:
            stroke(d, T(pts), grow * s, color, closed=True)
    elif k == "line":
        pts, w = p[1], p[2]
        stroke(d, T(pts), (w / 2 + grow) * s, color)


class Part:
    def __init__(self, prims, fill, ow=OW, clip=None, contour=True):
        self.prims, self.fill, self.ow, self.clip, self.contour = prims, fill, ow, clip, contour


class Art:
    """A 4500x5400 print drawn at SCALE x resolution."""

    def __init__(self, w=W, h=H):
        self.w, self.h, self.s = w, h, SCALE
        self.img = Image.new("RGBA", (w * self.s, h * self.s), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def prim(self, p, color, grow=0.0):
        draw_prim(self.d, p, color, grow, self.s)

    def part(self, part: Part):
        if part.clip is not None:
            self._clipped(part)
            return
        if part.ow:
            for p in part.prims:
                self.prim(p, INK, part.ow)
        for p in part.prims:
            self.prim(p, part.fill)

    def _clipped(self, part: Part):
        """Draw a part only inside the union of part.clip primitives."""
        boxes = [prim_bbox(p, part.ow) for p in part.prims]
        x0, y0 = min(b[0] for b in boxes) - 4, min(b[1] for b in boxes) - 4
        x1, y1 = max(b[2] for b in boxes) + 4, max(b[3] for b in boxes) + 4
        s = self.s
        size = (int((x1 - x0) * s) + 2, int((y1 - y0) * s) + 2)
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        if part.ow:
            for p in part.prims:
                draw_prim(ld, p, INK, part.ow, s, x0, y0)
        for p in part.prims:
            draw_prim(ld, p, part.fill, 0, s, x0, y0)
        mask = Image.new("L", size, 0)
        md = ImageDraw.Draw(mask)
        for p in part.clip:
            draw_prim(md, p, 255, 0, s, x0, y0)
        a = np.minimum(np.array(layer.getchannel("A")), np.array(mask))
        layer.putalpha(Image.fromarray(a))
        self.img.alpha_composite(layer, (int(x0 * s), int(y0 * s)))

    def figure(self, parts, contour=CREAM, cw=CW):
        """Sticker contour under the whole figure, then the parts back to front."""
        if contour:
            for part in parts:
                if part.contour and part.clip is None:
                    for p in part.prims:
                        self.prim(p, contour, part.ow + cw)
        for part in parts:
            self.part(part)

    def paste(self, layer: Image.Image, x: float, y: float):
        """Paste a SCALE-resolution layer with its top-left at print coords (x, y)."""
        self.img.alpha_composite(layer, (int(round(x * self.s)), int(round(y * self.s))))

    def paste_center(self, layer, cx, top):
        self.paste(layer, cx - layer.width / self.s / 2, top)

    # ------------------------------------------------------------ output
    def finish(self, seed=1, distress_amount=1.0) -> bytes:
        img = self.img
        if distress_amount:
            img = distress(img, seed, distress_amount, self.s)
        if self.s > 1:
            img = img.convert("RGBa").reduce(self.s).convert("RGBA")
        a = np.array(img)
        alpha = a[..., 3]
        alpha[alpha < 10] = 0
        alpha[alpha > 245] = 255
        a[alpha == 0] = 0
        img = Image.fromarray(a, "RGBA")
        if img.size != (W, H):
            img = img.resize((W, H), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="PNG", dpi=(300, 300), optimize=True)
        return buf.getvalue()


def distress(img: Image.Image, seed: int, amount: float, s: int) -> Image.Image:
    """Punch small irregular specks and short scratches out of the ink (binary alpha)."""
    rng = np.random.default_rng(seed)
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    # Low-frequency field so wear clusters like a real worn print.
    field = rng.random((9, 8))
    field = np.array(Image.fromarray((field * 255).astype(np.uint8)).resize((w // 50 + 1, h // 50 + 1), Image.BICUBIC)) / 255.0
    alpha = np.array(img.getchannel("A"))
    n = int(4000 * amount)
    for _ in range(n):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        f = field[int(y // 50), int(x // 50)]
        if rng.random() > f ** 2.2:
            continue
        if alpha[int(y), int(x)] == 0:
            continue
        r = rng.uniform(4.5, 13) * s if rng.random() < 0.85 else rng.uniform(13, 22) * s
        k = rng.integers(6, 10)
        pts = []
        for i in range(k):
            a = 2 * math.pi * i / k + rng.uniform(-0.25, 0.25)
            rr = r * rng.uniform(0.6, 1.15)
            pts.append((x + rr * math.cos(a), y + rr * math.sin(a)))
        md.polygon(pts, fill=255)
    # A few dry-brush scratches.
    for _ in range(int(18 * amount)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        if alpha[int(y), int(x)] == 0:
            continue
        ln = rng.uniform(60, 170) * s
        a = rng.uniform(0, math.pi)
        bend = rng.uniform(-0.08, 0.08) * ln
        p0 = (x - math.cos(a) * ln / 2, y - math.sin(a) * ln / 2)
        p2 = (x + math.cos(a) * ln / 2, y + math.sin(a) * ln / 2)
        p1 = (x - math.sin(a) * bend, y + math.cos(a) * bend)
        stroke(md, qbez(p0, p1, p2, 12), rng.uniform(4.5, 6) * s, 255)
    m = np.array(mask) > 127
    alpha[m] = 0
    out = img.copy()
    out.putalpha(Image.fromarray(alpha))
    return out


# ------------------------------------------------------------------ text
def extrude(dist, ang_deg=60.0, step=4.0):
    n = max(1, int(dist / step))
    a = math.radians(ang_deg)
    return [(math.cos(a) * dist * i / n, math.sin(a) * dist * i / n) for i in range(1, n + 1)]


def text_layer(text, fname, size, fill, ow=OW, shadow=None, shadow_dist=0, shadow_ang=60.0,
               contour=CREAM, cw=CW, tracking=0.0):
    """Retro text: fill + ink outline, optional ink-outlined 3D extrusion, cream outer contour.

    Returns an RGBA layer at SCALE resolution, cropped to its ink.
    """
    s = SCALE
    f = font(fname, size * s)
    offs = extrude(shadow_dist * s, shadow_ang, 3.0 * s) if shadow else []
    pad = int((ow + cw + shadow_dist + 40) * s)
    # glyph positions (manual tracking)
    chars = list(text)
    xs, x = [], 0.0
    for i, ch in enumerate(chars):
        xs.append(x)
        x += f.getlength(ch) + tracking * s
        if i + 1 < len(chars) and not tracking:
            x += f.getlength(ch + chars[i + 1]) - f.getlength(ch) - f.getlength(chars[i + 1])
    width = int(x + 2 * pad)
    asc, desc = f.getmetrics()
    height = int(asc + desc + 2 * pad)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def put(dx, dy, color, stroke):
        if tracking:
            for ch, cx in zip(chars, xs):
                d.text((pad + cx + dx, pad + dy), ch, font=f, fill=color, stroke_width=int(stroke), stroke_fill=color)
        else:
            d.text((pad + dx, pad + dy), text, font=f, fill=color, stroke_width=int(stroke), stroke_fill=color)

    o, c = ow * s, cw * s
    if contour:
        put(0, 0, contour, o + c)
        for dx, dy in offs:
            put(dx, dy, contour, o + c)
    for dx, dy in offs:
        put(dx, dy, INK, o)
    for dx, dy in offs[:-1]:
        put(dx, dy, shadow, 0)
    if offs:
        put(*offs[-1], shadow, 0)
    put(0, 0, INK, o)
    put(0, 0, fill, 0)
    return img.crop(img.getbbox())


def warp_arc(img: Image.Image, amount: float, up=True) -> Image.Image:
    """Bend a layer into an arch (up=True: middle raised) by shifting columns."""
    a = np.array(img)
    h, w = a.shape[:2]
    A = int(round(amount * SCALE))
    u = (np.arange(w) - (w - 1) / 2) / ((w - 1) / 2)
    shift = (A * u ** 2) if up else (A * (1 - u ** 2))
    shift = np.round(shift).astype(int)
    out = np.zeros((h + A + 1, w, 4), dtype=a.dtype)
    for x in range(w):
        out[shift[x]:shift[x] + h, x] = a[:, x]
    res = Image.fromarray(out, "RGBA")
    return res.crop(res.getbbox())


def fit_size(text, fname, width, tracking=0.0):
    f = font(fname, 1000)
    adv = f.getlength(text) + tracking * (len(text) - 1)
    return 1000 * width / adv


def arc_text(art: Art, text, fname, size, cx, cy, radius, center_deg, fill, ow=OW, contour=None, cw=CW,
             bottom=False, tracking=0.0):
    """Glyphs placed along a circle. Top text reads clockwise with letters upright on the
    outside; bottom text reads left-to-right along the bottom with baselines toward the centre."""
    s = SCALE
    f = font(fname, size)
    widths = [f.getlength(ch) + tracking for ch in text]
    total = sum(widths) - tracking
    ang_total = math.degrees(total / radius)
    a = center_deg - ang_total / 2 if not bottom else center_deg + ang_total / 2
    for ch, wd in zip(text, widths):
        da = math.degrees(wd / radius)
        mid = a + (da / 2 if not bottom else -da / 2)
        if ch.strip():
            g = text_layer(ch, fname, size, fill, ow=ow, contour=contour, cw=cw)
            # rotate so the glyph's up points away from (top) or toward (bottom) the centre
            rot_deg = -(mid + 90) if not bottom else -(mid - 90)
            g = g.rotate(rot_deg, resample=Image.BICUBIC, expand=True)
            px = cx + radius * math.cos(math.radians(mid))
            py = cy + radius * math.sin(math.radians(mid))
            art.paste(g, px - g.width / s / 2, py - g.height / s / 2)
        a += da if not bottom else -da


# ------------------------------------------------------------------ props & body parts
def glove_open(cx, cy, u, ang=0.0, flip=False):
    """Waving cartoon glove, fingers up (before rotation). (cx, cy) = palm centre."""
    T = lambda pts: xf(pts, cx, cy, u, ang, flip)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    palm = poly(T(ellipse_pts(0, 0.05, 0.46, 0.44, n=60)))
    fingers = []
    for a, ln in [(-24, 0.82), (-3, 0.92), (18, 0.84)]:
        r = math.radians(a)
        bx, by = 0.36 * math.sin(r) * 0.6, -0.1
        tx, ty = math.sin(r) * ln, -math.cos(r) * ln
        fingers.append(line([C(bx, by), C(tx, ty)], 0.27 * u))
    thumb = line([C(-0.25, 0.12), C(-0.72, -0.18)], 0.27 * u)
    cuff = poly(T(rrect_pts(0, 0.6, 0.86, 0.34, 0.15)))
    crease = [line([C(-0.12, 0.3), C(-0.1, 0.08)], 0.055 * u), line([C(0.12, 0.3), C(0.11, 0.08)], 0.055 * u)]
    return [Part([palm, thumb] + fingers, CREAM), Part(crease, INK, ow=0), Part([cuff], CREAM)]


def glove_fist(cx, cy, u, ang=0.0, flip=False):
    """Fist gripping a handle that runs along the local y axis through (cx, cy); the wrist is on +x."""
    T = lambda pts: xf(pts, cx, cy, u, ang, flip)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    bumps = [circle(*C(-0.2, y), 0.17 * u) for y in (-0.26, 0.0, 0.26)]
    body = poly(T(rrect_pts(0.1, 0.0, 0.66, 0.78, 0.3)))
    creases = [line([C(-0.3, y), C(-0.02, y)], 0.05 * u) for y in (-0.13, 0.13)]
    thumb = line([C(0.3, -0.24), C(-0.08, -0.3)], 0.2 * u)
    cuff = poly(T(rrect_pts(0.52, 0, 0.28, 0.86, 0.12)))
    return [Part([body] + bumps, CREAM), Part(creases, INK, ow=0), Part([thumb], CREAM), Part([cuff], CREAM)]


def sneaker(cx, cy, u, ang=0.0, flip=False, color=RED):
    """Chunky retro high-top, toe pointing +x (before flip). (cx, cy) = ankle."""
    T = lambda pts: xf(pts, cx, cy, u, ang, flip)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    upper = poly(T(bez((-0.42, 0.0), (-0.45, -0.38), (0.05, -0.42), (0.1, -0.12), 20)
                   + bez((0.1, -0.12), (0.45, -0.08), (0.78, 0.0), (0.74, 0.3), 20)
                   + [(0.74, 0.34), (-0.46, 0.34)]))
    sole = poly(T(rrect_pts(0.14, 0.38, 1.3, 0.22, 0.11)))
    toe = poly(T(ellipse_pts(0.56, 0.2, 0.22, 0.16, n=40, a0=-120, a1=90) + [(0.4, 0.3)]))
    laces = [line([C(0.0 + 0.17 * i, -0.13 + 0.06 * i), C(0.1 + 0.17 * i, -0.02 + 0.06 * i)], 0.06 * u) for i in range(3)]
    return [Part([upper], color), Part([toe], CREAM), Part(laces, CREAM, ow=0), Part([sole], CREAM)]


def paddle(gx, gy, ang, L, face=GREEN, trim=CREAM, grip=RED):
    """Paddle whose grip centre is (gx, gy), pointing at angle ang (0 = straight up). L = total length."""
    T = lambda pts: xf(pts, gx, gy, L, ang)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    handle = line([C(0, 0.1), C(0, -0.3)], 0.12 * L)
    outline = rrect_pts(0, -0.64, 0.62, 0.72, 0.24)
    face_p = poly(T(outline))
    clip = [poly(T(rrect_pts(0, -0.64, 0.62, 0.72, 0.24)))]
    stripe = poly(T([(-0.4, -0.5), (0.4, -0.86), (0.4, -0.74), (-0.4, -0.38)]))
    stripe2 = poly(T([(-0.4, -0.36), (0.4, -0.72), (0.4, -0.67), (-0.4, -0.31)]))
    return {
        "handle": [Part([handle], grip)],
        "face": [Part([face_p], face), Part([stripe, stripe2], trim, ow=0, clip=clip)],
    }


def santa_hat(cx, cy, R, tilt=-8.0, droop=1.0):
    """Santa hat with a drooping tip and pompom, on a ball of radius R centred at (cx, cy)."""
    T = lambda pts: xf(pts, cx, cy, R, tilt)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    tip = (1.0 + 0.24 * droop, -1.0 + 0.0 * droop)
    body = poly(T(bez((-0.84, -0.7), (-0.78, -1.28), (-0.22, -1.62), (0.33, -1.6), 30)
                  + bez((0.33, -1.6), (0.85, -1.58), (tip[0] - 0.02, -1.4), tip, 24)
                  + bez((tip[0] - 0.16, tip[1]), (tip[0] - 0.18, -1.2), (0.85, -1.3), (0.62, -1.2), 16)
                  + bez((0.62, -1.2), (0.7, -1.0), (0.8, -0.86), (0.84, -0.7), 16)))
    crease = line(T(qbez((0.52, -1.42), (0.78, -1.4), (0.92, -1.18), 16)), 0.045 * R)
    fur = []
    for i in range(9):
        t = i / 8
        fur.append(circle(*C(-0.92 + 1.84 * t, -0.72 - 0.08 * math.sin(math.pi * t)), 0.19 * R))
    fur.append(line(T([(-0.9, -0.73), (0.9, -0.73)]), 0.34 * R))
    px, py = tip[0] - 0.06, tip[1] + 0.1
    pom = [circle(*C(px, py), 0.2 * R), circle(*C(px - 0.12, py - 0.08), 0.14 * R),
           circle(*C(px + 0.13, py - 0.1), 0.14 * R), circle(*C(px + 0.05, py + 0.14), 0.14 * R),
           circle(*C(px - 0.13, py + 0.1), 0.12 * R)]
    return [Part([body], RED), Part([crease], INK, ow=0), Part(fur, CREAM), Part(pom, CREAM)]


def ball_body(cx, cy, R, face_box=None, skip=()):
    """Lime pickleball with olive holes and a cream highlight."""
    parts = [Part([circle(cx, cy, R)], LIME)]
    holes = []
    for i in range(14):
        a = math.radians(i * 360 / 14 + 8)
        holes.append((cx + 0.8 * R * math.cos(a), cy + 0.8 * R * math.sin(a)))
    for i in range(7):
        a = math.radians(i * 360 / 7 + 30)
        holes.append((cx + 0.47 * R * math.cos(a), cy + 0.47 * R * math.sin(a)))
    keep = []
    for k, (x, y) in enumerate(holes):
        if k in skip:
            continue
        if face_box and face_box[0] < x < face_box[2] and face_box[1] < y < face_box[3]:
            continue
        keep.append(circle(x, y, 0.075 * R))
    parts.append(Part(keep, OLIVE, ow=0))
    shine = line(ellipse_pts(cx, cy, 0.84 * R, 0.84 * R, n=30, a0=150, a1=196), 0.07 * R)
    parts.append(Part([shine], CREAM, ow=0))
    return parts


def face(cx, cy, R, look=(0.0, 0.0), wink=False, nose=None):
    """Rubber-hose face: big cream eyes with pie-cut pupils, rosy cheeks, open grin."""
    lx, ly = look
    parts = []
    for side in (-1, 1):
        ex, ey = cx + side * 0.25 * R + lx * R, cy - 0.12 * R + ly * R
        if wink and side == 1:
            parts.append(Part([line(qbez((ex - 0.14 * R, ey + 0.02 * R), (ex, ey - 0.14 * R), (ex + 0.14 * R, ey + 0.02 * R)), 0.07 * R)],
                              INK, ow=0))
            continue
        parts.append(Part([ell(ex, ey, 0.15 * R, 0.22 * R)], CREAM))
        px, py = ex + 0.03 * R + lx * 0.3 * R, ey + 0.05 * R
        parts.append(Part([ell(px, py, 0.085 * R, 0.14 * R)], INK, ow=0))
        wedge = poly([(px, py - 0.02 * R), (px + 0.1 * R, py - 0.16 * R), (px + 0.0 * R, py - 0.19 * R)])
        parts.append(Part([wedge], CREAM, ow=0, clip=[ell(px, py, 0.085 * R, 0.14 * R)]))
    mx, my = cx + lx * R, cy + 0.2 * R + ly * R
    for side in (-1, 1):
        parts.append(Part([ell(mx + side * 0.45 * R, my + 0.02 * R, 0.11 * R, 0.07 * R)], PINK, ow=0))
    mouth_pts = (qbez((mx - 0.3 * R, my), (mx, my + 0.07 * R), (mx + 0.3 * R, my), 20)
                 + bez((mx + 0.3 * R, my), (mx + 0.28 * R, my + 0.36 * R), (mx - 0.28 * R, my + 0.36 * R), (mx - 0.3 * R, my), 30))
    mouth_p = poly(mouth_pts)
    parts.append(Part([mouth_p], INK, ow=int(0.03 * R)))
    parts.append(Part([ell(mx + 0.02 * R, my + 0.3 * R, 0.17 * R, 0.11 * R)], RED, ow=0, clip=[mouth_p]))
    for side in (-1, 1):
        parts.append(Part([line(qbez((mx + side * 0.27 * R, my - 0.07 * R), (mx + side * 0.34 * R, my - 0.02 * R),
                                     (mx + side * 0.33 * R, my + 0.07 * R), 10), 0.045 * R)], INK, ow=0))
    if nose:
        nx, ny = mx + 0.02 * R, my - 0.06 * R
        parts.append(Part([circle(nx, ny, 0.12 * R)], nose, ow=int(0.03 * R)))
        parts.append(Part([ell(nx - 0.04 * R, ny - 0.045 * R, 0.035 * R, 0.025 * R, -30)], CREAM, ow=0))
    return parts


def limb(pts, R, color=INK):
    return Part([line(pts, 0.115 * R)], color, ow=0)


def sparkle(cx, cy, r, color=CREAM):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.24
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return Part([poly(pts)], color, ow=0, contour=False)


def snowflake(cx, cy, r, color=CREAM, w=None, ang=0.0):
    w = w or max(22, r * 0.16)
    prims = []
    for i in range(6):
        a = math.radians(ang + i * 60)
        ex, ey = cx + r * math.cos(a), cy + r * math.sin(a)
        prims.append(line([(cx, cy), (ex, ey)], w))
        for t, br in ((0.55, 0.32),):
            bx, by = cx + r * t * math.cos(a), cy + r * t * math.sin(a)
            for da in (-50, 50):
                b = a + math.radians(da)
                prims.append(line([(bx, by), (bx + r * br * math.cos(b), by + r * br * math.sin(b))], w))
    return Part(prims, color, ow=0, contour=False)


def arm_to(parts, sh, hand, R, c1, c2):
    """Rubber-hose arm from shoulder sh to hand, with bezier control offsets c1, c2 (in R units)."""
    p1 = (sh[0] + c1[0] * R, sh[1] + c1[1] * R)
    p2 = (hand[0] + c2[0] * R, hand[1] + c2[1] * R)
    parts.append(limb(bez(sh, p1, p2, hand, 30), R))


def fist_cuff(hand, u, ang, flip=False):
    return xf([(0.62, 0.0)], hand[0], hand[1], u, ang, flip)[0]


# ------------------------------------------------------------------ design 1: Merry Dinkmas
def mascot_merry(cx, cy, R):
    back, front = [], []
    for side in (-1, 1):
        hip = (cx + side * 0.32 * R, cy + 0.85 * R)
        ank = (cx + side * 0.5 * R, cy + 1.48 * R)
        back.append(limb(bez(hip, (hip[0] + side * 0.05 * R, hip[1] + 0.3 * R), (ank[0] - side * 0.05 * R, ank[1] - 0.3 * R), ank, 20), R))
        back += sneaker(ank[0], ank[1], 0.64 * R, ang=side * 4, flip=(side < 0))
    # paddle arm (viewer's left)
    hand, ang, u = (cx - 1.52 * R, cy - 0.12 * R), -10, 0.5 * R
    cuff = fist_cuff(hand, u, ang)
    wx, wy = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    arm_to(back, (cx - 0.8 * R, cy + 0.22 * R), cuff, R, (-0.4, 0.06), (0.3 * wx, 0.3 * wy))
    pad = paddle(hand[0], hand[1], ang, 1.5 * R)
    front += pad["face"] + pad["handle"] + glove_fist(hand[0], hand[1], u, ang)
    # waving arm
    hand2 = (cx + 1.6 * R, cy - 0.42 * R)
    arm_to(back, (cx + 0.8 * R, cy + 0.15 * R), (hand2[0] - 0.02 * R, hand2[1] + 0.3 * R), R, (0.5, 0.05), (0.05, 0.35))
    front += glove_open(hand2[0], hand2[1] - 0.05 * R, 0.46 * R, ang=18)
    body = ball_body(cx, cy, R, face_box=(cx - 0.62 * R, cy - 0.45 * R, cx + 0.62 * R, cy + 0.7 * R))
    return back + body + face(cx, cy, R) + santa_hat(cx, cy, R) + front


def design_merry() -> bytes:
    art = Art()
    # "Merry": cream script, red extrusion, arched
    merry = text_layer("Merry", "lobster", fit_size("Merry", "lobster", 2700), CREAM, shadow=RED, shadow_dist=55)
    merry = warp_arc(merry, 230, up=True)
    art.paste_center(merry, W / 2, 110)
    mh = merry.height / SCALE
    # sparkles and snow around the character
    deco = [sparkle(520, 1650, 150), sparkle(3980, 1500, 120), sparkle(700, 3550, 110), sparkle(3900, 3450, 150),
            snowflake(380, 2550, 120), snowflake(4140, 2550, 135, ang=15), sparkle(330, 1150, 85), sparkle(4200, 1050, 95)]
    for p in deco:
        art.part(p)
    R = 860
    cy = 110 + mh + 1.5 * R - 40
    # "DINKMAS": fat retro block, lime with red extrusion, gentle smile curve; the mascot stands on it
    dk = text_layer("DINKMAS", "shrikhand", fit_size("DINKMAS", "shrikhand", 3700), LIME, shadow=RED, shadow_dist=75)
    dk = warp_arc(dk, 160, up=False)
    feet_bottom = cy + 1.48 * R + 0.56 * 0.64 * R
    art.paste_center(dk, W / 2, feet_bottom - 210)
    art.figure(mascot_merry(W / 2, cy, R))
    return art


def ribbon_layer(text, fname, band_w, band_h, fill=RED, text_color=CREAM, arc=0.0, tail_w=None, fold=INK,
                 tracking=0.0):
    """Retro ribbon banner with notched tails and the text on the band. Returns a SCALE-res layer."""
    tail_w = tail_w or band_h * 1.05
    drop = band_h * 0.32
    tuck = band_h * 0.45
    pad = OW + CW + 20
    lw, lh = int(band_w + 2 * tail_w - 2 * tuck + 2 * pad), int(band_h + drop + 2 * pad)
    lay = Art(lw, lh)
    x0, y0 = pad + tail_w - tuck, pad
    x1 = x0 + band_w
    notch = band_h * 0.32
    tails = []
    for side in (-1, 1):
        if side < 0:
            ox = pad
            pts = [(ox, y0 + drop), (ox + tail_w, y0 + drop), (ox + tail_w, y0 + drop + band_h), (ox, y0 + drop + band_h),
                   (ox + notch, y0 + drop + band_h / 2)]
        else:
            ox = x1 + tuck - tail_w + tail_w - tuck
            ox = x1 - tuck
            pts = [(ox, y0 + drop), (ox + tail_w, y0 + drop), (ox + tail_w - notch, y0 + drop + band_h / 2),
                   (ox + tail_w, y0 + drop + band_h), (ox, y0 + drop + band_h)]
        tails.append(Part([poly(pts)], fill))
    folds = [Part([poly([(x0, y0 + band_h), (x0 + tuck, y0 + band_h + drop), (x0 + tuck, y0 + band_h)])], fold),
             Part([poly([(x1, y0 + band_h), (x1 - tuck, y0 + band_h + drop), (x1 - tuck, y0 + band_h)])], fold)]
    band = Part([poly([(x0, y0), (x1, y0), (x1, y0 + band_h), (x0, y0 + band_h)])], fill)
    lay.figure(tails + folds + [band])
    size = fit_size(text, fname, band_w - 2.2 * band_h * 0.5, tracking)
    f = font(fname, 1000)
    asc_box = f.getbbox(text, anchor="ls")
    cap_h = -asc_box[1] / 1000 * size
    size = min(size, 0.62 * band_h / (cap_h / size))
    t = text_layer(text, fname, size, text_color, ow=0, contour=None, tracking=tracking * size / 1000)
    lay.paste(t, (x0 + x1) / 2 - t.width / SCALE / 2, y0 + band_h / 2 - t.height / SCALE / 2)
    img = lay.img
    if arc:
        img = warp_arc(img, arc, up=True)
    return img.crop(img.getbbox())


# ------------------------------------------------------------------ design 2: Dashing Through the Kitchen
def antler(cx, cy, R, side, color=GOLD):
    """One branching antler rooted on top of the ball; side=-1 left, +1 right."""
    b0 = (cx + side * 0.3 * R, cy - 0.8 * R)
    beam = bez(b0, (b0[0] + side * 0.05 * R, b0[1] - 0.45 * R), (b0[0] + side * 0.45 * R, b0[1] - 0.6 * R),
               (b0[0] + side * 0.62 * R, b0[1] - 0.85 * R), 20)
    w = 0.12 * R
    t1s = beam[7]
    t2s = beam[13]
    tine1 = qbez(t1s, (t1s[0] - side * 0.05 * R, t1s[1] - 0.22 * R), (t1s[0] - side * 0.02 * R, t1s[1] - 0.36 * R), 10)
    tine2 = qbez(t2s, (t2s[0] + side * 0.02 * R, t2s[1] - 0.2 * R), (t2s[0] - side * 0.06 * R, t2s[1] - 0.32 * R), 10)
    return Part([line(beam, w), line(tine1, w * 0.9), line(tine2, w * 0.85)], color)


def motion_lines(x_right, ys_lens, w=46, color=CREAM):
    return Part([line([(x_right - ln, y), (x_right, y)], w) for y, ln in ys_lens], color, ow=0, contour=False)


def puff(cx, cy, r, color=CREAM):
    return Part([circle(cx, cy, r), circle(cx - 0.8 * r, cy + 0.25 * r, 0.7 * r), circle(cx + 0.85 * r, cy + 0.2 * r, 0.75 * r),
                 circle(cx + 0.1 * r, cy + 0.45 * r, 0.7 * r)], color, ow=OW)


def mascot_dashing(cx, cy, R):
    back, front = [], []
    # back leg kicked out behind, front leg reaching forward
    hipb, ankb = (cx - 0.25 * R, cy + 0.85 * R), (cx - 1.0 * R, cy + 1.12 * R)
    back.append(limb(bez(hipb, (hipb[0] - 0.05 * R, hipb[1] + 0.45 * R), (ankb[0] + 0.35 * R, ankb[1] + 0.25 * R), ankb, 24), R))
    back += sneaker(ankb[0], ankb[1], 0.6 * R, ang=38)
    hipf, ankf = (cx + 0.3 * R, cy + 0.82 * R), (cx + 0.98 * R, cy + 1.28 * R)
    back.append(limb(bez(hipf, (hipf[0] + 0.45 * R, hipf[1] + 0.05 * R), (ankf[0] - 0.25 * R, ankf[1] - 0.45 * R), ankf, 24), R))
    back += sneaker(ankf[0], ankf[1], 0.6 * R, ang=-8)
    # antlers behind the head
    back += [antler(cx, cy, R, -1), antler(cx, cy, R, 1)]
    # back arm swinging behind with an open glove
    hb = (cx - 1.42 * R, cy + 0.12 * R)
    arm_to(back, (cx - 0.8 * R, cy + 0.2 * R), (hb[0] + 0.14 * R, hb[1] + 0.12 * R), R, (-0.3, 0.25), (0.25, 0.15))
    front += glove_open(hb[0], hb[1], 0.42 * R, ang=-118)
    # paddle arm reaching forward
    hand, ang, u = (cx + 1.45 * R, cy - 0.18 * R), 30, 0.48 * R
    cuff = fist_cuff(hand, u, ang + 180, flip=False)
    wx, wy = math.cos(math.radians(ang + 180)), math.sin(math.radians(ang + 180))
    arm_to(back, (cx + 0.8 * R, cy + 0.18 * R), cuff, R, (0.35, 0.15), (0.3 * wx, 0.3 * wy))
    pad = paddle(hand[0], hand[1], ang, 1.45 * R, face=RED, trim=CREAM, grip=GREEN)
    front += pad["face"] + pad["handle"] + glove_fist(hand[0], hand[1], u, ang + 180)
    body = ball_body(cx, cy, R, face_box=(cx - 0.5 * R, cy - 0.45 * R, cx + 0.75 * R, cy + 0.7 * R))
    return back + body + face(cx, cy, R, look=(0.12, 0.0), nose=RED) + front


def design_dashing() -> Art:
    art = Art()
    top = 110
    dash = text_layer("DASHING", "racing", fit_size("DASHING", "racing", 3650), CREAM, shadow=RED, shadow_dist=70)
    dash = warp_arc(dash, 210, up=True)
    art.paste_center(dash, W / 2, top)
    dash_bottom = top + dash.height / SCALE
    R = 720
    cx, cy = W / 2 + 110, dash_bottom + 1.95 * R - 40
    # motion lines and snow behind the runner
    art.part(motion_lines(cx - 1.75 * R, [(cy - 0.55 * R, 520), (cy - 0.12 * R, 780), (cy + 0.32 * R, 460)]))
    for p in [snowflake(430, cy - 1.15 * R, 120), snowflake(4140, cy - 0.35 * R, 115, ang=15), sparkle(4060, cy + 0.75 * R, 120),
              sparkle(380, cy + 0.85 * R, 100), sparkle(3700, cy - 1.75 * R, 80), sparkle(820, cy - 1.75 * R, 70)]:
        art.part(p)
    rib_top = cy + 1.66 * R
    rib = ribbon_layer("THROUGH THE", "bowlby", 2500, 400, arc=70, tracking=60)
    kit = text_layer("KITCHEN", "racing", fit_size("KITCHEN", "racing", 3750), LIME, shadow=RED, shadow_dist=75)
    kit = warp_arc(kit, 150, up=False)
    art.paste_center(kit, W / 2, rib_top + rib.height / SCALE - 150)
    art.paste_center(rib, W / 2, rib_top)
    # snow puffs kicked up behind the back foot
    art.figure([puff(cx - 1.55 * R, cy + 1.42 * R, 90), puff(cx - 2.0 * R, cy + 1.58 * R, 66)])
    art.figure(mascot_dashing(cx, cy, R))
    return art


def preview(art: Art, name: str, shirt="#1B1B1D", seed=1, distress_amount=1.0):
    png = art.finish(seed=seed, distress_amount=distress_amount)
    scratch = Path(os.environ.get("SCRATCH", "/tmp"))
    img = Image.open(io.BytesIO(png))
    bg = Image.new("RGBA", img.size, shirt)
    bg.alpha_composite(img)
    bg.convert("RGB").resize((900, 1080), Image.LANCZOS).save(scratch / f"{name}_view.png")
    m = make_mockup(png, shirt)
    (scratch / f"{name}_mock.png").write_bytes(m)
    Image.open(io.BytesIO(m)).resize((300, 330), Image.LANCZOS).save(scratch / f"{name}_thumb.png")
    return png
