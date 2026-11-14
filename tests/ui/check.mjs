#!/usr/bin/env node
// Phone-size layout checks over rur's scene.json (see tests/ui/README.md). Pure Node, no dependencies.
//   node tests/ui/check.mjs [--baseline f] [--update-baseline f] <render dir>...   (dir: scene.json + meta.json)
// Exit 1 when any error-level finding exists. Rules follow Movie Mogul/UI Taste Rules.md "Borrowed checks".
import fs from "node:fs";
import path from "node:path";

const TOUCH_MIN = 44; // px, phone sizes only
const TEXT_MIN = 12; // px, rendered height of a TextScaled label
const TOP_BAR = 36; // Roblox top bar, px
// Roblox draws the thumbstick and jump button over the game; fractions of the screen (roblox-ui-verify).
const THUMBSTICK = [0.0, 0.62, 0.3, 1.0];
const JUMP = [0.76, 0.68, 1.0, 1.0];
// On phones every open panel hides the touch controls (Declutter, UiKit.holdTouchControls), the picker too.
const PICKER_COLUMNS = 3;
const SLACK = 1.5; // px of rounding / stroke tolerance
// Parts that overhang on purpose or are pure decoration: never reported as outside / off-screen / overlapping.
const DECOR = /(^|\.)(PanelIcon|[A-Za-z]*Shadow|[A-Za-z]*Scrim|[A-Za-z]*Dim|Glow|Halo|Shine|Backdrop|Outline|Next)(\.|$)/;

const area = (r) => Math.max(0, r[2]) * Math.max(0, r[3]);
function intersect(a, b) {
	const x0 = Math.max(a[0], b[0]), y0 = Math.max(a[1], b[1]);
	const x1 = Math.min(a[0] + a[2], b[0] + b[2]), y1 = Math.min(a[1] + a[3], b[1] + b[3]);
	return x1 > x0 && y1 > y0 ? [x0, y0, x1 - x0, y1 - y0] : null;
}
const fmt = (r) => `[${r.map((v) => Math.round(v * 10) / 10).join(", ")}]`;
const short = (p) => p.replace(/^CoreGui\.RURStory\.?/, "");

