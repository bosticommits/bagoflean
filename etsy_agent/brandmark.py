"""Dink District brand marks: the small details that make a print feel like a real brand.

- seal(): a one-colour round stamp "DINK DISTRICT · EST. 2026" with crossed paddles,
  to tuck under or beside the main artwork (like a vintage athletic-dept. stamp).
- brand_line(): a spaced-caps line such as "DINK DISTRICT ATHLETIC CO. · EST. 2026".
- neck_label(): the inside-neck print (logo, size, care line) that real clothing brands have.

Everything is a transparent RGBA PIL image in one flat colour, drawn at print
resolution, so it passes scripts/design_check.py. Paste with Image.alpha_composite.

    from etsy_agent.brandmark import seal, brand_line, neck_label
    stamp = seal(420, "#FBF3E4")            # 420 px wide, cream ink
    line = brand_line("DINK DISTRICT · EST. 2026", 2400, "#1D2B45")
    label = neck_label("M", "#FBF3E4")      # 756x756 for Gildan; pass size=(750, 750) for Bella
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONTS = Path(__file__).resolve().parent.parent / "fonts"
EST = "EST. 2026"
SS = 4  # supersampling, then downscale and re-threshold to keep edges crisp but flat


def _font(name: str, px: float) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), max(1, int(px)))


def _flat(mask: Image.Image, size: tuple[int, int], color: str) -> Image.Image:
    """Downscale a supersampled L mask and colour it; alpha keeps only a thin anti-aliased edge."""
    small = mask.resize(size, Image.LANCZOS).point(lambda v: 0 if v < 40 else 255 if v > 215 else v)
    out = Image.new("RGBA", size, color)
    out.putalpha(small)
    return out


def _arc_text(d: ImageDraw.ImageDraw, canvas: Image.Image, text: str, fnt, cx, cy, r, center_deg, top=True,
              tracking=0.12):
    """Draw text along a circle (top: reads clockwise over the top; bottom: reads left-to-right underneath)."""
    widths = [d.textlength(ch, font=fnt) for ch in text]
    gap = fnt.size * tracking
    total = sum(widths) + gap * (len(text) - 1)
    span = total / r  # radians
    ang = math.radians(center_deg) - (span / 2 if top else -span / 2)
    for ch, w in zip(text, widths):
        step = (w / 2) / r
        ang += step if top else -step
        x, y = cx + r * math.cos(ang), cy + r * math.sin(ang)
        tile = Image.new("L", (int(fnt.size * 2), int(fnt.size * 2)), 0)
        ImageDraw.Draw(tile).text((tile.width / 2, tile.height / 2), ch, font=fnt, fill=255, anchor="mm")
        rot = math.degrees(ang) + (90 if top else -90)
        tile = tile.rotate(-rot, resample=Image.BICUBIC)
        canvas.paste(255, (int(x - tile.width / 2), int(y - tile.height / 2)), tile)
        ang += step + (gap / r) if top else -(step + gap / r)


def _emblem(d: ImageDraw.ImageDraw, cx, cy, s):
    """Crossed paddles with a ball, as a single-colour silhouette with knocked-out separations."""
    def face_pts(fx, fy, ux, uy, px, py, grow=0.0):
        fw, fh = 0.25 * s + grow, 0.33 * s + grow
        pts = []
        for t in range(0, 360, 6):
            tr = math.radians(t)
            c, sn = math.cos(tr), math.sin(tr)
            ex = math.copysign(abs(c) ** 0.5, c) * fw
            ey = math.copysign(abs(sn) ** 0.5, sn) * fh
            pts.append((fx + px * ex + ux * ey, fy + py * ex + uy * ey))
        return pts

    gap = 0.05 * s
    for ang in (-34, 34):  # the second paddle is drawn on top, with a knocked-out edge
        a = math.radians(ang)
        ux, uy = math.sin(a), -math.cos(a)          # axis from handle end to face
        px, py = -uy, ux
        bx, by = cx - ux * 0.62 * s, cy - uy * 0.62 * s   # bottom of the handle
        fx, fy = bx + ux * 1.05 * s, by + uy * 1.05 * s    # face centre
        hw = 0.065 * s
        handle = [(bx + px * hw, by + py * hw), (bx - px * hw, by - py * hw),
                  (bx - px * hw + ux * 0.75 * s, by - py * hw + uy * 0.75 * s),
                  (bx + px * hw + ux * 0.75 * s, by + py * hw + uy * 0.75 * s)]
        edge = [(x + (px if i in (0, 3) else -px) * gap, y + (py if i in (0, 3) else -py) * gap)
                for i, (x, y) in enumerate(handle)]
        d.polygon(edge, fill=0)
        d.polygon(face_pts(fx, fy, ux, uy, px, py, grow=gap), fill=0)
        d.polygon(handle, fill=255)
        d.polygon(face_pts(fx, fy, ux, uy, px, py), fill=255)
        # grip end cap
        d.ellipse((bx - hw * 1.5, by - hw * 1.5, bx + hw * 1.5, by + hw * 1.5), fill=255)
    # ball between the paddle faces, with knocked-out holes
    br = 0.17 * s
    bx, by = cx, cy - 0.95 * s
    d.ellipse((bx - br - gap, by - br - gap, bx + br + gap, by + br + gap), fill=0)
    d.ellipse((bx - br, by - br, bx + br, by + br), fill=255)
    for hx, hy in [(0, 0), (-0.45, -0.3), (0.45, -0.3), (-0.45, 0.35), (0.45, 0.35), (0, -0.62), (0, 0.65)]:
        hr = br * 0.13
        d.ellipse((bx + hx * br - hr, by + hy * br - hr, bx + hx * br + hr, by + hy * br + hr), fill=0)


def seal(width: int, color: str, top_text: str = "DINK DISTRICT", bottom_text: str = EST) -> Image.Image:
    """Round one-colour stamp. Keep it at least ~360 px wide on a shirt so the lettering prints."""
    W = width * SS
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    c, R = W / 2, W / 2
    ring = max(SS * 22, W * 0.045)
    d.ellipse((0, 0, W, W), fill=255)
    d.ellipse((ring, ring, W - ring, W - ring), fill=0)
    inner = R * 0.66
    d.ellipse((c - inner, c - inner, c + inner, c + inner), fill=255)
    d.ellipse((c - inner + ring * 0.7, c - inner + ring * 0.7, c + inner - ring * 0.7, c + inner - ring * 0.7), fill=0)
    band_r = (R - ring + inner) / 2
    fnt = _font("Righteous-Regular.ttf", (R - ring - inner) * 0.62)
    _arc_text(d, m, top_text, fnt, c, c, band_r, -90, top=True)
    _arc_text(d, m, bottom_text, fnt, c, c, band_r, 90, top=False)
    for side in (-1, 1):  # small stars between the two arcs
        sx, sy = c + side * band_r, c
        rr = fnt.size * 0.28
        pts = [(sx + (rr if k % 2 == 0 else rr * 0.45) * math.cos(math.radians(-90 + k * 36)),
                sy + (rr if k % 2 == 0 else rr * 0.45) * math.sin(math.radians(-90 + k * 36))) for k in range(10)]
        d.polygon(pts, fill=255)
    _emblem(d, c, c + inner * 0.3, inner * 0.6)
    return _flat(m, (width, width), color)


def brand_line(text: str, width: int, color: str, font: str = "Righteous-Regular.ttf",
               tracking: float = 0.22) -> Image.Image:
    """Spaced caps fitted to `width` px. Use for taglines like 'DINK DISTRICT ATHLETIC CO. · EST. 2026'."""
    probe = _font(font, 100 * SS)
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    raw = sum(tmp.textlength(ch, font=probe) for ch in text) + probe.size * tracking * (len(text) - 1)
    size = 100 * SS * (width * SS) / raw
    fnt = _font(font, size)
    asc, desc = fnt.getmetrics()
    m = Image.new("L", (width * SS, asc + desc), 0)
    d = ImageDraw.Draw(m)
    x = 0.0
    for ch in text:
        d.text((x, 0), ch, font=fnt, fill=255)
        x += d.textlength(ch, font=fnt) + fnt.size * tracking
    box = m.getbbox()
    m = m.crop((0, box[1], m.width, box[3]))
    return _flat(m, (width, max(1, m.height // SS)), color)


def neck_label(size_text: str, color: str, size: tuple[int, int] = (756, 756),
               care: str = "WASH COLD · DRY LOW") -> Image.Image:
    """Inside-neck print: seal, DINK DISTRICT, big size letter, care line. One colour."""
    w, h = size
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    s = seal(int(w * 0.36), color)
    out.alpha_composite(s, ((w - s.width) // 2, int(h * 0.02)))
    y = int(h * 0.02) + s.height + int(h * 0.03)
    name = brand_line("DINK DISTRICT", int(w * 0.82), color, font="ArchivoBlack-Regular.ttf", tracking=0.08)
    out.alpha_composite(name, ((w - name.width) // 2, y))
    y += name.height + int(h * 0.035)
    big = Image.new("L", (w * SS, int(h * 0.26) * SS), 0)
    fnt = _font("ArchivoBlack-Regular.ttf", h * 0.2 * SS)
    ImageDraw.Draw(big).text((big.width / 2, big.height / 2), size_text, font=fnt, fill=255, anchor="mm")
    big_img = _flat(big, (w, int(h * 0.26)), color)
    out.alpha_composite(big_img, (0, y))
    y += big_img.height + int(h * 0.02)
    for line in (care, "PRINTED TO ORDER"):
        ln = brand_line(line, int(w * 0.9), color, tracking=0.12)
        if ln.height > h * 0.065:
            ln = ln.resize((int(ln.width * h * 0.065 / ln.height), int(h * 0.065)), Image.LANCZOS)
        out.alpha_composite(ln, ((w - ln.width) // 2, y))
        y += ln.height + int(h * 0.025)
    return out
