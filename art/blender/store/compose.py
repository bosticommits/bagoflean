"""Put the store art together: words on the thumbnail, the icon at 512, and a cropped logo.

Plain Python with Pillow (no Blender). Reads the renders in $STORE_OUT and writes the finished
images to $STORE_OUT/final/.
"""

import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

OUT = os.environ.get("STORE_OUT", "/tmp/store")
FINAL = os.path.join(OUT, "final")


def load(name):
    return Image.open(os.path.join(OUT, name)).convert("RGBA")


def word(name, height, angle=0.0):
    """A caption render scaled to `height` pixels and tilted by `angle` degrees."""
    im = load(os.path.join("words", f"{name}.png"))
    im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
    if angle:
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
    return im


def paste(base, im, centre, shadow=(10, 12), shadow_alpha=0.5, blur=8):
    """Paste `im` centred at `centre`, over a soft drop shadow."""
    x = round(centre[0] - im.width / 2)
    y = round(centre[1] - im.height / 2)
    if shadow:
        alpha = im.getchannel("A").point(lambda a: int(a * shadow_alpha))
        sh = Image.new("RGBA", im.size, (10, 8, 30, 0))
        sh.putalpha(alpha)
        sh = sh.filter(ImageFilter.GaussianBlur(blur))
        base.alpha_composite(sh, (x + shadow[0], y + shadow[1]))
    base.alpha_composite(im, (x, y))


def vignette(im, strength=0.28):
    w, h = im.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * 0.18, -h * 0.25, w * 1.18, h * 1.25), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) // 6))
    dark = ImageEnhance.Brightness(im).enhance(1 - strength)
    return Image.composite(im, dark, mask)


def punch(im, saturation=1.08, contrast=1.05):
    im = ImageEnhance.Color(im).enhance(saturation)
    return ImageEnhance.Contrast(im).enhance(contrast)


def thumbnail():
    scene = punch(vignette(load("thumbnail_scene.png").convert("RGB"))).convert("RGBA")
    w, h = scene.size
    paste(scene, word("one_in", round(h * 0.125), 6), (w * 0.115, h * 0.10))
    paste(scene, word("million", round(h * 0.235), 6), (w * 0.28, h * 0.25))
    paste(scene, word("icon", round(h * 0.19), -5), (w * 0.855, h * 0.64))
    return scene.convert("RGB")


def sticker(im, width=12, color=(255, 255, 255, 255)):
    """Crop a cutout to its edges and give it a solid outline, like a sticker."""
    im = im.crop(im.getchannel("A").getbbox())
    pad = width + 4
    padded = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    padded.alpha_composite(im, (pad, pad))
    ring = padded.getchannel("A").point(lambda a: 255 if a > 40 else 0).filter(ImageFilter.MaxFilter(2 * width + 1))
    out = Image.new("RGBA", padded.size, color)
    out.putalpha(ring.filter(ImageFilter.GaussianBlur(1)))
    out.alpha_composite(padded)
    return out


def thumbnail_lots():
    """Day one on the left, fully upgraded on the right, split on a slant, with the player on each."""
    w, h = 1920, 1080
    left = load("lots_before.png").convert("RGB")
    left = ImageEnhance.Brightness(ImageEnhance.Color(left).enhance(0.7)).enhance(0.94)
    right = load("lots_after.png").convert("RGB")
    canvas = Image.new("RGB", (w, h))
    canvas.paste(left, (round(w * 0.26 - left.width / 2), 0))
    after = Image.new("RGB", (w, h))
    after.paste(right, (round(w * 0.74 - right.width / 2), 0))
    top_x, bottom_x = w * 0.535, w * 0.465
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon([(top_x, 0), (w, 0), (w, h), (bottom_x, h)], fill=255)
    canvas = Image.composite(after, canvas, mask)
    canvas = punch(vignette(canvas, 0.2)).convert("RGBA")
    # The sad player is mirrored so both players face the middle.
    for name, x, colour, flip in (("player_sad", 0.1, (214, 222, 232, 255), True),
                                  ("player_cool", 0.9, (255, 214, 92, 255), False)):
        cut = load(f"{name}.png")
        if flip:
            cut = ImageOps.mirror(cut)
        cut = sticker(cut, color=colour)
        scale = h * 0.68 / cut.height
        cut = cut.resize((round(cut.width * scale), round(cut.height * scale)), Image.LANCZOS)
        paste(canvas, cut, (w * x, h * 0.4 + cut.height / 2), shadow=(12, 14), shadow_alpha=0.45, blur=10)
    draw = ImageDraw.Draw(canvas)
    draw.line([(top_x, -10), (bottom_x, h + 10)], fill=(27, 35, 64, 255), width=24)
    draw.line([(top_x, -10), (bottom_x, h + 10)], fill=(255, 255, 255, 255), width=10)
    paste(canvas, word("noob", round(h * 0.16), 4), (w * 0.25, h * 0.11))
    paste(canvas, word("mogul", round(h * 0.2), -4), (w * 0.75, h * 0.12))
    paste(canvas, word("arrow", round(h * 0.19)), (w * 0.5, h * 0.47))
    return canvas.convert("RGB")


def icon():
    scene = punch(vignette(load("icon_scene.png").convert("RGB"), 0.22)).convert("RGBA")
    w, h = scene.size
    paste(scene, word("rng", round(h * 0.2), -6), (w * 0.76, h * 0.85), shadow=(8, 10))
    return scene.convert("RGB").resize((512, 512), Image.LANCZOS)


def logo():
    im = load("logo.png")
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    pad = 24
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, im.width), min(box[3] + pad, im.height))
    return im.crop(box)


if __name__ == "__main__":
    os.makedirs(FINAL, exist_ok=True)
    thumbnail().save(os.path.join(FINAL, "hollywood-rng-thumbnail-1920x1080.png"))
    if os.path.exists(os.path.join(OUT, "lots_after.png")):
        thumbnail_lots().save(os.path.join(FINAL, "hollywood-rng-thumbnail-lots-1920x1080.png"))
    icon().save(os.path.join(FINAL, "hollywood-rng-icon-512.png"))
    logo().save(os.path.join(FINAL, "hollywood-rng-logo.png"))
    print("Wrote", FINAL)
