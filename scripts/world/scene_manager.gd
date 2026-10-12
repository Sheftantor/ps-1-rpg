extends CanvasLayer
## Scene changes with a fade (autoload "SceneManager", res://scenes/scene_manager.tscn),
## ported from metroidvania-proto. transition_scene() pauses the game, slides a
## dark radial overlay ($fade) in from one side, changes the scene, emits
## new_scene_ready while the screen is covered (listeners place the player or,
## for SaveManager, apply a save), then slides the overlay out the opposite
## side and unpauses.
##
## Area-to-area travel through AreaExits and save orbs still goes through
## AreaTravel (fade to black with a loading screen); this one is used by the
## start menu and save loading.

signal load_scene_started
signal new_scene_ready(target_name: String, offset: Vector3)
signal load_scene_finished
signal scene_entered(uid: String)

## Seconds for the overlay to slide in, and again to slide out.
@export var fade_time: float = 0.4

## uid:// of the current scene (or its path if it has no uid).
var current_scene_uid: String = ""
## True during a transition.
var busy: bool = false

@onready var fade: Control = $fade


func _ready() -> void:
	fade.visible = false
	await get_tree().process_frame
	load_scene_finished.emit()
	var current := get_tree().current_scene
	if current != null:
		current_scene_uid = _uid(current.scene_file_path)
		scene_entered.emit(current_scene_uid)


## Changes to new_scene behind the fade. target_area and player_offset are
## passed on through new_scene_ready (e.g. a spawn point name and an offset
## from it); dir is the side the overlay comes in from: "left", "right", "up"
## or "down".
func transition_scene(new_scene: String, target_area: String, player_offset: Vector3, dir: String) -> void:
	if busy:
		return
	busy = true
	var tree := get_tree()
	tree.paused = true
	var fade_pos := get_fade_pos(dir)
	fade.visible = true
	load_scene_started.emit()
	await fade_screen(fade_pos, Vector2.ZERO)
	await tree.process_frame

	var err := tree.change_scene_to_file(new_scene)
	if err != OK:
		push_error("SceneManager: couldn't change to %s (%s)" % [new_scene, error_string(err)])
	else:
		current_scene_uid = _uid(new_scene)
		scene_entered.emit(current_scene_uid)
		await tree.scene_changed
		# Hit-stop or gun mode may have been slowing time in the old scene.
		Engine.time_scale = 1.0
		new_scene_ready.emit(target_area, player_offset)

	await tree.process_frame
	await fade_screen(Vector2.ZERO, -fade_pos)
	fade.visible = false
	tree.paused = false
	busy = false
	load_scene_finished.emit()


func fade_screen(from: Vector2, to: Vector2) -> Signal:
	fade.position = from
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(fade, ^"position", to, fade_time)
	return tween.finished


## Where the overlay starts: one screen away on the dir side (diagonally,
## from the bottom right, if dir isn't one of the four, as in the old game).
func get_fade_pos(dir: String) -> Vector2:
	var pos := get_viewport().get_visible_rect().size
	match dir:
		"left":
			pos *= Vector2(-1, 0)
		"right":
			pos *= Vector2(1, 0)
		"up":
			pos *= Vector2(0, -1)
		"down":
			pos *= Vector2(0, 1)
	return pos


static func _uid(path: String) -> String:
	var id := ResourceLoader.get_resource_uid(path)
	return ResourceUID.id_to_text(id) if id != ResourceUID.INVALID_ID else path
