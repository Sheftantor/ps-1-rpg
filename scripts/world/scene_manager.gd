extends CanvasLayer
## Scene changes behind a loading screen (autoload "SceneManager",
## res://scenes/scene_manager.tscn), used by the start menu (New Game, Continue,
## Load Game) and the pause menu's quit to title. transition_scene() pauses the
## game, fades to the same black loading screen as area travel (AreaTravel): an
## optional title (the area's name) over "NOW LOADING...", shown only on full
## black so it never floats over a scene; loads the scene in the
## background, changes to it, emits new_scene_ready while the screen is still
## black (listeners place the player or, for SaveManager, apply a save), gives
## the new scene time to settle (it runs unpaused behind the black screen until
## its frame times are steady, so first-frame shader compiles and physics
## hitches happen out of sight), then fades back in on a live scene.

signal load_scene_started
signal new_scene_ready(target_name: String, offset: Vector3)
signal load_scene_finished
signal scene_entered(uid: String)

## Seconds to fade to black, and again to fade back in (real time).
@export var fade_time: float = 0.45
## Seconds for the loading text to fade in on black, and out before the reveal.
@export var text_fade_time: float = 0.15
## The loading screen stays up at least this long so it reads (real seconds).
@export var min_loading_time: float = 0.8
## Before the fade in, the new scene runs behind the black screen until this
## many frames in a row each take under steady_frame_time seconds...
@export var steady_frames: int = 8
@export var steady_frame_time: float = 0.034
## ...or for at most this long (real seconds).
@export var max_settle_time: float = 3.0

const TITLE_SETTINGS: LabelSettings = preload("res://resources/ui/menu_header.tres")
const TEXT_SETTINGS: LabelSettings = preload("res://resources/ui/prompt_label.tres")
const LOADING_TEXT := "NOW LOADING"

## uid:// of the current scene (or its path if it has no uid).
var current_scene_uid: String = ""
## True during a transition.
var busy: bool = false

var _cover := ColorRect.new()
var _title := Label.new()
var _loading := Label.new()


func _ready() -> void:
	_cover.color = Color.BLACK
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.modulate.a = 0.0
	_cover.visible = false
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
	await get_tree().process_frame
	load_scene_finished.emit()
	var current := get_tree().current_scene
	if current != null:
		current_scene_uid = _uid(current.scene_file_path)
		scene_entered.emit(current_scene_uid)


## Changes to new_scene behind the loading screen. target_area and
## player_offset are passed on through new_scene_ready (e.g. a spawn point name
## and an offset from it). title is shown over "NOW LOADING" (e.g. the area's
## name); empty shows just the loading text.
func transition_scene(new_scene: String, target_area: String = "", player_offset: Vector3 = Vector3.ZERO,
		title: String = "") -> void:
	if busy:
		return
	busy = true
	var tree := get_tree()
	tree.paused = true
	_title.text = title.to_upper()
	_title.visible = title != ""
	_loading.text = LOADING_TEXT
	_set_text_alpha(0.0)
	_cover.visible = true
	load_scene_started.emit()
	await _fade(1.0)
	_fade_text(1.0)

	var started := Time.get_ticks_msec()
	var err := ResourceLoader.load_threaded_request(new_scene)
	var dots := 0
	while err == OK and ResourceLoader.load_threaded_get_status(new_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or Time.get_ticks_msec() - started < min_loading_time * 1000.0:
		dots = (dots + 1) % 40
		_loading.text = LOADING_TEXT + ".".repeat(dots / 10)
		await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(new_scene) as PackedScene if err == OK else null
	if scene == null:
		push_error("SceneManager: couldn't load %s" % new_scene)
	else:
		tree.change_scene_to_packed(scene)
		current_scene_uid = _uid(new_scene)
		scene_entered.emit(current_scene_uid)
		await tree.scene_changed
		# Hit-stop or gun mode may have been slowing time in the old scene.
		Engine.time_scale = 1.0
		new_scene_ready.emit(target_area, player_offset)

	# Let the new scene run out of sight until it's steady, then reveal it live.
	tree.paused = false
	await _settle()
	await _fade_text(0.0)
	await _fade(0.0)
	_cover.visible = false
	busy = false
	load_scene_finished.emit()


func _settle() -> void:
	var tree := get_tree()
	var started := Time.get_ticks_msec()
	var steady := 0
	var last := Time.get_ticks_usec()
	while steady < steady_frames and Time.get_ticks_msec() - started < max_settle_time * 1000.0:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		steady = steady + 1 if (now - last) / 1000000.0 < steady_frame_time else 0
		last = now


func _fade(to: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_cover, ^"modulate:a", to, fade_time).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _fade_text(to: float) -> void:
	var tween := create_tween().set_parallel()
	tween.set_ignore_time_scale(true)
	for label: Label in [_title, _loading]:
		tween.tween_property(label, ^"modulate:a", to, text_fade_time)
	await tween.finished


func _set_text_alpha(alpha: float) -> void:
	for label: Label in [_title, _loading]:
		label.modulate.a = alpha


static func _uid(path: String) -> String:
	var id := ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else path
