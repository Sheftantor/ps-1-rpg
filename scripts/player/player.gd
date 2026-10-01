class_name Player
extends CharacterBody3D
## Player controller. Behaviour lives in the StateMachine child (one script per
## state in res://scripts/player/states/); this script owns the body, the input
## buffer, damage handling, camera/lock-on, and the helpers those states use.
## Numbers live in the PlayerStats resource; skills and items in PlayerLoadout.
##
## The body itself never rotates: CameraRig holds the camera yaw (movement is
## relative to it) and Facing turns the mesh and hitbox toward movement/target.

## Buffered action names. Inputs go through buffer_action() so a press made
## mid-swing or mid-roll still happens once the player is free to act.
const ACTION_LIGHT: StringName = &"attack_light"
const ACTION_HEAVY: StringName = &"attack_heavy"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_JUMP: StringName = &"jump"
const ACTION_SKILL: StringName = &"skill"
## Uses the selected inventory item (payload: its ItemStack); the use_item input.
const ACTION_ITEM: StringName = &"item"
const ACTION_INTERACT: StringName = &"interact"
## Draw the gun into time-stop targeting (GunAim), or back out of it.
const ACTION_GUN: StringName = &"gun_mode"
## Gun mode: take a queued target back off the shot queue.
const ACTION_GUN_UNDO: StringName = &"gun_undo"
## Opens the player stats and gear screen.
const ACTION_STATUS: StringName = &"status_menu"
const BUTTON_ACTIONS: Array[StringName] = [ACTION_LIGHT, ACTION_HEAVY, ACTION_DODGE, ACTION_JUMP, ACTION_INTERACT, ACTION_GUN,
		ACTION_GUN_UNDO, ACTION_STATUS]

const NO_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const BLOCK_FLASH_COLOR: Color = Color(0.5, 0.75, 1.0, 0.85)
const HIT_FLASH_TIME: float = 0.12
const LOCK_ON_MARKER_HEIGHT: float = 2.4
const RESPAWN_DELAY: float = 1.5

## Action clips on the model, built by res://scripts/tools/build_player_animations.gd.
## They play through the AnimationTree's two alternating one-shot slots
## (ActionA/ShotA, ActionB/ShotB), so a combo hit crossfades into a fresh swing.
const ANIM_ATTACK: StringName = &"Attack"
const ANIM_STRONG_ATTACK: StringName = &"StrongAttack"
const ANIM_AIR_ATTACK: StringName = &"AirAttack"
const ANIM_AIR_STRONG_ATTACK: StringName = &"AirStrongAttack"
const ANIM_ROLL: StringName = &"Roll"
const ANIM_AIM_FIRE: StringName = &"AimFire"
const ACTION_SLOTS: PackedStringArray = ["A", "B"]
## AnimationTree parameters (see the tree in build_player_animations.gd).
const TREE_LOCOMOTION: StringName = &"parameters/Locomotion/blend_position"
const TREE_LOCOMOTION_SPEED: StringName = &"parameters/LocoSpeed/scale"
const TREE_AIR_REQUEST: StringName = &"parameters/Air/transition_request"
const TREE_AIR_STATE: StringName = &"parameters/Air/current_state"
const TREE_JUMP_SEEK: StringName = &"parameters/JumpSeek/seek_request"
const TREE_JUMP_ARMS: StringName = &"parameters/JumpArms/blend_amount"
const TREE_AIM: StringName = &"parameters/AimBlend/blend_amount"
## How fast the upper body raises/lowers the gun (blend per second).
const AIM_BLEND_SPEED: float = 8.0
## Where the sheathed melee weapon rides while the gun is out, in Facing space: grip at
## the left hip, blade angled down and back.
const SHEATH_OFFSET: Vector3 = Vector3(-0.22, 0.95, 0.08)
const SHEATH_BLADE_DIR: Vector3 = Vector3(0.0, -0.75, 0.66)
## Shots at a locked target are only stopped by the world (layer 1); an unaimed
## shot also hits character bodies (layer 3).
const SHOT_WORLD_MASK: int = 1
const SHOT_COLLISION_MASK: int = 1 | 4
const MUZZLE_FLASH_TIME: float = 0.06
## Ground speeds (m/s) each locomotion clip covers at 1x. The blend space puts
## walk at 1 and run at 2; playback is scaled so feet roughly match the ground.
const WALK_CLIP_SPEED: float = 1.7
const RUN_CLIP_SPEED: float = 4.4
const STRAFE_WALK_CLIP_SPEED: float = 0.9
const STRAFE_RUN_CLIP_SPEED: float = 1.65
## Where the Jump clip's falling pose starts, for walking off a ledge.
const JUMP_FALL_TIME: float = 0.7
## Airborne this long without jumping before the fall pose plays (slopes, steps).
const FALL_ANIM_DELAY: float = 0.12

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
## Index into inventory of the item use_item spends; next_item steps it.
var selected_item: int = 0
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
var _air_time: float = 0.0
## Every mesh on the model (body and weapons), for hit/state flashes.
var _flash_meshes: Array[GeometryInstance3D] = []
## The action clip last started in a one-shot slot, its playback position (clip
## seconds, tracked here because the tree doesn't expose it) and speed.
var _action_clip: StringName = &""
var _action_playing: bool = false
var _action_time: float = 0.0
var _action_speed: float = 1.0
var _action_slot: int = 0
## Whether the current airborne stretch started with a jump (not a ledge drop).
var _jumped: bool = false
## Primary weapon (bat, sword...), from the loadout.
var melee_weapon: MeleeWeaponData = null
## Secondary weapon slot (the melee weapon is always the primary). Null until a gun is picked up.
var gun: WeaponData = null
## Worn armour by slot, from the loadout; empty slots are absent.
var armor: Dictionary[ArmorData.Slot, ArmorData] = {}
var _gun_model: Node3D = null
var _aim_amount: float = 0.0
var _aim_target: float = 0.0
var _melee_holder: Node3D = null
var _melee_hand_transform: Transform3D
var _hip_attachment: BoneAttachment3D = null

