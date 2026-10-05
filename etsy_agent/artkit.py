"""Vector drawing helpers used for the hand-made designs in samples/.

Everything draws on the 4500x5400 print canvas and returns SVG snippets.
"""

import math

from .textmetrics import measure

CX = 2250  # horizontal centre of the print canvas


def fit(font, text, width, spacing_per_1000=0):
    """font size so advance width == width (spacing scales with size)."""
    adv = measure(font, text, 1000, spacing_per_1000)["advance_width"]
    size = 1000 * width / adv
    return size, spacing_per_1000 * size / 1000


def ink(font, text, size, spacing=0):
    r = measure(font, text, size, spacing)
    return -r["ink_top"], r["ink_bottom"]


def text(x, y, s, font, size, fill, spacing=0, anchor="middle", extra=""):
    ls = f' letter-spacing="{spacing:.1f}"' if spacing else ""
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{font}" font-size="{size:.1f}"'
            f' fill="{fill}" text-anchor="{anchor}"{ls} {extra}>{s}</text>')


def pickleball(cx, cy, r, fill="#D9F03C", hole="#9FB82A", outline=None, ow=0, highlight=True):
    parts = []
    if outline:
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r + ow / 2:.1f}" fill="{outline}"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>')
    hr = 0.085 * r
    pts = [(0, 0)]
    pts += [(0.42 * r * math.cos(a), 0.42 * r * math.sin(a)) for a in [i * math.pi / 3 + math.pi / 6 for i in range(6)]]
    pts += [(0.76 * r * math.cos(a), 0.76 * r * math.sin(a)) for a in [i * math.pi / 6 for i in range(12)]]
    for dx, dy in pts:
        parts.append(f'<circle cx="{cx + dx:.1f}" cy="{cy + dy:.1f}" r="{hr:.1f}" fill="{hole}"/>')
    if highlight:
        parts.append(
            f'<path d="M{cx - 0.78 * r:.1f} {cy - 0.15 * r:.1f} A{0.8 * r:.1f} {0.8 * r:.1f} 0 0 1 {cx - 0.15 * r:.1f} {cy - 0.78 * r:.1f}"'
            f' fill="none" stroke="#ffffff" stroke-opacity="0.45" stroke-width="{0.07 * r:.1f}" stroke-linecap="round"/>')
    return "\n".join(parts)


def paddle(x, y, angle, scale, face, edge, grip, sweet=None, halo=None):
    """Paddle with handle end at (x, y), pointing up, rotated by angle."""
    s = scale
    g = [f'<g transform="translate({x:.1f} {y:.1f}) rotate({angle}) scale({s})">']
    if halo:
        g.append(f'<rect x="-95" y="-560" width="190" height="600" rx="60" fill="{halo}" stroke="{halo}" stroke-width="140"/>')
        g.append(f'<rect x="-380" y="-1500" width="760" height="980" rx="300" fill="{halo}" stroke="{halo}" stroke-width="210"/>')
    g.append(f'<rect x="-95" y="-560" width="190" height="600" rx="60" fill="{grip}"/>')
    for yy in (-470, -380, -290, -200, -110):
        g.append(f'<line x1="-95" y1="{yy}" x2="95" y2="{yy - 50}" stroke="{edge}" stroke-width="26" stroke-opacity="0.55"/>')
    g.append(f'<rect x="-120" y="-30" width="240" height="70" rx="30" fill="{edge}"/>')
    g.append(f'<rect x="-380" y="-1500" width="760" height="980" rx="300" fill="{face}" stroke="{edge}" stroke-width="70"/>')
    if sweet:
        g.append(f'<rect x="-250" y="-1360" width="500" height="700" rx="200" fill="none" stroke="{sweet}" stroke-width="34"/>')
    g.append("</g>")
    return "\n".join(g)


def crossed_paddles(cx, cy, angle, s, back, front, halo):
    """Two paddles crossing at their necks at (cx, cy). back/front = (face, edge, grip, sweet)."""
    out = []
    for a, colors, h in [(angle, back, None), (-angle, front, halo)]:
        rad = math.radians(a)
        hx = cx - math.sin(rad) * 600 * s
        hy = cy + math.cos(rad) * 600 * s
        out.append(paddle(hx, hy, a, s, *colors, halo=h))
    return "\n".join(out)


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4500 5400" width="4500" height="5400">\n'
            + body + "\n</svg>\n")


def star(cx, cy, r, fill):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append(f"{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}")
    return f'<polygon points="{" ".join(pts)}" fill="{fill}"/>'
