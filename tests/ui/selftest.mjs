#!/usr/bin/env node
// Proves each check in check.mjs can fail: builds tiny synthetic scenes and runs check.mjs on them.
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const here = path.dirname(new URL(import.meta.url).pathname);
let id = 0;
const node = (name, cls, rect, parent, extra = {}) => ({ id: ++id, name, class: cls, rect, parent, visible: true, path: "CoreGui.RURStory." + name, ...extra });
function scene(W, H, build) {
	id = 0;
	const root = { id: ++id, name: "RURStory", class: "ScreenGui", rect: [0, 36, W, H - 36], visible: true, path: "CoreGui.RURStory" };
	return { viewport: { width: W, height: H }, nodes: [root, ...build(root.id)] };
}
const btn = (name, rect, parent, text = "Go") => node(name, "TextButton", rect, parent, { props: { text }, bg: { transparency: 0 } });
const label = (name, rect, parent, text, extra = {}) => node(name, "TextLabel", rect, parent, { props: { text, ...extra }, bg: { transparency: 1 }, text: { size: 20, lines: [{ x: rect[0], top: rect[1], width: rect[2], height: rect[3] }] } });

const cases = {
	"touch-target": scene(844, 390, (r) => [btn("Small", [100, 100, 30, 30], r)]),
	overlap: scene(844, 390, (r) => [btn("A", [100, 100, 60, 60], r), btn("B", [140, 120, 60, 60], r)]),
	offscreen: scene(844, 390, (r) => [btn("Edge", [800, 100, 80, 60], r)]),
	"safe-zone": scene(844, 390, (r) => [btn("Stick", [20, 300, 60, 60], r)]),
	"text-size": scene(844, 390, (r) => [label("Tiny", [100, 100, 80, 20], r, "tiny", { textScaled: true })].map((n) => ({ ...n, text: { ...n.text, size: 9 } }))),
	"outside-panel": scene(844, 390, (r) => {
		const p = node("DemoPanel", "Frame", [200, 80, 400, 250], r, { bg: { transparency: 0 } });
		return [p, btn("Wide", [500, 120, 200, 60], p.id)].map((n) => (n.name === "Wide" ? { ...n, path: "CoreGui.RURStory.DemoPanel.Wide" } : n));
	}),
	"picker-columns": scene(844, 390, (r) => {
		const panel = node("PickerPanel", "Frame", [100, 50, 640, 320], r, { bg: { transparency: 0 } });
		const grid = node("Actors", "Frame", [110, 100, 600, 200], panel.id, { path: "CoreGui.RURStory.PickerPanel.CastList.Actors" });
		const cards = [0, 1, 2, 3].map((i) => ({ ...btn("C" + i, [110 + i * 150, 100, 140, 100], grid.id), path: `CoreGui.RURStory.PickerPanel.CastList.Actors.C${i}` }));
		return [panel, grid, ...cards].map((n) => (n.name === "Actors" ? n : n));
	}),
};
let bad = 0;
for (const [rule, sc] of Object.entries(cases)) {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), "uicheck-"));
	fs.writeFileSync(path.join(dir, "scene.json"), JSON.stringify(sc));
	const res = spawnSync("node", [path.join(here, "check.mjs"), dir], { encoding: "utf8" });
	const hit = res.stdout.includes(`FAIL ${rule}`);
	console.log(`${hit ? "ok  " : "MISS"} ${rule} fails when broken`);
	if (!hit || res.status !== 1) bad++;
}
// A clean scene must pass.
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "uicheck-"));
fs.writeFileSync(path.join(dir, "scene.json"), JSON.stringify(scene(844, 390, (r) => [btn("Fine", [300, 120, 120, 60], r)])));
const clean = spawnSync("node", [path.join(here, "check.mjs"), dir], { encoding: "utf8" });
console.log(`${clean.status === 0 ? "ok  " : "MISS"} clean scene passes`);
if (clean.status !== 0) bad++;
process.exit(bad ? 1 : 0);
