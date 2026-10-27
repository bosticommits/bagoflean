"""Starter module for a new film-set art kit.

Copy this file to <theme>_kit.py, rename the sample models and add them to the map-kit
aggregator. The game consumes named models from MapKitShapes; keep names stable between the
Blender mesh and the code-built fallback.
"""

from kitdsl import B


def film_set_landmark():
    """Replace with a few readable shapes; origin at the floor, Blender forward is -Y."""
    return [
        B((0, 0, 1), (6, 2, 2), "Gold", bevel=0.12),
        B((0, 0, 3), (1, 1, 2), "Navy", bevel=0.08),
    ]


KIT = [
    ("FilmSetTemplateLandmark", film_set_landmark),
]

# Models sunk into terrain rather than resting on the floor.
NO_LIFT = set()

# Optional Blender preview sheets: filename -> (ground models, elevated models).
LINEUPS = {
    "film_set_template.png": ([], ["FilmSetTemplateLandmark"]),
}
