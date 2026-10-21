# Night street kit — setting, assets and layout guide

Visual target (from the reference shots): rainy night, wet dark asphalt, red-brick terraces, tower blocks,
sodium streetlamps with a visible light cone, pixelated trees and grass, flyovers, one huge landmark tower in the
sky, billboards. Low-res nearest-neighbour textures, flat shading. **Mood: UK architecture, American shops/signage.**

## Where things are
- `Import/Environment/*.glb` — 48 ready-to-use pieces (textures embedded, nearest filtering).
- `Import/Environment/source_textures/` — the PNGs (ignored by Godot via `.gdignore`; swap/re-paint here).
- `scripts/tools/street_kit/` — the generator (`build_kit.py`, `textures.py`). It re-makes every GLB.
  Run (needs `pip install bpy pillow numpy`, Python 3.13): `python build_kit.py out_folder`
- `env_street_kit.blend` (in your Blend folder) — every piece laid out in rows by group, open in Blender.

## Conventions
1 unit = 1 m. Origin at the base centre. Fronts face +Z in Godot (-Y in Blender). Y-up on export.

## Pieces
| Group | Names |
|---|---|
| buildings | terrace_a/b/c (6x7m), terrace_row (18m), shop_terrace (12m), tower_block_orange (24x12x24), tower_block_green, highrise_a (68m), highrise_b |
| landmarks | beacon_tower (4x4x58, put it far away so it's always on the skyline) |
| road | road_straight (8x8, centre dashes), road_plain, sidewalk, grass_verge, flyover (16m long deck + pillars), underpass_road |
| alley | alley_wall (6x6), alley_wall_tall (12m), alley_wall_graffiti, alley_floor, alley_mouth (arch entrance, 4m opening), alley_gate (chain-link + blocks), fire_escape |
| props | street_lamp, lamp_cone (translucent light shaft), railing, chainlink_fence, wheelie_bin, dumpster, traffic_cone, bottle, bin_bag, bench, bollard, parking_sign, phone_box, bus_shelter, car_hatch, billboard |
| nature | tree_a, tree_b, bush |
| store | store_exterior, store_interior, shelf_unit, fridge_unit, counter, slush_machine |

## Godot setup notes
- Lamps: the street_lamp mesh glows (emission) but doesn't light anything. Put an `OmniLight3D`/`SpotLight3D` at the lamp head (about 6.2 m up) with orange `#ffb060`, and drop `lamp_cone` under it (it is already translucent).
- `chainlink` and `lamp_cone` use alpha blend; if sorting looks wrong set their material Transparency to Alpha Scissor.
- Lit windows are baked into the textures. For a stronger night look, darken the sun/ambient and add a little fog (`Environment` fog, blue-grey) like the reference.
- Rain: a `GPUParticles3D` of thin streaks following the camera does the job.

## Areas: down a road or an alley
Stop making every area a plaza. Each area is one **corridor** with a distinct dressing, and the exits are the
transitions you already have (`area_exit.gd`, fade in/out):
- **Road exit:** `road_straight` pieces running off with `alley_gate`/`railing` + a `parking_sign`; far end is fog.
- **Alley exit:** `alley_mouth` between two `terrace_*`; alley made of `alley_wall` + `alley_floor`, dumpsters, `fire_escape`.
Suggested sequence so no two areas look alike:
1. Terrace street — `terrace_a/b/c`, `sidewalk`, `street_lamp`, `bin`, `car_hatch`
2. Tower-block estate — `tower_block_*`, `grass_verge`, `tree_a`, `bench`, `bus_shelter`
3. **Shop corner (save orb + shop)** — see below
4. Flyover underpass — `flyover` over `underpass_road`, graffiti walls, `billboard`
5. Highrise downtown — `highrise_*`, `phone_box`, wet road, `beacon_tower` in the sky

## Area 3 blockout: save orb + shop
```
  alley_mouth (back exit)                      <- fog
      |
  terrace_b | alley_wall_graffiti
  ---------------------------------------
  [save orb]   [store_exterior, forecourt facing the road]
  street_lamp x2 (lamp_cone), bench, wheelie_bin
  ---------------------------------------
  road_straight x3 + sidewalk (player enters from here)
```
Orb ~6 m from the store door so the save and the shop read as one safe pocket.
The store scene = `store_exterior` outside; walking through the door fades to a scene with `store_interior`
+ `shelf_unit`/`fridge_unit`/`counter`/`slush_machine`. The shop menu UI (Win95 window style) is yours to design.

## Store name
The sign is the texture `store_sign.png` made from `STORE_NAME` at the top of `textures.py` (default "6-12").
Swap the PNG or edit the constant and re-run the generator. The orange/green/red band is a clear nod to a real
chain's branding; shifting those colours in `stripe_band()` keeps it a parody if you ever ship commercially.

## Not made yet
Characters/NPCs, the sky (stars, moon), rain, a real tileable wet-road shader, and Godot scene files that
assemble these into levels. The pieces are ready for that next step.
