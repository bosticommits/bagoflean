"""Store thumbnail B, Roblox front-page style: a golden casting ticket turns into a 1 in
1,000,000 rainbow superstar. compose_roblox.py splits the frame, draws the sky, sunburst and
checks, the curved arrow and the words.

Renders, on transparent backgrounds:
  $STORE_OUT/reveal_ticket.png  the mystery ticket (left side)
  $STORE_OUT/reveal_star.png    the superstar on a grass baseplate (right side)
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bacon  # noqa: E402
import kit  # noqa: E402

RAINBOW = [(0.0, "#FF3B5C"), (0.2, "#FF9A1F"), (0.4, "#FFE53B"), (0.6, "#3EDB6A"), (0.8, "#3A9BFF"), (1.0, "#B05CFF")]
SIZE = (1100, 1080)


def ticket_shape(w=4.2, h=2.6, notch=0.42, corner=0.28):
    """A cinema ticket: a rounded card with a half-round bite out of each end."""
    from shapely.geometry import Point, box

    card = box(-w / 2 + corner, -h / 2 + corner, w / 2 - corner, h / 2 - corner).buffer(corner, quad_segs=8)
    for sx in (-1, 1):
        card = card.difference(Point(sx * w / 2, 0).buffer(notch, quad_segs=16))
    return card


def ticket():
    kit.new_scene(*SIZE, samples=128, transparent=True)
    kit.sky(top="#9FD4FF", middle="#7DB8F0", horizon="#5A8FD0", glow="#3A6AB0", strength=0.8)
    root = kit._empty("Ticket", (0, 0, 0), (0, 0, 0))
    gold = kit.ramp_material("TicketGold", [(0.0, "#FF9E1A"), (0.5, "#FFC93A"), (1.0, "#FFF09A")], axis="Y", metallic=0.35, emission=0.1)
    purple = kit.ramp_material("TicketPanel", [(0.0, "#4A12B8"), (0.6, "#7B2FF7"), (1.0, "#B57BFF")], axis="Y", emission=0.25)
    navy = kit.material("#1B1035")
    shape = ticket_shape()
    parts = [
        kit._slab("TicketEdge", shape.buffer(0.09, join_style="round"), -0.2, 0.0, navy, bevel=0.03),
        kit._slab("TicketBody", shape, -0.16, 0.12, gold, bevel=0.05),
        kit._slab("TicketPanel", shape.buffer(-0.3, join_style="round"), 0.0, 0.18, purple, bevel=0.04),
    ]
    # A row of little stars round the panel, like a ticket's printed border.
    for i, (x, y) in enumerate([(-1.45, 0.92), (1.45, 0.92), (-1.45, -0.92), (1.45, -0.92)]):
        s = kit.gold_star(f"TicketStar{i}", (x, y, 0.2), (90, 0, 0), size=0.17, color="#FFE14D", emission=0.4)
        parts.append(s)
    for p in parts:
        kit._child(p, root)
    q = kit.title("?", 2.3, kit.material("#FFFFFF", emission=0.6), kit.material("#5B17C9"), location=(0, 0, 0), thickness=0.07,
                  depth=0.08, outline2=kit.material("#FFFFFF", emission=0.4), thickness2=0.035)
    q.parent = root
    q.location = (0.02, -0.02, 0.24)
    q.rotation_euler = (0, 0, 0)
    root.rotation_euler = (math.radians(90), math.radians(-14), math.radians(-12))
    root.scale = (1.35, 1.35, 1.35)
    kit.glow_disc("TicketGlow", (0, 1.5, 0), 5.5, "#C77DFF", strength=2.5, facing=(0, -30, 0), power=1.8)
    rnd = random.Random(3)
    for i in range(7):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(3.6, 4.4)
        kit.sparkle(f"Glint{i}", (math.cos(a) * r, -1.5, math.sin(a) * r * 0.9), size=rnd.uniform(0.2, 0.4), strength=8)
    kit.camera((0, -30, 0), (0, 0, 0), lens=125)
    kit.light("AREA", (-6, -14, 10), 3000, "#FFF6E8", target=(0, 0, 0), size=10, name="Key")
    kit.light("AREA", (8, -10, -4), 1200, "#E6D2FF", target=(0, 0, 0), size=8, name="Fill")
    kit.light("AREA", (0, 8, 6), 2000, "#FFFFFF", target=(0, 0, 0), size=10, name="Rim")
    kit.glare(threshold=1.3, size=7, mix=-0.6)


def baseplate_material():
    """Bright Roblox baseplate green with a lighter grid every 4 studs."""
    mat = bpy.data.materials.new("Baseplate")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.7
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    lines = []
    for axis in ("X", "Y"):
        div = nt.nodes.new("ShaderNodeMath")
        div.operation = "DIVIDE"
        div.inputs[1].default_value = 4.0
        nt.links.new(sep.outputs[axis], div.inputs[0])
        fr = nt.nodes.new("ShaderNodeMath")
        fr.operation = "FRACT"
        nt.links.new(div.outputs[0], fr.inputs[0])
        lt = nt.nodes.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        lt.inputs[1].default_value = 0.05
        nt.links.new(fr.outputs[0], lt.inputs[0])
        lines.append(lt)
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    nt.links.new(lines[0].outputs[0], mx.inputs[0])
    nt.links.new(lines[1].outputs[0], mx.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*kit.hex_rgb("#4CC33A"), 1)
    mix.inputs["B"].default_value = (*kit.hex_rgb("#7FE06A"), 1)
    nt.links.new(mx.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


def superstar():
    kit.new_scene(*SIZE, samples=128, transparent=True)
    kit.sky(top="#1F7BFF", middle="#5DB4FF", horizon="#BFE6FF", glow="#E6F6FF", strength=1.0)
    cam = kit.camera((0.6, -13, 2.2), (0.3, 0, 6.9), lens=30)
    ground = kit.primitive("cube", "Ground", (0, 0, -0.5), (400, 400, 1.0), baseplate_material())
    ground.visible_diffuse = False
    rainbow = kit.ramp_material("RainbowJacket", RAINBOW, axis="Z", emission=0.35)
    _height_ramp(rainbow, 3.6, 9.0)  # bottom of the jacket to the raised hands
    with kit.collect() as star:
        av = bacon.avatar("Superstar", (0, 0, 0), yaw=-8, face="grin", outfit="star", scale=1.75, head_scale=1.15, jacket_mat=rainbow,
                          hair={"color": "#FFC21A", "light": "#FFE98A"},
                          pose={"arm_r": (-168, -26, 0), "arm_l": (-165, 30, 0), "head": (6, -4, 0), "leg_r": (0, -8, 0), "leg_l": (0, 8, 0)})
        crown_at = Vector((0.1, 0, 5.9 * 1.75 + 1.0))
        kit.gold_star("CrownStar", crown_at, (0, -6, 0), size=0.9, color="#FFD23F", emission=0.6)
    kit.glow_disc("StarAura", (0, 3.0, 6.0), 9.0, "#FFF2B0", strength=2.2, facing=cam.location, power=1.6)
    rnd = random.Random(8)
    for i in range(16):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(4.5, 8.5)
        at = (math.cos(a) * r, rnd.uniform(-3, 1), 6.2 + math.sin(a) * r * 0.85)
        if at[2] < 1.0:
            continue
        kit.sparkle(f"Sparkle{i}", at, size=rnd.uniform(0.3, 0.7), color=rnd.choice(["#FFFFFF", "#FFF2A8", "#FFD0F4"]), strength=12, face=cam)
    for i in range(6):
        a = rnd.uniform(0.2, math.pi - 0.2)
        r = rnd.uniform(6.5, 8.5)
        kit.gold_star(f"Star{i}", (math.cos(a) * r, rnd.uniform(-2, 1), 5.5 + math.sin(a) * r * 0.7), (rnd.uniform(-30, 30), 0, rnd.uniform(-30, 30)),
                      size=rnd.uniform(0.5, 0.8), color="#FFD23F", emission=0.5)
    kit.confetti(14, (0, -2, 8), (8, 3, 5), ["#FF3B5C", "#FFE53B", "#3EDB6A", "#3A9BFF", "#B05CFF"], seed=4, size=(0.4, 0.1, 0.6), emission=0.4)
    kit.light("SUN", (0, 0, 50), 3.2, "#FFF4E0", target=(8, 20, 0), angle=4, name="Sun")
    fill = kit.light("AREA", (-4, -18, 10), 2500, "#FFFFFF", target=(0, 0, 5), size=10, name="Fill")
    kit.light_only(fill, star.objects)
    for sx, color in ((-1, "#FF9DF0"), (1, "#8FE3FF")):
        rim = kit.light("AREA", (sx * 7, 6, 12), 5000, color, target=(0, 0, 6), size=4, name=f"Rim{sx}")
        kit.light_only(rim, star.objects)
    kit.glare(threshold=1.3, size=7, mix=-0.6)
    return av


def _height_ramp(mat, z0, z1):
    """Point a ramp material's colour at world height (z0 at the bottom colour, z1 at the top)."""
    nt = mat.node_tree
    sep = nt.nodes["Separate XYZ"]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = z0
    rng.inputs["From Max"].default_value = z1
    ramp = nt.nodes["Color Ramp"]
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])


if __name__ == "__main__":
    ticket()
    kit.render(os.path.join(kit.OUT, "reveal_ticket.png"))
    superstar()
    kit.render(os.path.join(kit.OUT, "reveal_star.png"))
