"""Store thumbnail: a player pulls an Icon actor (1 in 1,000,000) on a max-level studio lot.

Renders $STORE_OUT/thumbnail_scene.png (1920 x 1080, no words). compose.py adds the words.
The hero is The Mogul's Muse and the lot is LotLook at max progress, both straight from the
game's model code, so the art shows what players can really get.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

GROUND = 1.1  # top of the lot's yard
HERO_AT = Vector((4.2, -10.5, 1.2))  # pedestal base, on the red carpet
HERO_SCALE = 1.85
PLAYER_AT = Vector((-4.2, -18.5, GROUND))
CAMERA_AT = Vector((-2.0, -29.0, 3.0))  # low, looking up at the pull
LOOK_AT = Vector((1.5, -6.0, 11.0))
RAINBOW = ["#FF5FD2", "#FFC21A", "#3A8DFF", "#4CC764", "#A04DFF", "#FF5A2E"]

CLUTTER = ("SearchlightBeam", "ClaimPad", "CollectPad", "Lamp", "Trophy", "Case", "Blade")


def lot():
    parts = kit.dump("lotMax")

    def keep(p):
        x, y, z = p["cframe"][0:3]
        if 4.5 < x < 12.5 and -6.5 < z < 0.5 and y < 13:  # the lot's own star and its pedestal
            return False
        if p["name"] in ("Stanchion", "StanchionTop", "Rope") and -16 < z < -4:  # room for the pedestal
            return False
        if x < -13:  # the sound stages and office on the right edge of the frame
            return False
        return not p["name"].startswith(CLUTTER)

    kit.import_parts([p for p in parts if keep(p)], "Lot")
    # Grass beyond the lot, out to the horizon.
    kit.primitive("cube", "Land", (0, 0, 0.45), (900, 900, 0.9), kit.material("#4FA84E", "Grass"))


def hero():
    base = HERO_AT
    burgundy, cream, gold = kit.material("#7A1F2B"), kit.material("#F4E7CF"), kit.material("#F5B82E", "Metal")
    kit.primitive("cylinder", "PedestalBase", base + Vector((0, 0, 0.45)), (6.4, 6.4, 0.9), burgundy, bevel=0.12, segments=64)
    kit.primitive("cylinder", "PedestalGlow", base + Vector((0, 0, 1.0)), (6.1, 6.1, 0.22), kit.material("#FF5FD2", "Neon", emission=5.0), segments=64)
    kit.primitive("cylinder", "PedestalTop", base + Vector((0, 0, 1.35)), (5.8, 5.8, 0.5), cream, bevel=0.1, segments=64)
    kit.primitive("torus", "PedestalTrim", base + Vector((0, 0, 1.6)), (5.9, 5.9, 0.22), gold, segments=64)
    top = base + Vector((0, 0, 1.6))
    kit.import_parts(kit.dump("actor", "MogulsMuse:Normal"), "Muse", location=top, yaw=-12, scale=HERO_SCALE, bevel=0.06)
    return top, top + Vector((0, 0, 3.6 * HERO_SCALE))


def hero_lights(top, centre):
    kit.light("POINT", top + Vector((0, -4.5, 5)), 1500, "#FF7AD9", size=3, name="HeroGlow")
    # Two-tone rim lights from behind outline her against the sky.
    kit.light("AREA", top + Vector((6, 7, 10)), 22000, "#FFB8EC", target=centre + Vector((0, 0, 2)), size=5, name="HeroRimR")
    kit.light("AREA", top + Vector((-6, 7, 8)), 16000, "#8FE3FF", target=centre + Vector((0, 0, 2)), size=5, name="HeroRimL")
    # A soft glow behind her upper body.
    kit.glow_disc("HeroAura", centre + Vector((0, 4.0, 4.0)), 9, "#FFF0C8", strength=2.2, facing=bpy.context.scene.camera.location, power=3.0)


def burst(centre):
    """A soft rainbow burst behind the hero (Icon is the rainbow tier)."""
    at = centre + Vector((0, 5.0, 1.5))
    to_cam = (bpy.context.scene.camera.location - at).normalized()
    right = to_cam.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(to_cam).normalized()
    rays = 12
    colors = ["#FFE7A0", "#FF8FE0", "#FFFFFF"]
    for i in range(rays):
        a = 2 * math.pi * (i + 0.25) / rays
        d = right * math.cos(a) + up * math.sin(a)
        kit.beam(f"Ray{i}", at, at + d * 32, 0.2, 3.4, colors[i % len(colors)], strength=0.3)


def player():
    parts = kit.player(look=(-0.09, 0.08), arms=((150, 14), (140, 18)), head_turn=16, head_tilt=8, lean=4, roll=-3)
    kit.import_parts(parts, "Player", location=PLAYER_AT, yaw=24, scale=1.0, bevel=0.06)


def player_lights():
    kit.light("AREA", PLAYER_AT + Vector((-6, 5, 8)), 2200, "#7FD4FF", target=PLAYER_AT + Vector((0, 0, 4.5)), size=4, name="PlayerRim")


def searchlights():
    for sx in (-1, 1):
        lens = Vector((sx * 9.7, 17.9, 21.9))
        kit.beam(f"Search{sx}", lens, lens + Vector((-sx * 34, 50, 120)), 0.75, 5, "#FFF1C9", strength=0.7)
    for i, (x, y, tx) in enumerate([(-55, 80, 30), (60, 90, -40), (-110, 150, 40), (120, 160, -60)]):
        base = Vector((x, y, 0))
        kit.beam(f"FarSearch{i}", base, base + Vector((tx, 40, 160)), 1.2, 7, "#FFE6F6", strength=0.4)


def loot(centre):
    rnd = random.Random(7)
    # Coins and cash bursting out of the pull, a couple flying right past the camera.
    head = centre + Vector((0, 0, 5.0))
    placed = 0
    while placed < 14:
        a = rnd.uniform(-0.35, math.pi + 0.35)  # above and beside her, not in front of the pedestal
        r = rnd.uniform(6.5, 10)
        at = centre + Vector((math.cos(a) * r * 1.1, rnd.uniform(-5, 1), math.sin(a) * r * 0.75))
        if (at - head).length < 5.5:  # keep her face and halo clear
            continue
        i = placed
        placed += 1
        rot = (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360))
        if i % 4 == 3:
            kit.cash(f"Cash{i}", at, rot, length=rnd.uniform(1.8, 2.3))
        else:
            kit.coin(f"Coin{i}", at, rot, radius=rnd.uniform(0.7, 0.95))
    for i, at in enumerate([(-7.2, -22.5, 2.2)]):
        kit.coin(f"NearCoin{i}", at, (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)), radius=0.42)
    stars = []
    while len(stars) < 5:
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(8, 10)
        at = centre + Vector((math.cos(a) * r, rnd.uniform(-2, 1), math.sin(a) * r * 0.8))
        if (at - head).length > 5.5:
            stars.append(at)
    for i, at in enumerate(stars):
        kit.gold_star(f"Star{i}", at, (rnd.uniform(-30, 30), rnd.uniform(-20, 20), rnd.uniform(-30, 30)), size=rnd.uniform(0.7, 1.0), color="#FFD23F", emission=0.5)
    cam = bpy.context.scene.camera
    for i in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(3, 9)
        at = centre + Vector((math.cos(a) * r, rnd.uniform(-4, 0), math.sin(a) * r))
        kit.sparkle(f"Sparkle{i}", at, size=rnd.uniform(0.35, 0.75), color=rnd.choice(["#FFFFFF", "#FFE9A8", "#FFC8F0"]), strength=12, face=cam)
    kit.confetti(26, centre + Vector((0, -3, 3)), (13, 5, 8), RAINBOW[:4] + ["#FFFFFF"], seed=3, size=(0.5, 0.12, 0.8), emission=0.4)


def build(width=1920, height=1080, camera_at=CAMERA_AT, look_at=LOOK_AT, lens=28, samples=160):
    kit.new_scene(width, height, samples=samples)
    kit.sky(top="#0F1F66", middle="#2C56D6", horizon="#FF86B0", glow="#FFB36B", strength=1.1, light_strength=0.5)
    kit.camera(camera_at, look_at, lens=lens)
    lot()
    with kit.collect() as hero_objects:
        top, centre = hero()
    with kit.collect() as player_objects:
        player()
    with kit.collect() as loot_objects:
        loot(centre)
    hero_lights(top, centre)
    player_lights()
    burst(centre)
    searchlights()
    # Warm key lights just for the subjects, and a dim one for the whole lot, so the hero and
    # the player pop off a dusky background. The hero gets less, so her pinks stay pink.
    key = kit.light("SUN", (0, 0, 50), 2.2, "#FFE2BD", target=(10, 24, 26), angle=3, name="Key")
    kit.light_only(key, player_objects.objects + loot_objects.objects)
    hero_key = kit.light("SUN", (0, 0, 50), 1.5, "#FFE2BD", target=(10, 24, 26), angle=3, name="HeroKey")
    kit.light_only(hero_key, hero_objects.objects)
    kit.light("SUN", (0, 0, 50), 0.45, "#FFC7A8", target=(14, 30, 24), angle=3, name="Ambient")
    kit.glare(threshold=1.0, size=8, mix=-0.55)


if __name__ == "__main__":
    build()
    if os.environ.get("STORE_VIEW"):
        view, _, look = os.environ["STORE_VIEW"].partition("|")
        bpy.context.scene.view_settings.view_transform = view
        bpy.context.scene.view_settings.look = look or "None"
    kit.render(os.path.join(kit.OUT, "thumbnail_scene.png"))
