"""Create and publish the samples/ designs as Printify products on the Etsy store.

Usage:
  python scripts/printify_publish.py list                 # products already in the store
  python scripts/printify_publish.py create merry-dinkmas # create (not published) for review
  python scripts/printify_publish.py publish merry-dinkmas
  python scripts/printify_publish.py create-all           # every design in PLAN not created yet

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
import sys
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SAMPLES = ROOT / "samples"
STATE = ROOT / "printify" / "state.json"
API = "https://api.printify.com/v1"
SHOP_ID = 29206471  # "My new store", connected to the DinkDistrictArt Etsy shop

# ------------------------------------------------------------------ products
SIZE_PRICES = {
    "crewneck": {"S": 4499, "M": 4499, "L": 4499, "XL": 4499, "2XL": 4799, "3XL": 4999, "4XL": 5299, "5XL": 5299},
}

CREWNECK_DETAILS = """Product details:
- Gildan 18000 unisex crewneck sweatshirt
- 50/50 cotton-polyester, medium-heavy fleece (8.0 oz/yd²), warm without being bulky
- Classic fit with ribbed knit collar and double-needle stitching
- Unisex sizing - see the size chart in the photos

Care: machine wash cold, tumble dry low, do not iron the design, do not dry clean.

Made to order just for you - please allow 2-5 business days for production before shipping."""

PRODUCT_TYPES = {
    "crewneck": {
        "blueprint_id": 49,          # Gildan 18000, same as the Dink the Halls listing
        "print_provider_id": 99,
        "details": CREWNECK_DETAILS,
    },
}

# design slug -> product type, colours (first = main mockup colour), Etsy attributes
CHRISTMAS_ATTRS = {  # copied from the Dink the Halls listing (Holiday: Christmas etc.)
    "etsy_property:46803063659": "35",
    "etsy_property:325502673988": "2393",
    "etsy_property:332797777099": "461",
}
PLAN = {
    "merry-dinkmas": {"type": "crewneck", "colors": ["Maroon", "Black", "Navy", "Forest Green"], "attrs": CHRISTMAS_ATTRS},
    "santas-favorite-dinker": {"type": "crewneck", "colors": ["Dark Heather", "Black", "Navy"], "attrs": CHRISTMAS_ATTRS},
}


# ------------------------------------------------------------------ API
def call(method: str, path: str, body: dict | None = None) -> dict:
    headers = {"User-Agent": "DinkDistrictArt-uploader", "Content-Type": "application/json"}
    if os.environ.get("PRINTIFY_API_TOKEN"):
        headers["Authorization"] = f"Bearer {os.environ['PRINTIFY_API_TOKEN']}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{API}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            text = resp.read().decode()
    except urllib.error.HTTPError as exc:
        sys.exit(f"Printify {method} {path} failed ({exc.code}): {exc.read().decode()[:2000]}")
    return json.loads(text) if text else {}


def load_state() -> dict:
    return json.loads(STATE.read_text()) if STATE.exists() else {}


def save_state(state: dict) -> None:
    STATE.parent.mkdir(exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2) + "\n")


# ------------------------------------------------------------------ build
def cropped_art(slug: str) -> tuple[bytes, float]:
    """The design trimmed to its artwork, plus its height/width ratio."""
    img = Image.open(SAMPLES / slug / "design.png").convert("RGBA")
    pad = 20
    left, top, right, bottom = img.getchannel("A").getbbox()
    img = img.crop((max(left - pad, 0), max(top - pad, 0), min(right + pad, img.width), min(bottom + pad, img.height)))
    buf = io.BytesIO()
    img.save(buf, format="PNG", dpi=(300, 300), optimize=True)
    return buf.getvalue(), img.height / img.width


def placement(art_ratio: float, ph_w: int, ph_h: int) -> dict:
    """Centre horizontally, sit near the top, fill ~93% of the width."""
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


def build_product(slug: str, image_id: str) -> dict:
    plan = PLAN[slug]
    ptype = PRODUCT_TYPES[plan["type"]]
    listing = json.loads((SAMPLES / slug / "listing.json").read_text())
    catalog = call("GET", f"/catalog/blueprints/{ptype['blueprint_id']}/print_providers/{ptype['print_provider_id']}/variants.json")
    prices = SIZE_PRICES[plan["type"]]
    chosen = [v for v in catalog["variants"] if v["options"]["color"] in plan["colors"] and v["options"]["size"] in prices]
    missing = set(plan["colors"]) - {v["options"]["color"] for v in chosen}
    if missing:
        sys.exit(f"{slug}: colours not offered by this provider: {sorted(missing)}")
    main = plan["colors"][0]
    variants = [{
        "id": v["id"],
        "price": prices[v["options"]["size"]],
        "is_enabled": True,
        "is_default": v["options"]["color"] == main and v["options"]["size"] == "M",
    } for v in chosen]
    front = next(p for p in chosen[0]["placeholders"] if p["position"] == "front")
    _, ratio = cropped_art(slug)
    placeholders = [{"position": "front", "images": [{"id": image_id, **placement(ratio, front["width"], front["height"])}]}]
    return {
        "title": listing["title"],
        "description": description(listing, ptype["details"]),
        "tags": listing["tags"],
        "blueprint_id": ptype["blueprint_id"],
        "print_provider_id": ptype["print_provider_id"],
        "variants": variants,
        "print_areas": [{"variant_ids": [v["id"] for v in chosen], "placeholders": placeholders}],
        "sales_channel_properties": {"free_shipping": True, "custom_attributes": plan.get("attrs", {})},
    }


# ------------------------------------------------------------------ commands
def cmd_list(_args) -> None:
    products = call("GET", f"/shops/{SHOP_ID}/products.json?limit=50")["data"]
    for p in products:
        live = "on Etsy" if p.get("external") else "not published"
        print(f"{p['id']}  {live:14}  {p['title'][:80]}")


def cmd_create(args) -> None:
    state = load_state()
    for slug in args.slugs:
        if slug not in PLAN:
            sys.exit(f"{slug} is not in PLAN (add its product type and colours first)")
        if state.get(slug, {}).get("product_id"):
            print(f"{slug}: already created ({state[slug]['product_id']}), skipping")
            continue
        art, _ = cropped_art(slug)
        upload = call("POST", "/uploads/images.json", {
            "file_name": f"{slug}.png", "contents": base64.b64encode(art).decode()})
        product = call("POST", f"/shops/{SHOP_ID}/products.json", build_product(slug, upload["id"]))
        # free Economy shipping, as on the first hand-made listing
        call("PUT", f"/shops/{SHOP_ID}/products/{product['id']}.json", {"is_economy_shipping_enabled": True})
        state[slug] = {"product_id": product["id"], "image_id": upload["id"], "published": False}
        save_state(state)
        print(f"{slug}: created product {product['id']} (not published yet)")


def cmd_publish(args) -> None:
    state = load_state()
    for slug in args.slugs:
        pid = state.get(slug, {}).get("product_id")
        if not pid:
            sys.exit(f"{slug}: create it first")
        call("POST", f"/shops/{SHOP_ID}/products/{pid}/publish.json", {
            "title": True, "description": True, "images": True, "variants": True,
            "tags": True, "keyFeatures": True, "shipping_template": True})
        state[slug]["published"] = True
        save_state(state)
        print(f"{slug}: sent to Etsy")


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish designs to Printify / Etsy")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list").set_defaults(func=cmd_list)
    for name, func in [("create", cmd_create), ("publish", cmd_publish)]:
        p = sub.add_parser(name)
        p.add_argument("slugs", nargs="+")
        p.set_defaults(func=func)
    p = sub.add_parser("create-all")
    p.set_defaults(func=lambda a: cmd_create(argparse.Namespace(slugs=[s for s in PLAN if s not in load_state()])))
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
