"""Store icon: close-up of the shocked player with the Icon actor glowing behind.

Same scene as thumbnail.py with the player moved into a square close-up. Renders
$STORE_OUT/icon_scene.png (1024 x 1024); compose.py makes the 512 x 512 icon from it.
"""

import os
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import thumbnail  # noqa: E402

if __name__ == "__main__":
    thumbnail.PLAYER_AT = Vector((-0.95, -19.7, thumbnail.GROUND))
    thumbnail.build(1024, 1024, camera_at=Vector((0.0, -26.0, 4.6)), look_at=Vector((1.0, -14.0, 7.6)), lens=35, samples=192)
    kit.render(os.path.join(kit.OUT, "icon_scene.png"))
