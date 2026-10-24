# Adds the save-orb touch clip ("TouchOrb") to the player's animation library:
#   godot --headless --path . -s res://scripts/tools/build_orb_touch_clip.gd
#
# Placeholder until a real "touch"/"button push" animation is imported: the
# Idle clip with the free (left) arm swung out forward, slightly raised, palm
# leading. Reach over REACH_TIME, hold until HOLD_END, lower by LENGTH; the
# three lengths are stored on the clip ("phase_times") for the OrbTouch state,
# which saves the game as the reach ends. Rerun after changing the numbers below.
extends SceneTree

const LIBRARY := "res://resources/player/player_animations_real.tres"
const MODEL := "res://scenes/player_model.tscn"
const CLIP := &"TouchOrb"
const SOURCE_CLIP := &"Idle"
const FPS := 30.0

## Arm fully out (s).
const REACH_TIME := 0.4
## Arm starts coming back down (s).
const HOLD_END := 1.0
## Clip length: arm back at the side (s).
const LENGTH := 1.5
## Upper arm direction: degrees above horizontal, and towards the body's
## centre line (so the hand ends up in front of the chest, not off to the side).
const RAISE_DEGREES := 12.0
const INWARD_DEGREES := 18.0
## Slight elbow bend (degrees), so the arm doesn't look locked.
const ELBOW_BEND_DEGREES := 12.0

const ARM := "mixamorig_LeftArm"
const FOREARM := "mixamorig_LeftForeArm"
const HAND := "mixamorig_LeftHand"


func _initialize() -> void:
	var library: AnimationLibrary = load(LIBRARY)
	var idle := library.get_animation(SOURCE_CLIP)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	root.add_child(model)
	(model.get_node(^"AnimationTree") as AnimationTree).active = false
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D")[0]

	# Bone track -> bone index, for the rotation tracks of the source clip.
	var bone_tracks := {}
	for track in idle.get_track_count():
		if idle.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			var bone := skeleton.find_bone(String(idle.track_get_path(track).get_concatenated_subnames()))
			if bone >= 0:
				bone_tracks[track] = bone

	_pose(skeleton, idle, bone_tracks, 0.0)
	var reach := _reach_rotations(skeleton)

	var out := Animation.new()
	out.step = 1.0 / FPS
	out.length = LENGTH
	var copies := {}
	for track: int in bone_tracks:
		var copy := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(copy, idle.track_get_path(track))
		copies[track] = copy
	for track in idle.get_track_count():
		if idle.track_get_type(track) == Animation.TYPE_POSITION_3D:
			var copy := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(copy, idle.track_get_path(track))
			copies[track] = copy

	var frames := ceili(LENGTH * FPS)
	for i in frames + 1:
		var time := minf(i / FPS, LENGTH)
		var weight := _reach_weight(time)
		for track: int in copies:
			if idle.track_get_type(track) == Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(copies[track], time, idle.position_track_interpolate(track, time))
				continue
			var rotation := idle.rotation_track_interpolate(track, time)
			var bone: int = bone_tracks[track]
			if reach.has(bone):
				rotation = rotation.slerp(reach[bone], weight)
			out.rotation_track_insert_key(copies[track], time, rotation)
	out.set_meta(&"phase_times", Vector3(REACH_TIME, HOLD_END - REACH_TIME, LENGTH - HOLD_END))

	if library.has_animation(CLIP):
		library.remove_animation(CLIP)
	library.add_animation(CLIP, out)
	var err := ResourceSaver.save(library, LIBRARY)

	# Report where the hand ends up (model space, before the player's x1.8 scale).
	_pose(skeleton, out, copies_to_bones(out, skeleton), REACH_TIME)
	var hand := _global(skeleton, skeleton.find_bone(HAND)).origin
	var sh := _global(skeleton, skeleton.find_bone(ARM)).origin
	var el := _global(skeleton, skeleton.find_bone(FOREARM)).origin
	print("saved %s (error %d); model space: shoulder %s elbow %s hand %s" % [LIBRARY, err, sh, el, hand])
	quit()


