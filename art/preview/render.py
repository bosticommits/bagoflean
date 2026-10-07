"""Draw a quick flat-shaded preview of the parts dumped by dump.luau.

  python3 art/preview/render.py <parts.json> <out.png> [--view front|34|side|top|back]
      [--size 900x600] [--fit] [--ground]

Not a Roblox renderer: no SurfaceGui text, particles or lights. It is good enough to check
shapes, colors, proportions and that nothing floats or clips, without opening Studio.
"""

import argparse
import json
import math

import numpy as np
from PIL import Image

SKY_TOP = np.array([0.55, 0.75, 0.95])
SKY_BOTTOM = np.array([0.93, 0.95, 0.98])
LIGHT = np.array([-0.45, 0.8, -0.4])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def box_mesh():
    v = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)])
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, quads


def wedge_mesh():
    # Roblox WedgePart: full bottom, tall edge at +Z, slope facing -Z and up.
    v = np.array(
        [
            [-0.5, -0.5, -0.5],
            [0.5, -0.5, -0.5],
            [0.5, -0.5, 0.5],
            [-0.5, -0.5, 0.5],
            [-0.5, 0.5, 0.5],
            [0.5, 0.5, 0.5],
        ]
    )
    quads = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    return v, quads


def cylinder_mesh(seg=16):
    # Axis along X, unit length and unit diameter.
    verts = []
    for x in (-0.5, 0.5):
        for i in range(seg):
            a = 2 * math.pi * i / seg
            verts.append([x, 0.5 * math.cos(a), 0.5 * math.sin(a)])
    verts.append([-0.5, 0, 0])
    verts.append([0.5, 0, 0])
    quads = []
    for i in range(seg):
        j = (i + 1) % seg
        quads.append((i, j, seg + j, seg + i))
        quads.append((2 * seg, j, i))
        quads.append((2 * seg + 1, seg + i, seg + j))
    return np.array(verts), quads


def sphere_mesh(rings=8, seg=14):
    verts = []
    for r in range(rings + 1):
        phi = math.pi * r / rings
        for i in range(seg):
            a = 2 * math.pi * i / seg
            verts.append([0.5 * math.sin(phi) * math.cos(a), 0.5 * math.cos(phi), 0.5 * math.sin(phi) * math.sin(a)])
    quads = []
    for r in range(rings):
        for i in range(seg):
            j = (i + 1) % seg
            quads.append((r * seg + i, r * seg + j, (r + 1) * seg + j, (r + 1) * seg + i))
    return np.array(verts), quads


MESHES = {"Block": box_mesh(), "Wedge": wedge_mesh(), "Cylinder": cylinder_mesh(), "Ball": sphere_mesh()}


def part_triangles(p):
    shape = p["shape"] if p["shape"] in MESHES else "Block"
    verts, polys = MESHES[shape]
    size = np.array(p["size"], dtype=float)
    if shape == "Ball":
        size = np.full(3, size.min())
    elif shape == "Cylinder":
        d = min(size[1], size[2])
        size = np.array([size[0], d, d])
    c = p["cframe"]
    pos = np.array(c[0:3])
    rot = np.array(c[3:12]).reshape(3, 3)
    world = (verts * size) @ rot.T + pos
    center = pos
    tris = []
    for poly in polys:
        for k in range(1, len(poly) - 1):
            a, b, d = world[poly[0]], world[poly[k]], world[poly[k + 1]]
            n = np.cross(b - a, d - a)
            ln = np.linalg.norm(n)
            if ln < 1e-9:
                continue
            n = n / ln
            # Make normals point away from the part centre (mesh winding is not consistent).
            if np.dot(n, (a + b + d) / 3 - center) < 0:
                n = -n
            tris.append((a, b, d, n))
    return tris


def shade(color, normal, material, transparency):
    color = np.array(color)
    if material == "Neon":
        return np.minimum(1, color * 1.15 + 0.12)
    diffuse = max(0.0, float(np.dot(normal, LIGHT)))
    up = max(0.0, normal[1])
    light = 0.5 + 0.42 * diffuse + 0.12 * up
    out = color * light
    if material == "Glass":
        out = out * 0.75 + np.array([0.75, 0.88, 1.0]) * 0.25
    if material in ("Metal", "Foil") and normal[1] > 0.3:
        out = out + 0.08
    if transparency > 0:
        out = out * (1 - transparency * 0.5) + SKY_BOTTOM * transparency * 0.5
    return np.clip(out, 0, 1)


VIEWS = {
    # yaw (degrees, 0 = looking at the model's front which faces -Z), pitch
    "front": (0, 12),
    "34": (35, 22),
    "side": (90, 12),
    "back": (180, 15),
    "top": (20, 60),
}


