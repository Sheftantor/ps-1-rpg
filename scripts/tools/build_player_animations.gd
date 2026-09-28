# Builds the player's AnimationLibrary for the Mixamo-rigged character model.
# Re-run after editing a pose or replacing a source clip:
#   godot --headless --path . -s res://scripts/tools/build_player_animations.gd
#
# Idle, Walking and Running come from the Mixamo FBX clips: renamed, looped,
# made in place (Mixamo's walk/run carry forward root motion) and given a
# closed right hand for the sword. The sword moves are posed here instead:
# each key gives hand/foot targets in character space (+Z forward, -X is the
# character's right, 1 unit ~ rig height) and two-bone IK solves the limbs.
extends SceneTree

const RIG_SCENE := "res://Import/Character/Idle.fbx"
const OUTPUT_PATH := "res://resources/player/player_animations.tres"
const MIXAMO_CLIPS := {
	&"Idle": RIG_SCENE,
	&"Walking": "res://Import/Character/Walking.fbx",
	&"Running": "res://Import/Character/Running.fbx",
}
const SKELETON := "Skeleton3D"
const P := "mixamorig_"

## The sword grip crosses the palm diagonally, so the blade leans this far from
## the thumb direction toward the fingers. Keep in sync with the Sword transform
## in res://scenes/player_model.tscn (printed by this tool).
const GRIP_ANGLE := deg_to_rad(30.0)
## Warn when a pose bends the wrist further than this from the forearm.
const MAX_WRIST_BEND := 50.0

const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## Mixamo's idle hangs the hand thumb-back, which points the blade back into
## the leg; the forearm is twisted so the blade points this way instead.
const IDLE_BLADE_DIR := Vector3(0, -0.45, 0.9)

var _skel: Skeleton3D
var _rest_rot: Array[Quaternion] = []
var _rest_pos: Array[Vector3] = []
## Rest-pose primary (along the bone) and secondary (front/thumb/top) axes.
var _rest_dir: Dictionary[int, Vector3] = {}
var _rest_ref: Dictionary[int, Vector3] = {}
## Per-bone local rotation offsets applied on top of whatever the parent does.
var _grip_fingers: Dictionary[int, Quaternion] = {}
var _relaxed_fingers: Dictionary[int, Quaternion] = {}
var _warnings: PackedStringArray = []
var _clip_name := ""


func _initialize() -> void:
	var rig: Node3D = (load(RIG_SCENE) as PackedScene).instantiate()
	_skel = rig.get_node(SKELETON)
	for i in _skel.get_bone_count():
		var rest := _skel.get_bone_global_rest(i)
		_rest_rot.append(rest.basis.get_rotation_quaternion())
		_rest_pos.append(rest.origin)
	_setup_axes()
	_setup_fingers()

	var library := AnimationLibrary.new()
	for clip_name: StringName in MIXAMO_CLIPS:
		library.add_animation(clip_name, _convert_mixamo(clip_name, MIXAMO_CLIPS[clip_name]))
	library.add_animation(&"Attack", _build(&"Attack", _attack_keys(), 0.5))
	library.add_animation(&"StrongAttack", _build(&"StrongAttack", _strong_attack_keys(), 1.0))
	library.add_animation(&"Jump", _build(&"Jump", _jump_keys(), 1.1))
	library.add_animation(&"AirAttack", _build(&"AirAttack", _air_attack_keys(), 0.5))
	library.add_animation(&"AirStrongAttack", _build(&"AirStrongAttack", _air_strong_attack_keys(), 1.0))

	var err := ResourceSaver.save(library, OUTPUT_PATH)
	if err != OK:
		push_error("Saving %s failed: %s" % [OUTPUT_PATH, error_string(err)])
	else:
		print("Saved %s: %s" % [OUTPUT_PATH, library.get_animation_list()])
	for warning in _warnings:
		print("WARNING: ", warning)
	print("Sword transform (RightHand-local): ", var_to_str(_sword_transform()))
	rig.free()
	quit()


func _bone(bone_name: String) -> int:
	var index := _skel.find_bone(P + bone_name)
	assert(index >= 0, "Rig has no bone " + bone_name)
	return index


