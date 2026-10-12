class_name AreaTravel
extends CanvasLayer
## Moves the player between areas. One instance, made on first use by service()
## and kept under the tree root so it survives scene changes. travel() fades to a
## black loading screen with the destination's name, loads the area scene in
## the background, swaps it in, carries the player's state over (level, XP,
## health, energy, items; see Player.save_state()), stands the player at the
## named spawn point and fades back in. The game is paused for the trip.
## Also the souls-like checkpoint: resting at a SaveOrb (rest_at) makes it the
## checkpoint, brings the area's enemies back at their posts in place (no
## reload or loading screen; revive_enemies) and saves the game to the current
## slot (SaveManager); dying (respawn) returns to the last orb rested at, or
## the area's start if none, through the loading screen.
## Emptied loot sacks are remembered per area, so they stay gone. The
## checkpoint and emptied sacks are saved with the game ("saveable" group).

## Fade to and from black (real seconds).
const FADE_TIME := 0.45
## The loading screen stays up at least this long so it reads (real seconds).
const MIN_LOADING_TIME := 0.8
const TITLE_SETTINGS: LabelSettings = preload("res://resources/ui/menu_header.tres")
const TEXT_SETTINGS: LabelSettings = preload("res://resources/ui/prompt_label.tres")

## Spawn points are Marker3Ds in this group, found by node name.
const SPAWN_GROUP := &"spawn_points"
## Where respawning with no checkpoint puts the player.
const DEFAULT_SPAWN := &"FromSouth"

var busy: bool = false

static var _instance: AreaTravel = null
## Last save orb rested at: {scene, spawn, area_name}. Empty until the first rest.
var checkpoint: Dictionary = {}

## Scene path -> node paths (from the scene root) of loot sacks already emptied.
var _collected: Dictionary[String, PackedStringArray] = {}

var _cover := ColorRect.new()
var _title := Label.new()
var _loading := Label.new()


## The shared instance, created and added to the tree root the first time.
static func service() -> AreaTravel:
	if not is_instance_valid(_instance):
		_instance = AreaTravel.new()
		_instance.name = &"AreaTravel"
		(Engine.get_main_loop() as SceneTree).root.add_child(_instance)
	return _instance


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	add_child(_cover)
	for label: Label in [_title, _loading]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		label.grow_vertical = Control.GROW_DIRECTION_BOTH
		_cover.add_child(label)
	_title.label_settings = TITLE_SETTINGS
	_title.position.y -= 40.0
	_loading.label_settings = TEXT_SETTINGS
	_loading.position.y += 50.0
	_cover.visible = false
	add_to_group(&"saveable")
	SaveManager.game_started.connect(_on_game_started)
	SaveManager.claim_save_data(self)


## Fades out, loads scene_path and puts the player at the spawn point named
## spawn_name, then fades in. area_name is shown on the loading screen.
## refill restores full health and energy on arrival (resting, respawning).
func travel(scene_path: String, spawn_name: StringName, area_name: String, refill := false) -> void:
	if busy:
		return
	busy = true
	var tree := get_tree()
	var player := tree.get_first_node_in_group(&"player") as Player
	var state := player.save_state() if player != null else {}
	tree.paused = true
	_title.text = area_name.to_upper()
	_loading.text = "NOW LOADING"
	_cover.visible = true
	await _fade(1.0)

	var started := Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(scene_path)
	var dots := 0
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or Time.get_ticks_msec() - started < MIN_LOADING_TIME * 1000.0:
		dots = (dots + 1) % 40
		_loading.text = "NOW LOADING" + ".".repeat(dots / 10)
		await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		push_error("AreaTravel: couldn't load %s" % scene_path)
	else:
		tree.change_scene_to_packed(scene)
		# The new scene is in the tree (and ready) a frame later.
		await tree.process_frame
		await tree.process_frame
		_remove_collected()
		var arrived := tree.get_first_node_in_group(&"player") as Player
		if arrived != null:
			arrived.load_state(state)
			if refill:
				arrived.health.set_current(arrived.health.max_health)
				arrived.stamina.set_current(arrived.stamina.maximum)
			var spawn := _spawn_point(spawn_name)
			if spawn != null:
				arrived.place_at(spawn.global_transform)
	tree.paused = false
	await _fade(0.0)
	_cover.visible = false
	busy = false


