class_name Player
extends CharacterBody3D
## Player controller: movement + jump, light combo / heavy attack, dash with
## i-frames, and lock-on. Combat numbers live in the PlayerStats resource.
##
## The body itself never rotates: CameraRig holds the camera yaw (movement is
## relative to it) and Facing turns the mesh and hitbox toward movement/target.

enum ActionState { FREE, ATTACKING, DASHING, HURT, DEAD }
enum BufferedAction { NONE, LIGHT, HEAVY, DASH }

const NO_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const HIT_FLASH_TIME: float = 0.12
const IFRAME_COLOR: Color = Color(0.4, 0.9, 1.0, 0.45)
const HEAVY_WINDUP_COLOR: Color = Color(1.0, 0.55, 0.1, 0.6)
const LOCK_ON_MARKER_HEIGHT: float = 2.4
const RESPAWN_DELAY: float = 1.5

@export var stats: PlayerStats
@export var mouse_sensitivity: float = 0.0025
@export_range(0.0, 89.0) var pitch_limit_degrees: float = 70.0

var lock_target: Enemy = null
var action_state: ActionState = ActionState.FREE

var _state_time: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _buffered: BufferedAction = BufferedAction.NONE
var _buffer_timer: float = 0.0

var _current_attack: AttackData = null
## Index into stats.light_combo of the current/last light attack; -1 when not in a light combo.
var _combo_index: int = -1

var _dash_direction: Vector3 = Vector3.ZERO
var _dash_cooldown_timer: float = 0.0
var _invulnerable_timer: float = 0.0
var _hit_flash_timer: float = 0.0

@onready var health: Health = $Health
@onready var _facing: Node3D = $Facing
@onready var _body_mesh: MeshInstance3D = $Facing/Body
@onready var _hitbox: Hitbox = $Facing/Hitbox
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _camera_rig: Node3D = $CameraRig
@onready var _spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var _lock_on_marker: Node3D = $LockOnMarker


