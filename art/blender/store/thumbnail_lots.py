"""Second store thumbnail: the same lot on day one and fully upgraded ("noob to mogul").

Renders, into $STORE_OUT:
  lots_before.png, lots_after.png    the lot from the same camera (1300 x 1080 each)
  player_sad.png, player_cool.png    the player on a transparent background (1000 x 1000)
compose.py lays them side by side with the words. Both lots are LotLook from the game
(art/preview/scenes.luau lotStarter and lotMax), so the glow-up is what players build.
"""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

LOT_CAMERA = (Vector((-40.0, -62.0, 28.0)), Vector((3.0, -2.0, 4.0)), 27)
LOT_SHIFT = (0.0, 0.07)  # moves the lot down a little, under the words


def land(color):
    kit.primitive("cube", "Land", (0, 0, 0.45), (900, 900, 0.9), kit.material(color, "Grass"))


def lot_before():
    kit.new_scene(1300, 1080, samples=128)
    kit.sky(top="#7F93AE", middle="#A9B6C6", horizon="#D3D8DE", glow="#E2E2E2", strength=1.0, light_strength=0.9)
    kit.camera(*LOT_CAMERA[:2], lens=LOT_CAMERA[2], shift=LOT_SHIFT)
    kit.import_parts(kit.dump("lotStarter"), "Lot")
    land("#6E9C63")
    kit.light("SUN", (0, 0, 50), 1.5, "#E8EEF8", target=(14, 18, 4), angle=12, name="Sun")
    kit.glare(threshold=1.4, size=6, mix=-0.8)


def lot_after():
    kit.new_scene(1300, 1080, samples=128)
    kit.sky(top="#1B2C86", middle="#4E5BE0", horizon="#FF8A9E", glow="#FFC46B", strength=1.1, light_strength=0.6)
    kit.camera(*LOT_CAMERA[:2], lens=LOT_CAMERA[2], shift=LOT_SHIFT)
    kit.import_parts([p for p in kit.dump("lotMax") if p["name"] != "SearchlightBeam"], "Lot")
    land("#4FA84E")
    for sx in (-1, 1):
        lens = Vector((sx * 9.7, 17.9, 21.9))
        kit.beam(f"Search{sx}", lens, lens + Vector((-sx * 30, 40, 120)), 0.75, 6, "#FFF1C9", strength=1.0)
    rnd = random.Random(5)
    for i in range(24):
        at = Vector((rnd.uniform(-24, 24), rnd.uniform(-30, 10), rnd.uniform(14, 36)))
        rot = (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360))
        if i % 2:
            kit.cash(f"Cash{i}", at, rot, length=3.6)
        else:
            kit.coin(f"Coin{i}", at, rot, radius=1.6)
    kit.light("SUN", (0, 0, 50), 2.0, "#FFD9B0", target=(14, 18, 4), angle=3, name="Sun")
    kit.glare(threshold=1.0, size=8, mix=-0.55)


def player_alone(expression, arms, head_turn, head_tilt, lean, roll, rim):
    kit.new_scene(1000, 1000, samples=128, transparent=True)
    kit.sky(top="#C9D6F2", middle="#A8B4D0", horizon="#7A7F98", glow="#4A4E66", strength=0.8)
    parts = kit.player(expression=expression, arms=arms, head_turn=head_turn, head_tilt=head_tilt, lean=lean, roll=roll)
    kit.import_parts(parts, "Player", yaw=18)
    kit.camera((3.2, -12.5, 5.0), (0.15, 0, 4.3), lens=50)
    kit.light("AREA", (-5, -8, 9), 1500, "#FFF1E2", target=(0, 0, 4.5), size=6, name="Key")
    kit.light("AREA", (6, -6, 3), 380, "#DDE6FF", target=(0, 0, 4), size=6, name="Fill")
    kit.light("AREA", (-4, 6, 7), 2600, rim, target=(0, 0, 4.5), size=4, name="RimL")
    kit.light("AREA", (5, 5, 6), 2000, rim, target=(0, 0, 4.5), size=4, name="RimR")
    kit.glare(threshold=1.6, size=6, mix=-0.8)


if __name__ == "__main__":
    lot_before()
    kit.render(os.path.join(kit.OUT, "lots_before.png"))
    lot_after()
    kit.render(os.path.join(kit.OUT, "lots_after.png"))
    player_alone("sad", arms=((6, 3), (6, 3)), head_turn=0, head_tilt=-9, lean=-4, roll=2, rim="#9FB7D6")
    kit.render(os.path.join(kit.OUT, "player_sad.png"))
    player_alone("cool", arms=((155, 24), (30, 10)), head_turn=-4, head_tilt=4, lean=3, roll=-3, rim="#FF9BE6")
    kit.render(os.path.join(kit.OUT, "player_cool.png"))
