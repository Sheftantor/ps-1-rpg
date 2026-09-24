class_name Player
extends CharacterBody3D
## Player controller. Behaviour lives in the StateMachine child (one script per
## state in res://scripts/player/states/); this script owns the body, the input
## buffer, damage handling, camera/lock-on, and the helpers those states use.
## Numbers live in the PlayerStats resource; skills and items in PlayerLoadout.
##
## The body itself never rotates: CameraRig holds the camera yaw (movement is
## relative to it) and Facing turns the mesh and hitbox toward movement/target.

## Buffered action names. Direct input and command-menu picks both go through
## buffer_action(), so choosing Attack from the menu is the same as pressing it.
const ACTION_LIGHT: StringName = &"attack_light"
const ACTION_HEAVY: StringName = &"attack_heavy"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_JUMP: StringName = &"jump"
const ACTION_SKILL: StringName = &"skill"
const ACTION_ITEM: StringName = &"item"
const BUTTON_ACTIONS: Array[StringName] = [ACTION_LIGHT, ACTION_HEAVY, ACTION_DODGE, ACTION_JUMP]

const NO_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const BLOCK_FLASH_COLOR: Color = Color(0.5, 0.75, 1.0, 0.85)
const HIT_FLASH_TIME: float = 0.12
const LOCK_ON_MARKER_HEIGHT: float = 2.4
const RESPAWN_DELAY: float = 1.5

@export var stats: PlayerStats
@export var loadout: PlayerLoadout
@export var mouse_sensitivity: float = 0.0025
## Right-stick camera speed at full tilt (radians per second).
@export var stick_look_speed: float = 3.0
@export_range(0.0, 89.0) var pitch_limit_degrees: float = 70.0

@export_group("Debug")
## The debug_hurt input (K / Back) hits the player through the hurtbox, so
## dodge i-frames and blocking apply to it.
@export var debug_hit_damage: int = 15
@export var debug_hit_knockback: float = 4.0

var lock_target: Enemy = null
## The player's copy of loadout.inventory; items are spent from this.
var inventory: Array[ItemStack] = []
## Set by states each tick for their visual cue (wind-up, i-frames, guard).
var state_flash: Color = NO_COLOR
## What happened to the last incoming hit, for the debug HUD.
var last_hit_result: String = "-"

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _buffered: StringName = &""
var _buffered_payload: Resource = null
var _buffer_timer: float = 0.0

var _post_hit_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _hit_flash_color: Color = HIT_FLASH_COLOR
var _debug_hit: AttackData

@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina
@onready var state_machine: StateMachine = $StateMachine
@onready var command_menu: CommandMenu = $CommandMenu
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var _facing: Node3D = $Facing
@onready var _body_mesh: MeshInstance3D = $Facing/Body
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _camera_rig: Node3D = $CameraRig
@onready var _spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var _lock_on_marker: Node3D = $LockOnMarker


