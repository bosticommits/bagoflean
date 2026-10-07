"""Put our designs onto REAL photos of blank shirts (the most convincing listing photos).

Usage:
  python scripts/photo_templates.py list                       # templates and whether they're set up
  python scripts/photo_templates.py <slug> [<slug> ...]        # render every matching template
  python scripts/photo_templates.py <slug> --template flatlay-white-tee

How it works:
  photo_templates/<name>.jpg    a real photo of a blank shirt (phone photo, licensed mockup photo)
  photo_templates/<name>.json   where the print goes, e.g.
      {
        "product": "tee",                    # tee, crewneck or any (which listings it's used for)
        "garment_color": "White",            # colour of the shirt in the photo
        "recolor": true,                     # true: recolour a white/grey shirt to the listing colour
        "print_quad": [[812, 640], [1390, 640], [1395, 1360], [808, 1362]],
                                             # corners of the print area: top-left, top-right,
                                             # bottom-right, bottom-left (chest width x print height)
        "mask_seed": [1100, 1000],           # optional: a point on the shirt (default: quad centre)
        "source": "own photo, 2026-10-07"    # where the photo came from / licence
      }

The design is fitted to the quad's width and top, bent into its perspective, then
pushed around by the fabric's folds (displacement) and shaded by the photo's own light,
so it looks printed on that shirt rather than pasted on top.

Output: photos/<slug>/real-<template>.jpg (and real-<template>-<colour>.jpg for recoloured extras).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "photo_templates"
OUT = ROOT / "photos"
sys.path.insert(0, str(ROOT / "scripts"))
from photo_studio import GARMENT_RGB, find_design  # noqa: E402

SHIRTS = {"tee", "tee-cc", "crewneck"}


# ------------------------------------------------------------------ geometry
def perspective_coeffs(src: list, dst: list) -> list[float]:
    """Coefficients for PIL's Image.transform(PERSPECTIVE): maps output (dst) points to input (src)."""
    rows, rhs = [], []
    for (x, y), (u, v) in zip(dst, src):
        rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); rhs.append(u)
        rows.append([0, 0, 0, x, y, 1, -v * x, -v * y]); rhs.append(v)
    return np.linalg.solve(np.array(rows, float), np.array(rhs, float)).tolist()


def warp_design(design: Image.Image, quad: list, size: tuple[int, int]) -> Image.Image:
    """Trim the design to its art, fit it to the quad's width (top-aligned), warp into the photo frame."""
    art = design.crop(design.getchannel("A").getbbox())
    tl, tr, br, bl = [np.array(p, float) for p in quad]
    quad_w = (np.linalg.norm(tr - tl) + np.linalg.norm(br - bl)) / 2
    quad_h = (np.linalg.norm(bl - tl) + np.linalg.norm(br - tr)) / 2
    # art box in quad-relative units (0..1): full width, height by aspect, capped at the quad height
    h_rel = min(1.0, (art.height / art.width) * quad_w / quad_h)
    w_rel = 1.0 if h_rel < 1.0 else (art.width / art.height) * quad_h / quad_w
    x0 = (1 - w_rel) / 2

    def at(u, v):  # bilinear point inside the quad
        top, bot = tl + (tr - tl) * u, bl + (br - bl) * u
        return tuple(top + (bot - top) * v)

    dst = [at(x0, 0), at(x0 + w_rel, 0), at(x0 + w_rel, h_rel), at(x0, h_rel)]
    # supersample the source a little so the downscale is clean
    target_w = int(max(np.linalg.norm(np.subtract(dst[1], dst[0])), 10) * 1.5)
    art = art.resize((target_w, int(target_w * art.height / art.width)), Image.LANCZOS)
    src = [(0, 0), (art.width, 0), (art.width, art.height), (0, art.height)]
    return art.transform(size, Image.PERSPECTIVE, perspective_coeffs(src, dst), Image.BICUBIC)


# ------------------------------------------------------------------ photo analysis
def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114


def blur(arr: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)


