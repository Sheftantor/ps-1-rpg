# Handoff between the two Claude sessions (cloud Cowork + local Claude Code)

Joseph is running two Claude sessions on this project at once:
- **Cloud session ("Cowork")**: no Godot editor access. Writes files straight into this folder. Builds Blender models headless.
- **Local Claude Code (this PC)**: has the Beckett MCP (runs and inspects the Godot editor/game) and a Blender MCP.

They can't message each other. **This file is how they coordinate.** Read it before you touch anything listed below, and add a line to the log at the bottom when you finish something.

## Who owns what right now

### Cloud session is editing (don't change these until the log says "released")
- `scripts/shop/*` (new): ShopStock / ShopEntry resources
- `scripts/ui/shop_menu.gd`, `scenes/shop_menu.tscn` (new): the shop screen
- `scripts/world/shop_counter.gd`
- `resources/shop/*`, `resources/items/*` (new store items + `price` on items), `textures/ui/icons/item_*.png`
- `scripts/commands/item_data.gd` (adds `price`)
- `scripts/player/player.gd`, `scripts/player/player_saveable.gd`, `scripts/player/player_loadout.gd`, `scripts/player/player_stats.gd`: **only** adding `money` (wallet, kill cash, save/carry-over)
- `scripts/ui/game_menus.gd` (adds ShopMenu to any_open), `scripts/ui/inventory_menu.gd` + `scenes/inventory_menu.tscn` (wallet label)
- `scenes/areas/store_612.tscn` (rebuilt interior with clerk), `Import/Environment/env_store_interior.glb` + new store props (`env_clerk`, `env_back_bar`, `env_hotdog_roller`, `env_ice_chest`)
- `scripts/save/save_manager.gd`: `NEW_GAME_SCENE` → `res://scenes/areas/area_terrace_street.tscn`
- `scripts/tools/street_kit/*` (level generator; it regenerates `scenes/areas/area_*.tscn`, so hand edits to those files get overwritten the next time it runs)

### Good jobs for local Claude Code (it can run Godot, the cloud session can't)
1. Open each scene in `scenes/areas/` with Beckett, run it, and report errors/warnings (missing resources, import issues, collision problems, player falling through the floor, gates firing on spawn).
2. Play the chain start to finish: Terrace Street → Estate → Shop Corner (save orb + store door) → Underpass → Downtown.
3. Tune lighting/fog in each scene's WorldEnvironment if it's too dark through the PS1 post effect.
4. **Building new levels:** put them in `scenes/areas/` with new file names. Don't rename or hand-edit the five generated `area_*.tscn` files. Ask for changes in this log instead, or change `scripts/tools/street_kit/gen_levels.py` after the cloud session releases it.