func _setup_axes() -> void:
	for side in ["Left", "Right"]:
		for pair in [["Arm", "ForeArm"], ["ForeArm", "Hand"], ["Hand", "HandMiddle1"], ["UpLeg", "Leg"], ["Leg", "Foot"]]:
			var bone := _bone(side + pair[0])
			_rest_dir[bone] = (_rest_pos[_bone(side + pair[1])] - _rest_pos[bone]).normalized()
			# T-pose, palms down: thumbs, elbow creases and kneecaps all face forward.
			_rest_ref[bone] = Vector3.BACK


func _setup_fingers() -> void:
	# Relative curls, expressed in the T-pose frame: rotating about Z folds a
	# finger toward the palm (-Y); the sign flips for the left hand.
	for finger in FINGERS:
		var curls: PackedFloat32Array = [75.0, 95.0, 65.0]
		for segment in 3:
			var angle := deg_to_rad(curls[segment])
			_grip_fingers[_bone("RightHand%s%d" % [finger, segment + 1])] = Quaternion(Vector3.BACK, angle)
			_relaxed_fingers[_bone("LeftHand%s%d" % [finger, segment + 1])] = Quaternion(Vector3.BACK, -angle * 0.4)
	_grip_fingers[_bone("RightHandThumb1")] = Quaternion(Vector3.RIGHT, deg_to_rad(40.0))
	_grip_fingers[_bone("RightHandThumb2")] = Quaternion(Vector3.BACK, deg_to_rad(25.0))
	_grip_fingers[_bone("RightHandThumb3")] = Quaternion(Vector3.BACK, deg_to_rad(20.0))
	_relaxed_fingers[_bone("LeftHandThumb1")] = Quaternion(Vector3.RIGHT, deg_to_rad(15.0))


## Local rotation for a bone that only rotates relative to its parent by
## `offset` (given in the T-pose frame): independent of the parent's pose.
func _relative_local(bone: int, offset: Quaternion) -> Quaternion:
	var parent := _skel.get_bone_parent(bone)
	return _rest_rot[parent].inverse() * offset * _rest_rot[bone]


# --- Mixamo clips ---------------------------------------------------------------

func _convert_mixamo(clip_name: StringName, path: String) -> Animation:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var source: AnimationPlayer = scene.get_node("AnimationPlayer")
	var anim: Animation = source.get_animation(source.get_animation_list()[0]).duplicate(true)
	scene.free()
	anim.resource_name = clip_name
	anim.loop_mode = Animation.LOOP_LINEAR

	# In place: remove the hips' average horizontal travel, keep the sway.
	var hips := anim.find_track(NodePath(SKELETON + ":" + P + "Hips"), Animation.TYPE_POSITION_3D)
	var count := anim.track_get_key_count(hips)
	var first: Vector3 = anim.track_get_key_value(hips, 0)
	var last: Vector3 = anim.track_get_key_value(hips, count - 1)
	var travel := Vector3(last.x - first.x, 0.0, last.z - first.z)
	if travel.length() > 0.05:
		var start_time := anim.track_get_key_time(hips, 0)
		var span := maxf(anim.track_get_key_time(hips, count - 1) - start_time, 0.001)
		for key in count:
			var weight := (anim.track_get_key_time(hips, key) - start_time) / span
			var value: Vector3 = anim.track_get_key_value(hips, key)
			anim.track_set_key_value(hips, key, value - first * Vector3(1, 0, 1) - travel * weight)

	# Close the right hand around the sword grip.
	for bone: int in _grip_fingers:
		var track_path := NodePath(SKELETON + ":" + _skel.get_bone_name(bone))
		var track := anim.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track >= 0:
			anim.remove_track(track)
		track = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, track_path)
		anim.rotation_track_insert_key(track, 0.0, _relative_local(bone, _grip_fingers[bone]))
	if clip_name == &"Idle":
		_twist_forearm_to_blade(anim, IDLE_BLADE_DIR)
	return anim


