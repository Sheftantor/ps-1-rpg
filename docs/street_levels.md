# Street levels (night / rain / brick terraces)

Built from the 48-piece kit in `Import/Environment/env_*.glb`. **Generated, not yet opened in Godot** — expect small tuning.

## Area chain (south → north, player enters from the south)

| # | Scene | What's in it |
|---|-------|--------------|
| 1 | `scenes/areas/area_terrace_street.tscn` | Red-brick terraces, sodium lamps, parked cars, trees. Starting street. No south exit (barrier). |
| 2 | `scenes/areas/area_estate.tscn` | Tower blocks (orange/green), fire escapes, bins, alley branch. |
| 3 | `scenes/areas/area_shop_corner.tscn` | Shop front on the east side, **pink save orb next to it**, `ShopDoor` → store. |
| 3b | `scenes/areas/store_612.tscn` | Store interior: shelves, fridges, slush machine, counter (`ShopCounter`). Exit spawns `FromStore`. |
| 4 | `scenes/areas/area_underpass.tscn` | Flyover canyon, tall walls, floating monk. |
| 5 | `scenes/areas/area_downtown.tscn` | Highrise skyline, beacon tower ahead. No north exit (barrier) for now. |

Each area is entered by walking down a road/alley (`FromSouth` / `FromNorth` spawn markers + `AreaExit`).
Enemy levels ramp 2 → 8.

## Shop UI
`scripts/world/shop_counter.gd` (`ShopCounter`) joins the `interactables` group, shows verb "SHOP", and emits
`opened(player)`. Connect that signal to **your** UI. Nothing is drawn by default.

## Rain
`scripts/world/rain.gd` (`RainEmitter`) — GPUParticles3D streaks that follow the camera. Exports: amount, area, height, fall_speed, streak_length, rain_color.

## Hooking it in
Not wired into the existing game. Easiest: in `scripts/save/save_manager.gd` change `NEW_GAME_SCENE` to
`res://scenes/areas/area_terrace_street.tscn`, or add an `AreaExit` from an existing area pointing at it.

## Notes / known gaps
- Store name is a placeholder ("6-12"); the orange/green/red stripe look is close to a real chain — consider changing it before release.
- Moon is unshaded (`ps1_keep_materials` metadata keeps it out of the PS1 material swap).
- No stars, no real wet-road shader. Fog/lighting values in each scene's `WorldEnvironment` are the knobs to tune.
- Alley opening is 4 m wide (older doc said 4 but the old GLB was 2 m — fixed).

## Regenerating
`scripts/tools/street_kit/gen_levels.py` writes the scenes; `validate.py` checks references and collider overlaps;
`render_level.py` makes Blender previews (needs `bpy`). Kit meshes: `build_kit.py` + `Desktop/BlenderProjects/Blend/env_street_kit.blend`.
