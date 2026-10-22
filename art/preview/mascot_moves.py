"""Renders the mascots' animations with their real Blender meshes, as an animated GIF.

  lune run art/preview/mascot_moves.luau /tmp/mascot_moves.json
  python -c "import bpy, runpy, sys; runpy.run_path(sys.argv[1], run_name='__main__')" \\
      art/preview/mascot_moves.py /tmp/mascot_moves.json art/previews/mascot_moves.gif

The JSON holds every piece's transform per frame, worked out by the game's own MascotRig code
(see mascot_moves.luau), so the GIF shows what players will see, minus particles and lights.
Set MOVES_SAMPLES, MOVES_STEP (render every Nth frame) and MOVES_SIZE (e.g. 960x384) for speed.
"""

import json
import math
import os
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import mascots  # noqa: E402
import mmkit  # noqa: E402

STUD = mmkit.STUD
P = mascots.TO_ROBLOX.to_4x4()
TO_METRES = Matrix.Scale(STUD, 4) @ P
FROM_METRES = P @ Matrix.Scale(1 / STUD, 4)


def roblox_matrix(m):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = m
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def main():
    data_path, out_path = sys.argv[-2], sys.argv[-1]
    with open(data_path) as f:
        frames = json.load(f)
    samples = int(os.environ.get("MOVES_SAMPLES", "8"))
    every = int(os.environ.get("MOVES_STEP", "2"))
    width, height = (int(v) for v in os.environ.get("MOVES_SIZE", "1100x420").split("x"))
    mascots.SAMPLES = samples

    bpy.ops.wm.read_factory_settings(use_empty=True)
    placed = []  # (mascot id, {piece name: object}, line-up matrix)
    everything = []
    for i, (mascot_id, _, builder) in enumerate(mascots.MASCOTS):
        objs, _, pieces = mascots.build(mascot_id, builder)
        place = Matrix.Translation((STUD * (i - 2.5) * 4.3, 0, 0)) @ Matrix.Rotation(math.radians(-55 + i * 4), 4, "Z")
        placed.append((mascot_id, {p["name"]: o for p, o in zip(pieces, objs)}, place))
        everything += objs
    def pose(frame, lift=0.0):
        for mascot_id, objs, place in placed:
            for name, piece in frames[mascot_id][frame].items():
                m = roblox_matrix(piece["m"])
                sx, sy, sz = piece["s"]
                if (sx, sy, sz) != (1, 1, 1):
                    pivot = Vector(piece["pivot"])
                    m = m @ Matrix.Translation(pivot) @ Matrix.Diagonal((sx, sy, sz, 1)) @ Matrix.Translation(-pivot)
                objs[name].matrix_world = Matrix.Translation((0, 0, lift)) @ place @ TO_METRES @ m @ FROM_METRES

    # Frame the line-up with room above for the jumps.
    pose(0, STUD * 2.5)
    mascots.stage(everything, "unused.png", width, height, 0.97, 10, render=False)
    scene = bpy.context.scene

    count = len(frames[placed[0][0]])
    tmp = tempfile.mkdtemp()
    stills = []
    for frame in range(0, count, every):
        pose(frame)
        scene.render.filepath = os.path.join(tmp, f"f{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
        stills.append(scene.render.filepath)
        print("frame", frame, "of", count, flush=True)

    from PIL import Image

    images = [Image.open(p).convert("RGB").quantize(colors=128, method=Image.Quantize.MEDIANCUT) for p in stills]
    images[0].save(out_path, save_all=True, append_images=images[1:], duration=int(1000 * every / 30), loop=0, optimize=True)
    print("Wrote", out_path)


if __name__ == "__main__":
    main()