## Rolls the right forearm about its own length (so the hand stays put) until
## the sword, at the clip's first frame, points as close to `target` as it can.
func _twist_forearm_to_blade(anim: Animation, target: Vector3) -> void:
	var global := Quaternion.IDENTITY
	var forearm_global := Quaternion.IDENTITY
	for bone_name in ["Hips", "Spine", "Spine1", "Spine2", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]:
		var bone := _bone(bone_name)
		var track := anim.find_track(NodePath(SKELETON + ":" + P + bone_name), Animation.TYPE_ROTATION_3D)
		if track >= 0:
			global *= anim.rotation_track_interpolate(track, 0.0)
		else:
			global *= _skel.get_bone_rest(bone).basis.get_rotation_quaternion()
		if bone_name == "RightForeArm":
			forearm_global = global
	var blade := global * _sword_transform().basis.y
	var forearm := _bone("RightForeArm")
	var axis_local := _rest_rot[forearm].inverse() * _rest_dir[forearm]
	var axis := forearm_global * axis_local
	var from := (blade - axis * blade.dot(axis)).normalized()
	var to := (target - axis * target.dot(axis)).normalized()
	var twist := Quaternion(axis_local, from.signed_angle_to(to, axis))
	var track := anim.find_track(NodePath(SKELETON + ":" + P + "RightForeArm"), Animation.TYPE_ROTATION_3D)
	for key in anim.track_get_key_count(track):
		anim.track_set_key_value(track, key, (anim.track_get_key_value(track, key) as Quaternion) * twist)


# --- Posed clips ----------------------------------------------------------------

## keys: [[time, pose], ...]. Every bone gets a rotation track so blending
## from the Mixamo clips never leaves a bone behind.
func _build(clip_name: StringName, keys: Array, length: float) -> Animation:
	_clip_name = clip_name
	var anim := Animation.new()
	anim.resource_name = clip_name
	anim.length = length
	var solved: Array = []
	for key: Array in keys:
		solved.append(_solve(key[1], key[0]))

	var hips_track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_track, SKELETON + ":" + P + "Hips")
	for i in keys.size():
		anim.position_track_insert_key(hips_track, keys[i][0], solved[i].hips)
	for bone in _skel.get_bone_count():
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, SKELETON + ":" + _skel.get_bone_name(bone))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		for i in keys.size():
			anim.rotation_track_insert_key(track, keys[i][0], solved[i].local[bone])
	return anim


## Pose keys (all optional):
##   hips: Vector3 offset from the rest hips position.
##   hips_rot / spine: Euler degrees (pitch forward, yaw left, roll right);
##     spine is spread over Spine, Spine1 and Spine2 on top of the hips.
##   head: Euler degrees, where the head looks in character space.
##   r_hand/l_hand: wrist target; r_blade: sword direction; l_thumb: left
##     thumb direction; r_pole/l_pole: which way the elbow points.
##   r_foot/l_foot: ankle target; r_knee/l_knee: which way the knee points;
##   r_toe/l_toe: foot pitch in degrees (+ = toes down).
func _solve(pose: Dictionary, time: float) -> Dictionary:
	var count := _skel.get_bone_count()
	var global_rot: Array[Quaternion] = []
	var global_pos: Array[Vector3] = []
	var local: Array[Quaternion] = []
	global_rot.resize(count)
	global_pos.resize(count)
	local.resize(count)
	var hips_pos: Vector3 = _rest_pos[0] + pose.get("hips", Vector3.ZERO)
	var spine_rot := _euler(pose.get("spine", Vector3.ZERO) / 3.0)
	var head_rot := _euler(pose.get("head", Vector3.ZERO))
	var aims: Dictionary[int, Quaternion] = {}

	for bone in count:
		var parent := _skel.get_bone_parent(bone)
		var bone_name := _skel.get_bone_name(bone).trim_prefix(P)
		if parent >= 0:
			global_pos[bone] = global_pos[parent] + global_rot[parent] * _skel.get_bone_rest(bone).origin
		else:
			global_pos[bone] = hips_pos

		var delta: Quaternion
		var parent_delta := global_rot[parent] * _rest_rot[parent].inverse() if parent >= 0 else Quaternion.IDENTITY
		match bone_name:
			"Hips":
				delta = _euler(pose.get("hips_rot", Vector3.ZERO))
			"Spine", "Spine1", "Spine2":
				delta = parent_delta * spine_rot
			"Neck":
				delta = parent_delta.slerp(head_rot, 0.5)
			"Head":
				delta = head_rot
			"RightArm", "LeftArm":
				_solve_arm(bone_name.left(1).to_lower(), bone_name.trim_suffix("Arm"), global_pos[bone], pose, aims, time)
				delta = aims[bone]
			"RightUpLeg", "LeftUpLeg":
				_solve_leg(bone_name.left(1).to_lower(), bone_name.trim_suffix("UpLeg"), global_pos[bone], pose, aims)
				delta = aims[bone]
			_:
				if aims.has(bone):
					delta = aims[bone]
				elif _grip_fingers.has(bone):
					delta = parent_delta * _grip_fingers[bone]
				elif _relaxed_fingers.has(bone):
					delta = parent_delta * _relaxed_fingers[bone]
				else:
					delta = parent_delta
		global_rot[bone] = delta * _rest_rot[bone]
		local[bone] = global_rot[parent].inverse() * global_rot[bone] if parent >= 0 else global_rot[bone]
	return {"hips": hips_pos, "local": local}


