class_name Ragdoll
extends SkeletonModifier3D
## Death ragdoll for a dead enemy (the Dead state calls start()). On a humanoid
## rig (mixamorig_ bone names) the hips, chest, head, arms and legs become
## capsule rigid bodies joined with cone-twist joints, starting in the pose the
## enemy died in and carrying its velocity. This modifier runs last on the
## skeleton and lays each part's bone on its body every frame, so it overrides
## the frozen animation; bones in between (spine, shoulders, hands, fingers)
## ride along with their parents. A model without a skeleton (the Floating
## Monk's rigid parts) tips over as one rigid body instead.
## The bodies collide with the world only: not the player, enemies or each other.

const PREFIX := "mixamorig_"
## [bone, end bone, parent part, radius as a fraction of the length, mass,
## swing limit (degrees), twist limit (degrees)]. Parents come before children.
const PARTS: Array = [
	["Hips", "Spine1", "", 0.6, 3.0, 0.0, 0.0],
	["Spine1", "Neck", "Hips", 0.5, 3.0, 25.0, 20.0],
	["Head", "HeadTop_End", "Spine1", 0.55, 1.0, 40.0, 40.0],
	["LeftArm", "LeftForeArm", "Spine1", 0.22, 1.0, 75.0, 40.0],
	["LeftForeArm", "LeftHand", "LeftArm", 0.2, 0.8, 80.0, 10.0],
	["RightArm", "RightForeArm", "Spine1", 0.22, 1.0, 75.0, 40.0],
	["RightForeArm", "RightHand", "RightArm", 0.2, 0.8, 80.0, 10.0],
	["LeftUpLeg", "LeftLeg", "Hips", 0.22, 1.5, 50.0, 15.0],
	["LeftLeg", "LeftFoot", "LeftUpLeg", 0.18, 1.2, 75.0, 5.0],
	["RightUpLeg", "RightLeg", "Hips", 0.22, 1.5, 50.0, 15.0],
	["RightLeg", "RightFoot", "RightUpLeg", 0.18, 1.2, 75.0, 5.0],
]
## Physics layers the bodies land on (1 = world).
const WORLD_MASK := 1
## Random tumble added at the start (rad/s), so no two deaths fall the same.
const SPIN := 3.0

## Per part, in PARTS order: the bone and its body, and the bone's transform
## relative to the body (it includes the model's scale, which bodies can't carry).
var _bones: PackedInt32Array = []
var _bodies: Array[RigidBody3D] = []
var _offsets: Array[Transform3D] = []


## Ragdolls model (the enemy's $Facing/Model) moving at velocity. body_shape is
## the enemy's own collider, sizing the single body of a model with no skeleton.
static func start(model: Node3D, velocity: Vector3, body_shape: CollisionShape3D) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		var skeleton := skeletons[0] as Skeleton3D
		if skeleton.find_bone(PREFIX + "Hips") >= 0:
			var ragdoll := Ragdoll.new()
			# Last child, so it runs after the clip and the model's own modifiers.
			skeleton.add_child(ragdoll)
			ragdoll._build(skeleton, velocity)
			return
	_tip_over(model, velocity, body_shape)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	for i in _bones.size():
		skeleton.set_bone_global_pose(_bones[i], to_skeleton * _bodies[i].global_transform * _offsets[i])


func _build(skeleton: Skeleton3D, velocity: Vector3) -> void:
	var by_bone: Dictionary[String, RigidBody3D] = {}
	for part: Array in PARTS:
		var bone := skeleton.find_bone(PREFIX + part[0])
		if bone < 0:
			continue
		var start := _bone_world(skeleton, bone)
		var end := _end_point(skeleton, bone, part[1])
		var length := start.origin.distance_to(end)
		if length < 0.01:
			continue
		var body := _capsule_body(start.origin, end, length * part[3], part[4])
		add_child(body)
		body.global_transform = Transform3D(_basis_along(end - start.origin, Vector3.AXIS_Y), (start.origin + end) * 0.5)
		body.linear_velocity = velocity
		body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SPIN
		_bones.append(bone)
		_bodies.append(body)
		_offsets.append(body.global_transform.affine_inverse() * start)
		by_bone[part[0]] = body
		var parent: RigidBody3D = by_bone.get(part[2])
		if parent != null:
			_join(parent, body, start.origin, end - start.origin, part[5], part[6])


func _capsule_body(start: Vector3, end: Vector3, radius: float, mass: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.top_level = true
	body.collision_layer = 0
	body.collision_mask = WORLD_MASK
	body.mass = mass
	body.linear_damp = 0.1
	body.angular_damp = 1.5
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	body.physics_material_override = material
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(start.distance_to(end), radius * 2.0 + 0.01)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	body.add_child(shape)
	return body


## A cone-twist joint at point: child swings up to swing degrees off direction
## (its bone's line) and twists up to twist degrees about it.
func _join(parent: RigidBody3D, child: RigidBody3D, point: Vector3, direction: Vector3,
		swing: float, twist: float) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.top_level = true
	add_child(joint)
	# The joint twists about its X axis.
	joint.global_transform = Transform3D(_basis_along(direction, Vector3.AXIS_X), point)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist))
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)


static func _bone_world(skeleton: Skeleton3D, bone: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)


## Where a part ends: its end bone, or (no such bone, e.g. no head-top) as far
## again past the bone as its parent bone is behind it.
static func _end_point(skeleton: Skeleton3D, bone: int, end_name: String) -> Vector3:
	var end := skeleton.find_bone(PREFIX + end_name)
	if end >= 0:
		return _bone_world(skeleton, end).origin
	var start := _bone_world(skeleton, bone).origin
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return start
	return start + (start - _bone_world(skeleton, parent).origin)


## An orthonormal basis with the given axis along direction.
static func _basis_along(direction: Vector3, axis: Vector3.Axis) -> Basis:
	var main := direction.normalized()
	var ref := Vector3.FORWARD if absf(main.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var other := (ref - main * ref.dot(main)).normalized()
	if axis == Vector3.AXIS_X:
		return Basis(main, other, main.cross(other))
	# Y along direction: X x Y = Z keeps it right-handed.
	var x := other.cross(main)
	return Basis(x, main, x.cross(main))


## No skeleton: the whole model becomes one rigid body shaped like the enemy's
## collider, given a push and a spin about the ground so it topples.
static func _tip_over(model: Node3D, velocity: Vector3, body_shape: CollisionShape3D) -> void:
	if body_shape == null or body_shape.shape == null:
		return
	var body := RigidBody3D.new()
	body.top_level = true
	body.collision_layer = 0
	body.collision_mask = WORLD_MASK
	body.mass = 4.0
	body.angular_damp = 1.0
	var shape := CollisionShape3D.new()
	shape.shape = body_shape.shape.duplicate()
	body.add_child(shape)
	model.get_parent().add_child(body)
	body.global_transform = body_shape.global_transform.orthonormalized()
	model.reparent(body, true)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var fall := flat.normalized() if flat.length_squared() > 0.01 else Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	body.linear_velocity = velocity + Vector3.UP * 1.5
	body.angular_velocity = Vector3.UP.cross(fall) * SPIN
