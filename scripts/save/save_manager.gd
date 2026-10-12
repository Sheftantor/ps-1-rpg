extends Node
## Save slots (autoload "SaveManager"), ported from metroidvania-proto.
##
## Three slots, one JSON file each (user://save_01.sav ...), written to a .tmp
## file first and then swapped in so a crash mid-write can't wreck a slot. Saving
## happens at save orbs (AreaTravel.rest_at) and once when a new game starts;
## there's no autosave, like the old game. A missing, damaged or newer-version
## file is reported as such and never crashes the game.
##
## The manager knows nothing about the player or other systems: any node that
## needs saving joins the "saveable" group and implements
##   get_save_data() -> Dictionary      (JSON-safe values only)
##   apply_save_data(data: Dictionary)
## and may also implement get_save_summary() -> Dictionary for the slot list
## (the player gives its level). Data is stored per node path. A node that
## appears after a load (created on demand) calls claim_save_data(self) in its
## _ready to get its share. Loading changes to the saved scene first (through
## SceneManager), then applies the data while the screen is still covered.

## Emitted when a new game starts or a save starts loading, before the scene
## changes. Long-lived nodes clear their per-game state here.
signal game_started(slot: int)
signal game_saved(slot: int)
signal game_loaded(slot: int)

## Bump when the save layout changes, and upgrade older files in _migrate().
const SAVE_VERSION: int = 1
const SLOTS: Array[String] = ["save_01", "save_02", "save_03"]
const NEW_GAME_SCENE: String = "res://scenes/test_plaza.tscn"
## The loading screen's title for a new game (the area NEW_GAME_SCENE is).
const NEW_GAME_AREA_NAME: String = "Times Square"
const START_MENU_SCENE: String = "res://scenes/start_menu.tscn"
const SAVEABLE_GROUP: StringName = &"saveable"

var current_slot: int = 0
## The data last saved or loaded.
var save_data: Dictionary = {}
## Free-form progress any script can read and write (doors, switches, story
## flags...), saved with the game. Same as the old game's persistent_data.
var persistent_data: Dictionary = {}
## Real seconds played in this save (counted in game scenes, not in the start
## menu or during scene changes).
var play_time: float = 0.0

## Saved node data (node path -> data) not yet handed to its node.
var _pending: Dictionary = {}
var _last_ticks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	# Real time, so hit-stop and gun mode's slow motion don't shrink it.
	var now := Time.get_ticks_usec()
	var elapsed := (now - _last_ticks) / 1000000.0
	_last_ticks = now
	if _in_game() and not SceneManager.busy:
		play_time += elapsed


## Debug keys from the old game (debug builds only): F5 save, F7 load the
## current slot, F1-F3 pick the slot.
func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_F5:
			save_game()
		KEY_F7:
			load_game(current_slot)
		KEY_F1:
			current_slot = 0
		KEY_F2:
			current_slot = 1
		KEY_F3:
			current_slot = 2


## Starts a new game in slot: changes to NEW_GAME_SCENE and writes the slot
## straight away, so it shows up under Continue and Load Game.
func create_new_save_game(slot: int) -> void:
	if SceneManager.busy:
		return
	current_slot = slot
	persistent_data = {}
	play_time = 0.0
	save_data = {}
	_pending = {}
	game_started.emit(slot)
	SceneManager.transition_scene(NEW_GAME_SCENE, "", Vector3.ZERO, NEW_GAME_AREA_NAME)
	await SceneManager.new_scene_ready
	save_game()


## Writes the current game to the current slot. False if there's no game
## running (start menu) or the file can't be written.
func save_game() -> bool:
	var scene := get_tree().current_scene
	if not _in_game():
		return false
	var nodes := {}
	var summary := {location = String(scene.name).capitalize()}
	for node: Node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		if node.has_method(&"get_save_data"):
			nodes[String(node.get_path())] = node.get_save_data()
		if node.has_method(&"get_save_summary"):
			summary.merge(node.get_save_summary(), true)
	save_data = {
		version = SAVE_VERSION,
		timestamp = int(Time.get_unix_time_from_system()),
		play_time = play_time,
		scene_path = scene.scene_file_path,
		summary = summary,
		persistent_data = persistent_data,
		nodes = nodes,
	}
	var path := get_file_name(current_slot)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: couldn't write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(temp_path, path)
	if err != OK:
		push_warning("SaveManager: couldn't replace %s (%s)" % [path, error_string(err)])
		return false
	print("Saved game to slot %d" % (current_slot + 1))
	game_saved.emit(current_slot)
	return true