def garment_mask(photo: np.ndarray, seed: tuple[int, int], tol: float = 38.0) -> np.ndarray:
    """Flood-fill the shirt from a seed point by colour similarity, then smooth the edge."""
    h, w = photo.shape[:2]
    small_w = 600
    k = w / small_w
    sm = np.asarray(Image.fromarray(photo.astype(np.uint8)).resize((small_w, int(h / k))), dtype=np.float32)
    sm = blur(sm, 2)
    sy, sx = int(seed[1] / k), int(seed[0] / k)
    ref = sm[sy, sx]
    close = np.linalg.norm(sm - ref, axis=2) < tol
    # also accept shadowed parts of the same fabric (same hue, darker)
    lum = luminance(sm)
    chroma = sm / (lum[..., None] + 1)
    ref_chroma = ref / (luminance(ref[None, None])[0, 0] + 1)
    close |= (np.linalg.norm(chroma - ref_chroma, axis=2) < 0.12) & (lum > 25)
    # never grow into the background (white shirt on white backdrop): estimate the backdrop
    # colour from the image border and exclude anything within a few levels of it
    border = np.concatenate([sm[0], sm[-1], sm[:, 0], sm[:, -1]])
    backdrop = np.median(border, axis=0)
    if np.linalg.norm(ref - backdrop) > 4:
        close &= np.linalg.norm(sm - backdrop, axis=2) > min(10.0, np.linalg.norm(ref - backdrop) * 0.6)
    mask = np.zeros_like(close)
    stack = [(sy, sx)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < close.shape[0] and 0 <= x < close.shape[1] and close[y, x] and not mask[y, x]:
            mask[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    # fill holes (logos, highlights) that the fill went around: everything not reachable from the border
    outside = np.zeros_like(mask)
    stack = [(y, x) for y in range(mask.shape[0]) for x in (0, mask.shape[1] - 1)] + \
            [(y, x) for x in range(mask.shape[1]) for y in (0, mask.shape[0] - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < mask.shape[0] and 0 <= x < mask.shape[1] and not mask[y, x] and not outside[y, x]:
            outside[y, x] = True
            stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    mask = ~outside
    m = Image.fromarray((mask * 255).astype(np.uint8))
    # close small holes, then pull the edge in a little so no background fringe gets recoloured
    m = m.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MinFilter(3))
    m = m.filter(ImageFilter.GaussianBlur(1.0))
    return np.asarray(m.resize((w, h), Image.BILINEAR), dtype=np.float32) / 255.0


def recolor(photo: np.ndarray, mask: np.ndarray, target: tuple[int, int, int]) -> np.ndarray:
    """Recolour a white/light-grey shirt: keep its folds and light, swap the dye colour."""
    lum = luminance(photo)
    inside = mask > 0.5
    ref = np.percentile(lum[inside], 92) if inside.any() else 255.0
    shade = np.clip(lum / max(ref, 1), 0, 1.25)
    t = np.array(target, np.float32)
    dyed = t * np.minimum(shade, 1)[..., None]
    dyed += (255 - t) * np.clip(shade - 1, 0, 0.25)[..., None] * 0.8  # keep real highlights
    # dark dyes: lift the folds a little (dark fabric still shows soft highlights)
    if luminance(t[None, None])[0, 0] < 90:
        dyed += (shade[..., None] - 0.7).clip(0) * 40
    return photo * (1 - mask[..., None]) + dyed * mask[..., None]


def bilinear_sample(img: np.ndarray, ys: np.ndarray, xs: np.ndarray) -> np.ndarray:
    h, w = img.shape[:2]
    xs, ys = np.clip(xs, 0, w - 1.001), np.clip(ys, 0, h - 1.001)
    x0, y0 = xs.astype(int), ys.astype(int)
    fx, fy = (xs - x0)[..., None], (ys - y0)[..., None]
    a, b = img[y0, x0], img[y0, x0 + 1]
    c, d = img[y0 + 1, x0], img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def print_on_fabric(photo: np.ndarray, layer: np.ndarray, mask: np.ndarray | None) -> np.ndarray:
    """Composite an RGBA layer onto the photo with fabric displacement, light and texture."""
    h, w = photo.shape[:2]
    lum = luminance(photo)
    scale = w / 2000  # tuned on 2000 px wide photos
    # 1. displacement: ink follows the folds (gradient of the smoothed light)
    soft = blur(lum, 6 * scale)
    gy, gx = np.gradient(soft)
    amount = 3.5 * scale
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    layer = bilinear_sample(layer, ys + gy * amount, xs + gx * amount)
    # 2. light: shade the ink by the photo's own light relative to the local average
    local = blur(lum, 40 * scale)
    shade = np.clip((lum + 6) / (local + 6), 0.55, 1.35)
    # 3. texture: fine fabric grain from the photo
    grain = (lum - blur(lum, 1.2 * scale)) * 0.6
    ink = layer[..., :3] * shade[..., None] + grain[..., None]
    alpha = layer[..., 3:4] / 255.0 * 0.96
    if mask is not None:
        alpha *= mask[..., None]
    # DTG ink sits slightly into the fabric: a hint of the shirt colour shows through
    return photo * (1 - alpha) + ink * alpha


# ------------------------------------------------------------------ main
def load_templates() -> list[tuple[str, Path, dict | None]]:
    out = []
    for img in sorted(TEMPLATES.glob("*")):
        if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"):
            cfg = img.with_suffix(".json")
            out.append((img.stem, img, json.loads(cfg.read_text()) if cfg.exists() else None))
    return out


def render(slug: str, only: str | None = None) -> list[Path]:
    folder = find_design(slug)
    listing = json.loads((folder / "listing.json").read_text())
    product = listing["products"][0]
    ptype, colors = product["type"], product["colors"]
    design = Image.open(folder / "design.png").convert("RGBA")
    made = []
    for name, img_path, cfg in load_templates():
        if cfg is None or (only and name != only):
            continue
        tp = cfg.get("product", "any")
        if tp != "any" and not (tp == ptype or (tp == "tee" and ptype == "tee-cc")):
            continue
        photo_img = Image.open(img_path).convert("RGB")
        photo = np.asarray(photo_img, dtype=np.float32)
        quad = cfg["print_quad"]
        seed = cfg.get("mask_seed") or [int(sum(p[0] for p in quad) / 4), int(sum(p[1] for p in quad) / 4)]
        mask = garment_mask(photo, seed)
        targets = colors[:2] if cfg.get("recolor") else [cfg.get("garment_color")]
        for i, cname in enumerate(targets):
            base = recolor(photo, mask, GARMENT_RGB[cname]) if cfg.get("recolor") else photo
            layer = np.asarray(warp_design(design, quad, photo_img.size), dtype=np.float32)
            result = print_on_fabric(base, layer, mask)
            out = OUT / slug / (f"real-{name}.jpg" if i == 0 else f"real-{name}-{cname.lower().replace(' ', '-')}.jpg")
            out.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(np.clip(result, 0, 255).astype(np.uint8)).save(out, quality=92)
            made.append(out)
    return made


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("slugs", nargs="+")
    parser.add_argument("--template")
    args = parser.parse_args()
    if args.slugs == ["list"]:
        for name, img, cfg in load_templates():
            print(f"{name:32} {'ready: ' + cfg.get('product', 'any') if cfg else 'needs a .json (print_quad)'}")
        return
    for slug in args.slugs:
        for path in render(slug, args.template):
            print(path)


if __name__ == "__main__":
    main()