static func copies_to_bones(anim: Animation, skeleton: Skeleton3D) -> Dictionary:
	var map := {}
	for track in anim.get_track_count():
		if anim.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			map[track] = skeleton.find_bone(String(anim.track_get_path(track).get_concatenated_subnames()))
	return map


static func _pose(skeleton: Skeleton3D, anim: Animation, bone_tracks: Dictionary, time: float) -> void:
	skeleton.reset_bone_poses()
	for track: int in bone_tracks:
		skeleton.set_bone_pose_rotation(bone_tracks[track], anim.rotation_track_interpolate(track, time))


## Local rotations for the arm, forearm and hand that point the arm forward.
static func _reach_rotations(skeleton: Skeleton3D) -> Dictionary:
	var arm := skeleton.find_bone(ARM)
	var forearm := skeleton.find_bone(FOREARM)
	var hand := skeleton.find_bone(HAND)
	# Model forward, from the feet: the toes point the way the body faces (both
	# feet averaged, since each is splayed outwards).
	var toe := Vector3.ZERO
	for side_name: String in ["Left", "Right"]:
		var toe_end := _global(skeleton, skeleton.find_bone("mixamorig_%sToe_End" % side_name)).origin
		var foot := _global(skeleton, skeleton.find_bone("mixamorig_%sFoot" % side_name)).origin
		toe += (toe_end - foot).normalized()
	var forward := Vector3(toe.x, 0.0, toe.z).normalized()
	var up := Vector3.UP
	# The left arm's side of the body, to aim it a little across the chest.
	var shoulder := _global(skeleton, arm).origin
	var side := Vector3(shoulder.x, 0.0, shoulder.z)
	side = (side - forward * side.dot(forward)).normalized()
	var aim := forward.rotated(up.cross(forward).normalized(), -deg_to_rad(RAISE_DEGREES))
	aim = (aim - side * tan(deg_to_rad(INWARD_DEGREES))).normalized()

	var result := {}
	_point_bone(skeleton, arm, forearm, aim, result)
	# Elbow: bend the forearm a little upward from the upper arm's line.
	var bent := aim.rotated(aim.cross(up).normalized(), deg_to_rad(ELBOW_BEND_DEGREES))
	_point_bone(skeleton, forearm, hand, bent, result)
	_point_bone(skeleton, hand, skeleton.find_bone("mixamorig_LeftHandMiddle1"), bent, result)
	return result


## Turns bone so the line from it to child lies along direction (skeleton
## space); stores and applies the new local rotation. Uses the real child
## offset rather than an assumed bone axis, so it works for any rig.
static func _point_bone(skeleton: Skeleton3D, bone: int, child: int, direction: Vector3, result: Dictionary) -> void:
	var global := _global(skeleton, bone)
	var current := (_global(skeleton, child).origin - global.origin).normalized()
	var turn := Quaternion(current, direction.normalized())
	var new_global := Basis(turn) * global.basis
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := _global(skeleton, parent).basis if parent >= 0 else Basis()
	var local := (parent_basis.inverse() * new_global).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, local)
	result[bone] = local


## 0 at the side, 1 fully reached: ease out, hold, ease back down.
static func _reach_weight(time: float) -> float:
	if time <= REACH_TIME:
		var u := time / REACH_TIME
		return u * u * (3.0 - 2.0 * u)
	if time <= HOLD_END:
		return 1.0
	var v := clampf((time - HOLD_END) / (LENGTH - HOLD_END), 0.0, 1.0)
	return 1.0 - v * v * (3.0 - 2.0 * v)


## A bone's pose in skeleton space, from the local poses (the skeleton's own
## cache isn't refreshed while it's posed by hand here).
static func _global(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	return _global(skeleton, parent) * pose if parent >= 0 else pose
