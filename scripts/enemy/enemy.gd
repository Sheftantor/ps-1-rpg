class_name Enemy
extends CharacterBody3D
## Melee enemy. Behaviour lives in the StateMachine child (one script per state in
## res://scripts/enemy/states/); this script owns the body, senses, and the
## helpers those states use.

signal died

## Below this ground speed (m/s) the model stands instead of walking.
const WALK_ANIM_MIN_SPEED: float = 0.15

@export var stats: EnemyStats
## Size (world X/Z, m) of the box around the spawn point the enemy wanders in
## until it spots the player. Zero on an axis keeps it on a line; zero on both
## keeps it standing.
@export var patrol_area: Vector2 = Vector2(6.0, 6.0)
## This enemy's level for the level badge. 0 = use stats.level, so one stats
## resource can still be placed as tougher or weaker individuals.
@export_range(0, 99) var level_override: int = 0
## Multiplies the model's colours. A stand-in for real variants: tougher levels
## are recoloured until they get their own models.
@export var body_tint: Color = Color.WHITE

var target: Node3D = null
## The attack chosen for the current turn (set in Reposition, used through Recover).
var current_attack: AttackData = null
## Set by states to drive the telegraph visuals; alpha is flash strength.
var telegraph_flash: Color = Color(0.0, 0.0, 0.0, 0.0)
var pulse_scale: float = 1.0
## Where the enemy spawned; the centre of its patrol area.
var home_position: Vector3 = Vector3.ZERO
## The combo swing in progress (1-5), 0 outside a combo (see the Attack state).
var combo_swing: int = 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Whether max health has been scaled to the player's level yet.
var _scaled_to_player: bool = false
## Hit / kill flash (Feel): colour and seconds left.
var _hit_flash_color: Color = Color.WHITE
var _hit_flash_timer: float = 0.0
## Feel's hit push: extra velocity and seconds left.
var _push_velocity: Vector3 = Vector3.ZERO
var _push_timer: float = 0.0
## Seconds left of the post-combo vulnerability window.
var _vulnerable_timer: float = 0.0
## Seconds until the next combo may start.
var _combo_cooldown: float = 0.0

@onready var facing: Node3D = $Facing
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine
@onready var model: EnemyModel = $Facing/Model


func _ready() -> void:
	add_to_group(&"enemies")
	home_position = global_position
	health.setup(stats.max_health)
	model.set_tint(body_tint)
	health.died.connect(_award_xp)
	hurtbox.hit_received.connect(_on_hit_received)
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	# Hit stop (Feel): this enemy alone holds still for a moment.
	if Feel.is_frozen(self):
		return
	if not has_target():
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	if not _scaled_to_player:
		_scale_to_player()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	state_machine.physics_update(delta)
	if _push_timer > 0.0:
		# Feel's push rides on top of the state's own movement for one step.
		_push_timer -= delta
		var own_velocity := velocity
		velocity += _push_velocity
		move_and_slide()
		velocity.x = own_velocity.x
		velocity.z = own_velocity.z
	else:
		move_and_slide()
	_vulnerable_timer = maxf(_vulnerable_timer - delta, 0.0)
	_combo_cooldown = maxf(_combo_cooldown - delta, 0.0)
	_update_visuals(delta)
	_update_animation()


func _exit_tree() -> void:
	EnemyAttackCoordinator.release(self, 0.0)


func is_alive() -> bool:
	return not health.is_dead


## Open to punishment: staggered or off balance (see EnemyState.is_exposed()).
func is_exposed() -> bool:
	return (state_machine.current as EnemyState).is_exposed()


func has_target() -> bool:
	return target != null and is_instance_valid(target)


## Flat (XZ) distance to the target; INF when there is none.
func distance_to_target() -> float:
	if not has_target():
		return INF
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


## Flat (XZ) unit direction to the target.
func direction_to_target() -> Vector3:
	if not has_target():
		return Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.normalized()


func _award_xp() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var xp := player.award_kill(level()) if player != null else 0
	Feel.on_kill(self, xp)


func level() -> int:
	return level_override if level_override > 0 else stats.level


# --- Level scaling --------------------------------------------------------------
# Max health and hit damage follow the level gap to the player (LevelScaling,
# res://resources/combat_tuning.tres), from the bases in stats' Level Scaling group.

## Enemy level minus the player's level (0 without a player).
func level_gap() -> int:
	var player := _player()
	return level() - player.level if player != null else 0


func scaled_max_health() -> int:
	var player := _player()
	var base := float(stats.max_health)
	if stats.health_in_melee_hits > 0.0 and player != null:
		base = stats.health_in_melee_hits * LevelScaling.melee_damage(player.stats)
	return maxi(1, roundi(base * LevelScaling.health_multiplier(level_gap())))