def render(parts, out, view="34", size=(900, 600), ground=False, ss=2, zoom=1.0):
    tris = []
    for p in parts:
        for a, b, d, n in part_triangles(p):
            t = p.get("transparency", 0)
            tris.append((a, b, d, shade(p["color"], n, p["material"], 0), 1 - t))
    if ground:
        lo = np.min([np.min([t[0], t[1], t[2]], axis=0) for t in tris], axis=0)
        hi = np.max([np.max([t[0], t[1], t[2]], axis=0) for t in tris], axis=0)
        pad = 8
        y = 0.0
        g = [np.array(v) for v in ([lo[0] - pad, y, lo[2] - pad], [hi[0] + pad, y, lo[2] - pad], [hi[0] + pad, y, hi[2] + pad], [lo[0] - pad, y, hi[2] + pad])]
        col = np.array([0.42, 0.68, 0.38])
        tris.append((g[0], g[1], g[2], col, 1.0))
        tris.append((g[0], g[2], g[3], col, 1.0))
    allv = np.array([v for t in tris if t[4] >= 1 for v in t[:3]])
    lo, hi = allv.min(axis=0), allv.max(axis=0)
    target = (lo + hi) / 2
    radius = np.linalg.norm(hi - lo) / 2
    yaw, pitch = (math.radians(a) for a in VIEWS[view])
    # Front faces -Z, so the camera starts on the -Z side.
    direction = np.array([math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
    fov = math.radians(35)
    dist = radius / math.tan(fov / 2) * 1.05 / zoom
    eye = target + direction * dist
    forward = (target - eye) / np.linalg.norm(target - eye)
    right = np.cross(forward, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, forward)

    W, H = size[0] * ss, size[1] * ss
    f = (H / 2) / math.tan(fov / 2)
    ys = np.linspace(0, 1, H)[:, None]
    img = (SKY_TOP * (1 - ys) + SKY_BOTTOM * ys)[:, None, :].repeat(W, axis=1)
    zbuf = np.full((H, W), np.inf)

    def project(v):
        rel = v - eye
        z = rel @ forward
        return np.array([W / 2 + f * (rel @ right) / z, H / 2 - f * (rel @ up) / z, z])

    # Opaque first with depth writes, then see-through parts blended on top.
    tris.sort(key=lambda t: t[4] < 1)
    for a, b, d, col, alpha in tris:
        pa, pb, pd = project(a), project(b), project(d)
        if min(pa[2], pb[2], pd[2]) <= 0.1:
            continue
        x0 = max(int(math.floor(min(pa[0], pb[0], pd[0]))), 0)
        x1 = min(int(math.ceil(max(pa[0], pb[0], pd[0]))), W - 1)
        y0 = max(int(math.floor(min(pa[1], pb[1], pd[1]))), 0)
        y1 = min(int(math.ceil(max(pa[1], pb[1], pd[1]))), H - 1)
        if x0 > x1 or y0 > y1:
            continue
        area = (pb[0] - pa[0]) * (pd[1] - pa[1]) - (pd[0] - pa[0]) * (pb[1] - pa[1])
        if abs(area) < 1e-9:
            continue
        xs, yy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        w0 = ((pb[0] - xs) * (pd[1] - yy) - (pd[0] - xs) * (pb[1] - yy)) / area
        w1 = ((pd[0] - xs) * (pa[1] - yy) - (pa[0] - xs) * (pd[1] - yy)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not inside.any():
            continue
        # Perspective-correct depth.
        invz = w0 / pa[2] + w1 / pb[2] + w2 / pd[2]
        z = 1 / np.where(invz > 0, invz, 1e-9)
        region = zbuf[y0 : y1 + 1, x0 : x1 + 1]
        closer = inside & (z < region - 1e-4)
        tile = img[y0 : y1 + 1, x0 : x1 + 1]
        if alpha < 1:
            tile[closer] = tile[closer] * (1 - alpha) + col * alpha
            continue
        region[closer] = z[closer]
        tile[closer] = col

    # Dark outlines where depth jumps, for the chunky toy look.
    finite = np.where(np.isinf(zbuf), 1e6, zbuf)
    edge = np.zeros_like(finite, dtype=bool)
    for dy, dx in ((0, 1), (1, 0)):
        a = finite
        b = np.roll(finite, (dy, dx), axis=(0, 1))
        edge |= np.abs(a - b) > 0.04 * np.minimum(a, b) + 0.3
    img[edge] = img[edge] * 0.35
    im = Image.fromarray((img * 255).astype(np.uint8)).resize(size, Image.LANCZOS)
    im.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parts")
    ap.add_argument("out")
    ap.add_argument("--view", default="34", choices=VIEWS)
    ap.add_argument("--size", default="900x600")
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--ground", action="store_true")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.split("x"))
    with open(args.parts) as fh:
        parts = json.load(fh)
    render(parts, args.out, args.view, (w, h), args.ground, zoom=args.zoom)


if __name__ == "__main__":
    main()
