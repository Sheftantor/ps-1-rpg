class_name FloatingFigure
extends EnemyModel
## The imported multi-arm figure (res://Import/Character/Suit_Enemy1/Multi_Arm_Man.glb)
## posed and floating. Each part of the model is a rigid mesh with no armature;
## Float/Pivots holds one Node3D per part, named exactly like the part and placed
## at its joint (shoulder for arms, hip for legs, chest centre for Body). On ready
## each part mesh moves under its pivot (keeping its world position), so rotating
## a pivot swings the limb from the joint. Every pose and motion number comes from
## the IdlePose resource; nothing is tuned here.
## As an EnemyModel (the Floating Monk, res://scenes/floating_monk.tscn) it also
## flashes and tints, and any limb can fly out in a strike (set_strike()).
## The model faces +Z.

## The pose and idle motion. Edited live by the F8 FloatingFigureTuner.
@export var pose: IdlePose = preload("res://resources/idle_pose_default.tres")
## Off: hold the pose still (no bob, sway or drift), e.g. while tuning by eye.
@export var animate: bool = true

@export_group("Strike")
## How far forward a striking limb's joint flies out (model metres).
@export var strike_reach: float = 0.35
## Height in the model the strikes converge on (chest).
@export var strike_height: float = 0.72
## How far past the joint, straight ahead, the striking hands meet (model metres).
@export var strike_focus: float = 0.45
## A winding-up limb (negative strike amount) pulls back and up by this (model metres).
@export var windup_offset: Vector3 = Vector3(0.0, 0.06, -0.14)

@onready var _float: Node3D = $Float
@onready var _model: Node3D = $Float/Model
@onready var _pivots: Node3D = $Float/Pivots

## Pivot -> its rest position (the joint), which pos_offset is added to.
var _rest: Dictionary[Node3D, Vector3] = {}
## Pivot -> roughly where the limb's far end (hand / foot) is, in pivot space.
var _tip: Dictionary[Node3D, Vector3] = {}
## Pivot -> strike amount: 0 idle, 1 fully struck out, negative winding up.
var _strike: Dictionary[Node3D, float] = {}
var _meshes: Array[GeometryInstance3D] = []
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0


func _ready() -> void:
	_base_scale = scale
	for pivot: Node3D in _pivots.get_children():
		var part := _model.get_node_or_null(NodePath(String(pivot.name))) as MeshInstance3D
		if part == null:
			push_warning("FloatingFigure: no part named '%s' in the model" % pivot.name)
			continue
		part.reparent(pivot)
		_rest[pivot] = pivot.position
		# The joint is at one end of the part, so the far end is about twice
		# as far out as the part's centre.
		_tip[pivot] = (part.transform * part.get_aabb().get_center()) * 2.0
		_meshes.append(part)
	_apply()


func _process(delta: float) -> void:
	if animate:
		_time += delta
	_apply()


func get_part_names() -> PackedStringArray:
	var names := PackedStringArray()
	for pivot in _rest:
		names.append(String(pivot.name))
	return names


## Drives one limb's strike: 0 = its idle pose, 1 = flown out toward the front
## at chest height, negative = wound back (-1 fully). Stays until changed.
func set_strike(part_name: String, amount: float) -> void:
	var pivot := _pivots.get_node_or_null(NodePath(part_name)) as Node3D
	if pivot != null:
		_strike[pivot] = amount


func clear_strikes() -> void:
	_strike.clear()


## World position of a limb's far end (the hand), e.g. where a bolt leaves.
func hand_position(part_name: String) -> Vector3:
	var pivot := _pivots.get_node_or_null(NodePath(part_name)) as Node3D
	if pivot == null or not _tip.has(pivot):
		return global_position
	return pivot.global_transform * _tip[pivot]


func freeze() -> void:
	animate = false


func set_flash(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"flash_color", color)


func set_tint(color: Color) -> void:
	for mesh in _meshes:
		mesh.set_instance_shader_parameter(&"tint", color)


func set_pulse(amount: float) -> void:
	scale = _base_scale * amount


func _apply() -> void:
	if pose == null:
		return
	_float.position.y = pose.bob_amplitude * sin(TAU * pose.bob_hz * _time)
	_float.rotation.y = deg_to_rad(pose.yaw_sway_deg) * sin(TAU * pose.yaw_sway_hz * _time)
	for pivot in _rest:
		var part: Dictionary = pose.parts.get(String(pivot.name), {})
		var drift: float = part.get("drift", 0.0)
		var wave: float = TAU * (pose.limb_drift_hz * part.get("speed", 1.0) * _time + part.get("phase", 0.0))
		# Bob on Y; sway tips the limb about X and Z a quarter cycle apart, so it
		# circles gently instead of rocking on one axis.
		var bob := Vector3.UP * pose.limb_bob_amplitude * sin(wave)
		var sway := Vector3(cos(wave), 0.0, sin(wave)) * pose.limb_sway_deg
		var idle_position: Vector3 = _rest[pivot] + part.get("pos_offset", Vector3.ZERO) + bob * drift
		var idle_rotation: Vector3 = part.get("rot_deg", Vector3.ZERO) + sway * drift
		var strike: float = _strike.get(pivot, 0.0)
		if strike < 0.0:
			pivot.position = idle_position + windup_offset * -strike
			pivot.rotation_degrees = idle_rotation
		elif strike > 0.0:
			_apply_strike(pivot, idle_position, idle_rotation, strike)
		else:
			pivot.position = idle_position
			pivot.rotation_degrees = idle_rotation


## Blends a limb from its idle pose toward flying out ahead, its far end
## pointing at the strike focus in front of the chest.
func _apply_strike(pivot: Node3D, idle_position: Vector3, idle_rotation_deg: Vector3, amount: float) -> void:
	var rest: Vector3 = _rest[pivot]
	var out := Vector3(rest.x * 0.6, lerpf(rest.y, strike_height, 0.5), rest.z + strike_reach)
	var focus := Vector3(0.0, strike_height, rest.z + strike_reach + strike_focus)
	var aim := Quaternion(_tip[pivot].normalized(), (focus - out).normalized())
	var idle := Quaternion.from_euler(idle_rotation_deg * (PI / 180.0))
	pivot.position = idle_position.lerp(out, amount)
	pivot.quaternion = idle.slerp(aim, amount)
