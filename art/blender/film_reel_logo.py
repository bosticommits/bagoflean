"""FilmReelLogo: gold film reel on a stand, the studio logo on top of the office tower.

About 7.5 studs tall, reel face toward the front (-Y). In Studio, name the MeshPart
"FilmReelLogo".
"""

import math
import os
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mmkit  # noqa: E402



def build():
    m = mmkit.Model("FilmReelLogo")
    gold = m.mat("Gold", metallic=0.5, roughness=0.35)
    navy = m.mat("Navy")
    red = m.mat("Burgundy")
    dark = m.mat("Charcoal", metallic=0.3)

    # Stand: a stepped plinth and a post.
    m.box((2.4, 1.6, 0.5), at=(0, 0, 0.25), mat=red)
    m.box((1.0, 0.8, 1.6), at=(0, 0, 1.3), mat=dark, taper=0.7)
    centre_z = 4.6
    radius = 2.9
    # Reel disc and hub.
    m.cylinder(radius, 0.6, at=(0, 0, centre_z), mat=gold, segments=20, axis="Y")
    m.cylinder(0.7, 0.9, at=(0, 0, centre_z), mat=red, segments=10, axis="Y")
    # Five "holes": navy discs set into both faces.
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        x, z = 1.75 * math.cos(a), centre_z + 1.75 * math.sin(a)
        m.cylinder(0.7, 0.72, at=(x, 0, z), mat=navy, segments=10, axis="Y")
    # A strip of film unspooling down the side.
    for k in range(4):
        m.box((0.9, 0.12, 0.7), at=(radius + 0.2, -0.1, centre_z - 1.2 - k * 0.75), mat=dark)
        m.box((0.5, 0.14, 0.4), at=(radius + 0.2, -0.12, centre_z - 1.2 - k * 0.75), mat=navy)
    return m.obj()


mmkit.finish(build(), "film_reel_logo", max_tris=2000)
