class_name AreaTravel
extends CanvasLayer
## Moves the player between areas. One instance, made on first use by service()
## and kept under the tree root so it survives scene changes. travel() fades to a
## black loading screen with the destination's name, loads the area scene in
## the background, swaps it in, carries the player's state over (level, XP,
## health, energy, items; see Player.save_state()), stands the player at the
## named spawn point and fades back in. The game is paused for the trip.
## Also the souls-like checkpoint: resting at a SaveOrb (rest_at) saves there
## (to SAVE_PATH too) and reloads the area so its enemies respawn; dying
## (respawn) returns to the last orb rested at, or the area's start if none.
## Emptied loot sacks are remembered per area, so they stay gone.

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
const SAVE_PATH := "user://save.json"

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


## Rests at a save orb: it becomes the checkpoint (saved to disk) and the area
## reloads, enemies respawned, with the player stood at the orb.
func rest_at(orb: SaveOrb) -> void:
	if busy:
		return
	var scene_path := orb.get_tree().current_scene.scene_file_path
	checkpoint = {scene = scene_path, spawn = String(SaveOrb.SPAWN_NAME), area_name = orb.area_name}
	_write_save()
	travel(scene_path, SaveOrb.SPAWN_NAME, orb.area_name, true)


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


## The checkpoint and the player's progress, as JSON (resources by path).
func _write_save() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	var state := player.save_state()
	var inventory := []
	for stack: ItemStack in state.inventory:
		inventory.append([stack.item.resource_path, stack.count])
	state.inventory = inventory
	state.gun = state.gun.resource_path if state.gun != null else ""
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("AreaTravel: couldn't write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({checkpoint = checkpoint, player = state}, "  "))


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
