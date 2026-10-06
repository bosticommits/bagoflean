"""Create and publish designs as Printify products on the Etsy store.

Usage:
  python scripts/printify_publish.py list                    # products in the store
  python scripts/printify_publish.py plan                    # what would be created
  python scripts/printify_publish.py create merry-dinkmas-christmas [...]
  python scripts/printify_publish.py create-all              # everything in the plan not created yet
  python scripts/printify_publish.py publish merry-dinkmas-christmas [...]
  python scripts/printify_publish.py delete <slug>           # remove an unpublished product

A design is a folder in designs-round-2/ (or samples/) with design.png and a
listing.json whose "products" list names the product type and colours. The
first product in that list is the one created.

Auth: the cloud environment's API credential for api.printify.com adds the
Authorization header automatically. Locally, set PRINTIFY_API_TOKEN instead.
Created product IDs are remembered in printify/state.json.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DESIGN_DIRS = [ROOT / "designs-round-4", ROOT / "designs-round-3", ROOT / "designs-round-2", ROOT / "samples"]
STATE = ROOT / "printify" / "state.json"
API = "https://api.printify.com/v1"
SHOP_ID = 29206471  # "My new store", connected to the DinkDistrictArt Etsy shop

# Personalised designs carry example names; they need a per-order workflow first.
SKIP = {
    "pickleball-family-christmas-2026",
    "partners-in-dink-couples",
    "pickleball-social-club-custom-town",
    "pickleball-player-name-number",
}

# ------------------------------------------------------------------ product types
APPAREL_CARE = ("Care: machine wash cold, tumble dry low, do not iron the design, do not dry clean.\n\n"
                "Made to order just for you - please allow 2-5 business days for production before shipping.")

PRODUCT_TYPES = {
    "crewneck": {
        "blueprint_id": 49, "print_provider_id": 99,  # Gildan 18000, same as Dink the Halls
        "prices": {"S": 3699, "M": 3699, "L": 3699, "XL": 3699, "2XL": 3999, "3XL": 4199, "4XL": 4499, "5XL": 4499},
        "colors": {},  # listing colour names are already Gildan names
        "fit": "crop",
        "free_shipping": True,
        "details": ("Product details:\n- Gildan 18000 unisex crewneck sweatshirt\n"
                    "- 50/50 cotton-polyester, medium-heavy fleece (8.0 oz/yd²), warm without being bulky\n"
                    "- Relaxed unisex fit - order your usual size; see the size chart in the photos\n\n" + APPAREL_CARE),
    },
    "tee": {
        "blueprint_id": 12, "print_provider_id": 99,  # Bella+Canvas 3001
        "prices": {"S": 2499, "M": 2499, "L": 2499, "XL": 2499, "2XL": 2699, "3XL": 3099, "4XL": 3299, "5XL": 3499},
        "colors": {"Forest Green": "Forest", "Charcoal": "Asphalt", "Light Pink": "Soft Pink", "Sand": "Sand Dune"},
        "fit": "crop",
        "free_shipping": True,
        "details": ("Product details:\n- Bella+Canvas 3001 unisex jersey t-shirt\n"
                    "- Soft, lightweight 100% Airlume combed and ring-spun cotton (heather colours are blends)\n"
                    "- Retail fit, side-seamed - see the size chart in the photos\n\n" + APPAREL_CARE),
    },
    "tee-cc": {
        "blueprint_id": 706, "print_provider_id": 99,  # Comfort Colors 1717 garment-dyed
        "prices": {"S": 2699, "M": 2699, "L": 2699, "XL": 2699, "2XL": 2899, "3XL": 3199, "4XL": 3399},
        "colors": {"Forest Green": "Blue Spruce", "Charcoal": "Pepper", "Light Pink": "Blossom", "Natural": "Ivory",
                   "White": "Ivory", "Sand": "Ivory", "Light Blue": "Chalky Mint", "Military Green": "Blue Spruce"},
        "fit": "crop",
        "free_shipping": True,
        "title_prefix": "Comfort Colors ",
        "details": ("Product details:\n- Comfort Colors 1717 garment-dyed heavyweight t-shirt\n"
                    "- 100% ring-spun cotton, soft lived-in feel and vintage colour\n"
                    "- Relaxed unisex fit - see the size chart in the photos\n\n" + APPAREL_CARE),
    },
    "mug": {
        "blueprint_id": 478, "print_provider_id": 99,
        "variant_prices": {"11oz": 1699},
        "fit": "full",
        "free_shipping": False,
        "details": ("Product details:\n- 11oz white ceramic mug, printed on both sides\n"
                    "- Dishwasher and microwave safe\n\n"
                    "Made to order just for you - please allow 2-5 business days for production before shipping."),
    },
    "mug-accent": {
        "blueprint_id": 635, "print_provider_id": 99,  # 11oz accent mug (coloured handle and inside)
        "variant_prices": {"11oz / Light Green": 1899, "11oz / Black": 1899},
        "fit": "full",
        "free_shipping": False,
        "details": ("Product details:\n- 11oz white ceramic mug with a coloured handle and inside (lime green or black)\n"
                    "- Printed on both sides\n- Dishwasher and microwave safe\n\n"
                    "Made to order just for you - please allow 2-5 business days for production before shipping."),
    },
    "sticker": {
        "blueprint_id": 400, "print_provider_id": 99,  # Kiss-cut stickers
        "variant_prices": {'3" × 3" / White': 499, '4" × 4" / White': 599},
        "fit": "sticker",
        "free_shipping": False,
        "details": ("Product details:\n- Kiss-cut vinyl sticker with a white border\n"
                    "- Choose 3\" or 4\"\n- Great for paddle bags, water bottles, coolers and laptops\n\n"
                    "Made to order just for you - please allow 2-5 business days for production before shipping."),
    },
}

# Comfort Colors versions of designs that are already live as Bella+Canvas tees.
# Key: "<slug>@tee-cc"; value: Comfort Colors colour names (main colour first).
EXTRA_PRODUCTS = {
    "doctors-orders-pickleball-rx@tee-cc": ["Ivory", "Butter", "Chalky Mint"],
    "just-one-more-game-clock@tee-cc": ["Black", "Pepper", "Navy"],
    "mine-yours-doubles-oops@tee-cc": ["Ivory", "Butter", "Chalky Mint"],
    "pickleball-2027-resolutions@tee-cc": ["Black", "Pepper", "Navy"],
    "pickleball-grandma-sweet-sneaky@tee-cc": ["Blossom", "Ivory", "Chalky Mint", "Butter"],
    "pickleball-grandpa-dinking-since-retirement@tee-cc": ["Blue Spruce", "Pepper", "Navy", "Black"],
    "retirement-schedule-pickleball@tee-cc": ["Navy", "Pepper", "Black"],
}

CHRISTMAS_ATTRS = {  # Etsy attributes copied from the Dink the Halls sweatshirt (Holiday: Christmas)
    "etsy_property:46803063659": "35",
    "etsy_property:325502673988": "2393",
    "etsy_property:332797777099": "461",
}


# ------------------------------------------------------------------ API
def call(method: str, path: str, body: dict | None = None) -> dict:
    headers = {"User-Agent": "DinkDistrictArt-uploader", "Content-Type": "application/json"}
    if os.environ.get("PRINTIFY_API_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['PRINTIFY_API_TOKEN']}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{API}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            text = resp.read().decode()
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"Printify {method} {path} failed ({exc.code}): {exc.read().decode()[:2000]}")
    return json.loads(text) if text else {}


def load_state() -> dict:
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state: dict) -> None:
    STATE.parent.mkdir(exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2) + "\n")


# ------------------------------------------------------------------ designs
def design_dir(slug: str) -> Path:
    slug = slug.split("@")[0]
    for base in DESIGN_DIRS:
        if (base / slug / "listing.json").exists():
            return base / slug
    raise SystemExit(f"No design folder with listing.json for {slug}")


def all_slugs() -> list[str]:
    folders = [p.name for base in DESIGN_DIRS if base.name.startswith("designs-round") and base.exists()
               for p in base.iterdir() if (p / "listing.json").exists() and p.name not in SKIP]
    return sorted(folders) + list(EXTRA_PRODUCTS)


def load_listing(slug: str) -> tuple[dict, dict]:
    """The listing data and the product (type + colours) to create for this slug."""
    listing = json.loads((design_dir(slug) / "listing.json").read_text())
    if "@" in slug:
        ptype = slug.split("@")[1]
        product = {"type": ptype, "colors": EXTRA_PRODUCTS[slug]}
        prefix = PRODUCT_TYPES[ptype].get("title_prefix", "")
        title = listing["title"]
        if prefix and not title.startswith(prefix):
            title = prefix + title
            if len(title) > 140:
                title = title[:140].rsplit(",", 1)[0]
        tags = list(listing["tags"])
        if ptype == "tee-cc" and "comfort colors tee" not in tags:
            tags[-1] = "comfort colors tee"
        listing = {**listing, "title": title, "tags": tags}
    else:
        product = primary_product(listing)
    return listing, product


def primary_product(listing: dict) -> dict:
    for product in listing.get("products", []):
        if product["type"] in PRODUCT_TYPES:
            return product
    raise SystemExit(f"{listing.get('slug')}: no supported product type in {listing.get('products')}")


def artwork(slug: str, fit: str) -> tuple[bytes, float]:
    """PNG to upload (trimmed to the artwork unless 'full'), plus its height/width ratio."""
    img = Image.open(design_dir(slug) / "design.png").convert("RGBA")
    if fit != "full":
        pad = 20
        left, top, right, bottom = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        img = img.crop((max(left - pad, 0), max(top - pad, 0), min(right + pad, img.width), min(bottom + pad, img.height)))
    buf = io.BytesIO()
    img.save(buf, format="PNG", dpi=(300, 300), optimize=True)
    return buf.getvalue(), img.height / img.width


def placement(fit: str, art_ratio: float, ph_w: int, ph_h: int) -> dict:
    if fit == "full":
        return {"x": 0.5, "y": 0.5, "scale": 1, "angle": 0}
    if fit == "sticker":
        scale = min(0.96, 0.96 * ph_h / (ph_w * art_ratio))
        return {"x": 0.5, "y": 0.5, "scale": round(scale, 4), "angle": 0}
    # apparel: centred, near the top, ~93% of the print width
    scale = 0.93
    height_frac = scale * ph_w * art_ratio / ph_h
    if height_frac > 0.94:
        scale *= 0.94 / height_frac
        height_frac = 0.94
    return {"x": 0.5, "y": round(0.03 + height_frac / 2, 4), "scale": round(scale, 4), "angle": 0}


def description(listing: dict, details: str) -> str:
    text = listing["description"]
    paragraphs = text.split("\n\n")
    disclosure = paragraphs[-1]
    head = text.split("Product notes:")[0].rstrip() if "Product notes:" in text else "\n\n".join(paragraphs[:-1])
    return f"{head}\n\n{details}\n\n{disclosure}"


def choose_variants(ptype: dict, product: dict, catalog: list[dict]) -> list[dict]:
    if "variant_prices" in ptype:
        chosen = [v for v in catalog if v["title"] in ptype["variant_prices"]]
        return [{"id": v["id"], "price": ptype["variant_prices"][v["title"]], "is_enabled": True,
                 "is_default": i == 0, "_catalog": v} for i, v in enumerate(chosen)]
    colors = [ptype["colors"].get(c, c) for c in product["colors"]]
    offered = {v["options"]["color"] for v in catalog}
    colors = [c for c in colors if c in offered]
    if not colors:
        raise SystemExit(f"None of {product['colors']} is offered for {product['type']}")
    prices = ptype["prices"]
    chosen = [v for v in catalog if v["options"]["color"] in colors and v["options"]["size"] in prices]
    return [{"id": v["id"], "price": prices[v["options"]["size"]], "is_enabled": True,
             "is_default": v["options"]["color"] == colors[0] and v["options"]["size"] == "M",
             "_catalog": v} for v in chosen]


def build_product(slug: str, image_id: str | None = None) -> tuple[dict, dict]:
    """The Printify product payload and a short summary of it."""
    listing, product = load_listing(slug)
    ptype = PRODUCT_TYPES[product["type"]]
    catalog = call("GET", f"/catalog/blueprints/{ptype['blueprint_id']}/print_providers/"
                          f"{ptype['print_provider_id']}/variants.json")["variants"]
    variants = choose_variants(ptype, product, catalog)
    front = next(p for p in variants[0]["_catalog"]["placeholders"] if p["position"] == "front")
    _, ratio = artwork(slug, ptype["fit"])
    image = {"id": image_id or "PENDING", **placement(ptype["fit"], ratio, front["width"], front["height"])}
    attrs = CHRISTMAS_ATTRS if product["type"] == "crewneck" and "christmas" in listing.get("occasion", "").lower() else {}
    payload = {
        "title": listing["title"],
        "description": description(listing, ptype["details"]),
        "tags": listing["tags"],
        "blueprint_id": ptype["blueprint_id"],
        "print_provider_id": ptype["print_provider_id"],
        "variants": [{k: v for k, v in var.items() if k != "_catalog"} for var in variants],
        "print_areas": [{"variant_ids": [v["id"] for v in variants],
                         "placeholders": [{"position": "front", "images": [image]}]}],
        "sales_channel_properties": {"free_shipping": ptype["free_shipping"], "custom_attributes": attrs},
    }
    colours = sorted({v["_catalog"]["options"].get("color", v["_catalog"]["title"]) for v in variants})
    summary = {"type": product["type"], "variants": len(variants), "colours": colours,
               "prices": sorted({v["price"] / 100 for v in variants}), "placement": image}
    return payload, summary


# ------------------------------------------------------------------ commands
def cmd_list(_args) -> None:
    for p in call("GET", f"/shops/{SHOP_ID}/products.json?limit=50")["data"]:
        live = "on Etsy" if p.get("external") else "not published"
        print(f"{p['id']}  {live:14}  {p['title'][:80]}")


def cmd_plan(_args) -> None:
    state = load_state()
    for slug in all_slugs():
        _, summary = build_product(slug)
        done = "created" if state.get(slug, {}).get("product_id") else "to create"
        print(f"{slug:44} {done:10} {summary['type']:9} {summary['variants']:3} variants  "
              f"{', '.join(summary['colours'])}  ${'/'.join(f'{p:.2f}' for p in summary['prices'])}")


def cmd_create(args) -> None:
    state = load_state()
    for slug in args.slugs:
        if state.get(slug, {}).get("product_id"):
            print(f"{slug}: already created ({state[slug]['product_id']}), skipping")
            continue
        _, product = load_listing(slug)
        fit = PRODUCT_TYPES[product["type"]]["fit"]
        art, _ = artwork(slug, fit)
        upload = call("POST", "/uploads/images.json", {
            "file_name": f"{slug}.png", "contents": base64.b64encode(art).decode()})
        payload, summary = build_product(slug, upload["id"])
        product = call("POST", f"/shops/{SHOP_ID}/products.json", payload)
        if PRODUCT_TYPES[summary["type"]]["free_shipping"]:
            call("PUT", f"/shops/{SHOP_ID}/products/{product['id']}.json", {"is_economy_shipping_enabled": True})
        state[slug] = {"product_id": product["id"], "image_id": upload["id"], "type": summary["type"], "published": False}
        save_state(state)
        print(f"{slug}: created {summary['type']} {product['id']} (not published)")


def cmd_publish(args) -> None:
    state = load_state()
    for slug in args.slugs:
        pid = state.get(slug, {}).get("product_id")
        if not pid:
            raise SystemExit(f"{slug}: create it first")
        call("POST", f"/shops/{SHOP_ID}/products/{pid}/publish.json", {
            "title": True, "description": True, "images": True, "variants": True,
            "tags": True, "keyFeatures": True, "shipping_template": True})
        state[slug]["published"] = True
        save_state(state)
        print(f"{slug}: sent to Etsy")


BLUEPRINT_TYPES = {pt["blueprint_id"]: name for name, pt in PRODUCT_TYPES.items()}


def new_price(ptype: dict, title: str) -> int | None:
    if "variant_prices" in ptype:
        return ptype["variant_prices"].get(title)
    parts = [x.strip() for x in title.split("/")]
    return next((ptype["prices"][x] for x in parts if x in ptype["prices"]), None)


def cmd_reprice(_args) -> None:
    """Apply PRODUCT_TYPES prices to every product in the store; re-sync live ones to Etsy."""
    for p in call("GET", f"/shops/{SHOP_ID}/products.json?limit=50")["data"]:
        name = BLUEPRINT_TYPES.get(p["blueprint_id"])
        if not name:
            print(f"skip (unknown product type): {p['title'][:60]}")
            continue
        ptype = PRODUCT_TYPES[name]
        variants, changed = [], 0
        for v in p["variants"]:
            price = new_price(ptype, v["title"]) if v["is_enabled"] else None
            if price and price != v["price"]:
                changed += 1
            variants.append({"id": v["id"], "price": price or v["price"], "is_enabled": v["is_enabled"]})
        if not changed:
            print(f"unchanged: {p['title'][:60]}")
            continue
        call("PUT", f"/shops/{SHOP_ID}/products/{p['id']}.json", {"variants": variants})
        if p.get("external"):
            call("POST", f"/shops/{SHOP_ID}/products/{p['id']}/publish.json", {
                "title": False, "description": False, "images": False, "variants": True,
                "tags": False, "keyFeatures": False, "shipping_template": False})
        print(f"repriced {changed} variants{' and re-synced to Etsy' if p.get('external') else ''}: {p['title'][:60]}")


def cmd_delete(args) -> None:
    state = load_state()
    for slug in args.slugs:
        entry = state.get(slug)
        if not entry:
            raise SystemExit(f"{slug}: not in state")
        if entry.get("published"):
            raise SystemExit(f"{slug}: already published; unpublish it in Etsy/Printify by hand")
        call("DELETE", f"/shops/{SHOP_ID}/products/{entry['product_id']}.json")
        del state[slug]
        save_state(state)
        print(f"{slug}: deleted")


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish designs to Printify / Etsy")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list").set_defaults(func=cmd_list)
    sub.add_parser("plan").set_defaults(func=cmd_plan)
    sub.add_parser("reprice").set_defaults(func=cmd_reprice)
    for name, func in [("create", cmd_create), ("publish", cmd_publish), ("delete", cmd_delete)]:
        p = sub.add_parser(name)
        p.add_argument("slugs", nargs="+")
        p.set_defaults(func=func)
    sub.add_parser("create-all").set_defaults(
        func=lambda a: cmd_create(argparse.Namespace(slugs=[s for s in all_slugs() if s not in load_state()])))
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
