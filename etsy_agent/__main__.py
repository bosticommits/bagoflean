"""Command line: python -m etsy_agent {ideas,make,render} ..."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path


def cmd_ideas(args) -> None:
    from .pipeline import DesignAgent

    agent = DesignAgent(output_dir=Path(args.out))
    concepts = agent.ideate(args.count, args.focus, args.research)
    agent.output_dir.mkdir(parents=True, exist_ok=True)
    path = agent.output_dir / f"ideas-{dt.datetime.now():%Y%m%d-%H%M%S}.json"
    path.write_text(json.dumps(concepts, indent=2))
    for i, c in enumerate(concepts, 1):
        print(f"\n{i}. {c['slogan']}  [{c['shirt_color_name']} shirt]")
        print(f"   for: {c['persona']} | {c['occasion']}")
        print(f"   why: {c['why_it_sells']}")
    print(f"\nSaved to {path}. Make some with: python -m etsy_agent make --ideas {path} --pick 1,2")
    print(agent.llm.usage.summary())


def cmd_make(args) -> None:
    from .pipeline import DesignAgent

    agent = DesignAgent(output_dir=Path(args.out), max_rounds=args.rounds)
    if args.ideas:
        concepts = json.loads(Path(args.ideas).read_text())
        if args.pick:
            picks = [int(p) for p in args.pick.split(",")]
            concepts = [concepts[p - 1] for p in picks]
    else:
        concepts = agent.ideate(args.count, args.focus, args.research)
    print(f"Designing {len(concepts)} design(s): " + ", ".join(repr(c["slogan"]) for c in concepts))
    folders = agent.make_many(concepts, jobs=args.jobs)
    print(f"\nDone: {len(folders)}/{len(concepts)} designs saved under {agent.output_dir}/")
    for folder in folders:
        print(f"  {folder}/listing.md")
    print(agent.llm.usage.summary())


def cmd_render(args) -> None:
    from .render import inspect_png, make_mockup, render_png, validate_svg

    svg_path = Path(args.svg)
    svg = svg_path.read_text()
    report = validate_svg(svg)
    for err in report.errors:
        print(f"error: {err}")
    png = render_png(svg)
    for warning in inspect_png(png).warnings:
        print(f"warning: {warning}")
    (svg_path.parent / "design.png").write_bytes(png)
    (svg_path.parent / "mockup.png").write_bytes(make_mockup(png, args.shirt))
    print(f"Wrote {svg_path.parent / 'design.png'} and mockup.png")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="etsy_agent", description="AI designer for an Etsy pickleball shop")
    parser.add_argument("--out", default="output", help="output folder (default: output)")
    sub = parser.add_subparsers(dest="command", required=True)

    ideas = sub.add_parser("ideas", help="brainstorm design concepts (cheap, fast)")
    ideas.add_argument("--count", type=int, default=10)
    ideas.add_argument("--focus", help='e.g. "Christmas gifts for grandparents"')
    ideas.add_argument("--research", action="store_true", help="search the web for current trends first")
    ideas.set_defaults(func=cmd_ideas)

    make = sub.add_parser("make", help="create finished designs + listings")
    make.add_argument("--count", type=int, default=3)
    make.add_argument("--focus")
    make.add_argument("--research", action="store_true")
    make.add_argument("--ideas", help="ideas JSON file from the 'ideas' command")
    make.add_argument("--pick", help="comma-separated idea numbers, e.g. 1,4,5")
    make.add_argument("--rounds", type=int, default=3, help="max review/revise rounds per design")
    make.add_argument("--jobs", type=int, default=1, help="designs to work on in parallel")
    make.set_defaults(func=cmd_make)

    render = sub.add_parser("render", help="re-render a hand-edited design.svg (no API needed)")
    render.add_argument("svg")
    render.add_argument("--shirt", default="#222222", help="shirt colour hex for the mockup")
    render.set_defaults(func=cmd_render)

    args = parser.parse_args(argv)
    try:
        args.func(args)
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()
