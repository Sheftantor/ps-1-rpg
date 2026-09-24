class_name Enemy
extends CharacterBody3D
## Melee enemy. Behaviour lives in the StateMachine child (one script per state in
## res://scripts/enemy/states/); this script owns the body, senses, and the
## helpers those states use.

signal died

const HIT_FLASH_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const HIT_FLASH_TIME: float = 0.12

@export var stats: EnemyStats

var target: Node3D = null
## The attack chosen for the current turn (set in Reposition, used through Recover).
var current_attack: AttackData = null
## Set by states to drive the telegraph visuals; alpha is flash strength.
var telegraph_flash: Color = Color(0.0, 0.0, 0.0, 0.0)
var pulse_scale: float = 1.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _hit_flash_timer: float = 0.0

@onready var facing: Node3D = $Facing
@onready var hitbox: Hitbox = $Facing/Hitbox
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var state_machine: StateMachine = $StateMachine
@onready var _body_mesh: MeshInstance3D = $Facing/Body


func _ready() -> void:
	add_to_group(&"enemies")
	health.setup(stats.max_health)
	hurtbox.hit_received.connect(_on_hit_received)
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	if not has_target():
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_on_floor():
		velocity.y -= _gravity * delta
	state_machine.physics_update(delta)
	move_and_slide()
	_update_visuals(delta)


func _exit_tree() -> void:
	EnemyAttackCoordinator.release(self, 0.0)


func is_alive() -> bool:
	return not health.is_dead


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


func forward() -> Vector3:
	var dir := -facing.global_basis.z
	dir.y = 0.0
	return dir.normalized()


func face_target(delta: float) -> void:
	face_direction(direction_to_target(), delta)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
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


func reset_telegraph_visuals() -> void:
	telegraph_flash = Color(0.0, 0.0, 0.0, 0.0)
	pulse_scale = 1.0


func _update_visuals(delta: float) -> void:
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	var flash := HIT_FLASH_COLOR if _hit_flash_timer > 0.0 else telegraph_flash
	_body_mesh.set_instance_shader_parameter(&"flash_color", flash)
	_body_mesh.scale = Vector3.ONE * pulse_scale


func _on_hit_received(attack: AttackData, source: Node3D) -> void:
	health.take_damage(attack.damage)
	_hit_flash_timer = HIT_FLASH_TIME
	var push := global_position - source.global_position
	push.y = 0.0
	var msg := {"knockback": push.normalized() * attack.knockback}
	if health.is_dead:
		state_machine.transition_to(EnemyState.DEAD, msg)
		died.emit()
	elif (state_machine.current as EnemyState).can_be_staggered():
		state_machine.transition_to(EnemyState.STAGGER, msg)
