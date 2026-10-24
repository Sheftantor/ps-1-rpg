class_name FlailLimbs
extends SkeletonModifier3D
## Flailing arms and legs for an enemy sent flying back (Enemy.knock_down()):
## every arm and leg bone swings on two out-of-step waves on top of whatever
## pose the AnimationPlayer applied this frame, so the body thrashes as it sails
## through the air. Strength eases toward `amount` (0..1), so it never pops.
## Created by Enemy on the model's Skeleton3D the first time it's knocked down;
## sizes and speed come from the Enemy Knockdown group of the combat tuning.

## [bone, amplitude scale]: upper arms swing widest, shins least.
const BONES := {
	"mixamorig_LeftArm": 1.0, "mixamorig_RightArm": 1.0,
	"mixamorig_LeftForeArm": 0.7, "mixamorig_RightForeArm": 0.7,
	"mixamorig_LeftUpLeg": 0.6, "mixamorig_RightUpLeg": 0.6,
	"mixamorig_LeftLeg": 0.5, "mixamorig_RightLeg": 0.5,
}
## How fast the strength eases toward amount (per second).
const FADE_RATE: float = 6.0

## Target strength, 0 (still) to 1 (full flail).
var amount: float = 0.0
## Peak swing of an upper arm (degrees); other bones scale from it.
var degrees: float = 65.0
## Swings per second.
var speed: float = 3.0

var _bones: PackedInt32Array = []
var _scales: PackedFloat32Array = []
## Per bone: phase offsets of its two waves, so no two limbs move together.
var _phases: Array[Vector2] = []
var _strength: float = 0.0
var _time: float = 0.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _bones.is_empty():
		_resolve_bones(skeleton)
	var delta := get_process_delta_time()
	_strength = move_toward(_strength, amount, FADE_RATE * delta)
	if _strength <= 0.001:
		return
	_time += delta
	var wave := TAU * speed * _time
	for i in _bones.size():
		var size := deg_to_rad(degrees) * _scales[i] * _strength
		# Two axes at different rates: a big swing plus a sideways wobble.
		var swing := Quaternion(Vector3.RIGHT, sin(wave + _phases[i].x) * size)
		var wobble := Quaternion(Vector3.FORWARD, sin(wave * 1.37 + _phases[i].y) * size * 0.6)
		skeleton.set_bone_pose_rotation(_bones[i], skeleton.get_bone_pose_rotation(_bones[i]) * swing * wobble)


func _resolve_bones(skeleton: Skeleton3D) -> void:
	for bone_name: String in BONES:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		_bones.append(bone)
		_scales.append(BONES[bone_name])
		_phases.append(Vector2(randf() * TAU, randf() * TAU))
