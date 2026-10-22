"""Store logo: chunky 3D "HOLLYWOOD RNG" in gold and rainbow with a white outline, a clapperboard,
a die and the bacon-hair player in a beret, on a transparent background.

Renders $STORE_OUT/logo.png (2400 x 1350). compose.py crops it and uses it in the thumbnails.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bacon  # noqa: E402
import kit  # noqa: E402

NAVY = "#1B2340"


def stripes_material(name, a="#FFFFFF", b="#24222B", scale=1.7):
    """Diagonal clapperboard stripes in the object's own coordinates."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Coat Weight"].default_value = 0.4
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(sep.outputs["X"], add.inputs[0])
    nt.links.new(sep.outputs["Z"], add.inputs[1])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = scale
    nt.links.new(add.outputs[0], mul.inputs[0])
    frac = nt.nodes.new("ShaderNodeMath")
    frac.operation = "FRACT"
    nt.links.new(mul.outputs[0], frac.inputs[0])
    step = nt.nodes.new("ShaderNodeMath")
    step.operation = "GREATER_THAN"
    step.inputs[1].default_value = 0.5
    nt.links.new(frac.outputs[0], step.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*kit.hex_rgb(b), 1)
    mix.inputs["B"].default_value = (*kit.hex_rgb(a), 1)
    nt.links.new(step.outputs[0], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mat


def clapperboard(name, location, rotation=(0, 0, 0), size=1.0, open_angle=24):
    root = kit._empty(name, location, rotation, scale=size)
    slate_mat = kit.material("#2E2C34")
    slate = kit.primitive("cube", f"{name}_slate", (0, 0, 0), (2.6, 0.32, 1.9), slate_mat, bevel=0.08)
    kit._child(slate, root)
    chalk = kit.material("#F4E7CF")
    for i, (w, z) in enumerate(((2.1, 0.42), (2.1, -0.08), (1.3, -0.55))):
        line = kit.primitive("cube", f"{name}_line{i}", (-(2.1 - w) / 2, -0.17, z), (w, 0.04, 0.09), chalk)
        kit._child(line, root)
    stripes = stripes_material(f"{name}_stripes")
    stick = kit.primitive("cube", f"{name}_stick", (0, 0, 1.2), (2.6, 0.34, 0.46), stripes, bevel=0.05)
    kit._child(stick, root)
    hinge = kit._empty(f"{name}_hinge", (-1.3, 0, 1.45), (0, -open_angle, 0))
    kit._child(hinge, root)
    hinge.location = (-1.3, 0, 1.45)
    clap = kit.primitive("cube", f"{name}_clap", (1.3, 0, 0.24), (2.6, 0.34, 0.46), stripes, bevel=0.05)
    kit._child(clap, hinge)
    pin = kit.primitive("cylinder", f"{name}_pin", (0, -0.2, 0.0), (0.22, 0.22, 0.08), kit.material("#F5B82E", "Metal"), rotation=(90, 0, 0))
    kit._child(pin, hinge)
    return root


def build():
    kit.new_scene(2400, 1350, samples=128, transparent=True)
    bpy.context.scene.view_settings.view_transform = "Standard"
    kit.sky(top="#DCE8FF", middle="#9FB6E0", horizon="#55618A", glow="#2A2F4A", strength=0.9)

    gold = kit.ramp_material("HollywoodFill", [(0.0, "#FF9A1A"), (0.45, "#FFD23F"), (1.0, "#FFF6B0")], axis="Y", emission=0.15)
    rainbow = kit.ramp_material("RngFill", [(0.0, "#FF3B5C"), (0.2, "#FF9A1F"), (0.4, "#FFE53B"), (0.6, "#3EDB6A"), (0.8, "#3A9BFF"), (1.0, "#B05CFF")],
                                axis="X", emission=0.2)
    navy = kit.material(NAVY)
    white = kit.material("#FFFFFF", emission=0.35)

    # Front-page style: bright fills, a dark outline and a fat white outline round it all.
    kit.title("HOLLYWOOD", 1.42, gold, navy, location=(-0.5, 0, 1.78), rotation=(6, 0, 0), thickness=0.08, depth=0.3,
              outline2=white, thickness2=0.07, arc=8.5)
    kit.title("RNG", 3.35, rainbow, navy, location=(-0.5, 0.15, -1.05), thickness=0.07, depth=0.5, outline2=white, thickness2=0.05)

    clapperboard("Clapper", (-4.55, 0.9, -1.35), rotation=(6, 14, -20), size=1.0)
    kit.die("Die", (3.55, -0.9, -2.35), rotation=(16, 22, 30), size=1.35, color="#FFFFFF", pip_color="#E8306A", top=5, front=6, right=3)
    # The player pops up beside the words, star-struck, in a director's beret.
    bacon.avatar("Player", (2.6, 1.4, -4.3), yaw=-16, face="starstruck", hat="beret", head_scale=1.3, legs=False,
                 pose={"arm_r": (-10, 0, 0), "arm_l": (-160, 28, 0), "head": (0, 10, 6)})
    for i, (x, z, s_) in enumerate([(-1.55, 0.15, 0.55), (1.85, -2.05, 0.4), (-3.4, 3.0, 0.35)]):
        kit.sparkle(f"Glint{i}", (x, -1.6, z), size=s_, strength=6.0)

    for i, (x, z, s_, r) in enumerate([(-5.25, 2.2, 0.42, -12), (2.4, 3.15, 0.36, 14), (-5.8, 0.15, 0.3, 8), (5.6, -0.4, 0.3, -6)]):
        kit.gold_star(f"Star{i}", (x, -0.4, z), rotation=(0, r, 0), size=s_, color="#FFD23F", emission=0.3)

    kit.light("AREA", (-3, -12, 14), 2600, "#FFF6E8", target=(0, 0, 0), size=14, name="Key")
    kit.light("AREA", (6, -16, -3), 900, "#DCE6FF", target=(0, 0, 0), size=10, name="Fill")
    kit.light("AREA", (0, 10, 6), 1600, "#FFFFFF", target=(0, 0, 0), size=12, name="Rim")
    kit.camera((0, -27, -0.6), (0, 0, -0.15), lens=76)
    kit.glare(threshold=1.6, size=6, mix=-0.75)


if __name__ == "__main__":
    build()
    kit.render(os.path.join(kit.OUT, "logo.png"))
