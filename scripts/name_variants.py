"""Make "Pickleball <Name>" versions of the Grandma / Grandpa designs.

Usage:  python scripts/name_variants.py            # builds the default names
        python scripts/name_variants.py grandma Lolli Granny

Each version keeps the original artwork and swaps only the big name line, then
writes designs-round-2/pickleball-<name>-.../ with design.png, mockup.png and
listing.json (adapted from the original listing).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from etsy_agent.compliance import listing_problems  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from etsy_agent.render import make_mockup  # noqa: E402

FONT = ROOT / "fonts" / "ArchivoBlack-Regular.ttf"
D2 = ROOT / "designs-round-2"

BASES = {
    "grandma": {
        "src": "pickleball-grandma-sweet-sneaky",
        "word": "Grandma",
        "band": (2580, 3250),      # rows holding the big name in the original
        "cap": 2610, "base": 3240,
        "color": (29, 43, 69, 255),
        "mockup_hex": "#F2C4CE",
        "cc_colors": ["Blossom", "Ivory", "Chalky Mint", "Butter"],
        "names": ["Gigi", "Nana", "Mimi", "Memaw"],
        "slug_tail": "sweet-sneaky",
        "title": "Pickleball {N} Shirt, Sweet as Pie Sneaky at the Net, Funny Gift for {N} from Grandkids",
        "description": (
            "Sweet as pie off the court and sneaky at the net. A warm, funny pickleball shirt for the {N} "
            "everyone is scared to play against.\n\nWho it's for:\n- A {N} who plays pickleball every week\n"
            "- Grandkids and adult children looking for a gift she will actually wear\n"
            "- Mother's Day, birthday and Christmas shopping\n\nAbout the design:\nArched 'PICKLEBALL' over a "
            "big '{NU}', with two paddles and a ball, and the line 'Sweet as pie, sneaky at the net'."),
        "tags": ["pickleball {n}", "{n} gift", "{n} shirt", "gift for {n}", "pickleball grandma",
                 "grandma gift", "funny grandma shirt", "pickleball gift", "grandma birthday",
                 "pickleball lover", "mothers day gift", "pickleball humor", "pickleballer"],
    },
    "grandpa": {
        "src": "pickleball-grandpa-dinking-since-retirement",
        "word": "Grandpa",
        "band": (2560, 3250),
        "cap": 2610, "base": 3240,
        "color": (251, 243, 228, 255),
        "mockup_hex": "#1F4A33",
        "cc_colors": ["Blue Spruce", "Pepper", "Navy", "Black"],
        "names": ["Papa", "Pops", "Pawpaw", "Gramps"],
        "slug_tail": "dinking-since-retirement",
        "title": "Pickleball {N} Shirt, Dinking Since Retirement, Funny Retirement Gift for {N} from Grandkids",
        "description": (
            "He retired, bought a paddle, and hasn't been home since. A friendly pickleball shirt for the {N} "
            "who dinks for a living.\n\nWho it's for:\n- A {N} who lives at the pickleball courts\n"
            "- Retirement and birthday gifts from the grandkids\n- Father's Day and Christmas shopping\n\n"
            "About the design:\nArched gold 'PICKLEBALL' over a big cream '{NU}', with paddles and a ball, "
            "plus a lime 'Dinking since retirement' line."),
        "tags": ["pickleball {n}", "{n} gift", "{n} shirt", "gift for {n}", "pickleball grandpa",
                 "grandpa gift", "retirement gift", "funny grandpa shirt", "fathers day gift",
                 "pickleball humor", "pickleball lover", "retired pickleball", "pickleballer"],
    },
}


def swap_name(base: dict, name: str) -> Image.Image:
    img = Image.open(D2 / base["src"] / "design.png").convert("RGBA")
    top, bottom = base["band"]
    # clear the old name line
    clear = Image.new("RGBA", (img.width, bottom - top), (0, 0, 0, 0))
    img.paste(clear, (0, top))
    # draw the new name with the same cap height, centred
    cap_target = base["base"] - base["cap"]
    probe = ImageFont.truetype(str(FONT), 1000)
    cap_1000 = -probe.getbbox("H", anchor="ls")[1]
    size = int(1000 * cap_target / cap_1000)
    word = name.upper()
    font = ImageFont.truetype(str(FONT), size)
    while ImageDraw.Draw(img).textlength(word, font=font) > 4100:
        size -= 20
        font = ImageFont.truetype(str(FONT), size)
    ImageDraw.Draw(img).text((img.width / 2, base["base"]), word, font=font, fill=base["color"], anchor="ms")
    return img


def build(kind: str, name: str) -> Path:
    base = BASES[kind]
    slug = f"pickleball-{name.lower()}-{base['slug_tail']}"
    out = D2 / slug
    out.mkdir(exist_ok=True)
    img = swap_name(base, name)
    img.save(out / "design.png", dpi=(300, 300), optimize=True)
    with open(out / "design.png", "rb") as f:
        (out / "mockup.png").write_bytes(make_mockup(f.read(), base["mockup_hex"]))

    src = json.loads((D2 / base["src"] / "listing.json").read_text())
    n, N, word = name.lower(), name, base["word"]  # noqa: F841
    listing = dict(src)
    listing["slug"] = slug
    listing["verdict_for_old_design"] = f"name version of {base['src']}"
    listing["title"] = base["title"].format(N=N)
    listing["tags"] = [t.format(n=n) for t in base["tags"]]
    disclosure = src["description"].split("\n\n")[-1]
    listing["description"] = base["description"].format(N=N, NU=N.upper()) + "\n\n" + disclosure
    listing["alt_text"] = src["alt_text"].replace(word, N)
    listing["products"] = [{"type": "tee-cc", "colors": base["cc_colors"]}]
    listing["title"] = "Comfort Colors " + listing["title"]
    problems = listing_problems(listing, PICKLEBALL.blocked_terms)
    if problems:
        raise SystemExit(f"{slug}: {problems}")
    (out / "listing.json").write_text(json.dumps(listing, indent=2) + "\n")
    return out


def main() -> None:
    if len(sys.argv) > 2:
        jobs = [(sys.argv[1], n) for n in sys.argv[2:]]
    else:
        jobs = [(k, n) for k, b in BASES.items() for n in b["names"]]
    for kind, name in jobs:
        print(build(kind, name).name)


if __name__ == "__main__":
    main()