func _ready() -> void:
	InputBindings.ensure_defaults()
	add_to_group(&"player")
	health.setup(stats.max_health)
	health.died.connect(_on_died)
	_hurtbox.hit_received.connect(_on_hit_received)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# First click only recaptures the mouse; it shouldn't also attack.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if lock_target == null:
			_rotate_camera((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed(&"attack_light"):
		_buffer_action(BufferedAction.LIGHT)
	elif event.is_action_pressed(&"attack_heavy"):
		_buffer_action(BufferedAction.HEAVY)
	elif event.is_action_pressed(&"dash"):
		_buffer_action(BufferedAction.DASH)
	elif event.is_action_pressed(&"lock_on"):
		_toggle_lock_on()


func _physics_process(delta: float) -> void:
	_state_time += delta
	_tick_timers(delta)
	_validate_lock_target()

	match action_state:
		ActionState.FREE:
			_process_free(delta)
		ActionState.ATTACKING:
			_process_attack(delta)
		ActionState.DASHING:
			_process_dash()
		ActionState.HURT:
			_process_hurt(delta)
		ActionState.DEAD:
			_move_horizontal(Vector3.ZERO, stats.deceleration, delta)

	if action_state != ActionState.DASHING and not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	_update_lock_on_camera(delta)
	_update_visuals()


# --- States -------------------------------------------------------------------

func _process_free(delta: float) -> void:
	var move_dir := _get_move_direction()
	var rate: float
	if not is_on_floor():
		rate = stats.air_acceleration
	elif move_dir != Vector3.ZERO:
		rate = stats.acceleration
	else:
		rate = stats.deceleration
	_move_horizontal(move_dir * stats.move_speed, rate, delta)

	if lock_target != null:
		_face_toward(lock_target.global_position - global_position, delta)
	elif move_dir != Vector3.ZERO:
		_face_toward(move_dir, delta)

	if Input.is_action_just_pressed(&"jump") and is_on_floor():
		velocity.y = stats.jump_velocity

	match _buffered:
		BufferedAction.LIGHT:
			_start_attack(stats.light_combo[0], 0)
		BufferedAction.HEAVY:
			_start_attack(stats.heavy_attack, -1)
		BufferedAction.DASH:
			_try_start_dash()


func _process_attack(delta: float) -> void:
	var attack := _current_attack
	var active_start := attack.startup_time
	var active_end := active_start + attack.active_time

	if _state_time < active_end:
		_set_horizontal_velocity(_facing_forward() * attack.lunge_speed)
	else:
		_move_horizontal(Vector3.ZERO, stats.deceleration, delta)

	if _state_time >= active_start and _state_time < active_end and not _hitbox.is_active():
		_hitbox.activate(attack, self)
	elif _state_time >= active_end and _hitbox.is_active():
		_hitbox.deactivate()

	if _state_time < active_end:
		return
	# Recovery: this is the combo window.
	if _try_chain():
		return
	if _state_time >= active_end + attack.recovery_time:
		_combo_index = -1
		_set_state(ActionState.FREE)


func _process_dash() -> void:
	_set_horizontal_velocity(_dash_direction * stats.dash_speed)
	velocity.y = 0.0
	if _state_time >= stats.dash_duration:
		_set_horizontal_velocity(_dash_direction * stats.move_speed)
		_set_state(ActionState.FREE)


func _process_hurt(delta: float) -> void:
	_move_horizontal(Vector3.ZERO, stats.deceleration * 0.5, delta)
	if _state_time >= stats.hurt_stun_time:
		_set_state(ActionState.FREE)


# --- Actions ------------------------------------------------------------------

func _buffer_action(action: BufferedAction) -> void:
	_buffered = action
	_buffer_timer = stats.input_buffer_time


func _clear_buffer() -> void:
	_buffered = BufferedAction.NONE
	_buffer_timer = 0.0


## Called during attack recovery. Light chains to the next combo hit, heavy can
## follow any light hit, and dash cancels recovery.
func _try_chain() -> bool:
	match _buffered:
		BufferedAction.LIGHT:
			var next_index := _combo_index + 1
			if _combo_index >= 0 and next_index < stats.light_combo.size():
				_start_attack(stats.light_combo[next_index], next_index)
				return true
		BufferedAction.HEAVY:
			if _combo_index >= 0:
				_start_attack(stats.heavy_attack, -1)
				return true
		BufferedAction.DASH:
			return _try_start_dash()
	return false


func _start_attack(attack: AttackData, combo_index: int) -> void:
	_clear_buffer()
	_hitbox.deactivate()
	_current_attack = attack
	_combo_index = combo_index
	# Aim: locked target first, otherwise the direction being held.
	if lock_target != null:
		_snap_facing(lock_target.global_position - global_position)
	else:
		var move_dir := _get_move_direction()
		if move_dir != Vector3.ZERO:
			_snap_facing(move_dir)
	_set_state(ActionState.ATTACKING)


func _try_start_dash() -> bool:
	if _dash_cooldown_timer > 0.0:
		return false
	_clear_buffer()
	_hitbox.deactivate()
	_combo_index = -1
	_dash_direction = _get_move_direction().normalized()
	if _dash_direction == Vector3.ZERO:
		_dash_direction = -_facing_forward()  # No direction held: backstep.
	_invulnerable_timer = maxf(_invulnerable_timer, stats.dash_iframe_time)
	_dash_cooldown_timer = stats.dash_duration + stats.dash_cooldown
	_set_state(ActionState.DASHING)
	return true


func _set_state(new_state: ActionState) -> void:
	action_state = new_state
	_state_time = 0.0


func _tick_timers(delta: float) -> void:
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered = BufferedAction.NONE
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	_hurtbox.invulnerable = _invulnerable_timer > 0.0 or action_state == ActionState.DEAD


# --- Damage -------------------------------------------------------------------

func _on_hit_received(attack: AttackData, source: Node3D) -> void:
	health.take_damage(attack.damage)
	_hit_flash_timer = HIT_FLASH_TIME
	if health.is_dead:
		return
	var push := global_position - source.global_position
	push.y = 0.0
	_hitbox.deactivate()
	_combo_index = -1
	_clear_buffer()
	_set_horizontal_velocity(push.normalized() * attack.knockback)
	_invulnerable_timer = stats.post_hit_invulnerability
	_set_state(ActionState.HURT)


func _on_died() -> void:
	_hitbox.deactivate()
	lock_target = null
	_set_state(ActionState.DEAD)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(get_tree().reload_current_scene)


# --- Lock-on & camera -----------------------------------------------------------

func _toggle_lock_on() -> void:
	lock_target = null if lock_target != null else _find_nearest_enemy()


func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := stats.lock_on_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _validate_lock_target() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or not lock_target.is_alive() \
			or global_position.distance_to(lock_target.global_position) > stats.lock_on_break_range:
		lock_target = null


func _rotate_camera(relative: Vector2) -> void:
	_camera_rig.rotate_y(-relative.x * mouse_sensitivity)
	var pitch_limit := deg_to_rad(pitch_limit_degrees)
	_spring_arm.rotation.x = clampf(_spring_arm.rotation.x - relative.y * mouse_sensitivity, -pitch_limit, pitch_limit)


## While locked on, swing the camera behind the player facing the target so both stay framed.
func _update_lock_on_camera(delta: float) -> void:
	_lock_on_marker.visible = lock_target != null
	if lock_target == null:
		return
	_lock_on_marker.global_position = lock_target.global_position + Vector3.UP * LOCK_ON_MARKER_HEIGHT
	var to_target := lock_target.global_position - global_position
	to_target.y = 0.0
	var weight := 1.0 - exp(-stats.lock_on_camera_speed * delta)
	if to_target.length_squared() > 0.01:
		var yaw := atan2(-to_target.x, -to_target.z)
		_camera_rig.rotation.y = lerp_angle(_camera_rig.rotation.y, yaw, weight)
	_spring_arm.rotation.x = lerpf(_spring_arm.rotation.x, deg_to_rad(stats.lock_on_pitch_degrees), weight)


# --- Helpers ------------------------------------------------------------------

## Camera-relative input direction on the XZ plane (length 0..1).
func _get_move_direction() -> Vector3:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := _camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	return direction.normalized() * input.length()


func _facing_forward() -> Vector3:
	var forward := -_facing.global_basis.z
	forward.y = 0.0
	return forward.normalized()


func _face_toward(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	_facing.rotation.y = lerp_angle(_facing.rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func _snap_facing(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_facing.rotation.y = atan2(-direction.x, -direction.z)


func _move_horizontal(desired: Vector3, rate: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(desired.x, 0.0, desired.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func _set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _update_visuals() -> void:
	var flash := NO_COLOR
	if _hit_flash_timer > 0.0:
		flash = HIT_FLASH_COLOR
	elif action_state == ActionState.DASHING and _invulnerable_timer > 0.0:
		flash = IFRAME_COLOR
	elif action_state == ActionState.ATTACKING and _current_attack == stats.heavy_attack \
			and _state_time < _current_attack.startup_time:
		flash = Color(HEAVY_WINDUP_COLOR, HEAVY_WINDUP_COLOR.a * _state_time / _current_attack.startup_time)
	_body_mesh.set_instance_shader_parameter(&"flash_color", flash)
