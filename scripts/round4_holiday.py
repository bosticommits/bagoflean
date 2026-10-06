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
            d.line(T(pts + [pts[0]]), fill=color, width=max(1, int(round(2 * grow * s))), joint="curve")
            for x, y in pts:
                d.ellipse(((x - grow - ox) * s, (y - grow - oy) * s, (x + grow - ox) * s, (y + grow - oy) * s), fill=color)
    elif k == "line":
        pts, w = p[1], p[2]
        hw = w / 2 + grow
        d.line(T(pts), fill=color, width=max(1, int(round(2 * hw * s))), joint="curve")
        for x, y in (pts[0], pts[-1]):
            d.ellipse(((x - hw - ox) * s, (y - hw - oy) * s, (x + hw - ox) * s, (y + hw - oy) * s), fill=color)


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
    for _ in range(int(30 * amount)):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        if alpha[int(y), int(x)] == 0:
            continue
        ln = rng.uniform(120, 420) * s
        a = rng.uniform(0, math.pi)
        bend = rng.uniform(-0.25, 0.25) * ln
        p0 = (x - math.cos(a) * ln / 2, y - math.sin(a) * ln / 2)
        p2 = (x + math.cos(a) * ln / 2, y + math.sin(a) * ln / 2)
        p1 = (x - math.sin(a) * bend, y + math.cos(a) * bend)
        md.line(qbez(p0, p1, p2, 24), fill=255, width=int(rng.uniform(8, 11) * s), joint="curve")
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
    laces = [line([C(-0.05 + 0.12 * i, -0.08 + 0.05 * i), C(0.1 + 0.12 * i, -0.02 + 0.05 * i)], 0.06 * u) for i in range(3)]
    return [Part([upper], color), Part([toe], CREAM), Part(laces, CREAM, ow=0), Part([sole], CREAM)]


def paddle(gx, gy, ang, L, face=GREEN, trim=CREAM, grip=RED):
    """Paddle whose grip centre is (gx, gy), pointing at angle ang (0 = straight up). L = total length."""
    T = lambda pts: xf(pts, gx, gy, L, ang)  # noqa: E731
    C = lambda x, y: T([(x, y)])[0]  # noqa: E731
    handle = line([C(0, 0.14), C(0, -0.3)], 0.12 * L)
    outline = rrect_pts(0, -0.64, 0.62, 0.72, 0.24)
    face_p = poly(T(outline))
    clip = [poly(T(rrect_pts(0, -0.64, 0.62, 0.72, 0.24)))]
    stripe = poly(T([(-0.4, -0.5), (0.4, -0.86), (0.4, -0.74), (-0.4, -0.38)]))
    stripe2 = poly(T([(-0.4, -0.36), (0.4, -0.72), (0.4, -0.67), (-0.4, -0.31)]))
    cap = line([C(0, 0.15), C(0, 0.15)], 0.15 * L)
    return {
        "handle": [Part([handle], grip), Part([cap], INK, ow=0)],
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


def face(cx, cy, R, look=(0.0, 0.0), wink=False, mouth="grin"):
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
    return parts


def limb(pts, R, color=INK):
    return Part([line(pts, 0.115 * R)], color, ow=0)
