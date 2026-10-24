# Adds the melee guard clips to the player's animation library and the guard
# layer to its AnimationTree:
#   godot --headless --path . -s res://scripts/tools/build_guard_clips.gd
#
# Guard is the high guard every melee weapon uses while blocking: the weapon
# raised across the front of the body, tip up and to the left, the right hand
# in front of the right side of the chest and the left hand bracing the weapon
# a little way up its length, the chest hunched forward and the chin tucked.
# GuardImpact is the same guard knocked back toward the chest by a blocked hit.
# Both are single poses built from the Idle clip's first frame (only the
# torso, head, arms and the bracing hand's fingers are used: the tree blends
# them over locomotion with GUARD_BONES, so the legs keep walking, strafing
# and backpedalling underneath in every direction). The weapon direction is
# measured from the MeleeWeapon node in res://scenes/player_model.tscn, so it
# follows any melee weapon built in that grip convention.
# Rerun after changing the numbers below or the source Idle clip.
extends SceneTree

const LIBRARY := "res://resources/player/player_animations_real.tres"
const MODEL := "res://scenes/player_model.tscn"
const TREE_PATH := "res://resources/player/player_animation_tree.tres"
const SOURCE_CLIP := &"Idle"
const GUARD := &"Guard"
const GUARD_IMPACT := &"GuardImpact"
const P := "mixamorig_"
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]

## Bones the guard is blended onto. Spine (the lowest) keeps the walk's sway.
const GUARD_BONES := ["Spine1", "Spine2", "Neck", "Head", "RightShoulder", "LeftShoulder",
		"RightArm", "RightForeArm", "RightHand", "LeftArm", "LeftForeArm", "LeftHand",
		"LeftHandThumb1", "LeftHandThumb2", "LeftHandThumb3",
		"LeftHandIndex1", "LeftHandIndex2", "LeftHandIndex3",
		"LeftHandMiddle1", "LeftHandMiddle2", "LeftHandMiddle3",
		"LeftHandRing1", "LeftHandRing2", "LeftHandRing3",
		"LeftHandPinky1", "LeftHandPinky2", "LeftHandPinky3"]

## Each pose. Hand targets are in the body frame (x right, y up, z forward)
## from the point between the shoulders, in arm reaches (shoulder to wrist).
## weapon: direction the weapon points (same frame). lean: chest pitch
## forward (degrees, spread over Spine1/Spine2); head: extra head pitch down.
## grip: how far up the weapon the left hand braces it (weapon units).
const GUARD_POSE := {
	"lean": 10.0, "head": 6.0,
	"r_hand": Vector3(0.42, -0.12, 0.62), "r_elbow": Vector3(1.0, -1.0, -0.2),
	"weapon": Vector3(-0.86, 0.48, 0.18),
	"grip": 0.22, "l_elbow": Vector3(-1.0, -1.0, -0.3),
}
const IMPACT_POSE := {
	"lean": -4.0, "head": -4.0,
	"r_hand": Vector3(0.40, -0.08, 0.42), "r_elbow": Vector3(1.0, -0.8, -0.4),
	"weapon": Vector3(-0.84, 0.52, 0.0),
	"grip": 0.22, "l_elbow": Vector3(-1.0, -0.8, -0.4),
}
## Left finger curl (degrees) per segment, and the thumb's.
const CURL := [70.0, 85.0, 60.0]
const THUMB_CURL := [25.0, 30.0, 20.0]
const LENGTH := 0.5


func _initialize() -> void:
	var library: AnimationLibrary = load(LIBRARY)
	var idle := library.get_animation(SOURCE_CLIP)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	root.add_child(model)
	(model.get_node(^"AnimationTree") as AnimationTree).active = false
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D")[0]
	var weapon_local := (model.get_node(^"Skeleton3D/RightHandAttachment/MeleeWeapon") as Node3D).transform

	for clip: StringName in [GUARD, GUARD_IMPACT]:
		var pose := GUARD_POSE if clip == GUARD else IMPACT_POSE
		var rotations := _solve(skeleton, idle, weapon_local, pose, clip)
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, _clip_from(idle, skeleton, rotations))
	var err := ResourceSaver.save(library, LIBRARY)
	print("saved %s (error %d)" % [LIBRARY, err])

	# The whole tree is rebuilt (it includes the guard layer): a loaded tree's
	# existing nodes refuse new connections from a script.
	var tree: AnimationNodeBlendTree = load("res://scripts/tools/build_player_animations.gd").build_tree()
	err = save_keeping_uid(tree, TREE_PATH)
	print("saved %s (error %d)" % [TREE_PATH, err])
	quit()


