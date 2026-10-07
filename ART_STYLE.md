# Art Style Guide: Hollywood RNG

The target look for everything players see. Read it before building any model, map piece,
UI screen or effect. When something here conflicts with a reference image in `references/`,
ask the owner which one wins.

Status: **first draft**, written before any reference screenshots. Update it once the owner
adds images to `references/`.

---

## 1. The feel in one line

**Bright, chunky, cartoon Hollywood.** Sunny backlot by day, glowing red-carpet premiere by
night. It should be readable at a glance on a phone and look like a toy you want to collect.

Words to aim for: *glossy, bold, playful, golden, celebratory.*
Words to avoid: *gritty, realistic, muddy, thin, cluttered.*

## 2. Shapes

- **Big, simple silhouettes.** Every object must be recognizable as a black shape at 50 m.
- **Chunky proportions**: thick walls, oversized doors, rounded or bevelled edges, slightly
  exaggerated tops (marquees, rooftop signs, spotlights).
- **Low poly with flat shading.** No tiny details that disappear on mobile. Detail comes from
  shape and color, not texture noise.
- Slight wobble and asymmetry are fine (a leaning sign, a tilted spotlight) and add charm.

## 3. Color palette

Saturated and warm, with gold as the "reward" color.

| Role | Color | Hex |
|---|---|---|
| Studio walls (base) | Warm cream | `#F4E7CF` |
| Studio trim | Deep burgundy | `#7A1F2B` |
| Red carpet / premiere | Carpet red | `#C8202F` |
| Reward / money / trophies | Award gold | `#F5B82E` |
| Sky accent / UI highlight | Hollywood blue | `#2E86DE` |
| Night / cinema interior | Midnight navy | `#1B2340` |
| Grass and planters | Fresh green | `#5BBF5A` |
| Paths and asphalt | Warm grey | `#8C8A86` |

Rules: max 3 main colors per building, with gold reserved for rewards and rare things.
Avoid pure black and pure white surfaces, since they look flat under Roblox lighting.

## 4. Rarity colors (use everywhere: cards, glows, beams, text)

| Tier | Color | Hex | Effect |
|---|---|---|---|
| Newcomer | Grey | `#A7A9AC` | none |
| Rising | Green | `#4CC764` | soft glow |
| Pro | Blue | `#3A8DFF` | glow and sparkle |
| Star | Purple | `#A04DFF` | glow, sparkles, small beam |
| Superstar | Gold | `#FFC21A` | gold beam, camera shake, fanfare |
| Legend | Red-orange | `#FF5A2E` | big beam, confetti, server announcement |
| Icon | Rainbow / prismatic | animated | full-screen moment, fireworks, server announcement |

Variants: **Shiny** adds a white sparkle shimmer on top. **Award-Winning** adds a gold
trophy badge and gold particle trail.

## 5. Materials and lighting

- Materials: **SmoothPlastic** for most surfaces, **Neon** only for signs and lights,
  **Glass** for windows, **Metal** sparingly (trophies, camera rigs). No realistic textures.
- Lighting: `Future` technology, warm sun, soft shadows. Light `Atmosphere` with a slight
  warm haze. Gentle `Bloom` so neon signs pop. Slight `ColorCorrection` saturation boost.
- Day/night is cosmetic: day for building, dusk glow during **Award Night** events.

## 6. Scale and readability

- Characters are about 5 studs tall, so doors are at least 8 studs tall and paths at least 10 studs wide.
- Interactable pads (claim, collect) are bright, glowing and about 8×8 studs, with a floating
  icon and text label above them.
- Keep the camera's view clear: nothing tall right next to spawn or pads.

## 7. The map

```
                [ Hollywood sign on a hill ]
     Lot 1   Lot 2   Lot 3      <- each lot faces the central boulevard
   ===========  BOULEVARD  ===========   (red carpet strip, lamp posts, palm trees)
     Lot 4   Lot 5   Lot 6
           [ Spawn plaza: fountain, casting booth, shop, index board ]
```

- **Spawn plaza** in the middle: the Casting Booth (the gacha machine, the hero object of
  the game), the script shop, the Index board and the event countdown sign.
- **Boulevard**: red carpet strip, palm trees, lamp posts, spotlights that sweep the sky.
- **Lots**: flat square plots (about 80×80 studs) with a low fence, a name sign and a
  gate facing the boulevard.

## 8. The studio lot (grows with upgrades)

