"""A classic blocky Roblox-style player ("bacon hair") for the store art, plus its painted faces.

Front-page Roblox thumbnails star a plain player with blocky R6 proportions (2 x 2 torso,
1 x 2 limbs, a round head), a flat painted face and the swoopy brown "bacon" hair. This
builds that look in Blender. The faces are drawn with Pillow as flat decals and wrapped onto
the front of the head, like a Roblox face.

    import bacon
    bacon.avatar("Player", (0, 0, 0), yaw=20, face="smug", pose={"arm_r": (-150, 0, 20)})

The avatar faces -Y. Sizes are in studs: about 5.4 tall with the hair.
"""

import math
import os

import bpy
from mathutils import Euler, Matrix, Vector
from PIL import Image, ImageDraw, ImageFilter

import kit

SKIN = "#F4F1EC"  # the pale skin most front-page players have
INK = (24, 22, 30, 255)
FACE_SPAN = 1.16  # studs of head front covered by the face picture
HEAD = (1.52, 1.34, 1.38)  # width, depth, height (a little big, as thumbnail artists draw it)
HEAD_Z = 4.74


# ---------------------------------------------------------------------------------------------
# Faces: flat pictures with a transparent background


def _star_points(cx, cy, outer, inner, rot=-90):
    pts = []
    for i in range(10):
        a = math.radians(rot + 36 * i)
        r = outer if i % 2 == 0 else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def _brow(d, x0, y0, x1, y1, w, arch=0.0):
    """A thick round-ended eyebrow from (x0, y0) to (x1, y1), bowed up by `arch`."""
    steps = 16
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t - arch * 4 * t * (1 - t)
        pts.append((x, y))
    d.line(pts, fill=INK, width=w, joint="curve")
    for x, y in (pts[0], pts[-1]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=INK)


def _shine(d, x, y, r):
    d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 255))


def _open_mouth(im, S, box, tongue=True, teeth=True, flat_top=True):
    """A big open "D" mouth: dark inside, teeth along the top, tongue at the bottom."""
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    w, h = x1 - x0, y1 - y0
    if flat_top:
        ld.chord((x0, y0 - h, x1, y1), 0, 180, fill=(70, 16, 30, 255))
    else:
        ld.ellipse((x0, y0, x1, y1), fill=(70, 16, 30, 255))
    mask = layer.getchannel("A")
    if teeth:
        t = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(t).rectangle((x0, y0, x1, y0 + h * 0.24), fill=(255, 255, 255, 255))
        layer.alpha_composite(Image.composite(t, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))
    if tongue:
        t = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(t).ellipse((x0 + w * 0.2, y1 - h * 0.5, x1 - w * 0.2, y1 + h * 0.4), fill=(240, 92, 120, 255))
        layer.alpha_composite(Image.composite(t, Image.new("RGBA", (S, S), (0, 0, 0, 0)), mask))
    # Ink outline round the whole mouth.
    ring = mask.filter(ImageFilter.MaxFilter(int(S * 0.012) * 2 + 1))
    outline = Image.new("RGBA", (S, S), INK)
    outline.putalpha(ring)
    im.alpha_composite(outline)
    im.alpha_composite(layer)