## Level contract (so areas link up)
- Road runs along Z. Player enters from the south (+Z) heading north (−Z).
- Spawn points: `Marker3D` nodes in group `spawn_points` named `FromSouth` / `FromNorth` (plus `FromStore`, `FromDoor`, and the save orb's own `SaveOrbSpawn`).
- Exits: `Area3D` with `scripts/world/area_exit.gd` (`target_scene`, `target_spawn`, `area_name`, `size`). Keep a spawn at least ~3 m from any gate so arriving doesn't re-trigger it.
- Kit pieces: `Import/Environment/env_*.glb`. Front faces +Z, origin at base centre, 1 unit = 1 m. Colliders are separate `StaticBody3D` boxes (see `COL` in `gen_levels.py`).

## Log (newest last)
- 2026-10-21 cloud: committed 5 street areas + store_612 + rain.gd + shop_counter.gd (untested in Godot).
- 2026-10-21 cloud: STARTED shop system + money + store interior rebuild + new-game wiring (files above).
- 2026-10-21 cloud: DONE and **released** (Claude Code may edit any of those files now). None of it has been run in Godot yet. Summary:
  - Money: `Player.money`, `add_money()`, `spend_money()`, `remove_item()`, signal `money_changed`. Carried between areas (`save_state`/`load_state`) and saved (`PlayerSaveable`). Start cash is `PlayerLoadout.starting_money` (40). Kills pay `PlayerStats.kill_cash_per_level` (3) × enemy level, flashed as `+$N` beside the XP.
  - Shop: `ShopStock` / `ShopEntry` resources (`scripts/shop/`), stock in `resources/shop/store_612_stock.tres`. `ItemData.price` added. New items: hot_dog, slush, canned_coffee, bandages (+ prices on potion/tonic), with icons in `textures/ui/icons/item_*.png`.
  - `ShopMenu` (`scenes/shop_menu.tscn`, `scripts/ui/shop_menu.gd`): full-screen, pauses like the inventory, in `GameMenus.any_open()`. BUY/SELL tabs. Trade with right-click, E (interact) or the button. `next_item` switches tabs. Esc leaves. Found through the `shop_menu` group, and store_612.tscn has an instance.
  - `ShopCounter` now has `stock` and opens the menu. The `opened` signal still fires.
  - The inventory screen shows `CASH  $N` (new `Root/Wallet` label).
  - store_612 rebuilt at 12×9 m: shell GLB plus separate fridges, shelves, counters, back bar, clerk, hot dog roller, slush machine and ice chest. Spawn moved 3 m from the door gate.
  - New game now starts at `scenes/areas/area_terrace_street.tscn` (`SaveManager.NEW_GAME_SCENE`).
  - Downtown's north gate now goes to `res://scenes/test_plaza.tscn` → `FromSouth` (Times Square), so the old city follows the new streets.
- 2026-10-21 local: ran every scene in `scenes/areas/` with Beckett (post-release versions of store_612 + downtown). **No script errors, warnings or missing resources anywhere.** All new GLBs/PNGs imported. The 13 touched scripts (checklist 1 list + rain, item_data, player_stats, player_loadout, save_manager) compile. Player stands on the ground at every spawn, no falling through.
  - Gates: every link works and lands on the right spawn: Terrace↔Estate↔Shop Corner↔Underpass↔Downtown (all 8 directions), Shop Corner→store `FromDoor`, store→Shop Corner `FromStore` (no bounce back), Downtown→Times Square `FromSouth`. No gate fires on spawn in the new store (the old one did).
  - **BROKEN: enemies sit inside detection range of the entry spawns** (grunt/suit 12 m, monk 16 m), so you get mobbed on arrival. Seen at runtime with a fresh L1 player: Underpass `FromSouth` → dead in ~7 s and the no-checkpoint respawn drops you back on the same spot; Underpass `FromNorth` 100→0 HP in ~3 s; Estate/Shop Corner `FromNorth` → ~55 HP in 3 s; Downtown `FromSouth` 100→24 in 4.5 s. Offenders (fix in `gen_levels.py`, keep ≥14 m / ≥18 m for monks): Terrace SuitE (0,−52) 6 m from FromNorth; Estate GruntA (3,28) 10.4 m from FromSouth, GruntF (0,−56) 2 m from FromNorth; Shop Corner GruntE (−3,−56) 3.6 m from FromNorth, GruntA (−3,26) 12.4 m (borderline); Underpass GruntA (−3,30) 8.5 m from FromSouth, GruntF (3,−58) 3 m from FromNorth; Downtown MonkF (0,−52) 6 m from FromNorth, SuitA (−3,26) 12.4 m from FromSouth.
  - store_612: `FromDoor` (−3, 2) is on the same X as the door, so the camera's spring arm goes straight out the open doorway and the first frame is the store seen from outside in a black void. Shift the spawn ~1.5 m off the door axis (or add a camera blocker). Same idea at Shop Corner `FromStore`: the camera starts behind the door's gold haze, so the screen is washed gold until you move.
  - Cosmetic: in every street area the first lamp (−6.8, z 36) puts its translucent cone right beside `FromSouth`, filling the left third of the opening shot.
  - Not tested (needs input, which Beckett Lite can't send): checklist 2 (buy/sell), 3 (New Game, kill cash), 4 (save orb/cash persistence). Verified only that the counter has `store_612_stock.tres`, the ShopMenu is in the tree, and a new player has $40. Checklist 6 (test_plaza SouthGate) not done yet.
- 2026-10-21 local: **edited `gen_levels.py` and re-ran it** (all 5 `area_*.tscn` regenerated; store_612 output unchanged). Before the change, the generator output matched the committed scenes byte for byte, so no hand edits were lost. Fixes, from Joseph's playtest:
  - Sidewalk curb: the pavers collider top is 0.225 m, but the player capsule (r 0.4, floor_max_angle 60°) can only ride up about 0.20 m, so you had to jump onto every sidewalk and out of the Terrace alley mouth. Added a `ramp()` helper and two 24° slope colliders per sidewalk tile (road edge and building edge, 0.5 m run). `COL` boxes now take an optional 7th value, a roll in degrees about local Z (`tf_roll`). Checked with the real controller holding move_forward: before, it got stuck at the curb and at the alley mouth; after, it walks up at full speed.
  - Terrace alley fire escape: it was placed at yaw 90, so its 2 m width stuck 1.5 m across the 4 m alley, with no collision (walk-through stairs/poles). It's now yaw 180 (flush on the south wall, railing toward the alley) with a `COL["fire_escape"]` box.
  - If `build_kit.sidewalk` changes height, update `CURB_TOP`.
- 2026-10-21 local: **`gen_levels.py` edited again and re-run** (store_612 unchanged), from Joseph's playtest ("I can walk out of the path at the start"):
  - New `street_bounds()`: `row()` now records each roadside's building frontage (`sc.cover`, `sc.line`; also the store and the Underpass flank walls). Every uncovered stretch (row gaps, both street ends) gets an invisible 12 m wall plus `chainlink_fence` pieces, so you can't walk round behind the buildings. Called at the end of every area. New buildings placed outside `row()` need a `sc.cover[side].append(...)`.
  - Outer `Bounds` moved from ±27 to ±41 (`half=40`): the old West bound cut the Terrace alley (dead end at x −36) and the Shop Corner alley (−30) in half, so their loot, enemy and fire escape were unreachable.
  - Estate gates are now as wide as its street (`gates(width=)`, 33.4 m). At 16 m you could walk round them on the grass.
  - **New-game intro** on Terrace Street: `env_apartment_door` (stone porch + front door, built by `scripts/tools/street_kit/build_apartment_door.py`, with `door_open`/`door_close` glTF clips) sits on the first house on the right, (6.6, 37). `scenes/apartment_intro.tscn` + `scripts/world/apartment_intro.gd` play it: fade in on the door, the player model walks out and pulls the door shut, fade out, then fade in on the real player at the porch. Plays once per save via `SaveManager.persistent_data["apartment_intro_seen"]`. E/Esc/Enter skips it. It plays every time Terrace Street is run straight from the editor (fresh SaveManager).
  - Tested with the real controller: the start area, row gaps and street ends stop the player at the building line, and the Terrace alley is walkable to its dead end. All 6 scenes load with no errors.
- 2026-10-21 local: look pass from Joseph ("textures glitch out too much, too dark"):
  - `PS1Renderer` honours a new node meta `ps1_no_vertex_snap` (inherited by children) and sets the shader's `vertex_snap` false on those materials. `gen_levels.py` puts it on road/sidewalk/grass/alley-floor pieces (`NO_SNAP`) and the Ground plane, which also sits 8 cm under the road now (was 3 cm). Snapped, the 8 m tiles slid separately, so the lane line broke at every seam and the ground plane z-fought the road.
  - `settings/ps1_settings.tres` `vertex_snap_strength` 1.0 → 0.5 (global wobble, every level).
  - `rain.gd`: distance fade (`near_fade`), so drops passing the lens don't fill the screen as bars.
  - `night_env`: ambient 0.65 → 0.95, adjustment brightness 1.0 → 1.18, moonlight 0.55 → 0.75, and **`fog_sky_affect` 0 → 1** with the sky colour = fog colour. With sky affect 0, Godot 4.7 rendered the custom-colour background black under fog, which is why every sky was pure black. Area fog/sky tints lifted a little: Estate teal, Underpass purple, Downtown blue.

## Test checklist for local Claude Code (Beckett)
1. Let Godot import the new GLBs/PNGs, then check the Output panel for script parse errors in: shop_menu.gd, shop_counter.gd, shop_stock.gd, shop_entry.gd, player.gd, player_saveable.gd, inventory_menu.gd, game_menus.gd.
2. Run `scenes/areas/store_612.tscn`. Walk to the counter, press E, and make sure the shop opens. Buy a hot dog (cash drops by 5, item lands in the bag), switch to SELL, sell it back, then Esc to close (the game unpauses and the mouse is recaptured). Check the open shop doesn't also open the pause menu.
3. New Game from the start menu should load Terrace Street. Kill an enemy and confirm `+N XP   +$N`. The inventory should show cash.
4. Area travel keeps cash. Save at the Shop Corner orb, reload, and cash is still there.
5. Walk out of the store door and you should arrive at Shop Corner `FromStore`, facing the road, without bouncing straight back in.
6. **TODO for Claude Code:** add a `SouthGate` (AreaExit) to `scenes/test_plaza.tscn` at about z = 33 (FromSouth is at z = 26) → `res://scenes/areas/area_downtown.tscn`, spawn `FromNorth`, area_name "Downtown", so the player can walk back. The cloud session left test_plaza alone because it's yours.
7. Report anything broken in this log. If the fix is in a generated `area_*.tscn`, describe it here, or fix `gen_levels.py` and re-run it (`python scripts/tools/street_kit/gen_levels.py <outdir>`), rather than hand-editing the scene.