func _solve_arm(s: String, side: String, shoulder: Vector3, pose: Dictionary, aims: Dictionary[int, Quaternion], time: float) -> void:
	var arm := _bone(side + "Arm")
	var fore := _bone(side + "ForeArm")
	var hand := _bone(side + "Hand")
	var pole: Vector3 = pose.get(s + "_pole", Vector3(0, -1, -0.3))
	var joints := _two_bone(shoulder, pose[s + "_hand"], _rest_pos[fore].distance_to(_rest_pos[arm]),
			_rest_pos[hand].distance_to(_rest_pos[fore]), pole, "%s %s arm @%.2f" % [_clip_name, side, time])
	var upper := (joints[0] - shoulder).normalized()
	var forearm := (joints[1] - joints[0]).normalized()
	# The elbow crease faces away from the elbow point.
	aims[arm] = _aim(arm, upper, -pole)

	var thumb: Vector3
	var fingers: Vector3
	if s == "r":
		# Blade = cos(GRIP)*thumb + sin(GRIP)*fingers, and the hand stays as close
		# to the forearm line as that allows.
		var blade: Vector3 = (pose["r_blade"] as Vector3).normalized()
		var across := forearm - blade * forearm.dot(blade)
		if across.length() < 0.01:
			across = -pole - blade * (-pole).dot(blade)
		across = across.normalized()
		fingers = blade * sin(GRIP_ANGLE) + across * cos(GRIP_ANGLE)
		thumb = (blade - fingers * blade.dot(fingers)).normalized()
	else:
		thumb = (pose.get("l_thumb", Vector3.BACK) as Vector3).normalized()
		fingers = forearm - thumb * forearm.dot(thumb)
		if fingers.length() < 0.01:
			fingers = forearm
		fingers = fingers.normalized()
	var bend := rad_to_deg(fingers.angle_to(forearm))
	if bend > MAX_WRIST_BEND:
		_warnings.append("%s @%.2f: %s wrist bent %.0f deg" % [_clip_name, time, side, bend])
	aims[fore] = _aim(fore, forearm, thumb)
	aims[hand] = _aim(hand, fingers, thumb)


func _solve_leg(s: String, side: String, hip: Vector3, pose: Dictionary, aims: Dictionary[int, Quaternion]) -> void:
	var thigh := _bone(side + "UpLeg")
	var shin := _bone(side + "Leg")
	var foot := _bone(side + "Foot")
	var rest_foot := _rest_pos[foot]
	var ankle: Vector3 = pose.get(s + "_foot", Vector3(rest_foot.x, rest_foot.y, 0.0))
	var knee: Vector3 = pose.get(s + "_knee", Vector3(signf(rest_foot.x) * 0.15, 0.0, 1.0))
	var joints := _two_bone(hip, ankle, _rest_pos[shin].distance_to(_rest_pos[thigh]),
			_rest_pos[foot].distance_to(_rest_pos[shin]), knee, "")
	aims[thigh] = _aim(thigh, (joints[0] - hip).normalized(), knee)
	aims[shin] = _aim(shin, (joints[1] - joints[0]).normalized(), knee)
	var yaw := atan2(knee.x, knee.z) - atan2(signf(rest_foot.x) * 0.15, 1.0)
	aims[foot] = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, deg_to_rad(pose.get(s + "_toe", 0.0)))