def draw_face(kind, S=2048):
    """Draw a face. Returns an RGBA picture; the middle of it is the middle of the head front."""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ex, ey = 0.165 * S, 0.47 * S  # eye offset from the centre, eye height
    cx = S / 2
    if kind == "smug":
        # Half-shut eyes, one eyebrow up, a sideways smirk.
        for sx in (-1, 1):
            x = cx + sx * ex
            eye = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(eye).ellipse((x - 0.052 * S, ey - 0.07 * S, x + 0.052 * S, ey + 0.07 * S), fill=INK)
            lid = ey - 0.005 * S + sx * 0.012 * S
            ImageDraw.Draw(eye).rectangle((0, 0, S, lid), fill=(0, 0, 0, 0))
            im.alpha_composite(eye)
            _shine(d, x + 0.018 * S, lid + 0.022 * S, 0.012 * S)
        _brow(d, cx - ex - 0.07 * S, ey - 0.13 * S, cx - ex + 0.065 * S, ey - 0.155 * S, int(0.032 * S), arch=0.03 * S)
        _brow(d, cx + ex - 0.065 * S, ey - 0.085 * S, cx + ex + 0.07 * S, ey - 0.095 * S, int(0.032 * S), arch=0.005 * S)
        pts = []
        for i in range(33):
            t = i / 32
            pts.append((cx - 0.12 * S + 0.27 * S * t, 0.69 * S + 0.03 * S * math.sin(math.pi * t * 0.85) - 0.07 * S * t ** 3))
        d.line(pts, fill=INK, width=int(0.03 * S), joint="curve")
        for x, y in (pts[0], pts[-1]):
            r = 0.015 * S
            d.ellipse((x - r, y - r, x + r, y + r), fill=INK)
    elif kind == "shocked":
        for sx in (-1, 1):
            x = cx + sx * ex
            r = 0.075 * S
            d.ellipse((x - r, ey - r * 1.15, x + r, ey + r * 1.15), fill=INK)
            r2 = r - 0.016 * S
            d.ellipse((x - r2, ey - r2 * 1.15, x + r2, ey + r2 * 1.15), fill=(255, 255, 255, 255))
            p = 0.03 * S
            d.ellipse((x - p, ey - p, x + p, ey + p), fill=INK)
            _shine(d, x + 0.01 * S, ey - 0.012 * S, 0.009 * S)
            _brow(d, x - 0.07 * S, ey - 0.15 * S + sx * 0.0, x + 0.07 * S, ey - 0.16 * S, int(0.03 * S), arch=0.03 * S)
        _open_mouth(im, S, (cx - 0.075 * S, 0.65 * S, cx + 0.075 * S, 0.78 * S), teeth=False, flat_top=False)
    elif kind == "starstruck":
        for sx in (-1, 1):
            x = cx + sx * ex
            outer = 0.1 * S
            d.polygon(_star_points(x, ey + 0.005 * S, outer + 0.02 * S, (outer + 0.02 * S) * 0.5), fill=INK)
            d.polygon(_star_points(x, ey + 0.005 * S, outer, outer * 0.48), fill=(255, 204, 38, 255))
            d.polygon(_star_points(x - 0.012 * S, ey - 0.005 * S, outer * 0.45, outer * 0.22), fill=(255, 241, 150, 255))
            _shine(d, x - 0.03 * S, ey - 0.035 * S, 0.016 * S)
            _brow(d, x - 0.065 * S, ey - 0.165 * S, x + 0.065 * S, ey - 0.165 * S, int(0.028 * S), arch=0.035 * S)
            bx = cx + sx * 0.25 * S
            d.ellipse((bx - 0.05 * S, 0.615 * S, bx + 0.05 * S, 0.655 * S), fill=(255, 140, 160, 150))
        _open_mouth(im, S, (cx - 0.15 * S, 0.63 * S, cx + 0.15 * S, 0.77 * S))
    elif kind == "grin":
        # Superstar: shades and a big toothy grin.
        for sx in (-1, 1):
            x = cx + sx * 0.15 * S
            lens = [(x - 0.11 * S, ey - 0.07 * S), (x + 0.11 * S, ey - 0.07 * S), (x + 0.09 * S, ey + 0.06 * S),
                    (x - 0.08 * S, ey + 0.065 * S)]
            d.polygon(lens, fill=INK)
            d.polygon([(x - 0.07 * S, ey - 0.045 * S), (x - 0.03 * S, ey - 0.045 * S), (x - 0.075 * S, ey + 0.03 * S),
                       (x - 0.095 * S, ey + 0.0 * S)], fill=(255, 255, 255, 200))
        d.rectangle((cx - 0.1 * S, ey - 0.07 * S, cx + 0.1 * S, ey - 0.04 * S), fill=INK)
        _brow(d, cx - 0.25 * S, ey - 0.13 * S, cx - 0.08 * S, ey - 0.14 * S, int(0.03 * S), arch=0.02 * S)
        _brow(d, cx + 0.08 * S, ey - 0.15 * S, cx + 0.25 * S, ey - 0.17 * S, int(0.03 * S), arch=0.02 * S)
        _open_mouth(im, S, (cx - 0.14 * S, 0.65 * S, cx + 0.14 * S, 0.76 * S), tongue=False)
    else:
        raise ValueError(kind)
    return im.resize((S // 2, S // 2), Image.LANCZOS)


def face_image(kind):
    path = os.path.join(kit.OUT, "faces", f"{kind}.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    draw_face(kind).save(path)
    return bpy.data.images.load(path, check_existing=True)


def head_material(kind, skin=SKIN, span=FACE_SPAN):
    """Skin with the face painted on the front (object space: front is -Y, up is +Z)."""
    mat = bpy.data.materials.new(f"Head_{kind}")  # `span`: smaller makes the face bigger
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.42
    bsdf.inputs["Coat Weight"].default_value = 0.25
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    u = nt.nodes.new("ShaderNodeMath")
    u.operation = "MULTIPLY_ADD"
    # Seen from the front (camera on -Y), +X is on the viewer's right, so the picture runs with +X.
    u.inputs[1].default_value = 1 / span
    u.inputs[2].default_value = 0.5
    nt.links.new(sep.outputs["X"], u.inputs[0])
    v = nt.nodes.new("ShaderNodeMath")
    v.operation = "MULTIPLY_ADD"
    v.inputs[1].default_value = 1 / span
    v.inputs[2].default_value = 0.5
    nt.links.new(sep.outputs["Z"], v.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(u.outputs[0], comb.inputs["X"])
    nt.links.new(v.outputs[0], comb.inputs["Y"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = face_image(kind)
    tex.extension = "CLIP"
    tex.interpolation = "Cubic"
    nt.links.new(comb.outputs[0], tex.inputs["Vector"])
    # Only on the front: fade out as the surface turns away from -Y.
    sepn = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Normal"], sepn.inputs[0])
    front = nt.nodes.new("ShaderNodeMapRange")
    front.inputs["From Min"].default_value = -0.15
    front.inputs["From Max"].default_value = -0.35
    nt.links.new(sepn.outputs["Y"], front.inputs["Value"])
    amt = nt.nodes.new("ShaderNodeMath")
    amt.operation = "MULTIPLY"
    nt.links.new(tex.outputs["Alpha"], amt.inputs[0])
    nt.links.new(front.outputs["Result"], amt.inputs[1])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = (*kit.hex_rgb(skin), 1)
    nt.links.new(amt.outputs[0], mix.inputs["Factor"])
    nt.links.new(tex.outputs["Color"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    mat.diffuse_color = (*kit.hex_rgb(skin), 1)
    return mat


# ---------------------------------------------------------------------------------------------
# Body


def _box(name, size, at, mat, bevel=0.09, parent=None, rot=(0, 0, 0)):
    obj = kit.primitive("cube", name, at, size, mat, rotation=rot)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = min(bevel, min(size) * 0.45)
    mod.segments = 4
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.set_sharp_from_angle(angle=math.radians(80))
    if parent is not None:
        kit._child(obj, parent)
        obj.location = Vector(at)
        obj.rotation_euler = tuple(math.radians(r) for r in rot)
    return obj


def _head(name, kind, parent, skin, span=FACE_SPAN):
    """Round Roblox head: a short cylinder with soft rims, face painted on the front."""
    w, dpt, h = HEAD
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.5, depth=1.0)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.transform(Matrix.Diagonal((w, dpt, h, 1)))
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = 0.3
    mod.segments = 8
    mod.limit_method = "ANGLE"
    for p in obj.data.polygons:
        p.use_smooth = True
    obj.data.materials.append(head_material(kind, skin, span))
    kit._child(obj, parent)
    obj.location = (0, 0, 0)
    return obj


def hair_material(color):
    """Glossy brown with faint strands running front to back."""
    mat = bpy.data.materials.new("Hair")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.45
    bsdf.inputs["Coat Weight"].default_value = 0.2
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = 3.5
    wave.inputs["Distortion"].default_value = 5.0
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*(c * 0.6 for c in kit.hex_rgb(color)), 1)
    ramp.color_ramp.elements[1].color = (*kit.hex_rgb(color), 1)
    ramp.color_ramp.elements[0].position = 0.35
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.05
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def meta_hair(name, parent, elems, color="#C8692C", res=0.04):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = res
    mb.render_resolution = res
    mb.threshold = 0.6
    for (kind, co, radius, size, rot) in elems:
        e = mb.elements.new()
        e.type = kind
        e.co = co
        e.radius = 1.0
        e.size_x, e.size_y, e.size_z = (v / 0.574 for v in size)  # size is the half-extent we see
        e.rotation = Euler(tuple(math.radians(r) for r in rot)).to_quaternion()
        e.stiffness = 2.0
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(obj)
    m = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(m)
    mesh.shade_smooth()
    mesh.materials.append(hair_material(color))
    return m

HAIR = [
    # (centre, visible half-size, rotation) for each blob of the hair, in head space (front is -Y).
    ((0, 0.08, 0.4), (0.84, 0.78, 0.38), (0, 0, 0)),  # crown
    ((0, 0.32, 0.0), (0.82, 0.46, 0.66), (0, 0, 0)),  # back
    ((-0.74, 0.08, 0.06), (0.15, 0.56, 0.48), (0, 0, 0)),  # sides
    ((0.74, 0.08, 0.06), (0.15, 0.56, 0.48), (0, 0, 0)),
    ((-0.7, -0.22, -0.32), (0.12, 0.2, 0.3), (-20, 0, 18)),  # lock tips by the cheeks
    ((0.72, -0.18, -0.3), (0.12, 0.2, 0.3), (-20, 0, -18)),
    ((-0.18, -0.6, 0.6), (0.7, 0.15, 0.18), (0, -12, 0)),  # the fringe swoop
    ((0.4, -0.64, 0.45), (0.34, 0.13, 0.16), (0, -36, 0)),  # and its tip over one brow
]


def bacon_hair(parent, color="#C8692C"):
    """The bacon hair: soft blobs melted together (metaballs) into one mop with a side swoop."""
    mb = bpy.data.metaballs.new("Hair")
    mb.resolution = mb.render_resolution = 0.04
    mb.threshold = 0.6
    for co, half, rot in HAIR:
        e = mb.elements.new()
        e.type = "ELLIPSOID"
        e.co = co
        e.radius = 1.0
        e.stiffness = 2.0
        # With this threshold and stiffness a blob shows about 0.574 of its size.
        e.size_x, e.size_y, e.size_z = (v / 0.574 for v in half)
        e.rotation = Euler(tuple(math.radians(r) for r in rot)).to_quaternion()
    tmp = bpy.data.objects.new("HairMeta", mb)
    bpy.context.scene.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    mesh = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    mesh.shade_smooth()
    mesh.materials.append(hair_material(color))
    obj = bpy.data.objects.new("Hair", mesh)
    bpy.context.scene.collection.objects.link(obj)
    kit._child(obj, parent)
    obj.location = (0, 0, 0)
    return obj


def beret(parent, color="#C8102E"):
    """A director's beret, tipped to one side, with a little stalk on top."""
    m = kit.material(color, "Fabric")
    w, dpt, h = HEAD
    root = kit._empty("Beret", (0, 0, 0))
    kit._child(root, parent)
    root.location = (0.12, 0.02, h / 2 + 0.08)
    root.rotation_euler = (math.radians(-8), math.radians(14), 0)
    disc = kit.primitive("sphere", "BeretTop", (0, 0, 0), (w + 0.55, dpt + 0.5, 0.5), m, segments=48)
    kit._child(disc, root)
    disc.location = (0, 0, 0.12)
    band = kit.primitive("torus", "BeretBand", (0, 0, 0), (w + 0.2, dpt + 0.15, 0.2), kit.material("#8E0B20", "Fabric"), segments=48)
    kit._child(band, root)
    band.location = (0, 0, -0.04)
    stalk = kit.primitive("cylinder", "BeretStalk", (0, 0, 0), (0.1, 0.1, 0.22), m)
    kit._child(stalk, root)
    stalk.location = (0, 0, 0.42)


OUTFITS = {
    # Black jacket over a blue tee with a gold star, dark green trousers, white trainers.
    "bacon": dict(jacket="#1F1F26", shirt="#2F8CFF", pants="#2F4A36", shoes="#FFFFFF", star="#FFD23F"),
    # The superstar: a gold jacket over a hot-pink tee, purple trousers.
    "star": dict(jacket="#FFC21A", shirt="#FF4FA8", pants="#6A3BD9", shoes="#FFFFFF", star="#FFFFFF"),
}


def avatar(name, location, yaw=0.0, face="smug", outfit="bacon", pose=None, hair=True, hat=None, skin=SKIN,
           jacket_mat=None, scale=1.0, head_scale=1.0, legs=True, face_span=FACE_SPAN):
    """Build the player. `pose` angles are (x, y, z) degrees at each joint:
    arm_r / arm_l at the shoulders (x < 0 swings the arm forward and up), leg_r / leg_l at the hips,
    head at the neck, body for the whole figure's lean. The player's right is the viewer's left.
    `head_scale` makes the head (and hair and hat) bigger, as close-up art often does; `legs=False`
    leaves the legs off for a player peeking out from behind something.
    Returns {"root", "head", "objects"}."""
    pose = pose or {}
    o = OUTFITS[outfit]
    rad = lambda a: tuple(math.radians(x) for x in a)  # noqa: E731
    with kit.collect() as made:
        root = kit._empty(name, location, (0, 0, yaw), scale)
        body = kit._empty(f"{name}_Body", (0, 0, 0))
        kit._child(body, root)
        body.rotation_euler = rad(pose.get("body", (0, 0, 0)))
        jacket = jacket_mat or kit.material(o["jacket"])
        shirt = kit.material(o["shirt"])
        skin_m = kit.material(skin)
        _box("Torso", (2.0, 1.0, 2.0), (0, 0, 3.0), jacket, parent=body)
        _box("Shirt", (0.92, 0.1, 1.94), (0, -0.48, 2.99), shirt, bevel=0.03, parent=body)
        star = kit.add_object("ShirtStar", kit.star_mesh("ShirtStar", 0.32, 0.15, 0.06), kit.material(o["star"], emission=0.15), (0, -0.55, 3.3))
        kit._child(star, body)
        star.location = (0, -0.55, 3.25)
        for side, key, x in ((-1, "arm_r", -1.5), (1, "arm_l", 1.5)):
            joint = kit._empty(f"{name}_{key}", (0, 0, 0))
            kit._child(joint, body)
            joint.location = (x, 0, 3.55)
            joint.rotation_euler = rad(pose.get(key, (0, 0, 0)))
            _box("Sleeve", (1.0, 1.0, 1.55), (0, 0, -0.22), jacket, parent=joint)
            _box("Hand", (0.96, 0.96, 0.5), (0, 0, -1.25), skin_m, parent=joint)
        pants, shoes = kit.material(o["pants"]), kit.material(o["shoes"])
        for key, x in (("leg_r", -0.5), ("leg_l", 0.5)) if legs else ():
            joint = kit._empty(f"{name}_{key}", (0, 0, 0))
            kit._child(joint, body)
            joint.location = (x, 0, 2.0)
            joint.rotation_euler = rad(pose.get(key, (0, 0, 0)))
            _box("Leg", (0.99, 1.0, 1.66), (0, 0, -0.83), pants, parent=joint)
            _box("Shoe", (1.02, 1.08, 0.4), (0, -0.03, -1.8), shoes, bevel=0.12, parent=joint)
        neck = kit._empty(f"{name}_Neck", (0, 0, 0))
        kit._child(neck, body)
        neck.location = (0, 0, HEAD_Z)
        neck.rotation_euler = rad(pose.get("head", (0, 0, 0)))
        neck.scale = (head_scale,) * 3
        head = _head("Head", face, neck, skin, face_span)
        if hair:
            bacon_hair(neck, **(hair if isinstance(hair, dict) else {}))
        if hat == "beret":
            beret(neck)
    return {"root": root, "head": head, "neck": neck, "objects": made.objects}
