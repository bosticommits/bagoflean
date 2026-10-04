"""The design agent: research -> ideas -> draw -> review/revise -> listing."""

from __future__ import annotations

import datetime as dt
import io
import json
import re
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

import anthropic
from PIL import Image

from . import prompts
from .compliance import AI_DISCLOSURE, TAG_COUNT, TAG_MAX, TITLE_MAX, find_blocked, listing_problems
from .fonts import FONTS
from .llm import LLM, AgentError, image_block
from .niche import PICKLEBALL, NicheProfile
from .render import (
    check_slogan,
    extract_svg,
    inspect_png,
    make_mockup,
    on_color,
    render_png,
    validate_svg,
)
from .textmetrics import MEASURE_TOOL, run_measure_tool

OUTPUT_DIR = Path("output")
SHIP_SCORE = 8

_print_lock = threading.Lock()


def log(msg: str) -> None:
    with _print_lock:
        print(msg, flush=True)


@dataclass
class Round:
    number: int
    svg: str
    png: bytes
    mockup: bytes
    critique: dict
    auto_issues: list[str]

    @property
    def score(self) -> int:
        # An automated failure (missing words, protected names) never wins.
        return self.critique.get("score", 0) - (10 if self.auto_issues else 0)


@dataclass
class DesignAgent:
    niche: NicheProfile = PICKLEBALL
    llm: LLM = field(default_factory=LLM)
    output_dir: Path = OUTPUT_DIR
    max_rounds: int = 3

    # ---------------------------------------------------------------- ideas
    def research(self) -> str:
        log("Researching current trends with web search...")
        messages = [{
            "role": "user",
            "content": f"Today is {dt.date.today():%A, %B %d, %Y}. Research the market now.",
        }]
        message = self.llm.call(
            system=prompts.research_system(self.niche),
            messages=messages,
            effort="medium",
            tools=[{"type": "web_search_20260209", "name": "web_search", "max_uses": 6}],
        )
        return self.llm.text(message)

    def existing_slogans(self) -> list[str]:
        slogans = []
        for path in sorted(self.output_dir.glob("*/concept.json")):
            try:
                slogans.append(json.loads(path.read_text())["slogan"])
            except (OSError, KeyError, json.JSONDecodeError):
                continue
        return slogans

    def ideate(self, count: int, focus: str | None = None, research: bool = False) -> list[dict]:
        brief = self.research() if research else ""
        existing = self.existing_slogans()
        parts = [f"Today is {dt.date.today():%A, %B %d, %Y}.",
                 f"Propose exactly {count} new design concepts for the shop."]
        if focus:
            parts.append(f"Focus for this batch: {focus}")
        if brief:
            parts.append(f"<market_research>\n{brief}\n</market_research>")
        if existing:
            parts.append(
                "Already in the shop - don't repeat these jokes or make near-duplicates:\n"
                + "\n".join(f"- {s}" for s in existing)
            )
        log(f"Generating {count} concept(s)...")
        data = self.llm.json(
            system=prompts.strategist_system(self.niche),
            messages=[{"role": "user", "content": "\n\n".join(parts)}],
            effort="high",
            schema=prompts.IDEAS_SCHEMA,
            max_tokens=32000,
        )
        concepts = []
        for concept in data["concepts"][:count]:
            hits = find_blocked(f"{concept['slogan']} {concept['secondary_text']}", self.niche.blocked_terms)
            if hits:
                log(f"  dropped {concept['slogan']!r}: mentions {hits}")
                continue
            concept["fonts"] = [f for f in concept["fonts"] if f in FONTS] or ["Anton"]
            concept["slug"] = slugify(concept["slug"] or concept["slogan"])
            concepts.append(concept)
        return concepts

    # --------------------------------------------------------------- design
    def _brief(self, concept: dict) -> str:
        return (
            "Design this t-shirt graphic.\n\n<brief>\n"
            + json.dumps({k: v for k, v in concept.items() if k != "why_it_sells"}, indent=2)
            + "\n</brief>\n\nThe brief's fonts and palette are a starting point; change them if "
            "something else clearly works better. Keep the slogan wording exactly."
        )

    def _draw(self, messages: list[dict]) -> str:
        """Run the designer until it returns an SVG that validates and renders."""
        for _ in range(14):
            message = self.llm.call(
                system=prompts.designer_system(self.niche),
                messages=messages,
                effort="high",
                tools=[MEASURE_TOOL],
            )
            messages.append({"role": "assistant", "content": message.content})

            if message.stop_reason == "tool_use":
                results = []
                for block in message.content:
                    if block.type != "tool_use":
                        continue
                    try:
                        output = run_measure_tool(block.input)
                        results.append({"type": "tool_result", "tool_use_id": block.id,
                                        "content": json.dumps(output)})
                    except ValueError as exc:
                        results.append({"type": "tool_result", "tool_use_id": block.id,
                                        "content": f"Error: {exc}", "is_error": True})
                messages.append({"role": "user", "content": results})
                continue

            svg = extract_svg(self.llm.text(message))
            if not svg:
                messages.append({"role": "user", "content":
                                 "I couldn't find an SVG. Reply with the complete SVG in one ```svg block."})
                continue
            report = validate_svg(svg)
            if report.ok:
                try:
                    render_png(svg, 450, 540)
                    return svg
                except Exception as exc:  # CairoSVG raises a variety of types
                    report.errors.append(f"Renderer error: {exc}")
            messages.append({"role": "user", "content":
                             "The SVG failed technical checks. Fix these and send the full SVG again:\n- "
                             + "\n- ".join(report.errors)})
        raise AgentError("The designer could not produce a valid SVG.")

    def _auto_checks(self, concept: dict, svg: str, png: bytes) -> tuple[list[str], list[str]]:
        """Returns (blocking issues, advisory warnings)."""
        report = validate_svg(svg)
        blocking, advisory = [], []
        missing = check_slogan(report.text, concept["slogan"])
        if missing:
            blocking.append(f"Slogan words missing or misspelled in the artwork text: {missing}")
        hits = find_blocked(report.text, self.niche.blocked_terms)
        if hits:
            blocking.append(f"Artwork mentions protected names: {hits}")
        advisory += inspect_png(png).warnings
        return blocking, advisory

    def _critique(self, concept: dict, mockup: bytes, closeup: bytes, notes: list[str]) -> dict:
        thumb = Image.open(io.BytesIO(mockup))
        thumb = thumb.resize((300, int(300 * thumb.height / thumb.width)), Image.LANCZOS)
        buf = io.BytesIO()
        thumb.save(buf, format="PNG")
        content = [
            {"type": "text", "text": "<brief>\n" + json.dumps(concept, indent=2) + "\n</brief>\n\n"
             "Image 1: mockup. Image 2: same mockup at search-thumbnail size. "
             "Image 3: flat artwork close-up on the shirt colour."},
            image_block(mockup),
            image_block(buf.getvalue()),
            image_block(closeup),
            {"type": "text", "text": "Automated checks:\n" + ("\n".join(f"- {n}" for n in notes) or "- all passed")},
        ]
        return self.llm.json(
            system=prompts.critic_system(self.niche),
            messages=[{"role": "user", "content": content}],
            effort="medium",
            schema=prompts.CRITIQUE_SCHEMA,
            max_tokens=16000,
        )

    def design(self, concept: dict) -> Round:
        shirt = concept["shirt_color_hex"]
        messages: list[dict] = [{"role": "user", "content": self._brief(concept)}]
        rounds: list[Round] = []
        for number in range(1, self.max_rounds + 1):
            log(f"  [{concept['slug']}] drawing (round {number})...")
            svg = self._draw(messages)
            png = render_png(svg)
            mockup = make_mockup(png, shirt)
            closeup = on_color(png, shirt)
            blocking, advisory = self._auto_checks(concept, svg, png)
            critique = self._critique(concept, mockup, closeup, blocking + advisory)
            rounds.append(Round(number, svg, png, mockup, critique, blocking))
            log(f"  [{concept['slug']}] round {number}: score {critique['score']}/10, {critique['verdict']}"
                + (f" - {'; '.join(blocking)}" if blocking else ""))
            if critique["verdict"] == "ship" and critique["score"] >= SHIP_SCORE and not blocking:
                break
            if number == self.max_rounds:
                break
            feedback = (
                "Art director review of your design (images attached: mockup, then flat close-up):\n"
                + json.dumps(critique, indent=2)
                + ("\n\nAutomated checks:\n- " + "\n- ".join(blocking + advisory) if blocking + advisory else "")
                + "\n\nRevise the design to address this feedback. Re-measure any text you change, "
                "then send the complete revised SVG."
            )
            messages.append({"role": "user", "content": [
                {"type": "text", "text": feedback}, image_block(mockup), image_block(closeup)]})
        return max(rounds, key=lambda r: (r.score, r.number))

    # -------------------------------------------------------------- listing
    def listing(self, concept: dict, mockup: bytes) -> dict:
        messages = [{"role": "user", "content": [
            {"type": "text", "text": "Write the Etsy listing for this design.\n<brief>\n"
             + json.dumps(concept, indent=2) + "\n</brief>"},
            image_block(mockup),
        ]}]
        listing = {}
        for _ in range(2):
            message = self.llm.call(
                system=prompts.copywriter_system(self.niche), messages=messages,
                effort="medium", schema=prompts.LISTING_SCHEMA, max_tokens=16000,
            )
            listing = json.loads(self.llm.text(message))
            problems = listing_problems(listing, self.niche.blocked_terms)
            if not problems:
                break
            messages.append({"role": "assistant", "content": message.content})
            messages.append({"role": "user", "content": "Fix these problems and return the full listing:\n- "
                             + "\n- ".join(problems)})
        enforce_listing_limits(listing)
        listing["description"] = listing["description"].rstrip() + "\n\n" + AI_DISCLOSURE
        listing["problems"] = listing_problems(listing, self.niche.blocked_terms)
        return listing

    # ------------------------------------------------------------ end to end
    def make(self, concept: dict) -> Path | None:
        try:
            best = self.design(concept)
            log(f"  [{concept['slug']}] writing listing...")
            listing = self.listing(concept, best.mockup)
        except (AgentError, anthropic.APIError) as exc:
            log(f"  [{concept['slug']}] FAILED: {exc}")
            return None
        folder = save(self.output_dir, concept, best, listing)
        log(f"  [{concept['slug']}] saved to {folder} (score {best.critique['score']}/10)")
        return folder

    def make_many(self, concepts: list[dict], jobs: int = 1) -> list[Path]:
        with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
            return [p for p in pool.map(self.make, concepts) if p]


def slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return "-".join(slug.split("-")[:8]) or "design"


def enforce_listing_limits(listing: dict) -> None:
    """Last-resort trimming so a listing can always be pasted into Etsy."""
    title = listing.get("title", "")
    if len(title) > TITLE_MAX:
        listing["title"] = title[:TITLE_MAX].rsplit(" ", 1)[0].rstrip(",|-– ")
    seen, tags = set(), []
    for tag in listing.get("tags", []):
        tag = re.sub(r"[^A-Za-z0-9 '&-]", "", tag).strip()
        if tag and len(tag) <= TAG_MAX and tag.lower() not in seen:
            seen.add(tag.lower())
            tags.append(tag)
    listing["tags"] = tags[:TAG_COUNT]


def listing_markdown(concept: dict, listing: dict, critique: dict) -> str:
    tags = ", ".join(listing["tags"])
    products = ", ".join(listing.get("suggested_products", []))
    problems = "\n".join(f"- {p}" for p in listing.get("problems", [])) or "- none"
    return f"""# {concept['slogan']}

**Shirt colour:** {concept['shirt_color_name']} ({concept['shirt_color_hex']})
**Persona:** {concept['persona']}
**Occasion:** {concept['occasion']}
**Art director score:** {critique['score']}/10
**List it on:** {products}

## Title ({len(listing['title'])}/140)
{listing['title']}

## Tags ({len(listing['tags'])}/13)
{tags}

## Description
{listing['description']}

## Image alt text
{listing['alt_text']}

## Before you publish
- Search the slogan on the USPTO trademark search (tmsearch.uspto.gov) and on Etsy to make sure it isn't trademarked or already a best seller.
- Upload design.png (4500x5400, 300 DPI, transparent) to your print provider and use their real mockups as listing photos.
- Fill in the [BRACKETED] product details and set your production partner in the listing.
- Remaining listing warnings:
{problems}
"""


def save(output_dir: Path, concept: dict, best: Round, listing: dict) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    folder = output_dir / concept["slug"]
    n = 2
    while folder.exists():
        folder = output_dir / f"{concept['slug']}-{n}"
        n += 1
    folder.mkdir()
    (folder / "design.svg").write_text(best.svg)
    (folder / "design.png").write_bytes(best.png)
    (folder / "mockup.png").write_bytes(best.mockup)
    (folder / "concept.json").write_text(json.dumps(concept, indent=2))
    (folder / "listing.json").write_text(json.dumps(listing, indent=2))
    (folder / "review.json").write_text(json.dumps(
        {"round": best.number, "critique": best.critique, "automated": best.auto_issues}, indent=2))
    (folder / "listing.md").write_text(listing_markdown(concept, listing, best.critique))
    return folder
