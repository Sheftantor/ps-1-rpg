class_name SuitPosture
extends SkeletonModifier3D
## Suit Guy's posture layer, run on his skeleton after the AnimationPlayer every
## frame: turns the retargeted (slouching) clips into a hitman's bearing. In order:
##   - proportions: legs and torso lengthened by stand_height_scale (arms untouched),
##     less hip bob while walking;
##   - feet a little wider apart while standing;
##   - torso straightened upright with a slight lean back (chest out, collar up);
##   - shoulders raised and pulled back (level, broad), arms keeping their angle;
##   - gun arm (IK): low-ready (elbow bent, silencer forward and down), raised along
##     one smooth arc to chest height and level as aim_weight goes to 1, plus a
##     small recoil kick; meanwhile the torso turns side-on, gun side forward;
##   - off arm: hangs calm and nearly still.
## Created and driven by SuitModel; the tunables come from SuitGuy's Posture group.
## The model scene faces +Z with the gun in its -X hand (SuitGuy turns it to face
## -Z), so here forward is +Z and the gun side is -X of the model's space.

var stand_height_scale: float = 1.12
var lean_back_degrees: float = 4.0
var shoulder_raise_degrees: float = 10.0
var shoulder_square_degrees: float = 8.0
## Each leg's outward tilt while standing, so the feet sit about shoulder-width apart.
var stance_degrees: float = 3.0
var aim_turn_degrees: float = 30.0
## Silencer angle below level in the low-ready.
var low_ready_pitch_degrees: float = 25.0
## Hip bob left while walking (1 = the clip's own).
var walk_bob_scale: float = 0.4
## Gun kick at full recoil.
var recoil_degrees: float = 8.0

## 0 = low-ready, 1 = aiming (gun at chest height, torso turned).
var aim_weight: float = 0.0
## 0 = standing, 1 = walking.
var move_weight: float = 0.0
## 0..1 recoil kick, eased in and out by SuitModel.
var recoil: float = 0.0
## The gun's muzzle direction and up, in the right hand bone's space.
var gun_dir_in_hand: Vector3 = Vector3.FORWARD
var gun_up_in_hand: Vector3 = Vector3.UP
## Model space -> skeleton space (rotation only).
var model_to_skeleton: Basis = Basis.IDENTITY
## The Neck bone (collar) after this frame's posture, in skeleton space. Scripts
## reading the skeleton see the pose from before the modifiers, so use this.
var collar_position: Vector3 = Vector3.ZERO

const P := "mixamorig_"
## Gun hand targets from the shoulder, in arm lengths (forward, up, outward):
## low-ready, and aimed (arm nearly straight, hand just under the shoulder).
const LOW_READY_HAND := Vector3(0.38, -0.7, 0.04)
const AIM_HAND := Vector3(0.9, -0.17, -0.03)
## Off hand from its shoulder: hanging by the thigh, elbow just off straight.
const OFF_HAND := Vector3(0.05, -0.93, 0.1)
## How fully each spine segment is stood up (Spine, Spine1, Spine2, Neck).
const UPRIGHT := [1.0, 1.0, 1.0, 0.9]

var _bones := {}
var _hips_base: float = -1.0


func _ready() -> void:
	var skeleton := get_skeleton()
	for bone in ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
			"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
			"RightShoulder", "RightArm", "RightForeArm", "RightHand",
			"LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]:
		_bones[bone] = skeleton.find_bone(P + bone)


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _bones.is_empty():
		return
	var up := _dir(Vector3.UP)
	var forward := _dir(Vector3.BACK)
	var right := _dir(Vector3.LEFT)
	_proportions(skeleton, up)
	_stance(skeleton, right)
	_stand_upright(skeleton, up, forward, right)
	_square_shoulders(skeleton, up, forward)
	var turn := deg_to_rad(aim_turn_degrees) * aim_weight
	if turn != 0.0:
		# Gun side forward, half from each chest segment. The arm IK still aims
		# along the body's forward, i.e. at the player.
		_rotate(skeleton, _bones.Spine1, Quaternion(up, turn * 0.5))
		_rotate(skeleton, _bones.Spine2, Quaternion(up, turn * 0.5))
	_gun_arm(skeleton, up, forward, right)
	_off_arm(skeleton, up, forward, right)
	collar_position = skeleton.get_bone_global_pose(_bones.Neck).origin


