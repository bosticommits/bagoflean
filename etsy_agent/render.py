"""SVG validation, print-file rendering, and shirt mockups."""

from __future__ import annotations

import io
import re
from dataclasses import dataclass, field

from defusedxml import ElementTree as ET
from PIL import Image

from .fonts import FONTS, GENERIC_FAMILIES, configure_fontconfig

configure_fontconfig()
import cairosvg  # noqa: E402  (fontconfig must be configured first)

# Printify / Printful front-print standard: 15 x 18 in at 300 DPI.
PRINT_W, PRINT_H = 4500, 5400
DPI = 300

SVG_NS = "{http://www.w3.org/2000/svg}"
FORBIDDEN_TAGS = {"image", "foreignObject", "script", "iframe", "video", "audio"}
# CairoSVG silently ignores most filter primitives, so the art would print
# differently from what the designer intended.
UNSUPPORTED_TAGS = {
    "feGaussianBlur", "feDropShadow", "feMorphology", "feTurbulence",
    "feDisplacementMap", "feConvolveMatrix", "feComponentTransfer",
    "feColorMatrix", "feLighting", "feDiffuseLighting", "feSpecularLighting",
}


@dataclass
class SvgReport:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    text: str = ""
    fonts: set[str] = field(default_factory=set)

    @property
    def ok(self) -> bool:
        return not self.errors


def extract_svg(text: str) -> str | None:
    match = re.search(r"<svg\b.*?</svg>", text, re.DOTALL)
    return match.group(0) if match else None


