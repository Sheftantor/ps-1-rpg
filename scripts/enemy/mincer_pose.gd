class_name MincerPose
extends SkeletonModifier3D
## The Mincer's combo poses, layered on his clips every frame (made by MincerModel,
## driven by the Telegraph / Attack / Recover states): torso lean, yaw and roll,
## and the claws placed by two-bone IK. Each claw blends between four targets:
##   rear  - spread wide and raised (the telegraph),
##   swing - out on a horizontal circle around the chest at swing_angle (only
##           the claw on swing_side; the sweeps),
##   guard - held low in front (the claw that isn't swinging),
##   reach - flung forward and down (the stumble after the combo).
## Claw targets are smoothed so switching which claw swings never pops.
## Model space here: forward +Z, his left +X, up +Y. weight 0 = the clip alone.

## Overall strength of the whole layer (0 = off).
var weight: float = 0.0
## Torso pitch, + leans back (degrees).
var lean_degrees: float = 0.0
## Torso turn, + turns his chest to his left (degrees).
var yaw_degrees: float = 0.0
## Torso sideways tilt (degrees).
var roll_degrees: float = 0.0
var rear: float = 0.0
## +1 = left claw swings, -1 = right claw.
var swing_side: float = 1.0
var swing: float = 0.0
## Swinging claw's angle around the chest: 0 = straight ahead, + = out on its
## own side, - = across to the other side (degrees).
var swing_angle: float = 0.0
## Swinging claw's height relative to the shoulders, in arm lengths.
var swing_height: float = 0.0
var guard: float = 0.0
var reach: float = 0.0

const P := "mixamorig_"
## How quickly claw targets follow (per second): high enough for rapid swings.
const TARGET_FOLLOW := 40.0

var _bones := {}
## Smoothed claw targets and poles, by side (+1 / -1).
var _targets := {}
var _poles := {}


func _ready() -> void:
	var skeleton := get_skeleton()
	for bone in ["Spine", "Spine1", "Spine2", "LeftArm", "LeftForeArm", "LeftHand",
			"RightArm", "RightForeArm", "RightHand"]:
		_bones[bone] = skeleton.find_bone(P + bone)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.is_empty() or weight <= 0.0:
		_targets.clear()
		return
	var up := Vector3.UP
	var forward := Vector3.BACK
	var left := Vector3.RIGHT
	var torso := Quaternion(up, deg_to_rad(yaw_degrees) / 3.0) \
			* Quaternion(left, -deg_to_rad(lean_degrees) / 3.0) \
			* Quaternion(forward, deg_to_rad(roll_degrees) / 3.0)
	torso = Quaternion.IDENTITY.slerp(torso, weight)
	for bone in ["Spine", "Spine1", "Spine2"]:
		_rotate(skeleton, _bones[bone], torso)
	var delta := get_process_delta_time()
	for side: float in [1.0, -1.0]:
		_claw(skeleton, side, up, forward, left * side, delta)


func _claw(skeleton: Skeleton3D, side: float, up: Vector3, forward: Vector3, out: Vector3, delta: float) -> void:
	var prefix := "Left" if side > 0.0 else "Right"
	var shoulder := skeleton.get_bone_global_pose(_bones[prefix + "Arm"]).origin
	var other := skeleton.get_bone_global_pose(_bones[("Right" if side > 0.0 else "Left") + "Arm"]).origin
	var arm := _arm_length(skeleton, prefix)
	var swinging := swing if is_equal_approx(side, swing_side) else 0.0
	var holding := guard if not is_equal_approx(side, swing_side) else guard * (1.0 - swing)
	var parts: Array = []
	if rear > 0.0:
		parts.append([shoulder + (out * 0.7 + up * 0.65 + forward * 0.1) * arm, -up + out, rear])
	if swinging > 0.0:
		var chest := (shoulder + other) * 0.5
		var angle := deg_to_rad(swing_angle)
		var around := forward * cos(angle) + out * sin(angle)
		var radius := arm * 0.95 + shoulder.distance_to(other) * 0.5
		parts.append([chest + around * radius + up * swing_height * arm, -forward + up * 0.5 + out * 0.3, swinging])
	if holding > 0.0:
		parts.append([shoulder + (out * 0.25 + forward * 0.55 - up * 0.45) * arm, out - up * 0.5, holding])
	if reach > 0.0:
		parts.append([shoulder + (forward * 0.75 - up * 0.55 + out * 0.15) * arm, out - up, reach])
	var total := 0.0
	var target := Vector3.ZERO
	var pole := Vector3.ZERO
	for part: Array in parts:
		target += part[0] * part[2]
		pole += part[1] * part[2]
		total += part[2]
	if total <= 0.0:
		_targets.erase(side)
		return
	target /= total
	pole = (pole / total).normalized()
	var follow := 1.0 - exp(-TARGET_FOLLOW * delta)
	if _targets.has(side):
		target = (_targets[side] as Vector3).lerp(target, follow)
		pole = (_poles[side] as Vector3).lerp(pole, follow).normalized()
	_targets[side] = target
	_poles[side] = pole
	_two_bone(skeleton, prefix, target, pole, minf(total, 1.0) * weight)


func _two_bone(skeleton: Skeleton3D, prefix: String, target: Vector3, pole: Vector3, amount: float) -> void:
	var upper: int = _bones[prefix + "Arm"]
	var lower: int = _bones[prefix + "ForeArm"]
	var hand: int = _bones[prefix + "Hand"]
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(skeleton.get_bone_global_pose(hand).origin)
	var to_target := target - a
	var reach_length := clampf(to_target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := to_target.normalized()
	var cos_a := clampf((l1 * l1 + reach_length * reach_length - l2 * l2) / (2.0 * l1 * reach_length), -1.0, 1.0)
	var bend := (pole - u * pole.dot(u)).normalized()
	var elbow := a + u * l1 * cos_a + bend * l1 * sqrt(1.0 - cos_a * cos_a)
	_point(skeleton, upper, b - a, elbow - a, amount)
	var b2 := skeleton.get_bone_global_pose(lower).origin
	var c2 := skeleton.get_bone_global_pose(hand).origin
	_point(skeleton, lower, c2 - b2, a + u * reach_length - b2, amount)


func _arm_length(skeleton: Skeleton3D, prefix: String) -> float:
	return skeleton.get_bone_rest(_bones[prefix + "ForeArm"]).origin.length() \
			+ skeleton.get_bone_rest(_bones[prefix + "Hand"]).origin.length()


func _point(skeleton: Skeleton3D, bone: int, from_direction: Vector3, to_direction: Vector3, amount: float) -> void:
	if from_direction.is_zero_approx() or to_direction.is_zero_approx():
		return
	var arc := Quaternion(from_direction.normalized(), to_direction.normalized())
	_rotate(skeleton, bone, Quaternion.IDENTITY.slerp(arc, amount))


func _rotate(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(rotation) * pose.basis, pose.origin))