func _proportions(skeleton: Skeleton3D, up: Vector3) -> void:
	var s := stand_height_scale
	for bone in ["LeftLeg", "LeftFoot", "RightLeg", "RightFoot", "Spine1", "Spine2", "Neck",
			"LeftShoulder", "RightShoulder"]:
		skeleton.set_bone_pose_position(_bones[bone], skeleton.get_bone_rest(_bones[bone]).origin * s)
	var hips: Vector3 = skeleton.get_bone_pose_position(_bones.Hips)
	var height := hips.dot(up)
	if _hips_base < 0.0:
		_hips_base = height
	# The bob is the height's swing around its slow average.
	_hips_base = lerpf(_hips_base, height, 1.0 - exp(-3.0 * get_process_delta_time()))
	var bob := lerpf(1.0, walk_bob_scale, move_weight)
	var calm := _hips_base + (height - _hips_base) * bob
	skeleton.set_bone_pose_position(_bones.Hips, hips + up * (calm * s - height))


func _stance(skeleton: Skeleton3D, right: Vector3) -> void:
	var spread := tan(deg_to_rad(stance_degrees)) * (1.0 - move_weight)
	if spread == 0.0:
		return
	for side in [["LeftUpLeg", "LeftLeg", -1.0], ["RightUpLeg", "RightLeg", 1.0]]:
		var direction := _segment(skeleton, _bones[side[0]], _bones[side[1]])
		_point(skeleton, _bones[side[0]], direction, direction + right * side[2] * spread, 1.0)


## Each spine segment tilted to lean_back_degrees behind vertical (sideways tilt kept).
func _stand_upright(skeleton: Skeleton3D, up: Vector3, forward: Vector3, right: Vector3) -> void:
	var lean := deg_to_rad(lean_back_degrees)
	var chain := ["Spine", "Spine1", "Spine2", "Neck", "Head"]
	for i in 4:
		var bone: int = _bones[chain[i]]
		var direction := _segment(skeleton, bone, _bones[chain[i + 1]])
		var upright := up * cos(lean) - forward * sin(lean) + right * direction.dot(right)
		_point(skeleton, bone, direction, upright, UPRIGHT[i])


## Clavicles up and back; the arms keep their world angle so only the shoulder moves.
func _square_shoulders(skeleton: Skeleton3D, up: Vector3, forward: Vector3) -> void:
	var lift := tan(deg_to_rad(shoulder_raise_degrees))
	var back := tan(deg_to_rad(shoulder_square_degrees))
	for side in [["LeftShoulder", "LeftArm"], ["RightShoulder", "RightArm"]]:
		var clavicle: int = _bones[side[0]]
		var arm: int = _bones[side[1]]
		var arm_basis := skeleton.get_bone_global_pose(arm).basis
		var direction := _segment(skeleton, clavicle, arm)
		_point(skeleton, clavicle, direction, direction + up * lift - forward * back, 1.0)
		skeleton.set_bone_global_pose(arm, Transform3D(arm_basis, skeleton.get_bone_global_pose(arm).origin))


func _gun_arm(skeleton: Skeleton3D, up: Vector3, forward: Vector3, right: Vector3) -> void:
	var shoulder := skeleton.get_bone_global_pose(_bones.RightArm).origin
	var reach := _arm_length(skeleton, "Right")
	var offset := LOW_READY_HAND.lerp(AIM_HAND, aim_weight)
	var target := shoulder + (forward * offset.x + up * offset.y + right * offset.z) * reach
	# Elbow back and out at low-ready, down and out when aimed.
	var pole := (-forward + right * 0.6).lerp(-up + right * 0.4, aim_weight)
	_two_bone(skeleton, "Right", target, pole, 1.0)
	# Silencer forward: angled down at low-ready, level when aimed; gun upright.
	var pitch := Quaternion(right, -deg_to_rad(low_ready_pitch_degrees) * (1.0 - aim_weight))
	_orient_hand(skeleton, pitch * forward, pitch * up, 1.0)
	if recoil > 0.0:
		var kick := deg_to_rad(recoil_degrees) * recoil
		_rotate(skeleton, _bones.RightForeArm, Quaternion(right, kick * 0.6))
		_rotate(skeleton, _bones.RightHand, Quaternion(right, kick * 0.4))


