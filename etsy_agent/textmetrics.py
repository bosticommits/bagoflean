"""Exact text measurements with the bundled fonts.

The renderer can't stretch text to a target width (no SVG textLength), so the
designer measures strings with this tool and picks font sizes that fill the
layout exactly.
"""

from __future__ import annotations

from functools import lru_cache

from PIL import ImageFont

from .fonts import FONT_DIR, FONTS

_FILES = {
    "Anton": "Anton-Regular.ttf",
    "Bebas Neue": "BebasNeue-Regular.ttf",
    "Archivo Black": "ArchivoBlack-Regular.ttf",
    "Alfa Slab One": "AlfaSlabOne-Regular.ttf",
    "Bungee": "Bungee-Regular.ttf",
    "Bungee Shade": "BungeeShade-Regular.ttf",
    "Rubik Mono One": "RubikMonoOne-Regular.ttf",
    "Staatliches": "Staatliches-Regular.ttf",
    "Bowlby One SC": "BowlbyOneSC-Regular.ttf",
    "Black Ops One": "BlackOpsOne-Regular.ttf",
    "Racing Sans One": "RacingSansOne-Regular.ttf",
    "Righteous": "Righteous-Regular.ttf",
    "Shrikhand": "Shrikhand-Regular.ttf",
    "Monoton": "Monoton-Regular.ttf",
    "Rye": "Rye-Regular.ttf",
    "Pacifico": "Pacifico-Regular.ttf",
    "Lobster": "Lobster-Regular.ttf",
    "Kaushan Script": "KaushanScript-Regular.ttf",
    "Sacramento": "Sacramento-Regular.ttf",
    "Permanent Marker": "PermanentMarker-Regular.ttf",
    "Chewy": "Chewy-Regular.ttf",
}
assert set(_FILES) == set(FONTS), "every font in FONTS needs a file here"

_REF_SIZE = 1000  # measure at a fixed size, then scale linearly


@lru_cache(maxsize=None)
def _font(family: str) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / _FILES[family]), _REF_SIZE)


def measure(family: str, text: str, font_size: float, letter_spacing: float = 0) -> dict:
    """Advance width and ink box of `text`, in SVG user units.

    Ink top/bottom are relative to the baseline (negative = above), matching
    how SVG positions <text> by its baseline y.
    """
    font = _font(family)
    scale = font_size / _REF_SIZE
    advance = font.getlength(text) * scale + letter_spacing * max(len(text) - 1, 0)
    left, top, right, bottom = font.getbbox(text, anchor="ls")
    return {
        "font": family,
        "text": text,
        "font_size": font_size,
        "advance_width": round(advance, 1),
        "ink_left": round(left * scale, 1),
        "ink_width": round((right - left) * scale + letter_spacing * max(len(text) - 1, 0), 1),
        "ink_top": round(top * scale, 1),
        "ink_bottom": round(bottom * scale, 1),
        "font_size_to_fill_1000_wide": round(1000 * font_size / advance, 1) if advance else None,
    }


MEASURE_TOOL = {
    "name": "measure_text",
    "description": (
        "Measure strings exactly as they will render with the bundled fonts. "
        "Returns advance_width (what text-anchor centering uses), the ink box "
        "relative to the baseline (ink_top is negative = above baseline), and "
        "font_size_to_fill_1000_wide (scale it to fit any target width, e.g. "
        "x3.8 for 3800 px). Width scales linearly with font size. Measure "
        "every line of text before placing it so nothing overflows, collides, "
        "or looks undersized. Batch several strings in one call."
    ),
    "strict": True,
    "eager_input_streaming": True,
    "input_schema": {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "font": {"type": "string", "enum": sorted(FONTS)},
                        "text": {"type": "string"},
                        "font_size": {"type": "number"},
                        "letter_spacing": {"type": "number"},
                    },
                    "required": ["font", "text", "font_size", "letter_spacing"],
                    "additionalProperties": False,
                },
            }
        },
        "required": ["items"],
        "additionalProperties": False,
    },
}


def run_measure_tool(tool_input: object) -> list[dict]:
    """Validate (eager streaming skips server-side validation) and measure."""
    if not isinstance(tool_input, dict) or not isinstance(tool_input.get("items"), list):
        raise ValueError("Expected {'items': [...]}")
    results = []
    for item in tool_input["items"]:
        if not isinstance(item, dict):
            raise ValueError("Each item must be an object.")
        family = item.get("font")
        if family not in _FILES:
            raise ValueError(f"Unknown font {family!r}; choose from {sorted(_FILES)}.")
        text, size = item.get("text"), item.get("font_size")
        spacing = item.get("letter_spacing", 0)
        if not isinstance(text, str) or not isinstance(size, (int, float)) or size <= 0:
            raise ValueError("Each item needs a text string and a positive font_size.")
        if not isinstance(spacing, (int, float)):
            raise ValueError("letter_spacing must be a number.")
        results.append(measure(family, text, float(size), float(spacing)))
    return results