## Returns [middle joint, end joint]. Out-of-reach targets are clamped (and
## reported when `label` is set, since that usually means a typo in a pose).
func _two_bone(root: Vector3, target: Vector3, upper: float, lower: float, pole: Vector3, label: String) -> Array[Vector3]:
	var to_target := target - root
	var reach := upper + lower
	if label != "" and to_target.length() > reach + 0.01:
		_warnings.append("%s: target %.3f out of reach (%.3f)" % [label, to_target.length(), reach])
	var distance := clampf(to_target.length(), absf(upper - lower) + 0.001, reach * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0)
	var bend_dir := (pole - dir * pole.dot(dir)).normalized()
	var middle := root + dir * cos_a * upper + bend_dir * sqrt(1.0 - cos_a * cos_a) * upper
	return [middle, root + dir * distance]


## Rotation (in character space) taking a bone's rest axes onto dir/ref.
func _aim(bone: int, dir: Vector3, ref: Vector3) -> Quaternion:
	var target := _frame(dir, ref)
	var rest := _frame(_rest_dir[bone], _rest_ref[bone])
	return (target * rest.inverse()).get_rotation_quaternion()


func _frame(primary: Vector3, ref: Vector3) -> Basis:
	var x := primary.normalized()
	var y := (ref - x * ref.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _euler(degrees: Vector3) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(degrees.y)) \
			* Quaternion(Vector3.RIGHT, deg_to_rad(degrees.x)) \
			* Quaternion(Vector3.BACK, deg_to_rad(degrees.z))


## Where the Sword scene (blade along +Y, edge along +X) sits in RightHand's
## local space: grip through the closed fist, blade out the thumb side at
## GRIP_ANGLE toward the fingers.
func _sword_transform() -> Transform3D:
	var hand := _bone("RightHand")
	var to_local := Basis(_rest_rot[hand]).inverse()
	var hand_frame := _frame(_rest_dir[hand], _rest_ref[hand])
	var fingers := hand_frame.x
	var thumb := hand_frame.y
	var back_of_hand := hand_frame.z
	var blade := thumb * cos(GRIP_ANGLE) + fingers * sin(GRIP_ANGLE)
	var edge := (fingers - blade * fingers.dot(blade)).normalized()
	var basis := to_local * Basis(edge, blade, edge.cross(blade))
	var hand_length := _rest_pos[_bone("RightHandMiddle1")].distance_to(_rest_pos[hand])
	var grip := to_local * (fingers * hand_length * 0.75 - back_of_hand * 0.018)
	return Transform3D(basis, grip)


func _with(base: Dictionary, changes: Dictionary) -> Dictionary:
	var pose := base.duplicate()
	pose.merge(changes, true)
	return pose


# --- Poses ----------------------------------------------------------------------
# Rest landmarks: hips (0, 0.53, 0), shoulders (+-0.11, 0.77, -0.03), arm reach
# ~0.26, ankles (+-0.08, 0.05, -0.03), top of head ~0.99.

## Sword-ready stance that the ground attacks start and end on.
func _ready_pose() -> Dictionary:
	return {
		"hips": Vector3(0, -0.025, 0),
		"r_hand": Vector3(-0.15, 0.60, 0.10), "r_blade": Vector3(0.05, 0.55, 0.83), "r_pole": Vector3(-0.6, -0.8, -0.2),
		"l_hand": Vector3(0.14, 0.53, 0.06), "l_thumb": Vector3(0.1, 0, 1), "l_pole": Vector3(0.3, -0.3, -1),
		"r_foot": Vector3(-0.09, 0.052, 0.06), "l_foot": Vector3(0.09, 0.052, -0.07),
	}


## Airborne base: legs loosely tucked, sword ready.
func _air_pose() -> Dictionary:
	return {
		"hips_rot": Vector3(5, 0, 0), "spine": Vector3(5, 0, 0),
		"r_hand": Vector3(-0.15, 0.62, 0.10), "r_blade": Vector3(0.05, 0.5, 0.86), "r_pole": Vector3(-0.6, -0.8, -0.2),
		"l_hand": Vector3(0.18, 0.60, 0.05), "l_thumb": Vector3(0, 0.3, 1), "l_pole": Vector3(0.6, -0.4, -1),
		"r_foot": Vector3(-0.08, 0.20, 0.04), "l_foot": Vector3(0.08, 0.14, -0.08),
		"r_knee": Vector3(-0.1, 0.4, 1), "l_knee": Vector3(0.1, 0.2, 1), "r_toe": 25.0, "l_toe": 25.0,
	}