## Saves a freshly built resource over path without changing the file's uid.
static func save_keeping_uid(resource: Resource, path: String) -> Error:
	var uid := ResourceLoader.get_resource_uid(path)
	var err := ResourceSaver.save(resource, path)
	if err == OK and uid != ResourceUID.INVALID_ID:
		err = ResourceSaver.set_uid(path, uid)
	return err


## Adds the guard layer to the player's tree on top of `below`: GuardHold and
## GuardHit poses mixed by GuardRecoil (the blocked-hit knock-back), blended
## over the upper body by GuardBlend, which the caller connects onward and
## whose name is returned. Player drives both amounts. Called from
## build_player_animations.gd's build_tree().
static func add_guard_nodes(tree: AnimationNodeBlendTree, below: StringName) -> StringName:
	var hold := AnimationNodeAnimation.new()
	hold.animation = GUARD
	var hit := AnimationNodeAnimation.new()
	hit.animation = GUARD_IMPACT
	tree.add_node(&"GuardHold", hold, Vector2(600, -240))
	tree.add_node(&"GuardHit", hit, Vector2(600, -120))
	tree.add_node(&"GuardRecoil", AnimationNodeBlend2.new(), Vector2(800, -180))
	tree.connect_node(&"GuardRecoil", 0, &"GuardHold")
	tree.connect_node(&"GuardRecoil", 1, &"GuardHit")
	var guard := AnimationNodeBlend2.new()
	guard.filter_enabled = true
	for bone: String in GUARD_BONES:
		guard.set_filter_path(NodePath("Skeleton3D:" + P + bone), true)
	tree.add_node(&"GuardBlend", guard, Vector2(1000, -60))
	tree.connect_node(&"GuardBlend", 0, below)
	tree.connect_node(&"GuardBlend", 1, &"GuardRecoil")
	return &"GuardBlend"


## Local rotations (bone -> Quaternion) for the guard bones in this pose.
static func _solve(skeleton: Skeleton3D, idle: Animation, weapon_local: Transform3D, pose: Dictionary, label: String) -> Dictionary:
	_pose_clip(skeleton, idle, 0.0)
	var frame := _body_frame(skeleton)
	var right: Vector3 = frame.x
	var up: Vector3 = frame.y
	var forward: Vector3 = frame.z

	# Hunch: pitch the chest forward about the body's right axis (Godot's
	# right-handed rotation about +X tips +Y toward -Z, so negate for forward).
	var lean := deg_to_rad(pose["lean"]) * 0.5
	for bone_name: String in ["Spine1", "Spine2"]:
		_rotate_global(skeleton, _bone(skeleton, bone_name), Basis(right, -lean))
	_rotate_global(skeleton, _bone(skeleton, "Head"), Basis(right, -deg_to_rad(pose["head"])))

	var r_arm := _bone(skeleton, "RightArm")
	var l_arm := _bone(skeleton, "LeftArm")
	var r_shoulder := _global(skeleton, r_arm).origin
	var l_shoulder := _global(skeleton, l_arm).origin
	var reach := _reach(skeleton, "Right")
	var origin := (r_shoulder + l_shoulder) * 0.5
	var to_body := func(v: Vector3) -> Vector3: return right * v.x + up * v.y + forward * v.z

	# Right arm to the hand target, elbow out and down.
	var r_target: Vector3 = origin + to_body.call(pose["r_hand"]) * reach
	_two_bone(skeleton, "Right", r_target, to_body.call(pose["r_elbow"]), label)

	# Right wrist: turn the hand so the weapon points along `weapon`.
	var hand := _bone(skeleton, "RightHand")
	var weapon_dir: Vector3 = (to_body.call(pose["weapon"]) as Vector3).normalized()
	var weapon := _global(skeleton, hand) * weapon_local
	_rotate_global(skeleton, hand, Basis(Quaternion(weapon.basis.y.normalized(), weapon_dir)))
	weapon = _global(skeleton, hand) * weapon_local
	_report_wrist(skeleton, "Right", label)

	# Left hand braces the weapon `grip` up its length; the wrist sits a palm's
	# width off the weapon, toward the left shoulder.
	var grip_point: Vector3 = weapon.origin + weapon.basis.y * float(pose["grip"])
	var palm := _hand_length(skeleton, "Left")
	var l_target := grip_point + (l_shoulder - grip_point).normalized() * palm * 0.9
	_two_bone(skeleton, "Left", l_target, to_body.call(pose["l_elbow"]), label)
	var l_hand := _bone(skeleton, "LeftHand")
	_point_bone(skeleton, l_hand, _bone(skeleton, "LeftHandMiddle1"), grip_point - _global(skeleton, l_hand).origin)
	_report_wrist(skeleton, "Left", label)
	_curl_fingers(skeleton, "Left", (grip_point - _global(skeleton, l_hand).origin).normalized())

	print("%s: reach %.3f, right hand %s, weapon tip %s, left hand %s (body frame, reaches)" % [label, reach,
			_in_frame(frame, _global(skeleton, hand).origin - origin, reach),
			_in_frame(frame, weapon.origin + weapon.basis.y * 0.47 - origin, reach),
			_in_frame(frame, _global(skeleton, l_hand).origin - origin, reach)])

	var result := {}
	for bone_name: String in GUARD_BONES:
		var bone := _bone(skeleton, bone_name)
		result[bone] = skeleton.get_bone_pose_rotation(bone)
	return result


