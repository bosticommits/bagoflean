"""Bundled display fonts and the fontconfig setup that lets CairoSVG find them.

Every font in fonts/ is from github.com/google/fonts under the SIL Open Font
License or Apache 2.0, both of which allow commercial use on products.
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

FONT_DIR = Path(__file__).resolve().parent.parent / "fonts"

# family name -> when to use it. The designer may only use these families.
FONTS: dict[str, str] = {
    "Anton": "tall condensed impact type; big stacked punchlines",
    "Bebas Neue": "clean condensed all-caps; modern sporty",
    "Archivo Black": "heavy grotesque; bold modern statements",
    "Alfa Slab One": "fat slab serif; vintage athletic, badges",
    "Bungee": "blocky signage caps; playful, street",
    "Bungee Shade": "Bungee with built-in 3D shade; short words only",
    "Rubik Mono One": "wide rounded geometric caps; retro arcade",
    "Staatliches": "condensed stencil-ish caps; retro poster",
    "Bowlby One SC": "chunky small caps; varsity/collegiate",
    "Black Ops One": "stencil military; team/league shirts",
    "Racing Sans One": "italic speed script; sporty energy",
    "Righteous": "rounded retro 70s display",
    "Shrikhand": "fat retro italic; groovy 70s headlines",
    "Monoton": "multi-line neon; retro, large sizes only",
    "Rye": "western woodtype; rustic, saloon",
    "Pacifico": "bold brush script; fun beachy accents",
    "Lobster": "classic bold script; vintage logos",
    "Kaushan Script": "energetic brush script; sporty accents",
    "Sacramento": "thin monoline script; elegant, use LARGE only",
    "Permanent Marker": "hand-drawn marker; casual, humorous",
    "Chewy": "bubbly cartoon; cute characters",
}

GENERIC_FAMILIES = {"serif", "sans-serif", "monospace", "cursive", "fantasy"}

_configured = False


def configure_fontconfig() -> None:
    """Point fontconfig at the bundled fonts. Must run before cairo renders."""
    global _configured
    if _configured:
        return
    cache_dir = Path(tempfile.gettempdir()) / "etsy_agent_fontcache"
    cache_dir.mkdir(exist_ok=True)
    conf = cache_dir / "fonts.conf"
    system_confs = [
        "/etc/fonts/fonts.conf",
        "/opt/homebrew/etc/fonts/fonts.conf",
        "/usr/local/etc/fonts/fonts.conf",
    ]
    includes = "\n".join(
        f'  <include ignore_missing="yes">{c}</include>' for c in system_confs
    )
    conf.write_text(
        f"""<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
{includes}
  <dir>{FONT_DIR}</dir>
  <cachedir>{cache_dir}</cachedir>
</fontconfig>
"""
    )
    os.environ["FONTCONFIG_FILE"] = str(conf)
    _configured = True


def font_menu() -> str:
    return "\n".join(f'- "{name}": {use}' for name, use in FONTS.items())
