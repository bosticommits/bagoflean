"""Store thumbnail A, Roblox front-page style: a smug bacon-hair player shows off a towering
studio full of glowing actors. compose.py adds "99 SUPERSTARS" and a rainbow "$1,000,000/s".

Renders $STORE_OUT/tower_scene.png (1920 x 1080, no words). Bright sky, green grass, and the
game's own actor models on every floor, rarest at the top.
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

TOWER_X, TOWER_W, TOWER_D = 9.6, 16.5, 6.0
FLOOR_H = 4.6
PLAYER_AT = Vector((-9.5, -8.5, 0))
FLOORS = [
    # Bottom to top: rarer actors higher up, each with its tier colour glowing behind it.
    [("NervousIntern", "#C9CED6"), ("StuntDouble", "#C9CED6"), ("SoapRegular", "#4CC764"), ("AdModel", "#4CC764")],
    [("ActionVeteran", "#3A8DFF"), ("ComedyDuo", "#3A8DFF"), ("TeenHeartthrob", "#A04DFF"), ("SpaceCaptain", "#A04DFF")],
    [("BoxOfficeKing", "#FFC21A"), ("ScreamQueen", "#FFC21A"), ("GoldenAgeDiva", "#FF5A2E"), ("SciFiVisionary", "#FF5A2E")],
    [("MogulsMuse", "#FF5FD2"), ("LastActionHero", "#FF5FD2"), ("PhantomAuteur", "#FF5FD2"), ("SilentEraClown", "#FF5A2E")],
]


def curtain(name, x0, x1, y, z0, z1, color="#C8102E"):
    """Red stage curtain: a row of fat folds."""
    mat = kit.material(color, "Fabric")
    n = int((x1 - x0) / 0.7)
    for i in range(n):
        x = x0 + (i + 0.5) * (x1 - x0) / n
        kit.primitive("cylinder", f"{name}{i}", (x, y, (z0 + z1) / 2), (0.62, 0.42, z1 - z0), mat, segments=16)


def tower():
    x0, x1 = TOWER_X - TOWER_W / 2, TOWER_X + TOWER_W / 2
    wood, wood_dark = kit.material("#9A5530"), kit.material("#6E3A1F")
    carpet = kit.material("#D81F3C", "Fabric")
    gold = kit.material("#F5B82E", "Metal")
    bulb = kit.material("#FFE9A6", "Neon", emission=6.0)
    rnd = random.Random(4)
    actors = []
    for f, row in enumerate(FLOORS):
        z = f * FLOOR_H
        kit.primitive("cube", f"Slab{f}", (TOWER_X, 0, z + 0.3), (TOWER_W + 0.6, TOWER_D + 0.6, 0.6), wood, bevel=0.08)
        kit.primitive("cube", f"Carpet{f}", (TOWER_X, 0.2, z + 0.64), (TOWER_W - 0.6, TOWER_D - 1.0, 0.08), carpet)
        # Marquee bulbs along the front edge of every floor.
        for i in range(26):
            x = x0 + 0.2 + i * (TOWER_W - 0.4) / 25
            kit.primitive("sphere", f"Bulb{f}_{i}", (x, -TOWER_D / 2 - 0.32, z + 0.3), (0.26, 0.26, 0.26), bulb, segments=12)
        curtain(f"Curtain{f}_", x0 + 0.4, x1 - 0.4, TOWER_D / 2 - 0.4, z + 0.6, z + FLOOR_H)
        kit.primitive("cube", f"Valance{f}", (TOWER_X, TOWER_D / 2 - 0.55, z + FLOOR_H - 0.35), (TOWER_W - 0.6, 0.3, 0.6), kit.material("#A50D24", "Fabric"))
        for sx in (x0 + 0.3, x1 - 0.3):
            for sy in (-TOWER_D / 2 + 0.3, TOWER_D / 2 - 0.3):
                kit.primitive("cube", f"Post{f}", (sx, sy, z + FLOOR_H / 2 + 0.3), (0.6, 0.6, FLOOR_H), wood_dark, bevel=0.06)
        # A gold rail in front, low enough to see the actors over it.
        rail_z = z + 1.55
        kit.primitive("cube", f"Rail{f}", (TOWER_X, -TOWER_D / 2 + 0.25, rail_z), (TOWER_W - 0.6, 0.16, 0.16), gold, bevel=0.05)
        for i in range(13):
            x = x0 + 0.6 + i * (TOWER_W - 1.2) / 12
            kit.primitive("cylinder", f"Baluster{f}_{i}", (x, -TOWER_D / 2 + 0.25, z + 1.1), (0.12, 0.12, 0.9), gold)
        for i, (actor, glow) in enumerate(row):
            x = x0 + 2.0 + i * (TOWER_W - 4.0) / (len(row) - 1)
            at = Vector((x, 0.1, z + 0.68))
            kit.primitive("cylinder", f"Pad{f}_{i}", at + Vector((0, 0, 0.06)), (2.3, 2.3, 0.14), kit.material(glow, "Neon", emission=4.0), segments=40)
            kit.import_parts(kit.dump("actor", f"{actor}:Normal"), f"Actor{f}_{i}", location=at + Vector((0, 0, 0.12)),
                             yaw=rnd.uniform(-20, 20), scale=0.5, bevel=0.05)
            kit.glow_disc(f"Aura{f}_{i}", at + Vector((0, 1.2, 1.7)), 2.0, glow, strength=2.5, facing=bpy.context.scene.camera.location, power=1.6)
            actors.append((at, glow))
    roof_z = len(FLOORS) * FLOOR_H
    kit.primitive("cube", "Roof", (TOWER_X, 0, roof_z + 0.35), (TOWER_W + 1.0, TOWER_D + 1.0, 0.7), wood, bevel=0.1)
    for i in range(28):
        x = x0 - 0.1 + i * (TOWER_W + 0.2) / 27
        kit.primitive("sphere", f"RoofBulb{i}", (x, -TOWER_D / 2 - 0.52, roof_z + 0.35), (0.3, 0.3, 0.3), bulb, segments=12)
    kit.gold_star("RoofStar", (TOWER_X, 0, roof_z + 3.0), (0, 0, 0), size=2.4, color="#FFD23F", emission=0.6)
    return actors


def clouds():
    white = kit.material("#FFFFFF", emission=0.35)
    rnd = random.Random(11)
    for c, (cx, cy, cz, s) in enumerate([(-30, 70, 4, 9), (-6, 85, 2, 8), (28, 70, 6, 10), (52, 90, 3, 9), (-52, 85, 6, 9)]):
        for i in range(8):
            at = (cx + rnd.uniform(-1.6, 1.6) * s, cy + rnd.uniform(-2, 2), cz + rnd.uniform(0, 0.7) * s)
            r = s * rnd.uniform(0.55, 0.95)
            o = kit.primitive("sphere", f"Cloud{c}_{i}", at, (r * 1.4, r, r), white, segments=24)
            o.visible_shadow = False


def loot():
    rnd = random.Random(5)
    for i in range(9):
        at = Vector((rnd.uniform(1, 18), rnd.uniform(-12, -5), rnd.uniform(9, 20)))
        rot = (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360))
        if i % 3 == 0:
            kit.cash(f"Cash{i}", at, rot, length=1.8)
        else:
            kit.coin(f"Coin{i}", at, rot, radius=0.7)


def build(width=1920, height=1080, samples=128):
    kit.new_scene(width, height, samples=samples)
    kit.sky(top="#1F7BFF", middle="#5DB4FF", horizon="#BFE6FF", glow="#E6F6FF", strength=1.0)
    cam = kit.camera((-7.0, -31, 6.0), (1.0, 0, 9.2), lens=26)
    ground = kit.primitive("cube", "Ground", (0, 0, -0.5), (600, 600, 1.0), kit.material("#4CC33A", "Grass"))
    ground.visible_diffuse = False  # no green bounce on the player's skin
    clouds()
    tower()
    loot()
    with kit.collect() as player:
        bacon.avatar("Player", PLAYER_AT, yaw=22, face="smug", scale=1.7, head_scale=1.15,
                     pose={"arm_r": (-160, 40, 0), "arm_l": (-12, -84, -8), "head": (4, 7, -6), "body": (0, 0, 0)})
    kit.light("SUN", (0, 0, 50), 3.2, "#FFF4E0", target=(14, 30, 0), angle=4, name="Sun")
    fill = kit.light("AREA", (-12, -30, 14), 3000, "#FFFFFF", target=PLAYER_AT + Vector((0, 0, 5)), size=10, name="PlayerFill")
    kit.light_only(fill, player.objects)
    kit.light("AREA", (7.6, -26, 12), 6000, "#FFF2DD", target=(7.6, 0, 8), size=18, name="TowerFill")
    rim = kit.light("AREA", (-16, 0, 14), 3000, "#BDE6FF", target=PLAYER_AT + Vector((0, 0, 6)), size=4, name="PlayerRim")
    kit.light_only(rim, player.objects)
    kit.glare(threshold=1.4, size=7, mix=-0.7)


if __name__ == "__main__":
    build()
    kit.render(os.path.join(kit.OUT, "tower_scene.png"))
