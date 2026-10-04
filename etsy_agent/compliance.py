"""Etsy listing rules and protected-name screening."""

from __future__ import annotations

import re

TITLE_MAX = 140
TAG_COUNT = 13
TAG_MAX = 20

AI_DISCLOSURE = (
    "This design was created by our shop with the help of AI design tools "
    "and is printed on demand by our production partner."
)


def find_blocked(text: str, blocked_terms: list[str]) -> list[str]:
    hits = []
    for term in blocked_terms:
        if re.search(rf"(?<![A-Za-z0-9]){re.escape(term)}(?![A-Za-z0-9])", text, re.IGNORECASE):
            hits.append(term)
    return hits


def listing_problems(listing: dict, blocked_terms: list[str]) -> list[str]:
    problems = []
    title = listing.get("title", "")
    if len(title) > TITLE_MAX:
        problems.append(f"Title is {len(title)} characters; Etsy's limit is {TITLE_MAX}.")
    tags = listing.get("tags", [])
    if len(tags) != TAG_COUNT:
        problems.append(f"Need exactly {TAG_COUNT} tags (got {len(tags)}).")
    for tag in tags:
        if len(tag) > TAG_MAX:
            problems.append(f"Tag {tag!r} is {len(tag)} characters; the limit is {TAG_MAX}.")
        if not re.fullmatch(r"[A-Za-z0-9 '&-]+", tag):
            problems.append(f"Tag {tag!r} has characters Etsy rejects.")
    if len({t.lower() for t in tags}) != len(tags):
        problems.append("Tags must be unique.")
    copy = " ".join([title, listing.get("description", ""), *tags])
    hits = find_blocked(copy, blocked_terms)
    if hits:
        problems.append(f"Listing mentions protected names: {hits}.")
    return problems
