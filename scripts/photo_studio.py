"""Listing photos for Etsy: styled flat-lay scenes, colour options and a gift card.

Usage:
  python scripts/photo_studio.py <slug> [<slug> ...]     # writes photos/<slug>/
  python scripts/photo_studio.py --all                    # every design with a listing

For each design it renders, at 2400x1800 (4:3, Etsy's recommended ratio):
  1-hero.jpg      styled flat-lay on wood or linen with props (seasonal when relevant)
  2-closeup.jpg   close crop of the print on the fabric
  3-colors.jpg    the design on every colour offered
  4-gift.jpg      "why it makes a great gift" card with honest product facts
Mugs get a mug scene instead of the garment shots.

Everything is drawn procedurally (no stock photos), so it is free to use.
"""

from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
FONTS = ROOT / "fonts"
OUT = ROOT / "photos"
W, H = 2400, 1800

# Garment colour names -> RGB (Gildan 18000, Bella+Canvas 3001, Comfort Colors 1717)
GARMENT_RGB = {
    "Black": (28, 28, 30), "Navy": (31, 41, 66), "Forest Green": (32, 70, 50), "Forest": (34, 72, 52),
    "Maroon": (95, 30, 44), "Charcoal": (64, 66, 70), "Dark Heather": (66, 68, 72), "Asphalt": (70, 72, 76),
    "Sand": (216, 200, 172), "Ash": (214, 214, 210), "Light Blue": (170, 198, 228), "White": (244, 244, 241),
    "Natural": (238, 230, 212), "Light Pink": (240, 200, 210), "Military Green": (80, 85, 52),
    "Sand Dune": (210, 194, 166), "Soft Pink": (238, 198, 206), "Soft Cream": (240, 232, 214),
    # Comfort Colors garment-dyed tones
    "Ivory": (238, 230, 212), "Butter": (243, 228, 170), "Chalky Mint": (186, 222, 205), "Blossom": (240, 196, 205),
    "Pepper": (78, 78, 76), "Blue Spruce": (46, 80, 78), "Moss": (110, 116, 84), "Blue Jean": (110, 134, 160),
    "True Navy": (40, 48, 72), "Sage": (160, 172, 140),
}
DARK_BG_GARMENTS = set()


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


# ------------------------------------------------------------------ noise helpers
def smooth_noise(h: int, w: int, cell_h: float, cell_w: float, rng: np.random.Generator) -> np.ndarray:
    gh, gw = max(2, int(h / cell_h) + 2), max(2, int(w / cell_w) + 2)
    small = Image.fromarray((rng.random((gh, gw)) * 255).astype(np.uint8))
    big = small.resize((w, h), Image.BICUBIC)
    return np.asarray(big, dtype=np.float32) / 255.0


def fine_noise(h: int, w: int, rng: np.random.Generator) -> np.ndarray:
    return rng.random((h, w), dtype=np.float32)


