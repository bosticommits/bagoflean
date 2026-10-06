"""Pre-flight check for design folders (the checklist in knowledge/design-playbook.md).

Usage:  python scripts/design_check.py designs-round-4/grandmas-got-game [...]
        python scripts/design_check.py designs-round-4          # every design in a round

For each design it checks the print file (size, DPI, transparency, flat colour,
width, top margin, thin lines), the contrast against every listed garment
colour, and the listing (title, tags, AI disclosure). It writes thumbs.png next
to the design: the art at Etsy-thumbnail size on each garment colour, which you
must look at before scoring the design.

Exit code 1 if anything FAILs; WARN lines are for judgement.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))
from etsy_agent.compliance import listing_problems  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from photo_studio import GARMENT_RGB  # noqa: E402

SIZES = {"crewneck": (4500, 5400), "tee": (4500, 5400), "tee-cc": (4500, 5400),
         "mug": (2475, 1155), "mug-accent": (2475, 1155), "sticker": (3000, 3000)}
SHIRTS = {"crewneck", "tee", "tee-cc"}
THUMB_W = 300


def luminance(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def contrast(l1: np.ndarray, l2: float) -> np.ndarray:
    hi, lo = np.maximum(l1, l2), np.minimum(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def check(folder: Path) -> tuple[list[str], list[str], list[str]]:
    fails, warns, info = [], [], []
    listing = json.loads((folder / "listing.json").read_text())
    product = (listing.get("products") or [{}])[0]
    ptype, colors = product.get("type", "?"), product.get("colors", [])

    img = Image.open(folder / "design.png")
    dpi = img.info.get("dpi", (0, 0))
    if img.mode != "RGBA":
        fails.append(f"mode is {img.mode}, needs RGBA (transparent)")
        img = img.convert("RGBA")
    if ptype in SIZES and img.size != SIZES[ptype]:
        fails.append(f"size {img.size}, {ptype} needs {SIZES[ptype]}")
    if round(dpi[0]) != 300:
        fails.append(f"DPI is {dpi[0]}, needs 300")

    a = np.asarray(img)
    alpha = a[..., 3]
    ink = alpha > 0
    if not ink.any():
        return ["design is empty"], warns, info
    # anti-aliased edges are a 1-2 px band; a glow, shadow or gradient is a wide band of partial alpha
    partial_mask = (alpha > 0) & (alpha < 250)
    partial = partial_mask.sum() / ink.sum()
    wide = np.asarray(Image.fromarray(partial_mask.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(5))) > 0
    glow = wide.sum() / ink.sum()
    (fails if glow > 0.002 else info).append(
        f"semi-transparent: {partial:.1%} of ink at edges, {glow:.2%} in wide bands "
        f"(wide bands = glow/gradient/soft shadow, not allowed)")

    ys, xs = np.nonzero(ink)
    width_pct = (xs.max() - xs.min() + 1) / img.width
    if ptype in SHIRTS:
        if not 0.78 <= width_pct <= 0.96:
            warns.append(f"art is {width_pct:.0%} of the print width (aim for 80-95%)")
        if ys.min() > 300:
            warns.append(f"art starts {ys.min()} px from the top (aim for under 300 so it sits on the chest)")
        info.append(f"art box: {width_pct:.0%} wide, rows {ys.min()}-{ys.max()} "
                    f"({(ys.max() - ys.min()) / 300:.1f} in tall)")

    # thin lines: anything an opening of ~20 print px removes is too thin to print well
    small = Image.fromarray((alpha > 127).astype(np.uint8) * 255).resize(
        (img.width // 4, img.height // 4), Image.BOX).point(lambda v: 255 if v > 127 else 0)
    opened = small.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(5))
    s, o = np.asarray(small) > 0, np.asarray(opened) > 0
    thin = (s & ~o).sum() / max(1, s.sum())
    (warns if thin > 0.03 else info).append(f"ink thinner than ~20 px: {thin:.1%} (sparkle tips and specks are fine)")

    # contrast against each garment colour
    rgb = a[..., :3][ink].astype(np.float64)
    lum = luminance(rgb)
    edge = ink & ~(np.asarray(Image.fromarray(ink.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(9))) > 0)
    edge_lum = luminance(a[..., :3][edge].astype(np.float64))
    for name in colors:
        if name not in GARMENT_RGB:
            warns.append(f"no reference colour for '{name}', contrast not checked")
            continue
        g = float(luminance(np.array(GARMENT_RGB[name], dtype=np.float64)))
        low = (contrast(lum, g) < 1.6).mean()
        low_edge = (contrast(edge_lum, g) < 1.6).mean()
        msg = f"{name}: {low:.0%} of ink and {low_edge:.0%} of the outer edge blend into the shirt"
        (fails if low_edge > 0.5 else warns if low_edge > 0.25 or low > 0.35 else info).append(msg)

    problems = listing_problems(listing, PICKLEBALL.blocked_terms)
    fails += [f"listing: {p}" for p in problems]

    make_thumbs(img, colors, folder / "thumbs.png")
    return fails, warns, info


def make_thumbs(img: Image.Image, colors: list[str], out: Path) -> None:
    th = img.resize((THUMB_W, round(THUMB_W * img.height / img.width)), Image.LANCZOS)
    pad = 20
    sheet = Image.new("RGB", (len(colors) * (THUMB_W + pad) + pad, th.height + 2 * pad + 30), (246, 242, 235))
    d = ImageDraw.Draw(sheet)
    lab = ImageFont.truetype(str(ROOT / "fonts" / "ArchivoBlack-Regular.ttf"), 16)
    for i, name in enumerate(colors or ["White"]):
        tile = Image.new("RGBA", th.size, GARMENT_RGB.get(name, (200, 200, 200)) + (255,))
        tile.alpha_composite(th)
        x = pad + i * (THUMB_W + pad)
        sheet.paste(tile.convert("RGB"), (x, pad))
        d.text((x, pad + th.height + 6), name, font=lab, fill=(29, 43, 69))
    sheet.save(out)


def main(args: list[str]) -> int:
    folders = []
    for arg in args:
        p = Path(arg)
        folders += [p] if (p / "listing.json").exists() else sorted(q for q in p.iterdir() if (q / "listing.json").exists())
    bad = 0
    for folder in folders:
        fails, warns, info = check(folder)
        status = "FAIL" if fails else "WARN" if warns else "PASS"
        bad += bool(fails)
        print(f"\n[{status}] {folder.name}   (look at {folder / 'thumbs.png'})")
        for tag, lines in (("FAIL", fails), ("WARN", warns), ("ok  ", info)):
            for line in lines:
                print(f"  {tag} {line}")
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    raise SystemExit(main(sys.argv[1:]))
