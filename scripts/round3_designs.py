"""Round 3 designs: two-tone accent mugs and a knit 'ugly sweater' Christmas crewneck.

Usage:  python scripts/round3_designs.py
Writes designs-round-3/<slug>/ with design.png, mockup.png and listing.json.
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from etsy_agent.compliance import AI_DISCLOSURE, listing_problems  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from etsy_agent.render import make_mockup  # noqa: E402

OUT = ROOT / "designs-round-3"
FONTS = ROOT / "fonts"
NAVY, LIME, CREAM, RED, GREEN, GOLD = "#1D2B45", "#C9E33B", "#FBF3E4", "#D7263D", "#2E7D32", "#F2C14E"


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def fit_font(draw, text, name, width, start=1200):
    size = start
    while size > 20 and draw.textlength(text, font=font(name, size)) > width:
        size -= 4
    return font(name, size)


def ball(draw, cx, cy, r, fill=LIME, hole=NAVY, outline=NAVY):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline, width=max(6, r // 9))
    import math
    hr = max(5, int(r * 0.11))
    pts = [(0, 0)] + [(0.45 * r * math.cos(a), 0.45 * r * math.sin(a)) for a in [i * math.pi / 3 for i in range(6)]]
    for dx, dy in pts:
        draw.ellipse((cx + dx - hr, cy + dy - hr, cx + dx + hr, cy + dy + hr), fill=hole)


# ------------------------------------------------------------------ mugs
def mug_half(lines, accent_line):
    """One side of the mug: stacked type, ~1050x1000."""
    W, H = 1050, 1800  # tall scratch canvas; trimmed to the artwork below
    half = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(half)
    y = 40
    for text, fnt, color, gap in lines:
        f = fit_font(d, text, fnt, W - 60)
        d.text((W / 2, y), text, font=f, fill=color, anchor="ma")
        box = d.textbbox((W / 2, y), text, font=f, anchor="ma")
        y = box[3] + gap
    if accent_line:
        text, fnt, color = accent_line
        f = fit_font(d, text, fnt, 560, 150)
        tw = d.textlength(text, font=f)
        r = 58
        total = tw + 2 * r + 30
        x0 = (W - total) / 2
        ball(d, int(x0 + r), int(y + r), r)
        d.text((x0 + 2 * r + 30, y + r), text, font=f, fill=color, anchor="lm")
        y += 2 * r
    # trim to content and centre vertically
    box = half.getbbox()
    half = half.crop(box)
    return half


def mug(lines, accent_line) -> bytes:
    W, H = 2475, 1155
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    side = mug_half(lines, accent_line)
    scale = min(1050 / side.width, 1000 / side.height)
    side = side.resize((int(side.width * scale), int(side.height * scale)), Image.LANCZOS)
    for cx in (W // 4, 3 * W // 4):
        canvas.alpha_composite(side, (cx - side.width // 2, (H - side.height) // 2))
    buf = io.BytesIO()
    canvas.save(buf, format="PNG", dpi=(300, 300))
    return buf.getvalue()


def mug_mockup(png: bytes, accent: str) -> bytes:
    art = Image.open(io.BytesIO(png)).convert("RGBA")
    W, H = 1600, 1100
    m = Image.new("RGB", (W, H), "#EFEDE7")
    d = ImageDraw.Draw(m)
    body = (260, 170, 1180, 960)
    d.rounded_rectangle((body[2] - 60, 330, body[2] + 230, 800), radius=150, outline=accent, width=70)
    d.rounded_rectangle(body, radius=40, fill="#FFFFFF")
    d.rectangle((body[0], body[1], body[2], body[1] + 34), fill=accent)
    side = art.crop((0, 0, art.width // 2, art.height))
    side = side.crop(side.getbbox())
    s = min(780 / side.width, 640 / side.height)
    side = side.resize((int(side.width * s), int(side.height * s)), Image.LANCZOS)
    m.paste(side, ((body[0] + body[2]) // 2 - side.width // 2, (body[1] + body[3]) // 2 - side.height // 2 + 20), side)
    buf = io.BytesIO()
    m.save(buf, format="PNG")
    return buf.getvalue()


# ------------------------------------------------------------------ ugly sweater
SNOW = ["...#...", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "...#..."]
BALL = ["..###..", ".#####.", "#.###.#", "#######", "##.#.##", ".#####.", "..###.."]
TREE = ["...#...", "..###..", ".#####.", "..###..", ".#####.", "#######", "...#..."]


def ugly_sweater() -> bytes:
    W, H = 4500, 5400
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cell = 54
    cols = 78
    x0 = (W - cols * cell) // 2

    def px(cx, cy, color):
        d.rectangle((x0 + cx * cell, cy, x0 + (cx + 1) * cell - 1, cy + cell - 1), fill=color)

    def zigzag(y, color):
        for c in range(cols):
            k = c % 4
            px(c, y + (cell if k in (1, 3) else (0 if k == 0 else 2 * cell)), color)

    def motif_row(y):
        motifs = [(SNOW, CREAM), (BALL, LIME), (TREE, CREAM), (BALL, LIME)]
        c = 1
        i = 0
        while c + 7 <= cols:
            pattern, color = motifs[i % len(motifs)]
            for r, row in enumerate(pattern):
                for k, ch in enumerate(row):
                    if ch == "#":
                        px(c + k, y + r * cell, color)
            c += 10
            i += 1

    def band(y):
        for c in range(cols):
            px(c, y, RED)
        zigzag(y + 2 * cell, CREAM)
        motif_row(y + 6 * cell)
        zigzag(y + 14 * cell, CREAM)
        for c in range(cols):
            px(c, y + 18 * cell, RED)
        return y + 19 * cell

    y = band(260)
    # Title text in blocky type with a red drop shadow
    lines = [("JINGLE ALL", "Bungee-Regular.ttf", CREAM), ("THE WAY TO", "Bungee-Regular.ttf", CREAM),
             ("THE KITCHEN", "Bungee-Regular.ttf", LIME)]
    y += 170
    for text, fnt, color in lines:
        f = fit_font(d, text, fnt, cols * cell - 200)
        d.text((W / 2 + 34, y + 34), text, font=f, fill=RED, anchor="ma")
        d.text((W / 2, y), text, font=f, fill=color, anchor="ma")
        y = d.textbbox((W / 2, y), text, font=f, anchor="ma")[3] + 90
    band(y + 60)
    buf = io.BytesIO()
    img.save(buf, format="PNG", dpi=(300, 300))
    return buf.getvalue()


# ------------------------------------------------------------------ listings
def listing(slug, title, tags, hook, who, about, alt, products, occasion):
    desc = f"{hook}\n\nWho it's for:\n" + "\n".join(f"- {w}" for w in who) + f"\n\nAbout the design:\n{about}\n\n{AI_DISCLOSURE}"
    data = {"slug": slug, "verdict_for_old_design": "new (round 3)", "title": title, "tags": tags,
            "description": desc, "alt_text": alt, "products": products, "occasion": occasion}
    problems = listing_problems(data, PICKLEBALL.blocked_terms)
    if problems:
        raise SystemExit(f"{slug}: {problems}")
    return data


def save(slug, design: bytes, mockup: bytes, data: dict):
    d = OUT / slug
    d.mkdir(parents=True, exist_ok=True)
    (d / "design.png").write_bytes(design)
    (d / "mockup.png").write_bytes(mockup)
    (d / "listing.json").write_text(json.dumps(data, indent=2) + "\n")
    print(slug)


def main():
    # Mug 1
    png = mug([("I'M NOT YELLING,", "Anton-Regular.ttf", NAVY, 30), ("I'M CALLING", "Anton-Regular.ttf", NAVY, 30),
               ("THE SCORE", "Anton-Regular.ttf", GREEN, 50)], ("0-0-2!", "Anton-Regular.ttf", NAVY))
    save("not-yelling-calling-the-score-mug", png, mug_mockup(png, "#9BCB3C"), listing(
        "not-yelling-calling-the-score-mug",
        "Funny Pickleball Mug, I'm Not Yelling I'm Calling the Score, Two-Tone Coffee Mug Gift for Players",
        ["pickleball mug", "funny pickleball mug", "pickleball gift", "calling the score", "pickleball coffee",
         "gift for him", "gift for her", "pickleball lover", "two tone mug", "pickleball humor",
         "coffee mug gift", "pickleball player", "retirement mug"],
        "Every pickleball player knows someone who calls the score loud enough for the next three courts. Now they have the mug to prove it.",
        ["The friend who calls 0-0-2 louder than anyone", "Birthday, Christmas and Secret Santa gifts under $20",
         "Club gift exchanges and thank-you gifts"],
        "Bold stacked lettering, 'I'm not yelling, I'm calling the score', with a pickleball and '0-0-2!', printed on both sides. Choose a lime green or black handle and inside.",
        "White mug with a lime green handle reading I'm not yelling, I'm calling the score, 0-0-2.",
        [{"type": "mug-accent", "colors": ["Light Green", "Black"]}], "year-round"))
    # Mug 2
    png = mug([("PROFESSIONAL", "Anton-Regular.ttf", NAVY, 20), ("DINKER", "Anton-Regular.ttf", GREEN, 40),
               ("AMATEUR AT EVERYTHING ELSE", "Anton-Regular.ttf", NAVY, 30)], None)
    save("professional-dinker-mug", png, mug_mockup(png, "#9BCB3C"), listing(
        "professional-dinker-mug",
        "Professional Dinker Mug, Funny Pickleball Coffee Mug, Two-Tone Pickleball Gift for Men and Women",
        ["professional dinker", "pickleball mug", "funny pickleball mug", "pickleball gift", "dink mug",
         "pickleball coffee", "gift for him", "gift for her", "two tone mug", "pickleball humor",
         "coffee mug gift", "pickleball lover", "pickleballer"],
        "Professional dinker, amateur at everything else. A funny pickleball mug for the player whose real job is the kitchen line.",
        ["Players who would rather dink than do chores", "Birthday, retirement and Christmas gifts",
         "Club and league gift exchanges"],
        "Big stacked lettering, 'Professional DINKER, amateur at everything else', printed on both sides. Choose a lime green or black handle and inside.",
        "White mug with a lime green handle reading Professional Dinker, amateur at everything else.",
        [{"type": "mug-accent", "colors": ["Light Green", "Black"]}], "year-round"))
    # Ugly sweater
    png = ugly_sweater()
    save("jingle-all-the-way-to-the-kitchen", png, make_mockup(png, "#1F4A33"), listing(
        "jingle-all-the-way-to-the-kitchen",
        "Pickleball Ugly Christmas Sweater, Jingle All the Way to the Kitchen Sweatshirt, Funny Pickleball Gift",
        ["pickleball christmas", "ugly sweater", "ugly xmas sweater", "pickleball sweater", "pickleball gift",
         "jingle all the way", "christmas sweatshirt", "funny pickleball", "holiday party shirt",
         "pickleball lover", "secret santa gift", "kitchen pickleball", "christmas pickleball"],
        "Jingle all the way... to the kitchen. An ugly-Christmas-sweater style pickleball sweatshirt for holiday parties and the courts.",
        ["Pickleball players heading to an ugly sweater party", "Christmas, Secret Santa and stocking-stuffer shoppers",
         "Clubs planning a holiday round-robin"],
        "Knit-style bands of snowflakes, pickleballs and trees around blocky 'Jingle all the way to the kitchen' lettering. Printed on a soft crewneck sweatshirt.",
        "Forest green sweatshirt with a knit-style pattern of snowflakes, pickleballs and trees around the words Jingle all the way to the kitchen.",
        [{"type": "crewneck", "colors": ["Forest Green", "Maroon", "Navy", "Black"]}], "Christmas"))


if __name__ == "__main__":
    main()
