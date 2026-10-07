# Real photo templates

Photos of **blank** shirts. `scripts/photo_templates.py` prints our designs onto them, so the
listing photos look like real photos instead of drawings.

## What photos to send (any phone works)
- A **plain, blank** t-shirt or crewneck with no print. **White or light grey works best**:
  the script can recolour it to any listing colour (black, navy, pink...). Already the right
  colour (e.g. a black sweatshirt) also works.
- **Flat lay:** shirt laid flat on a bed, wooden table or floor, photographed straight from above,
  daylight from a window, no flash. Smooth it out, then add a few soft natural wrinkles.
  Props help: a paddle, balls, a coffee mug, sunglasses, a plant.
- **Hanging:** shirt on a wooden hanger against a plain wall or door.
- **Worn (best of all):** someone wearing the blank shirt, facing the camera, chest visible,
  only with their permission. It can be cropped at the chin so no face shows.
- Big and sharp: at least 2000 px wide, the shirt filling most of the frame.

Licensed mockup photos also work (e.g. downloaded from a mockup site with a **commercial
licence**). Note the source in the JSON.

## Setting one up
Put the photo here as `<name>.jpg`. Claude then adds `<name>.json` with the print area
corners (see the docstring in `scripts/photo_templates.py`) and runs:

    python scripts/photo_templates.py <slug>

Results go to `photos/<slug>/real-<name>.jpg`.
