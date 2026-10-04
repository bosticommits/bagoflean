#!/usr/bin/env python3
"""Roblox Limited trade advisor: search items, evaluate trades, scan flip candidates.

Advice only. This module reads the public Rolimons item API and a local
portfolio.json. It never logs in to Roblox, never touches cookies or passwords,
and never sends, accepts or automates trades or purchases.

Every public function returns plain data (dicts/lists) so it can be used from
the CLI below or exposed as a tool to the chat agent in agent.py.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

import requests

ROLIMONS_ITEMS_URL = "https://api.rolimons.com/items/v2/itemdetails"
CACHE_TTL_SECONDS = 15 * 60
MARKETPLACE_FEE = 0.30  # Roblox keeps 30% of every resale

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE_FILE = os.environ.get("ROLIMONS_CACHE_FILE", os.path.join(HERE, ".rolimons_cache.json"))
PORTFOLIO_FILE = os.environ.get("PORTFOLIO_FILE", os.path.join(HERE, "portfolio.json"))
# Point this at a JSON file shaped like the Rolimons response to run fully offline.
MOCK_FILE = os.environ.get("ROLIMONS_MOCK_FILE")

DEMAND_LABELS = {-1: "unassigned", 0: "terrible", 1: "low", 2: "normal", 3: "high", 4: "amazing"}
TREND_LABELS = {-1: "unassigned", 0: "lowering", 1: "unstable", 2: "stable", 3: "raising", 4: "fluctuating"}

# Ratio of what you get to what you give, by value. Bands are deliberately tight:
# small edges disappear quickly once demand, trend and RAP inflation are considered.
GOOD_TRADE_RATIO = 1.10
FAIR_TRADE_RATIO = 0.95
# RAP this far above value usually means it was pumped by a few high sales.
INFLATED_RAP_RATIO = 1.25


class RolimonsError(RuntimeError):
    """The Rolimons API could not be reached or returned something unusable."""


_memory_cache = {"fetched_at": 0.0, "items": None}


# ---------------------------------------------------------------- data access

def _parse_items(payload):
    if not isinstance(payload, dict) or not payload.get("success") or "items" not in payload:
        raise RolimonsError("Rolimons returned an unexpected response (no 'items' field).")
    items = {}
    for item_id, row in payload["items"].items():
        # [name, acronym, rap, value, default_value, demand, trend, projected, hyped, rare]
        name, acronym, rap, value, default_value, demand, trend, projected, hyped, rare = row[:10]
        items[str(item_id)] = {
            "id": str(item_id),
            "name": name,
            "acronym": acronym or "",
            "rap": rap,
            # Rolimons uses -1 for "no value assigned"; keep that explicit as None.
            "value": value if value is not None and value > 0 else None,
            "demand": DEMAND_LABELS.get(demand, "unassigned"),
            "demand_level": demand,
            "trend": TREND_LABELS.get(trend, "unassigned"),
            "projected": projected == 1,
            "hyped": hyped == 1,
            "rare": rare == 1,
        }
    return items


def _read_disk_cache():
    try:
        with open(CACHE_FILE) as f:
            cached = json.load(f)
        return cached["fetched_at"], cached["payload"]
    except (OSError, ValueError, KeyError):
        return None, None


def _write_disk_cache(fetched_at, payload):
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump({"fetched_at": fetched_at, "payload": payload}, f)
    except OSError:
        pass  # the cache is an optimisation, not a requirement


def fetch_items(force=False):
    """Return {item_id: item} from Rolimons, cached for 15 minutes (memory + disk)."""
    now = time.time()
    if MOCK_FILE:
        with open(MOCK_FILE) as f:
            return _parse_items(json.load(f))

    if not force and _memory_cache["items"] and now - _memory_cache["fetched_at"] < CACHE_TTL_SECONDS:
        return _memory_cache["items"]

    fetched_at, payload = _read_disk_cache()
    if not force and payload and now - fetched_at < CACHE_TTL_SECONDS:
        items = _parse_items(payload)
        _memory_cache.update(fetched_at=fetched_at, items=items)
        return items

    try:
        resp = requests.get(ROLIMONS_ITEMS_URL, timeout=15)
        resp.raise_for_status()
        payload = resp.json()
    except requests.exceptions.Timeout:
        raise RolimonsError("Rolimons API timed out. Try again in a minute.")
    except requests.exceptions.ConnectionError:
        raise RolimonsError("Could not connect to the Rolimons API. Check your internet connection or try later.")
    except requests.exceptions.HTTPError as e:
        code = e.response.status_code if e.response is not None else "?"
        hint = " (rate limited, wait a few minutes)" if code == 429 else ""
        raise RolimonsError(f"Rolimons API returned HTTP {code}{hint}.")
    except ValueError:
        raise RolimonsError("Rolimons API returned invalid JSON.")

    items = _parse_items(payload)
    _write_disk_cache(now, payload)
    _memory_cache.update(fetched_at=now, items=items)
    return items


def data_age_minutes():
    """Minutes since the item data was fetched, or None if not fetched yet."""
    if MOCK_FILE:
        return 0
    fetched_at = _memory_cache["fetched_at"] or (_read_disk_cache()[0] or 0)
    return round((time.time() - fetched_at) / 60, 1) if fetched_at else None


# ------------------------------------------------------------------- helpers

def effective_value(item):
    """Value if Rolimons assigned one, otherwise RAP. Callers should flag the RAP case."""
    return item["value"] if item["value"] is not None else item["rap"]


def item_flags(item):
    """Risk flags the advisor must always surface."""
    flags = []
    if item["value"] is None:
        flags.append("unvalued (no Rolimons value, using RAP)")
    if item["projected"]:
        flags.append("projected (RAP artificially pushed, do not trust it)")
    if item["demand_level"] is not None and 0 <= item["demand_level"] <= 1:
        flags.append(f"{item['demand']} demand (hard to resell)")
    elif item["demand_level"] == -1:
        flags.append("demand unassigned")
    if item["trend"] == "lowering":
        flags.append("falling trend")
    elif item["trend"] in ("unstable", "fluctuating"):
        flags.append(f"{item['trend']} trend")
    if item["value"] is not None and item["rap"] > item["value"] * INFLATED_RAP_RATIO:
        flags.append(f"inflated RAP ({item['rap']:,} vs value {item['value']:,})")
    if item["hyped"]:
        flags.append("hyped (price may drop when hype fades)")
    return flags


def _summary(item):
    return {
        "id": item["id"],
        "name": item["name"],
        "acronym": item["acronym"],
        "rap": item["rap"],
        "value": item["value"],
        "demand": item["demand"],
        "trend": item["trend"],
        "projected": item["projected"],
        "rare": item["rare"],
        "flags": item_flags(item),
    }


def resolve_item(query, items=None):
    """Find one item by id, exact name, exact acronym, or unique substring.

    Returns (item, candidates). item is None when nothing or more than one item matched;
    candidates then lists the closest matches so the caller can ask which one.
    """
    items = items if items is not None else fetch_items()
    q = str(query).strip()
    if q in items:
        return items[q], []
    ql = q.lower()
    for item in items.values():
        if item["name"].lower() == ql:
            return item, []
    acronym_hits = [i for i in items.values() if i["acronym"] and i["acronym"].lower() == ql]
    if len(acronym_hits) == 1:
        return acronym_hits[0], []
    hits = [i for i in items.values() if ql in i["name"].lower()]
    if len(hits) == 1:
        return hits[0], []
    hits = acronym_hits + hits
    hits.sort(key=lambda i: -effective_value(i))
    return None, [i["name"] for i in hits[:5]]


# ------------------------------------------------------------- core commands

def search_items(query, limit=10):
    """Items whose name or acronym contains query, most valuable first."""
    items = fetch_items()
    ql = str(query).strip().lower()
    if not ql:
        return {"query": query, "results": [], "note": "Empty search."}
    hits = [i for i in items.values() if ql in i["name"].lower() or ql == i["acronym"].lower()]
    hits.sort(key=lambda i: -effective_value(i))
    return {
        "query": query,
        "total_matches": len(hits),
        "results": [_summary(i) for i in hits[:limit]],
        "data_age_minutes": data_age_minutes(),
    }


def evaluate_trade(give, get):
    """Compare the items you give against the items you get and rate the trade."""
    items = fetch_items()
    unresolved = []
    sides = {}
    for side, names in (("give", give), ("get", get)):
        resolved = []
        for name in names:
            item, candidates = resolve_item(name, items)
            if item is None:
                unresolved.append({"side": side, "query": name, "did_you_mean": candidates})
            else:
                resolved.append(item)
        sides[side] = resolved

    if unresolved:
        return {
            "verdict": None,
            "error": "Some items could not be identified. Ask which item was meant.",
            "unresolved": unresolved,
        }
    if not sides["give"] or not sides["get"]:
        return {"verdict": None, "error": "Both sides of the trade need at least one item."}

    def side_report(side_items):
        return {
            "items": [_summary(i) for i in side_items],
            "total_value": sum(effective_value(i) for i in side_items),
            "total_rap": sum(i["rap"] for i in side_items),
        }

    give_r, get_r = side_report(sides["give"]), side_report(sides["get"])
    ratio = get_r["total_value"] / give_r["total_value"] if give_r["total_value"] else None

    risks = []
    for i in sides["get"]:
        risks += [f"You receive {i['name']}: {f}" for f in item_flags(i)]
    for i in sides["give"]:
        if i["demand_level"] is not None and i["demand_level"] >= 3 and i["trend"] in ("stable", "raising"):
            risks.append(f"You give away {i['name']}: {i['demand']} demand, {i['trend']} trend (a strong item to let go)")
    if len(sides["get"]) > len(sides["give"]):
        risks.append("Downgrade: you receive more, smaller items. They are usually harder to resell one by one.")
    elif len(sides["get"]) < len(sides["give"]):
        risks.append("Upgrade: you consolidate into fewer items. Fine if demand is good, but you pay a premium for that.")

    if ratio is None:
        verdict = None
    elif ratio >= GOOD_TRADE_RATIO:
        verdict = "good"
    elif ratio >= FAIR_TRADE_RATIO:
        verdict = "fair"
    else:
        verdict = "bad"

    # A trade that only looks good because of a projected or unvalued item is not good.
    shaky_get = [i for i in sides["get"] if i["projected"] or i["value"] is None or (i["demand_level"] or 0) <= 1]
    if verdict == "good" and shaky_get:
        verdict = "fair"
        risks.append("Verdict downgraded from good to fair: part of what you receive is projected, unvalued or low demand.")

    return {
        "verdict": verdict,
        "value_ratio_get_over_give": round(ratio, 3) if ratio else None,
        "value_difference": get_r["total_value"] - give_r["total_value"],
        "give": give_r,
        "get": get_r,
        "risks": risks,
        "method": "Compares Rolimons value (RAP when unvalued). good >= +10%, fair -5%..+10%, bad below -5%.",
        "data_age_minutes": data_age_minutes(),
    }


def scan_candidates(budget, min_edge=0.10, min_demand=2, limit=15):
    """Items affordable at RAP whose value exceeds RAP by at least min_edge.

    RAP is a proxy for the price you would pay; the real cheapest listing may differ.
    net_after_fee assumes you resell at value and Roblox keeps 30%.
    """
    items = fetch_items()
    out = []
    for i in items.values():
        if i["value"] is None or i["projected"] or i["rap"] <= 0 or i["rap"] > budget:
            continue
        if i["demand_level"] is None or i["demand_level"] < min_demand:
            continue
        if i["trend"] == "lowering":
            continue
        edge = (i["value"] - i["rap"]) / i["rap"]
        if edge < min_edge:
            continue
        resale_proceeds = int(i["value"] * (1 - MARKETPLACE_FEE))
        out.append({
            **_summary(i),
            "edge": round(edge, 3),
            "resale_proceeds_after_fee": resale_proceeds,
            "net_after_fee": resale_proceeds - i["rap"],
            # Price you would need to sell at just to get your money back.
            "break_even_sell_price": int(i["rap"] / (1 - MARKETPLACE_FEE)) + 1,
        })
    out.sort(key=lambda c: (-c["edge"], -c["net_after_fee"]))
    return {
        "budget": budget,
        "min_edge": min_edge,
        "min_demand": DEMAND_LABELS.get(min_demand, min_demand),
        "count": len(out),
        "candidates": out[:limit],
        "notes": [
            "Projected, unvalued and falling-trend items are excluded.",
            "RAP is used as the buy price; check the actual cheapest listing before buying.",
            "Marketplace resale loses 30% to Roblox fees; trading item-for-item has no fee.",
        ],
        "data_age_minutes": data_age_minutes(),
    }


# ----------------------------------------------------------------- portfolio

def _load_portfolio():
    try:
        with open(PORTFOLIO_FILE) as f:
            data = json.load(f)
    except FileNotFoundError:
        return {"holdings": [], "history": []}
    except ValueError:
        raise RuntimeError(f"{PORTFOLIO_FILE} is not valid JSON. Fix or delete it.")
    data.setdefault("holdings", [])
    data.setdefault("history", [])
    return data


def _save_portfolio(data):
    tmp = PORTFOLIO_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, PORTFOLIO_FILE)


def get_portfolio():
    """Holdings with cost, current value, and what you would actually net selling now."""
    data = _load_portfolio()
    try:
        items = fetch_items()
        lookup_error = None
    except RolimonsError as e:
        items, lookup_error = {}, str(e)

    rows = []
    total_cost = total_value = total_net = 0
    for h in data["holdings"]:
        item = items.get(h["id"])
        row = {"id": h["id"], "name": h["name"], "cost": h["cost"], "bought_at": h.get("bought_at")}
        if item:
            value = effective_value(item)
            net = int(value * (1 - MARKETPLACE_FEE))
            row.update({
                "current_value": value,
                "rap": item["rap"],
                "unrealized_gain": value - h["cost"],
                "net_if_sold_now": net,
                "net_profit_if_sold_now": net - h["cost"],
                "flags": item_flags(item),
            })
            total_value += value
            total_net += net
        else:
            row["current_value"] = None
        total_cost += h["cost"]
        rows.append(row)

    result = {
        "holdings": rows,
        "total_cost": total_cost,
        "total_current_value": total_value,
        "total_net_if_sold_now": total_net,
        "total_net_profit_if_sold_now": total_net - total_cost,
        "realized_profit": sum(e.get("profit", 0) for e in data["history"] if e["action"] == "sell"),
        "note": "net_if_sold_now subtracts Roblox's 30% marketplace fee.",
    }
    if lookup_error:
        result["warning"] = f"Live values unavailable: {lookup_error}"
    return result


def update_portfolio(action, item, price):
    """Record a purchase (add), a sale (sell) or remove an entry (remove). Local file only."""
    if action not in ("add", "sell", "remove"):
        return {"ok": False, "error": "action must be 'add', 'sell' or 'remove'."}
    try:
        price = int(price)
    except (TypeError, ValueError):
        return {"ok": False, "error": "price must be a whole number of Robux."}
    if price < 0:
        return {"ok": False, "error": "price cannot be negative."}

    data = _load_portfolio()
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    if action == "add":
        found, candidates = resolve_item(item)
        if found is None:
            return {"ok": False, "error": f"Could not identify '{item}'.", "did_you_mean": candidates}
        entry = {"id": found["id"], "name": found["name"], "cost": price, "bought_at": now}
        data["holdings"].append(entry)
        data["history"].append({"action": "add", **entry})
        _save_portfolio(data)
        return {"ok": True, "added": entry}

    # sell / remove operate on what you already hold, matched by id or name.
    ql = str(item).strip().lower()
    idx = next((n for n, h in enumerate(data["holdings"])
                if h["id"] == str(item).strip() or h["name"].lower() == ql), None)
    if idx is None:
        idx = next((n for n, h in enumerate(data["holdings"]) if ql in h["name"].lower()), None)
    if idx is None:
        return {"ok": False, "error": f"'{item}' is not in your portfolio."}
    holding = data["holdings"].pop(idx)

    if action == "remove":
        data["history"].append({"action": "remove", "id": holding["id"], "name": holding["name"], "at": now})
        _save_portfolio(data)
        return {"ok": True, "removed": holding}

    # price is the listing price the buyer paid; you receive 70% of it.
    proceeds = int(price * (1 - MARKETPLACE_FEE))
    record = {"action": "sell", "id": holding["id"], "name": holding["name"], "cost": holding["cost"],
              "sale_price": price, "proceeds_after_fee": proceeds, "profit": proceeds - holding["cost"], "at": now}
    data["history"].append(record)
    _save_portfolio(data)
    return {"ok": True, "sold": record}


# ------------------------------------------------------------------------ CLI

def _print_item(i):
    value = f"{i['value']:,}" if i["value"] is not None else "unvalued"
    print(f"  {i['name']} [{i['acronym'] or '-'}]  RAP {i['rap']:,}  value {value}  "
          f"demand {i['demand']}  trend {i['trend']}")
    for f in i["flags"]:
        print(f"      ! {f}")


def main(argv=None):
    p = argparse.ArgumentParser(description="Roblox Limited trade advisor (advice only).")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search", help="search items by name or acronym")
    s.add_argument("query")
    t = sub.add_parser("trade", help="evaluate a trade")
    t.add_argument("--give", nargs="+", required=True)
    t.add_argument("--get", nargs="+", required=True)
    c = sub.add_parser("scan", help="scan for flip candidates")
    c.add_argument("--budget", type=int, required=True)
    c.add_argument("--min-edge", type=float, default=0.10)
    c.add_argument("--min-demand", type=int, default=2, choices=range(0, 5))
    sub.add_parser("portfolio", help="show portfolio")
    args = p.parse_args(argv)

    try:
        if args.cmd == "search":
            r = search_items(args.query)
            print(f"{r['total_matches']} match(es) for '{args.query}':")
            for i in r["results"]:
                _print_item(i)
        elif args.cmd == "trade":
            r = evaluate_trade(args.give, args.get)
            if r["verdict"] is None:
                print(r["error"])
                for u in r.get("unresolved", []):
                    print(f"  ? {u['query']} -> did you mean: {', '.join(u['did_you_mean']) or 'nothing found'}")
                return 1
            print(f"Verdict: {r['verdict'].upper()}  (you get {r['value_ratio_get_over_give']:.0%} "
                  f"of what you give, {r['value_difference']:+,} value)")
            for side in ("give", "get"):
                print(f"{side.upper()} (value {r[side]['total_value']:,}):")
                for i in r[side]["items"]:
                    _print_item(i)
            for risk in r["risks"]:
                print(f"  - {risk}")
        elif args.cmd == "scan":
            r = scan_candidates(args.budget, args.min_edge, args.min_demand)
            print(f"{r['count']} candidate(s) under {args.budget:,} R$:")
            for i in r["candidates"]:
                print(f"  {i['name']}: RAP {i['rap']:,} value {i['value']:,} edge {i['edge']:.0%} "
                      f"net after fee {i['net_after_fee']:+,}")
            for n in r["notes"]:
                print(f"  * {n}")
        elif args.cmd == "portfolio":
            r = get_portfolio()
            for h in r["holdings"]:
                print(f"  {h['name']}: cost {h['cost']:,}  value {h.get('current_value') or '?'}")
            print(f"Cost {r['total_cost']:,} | value {r['total_current_value']:,} | "
                  f"net if sold now {r['total_net_if_sold_now']:,}")
            if "warning" in r:
                print(r["warning"])
    except RolimonsError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
