"""Put together the Roblox front-page style store art: both thumbnails, the icon and the logo.

Plain Python with Pillow (no Blender). Reads the renders in $STORE_OUT (from thumbnail_tower.py,
thumbnail_reveal.py, icon_bacon.py, logo.py and words.py) and writes the finished images to
$STORE_OUT/final/:
  hollywood-rng-thumbnail-tower-1920x1080.png   A: the studio tower, "$1,000,000/s"
  hollywood-rng-thumbnail-reveal-1920x1080.png  B: ticket to superstar, "1 IN 1,000,000"
  hollywood-rng-icon-512.png
  hollywood-rng-logo.png
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from compose import FINAL, OUT, load, logo, paste, punch, word

FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fonts", "LuckiestGuy.ttf")
W, H = 1920, 1080


def gradient(size, top, bottom):
    w, h = size
    im = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        im.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return im.resize((w, h)).convert("RGBA")


def sunburst(size, centre, rays=18, color=(255, 255, 255, 70), spin=0.0):
    """Wedges of light fanning out from `centre`, like the rays behind a front-page hero."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = math.hypot(w, h)
    for i in range(rays):
        a0 = math.radians(spin + i * 360 / rays)
        a1 = a0 + math.radians(360 / rays * 0.45)
        d.polygon([centre, (centre[0] + r * math.cos(a0), centre[1] + r * math.sin(a0)),
                   (centre[0] + r * math.cos(a1), centre[1] + r * math.sin(a1))], fill=color)
    return layer


def soft_glow(size, centre, radius, color):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse((centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius), fill=color)
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.45))


def place_left(base, im, x, y):
    """Paste a word with its left edge at x and its middle at y."""
    paste(base, im, (x + im.width / 2, y), shadow=(8, 10), shadow_alpha=0.45, blur=8)


def fit(name, height, max_width, angle=0.0):
    im = word(name, height)
    if im.width > max_width:
        im = word(name, round(height * max_width / im.width))
    return im.rotate(angle, resample=Image.BICUBIC, expand=True) if angle else im


def thumbnail_tower():
    scene = punch(load("tower_scene.png").convert("RGB"), saturation=1.1, contrast=1.04).convert("RGBA")
    place_left(scene, fit("superstars", round(H * 0.14), W * 0.47, 3), 40, H * 0.11)
    place_left(scene, fit("per_second", round(H * 0.17), W * 0.47, 3), 34, H * 0.27)
    return scene.convert("RGB")