function checkScene(dir) {
	const scene = JSON.parse(fs.readFileSync(path.join(dir, "scene.json"), "utf8"));
	const meta = fs.existsSync(path.join(dir, "meta.json")) ? JSON.parse(fs.readFileSync(path.join(dir, "meta.json"), "utf8")) : {};
	const { width: W, height: H } = scene.viewport;
	const phone = Math.min(W, H) <= 500;
	const nodes = scene.nodes;
	const byId = new Map(nodes.map((n) => [n.id, n]));
	const root = nodes[0]; // the RURStory ScreenGui: the game's safe area (below the top bar)
	const findings = [];
	const add = (rule, level, node, msg, size) => {
		// With a panel open the story is about that panel: the HUD behind it is checked by the Hud story.
		if (scoped && !info.get(node.id)?.panel) return;
		findings.push({ rule, level, path: short(node.path), rect: node.rect.map((v) => Math.round(v * 10) / 10), msg, size });
	};
	let scoped = false;

	const parentOf = (n) => byId.get(n.parent);
	const ancestors = (n) => { const out = []; for (let p = parentOf(n); p; p = parentOf(p)) out.push(p); return out; };
	// Visible = itself and every ancestor visible, and (for content under a ScrollingFrame) inside its window.
	const info = new Map();
	for (const n of nodes) {
		const anc = ancestors(n);
		let vis = n.visible && anc.every((a) => a.visible);
		let clip = n.rect;
		for (const a of anc) if (a.class === "ScrollingFrame" && clip) clip = intersect(clip, a.rect);
		if (!clip || area(clip) < 1) vis = false;
		const panel = [n, ...anc].reverse().find((x) => /Panel$/.test(x.name) && x.parent === root.id);
		info.set(n.id, { vis, clip, anc, panel, decor: DECOR.test(n.path), scrolled: anc.some((a) => a.class === "ScrollingFrame") });
	}
	const isButton = (n) => n.class === "TextButton" || n.class === "ImageButton";
	const text = (n) => (typeof n.props?.text === "string" ? n.props.text : "");
	const drawn = (n) => (n.bg && n.bg.transparency < 1) || text(n) !== "" || n.image || isButton(n);
	
	// Real extent of a label: the text itself, not its (often much wider) box.
	function extent(n) {
		const lines = n.text?.lines;
		if (text(n) !== "" && Array.isArray(lines) && lines.length && !isButton(n)) {
			const x0 = Math.min(...lines.map((l) => l.x)), x1 = Math.max(...lines.map((l) => l.x + l.width));
			const y0 = Math.min(...lines.map((l) => l.top)), y1 = Math.max(...lines.map((l) => l.top + l.height));
			if (x1 > x0) return [x0, y0, x1 - x0, y1 - y0];
		}
		return info.get(n.id).clip;
	}

	scoped = nodes.some((n) => n.parent === root.id && /Panel$/.test(n.name) && info.get(n.id).vis);
	const openPanels = nodes.filter((n) => n.parent === root.id && /Panel$/.test(n.name) && info.get(n.id).vis);

	// 1. Off-screen: anything drawn outside the safe area (the story's ScreenGui).
	const bounds = root.rect;
	for (const n of nodes) {
		const i = info.get(n.id);
		if (n === root || !i.vis || i.decor || !drawn(n) || i.anc.some((a) => DECOR.test(a.path))) continue;
		const r = i.clip;
		const over = Math.max(bounds[0] - r[0], bounds[1] - r[1], r[0] + r[2] - (bounds[0] + bounds[2]), r[1] + r[3] - (bounds[1] + bounds[3]));
		if (over > SLACK && area(r) > 4) add("offscreen", "error", n, `${Math.round(over)} px outside the screen ${fmt(bounds)}`);
	}

	// 2. Outside its panel: anything drawn past the panel's outline (scroll content is already clipped to its window).
	for (const panel of openPanels) {
		for (const n of nodes) {
			const i = info.get(n.id);
			if (i.panel !== panel || n === panel || !i.vis || i.decor || !drawn(n) || i.anc.some((a) => DECOR.test(a.path))) continue;
			const r = i.clip, p = panel.rect;
			const over = Math.max(p[0] - r[0], p[1] - r[1], r[0] + r[2] - (p[0] + p[2]), r[1] + r[3] - (p[1] + p[3]));
			if (over > 6) add("outside-panel", "error", n, `${Math.round(over)} px past ${panel.name} ${fmt(p)}`);
		}
	}

	// 3. Overlap between things that should not: buttons and labels that are not parent/child, in the same
	// layer (the HUD, or inside one open panel). Labels use the extent of their text.
	const items = nodes.filter((n) => {
		const i = info.get(n.id);
		return n !== root && i.vis && !i.decor && !i.anc.some((a) => DECOR.test(a.path)) && (isButton(n) || text(n) !== "");
	});
	const layer = (n) => info.get(n.id).panel?.id ?? 0;
	for (let a = 0; a < items.length; a++) {
		for (let b = a + 1; b < items.length; b++) {
			const A = items[a], B = items[b];
			if (layer(A) !== layer(B)) continue;
			const ia = info.get(A.id), ib = info.get(B.id);
			if (ia.anc.includes(B) || ib.anc.includes(A)) continue;
			// A label inside a button belongs to it (a sibling label of the same button as well).
			const ba = ia.anc.find(isButton), bb = ib.anc.find(isButton);
			if (ba && ba === bb) continue;
			const x = intersect(isButton(A) ? ia.clip : extent(A), isButton(B) ? ib.clip : extent(B));
			if (x && x[2] > 2 && x[3] > 2) add("overlap", "error", A, `overlaps ${short(B.path)} ${fmt(B.rect)} by ${Math.round(x[2])}x${Math.round(x[3])} px`);
		}
	}

	// 3b. HUD blocks (side menu, wallet, event lines, CAST bar...) must not cover each other: compare their solid
	// frames, buttons and labels across blocks. A panel over the HUD is deliberate and not compared.
	const blockOf = (n) => [n, ...info.get(n.id).anc].find((x) => x.parent === root.id);
	const solids = nodes.filter((n) => {
		const i = info.get(n.id);
		const solid = n.class === "Frame" && n.bg && n.bg.transparency < 0.5 && n.rect[2] >= 8 && n.rect[3] >= 8;
		return n !== root && i.vis && !i.decor && !i.anc.some((a) => DECOR.test(a.path)) && !i.panel && (solid || isButton(n) || text(n) !== "");
	});
	const pairSeen = new Set(); // one finding per pair of blocks
	for (let a = 0; a < solids.length; a++) {
		for (let b = a + 1; b < solids.length; b++) {
			const A = solids[a], B = solids[b];
			if (blockOf(A) === blockOf(B)) continue;
			const pairKey = `${blockOf(A).id}-${blockOf(B).id}`;
			if (pairSeen.has(pairKey)) continue;
			const x = intersect(isButton(A) || A.class === "Frame" ? info.get(A.id).clip : extent(A), isButton(B) || B.class === "Frame" ? info.get(B.id).clip : extent(B));
			if (x && x[2] > 2 && x[3] > 2) {
				pairSeen.add(pairKey);
				add("overlap", "error", A, `overlaps ${short(B.path)} ${fmt(B.rect)} by ${Math.round(x[2])}x${Math.round(x[3])} px`);
			}
		}
	}

	// 4. Touch targets on phones.
	if (phone) {
		for (const n of nodes) {
			const i = info.get(n.id);
			if (!isButton(n) || !i.vis || i.decor) continue;
			// A card scrolled half out of view is still a full-size target: measure its real rect.
			const r = i.scrolled ? n.rect : i.clip;
			const small = Math.min(r[2], r[3]);
			if (small < TOUCH_MIN - 0.5) add("touch-target", "error", n, `${Math.round(r[2])}x${Math.round(r[3])} px, under ${TOUCH_MIN}`, Math.round(small));
		}
	}

	// 5. Safe zones on phones: top bar, thumbstick, jump button (not inside a modal that hides touch controls).
	if (phone) {
		const zone = (z) => [z[0] * W, z[1] * H, (z[2] - z[0]) * W, (z[3] - z[1]) * H];
		for (const n of nodes) {
			const i = info.get(n.id);
			if (!isButton(n) || !i.vis || i.decor) continue;
			const r = i.clip;
			if (r[1] < TOP_BAR - SLACK) add("safe-zone", "error", n, `inside the top ${TOP_BAR} px bar`);
			if (i.panel) continue; // a panel's buttons: the touch controls are hidden while it is open
			const level = "error";
			for (const [z, label] of [[THUMBSTICK, "thumbstick"], [JUMP, "jump button"]]) {
				const x = intersect(r, zone(z));
				if (x && x[2] > 4 && x[3] > 4) add("safe-zone", level, n, `in the ${label} zone (${Math.round(x[2])}x${Math.round(x[3])} px)`);
			}
		}
	}

	// 6. TextScaled labels that render too small.
	for (const n of nodes) {
		const i = info.get(n.id);
		if (!i.vis || n.props?.textScaled !== true || text(n) === "" || !n.text) continue;
		const size = n.text.size ?? n.text.textSize;
		if (size < TEXT_MIN - 0.01) add("text-size", "error", n, `"${text(n).slice(0, 28)}" renders at ${size} px, under ${TEXT_MIN}`, Math.round(size));
	}

	// 7. Picker grid: exactly three columns of actor cards.
	const cards = nodes.filter((n) => isButton(n) && n.path.includes("PickerPanel.CastList.Actors.") && n.parent && byId.get(n.parent).name === "Actors" && info.get(n.id).vis);
	if (nodes.some((n) => n.name === "PickerPanel" && info.get(n.id).vis)) {
		const xs = [];
		for (const c of cards.map((c) => c.rect[0]).sort((a, b) => a - b)) if (!xs.length || c - xs[xs.length - 1] > 12) xs.push(c);
		if (cards.length === 0) add("picker-columns", "error", openPanels[0] ?? root, "no actor cards found");
		else if (xs.length !== PICKER_COLUMNS) add("picker-columns", "error", cards[0], `${xs.length} columns of actor cards (expected ${PICKER_COLUMNS}); cell ${Math.round(cards[0].rect[2])}x${Math.round(cards[0].rect[3])}`);
	}

	// A story that must show something (e.g. Visit's Invite friends button) lists its node names in meta.expect.
	// An entry "phone:Name" only applies at phone sizes (HudMore's flyout tiles do not exist on PC).
	for (const entry of meta.expect ?? []) {
		if (entry.startsWith("phone:") && !phone) continue;
		const want = entry.replace(/^phone:/, "");
		if (!nodes.some((n) => n.name === want && info.get(n.id).vis)) findings.push({ rule: "missing", level: "error", path: want, rect: [0, 0, 0, 0], msg: `expected a visible "${want}" in this story, none rendered` });
	}

	return { dir, name: meta.name ?? path.basename(dir), viewport: `${W}x${H}`, phone, findings };
}

