"""Make Pinterest pins for every live listing plus a bulk-upload CSV that schedules them.

Usage:  python scripts/marketing_pins.py [--start 2026-10-06] [--per-day 2]
        python scripts/marketing_pins.py --round designs-round-4 --csv pinterest_round4.csv

Writes marketing/pins/*.png (1000x1500) and marketing/pinterest_bulk.csv (or --csv).
Pins use the listing photos from photo_studio.py (photos/<slug>/) when they exist,
otherwise the plain mockup. --round limits the pins to one design folder.
Upload the CSV in Pinterest: Create > Create Pin > Bulk create Pins.
Images are served from this public repo, so push before uploading the CSV.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import sys
import textwrap
import urllib.parse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import printify_publish as pf  # noqa: E402

OUT = ROOT / "marketing"
RAW = "https://raw.githubusercontent.com/bosticommits/bagoflean/claude/etsy-design-agent-3ijscw/marketing/pins/"
FONTS = ROOT / "fonts"
NAVY, CREAM, CORAL, LIME = "#1D2B45", "#FBF3E4", "#E76F51", "#D9F03C"
W, H = 1000, 1500

BOARDS = {
    "christmas": "Pickleball Christmas Gifts",
    "thanksgiving": "Pickleball Christmas Gifts",
    "grand": "Pickleball Gifts for Grandparents",
    "mug": "Pickleball Mugs and Gifts",
    "sticker": "Pickleball Mugs and Gifts",
    "default": "Funny Pickleball Shirts",
}

# Two headlines per kind of design; each becomes its own pin.
HOOKS = {
    "christmas": ["Christmas gift idea for pickleball lovers", "The pickleball Christmas sweatshirt",
                  "Ugly Christmas sweater for pickleball players"],
    "thanksgiving": ["Thanksgiving shirt for pickleball players", "Gobble gobble, dink dink"],
    "grandma": ["Gift for the pickleball grandma", "For grandmas who rule the court",
                "Grandma's got game: gift from the grandkids"],
    "grandpa": ["Gift for the pickleball grandpa", "For grandpas who dink daily"],
    "knees": ["Funny gift for pickleball players over 50", "My knees say no. My heart says pickleball.",
              "Pickleball shirt for bad knees and big hearts"],
    "kitchen": ["Gift for the player who lives in the kitchen", "Kitchen staff only: a pickleball insider joke",
                "Funny pickleball shirt for dinkers"],
    "retirement": ["Retirement gift for pickleball players", "The only retirement plan they need",
                   "Retired and now serving full time"],
    "mug": ["Pickleball gift under $20", "For the morning pickleball crew"],
    "sticker": ["Pickleball stocking stuffer", "Sticker for your paddle bag"],
    "default": ["Funny pickleball shirt", "Gift idea for pickleball players"],
}


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def kind(slug: str, listing: dict, ptype: str) -> str:
    if ptype in ("mug", "sticker"):
        return ptype
    for key, words in (("grandma", ("grandma",)), ("grandpa", ("grandpa",)), ("knees", ("knees",)),
                       ("retirement", ("retire",))):
        if any(w in slug for w in words):
            return key
    occ = (listing.get("occasion") or listing.get("_concept_occasion", "")).lower()
    for key in ("christmas", "thanksgiving"):
        if occ.startswith(key) or key in slug or (key == "christmas" and "dink-the-halls" in slug):
            return key
    if "kitchen" in slug:
        return "kitchen"
    return "default"


def pin_images(slug: str, folder: Path) -> list[Path]:
    """Listing photos to put on pins (hero, close-up, gift card), else the mockup."""
    photos = ROOT / "photos" / slug
    picks = [photos / f for f in ("1-hero.jpg", "2-closeup.jpg", "4-gift.jpg") if (photos / f).exists()]
    return picks or [folder / "mockup.png"]


def fit_lines(draw, text, fnt_name, max_w, max_size, max_lines=2):
    for size in range(max_size, 30, -2):
        fnt = font(fnt_name, size)
        for width in range(10, 40):
            lines = textwrap.wrap(text, width=width)
            if len(lines) <= max_lines and all(draw.textlength(l, font=fnt) <= max_w for l in lines):
                return fnt, lines
    return font(fnt_name, 30), textwrap.wrap(text, 30)[:max_lines]


def make_pin(mockup: Path, hook: str, price_line: str, bg: str, out: Path) -> None:
    pin = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(pin)
    # headline
    fnt, lines = fit_lines(draw, hook.upper(), "Anton-Regular.ttf", W - 120, 110)
    y = 70
    for line in lines:
        draw.text((W / 2, y), line, font=fnt, fill=NAVY, anchor="ma")
        y += int(fnt.size * 1.08)
    # product photo in a rounded card
    top, bottom = y + 30, H - 230
    card = Image.open(mockup).convert("RGB")
    box_w, box_h = W - 100, bottom - top
    if mockup.name.startswith("1-hero"):
        # flat-lay photo: crop to fill the tall pin (the garment sits in the middle)
        scale = max(box_w / card.width, box_h / card.height)
        card = card.resize((int(card.width * scale), int(card.height * scale)), Image.LANCZOS)
        left, upper = (card.width - box_w) // 2, (card.height - box_h) // 2
        card = card.crop((left, upper, left + box_w, upper + box_h))
    else:
        scale = min(box_w / card.width, box_h / card.height)
        card = card.resize((int(card.width * scale), int(card.height * scale)), Image.LANCZOS)
    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *card.size), radius=36, fill=255)
    pin.paste(card, ((W - card.width) // 2, top + (bottom - top - card.height) // 2), mask)
    # footer
    draw.rounded_rectangle((60, H - 200, W - 60, H - 60), radius=40, fill=NAVY)
    draw.text((W / 2, H - 175), price_line, font=font("BebasNeue-Regular.ttf", 54), fill=LIME, anchor="ma")
    draw.text((W / 2, H - 115), "DINK DISTRICT  ·  SHOP ON ETSY", font=font("BebasNeue-Regular.ttf", 44), fill=CREAM, anchor="ma")
    out.parent.mkdir(parents=True, exist_ok=True)
    pin.save(out, optimize=True)


def short_title(text: str, limit: int = 100) -> str:
    if len(text) <= limit:
        return text
    return text[:limit].rsplit(" ", 1)[0].rstrip(",|- ")


def live_listings() -> list[dict]:
    """Every live Etsy listing with its design folder, listing data and URL."""
    state = pf.load_state()
    by_pid = {v["product_id"]: k for k, v in state.items()}
    items = []
    for p in pf.call("GET", f"/shops/{pf.SHOP_ID}/products.json?limit=50")["data"]:
        if not p.get("external"):
            continue
        slug = by_pid.get(p["id"]) or ("dink-the-halls" if "Dink the Halls" in p["title"] else None)
        if not slug:
            continue
        slug = state.get(slug, {}).get("design", slug)  # artwork swapped onto an older product
        folder = pf.design_dir(slug)
        listing = json.loads((folder / "listing.json").read_text())
        ptype = pf.BLUEPRINT_TYPES[p["blueprint_id"]]
        low = min(v["price"] for v in p["variants"] if v["is_enabled"]) / 100
        items.append({"slug": slug, "folder": folder, "listing": listing, "type": ptype,
                      "url": p["external"]["handle"], "from": low, "title": p["title"]})
    return items


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--start", default=(dt.date.today() + dt.timedelta(days=1)).isoformat())
    parser.add_argument("--per-day", type=int, default=2)
    parser.add_argument("--round", help="only designs in this folder, e.g. designs-round-4")
    parser.add_argument("--csv", default="pinterest_bulk.csv")
    args = parser.parse_args()

    rows = []
    items = [i for i in live_listings() if not args.round or i["folder"].parent.name == args.round]
    for item in sorted(items, key=lambda i: i["slug"]):
        listing, k = item["listing"], kind(item["slug"], item["listing"], item["type"])
        shipping = "  ·  FREE US SHIPPING" if pf.PRODUCT_TYPES[item["type"]]["free_shipping"] else ""
        price_line = f"FROM ${item['from']:.2f}{shipping}"
        bg = CREAM
        images = pin_images(item["slug"], item["folder"])
        for n, hook in enumerate(HOOKS.get(k, HOOKS["default"])):
            name = f"{item['slug']}-{n + 1}.png"
            make_pin(images[n % len(images)], hook, price_line, bg, OUT / "pins" / name)
            bg = "#EAF3F1" if bg == CREAM else CREAM
            board = BOARDS.get(k if k not in ("grandma", "grandpa") else "grand", BOARDS["default"])
            first = listing["description"].split("\n")[0].strip()
            desc = f"{first} Shop DinkDistrictArt on Etsy. " + " ".join(f"#{t.replace(' ', '')}" for t in listing["tags"][:5])
            link = item["url"] + "?" + urllib.parse.urlencode(
                {"utm_source": "pinterest", "utm_medium": "social", "utm_campaign": item["slug"]})
            rows.append({
                "Title": short_title(f"{hook} | {listing['title']}"),
                "Media URL": RAW + name,
                "Pinterest board": board,
                "Thumbnail": "",
                "Description": desc[:500],
                "Link": link,
                "Publish date": "",
                "Keywords": ", ".join(listing["tags"]),
            })

    # Interleave so the first pins of each design go out first, then schedule.
    per = {}
    for row in rows:
        per.setdefault(row["Link"], []).append(row)
    rows = [r for n in range(max(map(len, per.values()))) for group in per.values() if n < len(group) for r in [group[n]]]
    start = dt.date.fromisoformat(args.start)
    times = ["09:00", "19:00", "13:00", "16:00"][: args.per_day]
    for i, row in enumerate(rows):
        day = start + dt.timedelta(days=i // args.per_day)
        row["Publish date"] = f"{day.isoformat()} {times[i % args.per_day]}"
    OUT.mkdir(exist_ok=True)
    with open(OUT / args.csv, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"{len(rows)} pins, {rows[0]['Publish date']} to {rows[-1]['Publish date']}")
    print("Boards needed:", ", ".join(sorted({r['Pinterest board'] for r in rows})))


if __name__ == "__main__":
    main()