## A looping clip: the Idle clip's first frame with `rotations` swapped in.
static func _clip_from(idle: Animation, skeleton: Skeleton3D, rotations: Dictionary) -> Animation:
	var out := Animation.new()
	out.length = LENGTH
	out.loop_mode = Animation.LOOP_LINEAR
	for track in idle.get_track_count():
		var type := idle.track_get_type(track)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var path := idle.track_get_path(track)
		var copy := out.add_track(type)
		out.track_set_path(copy, path)
		if type == Animation.TYPE_POSITION_3D:
			out.position_track_insert_key(copy, 0.0, idle.position_track_interpolate(track, 0.0))
			continue
		var bone := skeleton.find_bone(String(path.get_concatenated_subnames()))
		var value: Quaternion = rotations.get(bone, idle.rotation_track_interpolate(track, 0.0))
		out.rotation_track_insert_key(copy, 0.0, value)
	# Guard bones the Idle clip doesn't key (e.g. fingers) still need tracks.
	for bone: int in rotations:
		var path := NodePath("Skeleton3D:" + skeleton.get_bone_name(bone))
		if out.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var copy := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(copy, path)
			out.rotation_track_insert_key(copy, 0.0, rotations[bone])
	return out


## Places the elbow of side's arm (two-bone IK toward `pole`) and points the
## upper arm and forearm so the wrist lands on target.
static func _two_bone(skeleton: Skeleton3D, side: String, target: Vector3, pole: Vector3, label: String) -> void:
	var arm := _bone(skeleton, side + "Arm")
	var fore := _bone(skeleton, side + "ForeArm")
	var hand := _bone(skeleton, side + "Hand")
	var shoulder := _global(skeleton, arm).origin
	var upper := shoulder.distance_to(_global(skeleton, fore).origin)
	var lower := _global(skeleton, fore).origin.distance_to(_global(skeleton, hand).origin)
	var to_target := target - shoulder
	if to_target.length() > upper + lower:
		print("WARNING %s: %s hand target out of reach by %.3f" % [label, side, to_target.length() - upper - lower])
	var distance := clampf(to_target.length(), absf(upper - lower) + 0.001, (upper + lower) * 0.999)
	var dir := to_target.normalized()
	var cos_a := clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0)
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * cos_a * upper + bend * sqrt(1.0 - cos_a * cos_a) * upper
	_point_bone(skeleton, arm, fore, elbow - shoulder)
	_point_bone(skeleton, fore, hand, shoulder + dir * distance - elbow)