def checks(size, cell, top, bottom, shade=0.9):
    """A two-tone checkerboard over a top-to-bottom colour fade (the left of the reveal)."""
    base = gradient(size, top, bottom)
    dark = Image.new("L", size, 0)
    d = ImageDraw.Draw(dark)
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            if (x // cell + y // cell) % 2:
                d.rectangle((x, y, x + cell - 1, y + cell - 1), fill=255)
    shaded = base.point(lambda v: int(v * shade))
    return Image.composite(shaded, base, dark)


def arrow(base, start, control, end, width=34):
    """A fat red curved arrow with a dark outline, from `start` bending through `control` to `end`."""
    pts = []
    for i in range(41):
        t = i / 40
        x = (1 - t) ** 2 * start[0] + 2 * (1 - t) * t * control[0] + t ** 2 * end[0]
        y = (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * control[1] + t ** 2 * end[1]
        pts.append((x, y))
    dx, dy = end[0] - pts[-4][0], end[1] - pts[-4][1]
    n = math.hypot(dx, dy)
    ux, uy = dx / n, dy / n
    head = width * 1.9
    tip = (end[0] + ux * head * 0.75, end[1] + uy * head * 0.75)
    wing = [(end[0] - uy * head * 0.8, end[1] + ux * head * 0.8), tip, (end[0] + uy * head * 0.8, end[1] - ux * head * 0.8)]
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for color, grow in (((27, 22, 40, 255), 12), ((235, 52, 52, 255), 0)):
        d = ImageDraw.Draw(layer)
        d.line(pts[:-2], fill=color, width=width + grow * 2, joint="curve")
        r = (width + grow * 2) / 2
        d.ellipse((pts[0][0] - r, pts[0][1] - r, pts[0][0] + r, pts[0][1] + r), fill=color)
        if grow:
            big = [(end[0] - uy * (head * 0.8 + grow * 1.6), end[1] + ux * (head * 0.8 + grow * 1.6)),
                   (tip[0] + ux * grow * 2, tip[1] + uy * grow * 2),
                   (end[0] + uy * (head * 0.8 + grow * 1.6), end[1] - ux * (head * 0.8 + grow * 1.6))]
            d.polygon([(x - ux * grow, y - uy * grow) for x, y in big], fill=color)
        else:
            d.polygon(wing, fill=color)
    paste(base, layer, (base.width / 2, base.height / 2), shadow=(6, 8), shadow_alpha=0.4, blur=6)


def prompt_label(text, height=104):
    """The dark rounded "[E] CAST" key prompt, like an in-game ProximityPrompt."""
    font = ImageFont.truetype(FONT, round(height * 0.62))
    box = font.getbbox(text)
    w = box[2] - box[0] + round(height * 0.7)
    im = Image.new("RGBA", (w, height), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, height - 1), radius=round(height * 0.24), fill=(22, 26, 44, 225))
    d.text((w / 2, height / 2 + height * 0.04), text, font=font, fill=(255, 255, 255, 255), anchor="mm")
    return im


def thumbnail_reveal():
    split_top, split_bottom = W * 0.53, W * 0.47
    left = checks((W, H), 90, (64, 156, 255), (67, 205, 110))
    left.alpha_composite(soft_glow((W, H), (W * 0.25, H * 0.56), 360, (190, 110, 255, 170)))
    right = gradient((W, H), (31, 123, 255), (191, 230, 255))
    star_c = (W * 0.75, H * 0.5)
    right.alpha_composite(sunburst((W, H), star_c, rays=20, color=(255, 255, 255, 60), spin=4))
    right.alpha_composite(soft_glow((W, H), star_c, 330, (255, 246, 190, 150)))
    star = load("reveal_star.png")
    right.alpha_composite(star, (round(star_c[0] - star.width / 2), H - star.height))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon([(split_top, 0), (W, 0), (W, H), (split_bottom, H)], fill=255)
    canvas = Image.composite(right, left, mask)
    ticket = load("reveal_ticket.png")
    canvas.alpha_composite(ticket, (round(W * 0.25 - ticket.width / 2), round(H * 0.56 - ticket.height / 2)))
    canvas = punch(canvas.convert("RGB"), saturation=1.08, contrast=1.04).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    d.line([(split_top, -10), (split_bottom, H + 10)], fill=(27, 22, 40, 255), width=26)
    d.line([(split_top, -10), (split_bottom, H + 10)], fill=(255, 255, 255, 255), width=12)
    label = prompt_label("[E] CAST")
    paste(canvas, label, (W * 0.25, H * 0.13), shadow=(6, 8), shadow_alpha=0.35, blur=6)
    arrow(canvas, (W * 0.33, H * 0.83), (W * 0.45, H * 0.94), (W * 0.545, H * 0.72))
    caption = fit("one_in_million", round(H * 0.16), W * 0.5, 4)
    paste(canvas, caption, (W * 0.745, H * 0.12), shadow=(8, 10), shadow_alpha=0.45, blur=8)
    return canvas.convert("RGB")


def icon():
    size = 1024
    bg = gradient((size, size), (36, 128, 255), (110, 196, 255))
    bg.alpha_composite(sunburst((size, size), (size * 0.5, size * 0.44), rays=16, color=(255, 255, 255, 55), spin=8))
    bg.alpha_composite(soft_glow((size, size), (size * 0.5, size * 0.42), 300, (255, 244, 200, 140)))
    player = load("icon_bacon.png")
    bg.alpha_composite(player.resize((size, size), Image.LANCZOS))
    return punch(bg.convert("RGB"), saturation=1.06).resize((512, 512), Image.LANCZOS)


if __name__ == "__main__":
    os.makedirs(FINAL, exist_ok=True)
    thumbnail_tower().save(os.path.join(FINAL, "hollywood-rng-thumbnail-tower-1920x1080.png"))
    thumbnail_reveal().save(os.path.join(FINAL, "hollywood-rng-thumbnail-reveal-1920x1080.png"))
    icon().save(os.path.join(FINAL, "hollywood-rng-icon-512.png"))
    logo().save(os.path.join(FINAL, "hollywood-rng-logo.png"))
    print("Wrote", FINAL)