## Rests at a save orb: it becomes the checkpoint, the area's enemies come
## back where they started (dead or alive) and the game saves, all in place.
func rest_at(orb: SaveOrb) -> void:
	if busy:
		return
	var scene_path := orb.get_tree().current_scene.scene_file_path
	checkpoint = {scene = scene_path, spawn = String(SaveOrb.SPAWN_NAME), area_name = orb.area_name}
	revive_enemies()
	SaveManager.save_game()


## Puts every enemy the area scene places back as the scene file has it: each
## Enemy, EnemySpawnPoint and EnemySpawner in a fresh copy of the scene replaces
## the live one at the same path (or fills the gap if it died and was freed),
## so killed enemies return and the rest go back to their posts at full health.
## Enemies spawned by other means stay as they are. Returns how many were reset.
func revive_enemies() -> int:
	var scene := get_tree().current_scene
	var packed := load(scene.scene_file_path) as PackedScene
	if packed == null:
		return 0
	var fresh := packed.instantiate()
	var originals: Array[Node] = []
	_collect_enemy_roots(fresh, originals)
	for original: Node in originals:
		var path := String(fresh.get_path_to(original))
		var parent_path := path.get_base_dir()
		var live_parent := scene if parent_path == "" else scene.get_node_or_null(parent_path)
		if live_parent == null:
			continue
		var index := original.get_index()
		var live := scene.get_node_or_null(path)
		if live != null:
			index = live.get_index()
			live_parent.remove_child(live)
			live.queue_free()
		original.get_parent().remove_child(original)
		original.owner = null
		live_parent.add_child(original)
		original.owner = scene
		live_parent.move_child(original, mini(index, live_parent.get_child_count() - 1))
	fresh.free()
	return originals.size()


static func _collect_enemy_roots(node: Node, into: Array[Node]) -> void:
	for child: Node in node.get_children():
		if child is Enemy or child is EnemySpawnPoint or child is EnemySpawner:
			into.append(child)
		else:
			_collect_enemy_roots(child, into)


## After death: back to the checkpoint, or the start of the current area.
func respawn() -> void:
	if checkpoint.is_empty():
		var scene := get_tree().current_scene
		travel(scene.scene_file_path, DEFAULT_SPAWN, String(scene.name).capitalize(), true)
	else:
		travel(checkpoint.scene, StringName(checkpoint.spawn), checkpoint.area_name, true)


## Called by a loot sack as it empties.
func mark_collected(node: Node) -> void:
	var scene := node.get_tree().current_scene
	if scene == null:
		return
	var key := scene.scene_file_path
	var paths: PackedStringArray = _collected.get(key, PackedStringArray())
	paths.append(String(scene.get_path_to(node)))
	_collected[key] = paths


func _remove_collected() -> void:
	var scene := get_tree().current_scene
	for path: String in _collected.get(scene.scene_file_path, PackedStringArray()):
		var node := scene.get_node_or_null(path)
		if node != null:
			node.queue_free()


# --- Saving (SaveManager) ---------------------------------------------------------

func get_save_data() -> Dictionary:
	var collected := {}
	for scene_path: String in _collected:
		collected[scene_path] = Array(_collected[scene_path])
	return {checkpoint = checkpoint, collected = collected}


func apply_save_data(data: Dictionary) -> void:
	_on_game_started(0)
	if data.get("checkpoint") is Dictionary:
		checkpoint = data.checkpoint
	var collected = data.get("collected")
	if collected is Dictionary:
		for scene_path in collected:
			if collected[scene_path] is Array:
				_collected[String(scene_path)] = PackedStringArray(collected[scene_path])
	if get_tree().current_scene != null:
		_remove_collected()


## A new game or a load: forget the last game's checkpoint and emptied sacks.
func _on_game_started(_slot: int) -> void:
	checkpoint = {}
	_collected.clear()


func _spawn_point(spawn_name: StringName) -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(SPAWN_GROUP):
		if node.name == spawn_name:
			return node as Node3D
	push_warning("AreaTravel: no spawn point named %s" % spawn_name)
	return null


func _fade(to: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cover, ^"modulate:a", to, FADE_TIME)
	await tween.finished