def _local(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag


def _families(value: str) -> list[str]:
    return [f.strip().strip("'\"") for f in value.split(",") if f.strip()]


def validate_svg(svg: str) -> SvgReport:
    report = SvgReport()
    try:
        root = ET.fromstring(svg)
    except ET.ParseError as exc:
        report.errors.append(f"SVG is not well-formed XML: {exc}")
        return report

    if _local(root.tag) != "svg":
        report.errors.append("Root element must be <svg>.")
    viewbox = (root.get("viewBox") or "").replace(",", " ").split()
    if viewbox != ["0", "0", str(PRINT_W), str(PRINT_H)]:
        report.errors.append(
            f'Root <svg> must have viewBox="0 0 {PRINT_W} {PRINT_H}" '
            f"(got {root.get('viewBox')!r})."
        )

    texts: list[str] = []
    for el in root.iter():
        tag = _local(el.tag)
        if tag in FORBIDDEN_TAGS:
            report.errors.append(f"<{tag}> is not allowed; draw everything as vectors.")
        if tag in UNSUPPORTED_TAGS:
            report.errors.append(f"<{tag}> is not supported by the renderer.")
        for attr, value in el.attrib.items():
            if _local(attr) == "href" and not value.startswith("#"):
                report.errors.append(f"External reference {value!r} is not allowed.")
        if tag in {"text", "tspan", "textPath"}:
            texts.append(el.text or "")
            if tag != "text":  # a tspan's tail is still inside its <text>
                texts.append(el.tail or "")
        families = []
        if el.get("font-family"):
            families.append(el.get("font-family"))
        style = el.get("style") or ""
        families += re.findall(r"font-family\s*:\s*([^;]+)", style)
        if tag == "style":
            css = el.text or ""
            if "@import" in css or "@font-face" in css:
                report.errors.append("@import / @font-face are not allowed in <style>.")
            families += re.findall(r"font-family\s*:\s*([^;}]+)", css)
        for value in families:
            names = _families(value)
            if names:
                report.fonts.add(names[0])

    unknown = {f for f in report.fonts if f not in FONTS and f.lower() not in GENERIC_FAMILIES}
    if unknown:
        report.errors.append(
            f"Fonts not available: {sorted(unknown)}. Use only: {sorted(FONTS)}."
        )
    report.text = " ".join(t for t in texts if t).strip()
    return report


def _words(text: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", text.lower().replace("'", "").replace("’", ""))


def check_slogan(svg_text: str, slogan: str) -> list[str]:
    """Words from the slogan that don't appear in the artwork's text."""
    have = set(_words(svg_text))
    return [w for w in _words(slogan) if w not in have]


def render_png(svg: str, width: int = PRINT_W, height: int = PRINT_H) -> bytes:
    png = cairosvg.svg2png(
        bytestring=svg.encode("utf-8"), output_width=width, output_height=height
    )
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    out = io.BytesIO()
    img.save(out, format="PNG", dpi=(DPI, DPI), optimize=True)
    return out.getvalue()


@dataclass
class PrintMetrics:
    width_ratio: float
    height_ratio: float
    ink_coverage: float
    margins: tuple[int, int, int, int]  # left, top, right, bottom in px
    warnings: list[str]


def inspect_png(png: bytes) -> PrintMetrics:
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    alpha = img.getchannel("A")
    bbox = alpha.point(lambda a: 255 if a > 16 else 0).getbbox()
    w, h = img.size
    if not bbox:
        return PrintMetrics(0, 0, 0, (0, 0, 0, 0), ["The artwork is empty / fully transparent."])
    left, top, right, bottom = bbox
    margins = (left, top, w - right, h - bottom)
    small = alpha.resize((w // 10, h // 10))
    coverage = sum(1 for a in small.getdata() if a > 16) / (small.width * small.height)
    warnings = []
    width_ratio, height_ratio = (right - left) / w, (bottom - top) / h
    if width_ratio < 0.6:
        warnings.append(
            f"Artwork only spans {width_ratio:.0%} of the print width; "
            "aim for 75-95% so it doesn't look tiny on the shirt."
        )
    if min(margins) < 0.01 * w:
        warnings.append("Artwork touches the edge of the canvas; keep a small margin.")
    corner = img.getpixel((2, 2))[3] > 16 and img.getpixel((w - 3, h - 3))[3] > 16
    if corner:
        warnings.append(
            "The canvas looks filled edge to edge; the background must be "
            "transparent (no full-canvas background rect)."
        )
    return PrintMetrics(width_ratio, height_ratio, coverage, margins, warnings)


def _hex(color: str) -> tuple[int, int, int]:
    c = color.lstrip("#")
    if len(c) == 3:
        c = "".join(ch * 2 for ch in c)
    return tuple(int(c[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _shade(rgb: tuple[int, int, int], factor: float) -> str:
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(v * factor))) for v in rgb)


# Tee silhouette in a 1000x1100 box; the print area sits on the chest.
_TEE = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1100" width="1000" height="1100">
  <rect width="1000" height="1100" fill="{bg}"/>
  <path d="M390 70 Q500 175 610 70 L800 125 Q900 200 965 330 L835 410 L782 340
           L790 1060 Q500 1080 210 1060 L218 340 L165 410 L35 330 Q100 200 200 125 Z"
        fill="{shirt}" stroke="{edge}" stroke-width="4" stroke-linejoin="round"/>
  <path d="M390 70 Q500 175 610 70" fill="none" stroke="{edge}" stroke-width="16"/>
  <path d="M218 340 L226 600 M782 340 L774 600" stroke="{edge}" stroke-width="3" opacity="0.35"/>
</svg>"""
PRINT_BOX = (300, 195, 400, 480)  # x, y, w, h - 4500:5400 ratio


def make_mockup(png: bytes, shirt_hex: str, size: int = 1000) -> bytes:
    rgb = _hex(shirt_hex)
    luminance = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    edge = _shade(rgb, 0.8) if luminance > 60 else _shade((60, 60, 60), 1.0)
    tee_svg = _TEE.format(bg="#f1efe9", shirt=shirt_hex, edge=edge)
    tee = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=tee_svg.encode()))).convert("RGBA")
    art = Image.open(io.BytesIO(png)).convert("RGBA")
    x, y, w, h = PRINT_BOX
    art = art.resize((w, h), Image.LANCZOS)
    tee.alpha_composite(art, (x, y))
    if size != tee.width:
        tee = tee.resize((size, int(size * tee.height / tee.width)), Image.LANCZOS)
    out = io.BytesIO()
    tee.convert("RGB").save(out, format="PNG", optimize=True)
    return out.getvalue()


def on_color(png: bytes, shirt_hex: str, width: int = 900) -> bytes:
    """The flat artwork over the shirt colour, for close-up review."""
    art = Image.open(io.BytesIO(png)).convert("RGBA")
    art = art.resize((width, int(width * art.height / art.width)), Image.LANCZOS)
    bg = Image.new("RGBA", art.size, _hex(shirt_hex) + (255,))
    bg.alpha_composite(art)
    out = io.BytesIO()
    bg.convert("RGB").save(out, format="PNG", optimize=True)
    return out.getvalue()