| Piece | Starts as | Upgrades to |
|---|---|---|
| Sound stage | One small grey warehouse with a big number on the side | Up to 4 stages, painted, rooftop lights |
| Cinema | Small ticket booth with a marquee | Grand theatre with neon marquee and red carpet |
| Office | Trailer | Glass office tower with a rooftop logo |
| Billboard | Blank board | Lit billboard showing your rarest actor |
| Trophy shelf | Empty plinth | Trophies from Masterpiece premieres |
| Decor | none | Palm trees, golden statue, searchlights |

Upgrades must be visible from the boulevard. That is the show-off loop.

## 9. Actors (characters)

- **Style**: blocky Roblox-style figures (R15 rig) with exaggerated outfits and props that
  say their role at a glance (sunglasses and a scarf for the Diva, cape for the Hero, clipboard for the Intern).
- Higher rarity means more flair: Newcomers wear plain outfits, Legends get capes, auras and
  signature props.
- All actors are original characters. No real celebrities, names, logos or likenesses.

## 10. UI

- Rounded rectangles, thick dark outline (2–3 px), soft drop shadow, chunky bold font
  (`FredokaOne` or `GothamBlack`).
- Big buttons, at least 60 px tall on phones, with icon plus short label.
- Main colors: cream panels, burgundy headers, gold for currency and primary buttons.
- Casting reveal: a dark screen, then a spinning film reel, then a card flipping in rarity color.
  The rarer the result, the longer the build-up.

## 11. Effects and sound

- Every reward gets feedback: a number popping up, a sparkle and a sound.
- Rare pulls: beam of light in the rarity color, camera shake, music sting.
- Premieres: flashbulbs, confetti for Blockbuster and up, fireworks for Masterpiece.
- Keep effects short (under 3 s) and skippable after the first time.

## 12. Blender pipeline (for models that parts can't do well)

Use Roblox parts for boxy things (walls, stages, pads, fences). Use **Blender** for curved
or detailed props: trophies, film cameras, spotlights, palm trees, the Casting Booth,
the Hollywood sign letters, cars.

**How Claude runs it** (Claude Code on the owner's Mac, no Roqer app needed):

1. Write a Python script in `art/blender/<model>.py` that builds the model from scratch.
2. Run Blender headless:
   `/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python art/blender/<model>.py`
3. The script also **renders a preview PNG** (front and three-quarter views) into
   `art/previews/`. Look at it and fix problems before uploading.
4. Export **FBX** to `art/exports/<model>.fbx`, written in studs (see the export rules below).
5. Import the FBX into Studio with the **3D Importer** (Home → Import 3D), which uploads it
   to the owner's account and places it in the world. Set the MeshPart's `Color` to white and
   `Material` to SmoothPlastic so the vertex colors show unchanged, then screenshot it in
   Studio to check scale and look.
6. Commit the `.py` script and preview, so every model can be rebuilt or changed later.
   Don't commit large exports.

**Model rules**

- Low poly, flat shaded, simple shapes. **Under 2,000 triangles** for props and
  **under 5,000** for hero objects (Casting Booth, cinema facade).
- Colors from the palette above, as **solid-color materials** (no image textures for now).
  Roblox ignores FBX material colors, so the script must also **bake each face's material
  color into a vertex color attribute** and export with `colors_type="SRGB"`.
- Origin at the bottom center, facing −Y in Blender so it imports facing forward.
- Real scale in mind: 1 stud ≈ 0.28 m. A trophy is about 2 studs tall, a palm tree about 25.
- Roblox reads FBX units (centimetres) as studs, so export with
  `global_scale = 1 / (0.28 * 100)`. Without it a 2-stud trophy imports 56 studs tall.
- Apply all transforms before export. One object per model unless it needs moving parts.
- Name every model and material clearly (`Trophy_Gold`, `Mat_AwardGold`).
- Collision is done in Roblox with simple invisible parts, not the mesh.

**Working example:** `art/blender/trophy_gold.py` (604 triangles, 2 studs tall, Roblox
asset 100325620206746). New models use the shared helpers in `art/blender/mmkit.py`
(palette, vertex-color bake, previews, export); `palm_tree.py` is a short example.

**Using a mesh in the game:** put the imported MeshPart in `ReplicatedStorage.LotMeshes` under
the name the code looks for (see `art/README.md`). Code-built models call `Build.mesh` and fall
back to their part version until the mesh is there.

## 13. References

Put screenshots in `references/` with a short note in the filename, e.g.
`references/lot-layout-like-this.png` or `references/ui-colors-not-this.png`.
Use them for style only. Never copy another game's buildings, UI or assets one-to-one.
