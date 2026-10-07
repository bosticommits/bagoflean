#!/bin/sh
# Renders every actor to art/previews/actors_sheet.png (needs lune on PATH, run from repo root).
set -e
tmp=$(mktemp -d)
ids=$(grep -o 'id = "[A-Za-z]*", name = "[^"]*", tier' src/shared/Actors.luau | sed 's/id = "\([A-Za-z]*\)".*/\1/')
for id in $ids; do
	lune run art/preview/dump.luau actor "$tmp/$id.json" "$id" >/dev/null
	python3 art/preview/render.py "$tmp/$id.json" "$tmp/$id.png" --view 34 --size 300x360 --zoom 1.1
done
python3 - "$tmp" $ids <<'PY'
import sys
from PIL import Image
tmp, ids = sys.argv[1], sys.argv[2:]
cols = 7
sheet = Image.new("RGB", (300 * cols, 360 * ((len(ids) + cols - 1) // cols)), "white")
for i, actor in enumerate(ids):
    sheet.paste(Image.open(f"{tmp}/{actor}.png"), (300 * (i % cols), 360 * (i // cols)))
sheet.save("art/previews/actors_sheet.png")
PY
rm -rf "$tmp"
