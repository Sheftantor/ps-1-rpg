class_name Enemy
extends CharacterBody3D
## Melee enemy. Behaviour lives in the StateMachine child (one script per state in
## res://scripts/enemy/states/); this script owns the body, senses, and the
## helpers those states use.

signal died

const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const HIT_FLASH_TIME: float = 0.12
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
## Attacks finished in a row without the player landing a hit (see the
## Escalation group in EnemyStats). The next attack is number slash_chain + 1.
var slash_chain: int = 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _hit_flash_timer: float = 0.0
var _chain_timer: float = 0.0
## False once the current swing is hit, so it doesn't count toward the chain.
var _swing_clean: bool = false

@onready var facing: Node3D = $Facing
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine
@onready var model: MincerModel = $Facing/Model


func _ready() -> void:
	add_to_group(&"enemies")
	home_position = global_position
	health.setup(stats.max_health)
	model.set_tint(body_tint)
	health.died.connect(_award_xp)
	hurtbox.hit_received.connect(_on_hit_received)
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	if not has_target():
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_on_floor():
		velocity.y -= _gravity * delta
	state_machine.physics_update(delta)
	move_and_slide()
	_update_escalation(delta)
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
	if player != null:
		player.award_kill(level())


func level() -> int:
	return level_override if level_override > 0 else stats.level


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


# --- Escalation -----------------------------------------------------------------
# Each attack finished without the player landing a hit adds to slash_chain:
# the next one plays faster, the arms start to shake from jitter_start_attack on,
# the top attacks hit harder, and finishing the last one costs the enemy its
# balance. Any hit the player lands drops the chain back to the base attack.

## Playback-speed multiplier for the next attack (also scales its timings).
func attack_speed() -> float:
	return 1.0 + stats.escalation_speed_step * slash_chain


## Arm jitter (degrees) for the next attack's swing; 0 before jitter_start_attack.
func attack_jitter() -> float:
	var past_start := slash_chain + 1 - stats.jitter_start_attack
	return stats.jitter_degrees_per_attack * (past_start + 1) if past_start >= 0 else 0.0


## Whether the next attack is one of the harder-hitting top attacks.
func is_top_attack() -> bool:
	return slash_chain >= stats.escalation_chain_length - stats.top_attack_count


## current_attack, boosted for the top of the chain.
func escalated_attack() -> AttackData:
	if not is_top_attack():
		return current_attack
	var boosted := current_attack.duplicate() as AttackData
	boosted.knockback *= stats.top_attack_knockback_multiplier
	boosted.hit_stun_multiplier *= stats.top_attack_hit_stun_multiplier
	return boosted


func begin_attack() -> void:
	_swing_clean = true


## Called when an attack's swing ends. Counts it toward the chain unless it was
## hit; returns true when it was the last attack in the chain and the enemy
## should lose its balance.
func finish_attack() -> bool:
	if not _swing_clean:
		return false
	if slash_chain + 1 >= stats.escalation_chain_length:
		break_chain()
		return true
	slash_chain += 1
	_chain_timer = stats.escalation_chain_timeout
	return false


func break_chain() -> void:
	slash_chain = 0
	_chain_timer = 0.0
	_swing_clean = false


func _update_escalation(delta: float) -> void:
	if slash_chain == 0:
		return
	_chain_timer -= delta
	if _chain_timer <= 0.0:
		break_chain()


func reset_telegraph_visuals() -> void:
	telegraph_flash = Color(0.0, 0.0, 0.0, 0.0)
	pulse_scale = 1.0


func _update_visuals(delta: float) -> void:
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	var flash := HIT_FLASH_COLOR if _hit_flash_timer > 0.0 else telegraph_flash
	model.set_flash(flash)
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
	health.take_damage(attack.damage)
	_hit_flash_timer = HIT_FLASH_TIME
	# Interrupted: the escalation starts over from the base attack.
	break_chain()
	var push := global_position - source.global_position
	push.y = 0.0
	var msg := {"knockback": push.normalized() * attack.knockback}
	if health.is_dead:
		state_machine.transition_to(EnemyState.DEAD, msg)
		died.emit()
	elif (state_machine.current as EnemyState).can_be_staggered():
		state_machine.transition_to(EnemyState.STAGGER, msg)
