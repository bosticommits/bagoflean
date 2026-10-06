"""Round 4: evergreen gift tees with retro rubber-hose pickleball mascots.

Usage:
    python scripts/round4_evergreen.py                 # all designs, print quality (2x supersampled)
    python scripts/round4_evergreen.py --preview       # fast low-res previews into --out (default: scratch)
    python scripts/round4_evergreen.py --only kitchen-staff-only-chef

Writes designs-round-4/<slug>/design.png (4500x5400, transparent, 300 DPI),
mockup.png and listing.json.

How the drawing works
- Everything is laid out in print-file units (4500x5400) and drawn with PIL at
  `ss` times that size (2x for print), then reduced, so edges are anti-aliased
  while fills stay flat solid colours.
- Characters are built from simple shapes. `ink()` draws every shape's outline
  first and then every fill, so a group gets one clean outer contour.
- `finish()` crops the artwork, fits it to ~87% of the shirt width at the top,
  punches a subtle binary speck/scratch texture out of the ink and cleans the
  alpha so only edge pixels are partially transparent.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import random
import sys
from contextlib import contextmanager
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from etsy_agent.compliance import AI_DISCLOSURE, listing_problems  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from etsy_agent.render import make_mockup  # noqa: E402

OUT = ROOT / "designs-round-4"
FONTS = ROOT / "fonts"
W, H = 4500, 5400

NAVY, CORAL, TEAL, LIME, CREAM, WHITE = "#1D2B45", "#E76F51", "#2A9D8F", "#D9F03C", "#FBF3E4", "#FFFFFF"
HOLE = "#A9C12B"  # darker lime for the ball's holes

# Comfort Colors 1717 garment colours (approximate hex, for mockups only)
CC = {
    "Ivory": "#F1EAD7", "Butter": "#F5E2A0", "Chalky Mint": "#B4DCCD", "Blossom": "#F2C5CE",
    "Pepper": "#4E4B49", "Navy": "#2C3651", "Black": "#232323", "Blue Spruce": "#2F4E48",
}
LIGHT = ["Ivory", "Butter", "Chalky Mint", "Blossom"]
DARK = ["Pepper", "Navy", "Black", "Blue Spruce"]


# --------------------------------------------------------------------------- canvas
class Layer:
    """An RGBA image addressed in print-file units, scaled by `ss`."""

    def __init__(self, box, ss):
        x0, y0, x1, y1 = box
        self.ox, self.oy, self.ss = x0, y0, ss
        self.img = Image.new("RGBA", (max(1, round((x1 - x0) * ss)), max(1, round((y1 - y0) * ss))), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def p(self, x, y):
        return ((x - self.ox) * self.ss, (y - self.oy) * self.ss)

    def k(self, v):
        return v * self.ss

    def sub(self, box):
        return Layer(box, self.ss)

    def put(self, other: "Layer"):
        composite(self.img, other.img, round((other.ox - self.ox) * self.ss), round((other.oy - self.oy) * self.ss))

    def put_img(self, img, cx, cy):
        """Paste an ss-scaled image centred on (cx, cy) in print units."""
        px, py = self.p(cx, cy)
        composite(self.img, img, round(px - img.width / 2), round(py - img.height / 2))

    def put_img_top(self, img, cx, top):
        px, py = self.p(cx, top)
        composite(self.img, img, round(px - img.width / 2), round(py))


def composite(dst, src, dx, dy):
    sx0, sy0 = max(0, -dx), max(0, -dy)
    dx0, dy0 = max(0, dx), max(0, dy)
    w = min(src.width - sx0, dst.width - dx0)
    h = min(src.height - sy0, dst.height - dy0)
    if w > 0 and h > 0:
        dst.alpha_composite(src, (dx0, dy0), (sx0, sy0, sx0 + w, sy0 + h))


def rot(px, py, cx, cy, deg):
    a = math.radians(deg)
    dx, dy = px - cx, py - cy
    return (cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a))


def bezier(p0, p1, p2, n=48):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def bezier3(p0, p1, p2, p3, n=60):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


# --------------------------------------------------------------------------- shapes
class Shape:
    def draw(self, L, fill, g=0, d=None):
        raise NotImplementedError


class Ell(Shape):
    def __init__(self, cx, cy, rx, ry=None, ang=0):
        self.cx, self.cy, self.rx, self.ry, self.ang = cx, cy, rx, rx if ry is None else ry, ang

    def pts(self, g=0, n=180):
        out = []
        for i in range(n):
            t = 2 * math.pi * i / n
            out.append(rot(self.cx + (self.rx + g) * math.cos(t), self.cy + (self.ry + g) * math.sin(t), self.cx, self.cy, self.ang))
        return out

    def draw(self, L, fill, g=0, d=None):
        (d or L.d).polygon([L.p(*q) for q in self.pts(g)], fill=fill)


class RR(Shape):
    """Rounded rectangle centred at (cx, cy), rotated by ang degrees (clockwise)."""

    def __init__(self, cx, cy, w, h, r, ang=0):
        self.cx, self.cy, self.w, self.h, self.r, self.ang = cx, cy, w, h, r, ang

    def pts(self, g=0, n=14):
        w, h = self.w + 2 * g, self.h + 2 * g
        r = min(self.r + g, w / 2, h / 2)
        out = []
        for qx, qy, a0 in ((w / 2 - r, -h / 2 + r, -90), (w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180)):
            for i in range(n + 1):
                t = math.radians(a0 + 90 * i / n)
                out.append(rot(self.cx + qx + r * math.cos(t), self.cy + qy + r * math.sin(t), self.cx, self.cy, self.ang))
        return out

    def draw(self, L, fill, g=0, d=None):
        (d or L.d).polygon([L.p(*q) for q in self.pts(g)], fill=fill)


class Poly(Shape):
    def __init__(self, pts):
        self.pts_ = list(pts)

    def draw(self, L, fill, g=0, d=None):
        d = d or L.d
        P = [L.p(*q) for q in self.pts_]
        d.polygon(P, fill=fill)
        if g > 0:
            gw = L.k(g)
            d.line(P + [P[0]], fill=fill, width=max(1, round(2 * gw)), joint="curve")
            for x, y in P:
                d.ellipse((x - gw, y - gw, x + gw, y + gw), fill=fill)


class Tube(Shape):
    """A round-capped stroke along a polyline (limbs, swooshes)."""

    def __init__(self, pts, width):
        self.pts_, self.w = list(pts), width

    def draw(self, L, fill, g=0, d=None):
        d = d or L.d
        P = [L.p(*q) for q in self.pts_]
        wd = L.k(self.w + 2 * g)
        d.line(P, fill=fill, width=max(1, round(wd)), joint="curve")
        for x, y in (P[0], P[-1]):
            d.ellipse((x - wd / 2, y - wd / 2, x + wd / 2, y + wd / 2), fill=fill)


def heart_pts(cx, cy, size, ang=0, n=160):
    """Heart about `size` wide, centred on (cx, cy)."""
    raw = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        raw.append((x, y))
    s = size / 33.0
    return [rot(cx + x * s, cy + (y + 1.5) * s, cx, cy, ang) for x, y in raw]


def star_pts(cx, cy, r_out, r_in, n, ang=0):
    out = []
    for i in range(2 * n):
        a = math.radians(ang - 90 + i * 180 / n)
        r = r_out if i % 2 == 0 else r_in
        out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


OW = 26  # standard outline width in print pixels


def ink(L, parts, ow=OW, oc=NAVY):
    """Draw a group: all outlines (grown shapes) first, then all fills in order."""
    for shp, _ in parts:
        shp.draw(L, oc, ow)
    for shp, fill in parts:
        if fill:
            shp.draw(L, fill, 0)


def line(L, pts, width, color):
    Tube(pts, width).draw(L, color)


@contextmanager
def clipped(L, box, shape: Shape):
    """Draw into a temporary layer that is clipped to `shape` before being merged."""
    sub = L.sub(box)
    yield sub
    m = Image.new("L", sub.img.size, 0)
    shape.draw(sub, 255, 0, d=ImageDraw.Draw(m))
    sub.img.putalpha(ImageChops.multiply(sub.img.getchannel("A"), m))
    L.put(sub)


def silhouette(img, color):
    out = Image.new("RGBA", img.size, color)
    out.putalpha(img.getchannel("A"))
    return out


def halo(img, radius_px, color):
    """Return img on top of a solid rounded outline `radius_px` (image pixels) wide."""
    pad = int(radius_px * 1.6) + 4
    big = Image.new("L", (img.width + 2 * pad, img.height + 2 * pad), 0)
    big.paste(img.getchannel("A"), (pad, pad))
    f = 4
    small = big.resize((big.width // f, big.height // f), Image.BOX)
    small = small.filter(ImageFilter.GaussianBlur(radius_px / f / 1.45))
    small = small.point(lambda v: 255 if v > 18 else 0)
    mask = small.resize(big.size, Image.BICUBIC).point(lambda v: 255 if v > 127 else 0)
    out = Image.new("RGBA", big.size, color)
    out.putalpha(mask)
    out.alpha_composite(img, (pad, pad))
    return out


def extrude(img, dx, dy, color, steps=None):
    """Solid block shadow: the silhouette repeated along (dx, dy) under the image."""
    steps = steps or max(1, int(max(abs(dx), abs(dy)) / 3))
    out = Image.new("RGBA", (img.width + abs(dx), img.height + abs(dy)), (0, 0, 0, 0))
    sil = silhouette(img, color)
    ox, oy = (0 if dx >= 0 else -dx), (0 if dy >= 0 else -dy)
    for i in range(steps, 0, -1):
        out.alpha_composite(sil, (ox + round(dx * i / steps), oy + round(dy * i / steps)))
    out.alpha_composite(img, (ox, oy))
    return out


# --------------------------------------------------------------------------- text
def font(name, px):
    return ImageFont.truetype(str(FONTS / name), max(1, round(px)))


def text_img(L, s, fname, size, fill, stroke=0, sfill=NAVY, track=0):
    """Render text at layer scale, tightly cropped. Sizes are in print units."""
    f = font(fname, L.k(size))
    sw = round(L.k(stroke))
    tr = L.k(track)
    chars = list(s) if track else [s]
    advs = [f.getlength(c) + tr for c in chars] if track else [f.getlength(s)]
    asc, desc = f.getmetrics()
    pad = sw + int(L.k(size) * 0.6)
    im = Image.new("RGBA", (int(sum(advs)) + 2 * pad, asc + desc + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for pass_ in ("stroke", "fill"):
        x = pad
        for c, a in zip(chars, advs):
            if pass_ == "stroke" and sw:
                d.text((x, pad + asc), c, font=f, fill=sfill, anchor="ls", stroke_width=sw, stroke_fill=sfill)
            elif pass_ == "fill":
                d.text((x, pad + asc), c, font=f, fill=fill, anchor="ls")
            x += a
    return im.crop(im.getbbox())


def arc_text(L, s, fname, size, cx, cy, radius, fill, stroke=0, sfill=NAVY, track=0, up=True):
    """Text along a circle. up=True: convex arch above (cx, cy); False: smile below."""
    f = font(fname, L.k(size))
    sw = round(L.k(stroke))
    rr = L.k(radius)
    advs = [f.getlength(c) + L.k(track) for c in s]
    advs[-1] -= L.k(track)
    total = sum(advs)
    cap = f.getbbox("H", anchor="ls")
    cap_h = -cap[1]
    asc, desc = f.getmetrics()
    hh = asc + desc + sw * 2
    size_px = int(2 * (rr + hh) + 10)
    strokes = Image.new("RGBA", (size_px, size_px), (0, 0, 0, 0))
    fills = Image.new("RGBA", (size_px, size_px), (0, 0, 0, 0))
    c0 = size_px / 2
    pos = -total / 2
    for c, a in zip(s, advs):
        theta = (pos + (a - (L.k(track) if c != s[-1] else 0)) / 2) / rr
        pos += a
        if c == " ":
            continue
        cw = int(f.getlength(c)) + 2 * sw + 4
        for layer, (fc, w_) in ((strokes, (sfill, sw)), (fills, (fill, 0))):
            if layer is strokes and not sw:
                continue
            ci = Image.new("RGBA", (cw, int(2 * hh)), (0, 0, 0, 0))
            ImageDraw.Draw(ci).text((sw + 2, hh + cap_h / 2), c, font=f, fill=fc, anchor="ls",
                                    stroke_width=w_, stroke_fill=fc)
            deg = math.degrees(theta)
            ci = ci.rotate(-deg if up else deg, resample=Image.BICUBIC, expand=True)
            x = c0 + rr * math.sin(theta)
            y = c0 - rr * math.cos(theta) if up else c0 + rr * math.cos(theta)
            composite(layer, ci, round(x - ci.width / 2), round(y - ci.height / 2))
    strokes.alpha_composite(fills)
    box = strokes.getbbox()
    out = strokes.crop(box)
    # centre of the circle relative to the crop, so callers can place it
    return out, (c0 - box[0], c0 - box[1])


def place_arc(L, arc, cx, cy):
    img, (ccx, ccy) = arc
    px, py = L.p(cx, cy)
    composite(L.img, img, round(px - ccx), round(py - ccy))


# --------------------------------------------------------------------------- props
def ribbon(L, cx, cy, width, band_h, fill, sag=0, tail=None, ow=OW, oc=NAVY):
    """A banner whose band follows a gentle curve (sag > 0 = smile). Returns the curve function."""
    tail = tail or band_h * 0.95

    def mid(x):
        u = (x - cx) / (width / 2)
        return cy + sag * (u * u)

    def band_poly(x0, x1, dy=0, n=40):
        top = [(x0 + (x1 - x0) * i / n, mid(x0 + (x1 - x0) * i / n) - band_h / 2 + dy) for i in range(n + 1)]
        bot = [(x, y + band_h) for x, y in reversed(top)]
        return top + bot

    for side in (-1, 1):
        xe = cx + side * width / 2
        xin = xe - side * tail * 0.55
        xout = xe + side * tail
        dy = band_h * 0.38
        ye = mid(xe) + dy
        pts = [(xin, ye - band_h / 2), (xout, ye - band_h / 2), (xout - side * tail * 0.38, ye), (xout, ye + band_h / 2), (xin, ye + band_h / 2)]
        ink(L, [(Poly(pts), fill)], ow, oc)
        fold = [(xe - side * 2, mid(xe) + band_h / 2), (xin, ye + band_h / 2), (xin, mid(xe) + band_h / 2)]
        ink(L, [(Poly(fold), oc)], ow * 0.5, oc)
    ink(L, [(Poly(band_poly(cx - width / 2, cx + width / 2)), fill)], ow, oc)
    return mid


def sparkle(L, cx, cy, r, color, ang=0):
    ink(L, [(Poly(star_pts(cx, cy, r, r * 0.28, 4, ang)), color)], 0)


# --------------------------------------------------------------------------- mascot parts
def ball_body(L, cx, cy, R, holes=True, skip=(), highlight=True, ow=OW):
    ink(L, [(Ell(cx, cy, R), LIME)], ow)
    if holes:
        for i in range(12):
            a = i * 30 + 15
            if any(abs(((a - s + 180) % 360) - 180) < 22 for s in skip):
                continue
            hx, hy = cx + 0.8 * R * math.sin(math.radians(a)), cy - 0.8 * R * math.cos(math.radians(a))
            ink(L, [(Ell(hx, hy, 0.058 * R), HOLE)], 0)
    if highlight:
        pts = [(cx + 0.84 * R * math.cos(math.radians(t)), cy + 0.84 * R * math.sin(math.radians(t))) for t in range(203, 236, 2)]
        line(L, pts, 0.065 * R, WHITE)


def ring_restroke(L, cx, cy, R, a0, a1, ow=OW):
    """Redraw part of the ball outline (PIL angles: 0 = 3 o'clock, clockwise)."""
    pts = [(cx + (R + ow / 2) * math.cos(math.radians(t)), cy + (R + ow / 2) * math.sin(math.radians(t)))
           for t in [a0 + (a1 - a0) * i / 40 for i in range(41)]]
    line(L, pts, ow, NAVY)


def pie_eye(L, x, y, R, look=(0.0, 0.0), sclera=True, scale=1.0):
    s = scale
    if sclera:
        ink(L, [(Ell(x, y, 0.125 * R * s, 0.18 * R * s), WHITE)], OW * 0.85)
    px, py = x + look[0] * R, y + look[1] * R
    rx, ry = 0.072 * R * s, 0.112 * R * s
    Ell(px, py, rx, ry).draw(L, NAVY)
    # the classic 1930s pie-cut highlight
    box = [*L.p(px - rx, py - ry), *L.p(px + rx, py + ry)]
    L.d.pieslice(box, 292, 332, fill=WHITE)


def closed_eye(L, x, y, R, happy=True):
    pts = [(x + 0.12 * R * math.cos(math.radians(t)), y + 0.06 * R * math.sin(math.radians(t)) * (-1 if happy else 1) + (0.03 * R if happy else 0))
           for t in range(180, 361, 10)]
    line(L, pts, 0.05 * R, NAVY)


def open_mouth(L, x, y, R, w=0.44, depth=0.26, tongue=True):
    mw, md = w * R, depth * R
    pts = [(x - mw / 2, y)] + [(x + mw / 2 * math.cos(math.radians(t)), y + md * math.sin(math.radians(t))) for t in range(180, -1, -6)]
    pts = [(x + mw / 2 * math.cos(math.radians(t)), y + md * math.sin(math.radians(t))) for t in range(0, 181, 6)]
    mouth = Poly(pts)
    ink(L, [(mouth, NAVY)], OW * 0.6)
    if tongue:
        with clipped(L, (x - mw, y - md, x + mw, y + 2 * md), mouth) as t:
            Ell(x + 0.04 * R, y + md * 0.95, mw * 0.3, md * 0.45).draw(t, CORAL)
    # little smile corners
    for sgn in (-1, 1):
        cxp = x + sgn * mw / 2
        line(L, [(cxp - sgn * 0.01 * R, y + 0.01 * R), (cxp + sgn * 0.05 * R, y - 0.05 * R)], 0.045 * R, NAVY)


def cheeks(L, cx, cy, R, dx=0.5, dy=0.14):
    for sgn in (-1, 1):
        Ell(cx + sgn * dx * R, cy + dy * R, 0.095 * R, 0.062 * R).draw(L, CORAL)


def limb(L, p0, p1, p2, width):
    Tube(bezier(p0, p1, p2), width).draw(L, NAVY)


def end_dir(p1, p2):
    return math.degrees(math.atan2(p2[1] - p1[1], p2[0] - p1[0]))


def cuff(L, x, y, ang, R):
    """Glove cuff at the wrist; ang = direction the arm points (degrees, 0 = right)."""
    ink(L, [(RR(x, y, 0.13 * R, 0.3 * R, 0.06 * R, ang), WHITE)], OW * 0.85)


def glove_fist(L, x, y, ang, R, knuckles=True):
    """Fist centred on (x, y); the arm arrives from direction ang+180."""
    a = math.radians(ang)
    cx_, cy_ = x - 0.16 * R * math.cos(a), y - 0.16 * R * math.sin(a)
    cuff(L, cx_, cy_, ang, R)
    ink(L, [(Ell(x, y, 0.17 * R, 0.16 * R, ang), WHITE)], OW * 0.85)
    if knuckles:
        for off in (-0.06, 0.06):
            px, py = rot(x + 0.05 * R, y + off * R, x, y, ang)
            qx, qy = rot(x + 0.13 * R, y + off * R, x, y, ang)
            line(L, [(px, py), (qx, qy)], 0.03 * R, NAVY)


def glove_open(L, x, y, ang, R, thumb_side=1):
    """Open waving glove; fingers point along ang."""
    a = math.radians(ang)
    wx, wy = x - 0.17 * R * math.cos(a), y - 0.17 * R * math.sin(a)
    cuff(L, wx, wy, ang, R)
    parts = [(Ell(x, y, 0.16 * R, 0.15 * R, ang), WHITE)]
    for fa in (-30, -10, 10, 30):
        b = math.radians(ang + fa)
        tip = (x + 0.3 * R * math.cos(b), y + 0.3 * R * math.sin(b))
        parts.append((Tube([(x, y), tip], 0.105 * R), WHITE))
    b = math.radians(ang + thumb_side * 78)
    parts.append((Tube([(x, y), (x + 0.24 * R * math.cos(b), y + 0.24 * R * math.sin(b))], 0.1 * R), WHITE))
    ink(L, parts, OW * 0.85)
    for fa in (-20, 0, 20):
        b = math.radians(ang + fa)
        line(L, [(x + 0.13 * R * math.cos(b), y + 0.13 * R * math.sin(b)), (x + 0.2 * R * math.cos(b), y + 0.2 * R * math.sin(b))], 0.028 * R, NAVY)


def glove_thumbs_up(L, x, y, R, side=-1):
    """Fist with thumb pointing up; arm arrives from below/side."""
    cuff(L, x - side * 0.02 * R, y + 0.19 * R, 90, R)
    ink(L, [(RR(x, y, 0.36 * R, 0.3 * R, 0.13 * R), WHITE),
            (Tube([(x + side * 0.06 * R, y - 0.08 * R), (x + side * 0.08 * R, y - 0.33 * R)], 0.12 * R), WHITE)], OW * 0.85)
    for yy in (-0.02, 0.07):
        line(L, [(x - 0.12 * R * -side, y + yy * R), (x + 0.1 * R * side, y + yy * R)], 0.028 * R, NAVY)


def shoe(L, x, y, facing, R, ang=0, sole=CORAL):
    """Cartoon sneaker; (x, y) is the ankle, facing = +1 right / -1 left."""
    f = facing

    def P(px, py):
        return rot(x + f * px * R, y + py * R, x, y, ang * f)

    upper = Ell(*P(0.14, 0.04), 0.33 * R, 0.215 * R, ang * f)
    ink(L, [(upper, WHITE)], OW)
    s_pts = [P(-0.15, 0.22), P(0.43, 0.22)]
    ink(L, [(Tube(s_pts, 0.1 * R), sole)], OW)
    for i in range(2):
        a, b = P(-0.02 + i * 0.1, -0.1), P(0.05 + i * 0.1, -0.02)
        line(L, [a, b], 0.035 * R, NAVY)


def paddle(L, hx, hy, ang, R, face=CORAL, grip=TEAL, heart=False, trim=CREAM, scale=1.0):
    """Paddle held at (hx, hy) (middle of the grip), pointing up, rotated ang degrees clockwise."""
    s = R * scale

    def P(px, py):
        return rot(hx + px * s, hy + py * s, hx, hy, ang)

    ink(L, [(RR(*P(0, -0.05), 0.16 * s, 0.5 * s, 0.06 * s, ang), grip)], OW)
    for i in range(3):
        a, b = P(-0.08, 0.06 - i * 0.12), P(0.08, 0.0 - i * 0.12)
        line(L, [a, b], 0.03 * s, NAVY)
    fc = P(0, -0.7)
    if heart:
        hp = heart_pts(*fc, 0.9 * s, ang)
        ink(L, [(Poly(hp), face)], OW)
        inner = heart_pts(fc[0], fc[1] - 0.0 * s, 0.68 * s, ang)
        line(L, inner + [inner[0]], 0.035 * s, trim)
    else:
        ink(L, [(RR(*fc, 0.66 * s, 0.8 * s, 0.3 * s, ang), face)], OW)
        inner = RR(*fc, 0.5 * s, 0.64 * s, 0.22 * s, ang).pts()
        line(L, inner + [inner[0]], 0.035 * s, trim)


def mini_ball(L, x, y, r, ow=OW * 0.8):
    ink(L, [(Ell(x, y, r), LIME)], ow)
    for a in range(0, 360, 60):
        Ell(x + 0.5 * r * math.cos(math.radians(a + 30)), y + 0.5 * r * math.sin(math.radians(a + 30)), 0.13 * r).draw(L, HOLE)
    Ell(x, y, 0.13 * r).draw(L, HOLE)


def motion_arcs(L, cx, cy, r0, a0, a1, n=3, gap=90, width=34, color=NAVY):
    for i in range(n):
        r = r0 + i * gap
        span = (a1 - a0) * (1 - 0.18 * i)
        pts = [(cx + r * math.cos(math.radians(t)), cy + r * math.sin(math.radians(t))) for t in
               [a0 + span * j / 30 for j in range(31)]]
        line(L, pts, width, color)


# --------------------------------------------------------------------------- finishing
def distress(img, seed, density=1.0):
    """Punch small speck and scratch holes (binary) out of the ink."""
    rnd = random.Random(seed)
    w, h = img.size
    sc = w / 4500 * (4500 / max(1, w)) * 1.0
    m = Image.new("L", img.size, 255)
    d = ImageDraw.Draw(m)
    unit = w / 4000  # image px per print px (art is ~4000 wide)
    area = w * h / (unit * unit)
    clusters = [(rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(150, 600) * unit) for _ in range(int(26 * density))]
    n = int(area / 9000 * density)
    for i in range(n):
        if i % 3 and clusters:
            cx, cy, spread = rnd.choice(clusters)
            x, y = rnd.gauss(cx, spread), rnd.gauss(cy, spread)
        else:
            x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        r = rnd.uniform(4.5, 10) * unit
        if rnd.random() < 0.5:
            d.ellipse((x - r, y - r * rnd.uniform(0.7, 1), x + r, y + r), fill=0)
        else:
            pts = [(x + r * rnd.uniform(0.7, 1.3) * math.cos(a), y + r * rnd.uniform(0.7, 1.3) * math.sin(a))
                   for a in [k * math.pi / 3 + rnd.uniform(-.3, .3) for k in range(6)]]
            d.polygon(pts, fill=0)
    for _ in range(int(area / 520000 * density)):
        x, y = rnd.uniform(0, w), rnd.uniform(0, h)
        ln, a = rnd.uniform(40, 120) * unit, rnd.uniform(0, math.pi)
        d.line([(x, y), (x + ln * math.cos(a), y + ln * math.sin(a))], fill=0, width=max(1, round(8.5 * unit)))
    del sc
    img.putalpha(ImageChops.multiply(img.getchannel("A"), m))
    return img


def finish(L: Layer, seed, width_frac=0.87, top=110, max_h=5150, texture=1.0) -> Image.Image:
    art = L.img
    box = art.getbbox()
    art = art.crop(box)
    scale = min(W * width_frac / art.width, (max_h - top) / art.height)
    tw, th = round(art.width * scale), round(art.height * scale)
    art = art.convert("RGBa").resize((tw * 2, th * 2), Image.BOX).convert("RGBA")
    if texture:
        art = distress(art, seed, texture)
    art = art.convert("RGBa").reduce(2).convert("RGBA")
    a = art.getchannel("A").point(lambda v: 0 if v < 28 else (255 if v > 228 else v))
    art.putalpha(a)
    # transparent pixels carry no colour
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(art, ((W - tw) // 2, top))
    return out


def png_bytes(img):
    buf = io.BytesIO()
    img.save(buf, format="PNG", dpi=(300, 300), optimize=True)
    return buf.getvalue()


# =========================================================================== designs
def grandma(ss):
    L = Layer((0, 0, W, H), ss)
    cx = W / 2
    # ---- arched headline
    arc = arc_text(L, "GRANDMA'S", "BowlbyOneSC-Regular.ttf", 600, 0, 0, 3100, CORAL, stroke=30, track=34)
    arc = (extrude(arc[0], 0, round(L.k(55)), NAVY), arc[1])
    place_arc(L, arc, cx, 3500)

    # ---- the mascot
    R = 760
    bx, by = cx - 140, 2330
    P = lambda x, y: (bx + x * R, by + y * R)  # noqa: E731
    # legs: a happy hop, one foot kicked out
    limb(L, P(-0.3, 0.88), P(-0.5, 1.42), P(-0.98, 1.34), 0.12 * R)
    limb(L, P(0.3, 0.9), P(0.36, 1.3), P(0.42, 1.62), 0.12 * R)
    shoe(L, *P(-0.98, 1.34), -1, R, ang=-18)
    shoe(L, *P(0.42, 1.62), 1, R)
    # balance arm with an open glove
    limb(L, P(-0.88, 0.0), P(-1.5, 0.12), P(-1.42, -0.42), 0.12 * R)
    glove_open(L, *P(-1.4, -0.56), -95, R, thumb_side=1)
    # paddle arm, mid-swing
    motion_arcs(L, *P(0.9, 0.1), 1.62 * R, 8, 42, n=3, gap=0.16 * R, width=0.055 * R)
    limb(L, P(0.88, 0.12), P(1.45, 0.35), P(1.52, -0.12), 0.12 * R)
    paddle(L, *P(1.55, -0.24), 52, R, face=CORAL)
    glove_fist(L, *P(1.55, -0.24), -50, R)
    # hair bun (behind the head)
    ink(L, [(Ell(*P(0.05, -1.17), 0.3 * R), WHITE)])
    line(L, [P(-0.12, -1.3), P(0.22, -1.07)], 0.05 * R, CORAL)  # hair stick
    # head/body
    ball_body(L, bx, by, R, skip=(345, 15, 45, 315, 285, 75))
    # hair cap above the headband
    cap = [(bx + R * math.cos(math.radians(t)), by + R * math.sin(math.radians(t))) for t in range(214, 327, 3)]
    curls = [(Ell(*P(0.98 * math.sin(math.radians(a)), -0.98 * math.cos(math.radians(a))), 0.17 * R), WHITE) for a in (-58, -32, -8, 16, 40, 62)]
    ink(L, [(Poly(cap), WHITE)] + curls)
    # sweatband
    band = Ell(bx, by, R)
    with clipped(L, (bx - R, by - R, bx + R, by + R), band) as t:
        pts = [P(x / 20, -0.55 + 0.1 * (1 - (x / 20) ** 2)) for x in range(-22, 23)]
        Tube(pts, 0.2 * R + 2 * OW).draw(t, NAVY)
        Tube(pts, 0.2 * R).draw(t, TEAL)
        line(t, pts, 0.03 * R, CREAM)
    ring_restroke(L, bx, by, R, 190, 230)
    ring_restroke(L, bx, by, R, 310, 350)
    # side curls poking out under the band
    for sgn in (-1, 1):
        ink(L, [(Ell(*P(sgn * 0.92, -0.28), 0.15 * R), WHITE), (Ell(*P(sgn * 0.98, -0.06), 0.13 * R), WHITE)])
    # cat-eye glasses
    for sgn in (-1, 1):
        ex, ey = P(sgn * 0.27, -0.1)
        tip = [P(sgn * 0.36, -0.24), P(sgn * 0.56, -0.36), P(sgn * 0.47, -0.12)]
        ink(L, [(Poly(tip), NAVY)], 6)
        ink(L, [(Ell(ex, ey, 0.2 * R, 0.19 * R), WHITE)], 0.05 * R)
        pie_eye(L, ex, ey, R, look=(0.04, -0.02), sclera=False, scale=1.05)
    line(L, bezier(P(-0.1, -0.14), P(0, -0.2), P(0.1, -0.14)), 0.045 * R, NAVY)
    cheeks(L, bx, by, R, dx=0.55, dy=0.18)
    open_mouth(L, *P(0.0, 0.2), R, w=0.42, depth=0.25)
    # pearl necklace
    with clipped(L, (bx - R, by - R, bx + R, by + R), band) as t:
        for i in range(-6, 7):
            x = i * 0.15
            y = 0.5 + 0.2 * (1 - (x / 0.9) ** 2)
            ink(t, [(Ell(*P(x, y), 0.07 * R), WHITE)], 14)
    ring_restroke(L, bx, by, R, 20, 160)
    # the ball she just smashed
    mini_ball(L, *P(2.95, -1.12), 0.2 * R)
    for k in range(3):
        a = P(2.66, -1.12 + (k - 1) * 0.16)
        b = P(2.5 + abs(k - 1) * 0.06, -1.12 + (k - 1) * 0.2)
        line(L, [a, b], 0.05 * R, NAVY)
    sparkle(L, *P(-2.0, -1.05), 0.2 * R, CORAL, 0)
    sparkle(L, *P(-1.75, 0.55), 0.12 * R, NAVY, 0)
    sparkle(L, *P(2.45, 0.45), 0.16 * R, CORAL, 0)

    # ---- script punchline
    t = text_img(L, "Got Game!", "Pacifico-Regular.ttf", 820, NAVY)
    t = extrude(t, round(L.k(28)), round(L.k(40)), CORAL)
    L.put_img_top(t, cx, 3800)
    return L


def headband(L, bx, by, R, y=-0.55, color=TEAL, sag=0.1, h=0.2):
    P = lambda x, yy: (bx + x * R, by + yy * R)  # noqa: E731
    with clipped(L, (bx - R, by - R, bx + R, by + R), Ell(bx, by, R)) as t:
        pts = [P(x / 20, y + sag * (1 - (x / 20) ** 2)) for x in range(-22, 23)]
        Tube(pts, h * R + 2 * OW).draw(t, NAVY)
        Tube(pts, h * R).draw(t, color)
        line(t, pts, 0.03 * R, CREAM)
    a = math.degrees(math.asin(max(-1, min(1, y + sag * 0.0))))
    ring_restroke(L, bx, by, R, 180 + a - 22, 180 + a + 22)
    ring_restroke(L, bx, by, R, 360 - a - 22, 360 - a + 22)


def knee_brace(L, x, y, R, ang=0):
    ink(L, [(RR(x, y, 0.27 * R, 0.4 * R, 0.1 * R, ang), TEAL)], OW)
    for dy in (-0.13, 0.13):
        a, b = rot(x - 0.135 * R, y + dy * R, x, y, ang), rot(x + 0.135 * R, y + dy * R, x, y, ang)
        line(L, [a, b], 0.035 * R, NAVY)
    ink(L, [(Ell(x, y, 0.07 * R), CREAM)], OW * 0.7)


def wobble(L, x, y, R, side):
    """Little tremble marks beside a knee."""
    for k in range(2):
        r = (0.22 + 0.13 * k) * R
        a0, a1 = (150, 210) if side < 0 else (-30, 30)
        pts = [(x + r * math.cos(math.radians(t)), y + r * math.sin(math.radians(t))) for t in range(a0, a1 + 1, 4)]
        line(L, pts, 0.045 * R, NAVY)


def sweat_drop(L, x, y, R):
    r = 0.075 * R
    pts = [(x + r * math.cos(math.radians(t)), y + r * math.sin(math.radians(t))) for t in range(-30, 211, 8)] + [(x, y - 2.3 * r)]
    ink(L, [(Poly(pts), WHITE)], OW * 0.8)


def plaster(L, x, y, R, ang):
    ink(L, [(RR(x, y, 0.36 * R, 0.13 * R, 0.06 * R, ang), CREAM)], OW * 0.7)
    ink(L, [(RR(x, y, 0.12 * R, 0.13 * R, 0.02 * R, ang), CORAL)], 0)


def knees(ss):
    L = Layer((0, 0, W, H), ss)
    cx = W / 2
    # ---- top line: script + block
    a = text_img(L, "My knees say", "Pacifico-Regular.ttf", 430, NAVY)
    b = text_img(L, "NO!", "Shrikhand-Regular.ttf", 640, CORAL, stroke=28)
    b = extrude(b, 0, round(L.k(45)), NAVY)
    gap = L.k(70)
    total = a.width + gap + b.width
    x0 = L.k(cx) - total / 2
    base = L.k(820)  # bottom alignment line (ss px)
    composite(L.img, a, round(x0), round(base - a.height - L.k(30)))
    composite(L.img, b, round(x0 + a.width + gap), round(base - b.height))

    # ---- mascot in a wobbly ready stance
    R = 700
    bx, by = cx, 1930
    P = lambda x, y: (bx + x * R, by + y * R)  # noqa: E731
    legs = []
    for sgn in (-1, 1):
        pts = bezier3(P(sgn * 0.3, 0.88), P(sgn * 0.95, 1.12), P(sgn * 0.92, 1.6), P(sgn * 0.62, 1.86))
        Tube(pts, 0.13 * R).draw(L, NAVY)
        legs.append(pts)
    for sgn in (-1, 1):
        shoe(L, *P(sgn * 0.62, 1.86), sgn, R)
    for sgn, pts in zip((-1, 1), legs):
        kx, ky = max(pts, key=lambda q: sgn * q[0])
        knee_brace(L, kx - sgn * 0.02 * R, ky, R, ang=sgn * 4)
        wobble(L, kx + sgn * 0.0 * R, ky, R, sgn)
    # thumbs-up arm (viewer left)
    limb(L, P(-0.88, 0.08), P(-1.45, 0.4), P(-1.32, -0.12), 0.12 * R)
    glove_thumbs_up(L, *P(-1.32, -0.28), R, side=1)
    # heart paddle arm (viewer right)
    limb(L, P(0.88, 0.08), P(1.45, 0.4), P(1.36, -0.1), 0.12 * R)
    paddle(L, *P(1.38, -0.22), 14, R, face=CORAL, heart=True)
    glove_fist(L, *P(1.38, -0.22), -76, R)
    # body
    ball_body(L, bx, by, R, skip=(15, 345, 255, 105))
    headband(L, bx, by, R, y=-0.6)
    for sgn in (-1, 1):
        pie_eye(L, *P(sgn * 0.24, -0.1), R, look=(0.025, -0.03))
        # determined brows
        line(L, [P(sgn * 0.36, -0.37 + 0.0), P(sgn * 0.13, -0.33)], 0.06 * R, NAVY)
    cheeks(L, bx, by, R, dx=0.47, dy=0.16)
    open_mouth(L, *P(0, 0.2), R, w=0.5, depth=0.3)
    sweat_drop(L, *P(-0.62, -0.32), R)
    plaster(L, *P(0.5, 0.52), R, -35)
    plaster(L, *P(0.5, 0.52), R, 35)
    # little hearts
    for hx, hy, hs, ha in ((2.25, -1.25, 0.26, 14), (2.5, -0.75, 0.18, 22), (-2.0, -0.9, 0.2, -16)):
        ink(L, [(Poly(heart_pts(*P(hx, hy), hs * R, ha)), CORAL)], OW * 0.8)

    # ---- bottom lines
    t1 = text_img(L, "My heart says", "Pacifico-Regular.ttf", 400, NAVY)
    L.put_img_top(t1, cx, 3440)
    arc = arc_text(L, "PICKLEBALL", "Shrikhand-Regular.ttf", 600, 0, 0, 5200, CORAL, stroke=28, track=10, up=False)
    arc = (extrude(arc[0], 0, round(L.k(45)), NAVY), arc[1])
    place_arc(L, arc, cx, 4080 - 5200)
    return L


def kitchen(ss):
    L = Layer((0, 0, W, H), ss)
    cx = W / 2
    arc = arc_text(L, "KITCHEN", "BowlbyOneSC-Regular.ttf", 640, 0, 0, 2300, CREAM, track=40)
    arc = (extrude(arc[0], 0, round(L.k(60)), CORAL), arc[1])
    place_arc(L, arc, cx, 2900)

    G = Layer((0, 0, W, H), ss)  # badge group, gets a cream halo
    dcx, dcy, dr = cx, 2330, 1080
    ink(G, [(Ell(dcx, dcy, dr), TEAL)], 34, NAVY)
    for i in range(48):
        a = math.radians(i * 7.5)
        Ell(dcx + (dr - 95) * math.cos(a), dcy + (dr - 95) * math.sin(a), 17).draw(G, CREAM)
    R = 600
    bx, by = cx - 60, 2470
    P = lambda x, y: (bx + x * R, by + y * R)  # noqa: E731
    # hand-on-hip arm
    limb(G, P(-0.9, 0.05), P(-1.62, 0.05), P(-1.02, 0.55), 0.12 * R)
    glove_fist(G, *P(-1.0, 0.56), 150, R)
    # flipping arm with the paddle as a spatula
    limb(G, P(0.88, 0.1), P(1.35, 0.35), P(1.42, -0.05), 0.12 * R)
    paddle(G, *P(1.45, -0.16), 62, R, face=CORAL)
    glove_fist(G, *P(1.45, -0.16), -28, R)
    ball_body(G, bx, by, R, skip=(345, 15, 255, 285, 75, 105))
    # chef hat
    hat = [(Ell(*P(-0.4, -1.32), 0.36 * R), WHITE), (Ell(*P(0.02, -1.52), 0.43 * R), WHITE),
           (Ell(*P(0.42, -1.3), 0.36 * R), WHITE), (RR(*P(0.0, -1.18), 0.95 * R, 0.5 * R, 0.1 * R), WHITE)]
    ink(G, hat)
    ink(G, [(RR(*P(0.0, -0.9), 1.02 * R, 0.34 * R, 0.08 * R), WHITE)])
    for x in (-0.25, 0.0, 0.25):
        line(G, [P(x, -1.08), P(x * 1.1, -1.32)], 0.035 * R, NAVY)
    # face: wink + curly mustache
    closed_eye(G, *P(-0.25, -0.38 + 0.12), R)
    pie_eye(G, *P(0.25, -0.24), R, look=(0.01, 0.0), scale=0.95)
    line(G, [P(-0.38, -0.5), P(-0.14, -0.47)], 0.055 * R, NAVY)
    line(G, [P(0.14, -0.5), P(0.38, -0.53)], 0.055 * R, NAVY)
    cheeks(G, bx, by, R, dx=0.5, dy=0.02)
    open_mouth(G, *P(0, 0.2), R, w=0.36, depth=0.22)
    for sgn in (-1, 1):
        pts = bezier3(P(0, 0.08), P(sgn * 0.22, 0.02), P(sgn * 0.42, 0.22), P(sgn * 0.5, 0.0))
        Tube(pts, 0.1 * R).draw(G, NAVY)
        Ell(*P(sgn * 0.47, 0.0), 0.065 * R).draw(G, NAVY)
    Ell(*P(0, 0.04), 0.08 * R, 0.06 * R).draw(G, NAVY)
    # the flipped ball and its arc
    fx, fy = P(2.15, -1.7)
    mini_ball(G, fx, fy, 0.24 * R)
    pts = bezier(P(1.5, -0.95), P(1.65, -1.75), P(1.85, -1.75), 20)
    for i in range(0, 20, 5):
        line(G, pts[i:i + 3], 0.05 * R, CREAM)
    sparkle(G, *P(2.65, -1.2), 0.14 * R, CREAM)
    sparkle(G, *P(-1.4, -1.3), 0.18 * R, CREAM)
    # ribbon
    ribbon_y = 3290
    ribbon(G, cx, ribbon_y, 3300, 430, CORAL, sag=-90, ow=30)
    G.img = halo(G.img, G.k(34), CREAM).crop((int(G.k(34) * 1.6) + 4, int(G.k(34) * 1.6) + 4, int(G.k(34) * 1.6) + 4 + G.img.width, int(G.k(34) * 1.6) + 4 + G.img.height))
    L.put(G)
    arc2 = arc_text(L, "STAFF ONLY", "BowlbyOneSC-Regular.ttf", 300, 0, 0, 3300 ** 2 / (8 * 90), CREAM, track=30, up=True)
    # The ribbon curves like a parabola with sag -90 over half-width 1650: approximate with a circle
    rad = 1650 ** 2 / (2 * 90)
    arc2 = arc_text(L, "STAFF ONLY", "BowlbyOneSC-Regular.ttf", 300, 0, 0, rad, CREAM, track=30, up=True)
    place_arc(L, arc2, cx, ribbon_y - 90 + rad + 15)
    sub = text_img(L, "NON-VOLLEY ZONE DEPT.", "BowlbyOneSC-Regular.ttf", 190, CREAM, track=22)
    L.put_img_top(sub, cx, 3720)
    for sgn in (-1, 1):
        sparkle(L, cx + sgn * (sub.width / L.ss / 2 + 150), 3720 + 95, 75, LIME)
    return L


def retired(ss):
    L = Layer((0, 0, W, H), ss)
    cx = W / 2
    t = text_img(L, "Retired.", "Lobster-Regular.ttf", 1000, CREAM)
    t = t.rotate(6, resample=Image.BICUBIC, expand=True)
    t = extrude(t, round(L.k(30)), round(L.k(45)), CORAL)
    L.put_img_top(t, cx, 120)

    G = Layer((0, 0, W, H), ss)
    R = 620
    bx, by = cx - 80, 2380
    P = lambda x, y: (bx + x * R, by + y * R)  # noqa: E731
    ink(G, [(Poly(star_pts(bx + 60, by + 80, 1.95 * R, 1.55 * R, 16, 6)), TEAL)], 30, CREAM)
    # legs: strolling
    limb(G, P(-0.3, 0.88), P(-0.5, 1.35), P(-0.72, 1.62), 0.12 * R)
    limb(G, P(0.3, 0.9), P(0.5, 1.3), P(0.5, 1.66), 0.12 * R)
    shoe(G, *P(-0.72, 1.62), -1, R, ang=8)
    shoe(G, *P(0.5, 1.66), 1, R)
    # paddle arm, low (ready to serve)
    limb(G, P(-0.88, 0.12), P(-1.4, 0.3), P(-1.42, 0.62), 0.12 * R)
    paddle(G, *P(-1.45, 0.72), -152, R, face=CORAL)
    glove_fist(G, *P(-1.45, 0.72), 100, R)
    # tray arm, up high like a waiter
    limb(G, P(0.88, 0.0), P(1.5, 0.05), P(1.45, -0.5), 0.12 * R)
    glove_open(G, *P(1.45, -0.62), -90, R, thumb_side=-1)
    ink(G, [(Ell(*P(1.5, -0.88), 0.68 * R, 0.15 * R), CREAM)])
    ring = Ell(*P(1.5, -0.9), 0.5 * R, 0.09 * R).pts()
    line(G, ring + [ring[0]], 0.03 * R, NAVY)
    mini_ball(G, *P(1.5, -1.25), 0.33 * R)
    sparkle(G, *P(2.15, -1.55), 0.15 * R, CREAM)
    sparkle(G, *P(0.92, -1.68), 0.11 * R, CREAM)
    ball_body(G, bx, by, R, skip=(345, 15, 45, 315, 165, 195))
    # visor
    with clipped(G, (bx - R, by - R, bx + R, by + R), Ell(bx, by, R)) as tt:
        pts = [P(x / 20, -0.58 + 0.08 * (1 - (x / 20) ** 2)) for x in range(-22, 23)]
        Tube(pts, 0.16 * R + 2 * OW).draw(tt, NAVY)
        Tube(pts, 0.16 * R).draw(tt, TEAL)
    ring_restroke(G, bx, by, R, 200, 240)
    ring_restroke(G, bx, by, R, 300, 340)
    brim = [P(0.82 * math.cos(math.radians(a)), -0.5 + 0.3 * math.sin(math.radians(a))) for a in range(0, 181, 5)]
    ink(G, [(Poly(brim), TEAL)])
    line(G, [P(0.6 * math.cos(math.radians(a)), -0.47 + 0.18 * math.sin(math.radians(a))) for a in range(20, 161, 5)], 0.03 * R, CREAM)
    # grandpa hair tufts
    for sgn in (-1, 1):
        ink(G, [(Ell(*P(sgn * 0.93, -0.32), 0.14 * R), WHITE), (Ell(*P(sgn * 1.0, -0.12), 0.12 * R), WHITE)])
    for sgn in (-1, 1):
        pie_eye(G, *P(sgn * 0.24, -0.02), R, look=(0.02, -0.01), scale=0.9)
    cheeks(G, bx, by, R, dx=0.5, dy=0.22)
    open_mouth(G, *P(0, 0.28), R, w=0.44, depth=0.24)
    # bow tie
    bt = [(Poly([P(0, 0.72), P(-0.3, 0.58), P(-0.3, 0.88)]), CORAL), (Poly([P(0, 0.72), P(0.3, 0.58), P(0.3, 0.88)]), CORAL)]
    ink(G, bt, OW * 0.9)
    ink(G, [(RR(*P(0, 0.72), 0.13 * R, 0.13 * R, 0.04 * R), CORAL)], OW * 0.9)
    pad = int(G.k(34) * 1.6) + 4
    G.img = halo(G.img, G.k(34), CREAM).crop((pad, pad, pad + G.img.width, pad + G.img.height))
    L.put(G)

    # ---- diner sign bottom
    ry = 3640
    R2 = ribbon(L, cx, ry, 2700, 400, CORAL, sag=0, ow=0)
    del R2
    t2 = text_img(L, "NOW SERVING", "BowlbyOneSC-Regular.ttf", 270, CREAM, track=30)
    L.put_img(t2, cx, ry)
    t3 = text_img(L, "FULL TIME", "BowlbyOneSC-Regular.ttf", 640, LIME, track=20)
    t3 = extrude(t3, 0, round(L.k(50)), CORAL)
    L.put_img_top(t3, cx, 3930)
    t4 = text_img(L, "OPEN 7 DAYS A WEEK", "BowlbyOneSC-Regular.ttf", 150, CREAM, track=30)
    L.put_img_top(t4, cx, 4720)
    for sgn in (-1, 1):
        sparkle(L, cx + sgn * (t4.width / L.ss / 2 + 120), 4720 + 75, 60, LIME)
    return L


DESIGNS = {
    "grandmas-got-game": dict(fn=grandma, seed=11, garments=LIGHT, mock="Blossom"),
    "knees-say-no-heart-says-pickleball": dict(fn=knees, seed=22, garments=LIGHT, mock="Chalky Mint"),
    "kitchen-staff-only-chef": dict(fn=kitchen, seed=33, garments=DARK, mock="Pepper"),
    "retired-now-serving-full-time": dict(fn=retired, seed=44, garments=DARK, mock="Blue Spruce"),
}


def build(slug, ss, outdir: Path, texture=1.0):
    spec = DESIGNS[slug]
    L = spec["fn"](ss)
    img = finish(L, spec["seed"], texture=texture)
    folder = outdir / slug
    folder.mkdir(parents=True, exist_ok=True)
    data = png_bytes(img)
    (folder / "design.png").write_bytes(data)
    (folder / "mockup.png").write_bytes(make_mockup(data, CC[spec["mock"]]))
    for g in spec["garments"]:
        (folder.parent / "_review").mkdir(exist_ok=True)
        (folder.parent / "_review" / f"{slug}-{g.replace(' ', '-').lower()}.png").write_bytes(make_mockup(data, CC[g], size=700))
    if "listing" in spec:
        listing = spec["listing"]
        problems = listing_problems(listing, PICKLEBALL.blocked_terms)
        if problems:
            raise SystemExit(f"{slug}: {problems}")
        (folder / "listing.json").write_text(json.dumps(listing, indent=2, ensure_ascii=False) + "\n")
    return folder


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--only")
    ap.add_argument("--out")
    a = ap.parse_args()
    ss = 0.5 if a.preview else 2
    outdir = Path(a.out) if a.out else OUT
    for slug in DESIGNS:
        if a.only and slug != a.only:
            continue
        print("built", build(slug, ss, outdir))


if __name__ == "__main__":
    main()