@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina
@onready var state_machine: StateMachine = $StateMachine
## Strong attacks and skills use `hitbox`; the basic (horizontal) swing uses
## `swing_hitbox`, a wide flat band along the swipe, opened on the clip's hit frames.
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var swing_hitbox: Hitbox = $Facing/SwingHitbox
@onready var _facing: Node3D = $Facing
@onready var _anim: AnimationPlayer = $Facing/Model/AnimationPlayer
@onready var _anim_tree: AnimationTree = $Facing/Model/AnimationTree
@onready var _weapon_trail: WeaponTrail = $Facing/Model/Skeleton3D/RightHandAttachment/MeleeWeapon/WeaponTrail
@onready var _melee: Node3D = $Facing/Model/Skeleton3D/RightHandAttachment/MeleeWeapon
@onready var hud: PlayerHud = $PlayerHud
@onready var status_menu: StatusMenu = $StatusMenu
@onready var _range_dome: RangeDome = $RangeDome
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
	_equip_from_loadout()

	_debug_hit = AttackData.new()
	_debug_hit.display_name = "Debug hit"
	_debug_hit.damage = debug_hit_damage
	_debug_hit.knockback = debug_hit_knockback

	for node: Node in $Facing/Model.find_children("*", "GeometryInstance3D"):
		if node != _weapon_trail:
			_flash_meshes.append(node as GeometryInstance3D)
	_melee_holder = _melee.get_parent()
	_melee_hand_transform = _melee.transform
	hud.set_weapon(melee_name())
	health.changed.connect(hud.set_health)
	stamina.changed.connect(hud.set_stamina)
	hud.set_health(health.current, health.max_health)
	hud.set_stamina(stamina.current, stamina.maximum)
	_refresh_item_hud()
	# The action slots' clips are swapped at runtime, so use a private copy of the tree.
	_anim_tree.tree_root = _anim_tree.tree_root.duplicate(true)
	_anim_tree.active = true

	state_machine.start(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	# Never leave the game slowed or paused if the scene changes mid gun mode.
	Engine.time_scale = 1.0
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if PauseMenu.is_open or StatusMenu.is_open:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# First click only recaptures the mouse; it shouldn't also attack.
		if event is InputEventMouseButton and event.is_pressed():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if state_machine.current_name() == PlayerState.GUN_AIM:
			state_machine.current.on_mouse_motion((event as InputEventMouseMotion).relative.x)
		elif lock_target == null:
			var relative := (event as InputEventMouseMotion).relative
			_rotate_camera(-relative.x * mouse_sensitivity, -relative.y * mouse_sensitivity)
		return
	if event.is_action_pressed(&"debug_hurt"):
		_debug_hurt()
	elif event.is_action_pressed(&"lock_on"):
		if state_machine.current_name() == PlayerState.GUN_AIM:
			state_machine.current.cycle_target()
		else:
			_toggle_lock_on()
	elif event.is_action_pressed(&"target_next"):
		_cycle_target(1)
	elif event.is_action_pressed(&"target_prev"):
		_cycle_target(-1)
	elif event.is_action_pressed(&"next_item"):
		cycle_item(1)
	elif event.is_action_pressed(&"use_item"):
		var stack := selected_item_stack()
		if stack != null:
			buffer_action(ACTION_ITEM, stack)
	else:
		for action: StringName in BUTTON_ACTIONS:
			if event.is_action_pressed(action):
				buffer_action(action)
				return


func _physics_process(delta: float) -> void:
	# Gun mode keeps the player processing through pauses; the pause menu stops it.
	if PauseMenu.is_open or StatusMenu.is_open:
		return
	_tick_timers(delta)
	_validate_lock_target()
	_apply_stick_look(delta)

	state_flash = NO_COLOR
	# While gun mode has the world paused, the player keeps processing but must not
	# fall (or build up fall speed to release all at once on resume).
	if not is_on_floor() and not get_tree().paused:
		velocity.y -= _gravity * delta
	state_machine.physics_update(delta)
	# Gun mode pauses the tree (and physics) while the player keeps processing.
	if not get_tree().paused:
		move_and_slide()

	_hurtbox.invulnerable = _post_hit_timer > 0.0 or current_state().is_invulnerable()
	_update_lock_on_camera(delta)
	_update_animation(delta)
	_update_visuals()
	_update_pickup_prompt()


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
	return Input.is_action_pressed(&"block")


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
	_refresh_item_hud()


## The item use_item spends, or null with an empty inventory.
func selected_item_stack() -> ItemStack:
	if inventory.is_empty():
		return null
	selected_item = clampi(selected_item, 0, inventory.size() - 1)
	return inventory[selected_item]


func cycle_item(step: int) -> void:
	if inventory.is_empty():
		return
	selected_item = posmod(selected_item + step, inventory.size())
	_refresh_item_hud()


func _refresh_item_hud() -> void:
	var stack := selected_item_stack()
	hud.set_item("%s x%d" % [stack.item.display_name, stack.count] if stack != null else "")


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
	if not get_tree().paused:
		stamina.regenerate(delta, stats.stamina_regen * current_state().stamina_regen_scale())


# --- Damage ---------------------------------------------------------------------

func _on_hit_received(attack: AttackData, source: Node3D) -> void:
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
	swing_hitbox.deactivate()
	lock_target = null
	state_machine.transition_to(PlayerState.DEAD)
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(get_tree().reload_current_scene)


# --- Lock-on & camera -----------------------------------------------------------

func _toggle_lock_on() -> void:
	lock_target = null if lock_target != null else _find_nearest_enemy()


## Mouse wheel / D-pad: moves the gun-mode cursor, or while locked on with the
## melee weapon, moves the lock to the next enemy in lock-on range (nearest first).
func _cycle_target(step: int) -> void:
	if state_machine.current_name() == PlayerState.GUN_AIM:
		state_machine.current.cycle_target(step)
		return
	if lock_target == null:
		return
	var candidates: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() and global_position.distance_to(enemy.global_position) <= stats.lock_on_range:
			candidates.append(enemy)
	if candidates.size() < 2:
		return
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	lock_target = candidates[posmod(candidates.find(lock_target) + step, candidates.size())]


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

## Camera-relative input direction on the XZ plane (length 0..1).
func get_move_direction() -> Vector3:
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
	for mesh: GeometryInstance3D in _flash_meshes:
		mesh.set_instance_shader_parameter(&"flash_color", flash)


# --- Weapons & pickups ------------------------------------------------------------

## Takes the melee weapon, gun and armour from the loadout and puts the melee
## weapon's model in the hand mount (replacing the scene's placeholder).
func _equip_from_loadout() -> void:
	melee_weapon = loadout.melee_weapon
	if gun == null:
		gun = loadout.gun
	var slots := {
		ArmorData.Slot.SHIRT: loadout.shirt, ArmorData.Slot.NECK: loadout.neck, ArmorData.Slot.ARMS: loadout.arms,
		ArmorData.Slot.BELT: loadout.belt, ArmorData.Slot.PANTS: loadout.pants, ArmorData.Slot.SHOES: loadout.shoes,
	}
	for slot: ArmorData.Slot in slots:
		if slots[slot] != null:
			armor[slot] = slots[slot]
	if melee_weapon != null and melee_weapon.model != null:
		var placeholder := _melee.get_node_or_null(^"Model")
		if placeholder != null:
			_melee.remove_child(placeholder)
			placeholder.queue_free()
		var model: Node3D = melee_weapon.model.instantiate()
		model.name = &"Model"
		_melee.add_child(model)
		_melee.move_child(model, 0)


func melee_name() -> String:
	return melee_weapon.display_name if melee_weapon != null else "Unarmed"


## Total defense of the worn armour.
func armor_defense() -> int:
	var total := 0
	for piece: ArmorData in armor.values():
		total += piece.defense
	return total


## Collects the nearest pickup in reach (interact input).
func interact() -> void:
	var pickup := nearest_pickup()
	if pickup == null:
		return
	if pickup.weapon != null:
		gun = pickup.weapon
		if _gun_model != null:
			_gun_model.queue_free()
			_gun_model = null
		hud.flash_message("GOT %s" % gun.display_name.to_upper())
	elif pickup.item != null:
		add_item(pickup.item)
		hud.flash_message("GOT %s" % pickup.display_name().to_upper())
	pickup.queue_free()


## Adds loot to the inventory, stacking onto a slot holding the same item.
func add_item(stack: ItemStack) -> void:
	for held: ItemStack in inventory:
		if held.item == stack.item:
			held.count += stack.count
			_refresh_item_hud()
			return
	inventory.append(stack.duplicate() as ItemStack)
	_refresh_item_hud()


func nearest_pickup() -> Pickup:
	var nearest: Pickup = null
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group(&"pickups"):
		var pickup := node as Pickup
		if pickup == null or pickup.is_queued_for_deletion() or not pickup.in_reach(global_position):
			continue
		var distance := global_position.distance_squared_to(pickup.global_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	return nearest


func _update_pickup_prompt() -> void:
	var pickup := nearest_pickup() if current_state().name != PlayerState.GUN_AIM else null
	hud.set_interact(ACTION_INTERACT, pickup.interact_verb if pickup != null else "")


## Gun mode: sheathes the melee weapon at the hip and puts the gun in its hand,
## or the reverse. The upper body blends to/from the aim pose.
func set_gun_drawn(drawn: bool) -> void:
	if drawn and gun != null:
		if _gun_model == null:
			_gun_model = gun.model.instantiate()
			_melee_holder.add_child(_gun_model)
			# Built in the melee weapon's grip convention, so it shares its mount.
			_gun_model.transform = _melee_hand_transform
			for node: Node in _gun_model.find_children("*", "GeometryInstance3D"):
				_flash_meshes.append(node as GeometryInstance3D)
		_gun_model.visible = true
		_sheathe_melee(true)
		_aim_target = 1.0
		hud.set_weapon(gun.display_name)
		_range_dome.show_range(gun.effective_range)
	else:
		if _gun_model != null:
			_gun_model.visible = false
		_sheathe_melee(false)
		_aim_target = 0.0
		hud.set_weapon(melee_name())
		_range_dome.hide_range()


func _sheathe_melee(sheathed: bool) -> void:
	if not sheathed:
		if _melee.get_parent() != _melee_holder:
			_melee.reparent(_melee_holder, false)
			_melee.transform = _melee_hand_transform
		return
	if _hip_attachment == null:
		_hip_attachment = BoneAttachment3D.new()
		_hip_attachment.bone_name = "mixamorig_Hips"
		$Facing/Model/Skeleton3D.add_child(_hip_attachment)
	var melee_scale := _melee.global_basis.get_scale()
	_melee.reparent(_hip_attachment)
	# Placed in world space once; from then on it rides along with the hips.
	var blade := _facing.global_basis * SHEATH_BLADE_DIR.normalized()
	var edge := (_facing.global_basis.z - blade * _facing.global_basis.z.dot(blade)).normalized()
	_melee.global_transform = Transform3D(Basis(edge, blade, edge.cross(blade)).scaled_local(melee_scale),
			_facing.global_transform * SHEATH_OFFSET)


## Resolves one shot at `target` (or straight ahead with none): a ray from the
## player's chest to the target's chest. Walls and props block it; other enemies
## don't, so a queued shot lands on the enemy that was locked. The hit goes
## through the enemy's Hurtbox like a melee hit, at full damage within the gun's
## effective range and reduced beyond it.
func fire_gun(target: Enemy) -> void:
	_play_action(ANIM_AIM_FIRE, 1.0)
	_show_muzzle_flash()
	var origin := aim_origin()
	var space := get_world_3d().direct_space_state
	var enemy := target
	if target != null:
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, aim_point(target), SHOT_WORLD_MASK, [get_rid()]))
		if not wall.is_empty():
			last_hit_result = "shot blocked"
			return
	else:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + forward() * gun.lock_range,
				SHOT_COLLISION_MASK, [get_rid()]))
		enemy = hit.get("collider") as Enemy
	if enemy == null or not enemy.is_alive():
		last_hit_result = "shot missed"
		return
	var attack := gun.shot
	if flat_distance_to(enemy) > gun.effective_range:
		attack = gun.shot.duplicate() as AttackData
		attack.damage = maxi(1, roundi(gun.shot.damage * gun.out_of_range_damage_scale))
	enemy.hurtbox.receive_hit(attack, self)
	last_hit_result = "shot %s for %d" % [enemy.name, attack.damage]


