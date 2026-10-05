"""Make a personalised "<TOWN> Pickleball Club" print file.

Usage:  python scripts/club_shirt.py "Palm Springs"

Writes output/club-<town>/design.png (4500x5400, 300 DPI, transparent) and
mockup.png. Use it when an Etsy customer orders the personalised club shirt:
make the file with their town name, then create the order in Printify with it.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from etsy_agent.artkit import CX, crossed_paddles, fit, ink, pickleball, svg, text  # noqa: E402
from etsy_agent.render import make_mockup, render_png, validate_svg  # noqa: E402


def club_svg(town: str, navy="#1D2B45", red="#C8102E", shirt="#FFFFFF") -> str:
    town = town.upper().replace("&", "&amp;").replace("<", "").replace(">", "")
    b = []
    arc_r, cy_arc = 4400, 5300
    b.append(f'<defs><path id="arc" d="M{CX - arc_r} {cy_arc} A{arc_r} {arc_r} 0 0 1 {CX + arc_r} {cy_arc}"/></defs>')
    size, _ = fit("Alfa Slab One", town, 3600)
    size = min(size * 0.95, 800)
    b.append(f'<g transform="translate(45 45)"><text font-family="Alfa Slab One" font-size="{size:.0f}" fill="{navy}">'
             f'<textPath href="#arc" startOffset="50%" text-anchor="middle">{town}</textPath></text></g>')
    b.append(f'<text font-family="Alfa Slab One" font-size="{size:.0f}" fill="{red}">'
             f'<textPath href="#arc" startOffset="50%" text-anchor="middle">{town}</textPath></text>')
    cyc = 2050
    b.append(crossed_paddles(CX, cyc + 250, 46, 0.78, (red, navy, navy, None), (red, navy, navy, None), shirt))
    b.append(pickleball(CX, cyc - 500, 230, outline=navy, ow=60))
    label = "PICKLEBALL CLUB"
    lsize, _ = fit("Bowlby One SC", label, 3900)
    up, _ = ink("Bowlby One SC", label, lsize)
    b.append(text(CX, cyc + 1050 + up, label, "Bowlby One SC", lsize, navy))
    return svg("\n".join(b))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("town", help="town or club name, e.g. 'Palm Springs'")
    parser.add_argument("--shirt", default="#FFFFFF", help="shirt colour hex for the mockup")
    args = parser.parse_args()
    svg_text = club_svg(args.town, shirt=args.shirt)
    report = validate_svg(svg_text)
    if not report.ok:
        sys.exit("\n".join(report.errors))
    slug = re.sub(r"[^a-z0-9]+", "-", args.town.lower()).strip("-")
    folder = Path("output") / f"club-{slug}"
    folder.mkdir(parents=True, exist_ok=True)
    png = render_png(svg_text)
    (folder / "design.svg").write_text(svg_text)
    (folder / "design.png").write_bytes(png)
    (folder / "mockup.png").write_bytes(make_mockup(png, args.shirt))
    print(f"Wrote {folder}/design.png and mockup.png")


if __name__ == "__main__":
    main()
