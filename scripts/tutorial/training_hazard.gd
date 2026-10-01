class_name TrainingHazard
extends Node3D
## Dodge-roll practice: a floor pad that telegraphs, then strikes everything on
## it. A strike rolled through on the roll's i-frames emits `dodged`. It can't
## kill: damage is capped to leave the player at 1 HP.

signal dodged

const COLOR_IDLE: Color = Color(0.35, 0.35, 0.4)
const COLOR_WARNING: Color = Color(1.0, 0.75, 0.2)
const COLOR_STRIKE: Color = Color(1.0, 0.2, 0.15)
const STRIKE_FLASH_TIME: float = 0.15

@export var radius: float = 2.5
## Seconds between strikes, warning included.
@export var interval: float = 2.2
## Warning before each strike; roll as it ends.
@export var warning_time: float = 0.8
@export var damage: int = 5
@export var knockback: float = 3.0

var _timer: float = 0.0
var _attack: AttackData
var _material: StandardMaterial3D


func _ready() -> void:
	# The Tutorial node above keeps running through pauses; this must not.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_attack = AttackData.new()
	_attack.display_name = "Training hazard"
	_attack.knockback = knockback

	var pad := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	pad.mesh = mesh
	pad.position.y = 0.02
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = COLOR_IDLE
	pad.material_override = _material
	add_child(pad)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		_strike()
	if _timer < STRIKE_FLASH_TIME:
		_material.albedo_color = COLOR_STRIKE
	elif _timer >= interval - warning_time:
		_material.albedo_color = COLOR_WARNING
	else:
		_material.albedo_color = COLOR_IDLE


func _strike() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.health.is_dead:
		return
	var offset := player.global_position - global_position
	offset.y = 0.0
	if offset.length() > radius:
		return
	_attack.damage = mini(damage, player.health.current - 1)
	var hurtbox := player.get_node("Hurtbox") as Hurtbox
	if not hurtbox.receive_hit(_attack, self) and player.state_machine.current_name() == PlayerState.DODGE:
		dodged.emit()