func _show_muzzle_flash() -> void:
	var flash := _gun_model.get_node_or_null("Muzzle/MuzzleFlash") as Node3D if _gun_model != null else null
	if flash == null:
		return
	flash.visible = true
	get_tree().create_timer(MUZZLE_FLASH_TIME, true, false, true).timeout.connect(func() -> void: flash.visible = false)


## Where shots leave from and where the targeting web starts: the player's chest.
func aim_origin() -> Vector3:
	return global_position + Vector3.UP * 1.3


## An enemy's chest, where shots and the reticle aim.
func aim_point(enemy: Enemy) -> Vector3:
	return enemy.global_position + Vector3.UP * 1.0


func flat_distance_to(node: Node3D) -> float:
	var offset := node.global_position - global_position
	offset.y = 0.0
	return offset.length()


func camera() -> Camera3D:
	return $CameraRig/SpringArm3D/Camera3D


# --- Animation ------------------------------------------------------------------
# The model's AnimationTree (built by build_player_animations.gd) has a base
# layer, locomotion blend space <-> jump, driven every tick from the body's
# motion, and two one-shot action slots on top that attacks and the roll fill.

## Plays the attack or strong attack swing (the air version while airborne),
## sped up or slowed to last `duration` so the swing lines up with the
## attack's startup/active/recovery timing.
func play_attack_animation(strong: bool, duration: float) -> void:
	var clip: StringName
	if is_on_floor():
		clip = ANIM_STRONG_ATTACK if strong else ANIM_ATTACK
	else:
		clip = ANIM_AIR_STRONG_ATTACK if strong else ANIM_AIR_ATTACK
	_play_action(clip, clampf(_anim.get_animation(clip).length / maxf(duration, 0.01), 0.5, 2.0))