## Loads slot: changes to its scene with the fade, then applies its data.
## False (and nothing happens) if the slot is empty or unreadable.
func load_game(slot: int) -> bool:
	if SceneManager.busy:
		return false
	var data := _read_slot(slot)
	if data.is_empty():
		return false
	current_slot = slot
	save_data = data
	persistent_data = data.get("persistent_data", {})
	play_time = float(data.get("play_time", 0.0))
	_pending = {}
	game_started.emit(slot)
	var summary = data.get("summary")
	var location := String(summary.get("location", "")) if summary is Dictionary else ""
	_change_and_apply(String(data.scene_path), location if location != "" else _area_name(String(data.scene_path)))
	return true


## Hands every saveable node in the tree its saved data. Called by load_game
## once the saved scene is in.
func apply_save_data_to_scene() -> void:
	var nodes = save_data.get("nodes", {})
	_pending = (nodes as Dictionary).duplicate() if nodes is Dictionary else {}
	for node: Node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		claim_save_data(node)


## Gives node its saved data, if the last load had some for its path. Nodes
## made after the load (e.g. AreaTravel, created on first use) call this.
func claim_save_data(node: Node) -> void:
	var key := String(node.get_path())
	if not _pending.has(key) or not node.has_method(&"apply_save_data"):
		return
	var data = _pending[key]
	_pending.erase(key)
	if data is Dictionary:
		node.apply_save_data(data)


func get_file_name(slot: int) -> String:
	return "user://" + SLOTS[slot] + ".sav"


func save_file_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_file_name(slot))


## For the slot list: {state = "empty" | "damaged" | "ok"}, and when ok also
## level, location, play_time (s) and timestamp (Unix seconds).
func get_slot_info(slot: int) -> Dictionary:
	if not save_file_exists(slot):
		return {state = "empty"}
	var data := _read_slot(slot)
	if data.is_empty():
		return {state = "damaged"}
	var summary: Dictionary = data.get("summary", {}) if data.get("summary") is Dictionary else {}
	return {
		state = "ok",
		level = int(summary.get("level", 1)),
		location = String(summary.get("location", "")),
		play_time = float(data.get("play_time", 0.0)),
		timestamp = int(data.get("timestamp", 0)),
	}


## The readable slot saved most recently, or -1 if there's none.
func most_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for slot in SLOTS.size():
		var info := get_slot_info(slot)
		if info.state == "ok" and info.timestamp > best_time:
			best = slot
			best_time = info.timestamp
	return best


## "H:MM:SS" for the slot list.
static func format_play_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, total / 60 % 60, total % 60]


## Local "YYYY-MM-DD HH:MM" for a Unix timestamp.
static func format_date(timestamp: int) -> String:
	var local := timestamp + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true).left(16)


func _change_and_apply(scene_path: String, title: String) -> void:
	SceneManager.transition_scene(scene_path, "", Vector3.ZERO, title)
	await SceneManager.new_scene_ready
	apply_save_data_to_scene()
	game_loaded.emit(current_slot)


## Fallback loading-screen title for a save without a location: the scene's
## file name, e.g. "Test Plaza".
static func _area_name(scene_path: String) -> String:
	return scene_path.get_file().get_basename().capitalize()


## The slot's data, upgraded to SAVE_VERSION, or {} if it's missing, damaged,
## from a newer version, or points at a scene that no longer exists.
func _read_slot(slot: int) -> Dictionary:
	var path := get_file_name(slot)
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_warning("SaveManager: %s is damaged (%s)" % [path, json.get_error_message()])
		return {}
	var data: Dictionary = json.data
	var version = data.get("version")
	if not (version is float or version is int) or int(version) > SAVE_VERSION:
		push_warning("SaveManager: %s has an unknown save version (%s)" % [path, version])
		return {}
	data = _migrate(data, int(version))
	var scene_path = data.get("scene_path")
	if not scene_path is String or not ResourceLoader.exists(scene_path):
		push_warning("SaveManager: %s points at a missing scene (%s)" % [path, scene_path])
		return {}
	return data


## Upgrades data saved by an older SAVE_VERSION. Nothing to do yet (version 1).
func _migrate(data: Dictionary, _from_version: int) -> Dictionary:
	data.version = SAVE_VERSION
	return data


func _in_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path != START_MENU_SCENE