func _ready() -> void:
	InputBindings.ensure_defaults()
	add_to_group(&"player")
	health.setup(stats.max_health)
	health.died.connect(_on_died)
	stamina.setup(stats.max_stamina, stats.stamina_regen_delay)
	_hurtbox.hit_received.connect(_on_hit_received)

	for stack: ItemStack in loadout.inventory:
		inventory.append(stack.duplicate() as ItemStack)
	command_menu.setup(loadout.skills, inventory, can_use_command)
	command_menu.attack_selected.connect(buffer_action.bind(ACTION_LIGHT, null))
	command_menu.skill_selected.connect(func(skill: SkillData) -> void: buffer_action(ACTION_SKILL, skill))
	command_menu.item_selected.connect(func(stack: ItemStack) -> void: buffer_action(ACTION_ITEM, stack))

	_debug_hit = AttackData.new()
	_debug_hit.display_name = "Debug hit"
	_debug_hit.damage = debug_hit_damage
	_debug_hit.knockback = debug_hit_knockback

	state_machine.start(self)
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
			var relative := (event as InputEventMouseMotion).relative
			_rotate_camera(-relative.x * mouse_sensitivity, -relative.y * mouse_sensitivity)
		return
	# Keyboard only: the default ui_cancel also includes gamepad B, which is dodge.
	if event is InputEventKey and event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed(&"debug_hurt"):
		_debug_hurt()
	elif event.is_action_pressed(&"lock_on"):
		_toggle_lock_on()
	elif not command_menu.is_open:
		# While the menu is open it owns the buttons (they double as menu controls).
		for action: StringName in BUTTON_ACTIONS:
			if event.is_action_pressed(action):
				buffer_action(action)
				return


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_validate_lock_target()
	_apply_stick_look(delta)

	state_flash = NO_COLOR
	if not is_on_floor():
		velocity.y -= _gravity * delta
	state_machine.physics_update(delta)
	move_and_slide()

	_hurtbox.invulnerable = _post_hit_timer > 0.0 or current_state().is_invulnerable()
	_update_lock_on_camera(delta)
	_update_visuals()


func current_state() -> PlayerState:
	return state_machine.current as PlayerState


# --- Input buffer ---------------------------------------------------------------

## Queues an action for the current state to pick up when it's able to, within
## stats.input_buffer_time. A newer action replaces an older one.
func buffer_action(action: StringName, payload: Resource = null) -> void:
	_buffered = action
	_buffered_payload = payload
	_buffer_timer = stats.input_buffer_time


func peek_buffer() -> StringName:
	return _buffered


## Clears the buffer and returns the buffered action's payload (skill/item), if any.
func consume_buffer() -> Resource:
	var payload := _buffered_payload
	_clear_buffer()
	return payload


func _clear_buffer() -> void:
	_buffered = &""
	_buffered_payload = null
	_buffer_timer = 0.0


# --- Actions --------------------------------------------------------------------

func can_dodge() -> bool:
	return stamina.has(stats.dodge_stamina_cost)


func wants_block() -> bool:
	return not command_menu.is_open and Input.is_action_pressed(&"block")


## Spends the skill's stamina and enters its state. Returns false if it can't.
func start_skill(skill: SkillData) -> bool:
	if skill == null:
		return false
	if not state_machine.has_state(skill.state):
		push_warning("Skill '%s' names no player state '%s'." % [skill.display_name, skill.state])
		return false
	if not stamina.spend(skill.stamina_cost):
		return false
	state_machine.transition_to(skill.state, {"attack": skill.attack})
	return true


func use_item(stack: ItemStack) -> void:
	if stack == null or stack.count <= 0 or not inventory.has(stack):
		return
	health.heal(stack.item.heal_amount)
	stamina.restore(stack.item.stamina_restore)
	stack.count -= 1
	if stack.count <= 0:
		inventory.erase(stack)


## For the command menu: whether a SkillData/ItemStack entry can be picked now.
func can_use_command(entry: Resource) -> bool:
	if entry is SkillData:
		return stamina.has((entry as SkillData).stamina_cost)
	if entry is ItemStack:
		return (entry as ItemStack).count > 0
	return true


## Faces the lock target, or the held direction, at the start of an attack.
func aim_attack() -> void:
	if lock_target != null:
		snap_facing(lock_target.global_position - global_position)
	else:
		var move_dir := get_move_direction()
		if move_dir != Vector3.ZERO:
			snap_facing(move_dir)


func _tick_timers(delta: float) -> void:
	_buffer_timer -= delta
	if _buffer_timer <= 0.0:
		_buffered = &""
		_buffered_payload = null
	_post_hit_timer = maxf(_post_hit_timer - delta, 0.0)
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	stamina.regenerate(delta, stats.stamina_regen * current_state().stamina_regen_scale())


# --- Damage ---------------------------------------------------------------------

