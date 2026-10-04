class_name ArmJitter
extends SkeletonModifier3D
## Shakes the arm bones by a small random rotation on top of whatever pose the
## AnimationPlayer applied this frame, so a baked swing reads as sloppy and out
## of control. Strength eases toward amount_degrees, so turning it on/off never pops.

const ARM_BONES: Array[String] = ["mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_RightArm", "mixamorig_RightForeArm"]
## Forearms shake this fraction of the upper arms.
const FOREARM_SCALE: float = 0.6
## How fast the strength eases toward amount_degrees (degrees per second).
const FADE_RATE: float = 120.0

## Peak random rotation per bone (degrees). 0 = off.
@export var amount_degrees: float = 0.0
## New random offsets per second; higher looks twitchier.
@export var rate: float = 14.0

var _bones: PackedInt32Array = []
var _offsets: Array[Vector3] = []
var _targets: Array[Vector3] = []
var _strength: float = 0.0
var _reroll_timer: float = 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _bones.is_empty():
		_resolve_bones(skeleton)
	var delta := get_process_delta_time()
	_strength = move_toward(_strength, amount_degrees, FADE_RATE * delta)
	if _strength <= 0.01:
		return

	_reroll_timer -= delta
	if _reroll_timer <= 0.0:
		_reroll_timer = 1.0 / maxf(rate, 0.1)
		for i in _targets.size():
			_targets[i] = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).limit_length(1.0)

	var follow := 1.0 - exp(-rate * 2.0 * delta)
	for i in _bones.size():
		_offsets[i] = _offsets[i].lerp(_targets[i], follow)
		var bone_scale := FOREARM_SCALE if ARM_BONES[i].ends_with("ForeArm") else 1.0
		var rotation_vector := _offsets[i] * deg_to_rad(_strength) * bone_scale
		if rotation_vector.length_squared() < 0.000001:
			continue
		var shake := Quaternion(rotation_vector.normalized(), rotation_vector.length())
		skeleton.set_bone_pose_rotation(_bones[i], skeleton.get_bone_pose_rotation(_bones[i]) * shake)


func _resolve_bones(skeleton: Skeleton3D) -> void:
	for bone_name: String in ARM_BONES:
		_bones.append(skeleton.find_bone(bone_name))
		_offsets.append(Vector3.ZERO)
		_targets.append(Vector3.ZERO)
