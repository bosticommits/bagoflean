# Studio baseline, 27 Oct 2026

A Studio stand-in for the low-end phone capture in ART_STYLE.md §13. Part, mesh and triangle
counts don't depend on the device. Frame times and memory here come from a Mac running Studio and
do **not** stand for a phone. The real phone capture is still to do.

## Setup

- Place 113373326961317 at `main` d8fe51e (after #93), solo playtest, default window (no device
  simulator).
- All six lots rebuilt at max level in the running server: 5 sound stages all filming, Cinema
  Size 6, Offline Earnings 5, 5 trophies, 3 laurels, a Superstar (BoxOfficeKing) on the pedestal.
- The three film set crews were running (Dusty Gulch, Moon Base, Jungle Temple).
- Town life (`claude/town-life`) is **not merged**, so it isn't in these numbers.
- Workspace.StreamingEnabled = true. The streaming radii couldn't be read from a script; check
  them in the published place's settings.

## Parts by area (client, whole workspace)

| Area | BaseParts | of which MeshParts | ART_STYLE ceiling |
| --- | ---: | ---: | ---: |
| One full lot | 545 (one-sixth of `Lots`) | 0 | 180 |
| All six lots (`Lots`) | 3,672 | 0 | — |
| Town (`Town`) | 4,058 | 1,877 | 500 (town core + lot approaches) |
| Film set crews (`FilmCrewGulch` / `MoonBase` / `Jungle`) | 73 / 67 / 56 | 63 / 58 / 48 | 220 per set incl. the set |
| Mascots | 37 | 0 | — |
| MapLife | 33 | 33 | — |
| **Whole workspace** | **8,014** | **2,095** | 1,000 |

Client instance count: about 68,300 (it rose by 163 in about two minutes; too short to call a
leak either way).

## Triangles and draw calls (client, camera at spawn)

| State | Triangles | Draw calls |
| --- | ---: | ---: |
| Empty lots (fresh join) | 159,278 | 138 |
| Six full lots | 173,030 | 159 |

The ceiling for town + six full lots + three crews is 100,000 triangles. Spawn alone is already
about 1.6x that before the lots fill up.

## Script cost (client, 8 s Script Profiler, Mac)

Our scripts took about 9.5% of the capture. The largest, as a share of the capture:

| Script | Share |
| --- | ---: |
| `WorldRoot.BulkMoveTo` (engine call made by the movers below) | 5.4% |
| `ActorLife` step (actors wandering town) | 3.9% |
| `FilmSetWorld` (crew playback) | 3.3% |
| `MapLife` (ducks, birds, butterflies, etc.) | about 2.2% |
| `PVInstance.PivotTo` | 1.5% |
| `CrewRig.apply` / `FilmScenes.frame` | 0.7% / 0.5% |

Server scripts: 0.14% of the capture (Award Night, special events, visits). Negligible.

A low-end phone CPU is several times slower than this Mac, so client animation scripts are the
part to watch.

## Memory (client, by tag, MB)

Studio's own process is included, so LuaHeap (916) and Internal (1,465) can't be separated from
Studio. Game-attributable tags: Instances 122, Script 284, GraphicsTexture 66, GraphicsTerrain 54,
Gui 51, BaseParts 40, Sounds 16, Signals 16, Particles 12, TerrainVoxels 11, Animation 9.

## What this says

1. **Lots are the cheapest big win.** Every lot building is still part-built: 545 parts and no
   meshes per full lot, three times the 180 ceiling. Rebuilding stages, cinema and office as
   Blender meshes (the plan in ART_STYLE) should cut lots from about 3,700 parts to a few hundred.
2. **Town is over budget too.** It's 4,058 parts, 2,181 of them plain parts (ground, paths, trims).
   Merging the flat ground into a few meshes, or streaming the far scenery out, would help.
3. **Triangles at spawn** are 173k against a 100k whole-scene ceiling. Either the ceiling is too
   tight for this map or far scenery needs lower-detail versions. The phone capture decides which.
4. **Client animation** (actors, crews, map life) is the main script cost. If the phone shows
   script time, slow distant movers to a lower update rate before anything else.

## Still to do on a real phone

The checklist item stays open. Publish, then on the lowest supported phone record: device,
resolution, graphics level, a 60 s warmed-up MicroProfiler capture, frame time, memory over a
30-minute session, and the same with crews and town life paused.