func _on_hit_received(attack: AttackData, source: Node3D) -> void:
	# Caught browsing: nothing pauses for the menu, and a hit knocks you out of it.
	command_menu.close()
	var push := _knockback_direction(source) * attack.knockback

	var guard_broken := false
	if current_state().is_blocking():
		if stamina.spend(attack.damage * stats.block_stamina_per_damage):
			last_hit_result = "blocked"
			_flash(BLOCK_FLASH_COLOR)
			set_horizontal_velocity(push * stats.block_knockback_scale)
			health.take_damage(roundi(attack.damage * stats.block_damage_multiplier))
			return
		stamina.drain(stamina.current)
		guard_broken = true

	last_hit_result = "guard broken" if guard_broken else "hit"
	health.take_damage(attack.damage)
	_flash(HIT_FLASH_COLOR)
	if health.is_dead:
		return
	_clear_buffer()
	_post_hit_timer = stats.post_hit_invulnerability
	state_machine.transition_to(PlayerState.HIT_STUN, {"knockback": push, "guard_break": guard_broken})


func _debug_hurt() -> void:
	if not _hurtbox.receive_hit(_debug_hit, null):
		last_hit_result = "dodged (i-frames)" if state_machine.current_name() == PlayerState.DODGE else "invulnerable"


## Away from the source, or straight back when there isn't one.
func _knockback_direction(source: Node3D) -> Vector3:
	if source != null and is_instance_valid(source):
		var away := global_position - source.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			return away.normalized()
	return -forward()


func _flash(color: Color) -> void:
	_hit_flash_color = color
	_hit_flash_timer = HIT_FLASH_TIME


func _on_died() -> void:
	hitbox.deactivate()
	lock_target = null
	command_menu.close()
	command_menu.enabled = false
	state_machine.transition_to(PlayerState.DEAD)
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


func _rotate_camera(yaw: float, pitch: float) -> void:
	_camera_rig.rotate_y(yaw)
	var pitch_limit := deg_to_rad(pitch_limit_degrees)
	_spring_arm.rotation.x = clampf(_spring_arm.rotation.x + pitch, -pitch_limit, pitch_limit)


func _apply_stick_look(delta: float) -> void:
	if lock_target != null:
		return
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look != Vector2.ZERO:
		_rotate_camera(-look.x * stick_look_speed * delta, -look.y * stick_look_speed * delta)


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


# --- Movement helpers (used by states) --------------------------------------------

## Camera-relative input direction on the XZ plane (length 0..1). Zero while the
## command menu is open, since the stick is navigating it.
func get_move_direction() -> Vector3:
	if command_menu.is_open:
		return Vector3.ZERO
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction := _camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	direction.y = 0.0
	return direction.normalized() * input.length()


## Accelerates toward the held direction at speed and turns to face the lock
## target, or (if turn_to_move) the movement direction.
func locomote(delta: float, speed: float, turn_to_move: bool = true) -> void:
	var move_dir := get_move_direction()
	var rate: float
	if not is_on_floor():
		rate = stats.air_acceleration
	elif move_dir != Vector3.ZERO:
		rate = stats.acceleration
	else:
		rate = stats.deceleration
	move_horizontal(move_dir * speed, rate, delta)

	if lock_target != null:
		face_toward(lock_target.global_position - global_position, delta)
	elif turn_to_move and move_dir != Vector3.ZERO:
		face_toward(move_dir, delta)


func forward() -> Vector3:
	var dir := -_facing.global_basis.z
	dir.y = 0.0
	return dir.normalized()


func face_toward(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	_facing.rotation.y = lerp_angle(_facing.rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


func snap_facing(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_facing.rotation.y = atan2(-direction.x, -direction.z)


func move_horizontal(desired: Vector3, rate: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(desired.x, 0.0, desired.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


func _update_visuals() -> void:
	var flash := state_flash
	if _hit_flash_timer > 0.0:
		flash = _hit_flash_color
	_body_mesh.set_instance_shader_parameter(&"flash_color", flash)