## Quick diagonal slash from over the right shoulder down across to the left.
## Impact (sword crossing the front) at 0.15s.
func _attack_keys() -> Array:
	var ready := _ready_pose()
	var windup := _with(ready, {
		"hips": Vector3(0, -0.03, -0.01), "hips_rot": Vector3(0, -25, 0), "spine": Vector3(-5, -25, 0),
		"r_hand": Vector3(-0.20, 0.86, -0.04), "r_blade": Vector3(-0.25, 0.75, -0.6), "r_pole": Vector3(-1, -0.5, 0.3),
		"l_hand": Vector3(0.10, 0.62, 0.18), "l_thumb": Vector3(0, 1, 0.2), "l_pole": Vector3(1, -0.5, -0.3),
	})
	var impact := _with(ready, {
		"hips": Vector3(0, -0.05, 0.02), "hips_rot": Vector3(0, 5, 0), "spine": Vector3(5, 10, 0),
		"r_hand": Vector3(-0.05, 0.66, 0.22), "r_blade": Vector3(0.5, -0.15, 0.85), "r_pole": Vector3(-0.3, -1, 0),
		"l_hand": Vector3(0.17, 0.55, -0.05),
	})
	var follow := _with(ready, {
		"hips": Vector3(0, -0.05, 0.02), "hips_rot": Vector3(0, 20, 0), "spine": Vector3(8, 25, 0),
		"r_hand": Vector3(0.04, 0.58, 0.17), "r_blade": Vector3(0.85, -0.45, -0.2), "r_pole": Vector3(0, -1, 0),
		"l_hand": Vector3(0.19, 0.56, -0.08),
	})
	var hold := _with(follow, {
		"hips": Vector3(0, -0.04, 0.01), "r_hand": Vector3(0.02, 0.57, 0.16), "r_blade": Vector3(0.8, -0.5, -0.1),
	})
	return [[0.0, ready], [0.10, windup], [0.15, impact], [0.20, follow], [0.32, hold], [0.5, ready]]


## Big overhead wind-up, stepping downward chop, long recovery. Impact at 0.44s.
func _strong_attack_keys() -> Array:
	var ready := _ready_pose()
	var gather := _with(ready, {
		"hips": Vector3(0, -0.06, 0), "spine": Vector3(8, -10, 0),
		"r_hand": Vector3(-0.19, 0.60, 0.02), "r_blade": Vector3(-0.2, 0.7, 0.6),
	})
	var peak := _with(ready, {
		"hips": Vector3(0, -0.01, -0.03), "hips_rot": Vector3(-5, -20, 0), "spine": Vector3(-15, -10, 0),
		"r_hand": Vector3(-0.08, 0.98, -0.06), "r_blade": Vector3(0.05, 0.35, -0.95), "r_pole": Vector3(-1, 0, 0.5),
		"l_hand": Vector3(0.0, 0.97, 0.0), "l_thumb": Vector3(0, 0.3, -1), "l_pole": Vector3(1, 0, 0.5),
		"r_foot": Vector3(-0.09, 0.10, 0.02), "l_foot": Vector3(0.09, 0.052, -0.08),
	})
	var swing := _with(ready, {
		"hips": Vector3(0, -0.05, 0.04), "hips_rot": Vector3(5, -5, 0), "spine": Vector3(10, 0, 0),
		"r_hand": Vector3(-0.05, 0.86, 0.22), "r_blade": Vector3(0, 0.9, 0.43), "r_pole": Vector3(-1, -0.3, 0),
		"l_hand": Vector3(0.02, 0.84, 0.20), "l_thumb": Vector3(0, 0.5, 1), "l_pole": Vector3(1, -0.3, 0),
		"r_foot": Vector3(-0.09, 0.07, 0.16), "l_foot": Vector3(0.09, 0.052, -0.10),
	})
	var impact := _with(ready, {
		"hips": Vector3(0, -0.11, 0.06), "hips_rot": Vector3(15, 5, 0), "spine": Vector3(20, 5, 0),
		"r_hand": Vector3(-0.05, 0.44, 0.30), "r_blade": Vector3(0, -0.6, 0.8), "r_pole": Vector3(-1, 0.2, 0),
		"l_hand": Vector3(0.05, 0.45, 0.24), "l_thumb": Vector3(0, 1, 0.3), "l_pole": Vector3(1, 0.2, 0),
		"r_foot": Vector3(-0.09, 0.052, 0.20), "l_foot": Vector3(0.09, 0.052, -0.12),
	})
	var settle := _with(impact, {
		"hips": Vector3(0, -0.12, 0.06), "r_hand": Vector3(-0.05, 0.42, 0.28), "r_blade": Vector3(0, -0.75, 0.65),
	})
	var recover := _with(ready, {
		"hips": Vector3(0, -0.07, 0.03), "hips_rot": Vector3(5, 0, 0), "spine": Vector3(8, 0, 0),
		"r_hand": Vector3(-0.12, 0.52, 0.18), "r_blade": Vector3(0, 0.1, 1),
		"r_foot": Vector3(-0.09, 0.08, 0.12), "l_foot": Vector3(0.09, 0.052, -0.09),
	})
	return [[0.0, ready], [0.12, gather], [0.32, peak], [0.39, swing], [0.44, impact], [0.56, settle],
			[0.72, settle], [0.86, recover], [1.0, ready]]