## One hit's damage: stats.damage_percent of a same-level player's max health
## (or raw_damage when that's 0), scaled by the level gap.
func scaled_damage(raw_damage: int) -> int:
	var player := _player()
	var base := float(raw_damage)
	if stats.damage_percent > 0.0 and player != null:
		base = stats.damage_percent * LevelScaling.player_max_health_at(level(), player.stats)
	return maxi(1, roundi(base * LevelScaling.damage_multiplier(level_gap())))


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _scale_to_player() -> void:
	var player := _player()
	if player == null:
		return
	_scaled_to_player = true
	health.setup(scaled_max_health())
	player.level_changed.connect(_on_player_level_changed)


## Keeps the same share of health when the gap changes mid-fight.
func _on_player_level_changed(_level: int) -> void:
	if health.is_dead:
		return
	var fraction := float(health.current) / health.max_health
	health.max_health = scaled_max_health()
	health.set_current(maxi(1, roundi(fraction * health.max_health)))


func forward() -> Vector3:
	var dir := -facing.global_basis.z
	dir.y = 0.0
	return dir.normalized()


func face_target(delta: float) -> void:
	face_direction(direction_to_target(), delta)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	# The direction is in world space but Facing turns relative to the body, so take
	# off the body's own yaw: an enemy placed rotated in a level still faces right.
	var body_forward := -global_basis.z
	var body_yaw := atan2(-body_forward.x, -body_forward.z)
	var target_yaw := atan2(-direction.x, -direction.z) - body_yaw
	facing.rotation.y = lerp_angle(facing.rotation.y, target_yaw, 1.0 - exp(-stats.turn_speed * delta))


## Moves horizontal velocity toward desired at rate (m/s²); leaves vertical alone.
func move_horizontal(desired: Vector3, rate: float, delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(desired.x, 0.0, desired.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func set_horizontal_velocity(value: Vector3) -> void:
	velocity.x = value.x
	velocity.z = value.z


## Weighted random pick from stats.attacks.
func pick_attack() -> AttackData:
	var total := 0.0
	for attack: AttackData in stats.attacks:
		total += attack.weight
	var roll := randf() * total
	for attack: AttackData in stats.attacks:
		roll -= attack.weight
		if roll <= 0.0:
			return attack
	return stats.attacks.back()


func try_acquire_attack_token() -> bool:
	return EnemyAttackCoordinator.try_acquire(self)


func release_attack_token(cooldown: float) -> void:
	EnemyAttackCoordinator.release(self, cooldown)


# --- Combo ----------------------------------------------------------------------
# One attack: the Combo group in EnemyStats (telegraph, five swings, recovery).

## A combo swing: current_attack's knockback, stun and lunge with
## stats.attack_damage (level-scaled). Every swing deals the same damage.
func combo_attack() -> AttackData:
	var swing := current_attack.duplicate() as AttackData
	swing.damage = scaled_damage(stats.attack_damage)
	return swing


func is_vulnerable() -> bool:
	return _vulnerable_timer > 0.0


## Opens the post-combo vulnerability window for seconds.
func set_vulnerable(seconds: float) -> void:
	_vulnerable_timer = seconds


func combo_ready() -> bool:
	return _combo_cooldown <= 0.0


## No combo for at least seconds (never shortens a longer wait).
func start_combo_cooldown(seconds: float) -> void:
	_combo_cooldown = maxf(_combo_cooldown, seconds)


## Flashes the model color for seconds (hit and kill feedback), shown at once.
func flash(color: Color, seconds: float) -> void:
	_hit_flash_color = color
	_hit_flash_timer = seconds
	model.set_flash(color)


## Adds a push (m/s) for seconds through the body's normal movement, so walls
## still stop it (hit feedback, on top of the hit's own knockback).
func push(push_velocity: Vector3, seconds: float) -> void:
	_push_velocity = push_velocity
	_push_timer = seconds


func reset_telegraph_visuals() -> void:
	telegraph_flash = Color(0.0, 0.0, 0.0, 0.0)
	pulse_scale = 1.0


func _update_visuals(delta: float) -> void:
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	model.set_flash(_hit_flash_color if _hit_flash_timer > 0.0 else telegraph_flash)
	model.set_pulse(pulse_scale)


## Walk/stand from the body's movement unless the state is playing its own clip.
func _update_animation() -> void:
	if (state_machine.current as EnemyState).drives_animation():
		return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed > WALK_ANIM_MIN_SPEED:
		model.walk(ground_speed)
	else:
		model.play(MincerModel.CLIP_IDLE)


func _on_hit_received(attack: AttackData, source: Node3D) -> void:
	var damage := attack.damage
	if is_vulnerable():
		damage = roundi(damage * stats.vulnerable_damage_multiplier)
	health.take_damage(damage)
	var push := global_position - source.global_position
	push.y = 0.0
	var msg := {"knockback": push.normalized() * attack.knockback}
	if health.is_dead:
		state_machine.transition_to(EnemyState.DEAD, msg)
		died.emit()
	elif (state_machine.current as EnemyState).can_be_staggered():
		state_machine.transition_to(EnemyState.STAGGER, msg)
