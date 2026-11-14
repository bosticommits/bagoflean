#!/usr/bin/env bash
# Phone-size UI checks: render the real UI code with fake data in rur, then check scene.json.
#   tests/ui/run.sh              all stories x all sizes, then the checks (exit 1 on any FAIL)
#   tests/ui/run.sh Picker       one story
#   tests/ui/run.sh --strict     ignore baseline.json (known findings)
#   tests/ui/run.sh --update-baseline   accept the current findings as known
# Env: RUR_UI_OUT (default /tmp/rur-ui), RUR_BIN, RUR_ROBLOX_CONTENT. Needs Roblox Studio's fonts, so it is
# a local pre-playtest check, not a GitHub Action (see tests/ui/README.md).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
out="${RUR_UI_OUT:-/tmp/rur-ui}"
rur="${RUR_BIN:-$HOME/Desktop/tools/rur-bin/x/rur-native}"
export RUR_ROBLOX_CONTENT="${RUR_ROBLOX_CONTENT:-/Applications/RobloxStudio.app/Contents/Resources/content}"
[ -x "$rur" ] || { echo "rur binary not found at $rur (set RUR_BIN)"; exit 2; }
[ -d "$RUR_ROBLOX_CONTENT" ] || { echo "Studio content folder not found: $RUR_ROBLOX_CONTENT"; exit 2; }

# Flags: --strict (ignore tests/ui/baseline.json: list every finding), --update-baseline (rewrite it).
mode=baseline; args=()
for a in "$@"; do case "$a" in --strict) mode=strict;; --update-baseline) mode=update;; *) args+=("$a");; esac; done
stories=(${args[@]+"${args[@]}"}); [ ${#stories[@]} -gt 0 ] || stories=(Hud HudMore Studio Picker Visit Mascots Goals TutorialCast TutorialOdds)
# 844x390 / 667x375 are the phones, 750x390 is the 844 phone minus its 47 px notch insets (rur has no side
# insets), 1336x653 is PC. Every size uses a 36 px top bar inset, as the game's ScreenInsets do.
sizes=(844x390 750x390 667x375 1336x653)

# Never rm -rf an arbitrary RUR_UI_OUT: only a folder this script names (rur-ui*) or a mktemp dir may be wiped.
case "$(basename "$out")" in rur-ui*|tmp.*|rur-ui-*) ;; *) echo "refusing to wipe RUR_UI_OUT=$out (its name must start with rur-ui, or use mktemp -d)"; exit 2;; esac
[ "$out" != "/" ] && [ "$out" != "$HOME" ] || { echo "refusing to wipe $out"; exit 2; }
rm -rf "$out"; mkdir -p "$out"
cd "$repo"
node "$here/selftest.mjs" >/dev/null || { echo "check.mjs selftest failed"; node "$here/selftest.mjs"; exit 2; }
dirs=()
for story in "${stories[@]}"; do
  for size in "${sizes[@]}"; do
    d="$out/$story-$size"
    device=desktop; [ "${size%%x*}" -lt 1000 ] && device=touch
    extra=(); [ -f "tests/ui/stories/$story.actions.json" ] && extra=(--actions "tests/ui/stories/$story.actions.json")
    "$rur" render --rojo default.project.json --mount ReplicatedStorage/UiTest=tests/ui/lib \
      --story "tests/ui/stories/$story.story.luau" --viewport "$size" --scale 1 --time 1.5 --offline \
      --device "$device" --topbar-inset 36 ${extra[@]+"${extra[@]}"} --dir "$d" > "$d.log" 2>&1 || { echo "render failed: $story $size"; tail -5 "$d.log"; exit 1; }
    grep -q "script errors\|rur: error" "$d.log" && { echo "script error in $story $size"; grep -v '^{' "$d.log" | tail -8; exit 1; }
    expect="[]"; [ -f "tests/ui/stories/$story.expect.json" ] && expect="$(cat "tests/ui/stories/$story.expect.json")"
    echo "{\"name\":\"$story $size\",\"expect\":$expect}" > "$d/meta.json"
    dirs+=("$d")
  done
done
echo "renders in $out (render.png + scene.json per folder)"
base="$here/baseline.json"
case "$mode" in
  strict) node "$here/check.mjs" "${dirs[@]}" ;;
  update) node "$here/check.mjs" --update-baseline "$base" "${dirs[@]}" ;;
  *) if [ -f "$base" ]; then node "$here/check.mjs" --baseline "$base" "${dirs[@]}"; else node "$here/check.mjs" "${dirs[@]}"; fi ;;
esac
