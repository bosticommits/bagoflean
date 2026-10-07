"""Offline tests: the whole agent loop against a scripted fake API client.

Run with:  python -m pytest tests   (or: python tests/test_pipeline.py)
"""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from etsy_agent.compliance import find_blocked, listing_problems  # noqa: E402
from etsy_agent.llm import LLM  # noqa: E402
from etsy_agent.niche import PICKLEBALL  # noqa: E402
from etsy_agent.pipeline import DesignAgent, enforce_listing_limits  # noqa: E402
from etsy_agent.render import check_slogan, validate_svg  # noqa: E402

SAMPLE_SVG = (Path(__file__).resolve().parent.parent / "samples/zero-zero-two/design.svg").read_text()

CONCEPT = {
    "slug": "zero-zero-two",
    "slogan": "It always starts with / 0-0-2",
    "secondary_text": "Pickleball",
    "persona": "Competitive player",
    "occasion": "Year-round",
    "search_phrase": "funny pickleball shirt",
    "visual_concept": "Retro sunset behind big numerals.",
    "style": "Retro 70s",
    "fonts": ["Shrikhand", "Bebas Neue", "Comic Sans"],
    "palette": ["#FDF0D5", "#F9C74F"],
    "shirt_color_name": "Black",
    "shirt_color_hex": "#111111",
    "why_it_sells": "Every game starts with this call.",
}

GOOD_LISTING = {
    "title": "Funny Pickleball Shirt, 0-0-2 Retro Sunset Tee, Pickleball Gift for Players",
    "tags": ["pickleball shirt", "pickleball gift", "funny pickleball", "retro sunset tee",
             "pickleball player", "dink shirt", "pickleball lover", "zero zero two",
             "pickleball mom", "pickleball dad", "sports gift", "pickleball tee", "gift for him"],
    "description": "A retro pickleball shirt for players who know every game starts the same way.",
    "alt_text": "Black t-shirt with a retro sunset and 0-0-2 pickleball design.",
    "primary_keyword": "funny pickleball shirt",
    "suggested_products": ["Unisex tee", "Crewneck sweatshirt"],
}


def block(type_, **kw):
    return SimpleNamespace(type=type_, **kw)


def message(content, stop_reason="end_turn"):
    usage = SimpleNamespace(input_tokens=100, output_tokens=50,
                            cache_creation_input_tokens=0, cache_read_input_tokens=0)
    return SimpleNamespace(content=content, stop_reason=stop_reason, usage=usage, stop_details=None)


class FakeStream:
    def __init__(self, msg):
        self.msg = msg

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False

    def get_final_message(self):
        return self.msg


class FakeClient:
    """Routes each request by system prompt and returns scripted replies."""

    def __init__(self):
        self.calls = []
        self.designer_turns = 0
        self.critic_turns = 0
        self.copy_turns = 0
        self.beta = SimpleNamespace(messages=SimpleNamespace(stream=self.stream))

    def stream(self, **params):
        # The agent keeps appending to one list, so snapshot it per call.
        params = dict(params, messages=list(params["messages"]))
        self.calls.append(params)
        system = params["system"][0]["text"]
        assert params["model"]
        assert params["thinking"] == {"type": "adaptive"}
        assert params["fallbacks"] == "default"
        if "product strategist" in system:
            return FakeStream(message([block("text", text=json.dumps({"concepts": [CONCEPT]}))]))
        if "lead graphic designer" in system:
            self.designer_turns += 1
            if self.designer_turns == 1:  # measures text first
                tool = block("tool_use", id="t1", name="measure_text",
                             input={"items": [{"font": "Shrikhand", "text": "0-0-2",
                                               "font_size": 1000, "letter_spacing": 0}]})
                return FakeStream(message([tool], stop_reason="tool_use"))
            if self.designer_turns == 2:  # broken SVG -> must be rejected
                return FakeStream(message([block("text", text="```svg\n<svg viewBox='0 0 10 10'></svg>\n```")]))
            return FakeStream(message([block("text", text=f"Here it is:\n```svg\n{SAMPLE_SVG}\n```")]))
        if "art director" in system:
            self.critic_turns += 1
            score, verdict = (6, "revise") if self.critic_turns == 1 else (9, "ship")
            critique = {"score": score, "verdict": verdict, "text_errors": [], "strengths": ["bold"],
                        "issues": ["sun too small"], "revision_instructions": "Make the sun larger."}
            return FakeStream(message([block("text", text=json.dumps(critique))]))
        if "Etsy listings" in system:
            self.copy_turns += 1
            listing = dict(GOOD_LISTING)
            if self.copy_turns == 1:  # first draft breaks the rules -> must be sent back
                listing["tags"] = listing["tags"] + ["this tag is far too long"]
            return FakeStream(message([block("text", text=json.dumps(listing))]))
        raise AssertionError(f"unexpected system prompt: {system[:80]}")


