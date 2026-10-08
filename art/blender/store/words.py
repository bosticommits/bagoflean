"""Store captions as chunky 3D words on transparent backgrounds, for compose.py.

Renders $STORE_OUT/words/<name>.png for each caption in CAPTIONS, cropped to the words.
"""

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

NAVY = "#1B2340"
GOLD = [(0.0, "#FF7417"), (0.35, "#FFA91F"), (0.7, "#FFDC3F"), (1.0, "#FFF6A6")]
WHITE = [(0.0, "#FFE9B0"), (0.5, "#FFFFFF"), (1.0, "#FFFFFF")]
RAINBOW = [(0.0, "#FF4FA8"), (0.22, "#FFB21A"), (0.42, "#FFE53B"), (0.6, "#4CD964"), (0.8, "#3A9BFF"), (1.0, "#B05CFF")]
BOLD_RAINBOW = [(0.0, "#FF2238"), (0.2, "#FF8A00"), (0.4, "#FFE000"), (0.6, "#1FD14A"), (0.8, "#1E7BFF"), (1.0, "#A22BFF")]
GREEN = [(0.0, "#2FA84F"), (0.5, "#5BE36F"), (1.0, "#C9FFB0")]
GREY = [(0.0, "#8D99A6"), (0.55, "#D5DCE3"), (1.0, "#FFFFFF")]


def arrow():
    """A fat arrow pointing right, as a flat shapely shape about one unit tall."""
    from shapely.geometry import Polygon

    pts = [(0, -0.22), (1.05, -0.22), (1.05, -0.55), (1.75, 0), (1.05, 0.55), (1.05, 0.22), (0, 0.22)]
    return Polygon(pts).buffer(0.06, join_style="round")


# name: (text or shape, fill stops, gradient axis)
CAPTIONS = {
    "one_in": ("1 IN", WHITE, "Y"),
    "million": ("1,000,000!", GOLD, "Y"),
    "icon": ("ICON", RAINBOW, "X"),
    "rng": ("RNG", GOLD, "Y"),
    "noob": ("NOOB", GREY, "Y"),
    "mogul": ("MOGUL", GOLD, "Y"),
    "arrow": (arrow, GOLD, "Y"),
    # Roblox front-page style (thumbnail_tower.py and thumbnail_reveal.py, put together by compose_roblox.py)
    "superstars": ("99 SUPERSTARS", WHITE, "Y"),
    "per_second": ("$1,000,000/s", BOLD_RAINBOW, "X"),
    "one_in_million": ("1 IN 1,000,000", BOLD_RAINBOW, "X"),
}
PX_PER_UNIT = 330


def render_caption(name, text, stops, axis):
    kit.new_scene(100, 100, samples=96, transparent=True)
    scene = bpy.context.scene
    scene.view_settings.view_transform = "Standard"
    kit.sky(top="#DCE8FF", middle="#9FB6E0", horizon="#55618A", glow="#2A2F4A", strength=0.9)
    fill = kit.ramp_material(f"{name}_fill", stops, axis=axis, emission=0.15)
    navy, white = kit.material(NAVY), kit.material("#FFFFFF", emission=0.35)
    if callable(text):
        root = kit.shape_title(name, text(), fill, navy, outline2=white)
    else:
        root = kit.title(text, 1.0, fill, navy, thickness=0.085, depth=0.4, outline2=white, thickness2=0.04)
    bpy.context.view_layer.update()
    lo, hi = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    for obj in root.children:
        for corner in obj.bound_box:
            w = obj.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    pad = 0.12
    width, height = hi.x - lo.x + 2 * pad, hi.z - lo.z + 2 * pad
    centre = (lo + hi) / 2
    cam = kit.camera((centre.x, -30, centre.z), (centre.x, 0, centre.z), lens=50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(width, height)
    scene.render.resolution_x = int(width * PX_PER_UNIT)
    scene.render.resolution_y = int(height * PX_PER_UNIT)
    kit.light("AREA", (-3, -12, 14), 2600, "#FFF6E8", target=(0, 0, 0), size=14, name="Key")
    kit.light("AREA", (6, -16, -3), 900, "#DCE6FF", target=(0, 0, 0), size=10, name="Fill")
    kit.light("AREA", (0, 10, 6), 1600, "#FFFFFF", target=(0, 0, 0), size=12, name="Rim")
    kit.render(os.path.join(kit.OUT, "words", f"{name}.png"))


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(CAPTIONS)
    for name in only:
        render_caption(name, *CAPTIONS[name])
