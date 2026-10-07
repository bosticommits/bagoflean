"""Draw the DinkDistrictArt shop icon and banner into brand/.

Usage:  python scripts/brand.py
"""

import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from PIL import Image  # noqa: E402

from etsy_agent.artkit import fit, ink, paddle, pickleball, text  # noqa: E402
from etsy_agent.render import cairosvg  # noqa: E402  (fontconfig set up on import)

NAVY, CREAM, CORAL, TEAL, LIME = "#1D2B45", "#FBF3E4", "#E76F51", "#2A9D8F", "#D9F03C"
OUT = Path(__file__).resolve().parent.parent / "brand"


def emblem(cx, cy, s):
    """Crossed paddles with a ball on top, centred on (cx, cy), scale s."""
    import math
    parts = []
    for a, face, halo in [(44, TEAL, None), (-44, CORAL, NAVY)]:
        r = math.radians(a)
        hx = cx - math.sin(r) * 600 * s
        hy = cy + 250 * s + math.cos(r) * 600 * s
        parts.append(paddle(hx, hy, a, s, face, CREAM, CREAM, halo=halo))
    parts.append(pickleball(round(cx), round(cy - 700 * s), round(230 * s), outline=NAVY, ow=round(60 * s)))
    return "\n".join(parts)


def stacked(x, top, lines):
    """Centred stacked text at x. lines: (text, font, width, fill, gap, shadow). Returns parts, bottom."""
    parts, y = [], top
    for i, (s, font, width, fill, gap, shadow) in enumerate(lines):
        plain = s.replace("&amp;", "&")
        size, _ = fit(font, plain, width)
        up, down = ink(font, plain, size)
        y += gap if i else 0
        base = y + up
        if shadow:
            off = size * 0.05
            parts.append(text(x + off, base + off, s, font, size, shadow))
        parts.append(text(x, base, s, font, size, fill))
        y = base + down
    return parts, y


def doc(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">'
            f'<rect width="{w}" height="{h}" fill="{NAVY}"/>{body}</svg>')


def png(svg_text, path, size=None):
    data = cairosvg.svg2png(bytestring=svg_text.encode())
    img = Image.open(io.BytesIO(data)).convert("RGB")
    if size:
        img = img.resize(size, Image.LANCZOS)
    img.save(path, optimize=True)


def icon():
    W = 2000
    b = [f'<circle cx="{W / 2}" cy="{W / 2}" r="{W * 0.46}" fill="none" stroke="{CREAM}" stroke-width="28"/>',
         emblem(W / 2, 640, 0.44)]
    parts, _ = stacked(W / 2, 1060, [
        ("DINK", "Alfa Slab One", 1050, CREAM, 0, CORAL),
        ("DISTRICT", "Alfa Slab One", 1300, LIME, 50, None),
    ])
    b += parts
    svg_text = doc(W, W, "\n".join(b))
    (OUT / "logo.svg").write_text(svg_text)
    png(svg_text, OUT / "shop-icon-500.png", (500, 500))
    png(svg_text, OUT / "logo-2000.png")


def banner():
    W, H = 3360, 840
    b = []
    # faint court lines across the banner
    b.append(f'<g fill="none" stroke="{LIME}" stroke-opacity="0.14" stroke-width="10">'
             f'<rect x="60" y="70" width="{W - 120}" height="{H - 140}"/>'
             f'<line x1="430" y1="70" x2="430" y2="{H - 70}"/>'
             f'<line x1="{W - 430}" y1="70" x2="{W - 430}" y2="{H - 70}"/></g>')
    for x, y, r in [(240, 260, 90), (250, 590, 55), (W - 240, 580, 90), (W - 250, 250, 55)]:
        b.append(pickleball(x, y, r))
    b.append(emblem(880, 470, 0.33))
    parts, _ = stacked(2000, 250, [
        ("DINK DISTRICT", "Bowlby One SC", 1700, CREAM, 0, CORAL),
        ("FUNNY PICKLEBALL SHIRTS &amp; GIFTS", "Bebas Neue", 1500, LIME, 80, None),
    ])
    b += parts
    svg_text = doc(W, H, "\n".join(b))
    (OUT / "banner.svg").write_text(svg_text)
    png(svg_text, OUT / "shop-banner-3360x840.png")


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    icon()
    banner()
    print(f"Wrote shop icon, logo and banner to {OUT}")