def test_full_pipeline():
    client = FakeClient()
    with tempfile.TemporaryDirectory() as tmp:
        agent = DesignAgent(llm=LLM(client=client, model="test-model"), output_dir=Path(tmp), max_rounds=3)
        concepts = agent.ideate(1)
        assert concepts[0]["fonts"] == ["Shrikhand", "Bebas Neue"]  # unknown font dropped
        folders = agent.make_many(concepts)
        assert len(folders) == 1
        folder = folders[0]
        for name in ["design.svg", "design.png", "mockup.png", "listing.json", "listing.md", "review.json"]:
            assert (folder / name).exists(), name
        listing = json.loads((folder / "listing.json").read_text())
        assert len(listing["tags"]) == 13
        assert listing["problems"] == []
        assert "AI design tools" in listing["description"]
        review = json.loads((folder / "review.json").read_text())
        assert review["critique"]["score"] == 9 and review["round"] == 2
        # A second batch must be told about the existing slogan.
        agent.ideate(1)
        assert "0-0-2" in client.calls[-1]["messages"][0]["content"]

    # The measure_text tool result went back to the designer...
    designer_calls = [c for c in client.calls if "lead graphic designer" in c["system"][0]["text"]]
    second = designer_calls[1]["messages"]
    assert second[-1]["content"][0]["type"] == "tool_result"
    assert "advance_width" in second[-1]["content"][0]["content"]
    # ...and the broken SVG was bounced with the validation errors.
    third = designer_calls[2]["messages"]
    assert "viewBox" in third[-1]["content"]
    # The revision round carried the critique and images.
    revision = designer_calls[3]["messages"][-1]["content"]
    assert "Make the sun larger" in revision[0]["text"] and revision[1]["type"] == "image"
    assert client.copy_turns == 2


def test_validation_and_compliance():
    assert validate_svg(SAMPLE_SVG).ok
    bad = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4500 5400"><image href="http://x/y.png"/>' \
          '<text font-family="Arial">Hi</text><filter><feGaussianBlur/></filter></svg>'
    errors = " ".join(validate_svg(bad).errors)
    assert "<image>" in errors and "External" in errors and "Arial" in errors and "feGaussianBlur" in errors
    assert check_slogan("IT ALWAYS STARTS WITH 0-0-2", "It always starts with / 0-0-2") == []
    assert check_slogan("DINKIN’ PROBLEM", "I've got a dinkin' problem") == ["ive", "got", "a"]
    assert find_blocked("Best JOOLA paddle", PICKLEBALL.blocked_terms) == ["JOOLA"]
    assert find_blocked("Head to the courts and engage", PICKLEBALL.blocked_terms) == []
    listing = dict(GOOD_LISTING, title="x " * 100, tags=GOOD_LISTING["tags"] + ["way too long for etsy tags"])
    assert len(listing_problems(listing, PICKLEBALL.blocked_terms)) == 3
    enforce_listing_limits(listing)
    assert len(listing["title"]) <= 140 and len(listing["tags"]) == 13


if __name__ == "__main__":
    test_validation_and_compliance()
    test_full_pipeline()
    print("all tests passed")