# ------------------------------------------------------------------ backgrounds
def wood(rng) -> Image.Image:
    base = np.array([196, 158, 116], dtype=np.float32)
    plank_h = 300
    out = np.zeros((H, W, 3), np.float32)
    for top in range(-rng.integers(0, plank_h), H, plank_h):
        y0, y1 = max(top, 0), min(top + plank_h, H)
        if y1 <= y0:
            continue
        h = y1 - y0
        tone = 0.88 + 0.2 * rng.random()
        grain = smooth_noise(h, W, 6, 260, rng) * 0.55 + smooth_noise(h, W, 2, 60, rng) * 0.25
        streaks = 0.82 + 0.3 * grain
        out[y0:y1] = base * tone * streaks[..., None]
        out[y0:y0 + 6] *= 0.62  # seam
    out *= (0.96 + 0.06 * fine_noise(H, W, rng))[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def linen(rng, tint=(236, 230, 219)) -> Image.Image:
    base = np.array(tint, dtype=np.float32)
    weave = (np.sin(np.arange(W) * 1.9)[None, :] * np.sin(np.arange(H) * 1.9)[:, None]) * 0.012
    tex = 1 + weave + (fine_noise(H, W, rng) - 0.5) * 0.05 + (smooth_noise(H, W, 220, 220, rng) - 0.5) * 0.05
    return Image.fromarray(np.clip(base * tex[..., None], 0, 255).astype(np.uint8))


def light_and_vignette(img: Image.Image, warm: float = 0.03) -> Image.Image:
    a = np.asarray(img, np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = 1.06 - 0.12 * ((xx / W) * 0.6 + (yy / H) * 0.4)  # soft window light from top-left
    r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    vig = 1 - 0.18 * np.clip(r - 0.55, 0, 1) ** 1.5
    a = a * (light * vig)[..., None]
    a[..., 0] *= 1 + warm
    a[..., 2] *= 1 - warm
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


# ------------------------------------------------------------------ garments
def garment_mask(kind: str, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    """Flat-lay silhouette mask (L) on a canvas of `size`, plus layout info."""
    w, h = size
    s = 2  # supersample
    m = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(m)

    def P(x, y):
        return (x * w * s, y * h * s)

    if kind == "crewneck":
        body = [P(.40, .075), P(.60, .075), P(.735, .115), P(.82, .17), P(.90, .40), P(.975, .76), P(.86, .80),
                P(.775, .42), P(.765, .905), P(.235, .905), P(.225, .42), P(.14, .80), P(.025, .76), P(.10, .40),
                P(.18, .17), P(.265, .115)]
        d.polygon(body, fill=255)
        d.rounded_rectangle((*P(.228, .87), *P(.772, .94)), radius=24 * s, fill=255)   # waistband
        d.polygon([P(.025, .74), P(.135, .785), P(.12, .84), P(.005, .80)], fill=255)  # cuffs
        d.polygon([P(.975, .74), P(.865, .785), P(.88, .84), P(.995, .80)], fill=255)
        info = {"neck": (.5, .085, .10), "print": (.5, .22, .38), "ribs": [(.228, .87, .772)], "cuffs": True}
    else:  # tee
        body = [P(.40, .075), P(.60, .075), P(.73, .115), P(.86, .17), P(.975, .36), P(.85, .455), P(.775, .38),
                P(.78, .94), P(.5, .955), P(.22, .94), P(.225, .38), P(.15, .455), P(.025, .36), P(.14, .17),
                P(.27, .115)]
        d.polygon(body, fill=255)
        info = {"neck": (.5, .085, .10), "print": (.5, .215, .40), "ribs": [], "cuffs": False}
    # neck opening (front neckline dips lower than the back)
    cx, cy, r = info["neck"]
    d.ellipse((*P(cx - r, cy - .035), *P(cx + r, cy + .05)), fill=0)
    # round every corner like real fabric
    m = m.filter(ImageFilter.GaussianBlur(14 * s)).point(lambda v: 255 if v > 128 else 0)
    m = m.resize((w, h), Image.LANCZOS)
    return m, info


def render_garment(design: Image.Image, color, kind: str, size: tuple[int, int], rng,
                   print_scale: float = 1.0) -> Image.Image:
    """RGBA image of the garment with the design printed on it."""
    w, h = size
    mask, info = garment_mask(kind, size)
    ma = np.asarray(mask, np.float32) / 255.0
    dark = is_dark(color)

    # folds: long soft diagonals from the shoulders, crinkles near the hem, armpit creases
    layer = Image.new("L", (w, h), 128)
    d = ImageDraw.Draw(layer)
    for side in (-1, 1):
        for k in range(2):
            x0 = w * (0.5 + side * rng.uniform(.12, .2))
            y0 = h * rng.uniform(.14, .2)
            x1 = x0 + side * w * rng.uniform(.02, .1)
            y1 = h * rng.uniform(.55, .85)
            d.line((x0, y0, x1, y1), fill=int(128 + rng.uniform(20, 36)), width=int(w * rng.uniform(.03, .05)))
            d.line((x0 + side * w * .03, y0, x1 + side * w * .03, y1), fill=int(128 - rng.uniform(20, 34)),
                   width=int(w * rng.uniform(.02, .035)))
        ax = w * (0.5 + side * 0.27)
        d.line((ax, h * .36, ax - side * w * .06, h * .50), fill=96, width=int(.03 * w))
    for _ in range(6):
        x0 = rng.uniform(.25, .75) * w
        y0 = rng.uniform(.7, .88) * h
        d.line((x0, y0, x0 + rng.uniform(-.12, .12) * w, y0 + rng.uniform(.02, .06) * h),
               fill=int(128 + rng.choice([-1, 1]) * rng.uniform(16, 30)), width=int(.025 * w))
    layer = layer.filter(ImageFilter.GaussianBlur(w * 0.02))
    folds = (np.asarray(layer, np.float32) - 128) / 128.0

    inner = np.asarray(mask.filter(ImageFilter.GaussianBlur(w * 0.025)), np.float32) / 255.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    light = 1.05 - 0.10 * (xx / w * 0.5 + yy / h * 0.5)
    mottle = 1 + (smooth_noise(h, w, w * .09, w * .09, rng) - 0.5) * (0.04 if kind != "crewneck" else 0.025)
    tex = 1 + (fine_noise(h, w, rng) - 0.5) * 0.05
    shade = (0.78 + 0.22 * inner) * (1 + 0.26 * folds) * light * mottle * tex

    base = np.array(color, np.float32)
    rgb = base[None, None, :] * shade[..., None]
    # dark fabrics: add a soft sheen so folds are visible
    lift = (np.clip(folds, 0, 1) * (34 if dark else 10) + (inner - 0.5) * (10 if dark else 0))
    rgb += lift[..., None]

    # rib collar band and neck opening
    cx, cy, r = info["neck"]
    rib = Image.new("L", (w, h), 0)
    rd = ImageDraw.Draw(rib)
    rd.ellipse(((cx - r - .028) * w, (cy - .055) * h, (cx + r + .028) * w, (cy + .075) * h), fill=255)
    rd.ellipse(((cx - r) * w, (cy - .035) * h, (cx + r) * w, (cy + .05) * h), fill=0)
    rib_a = np.asarray(rib.filter(ImageFilter.GaussianBlur(2)), np.float32) / 255.0 * ma
    rgb = rgb * (1 - 0.10 * rib_a[..., None])
    opening = Image.new("L", (w, h), 0)
    ImageDraw.Draw(opening).ellipse(((cx - r) * w, (cy - .035) * h, (cx + r) * w, (cy + .05) * h), fill=255)
    op = np.asarray(opening.filter(ImageFilter.GaussianBlur(1.5)), np.float32) / 255.0
    back_collar = op * (yy < (cy - .005) * h)
    rgb = rgb * (1 - back_collar[..., None]) + (base * 0.93)[None, None, :] * back_collar[..., None]
    op = op * (yy >= (cy - .005) * h)
    inside = base * 0.78
    # shadow at the top of the opening (the back of the neck casts it)
    top_shadow = np.clip(1 - (yy - (cy - .005) * h) / (0.04 * h), 0, 1) * 0.4
    inside_rgb = inside[None, None, :] * (1 - top_shadow)[..., None]
    rgb = rgb * (1 - op[..., None]) + inside_rgb * op[..., None]
    ma = np.maximum(ma, np.maximum(op, back_collar))
    for (x0, y0, x1) in info["ribs"]:
        band = (yy > y0 * h) & (xx > x0 * w) & (xx < x1 * w)
        rgb[band] *= 0.92
        for k in range(int((x1 - x0) * w / 14)):
            xk = int(x0 * w + k * 14)
            rgb[band & (xx >= xk) & (xx < xk + 3)] *= 0.96

    # print the design: lit by the same shading, slightly displaced by folds
    art = design.convert("RGBA")
    art = art.crop(art.getchannel("A").getbbox())
    px, py, pw = info["print"]
    target_w = int(pw * w * print_scale)
    target_h = int(target_w * art.height / art.width)
    max_h = int(0.50 * h)
    if target_h > max_h:
        target_h = max_h
        target_w = int(target_h * art.width / art.height)
    art = art.resize((target_w, target_h), Image.LANCZOS)
    ox, oy = int(px * w - target_w / 2), int(py * h)
    arr = np.asarray(art, np.float32)
    region = shade[oy:oy + target_h, ox:ox + target_w]
    fy = folds[oy:oy + target_h, ox:ox + target_w]
    gy, gx = np.gradient(fy)
    grid_y, grid_x = np.mgrid[0:target_h, 0:target_w]
    sy = np.clip((grid_y + gy * 320).astype(int), 0, target_h - 1)
    sx = np.clip((grid_x + gx * 320).astype(int), 0, target_w - 1)
    arr = arr[sy, sx]
    ink = arr[..., :3] * np.clip(region, 0.72, 1.12)[..., None] * 0.96 + lift[oy:oy + target_h, ox:ox + target_w, None] * 0.5
    alpha = arr[..., 3:4] / 255.0 * 0.95
    rgb[oy:oy + target_h, ox:ox + target_w] = rgb[oy:oy + target_h, ox:ox + target_w] * (1 - alpha) + ink * alpha

    out = np.dstack([np.clip(rgb, 0, 255), ma * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def drop_shadow(canvas: Image.Image, obj: Image.Image, pos, offset=(22, 30), blur=34, strength=0.42):
    a = obj.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", obj.size, (25, 18, 10, 0))
    sh.putalpha(a.point(lambda v: int(v * strength)))
    canvas.alpha_composite(sh, (pos[0] + offset[0], pos[1] + offset[1]))
    canvas.alpha_composite(obj, pos)


# ------------------------------------------------------------------ props
def sphere(r: int, color, holes=True, rng=None) -> Image.Image:
    s = 2 * r + 4
    yy, xx = np.mgrid[0:s, 0:s].astype(np.float32)
    dx, dy = (xx - s / 2) / r, (yy - s / 2) / r
    d2 = dx * dx + dy * dy
    inside = d2 <= 1
    nz = np.sqrt(np.clip(1 - d2, 0, 1))
    lx, ly, lz = -0.45, -0.55, 0.7
    lam = np.clip(dx * lx + dy * ly + nz * lz, 0, 1)
    spec = np.clip(dx * lx + dy * ly + nz * lz, 0, 1) ** 28
    rgb = np.array(color, np.float32)[None, None, :] * (0.45 + 0.65 * lam)[..., None] + 255 * spec[..., None] * 0.45
    img = np.dstack([np.clip(rgb, 0, 255), inside * 255]).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    if holes:
        d = ImageDraw.Draw(im)
        hr = r * 0.11
        pts = [(0, 0)] + [(0.5 * math.cos(a), 0.5 * math.sin(a)) for a in [i * math.pi / 3 + 0.3 for i in range(6)]]
        pts += [(0.82 * math.cos(a), 0.82 * math.sin(a)) for a in [i * math.pi / 4 + 0.1 for i in range(8)]]
        for px, py in pts:
            if px * px + py * py > 0.72:
                k = 0.6
            else:
                k = 1.0
            cx, cy = s / 2 + px * r, s / 2 + py * r
            dark = tuple(int(c * 0.42) for c in color)
            d.ellipse((cx - hr * k, cy - hr, cx + hr * k, cy + hr), fill=dark + (255,))
    return im


def paddle(length: int, face=(31, 41, 66), edge=(20, 24, 30), accent=(231, 111, 81)) -> Image.Image:
    wface, hface = int(length * 0.42), int(length * 0.62)
    img = Image.new("RGBA", (wface + 40, length + 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    hx = img.width // 2
    hw = int(wface * 0.22)
    d.rounded_rectangle((hx - hw // 2, hface, hx + hw // 2, length + 20), radius=hw // 3, fill=(40, 40, 42, 255))
    for y in range(hface + 30, length + 10, 34):  # grip wrap
        d.line((hx - hw // 2, y, hx + hw // 2, y - 18), fill=(70, 70, 72, 255), width=8)
    d.rounded_rectangle((20, 20, 20 + wface, 20 + hface), radius=int(wface * 0.35), fill=edge + (255,))
    d.rounded_rectangle((32, 32, 8 + wface, 8 + hface), radius=int(wface * 0.32), fill=face + (255,))
    d.rounded_rectangle((32 + wface * .18, 32 + hface * .22, 8 + wface * .82, 8 + hface * .55), radius=40,
                        outline=accent + (255,), width=10)
    # soft sheen
    sheen = Image.new("L", img.size, 0)
    ImageDraw.Draw(sheen).ellipse((40, 40, 40 + wface * 0.55, 40 + hface * 0.4), fill=60)
    sheen = sheen.filter(ImageFilter.GaussianBlur(30))
    white = Image.new("RGBA", img.size, (255, 255, 255, 0))
    white.putalpha(Image.fromarray(np.minimum(np.asarray(sheen), np.asarray(img.getchannel("A")))))
    img.alpha_composite(white)
    return img


def pine_sprig(length: int, rng) -> Image.Image:
    img = Image.new("RGBA", (length, length), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x0, y0 = length * 0.1, length * 0.9
    x1, y1 = length * 0.85, length * 0.15
    steps = 26
    for i in range(steps):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for side in (-1, 1):
            for k in range(3):
                ang = math.atan2(y1 - y0, x1 - x0) + side * (0.9 + 0.12 * k)
                ln = length * (0.12 - 0.06 * t) * (1 - 0.1 * k)
                col = (24 + int(rng.integers(0, 20)), 70 + int(rng.integers(0, 30)), 40 + int(rng.integers(0, 20)), 255)
                d.line((x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln), fill=col, width=max(4, length // 120))
    d.line((x0, y0, x1, y1), fill=(92, 62, 40, 255), width=max(6, length // 80))
    for _ in range(4):
        bx, by = x0 + (x1 - x0) * rng.uniform(.3, .8), y0 + (y1 - y0) * rng.uniform(.3, .8)
        b = sphere(int(length * 0.03), (196, 28, 40), holes=False)
        img.alpha_composite(b, (int(bx), int(by)))
    return img


def coffee_cup(r: int) -> Image.Image:
    img = Image.new("RGBA", (int(r * 2.9), int(r * 2.2)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((r * 1.7, r * 0.72, r * 2.78, r * 1.48), outline=(232, 230, 224, 255), width=int(r * 0.2))
    img.alpha_composite(sphere(r, (246, 244, 238), holes=False), (0, 0))
    coffee = sphere(int(r * 0.78), (96, 60, 36), holes=False)
    img.alpha_composite(coffee, (int(r * 0.22), int(r * 0.22)))
    d.ellipse((r * 0.62, r * 0.55, r * 1.05, r * 0.78), fill=(170, 122, 84, 200))  # crema
    return img


# ------------------------------------------------------------------ scenes
def is_dark(rgb) -> bool:
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2] < 110


def garment_kind(ptype: str) -> str:
    return "crewneck" if ptype in ("crewneck",) else "tee"


def hero(design: Image.Image, ptype: str, color_name: str, season: str, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    rnd = random.Random(seed)
    rgb = GARMENT_RGB.get(color_name, (200, 200, 200))
    bg = linen(rng) if is_dark(rgb) else wood(rng)
    canvas = bg.convert("RGBA")
    # props behind / around
    if season == "christmas":
        for (x, y, rot, ln) in [(-120, -160, 20, 760), (1820, 1150, 200, 820), (1900, -200, 120, 620)]:
            sp = pine_sprig(ln, rng).rotate(rot, expand=True, resample=Image.BICUBIC)
            drop_shadow(canvas, sp, (x, y), offset=(10, 14), blur=12, strength=0.3)
    gsize = (1560, 1560)
    g = render_garment(design, rgb, garment_kind(ptype), gsize, rng)
    g = g.rotate(rnd.uniform(-2.5, 2.5), expand=True, resample=Image.BICUBIC)
    gx, gy = (W - g.width) // 2, (H - g.height) // 2 + 30
    drop_shadow(canvas, g, (gx, gy))
    # foreground props
    pad = paddle(820, face=(31, 41, 66) if not is_dark(rgb) else (231, 111, 81), accent=(217, 240, 60))
    pad = pad.rotate(-32, expand=True, resample=Image.BICUBIC)
    drop_shadow(canvas, pad, (W - pad.width + 150, H - pad.height + 120), offset=(16, 22), blur=18, strength=0.35)
    for (x, y, r) in [(150, 1380, 92), (330, 1500, 92)]:
        ball = sphere(r, (214, 236, 52))
        drop_shadow(canvas, ball, (x, y), offset=(12, 16), blur=10, strength=0.38)
    if season != "christmas":
        cup = coffee_cup(150)
        drop_shadow(canvas, cup, (90, 90), offset=(14, 18), blur=14, strength=0.35)
    else:
        for (x, y, r, c) in [(260, 260, 70, (196, 28, 40)), (2040, 760, 60, (214, 168, 64))]:
            drop_shadow(canvas, sphere(r, c, holes=False), (x, y), offset=(10, 14), blur=10, strength=0.35)
    out = light_and_vignette(canvas.convert("RGB"))
    blank_callout(out, ptype, (gx + g.width * 0.78, gy + g.height * 0.14))
    return out


BLANK_NAMES = {"crewneck": ("Gildan", "18000", "crewneck"), "tee": ("Bella+Canvas", "3001", "tee"),
               "tee-cc": ("Comfort", "Colors", "1717")}


def blank_callout(img: Image.Image, ptype: str, target: tuple[float, float]) -> None:
    """Round badge naming the real blank, with a hand-drawn arrow to the garment (truthful trust cue)."""
    if ptype not in BLANK_NAMES:
        return
    d = ImageDraw.Draw(img)
    cx, cy, r = W - 260, 250, 190
    d.ellipse((cx - r + 8, cy - r + 12, cx + r + 8, cy + r + 12), fill=(0, 0, 0))  # flat shadow, softened below
    shadow = img.crop((cx - r - 40, cy - r - 40, cx + r + 60, cy + r + 60)).filter(ImageFilter.GaussianBlur(14))
    img.paste(shadow, (cx - r - 40, cy - r - 40))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(52, 50, 48))
    lines = BLANK_NAMES[ptype]
    fnt = font("Righteous-Regular.ttf", 66)
    for i, line in enumerate(lines):
        size = 66
        while d.textlength(line, font=font("Righteous-Regular.ttf", size)) > r * 1.55 and size > 30:
            size -= 2
        d.text((cx, cy + (i - 1) * 78), line, font=font("Righteous-Regular.ttf", size), fill=(246, 242, 234), anchor="mm")
    # arrow: a gentle curve from under the badge towards the garment, with a two-stroke head
    sx, sy = cx - r * 0.55, cy + r * 0.95
    tx, ty = target
    pts = []
    for k in range(31):
        t = k / 30
        mx, my = (sx + tx) / 2 - 60, (sy + ty) / 2 + 80
        x = (1 - t) ** 2 * sx + 2 * (1 - t) * t * mx + t ** 2 * tx
        y = (1 - t) ** 2 * sy + 2 * (1 - t) * t * my + t ** 2 * ty
        pts.append((x, y))
    d.line(pts, fill=(52, 50, 48), width=9, joint="curve")
    (x1, y1), (x2, y2) = pts[-4], pts[-1]
    ang = math.atan2(y2 - y1, x2 - x1)
    for da in (2.6, -2.6):
        d.line((x2, y2, x2 + 46 * math.cos(ang + da), y2 + 46 * math.sin(ang + da)), fill=(52, 50, 48), width=9)


def closeup(design: Image.Image, ptype: str, color_name: str, seed: int) -> Image.Image:
    rgb = GARMENT_RGB.get(color_name, (200, 200, 200))
    g = render_garment(design, rgb, garment_kind(ptype), (3200, 3200), np.random.default_rng(seed + 7))
    # find where the print landed by diffing against the same garment without it,
    # then crop a 4:3 box that holds the whole print with a little margin
    blank = render_garment(Image.new("RGBA", design.size), rgb, garment_kind(ptype), (3200, 3200),
                           np.random.default_rng(seed + 7))
    diff = np.abs(np.asarray(g.convert("RGB"), dtype=np.int16) - np.asarray(blank.convert("RGB"), dtype=np.int16))
    ys, xs = np.nonzero(diff.max(axis=2) > 24)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    bw = max((x1 - x0) * 1.12, (y1 - y0) * 1.12 * W / H)
    bh = bw * H / W
    box = (int(cx - bw / 2), int(cy - bh / 2), int(cx + bw / 2), int(cy + bh / 2))
    crop = g.crop(box).resize((W, int(W * (box[3] - box[1]) / (box[2] - box[0]))), Image.LANCZOS)
    bg = Image.new("RGB", (W, H), tuple(int(c * 0.8) for c in rgb))
    bg.paste(crop.convert("RGB"), (0, (H - crop.height) // 2), crop)
    return light_and_vignette(bg, warm=0.01)


def colors_sheet(design: Image.Image, ptype: str, colors: list[str], seed: int) -> Image.Image:
    rng = np.random.default_rng(seed + 3)
    bg = linen(rng, (243, 240, 234)).convert("RGBA")
    colors = colors[:4]
    n = len(colors)
    cols = 2 if n == 4 else n
    rows = math.ceil(n / cols)
    top_pad = 190
    cell_w, cell_h = W // cols, (H - top_pad) // rows
    gsize = int(min(cell_w * 0.9, cell_h - 120))
    d = ImageDraw.Draw(bg)
    d.text((W / 2, 50), "AVAILABLE COLORS", font=font("BebasNeue-Regular.ttf", 110), fill=(29, 43, 69), anchor="ma")
    label = font("BebasNeue-Regular.ttf", 64)
    for i, name in enumerate(colors):
        r, c = divmod(i, cols)
        g = render_garment(design, GARMENT_RGB.get(name, (200, 200, 200)), garment_kind(ptype), (gsize, gsize), rng)
        x = c * cell_w + (cell_w - gsize) // 2
        y = top_pad + r * cell_h
        drop_shadow(bg, g, (x, y), offset=(12, 16), blur=18, strength=0.3)
        d.text((c * cell_w + cell_w / 2, y + gsize - 4), name.upper(), font=label, fill=(29, 43, 69), anchor="ma")
    return bg.convert("RGB")


def gift_card(design: Image.Image, ptype: str, color_name: str, listing: dict, seed: int) -> Image.Image:
    rng = np.random.default_rng(seed + 11)
    navy, cream, lime, coral = (29, 43, 69), (251, 243, 228), (217, 240, 60), (231, 111, 81)
    img = Image.new("RGBA", (W, H), navy + (255,))
    g = render_garment(design, GARMENT_RGB.get(color_name, (200, 200, 200)), garment_kind(ptype), (1250, 1250), rng)
    card = Image.new("RGBA", (1100, 1500), cream + (255,))
    img.alpha_composite(card, (110, 150))
    drop_shadow(img, g, (35, 280), offset=(14, 18), blur=20, strength=0.35)
    d = ImageDraw.Draw(img)
    x = 1330
    d.text((x, 190), "THE GIFT THEY'LL", font=font("Anton-Regular.ttf", 120), fill=cream)
    d.text((x, 330), "ACTUALLY WEAR", font=font("Anton-Regular.ttf", 120), fill=lime)
    facts = {
        "crewneck": ["Cozy Gildan 18000 crewneck", "Relaxed unisex fit, true to size"],
        "tee-cc": ["Soft Comfort Colors 1717 tee", "Garment-dyed, relaxed unisex fit"],
        "tee": ["Soft Bella+Canvas 3001 tee", "Lightweight, unisex retail fit"],
    }.get(ptype, [])
    occ = (listing.get("occasion") or "").lower()
    if occ.startswith("christmas"):
        perfect = "Perfect for Christmas gifting"
    elif occ.startswith("thanksgiving"):
        perfect = "Made for Thanksgiving and fall"
    else:
        perfect = "Birthdays, retirement, holidays"
    lines = facts + ["Printed to order just for you", "Free shipping on US orders", perfect]
    y = 560
    for line in lines[:6]:
        d.ellipse((x, y + 18, x + 34, y + 52), fill=coral)
        d.text((x + 60, y), line, font=font("BebasNeue-Regular.ttf", 74), fill=cream)
        y += 140
    d.text((x, H - 170), "DINK DISTRICT", font=font("BowlbyOneSC-Regular.ttf", 70), fill=lime)
    return img.convert("RGB")


# ------------------------------------------------------------------ mugs
def mug_scene(design: Image.Image, accent=(155, 203, 60), seed: int = 1) -> Image.Image:
    rng = np.random.default_rng(seed)
    canvas = wood(rng).convert("RGBA")
    mw, mh = 980, 1080
    mug = Image.new("RGBA", (mw + 420, mh + 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(mug)
    # handle
    d.rounded_rectangle((mw - 120, 260, mw + 300, 820), radius=200, outline=accent + (255,), width=110)
    # body with cylindrical shading
    xs = np.linspace(-1, 1, mw)
    shade = 0.62 + 0.45 * np.cos(np.clip(xs + 0.25, -1.6, 1.6)) ** 0.8
    body = np.ones((mh, mw, 3), np.float32) * 246 * np.clip(shade, 0, 1.1)[None, :, None]
    # wrap one side of the print around the cylinder
    side = design.crop((0, 0, design.width // 2, design.height)).convert("RGBA")
    side = side.crop(side.getbbox())
    pw = int(mw * 0.86)
    ph = int(pw * side.height / side.width)
    if ph > mh * 0.72:
        ph = int(mh * 0.72)
        pw = int(ph * side.width / side.height)
    tex = np.asarray(side.resize((pw, ph), Image.LANCZOS), np.float32)
    x0, y0 = (mw - pw) // 2, (mh - ph) // 2 + 30
    u = np.linspace(-1, 1, pw)
    src = ((np.arcsin(np.clip(u * 0.92, -1, 1)) / math.asin(0.92)) * 0.5 + 0.5) * (pw - 1)
    tex = tex[:, src.astype(int)]
    a = tex[..., 3:4] / 255.0
    region = body[y0:y0 + ph, x0:x0 + pw]
    body[y0:y0 + ph, x0:x0 + pw] = region * (1 - a) + tex[..., :3] * np.clip(shade[x0:x0 + pw], 0.6, 1.05)[None, :, None] * a
    bimg = Image.fromarray(np.clip(body, 0, 255).astype(np.uint8))
    bm = Image.new("L", (mw, mh), 0)
    ImageDraw.Draw(bm).rounded_rectangle((0, 0, mw, mh), radius=60, fill=255)
    mug.paste(bimg, (0, 60), bm)
    d.ellipse((0, 20, mw, 140), fill=tuple(int(c * 0.85) for c in accent) + (255,))  # rim / inside colour
    d.ellipse((30, 38, mw - 30, 124), fill=(60, 40, 28, 255))  # coffee
    drop_shadow(canvas, mug, ((W - mug.width) // 2 + 120, (H - mug.height) // 2 + 40), offset=(30, 30), blur=40)
    for (x, y, r) in [(170, 1300, 100), (360, 1440, 100)]:
        drop_shadow(canvas, sphere(r, (214, 236, 52)), (x, y), offset=(12, 16), blur=10, strength=0.38)
    pad = paddle(820).rotate(28, expand=True, resample=Image.BICUBIC)
    drop_shadow(canvas, pad, (-180, -120), offset=(16, 22), blur=18, strength=0.35)
    return light_and_vignette(canvas.convert("RGB"))


def gift_tag_text(slug: str, listing: dict) -> str:
    """What the handwritten gift tag says: who the shirt is for, or the occasion."""
    if listing.get("gift_tag"):
        return listing["gift_tag"]
    for key, text in (("grandma", "For Grandma, with love"), ("grandpa", "For Grandpa, with love"),
                      ("gigi", "For Gigi, with love"), ("nana", "For Nana, with love"),
                      ("retire", "Happy Retirement!"), ("knees", "For my favorite player"),
                      ("kitchen", "For my doubles partner"), ("mom", "For Mom, with love"),
                      ("dad", "For Dad, with love")):
        if key in slug:
            return text
    return "Merry Christmas!" if season_of(listing) == "christmas" else "For my favorite player"


def tissue(size: tuple[int, int], rng) -> Image.Image:
    w, h = size
    base = np.full((h, w, 3), 246, np.float32)
    crinkle = smooth_noise(h, w, 60, 90, rng) * 0.6 + smooth_noise(h, w, 18, 26, rng) * 0.4
    base -= crinkle[..., None] * 26
    return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")


def gift_scene(design: Image.Image, ptype: str, color_name: str, slug: str, listing: dict, seed: int) -> Image.Image:
    """The shirt folded in an open gift box on tissue paper, with a handwritten tag (who it's for)."""
    rng = np.random.default_rng(seed + 19)
    rnd = random.Random(seed + 19)
    rgb = GARMENT_RGB.get(color_name, (200, 200, 200))
    christmas = season_of(listing) == "christmas"
    canvas = (wood(rng) if not christmas else linen(rng, (228, 222, 210))).convert("RGBA")
    kind = garment_kind(ptype)
    # box: kraft board seen from above, walls shaded, tissue inside
    bw, bh = 1500, 1380
    bx, by = 330, 240
    box = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(box)
    kraft, wall = (190, 152, 104), (160, 124, 82)
    bd.rounded_rectangle((0, 0, bw, bh), radius=18, fill=kraft + (255,))
    t = 70  # wall thickness in perspective
    bd.polygon([(t, t), (bw - t, t), (bw - t - 30, t + 40), (t + 30, t + 40)], fill=(132, 100, 64, 255))
    bd.rectangle((t, t + 40, bw - t, bh - t), fill=wall + (255,))
    box.alpha_composite(tissue((bw - 2 * t - 40, bh - 2 * t - 70), rng), (t + 20, t + 55))
    drop_shadow(canvas, box, (bx, by), offset=(26, 34), blur=40, strength=0.45)
    # folded shirt: the front panel from collar to below the print, sides folded under
    g = render_garment(design, rgb, kind, (1900, 1900), rng)
    # crop below the print's real bottom so tall designs aren't cut off
    alpha = np.asarray(g.getchannel("A"))
    diff = render_garment(Image.new("RGBA", design.size), rgb, kind, (1900, 1900), np.random.default_rng(seed + 19))
    ink = np.abs(np.asarray(g.convert("RGB"), dtype=np.int16) - np.asarray(diff.convert("RGB"), dtype=np.int16)).max(axis=2) > 24
    ys = np.nonzero(ink.any(axis=1))[0]
    bottom = min(int(ys.max() + 1900 * 0.05), int(1900 * 0.86)) if len(ys) else int(1900 * 0.66)
    fold = g.crop((int(1900 * 0.245), int(1900 * 0.06), int(1900 * 0.755), bottom))
    m = Image.new("L", fold.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, fold.width, fold.height), radius=40, fill=255)
    m = ImageChops.multiply(m, fold.getchannel("A"))
    fold.putalpha(m)
    edge = Image.new("RGBA", fold.size, (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    for i in range(36):  # darker folded edges left, right and bottom
        a = int(70 * (1 - i / 36))
        ed.line((i, 0, i, fold.height), fill=(0, 0, 0, a))
        ed.line((fold.width - 1 - i, 0, fold.width - 1 - i, fold.height), fill=(0, 0, 0, a))
        ed.line((0, fold.height - 1 - i, fold.width, fold.height - 1 - i), fill=(0, 0, 0, a))
    edge.putalpha(ImageChops.multiply(edge.getchannel("A"), m))
    fold.alpha_composite(edge)
    scale = min((bh - 2 * t - 140) / fold.height, (bw - 2 * t - 330) / fold.width)
    fold = fold.resize((int(fold.width * scale), int(fold.height * scale)), Image.LANCZOS)
    fold = fold.rotate(rnd.uniform(-2, 2), expand=True, resample=Image.BICUBIC)
    fx, fy = bx + t + 60, by + t + 70 + max(0, (bh - 2 * t - 140 - fold.height) // 2)
    drop_shadow(canvas, fold, (fx, fy), offset=(10, 16), blur=20, strength=0.35)
    # ribbon down the right side, with a bow
    ribbon = (178, 32, 44) if christmas else (42, 157, 143)
    rd = ImageDraw.Draw(canvas)
    rx = bx + bw - t - 150
    rd.rectangle((rx, 0, rx + 70, H), fill=ribbon + (255,))
    rd.rectangle((rx + 8, 0, rx + 18, H), fill=tuple(min(255, c + 40) for c in ribbon) + (255,))
    bow = Image.new("RGBA", (420, 300), (0, 0, 0, 0))
    bdw = ImageDraw.Draw(bow)
    dark = tuple(int(c * 0.7) for c in ribbon) + (255,)
    bdw.ellipse((0, 40, 210, 230), fill=ribbon + (255,))
    bdw.ellipse((210, 40, 420, 230), fill=ribbon + (255,))
    bdw.ellipse((60, 90, 170, 180), fill=dark)
    bdw.ellipse((250, 90, 360, 180), fill=dark)
    bdw.rounded_rectangle((170, 80, 250, 190), radius=20, fill=tuple(int(c * 0.85) for c in ribbon) + (255,))
    drop_shadow(canvas, bow, (rx + 35 - 210, by - 60), offset=(10, 14), blur=12, strength=0.35)
    # handwritten gift tag on a string
    tag = Image.new("RGBA", (640, 360), (0, 0, 0, 0))
    td = ImageDraw.Draw(tag)
    td.polygon([(90, 0), (640, 0), (640, 360), (90, 360), (0, 180)], fill=(250, 244, 230, 255))
    td.ellipse((50, 160, 90, 200), fill=(0, 0, 0, 0))
    text = gift_tag_text(slug, listing)
    fnt = font("Pacifico-Regular.ttf", 64)
    while td.textlength(text, font=fnt) > 500 and fnt.size > 30:
        fnt = font("Pacifico-Regular.ttf", fnt.size - 4)
    td.text((365, 175), text, font=fnt, fill=(29, 43, 69, 255), anchor="mm")
    tag = tag.rotate(rnd.uniform(-14, -6), expand=True, resample=Image.BICUBIC)
    tx, ty = bx + bw - 380, by + bh - 300
    rd.line((rx + 35, by + 60, tx + 90, ty + 210), fill=(120, 90, 60, 255), width=6)
    drop_shadow(canvas, tag, (tx, ty), offset=(12, 16), blur=14, strength=0.35)
    # props
    if christmas:
        for (x, y, rot, ln) in [(-140, 1200, 30, 760), (1950, -160, 120, 640)]:
            sp = pine_sprig(ln, rng).rotate(rot, expand=True, resample=Image.BICUBIC)
            drop_shadow(canvas, sp, (x, y), offset=(10, 14), blur=12, strength=0.3)
    else:
        for (x, y, r) in [(120, 1450, 88), (2080, 300, 80)]:
            drop_shadow(canvas, sphere(r, (214, 236, 52)), (x, y), offset=(12, 16), blur=10, strength=0.38)
    return light_and_vignette(canvas.convert("RGB"))


NECK_LABEL_TYPES = {"crewneck", "tee"}  # Comfort Colors 1717 can't take a neck print


def label_card(ptype: str, color_name: str, seed: int) -> Image.Image:
    """Detail card: our printed neck label on a fabric swatch, with what it is (truthful, not a fake photo)."""
    from etsy_agent.brandmark import neck_label
    rng = np.random.default_rng(seed + 23)
    navy, cream, lime = (29, 43, 69), (251, 243, 228), (217, 240, 60)
    rgb = GARMENT_RGB.get(color_name, (40, 40, 40))
    img = Image.new("RGBA", (W, H), navy + (255,))
    # fabric swatch with knit texture
    sw, sh = 1100, 1500
    fabric = np.ones((sh, sw, 3), np.float32) * np.array(rgb, np.float32)
    knit = smooth_noise(sh, sw, 3, 2, rng) * 0.5 + fine_noise(sh, sw, rng) * 0.5
    fabric *= (0.93 + knit[..., None] * 0.12)
    fabric *= (1.04 - smooth_noise(sh, sw, 400, 300, rng)[..., None] * 0.1)
    swatch = Image.fromarray(np.clip(fabric, 0, 255).astype(np.uint8)).convert("RGBA")
    m = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, sw, sh), radius=40, fill=255)
    swatch.putalpha(m)
    ImageDraw.Draw(swatch).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=40, outline=cream + (255,), width=10)
    label = neck_label("M", "#FBF3E4" if is_dark(rgb) else "#1D2B45", (900, 900))
    la = np.asarray(label, dtype=np.float32)
    la[..., :3] *= (0.94 + knit[:900, :900, None] * 0.1)  # ink picks up the fabric grain
    label = Image.fromarray(np.clip(la, 0, 255).astype(np.uint8))
    swatch.alpha_composite(label, ((sw - 900) // 2, 260))
    drop_shadow(img, swatch, (110, 150), offset=(14, 18), blur=20, strength=0.4)
    d = ImageDraw.Draw(img)
    x = 1330
    d.text((x, 190), "OUR OWN", font=font("Anton-Regular.ttf", 120), fill=cream)
    d.text((x, 330), "NECK LABEL", font=font("Anton-Regular.ttf", 120), fill=lime)
    body = font("BebasNeue-Regular.ttf", 58)
    for i, line in enumerate(["PRINTED INSIDE THE COLLAR", "DINK DISTRICT SEAL + YOUR SIZE", "CARE NOTES ALWAYS AT HAND",
                              "PRINTED TO ORDER JUST FOR YOU"]):
        y = 540 + i * 92
        d.ellipse((x, y + 20, x + 22, y + 42), fill=(231, 111, 81))
        d.text((x + 44, y), line, font=body, fill=cream)
    d.text((x, 1560), "DINK DISTRICT", font=font("ArchivoBlack-Regular.ttf", 64), fill=lime)
    return img.convert("RGB")


# ------------------------------------------------------------------ driver
def find_design(slug: str) -> Path:
    for base in ("designs-round-4", "designs-round-3", "designs-round-2", "samples"):
        p = ROOT / base / slug
        if (p / "listing.json").exists():
            return p
    raise SystemExit(f"no design folder for {slug}")


def season_of(listing: dict) -> str:
    occ = (listing.get("occasion") or "").lower()
    return "christmas" if occ.startswith("christmas") else "evergreen"


def render(slug: str) -> Path:
    folder = find_design(slug)
    listing = json.loads((folder / "listing.json").read_text())
    product = listing["products"][0]
    ptype, colors = product["type"], product["colors"]
    design = Image.open(folder / "design.png").convert("RGBA")
    out = OUT / slug
    out.mkdir(parents=True, exist_ok=True)
    seed = sum(map(ord, slug))
    if ptype.startswith("mug"):
        accent = (155, 203, 60) if ptype == "mug-accent" else (240, 240, 236)
        mug_scene(design, accent, seed).save(out / "1-hero.jpg", quality=90)
        if ptype == "mug-accent":
            mug_scene(design, (32, 32, 34), seed + 1).save(out / "2-black.jpg", quality=90)
        return out
    if ptype == "sticker":
        return out
    hero(design, ptype, colors[0], season_of(listing), seed).save(out / "1-hero.jpg", quality=90)
    closeup(design, ptype, colors[0], seed).save(out / "2-closeup.jpg", quality=90)
    colors_sheet(design, ptype, colors, seed).save(out / "3-colors.jpg", quality=90)
    gift_card(design, ptype, colors[0], listing, seed).save(out / "4-gift.jpg", quality=90)
    gift_scene(design, ptype, colors[0], slug, listing, seed).save(out / "5-giftbox.jpg", quality=90)
    if ptype in NECK_LABEL_TYPES:
        label_card(ptype, colors[0], seed).save(out / "6-label.jpg", quality=90)
    return out


def main() -> None:
    args = sys.argv[1:]
    if args == ["--all"]:
        slugs = []
        for base in ("designs-round-4", "designs-round-3", "designs-round-2"):
            for p in sorted((ROOT / base).glob("*/listing.json")) if (ROOT / base).exists() else []:
                slugs.append(p.parent.name)
        args = slugs
    for slug in args:
        print(render(slug))


if __name__ == "__main__":
    main()