## Takeoff, tuck at the apex, then legs reach down; the last key is held while
## falling. Player.JUMP_FALL_TIME points at the fall pose for walking off ledges.
func _jump_keys() -> Array:
	var crouch := {
		"hips": Vector3(0, -0.08, 0), "hips_rot": Vector3(10, 0, 0), "spine": Vector3(10, 0, 0),
		"r_hand": Vector3(-0.17, 0.50, -0.08), "r_blade": Vector3(0, -0.3, 1), "r_pole": Vector3(-0.5, -0.5, -1),
		"l_hand": Vector3(0.17, 0.50, -0.08), "l_thumb": Vector3(0, 0, 1), "l_pole": Vector3(0.5, -0.5, -1),
		"r_foot": Vector3(-0.09, 0.052, 0.0), "l_foot": Vector3(0.09, 0.052, -0.03),
	}
	var launch := {
		"hips_rot": Vector3(-3, 0, 0), "spine": Vector3(-5, 0, 0),
		"r_hand": Vector3(-0.16, 0.80, 0.12), "r_blade": Vector3(0, 0.6, 0.8), "r_pole": Vector3(-1, -0.5, 0),
		"l_hand": Vector3(0.16, 0.82, 0.10), "l_thumb": Vector3(0, 0.4, -0.9), "l_pole": Vector3(1, -0.5, 0),
		"r_foot": Vector3(-0.07, 0.04, -0.03), "l_foot": Vector3(0.07, 0.04, -0.05), "r_toe": 35.0, "l_toe": 35.0,
	}
	var tuck := {
		"hips": Vector3(0, 0.02, 0), "hips_rot": Vector3(8, 0, 0), "spine": Vector3(8, 0, 0),
		"r_hand": Vector3(-0.24, 0.66, 0.02), "r_blade": Vector3(-0.5, 0.3, 0.8), "r_pole": Vector3(-0.3, -1, -0.3),
		"l_hand": Vector3(0.22, 0.70, 0.10), "l_thumb": Vector3(0, 0.5, 1), "l_pole": Vector3(0.3, -1, -0.3),
		"r_foot": Vector3(-0.08, 0.24, 0.02), "l_foot": Vector3(0.08, 0.18, -0.06),
		"r_knee": Vector3(-0.1, 0.5, 1), "l_knee": Vector3(0.1, 0.4, 1), "r_toe": 25.0, "l_toe": 25.0,
	}
	var fall := {
		"hips_rot": Vector3(2, 0, 0), "spine": Vector3(3, 0, 0),
		"r_hand": Vector3(-0.25, 0.68, 0.06), "r_blade": Vector3(-0.3, 0.5, 0.8), "r_pole": Vector3(-0.3, -1, -0.3),
		"l_hand": Vector3(0.25, 0.70, 0.04), "l_thumb": Vector3(0, 0.5, 1), "l_pole": Vector3(0.3, -1, -0.3),
		"r_foot": Vector3(-0.08, 0.09, 0.06), "l_foot": Vector3(0.08, 0.07, -0.05), "r_toe": 20.0, "l_toe": 20.0,
	}
	return [[0.0, crouch], [0.10, launch], [0.38, tuck], [0.70, fall], [1.1, fall]]