func _off_arm(skeleton: Skeleton3D, up: Vector3, forward: Vector3, right: Vector3) -> void:
	var shoulder := skeleton.get_bone_global_pose(_bones.LeftArm).origin
	var reach := _arm_length(skeleton, "Left")
	var target := shoulder + (forward * OFF_HAND.x + up * OFF_HAND.y - right * OFF_HAND.z) * reach
	_two_bone(skeleton, "Left", target, -forward - right * 0.3, 1.0)


## Two-bone IK on side's arm toward target (skeleton space), elbow bending toward pole.
func _two_bone(skeleton: Skeleton3D, side: String, target: Vector3, pole: Vector3, weight: float) -> void:
	var upper: int = _bones[side + "Arm"]
	var lower: int = _bones[side + "ForeArm"]
	var hand: int = _bones[side + "Hand"]
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(skeleton.get_bone_global_pose(hand).origin)
	var to_target := target - a
	var reach := clampf(to_target.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := to_target.normalized()
	var cos_a := clampf((l1 * l1 + reach * reach - l2 * l2) / (2.0 * l1 * reach), -1.0, 1.0)
	var bend := (pole - u * pole.dot(u)).normalized()
	var elbow := a + u * l1 * cos_a + bend * l1 * sqrt(1.0 - cos_a * cos_a)
	_point(skeleton, upper, b - a, elbow - a, weight)
	var b2 := skeleton.get_bone_global_pose(lower).origin
	_point(skeleton, lower, _segment(skeleton, lower, hand), a + u * reach - b2, weight)


## Turns the right hand so the gun points along direction with gun_up toward up.
func _orient_hand(skeleton: Skeleton3D, direction: Vector3, gun_up: Vector3, weight: float) -> void:
	var hand: int = _bones.RightHand
	var pose := skeleton.get_bone_global_pose(hand)
	var wanted := _frame(direction, gun_up) * _frame(gun_dir_in_hand, gun_up_in_hand).inverse()
	var rotation := pose.basis.get_rotation_quaternion().slerp(wanted.get_rotation_quaternion(), weight)
	skeleton.set_bone_global_pose(hand, Transform3D(Basis(rotation), pose.origin))


func _arm_length(skeleton: Skeleton3D, side: String) -> float:
	return skeleton.get_bone_rest(_bones[side + "ForeArm"]).origin.length() \
			+ skeleton.get_bone_rest(_bones[side + "Hand"]).origin.length()


## Rotates bone (about its own origin) so from_direction turns toward to_direction.
func _point(skeleton: Skeleton3D, bone: int, from_direction: Vector3, to_direction: Vector3, weight: float) -> void:
	if from_direction.is_zero_approx() or to_direction.is_zero_approx():
		return
	var arc := Quaternion(from_direction.normalized(), to_direction.normalized())
	_rotate(skeleton, bone, Quaternion.IDENTITY.slerp(arc, weight))


func _rotate(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(rotation) * pose.basis, pose.origin))


## Unit direction from bone to child.
func _segment(skeleton: Skeleton3D, bone: int, child: int) -> Vector3:
	return (skeleton.get_bone_global_pose(child).origin - skeleton.get_bone_global_pose(bone).origin).normalized()


func _dir(model_direction: Vector3) -> Vector3:
	return (model_to_skeleton * model_direction).normalized()


## Orthonormal basis with z along forward and y as close to up as possible.
static func _frame(forward: Vector3, up: Vector3) -> Basis:
	var z := forward.normalized()
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x), z)