## Folds side's fingers toward the palm side, which faces `palm_dir`.
static func _curl_fingers(skeleton: Skeleton3D, side: String, palm_dir: Vector3) -> void:
	for finger: String in FINGERS + ["Thumb"]:
		var curls: Array = THUMB_CURL if finger == "Thumb" else CURL
		for segment in 3:
			var bone := skeleton.find_bone("%s%sHand%s%d" % [P, side, finger, segment + 1])
			var child := skeleton.find_bone("%s%sHand%s%d" % [P, side, finger, segment + 2])
			if bone < 0 or child < 0:
				continue
			var along := _global(skeleton, child).origin - _global(skeleton, bone).origin
			var axis := along.cross(palm_dir)
			if axis.length() < 0.0001:
				continue
			_rotate_global(skeleton, bone, Basis(axis.normalized(), deg_to_rad(curls[segment])))


## Right, up and forward of the posed body (skeleton space).
static func _body_frame(skeleton: Skeleton3D) -> Basis:
	# Forward from the toes (both feet averaged, since each is splayed out).
	var toe := Vector3.ZERO
	for side: String in ["Left", "Right"]:
		var toe_end := _global(skeleton, _bone(skeleton, side + "Toe_End")).origin
		var foot := _global(skeleton, _bone(skeleton, side + "Foot")).origin
		toe += (toe_end - foot).normalized()
	var forward := Vector3(toe.x, 0.0, toe.z).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, forward)


static func _in_frame(frame: Basis, v: Vector3, reach: float) -> Vector3:
	return Vector3(v.dot(frame.x), v.dot(frame.y), v.dot(frame.z)) / reach


static func _reach(skeleton: Skeleton3D, side: String) -> float:
	var arm := _global(skeleton, _bone(skeleton, side + "Arm")).origin
	var fore := _global(skeleton, _bone(skeleton, side + "ForeArm")).origin
	var hand := _global(skeleton, _bone(skeleton, side + "Hand")).origin
	return arm.distance_to(fore) + fore.distance_to(hand)


static func _hand_length(skeleton: Skeleton3D, side: String) -> float:
	return _global(skeleton, _bone(skeleton, side + "Hand")).origin.distance_to(
			_global(skeleton, _bone(skeleton, side + "HandMiddle1")).origin)


static func _report_wrist(skeleton: Skeleton3D, side: String, label: String) -> void:
	var fore := _global(skeleton, _bone(skeleton, side + "ForeArm")).origin
	var hand := _global(skeleton, _bone(skeleton, side + "Hand")).origin
	var middle := _global(skeleton, _bone(skeleton, side + "HandMiddle1")).origin
	print("%s: %s wrist bend %.0f deg" % [label, side, rad_to_deg((hand - fore).angle_to(middle - hand))])


static func _bone(skeleton: Skeleton3D, bone_name: String) -> int:
	var bone := skeleton.find_bone(P + bone_name)
	assert(bone >= 0, "Rig has no bone " + bone_name)
	return bone


static func _pose_clip(skeleton: Skeleton3D, anim: Animation, time: float) -> void:
	skeleton.reset_bone_poses()
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := skeleton.find_bone(String(anim.track_get_path(track).get_concatenated_subnames()))
		if bone >= 0:
			skeleton.set_bone_pose_rotation(bone, anim.rotation_track_interpolate(track, time))


## Applies `turn` (skeleton space) to bone's global orientation; its children follow.
static func _rotate_global(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := _global(skeleton, parent).basis if parent >= 0 else Basis()
	var new_global := turn * _global(skeleton, bone).basis
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * new_global).get_rotation_quaternion())


## Turns bone so the line from it to child lies along direction (skeleton space).
static func _point_bone(skeleton: Skeleton3D, bone: int, child: int, direction: Vector3) -> void:
	var current := (_global(skeleton, child).origin - _global(skeleton, bone).origin).normalized()
	_rotate_global(skeleton, bone, Basis(Quaternion(current, direction.normalized())))


## A bone's pose in skeleton space, from the local poses (the skeleton's own
## cache isn't refreshed while it's posed by hand here).
static func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	return _global(skeleton, parent) * pose if parent >= 0 else pose
