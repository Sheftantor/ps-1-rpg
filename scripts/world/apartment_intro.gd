class_name ApartmentIntro
extends Node3D
## New-game intro on Terrace Street, sitting on the player's front door
## (env_apartment_door, placed by gen_levels.py). Fades in on the door, the door
## swings open, the player walks out, turns and pulls it shut, then the screen
## fades out and back in on the real player standing where the walk ended.
## Plays once per save: SaveManager.persistent_data[SEEN_KEY] is set as it
## starts, so the save written when a new game begins already has it. Interact,
## pause or accept skips to the end. Positions are porch-local: +Z is out toward
## the street, +X is the door's hinge side.

const SEEN_KEY := "apartment_intro_seen"
const SKIP_ACTIONS: Array[StringName] = [&"interact", &"pause", &"ui_accept"]

@export var enabled: bool = true
## Seconds for each fade (in at the start, out at the end, back in on the player).
@export var fade_time: float = 0.8
## Walk from inside the dark doorway out onto the pavement (porch-local), at
## walk_speed m/s.
@export var walk_from: Vector3 = Vector3(0.0, 0.0, -0.2)
@export var walk_to: Vector3 = Vector3(0.25, 0.0, 1.75)
@export var walk_speed: float = 1.4
## Where the actor reaches for the open door's edge to pull it shut.
@export var door_handle: Vector3 = Vector3(0.65, 1.0, 1.35)
## Which way the player faces when control starts (porch-local; -X is up the street).
@export var face_at_end: Vector3 = Vector3(-1.0, 0.0, 0.0)
## Camera dolly start and end (porch-local), and what it looks at: the door,
## then the player once they're out.
@export var camera_from: Vector3 = Vector3(-4.4, 1.35, 4.8)
@export var camera_to: Vector3 = Vector3(-3.2, 1.5, 3.9)
@export var look_door: Vector3 = Vector3(0.0, 1.25, 0.45)
@export var look_player: Vector3 = Vector3(0.15, 1.25, 1.6)

var _door: AnimationPlayer
var _player: Player
var _enemies: Node3D
var _hidden_layers: Array[CanvasLayer] = []
var _timeline: Tween
var _look: Vector3
var _done: bool = false

@onready var _camera: Camera3D = $Camera
@onready var _actor: Node3D = $Actor
@onready var _anim: AnimationPlayer = $Actor/Model/AnimationPlayer
@onready var _cover: ColorRect = $Fade/Cover


func _ready() -> void:
	# A loaded save (play time already counted) never replays it.
	if not enabled or SaveManager.persistent_data.get(SEEN_KEY, false) or SaveManager.play_time > 1.0:
		set_process(false)
		set_process_unhandled_input(false)
		queue_free()
		return
	SaveManager.persistent_data[SEEN_KEY] = true
	_door = get_parent().find_child("AnimationPlayer", true, false) as AnimationPlayer
	# The model's AnimationTree is driven by Player; here the clips play directly.
	($Actor/Model/AnimationTree as AnimationTree).active = false
	_actor.position = walk_from
	_actor.rotation.y = _yaw(Vector3.BACK)
	_anim.play(&"Idle")
	_look = look_door
	_camera.position = camera_from
	_camera.look_at(to_global(_look))
	# Behind a scene change the loading screen's own fade-in reveals the first shot.
	_cover.modulate.a = 0.0 if SceneManager.busy else 1.0
	_take_over.call_deferred()


func _process(_delta: float) -> void:
	if not _done:
		_camera.look_at(to_global(_look))


func _unhandled_input(event: InputEvent) -> void:
	if _done or _timeline == null:
		return
	for action: StringName in SKIP_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			_finish()
			return


## Hides and freezes the player (and the enemies) and takes the camera, then
## starts once any loading screen has gone.
func _take_over() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_DISABLED
		_player.visible = false
		for child: Node in _player.get_children():
			if child is CanvasLayer and child.visible:
				child.visible = false
				_hidden_layers.append(child)
	_enemies = owner.get_node_or_null(^"Enemies") as Node3D if owner != null else null
	if _enemies != null:
		_enemies.process_mode = Node.PROCESS_MODE_DISABLED
		_enemies.visible = false
	_camera.make_current()
	if SceneManager.busy:
		await SceneManager.load_scene_finished
	_play()


func _play() -> void:
	var walk_time := walk_from.distance_to(walk_to) / walk_speed
	var out := 1.0 + walk_time  # stepped out onto the pavement
	var end := out + 3.0
	var face_door := _yaw(door_handle - walk_to)
	var face_street := _yaw(face_at_end)
	var t := create_tween().set_parallel()
	_timeline = t
	t.tween_property(_cover, ^"modulate:a", 0.0, fade_time)
	t.tween_property(_camera, ^"position", camera_to, end + fade_time).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_play_door.bind(&"door_open")).set_delay(0.6)
	t.tween_callback(_anim.play.bind(&"Walking", 0.25)).set_delay(1.0)
	t.tween_property(_actor, ^"position", walk_to, walk_time).set_delay(1.0)
	t.tween_property(self, ^"_look", look_player, walk_time).set_delay(1.0).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_anim.play.bind(&"Idle", 0.3)).set_delay(out)
	t.tween_method(_turn.bind(_actor.rotation.y, face_door), 0.0, 1.0, 0.45).set_delay(out + 0.1)
	t.tween_callback(_anim.play.bind(&"TouchOrb", 0.2)).set_delay(out + 0.4)
	t.tween_callback(_play_door.bind(&"door_close")).set_delay(out + 0.85)
	t.tween_callback(_anim.play.bind(&"Idle", 0.4)).set_delay(out + 1.7)
	t.tween_method(_turn.bind(face_door, face_street), 0.0, 1.0, 0.6).set_delay(out + 1.9)
	t.tween_property(_cover, ^"modulate:a", 1.0, fade_time).set_delay(end)
	t.finished.connect(_finish)


## Fades out (if not already black), hands control to the player where the
## walk ends, and fades back in.
func _finish() -> void:
	if _done:
		return
	_done = true
	if _timeline != null:
		_timeline.kill()
	if _cover.modulate.a < 1.0:
		var out := create_tween()
		out.tween_property(_cover, ^"modulate:a", 1.0, fade_time * (1.0 - _cover.modulate.a))
		await out.finished
	if _door != null and _door.has_animation(&"door_close"):
		_door.play(&"door_close")
		_door.seek(_door.current_animation_length, true)
	if _player != null:
		_player.place_at(global_transform * Transform3D(Basis(Vector3.UP, _yaw(face_at_end)), walk_to))
		_player.process_mode = Node.PROCESS_MODE_INHERIT
		_player.visible = true
		for layer: CanvasLayer in _hidden_layers:
			layer.visible = true
		_player.camera().make_current()
	if _enemies != null:
		_enemies.process_mode = Node.PROCESS_MODE_INHERIT
		_enemies.visible = true
	_actor.visible = false
	var back := create_tween()
	back.tween_property(_cover, ^"modulate:a", 0.0, fade_time)
	await back.finished
	queue_free()


func _play_door(clip: StringName) -> void:
	if _door != null and _door.has_animation(clip):
		_door.play(clip)


func _turn(weight: float, from: float, to: float) -> void:
	_actor.rotation.y = lerp_angle(from, to, weight)


## Yaw that points the actor's front (-Z, like the player's Facing) along direction.
static func _yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)