## Plays the dodge roll stretched to `duration` seconds.
func play_roll_animation(duration: float) -> void:
	_play_action(ANIM_ROLL, _anim.get_animation(ANIM_ROLL).length / maxf(duration, 0.01))


## Frames in the Roll clip; the roll's i-frames are counted in these.
func roll_clip_frames() -> int:
	var clip := _anim.get_animation(ANIM_ROLL)
	return roundi(clip.length / clip.step)


## Whether the attack clip started by play_attack_animation() is on its hit
## frames: 1 if inside them, 0 if not, -1 if the clip has no "hit_frames" meta
## (the attack then falls back to its AttackData timing).
func attack_hit_frame_state() -> int:
	return _action_frame_state(&"hit_frames")


## 1 if the current action clip is within the frame range stored in `meta` on
## it, 0 if not (or it has finished), -1 if there's no clip or no such meta.
func _action_frame_state(meta: StringName) -> int:
	if _action_clip == &"":
		return -1
	var clip := _anim.get_animation(_action_clip)
	if not clip.has_meta(meta):
		return -1
	if not _action_playing:
		return 0
	var frames: Vector2i = clip.get_meta(meta)
	var frame := int(_action_time / clip.step)
	return 1 if frame >= frames.x and frame <= frames.y else 0


## Starts `clip` at `speed` in the idle one-shot slot, fading out whatever the
## other slot is playing, so back-to-back actions crossfade instead of popping.
func _play_action(clip: StringName, speed: float) -> void:
	var previous := ACTION_SLOTS[_action_slot]
	if _anim_tree.get("parameters/Shot%s/active" % previous):
		_anim_tree.set("parameters/Shot%s/request" % previous, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_action_slot = (_action_slot + 1) % ACTION_SLOTS.size()
	var slot := ACTION_SLOTS[_action_slot]
	var root := _anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node("Action" + slot) as AnimationNodeAnimation).animation = clip
	_anim_tree.set("parameters/Action%sSpeed/scale" % slot, speed)
	_anim_tree.set("parameters/Shot%s/request" % slot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_action_clip = clip
	_action_playing = true
	_action_time = 0.0
	_action_speed = speed


func _stop_actions() -> void:
	for slot in ACTION_SLOTS:
		if _anim_tree.get("parameters/Shot%s/active" % slot):
			_anim_tree.set("parameters/Shot%s/request" % slot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	_action_playing = false


func _update_animation(delta: float) -> void:
	_air_time = 0.0 if is_on_floor() else _air_time + delta
	if _action_playing:
		_action_time += delta * _action_speed
		if _action_time >= _anim.get_animation(_action_clip).length:
			_action_playing = false
	# A state that got interrupted (hit stun, death) leaves its action behind.
	if _action_playing and not current_state().drives_animation():
		_stop_actions()
	# Visual only: the blade streak follows each attack clip's trail frames.
	_weapon_trail.emitting = _action_frame_state(&"trail_frames") == 1
	_aim_amount = move_toward(_aim_amount, _aim_target, AIM_BLEND_SPEED * delta)
	_anim_tree.set(TREE_AIM, _aim_amount)
	_update_air_layer()
	_update_locomotion_layer()


## Crossfades to the Jump clip once airborne (from its fall pose after a ledge
## drop) and raises the arms with the jump curve: none at takeoff, fully up at
## the apex, back down as the fall speeds up again.
func _update_air_layer() -> void:
	var in_air: bool = _anim_tree.get(TREE_AIR_STATE) == "air"
	if is_on_floor():
		_jumped = false
		if in_air:
			_anim_tree.set(TREE_AIR_REQUEST, "ground")
	elif not in_air:
		var jumping := velocity.y > 0.0 and _air_time <= FALL_ANIM_DELAY
		if jumping or _air_time >= FALL_ANIM_DELAY:
			_jumped = jumping
			_anim_tree.set(TREE_AIR_REQUEST, "air")
			if not jumping:
				_anim_tree.set(TREE_JUMP_SEEK, JUMP_FALL_TIME)
	var arms_up := 0.0
	if _jumped:
		arms_up = clampf(1.0 - absf(velocity.y) / stats.jump_velocity, 0.0, 1.0)
	_anim_tree.set(TREE_JUMP_ARMS, arms_up)


## Feeds the locomotion blend space the ground velocity relative to facing, so
## locked-on and blocking movement (where facing stays on the target) blends
## forward/back/strafe clips into all 8 directions.
func _update_locomotion_layer() -> void:
	var local := _facing.global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var planar := Vector2(local.x, -local.z)  # (strafe right, forward) in m/s
	var speed := planar.length()
	if speed < 0.05:
		_anim_tree.set(TREE_LOCOMOTION, Vector2.ZERO)
		_anim_tree.set(TREE_LOCOMOTION_SPEED, 1.0)
		return
	# Gait: 0 idle, 1 walk, 2 run. Direction goes on a diamond (|x| + |y| = 1) so a
	# diagonal lands between the forward and strafe points of the same gait.
	var gait := speed / WALK_CLIP_SPEED
	if speed > WALK_CLIP_SPEED:
		gait = 1.0 + clampf((speed - WALK_CLIP_SPEED) / (RUN_CLIP_SPEED - WALK_CLIP_SPEED), 0.0, 1.0)
	var direction := planar / (absf(planar.x) + absf(planar.y))
	_anim_tree.set(TREE_LOCOMOTION, direction * gait)

	var run := clampf(gait - 1.0, 0.0, 1.0)
	var clip_speed := lerpf(
			lerpf(WALK_CLIP_SPEED, RUN_CLIP_SPEED, run),
			lerpf(STRAFE_WALK_CLIP_SPEED, STRAFE_RUN_CLIP_SPEED, run),
			absf(direction.x))
	_anim_tree.set(TREE_LOCOMOTION_SPEED, clampf(speed / clip_speed, 0.6, 2.5))
