"""The intro stage's image textures (src/client/StageScene.luau, src/client/IntroScene.luau), made
from the Figma storyboard (https://www.figma.com/design/UgevrNkTl6lvragsvDCfmm, frames 5:74 to
5:229 and the logo reveal 8:74). The Figma exports are in art/ui/intro/figma/.

  intro_curtain.png    one velvet fold cut from the Figma curtain (node 5:233); the game tiles it
                       across each curtain panel
  intro_valance.png    one scallop of the valance (Figma 5:249 to 5:266: the band, a scallop with
                       its gold edge, the gold rail), transparent under the scallop, tiled across
  intro_starburst.png  the logo's starburst (Figma 8:75): 24 rays in two strengths of gold
  intro_spot.png       a spotlight cone (Figma 5:313): cream, fading from top to bottom
  intro_sparkle.png    a four-point sparkle with a soft glow (Figma 8:227)

Only Blender's own Python (numpy) is needed. Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/intro_textures.py
"""

import math
import os

import bpy
import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(REPO, "art", "ui", "intro", "figma")
OUT = os.path.join(REPO, "art", "ui", "intro")


def load(name):
    """RGBA float array, row 0 at the top."""
    img = bpy.data.images.load(os.path.join(SRC, name))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    return px


def save(name, px):
    h, w = px.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.ascontiguousarray(px[::-1]).ravel()
    img.filepath_raw = os.path.join(OUT, name)
    img.file_format = "PNG"
    img.save()
    print("Wrote", img.filepath_raw, w, h)


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


def grid(w, h, ss=4):
    """Sample centres (x, y) at `ss` x `ss` supersampling, in pixel units, row 0 at the top."""
    ys, xs = np.mgrid[0 : h * ss, 0 : w * ss].astype(np.float32)
    return (xs + 0.5) / ss, (ys + 0.5) / ss


def downsample(a, ss=4):
    h, w = a.shape[0] // ss, a.shape[1] // ss
    return a.reshape(h, ss, w, ss, *a.shape[2:]).mean(axis=(1, 3))


def over(dst, color, alpha):
    """Paint `color` with per-pixel `alpha` over premultiplied-free RGBA `dst`."""
    a = alpha[..., None]
    out_a = a + dst[..., 3:4] * (1 - a)
    rgb = (color * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    dst[..., :3], dst[..., 3:4] = rgb, out_a


def curtain():
    px = load("curtainL.png")
    # Figma draws three 50 px folds; the middle one tiles cleanly. Leave out the 14 px gold hem
    # (the game draws the hem as its own bar so it stays the same thickness on every screen).
    save("intro_curtain.png", px[0:706, 50:100].copy())


def valance():
    # Figma (1x): band 0..64 in the valance red, scallops 90 x 56 every 80 px from x = -5 at
    # y = 36 with a 3 px gold edge, and a gold rail at y 58..66. One tile = 80 x 92, drawn at 2x.
    k, ss = 2, 4
    w, h = 80 * k, 92 * k
    closed = load("closed.png")
    band_top, band_bottom = closed[4, 640, :3], closed[33, 640, :3]
    scallop = closed[80, 40, :3]
    gold = hexrgb("#F5B82E")
    x, y = grid(w, h, ss)
    x, y = x / k, y / k
    img = np.zeros((h * ss, w * ss, 4), dtype=np.float32)
    t = np.clip(y / 64, 0, 1)[..., None]
    over(img, band_top * (1 - t) + band_bottom * t, (y < 64).astype(np.float32))
    for cx in (35.0, 115.0, -45.0):  # this scallop, and its neighbours' edges that reach in
        d = ((x - cx) / 45) ** 2 + ((y - 64) / 28) ** 2
        inside = (d <= 1).astype(np.float32)
        edge = np.abs(np.sqrt(d) - 1) * 28 < 1.6
        over(img, scallop, inside)
        over(img, gold, edge.astype(np.float32))
    over(img, gold, ((y >= 58) & (y < 66)).astype(np.float32))
    save("intro_valance.png", downsample(img, ss))


def starburst():
    size, ss = 1024, 2
    x, y = grid(size, size, ss)
    c = size / 2
    angle = (np.degrees(np.arctan2(y - c, x - c)) + 360) % 360
    r = np.hypot(x - c, y - c) / c
    ray = np.floor(angle / 15).astype(int)
    inside = (angle % 15) < 6.0  # each ray is 6 of every 15 degrees, as in Figma
    alpha = np.where(ray % 2 == 0, 0.18, 0.1) * inside * np.clip((1 - r) / 0.08, 0, 1)
    img = np.zeros((size * ss, size * ss, 4), dtype=np.float32)
    img[..., :3] = hexrgb("#FFD84A")
    img[..., 3] = alpha
    out = downsample(img, ss)
    # Rays fade towards the middle, where the marquee sits.
    save("intro_starburst.png", out)


def spot():
    # Figma: from a 28 px top to a 240 px foot over 640 px, cream at 0.3 fading to 0.02. Drawn
    # symmetric, at 256 x 640; the game turns each cone to sweep.
    w, h, ss = 256, 640, 4
    x, y = grid(w, h, ss)
    t = y / h
    half = (14 + (120 - 14) * t) * (w / 240)
    soft = np.clip((half - np.abs(x - w / 2)) / 6, 0, 1)
    img = np.zeros((h * ss, w * ss, 4), dtype=np.float32)
    img[..., :3] = hexrgb("#FFF4C8")
    img[..., 3] = soft * (0.3 + (0.02 - 0.3) * t) / 0.3  # full strength at the top; the game sets transparency
    save("intro_spot.png", downsample(img, ss))


def sparkle():
    size, ss = 128, 4
    x, y = grid(size, size, ss)
    c = size / 2
    dx, dy = np.abs(x - c) / c, np.abs(y - c) / c
    # A four-point star: |x|^0.5 + |y|^0.5 <= 1, plus a soft round glow.
    star = (np.sqrt(dx) + np.sqrt(dy) <= 0.92).astype(np.float32)
    glow = np.clip(1 - np.hypot(dx, dy) / 0.55, 0, 1) ** 2 * 0.55
    img = np.zeros((size * ss, size * ss, 4), dtype=np.float32)
    img[..., :3] = hexrgb("#FFF6D8")
    img[..., 3] = np.maximum(star, glow)
    save("intro_sparkle.png", downsample(img, ss))


if __name__ == "__main__":
    curtain()
    valance()
    starburst()
    spot()
    sparkle()
