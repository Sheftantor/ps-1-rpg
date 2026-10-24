class_name EnemyHudVisibility
extends Node
## Fades an enemy's floating HUD (its FloatingHealthBar parent: the health bar
## and level badge, both on one billboard) by distance from the
## camera and hides it when world geometry is in the way. Fully visible up to
## full_opacity_distance, fading out by hide_distance and hidden (not drawn,
## not rendered) beyond. A ray from the camera to the HUD anchor (the bar,
## above the head) checks the view a few times a second, staggered per enemy.
## The lock-on target and enemies hit in the last hit_reveal_time seconds show
## fully at any distance up to reveal_max_distance (walls still hide them).
## Opacity always eases toward its target, never pops; on death it hides at
## once. Settings are shared: res://resources/ui/enemy_hud_settings.tres.
## Only the enemy bar scene has this; the player's own bar is unaffected.

@export var settings: EnemyHudSettings = preload("res://resources/ui/enemy_hud_settings.tres")

var _bar: Node3D = null
var _display: Sprite3D = null
var _canvas: SubViewport = null
var _enemy: Node = null
var _player: Player = null
var _alpha: float = 0.0
var _shown: bool = true
var _dead: bool = false
var _in_range: bool = false
var _in_sight: bool = true
## Seconds until the next line-of-sight check (randomized so enemies spread out).
var _los_timer: float = 0.0
var _last_hit_time: float = -INF


func _ready() -> void:
	_bar = get_parent() as Node3D
	_display = _bar.get_node(^"Display") as Sprite3D
	_canvas = _bar.get_node(^"Canvas") as SubViewport
	_enemy = _bar.get_parent()
	_los_timer = randf() / maxf(settings.los_check_rate, 0.1)
	var health := _bar.get_node(_bar.get(&"health_path")) as Health
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_apply()


func _process(delta: float) -> void:
	if _dead:
		return
	var camera := _bar.get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := camera.global_position.distance_to(_bar.global_position)
	var revealed := distance <= settings.reveal_max_distance and (_is_lock_target() \
			or Time.get_ticks_msec() / 1000.0 - _last_hit_time <= settings.hit_reveal_time)
	var in_range := revealed or distance < settings.hide_distance
	if in_range and not _in_range:
		# Just came into range: check the view now rather than trusting an old result.
		_los_timer = 0.0
	_in_range = in_range
	var target := 0.0
	if in_range and _in_sight:
		target = 1.0 if revealed else clampf(inverse_lerp(settings.hide_distance,
				settings.full_opacity_distance, distance), 0.0, 1.0)
	_alpha = move_toward(_alpha, target, settings.fade_speed * delta)
	_apply()


func _physics_process(delta: float) -> void:
	if _dead or not _in_range:
		return
	_los_timer -= delta
	if _los_timer > 0.0:
		return
	_los_timer += 1.0 / maxf(settings.los_check_rate, 0.1)
	var camera := _bar.get_viewport().get_camera_3d()
	if camera == null:
		return
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, _bar.global_position, settings.los_mask)
	_in_sight = _bar.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Current opacity, 0-1 (for tests and debugging).
func get_alpha() -> float:
	return _alpha


func _apply() -> void:
	_display.modulate.a = _alpha
	var shown := _alpha > 0.001
	if shown == _shown:
		return
	_shown = shown
	_display.visible = shown
	# A hidden HUD's SubViewport stops re-rendering, so far enemies cost nothing.
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED


func _is_lock_target() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player != null and _player.lock_target == _enemy


func _on_damaged(_amount: int) -> void:
	_last_hit_time = Time.get_ticks_msec() / 1000.0


func _on_died() -> void:
	_dead = true
	_alpha = 0.0
	_apply()