## Flat horizontal slash from the right while airborne. Impact at 0.15s.
func _air_attack_keys() -> Array:
	var base := _air_pose()
	var windup := _with(base, {
		"hips_rot": Vector3(5, -30, 0), "spine": Vector3(-5, -25, 0),
		"r_hand": Vector3(-0.24, 0.76, -0.06), "r_blade": Vector3(-0.55, 0.35, -0.75), "r_pole": Vector3(-0.3, -1, 0.3),
		"l_hand": Vector3(0.08, 0.68, 0.20), "l_thumb": Vector3(0, 1, 0.2), "l_pole": Vector3(1, -0.5, -0.3),
	})
	var impact := _with(base, {
		"hips_rot": Vector3(5, 10, 0), "spine": Vector3(0, 10, 0),
		"r_hand": Vector3(-0.04, 0.72, 0.23), "r_blade": Vector3(0.45, 0.05, 0.9), "r_pole": Vector3(-0.3, -1, 0),
		"l_hand": Vector3(0.20, 0.62, -0.04),
	})
	var follow := _with(base, {
		"hips_rot": Vector3(5, 30, 0), "spine": Vector3(5, 20, 0),
		"r_hand": Vector3(0.08, 0.70, 0.16), "r_blade": Vector3(0.95, 0, -0.3), "r_pole": Vector3(0, -1, 0),
		"l_hand": Vector3(0.21, 0.63, -0.08),
	})
	var hold := _with(follow, {"r_hand": Vector3(0.07, 0.69, 0.15), "r_blade": Vector3(0.9, -0.1, -0.4)})
	return [[0.0, base], [0.09, windup], [0.15, impact], [0.21, follow], [0.33, hold], [0.5, base]]


## Arched-back overhead wind-up, then a plunging chop with the legs driving
## down. Impact at 0.44s.
func _air_strong_attack_keys() -> Array:
	var base := _air_pose()
	var windup := _with(base, {
		"hips": Vector3(0, 0.02, -0.02), "hips_rot": Vector3(-12, -10, 0), "spine": Vector3(-15, -5, 0),
		"r_hand": Vector3(-0.07, 1.00, -0.08), "r_blade": Vector3(0, 0.3, -0.95), "r_pole": Vector3(-1, 0, 0.5),
		"l_hand": Vector3(0.0, 0.97, -0.03), "l_thumb": Vector3(0, 0.3, -1), "l_pole": Vector3(1, 0, 0.5),
		"r_foot": Vector3(-0.08, 0.26, -0.14), "l_foot": Vector3(0.08, 0.22, -0.18),
		"r_knee": Vector3(-0.1, -0.3, 1), "l_knee": Vector3(0.1, -0.3, 1),
	})
	var swing := _with(base, {
		"hips_rot": Vector3(5, -3, 0), "spine": Vector3(10, 0, 0),
		"r_hand": Vector3(-0.05, 0.86, 0.22), "r_blade": Vector3(0, 0.9, 0.45), "r_pole": Vector3(-1, -0.3, 0),
		"l_hand": Vector3(0.02, 0.84, 0.20), "l_thumb": Vector3(0, 0.5, 1), "l_pole": Vector3(1, -0.3, 0),
		"r_foot": Vector3(-0.08, 0.15, 0.02), "l_foot": Vector3(0.08, 0.12, -0.06),
	})
	var impact := _with(base, {
		"hips": Vector3(0, -0.02, 0.03), "hips_rot": Vector3(15, 0, 0), "spine": Vector3(25, 0, 0),
		"r_hand": Vector3(-0.05, 0.60, 0.33), "r_blade": Vector3(0, -0.6, 0.8), "r_pole": Vector3(-1, 0.2, 0),
		"l_hand": Vector3(0.05, 0.60, 0.29), "l_thumb": Vector3(0, 1, 0.3), "l_pole": Vector3(1, 0.2, 0),
		"r_foot": Vector3(-0.08, 0.05, 0.10), "l_foot": Vector3(0.08, 0.04, -0.02),
		"r_knee": Vector3(-0.1, 0, 1), "l_knee": Vector3(0.1, 0, 1), "r_toe": 30.0, "l_toe": 30.0,
	})
	var plunge := _with(impact, {"r_hand": Vector3(-0.05, 0.60, 0.30), "r_blade": Vector3(0, -0.9, 0.4)})
	return [[0.0, base], [0.30, windup], [0.38, swing], [0.44, impact], [0.58, plunge], [0.76, plunge], [1.0, base]]