const args = process.argv.slice(2);
const flag = (name) => { const i = args.indexOf(name); if (i < 0) return null; const [, v] = args.splice(i, 2); return v ?? null; };
const baselinePath = flag("--baseline"); // known findings: listed, not failing; only NEW errors fail
const updatePath = flag("--update-baseline");
const dirs = args;
if (dirs.length === 0) { console.error("usage: check.mjs [--baseline file] [--update-baseline file] <render dir>..."); process.exit(2); }
const keyOf = (r, f) => `${r.name}|${f.rule}|${f.path}`;
// Baseline entries are "story|rule|path" or "story|rule|path|size=N" (touch-target / text-size: the size known today).
// A known finding that gets SMALLER than its recorded size counts as new, so a regression cannot hide in the baseline.
const known = new Map();
for (const entry of baselinePath && fs.existsSync(baselinePath) ? JSON.parse(fs.readFileSync(baselinePath, "utf8")) : []) {
	const m = /^(.*)\|size=(\d+)$/.exec(entry);
	known.set(m ? m[1] : entry, m ? Number(m[2]) : null);
}
const isKnown = (key, f) => known.has(key) && (known.get(key) === null || f.size === undefined || f.size >= known.get(key));
const results = dirs.map(checkScene);
let errors = 0, warns = 0, knownCount = 0;
const seen = new Set();
for (const r of results) {
	const shown = [];
	for (const f of r.findings) {
		const key = keyOf(r, f);
		seen.add(key);
		if (f.level === "error" && isKnown(key, f)) { knownCount++; continue; }
		shown.push(f);
	}
	console.log(`\n== ${r.name} (${r.viewport}${r.phone ? ", phone" : ""}) ==`);
	if (shown.length === 0) console.log(r.findings.length ? "  ok (only known findings)" : "  ok");
	for (const f of shown) {
		console.log(`  ${f.level === "error" ? "FAIL" : "warn"} ${f.rule.padEnd(14)} ${f.path} ${fmt(f.rect)}: ${f.msg}`);
		if (f.level === "error") errors++; else warns++;
	}
}
const fixed = [...known.keys()].filter((k) => !seen.has(k) && dirs.length > 1);
if (fixed.length) console.log(`\n${fixed.length} known finding(s) no longer appear: remove them with tests/ui/run.sh --update-baseline`);
console.log(`\n${errors} new error(s), ${warns} warning(s), ${knownCount} known (baseline) in ${results.length} render(s)`);
if (updatePath) {
	const keys = [...new Set(results.flatMap((r) => r.findings.filter((f) => f.level === "error").map((f) => keyOf(r, f) + (f.size !== undefined ? `|size=${f.size}` : ""))))].sort();
	fs.writeFileSync(updatePath, JSON.stringify(keys, null, 1) + "\n");
	console.log(`baseline written: ${keys.length} finding(s) -> ${updatePath}`);
	process.exit(0);
}
if (process.env.RUR_UI_JSON) fs.writeFileSync(process.env.RUR_UI_JSON, JSON.stringify(results, null, 1));
process.exit(errors > 0 ? 1 : 0);
