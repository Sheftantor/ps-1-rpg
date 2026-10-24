# Adds the loot sack bend clip ("LootBend") to the player's animation library:
#   godot --headless --path . -s res://scripts/tools/build_loot_bend_clip.gd
#
# Placeholder until a real "pick up" animation is imported: the Idle clip
# bent into a squat over the sack. The hips drop and tip forward, the spine
# leans over, the legs bend (two-bone IK keeps the feet where they stood), the
# right hand reaches down in front of the feet and the left rests on its knee.
# Down over DOWN_TIME, hold until HOLD_END, back up by LENGTH; the three
# lengths are stored on the clip ("phase_times") for the LootBend state, which
# opens the loot window at the bottom. Rerun after changing the numbers below.
extends SceneTree

const LIBRARY := "res://resources/player/player_animations_real.tres"
const MODEL := "res://scenes/player_model.tscn"
const CLIP := &"LootBend"
const SOURCE_CLIP := &"Idle"
const FPS := 30.0

## Fully down (s).
const DOWN_TIME := 0.3
## Starts straightening up (s).
const HOLD_END := 0.55
## Clip length: standing again (s).
const LENGTH := 0.9
## Hip drop as a share of leg length (thigh + shin).
const DROP := 0.3
## Forward tip of the hips, and of each of the three spine bones (degrees).
const HIP_PITCH := 20.0
const SPINE_PITCH := 12.0
## Head tipped back up a little, toward the sack rather than the floor.
const HEAD_LIFT := 15.0
## Where the right hand reaches: in front of the toes by this share of leg length.
const REACH_AHEAD := 0.35
## Slight elbow bend on the reaching arm (degrees).
const ELBOW_BEND_DEGREES := 10.0

const P := "mixamorig_"


func _initialize() -> void:
	var library: AnimationLibrary = load(LIBRARY)
	var idle := library.get_animation(SOURCE_CLIP)
	var model: Node3D = (load(MODEL) as PackedScene).instantiate()
	root.add_child(model)
	(model.get_node(^"AnimationTree") as AnimationTree).active = false
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D")[0]

	var bone_tracks := _tracks_to_bones(idle, skeleton)
	_pose(skeleton, idle, bone_tracks, 0.0)
	var hips := skeleton.find_bone(P + "Hips")
	var rest_hips := skeleton.get_bone_pose_position(hips)
	var bend := _bend_rotations(skeleton)
	var hips_offset := skeleton.get_bone_pose_position(hips) - rest_hips

	var out := Animation.new()
	out.step = 1.0 / FPS
	out.length = LENGTH
	var copies := {}
	var hips_track := -1
	for track in idle.get_track_count():
		var type := idle.track_get_type(track)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var copy := out.add_track(type)
		out.track_set_path(copy, idle.track_get_path(track))
		copies[track] = copy
		if type == Animation.TYPE_POSITION_3D and bone_tracks.get(track, -1) == hips:
			hips_track = track

	var frames := ceili(LENGTH * FPS)
	for i in frames + 1:
		var time := minf(i / FPS, LENGTH)
		var weight := _bend_weight(time)
		for track: int in copies:
			if idle.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var position := idle.position_track_interpolate(track, time)
				if track == hips_track:
					position += hips_offset * weight
				out.position_track_insert_key(copies[track], time, position)
				continue
			var rotation := idle.rotation_track_interpolate(track, time)
			var bone: int = bone_tracks.get(track, -1)
			if bend.has(bone):
				rotation = rotation.slerp(bend[bone], weight)
			out.rotation_track_insert_key(copies[track], time, rotation)
	out.set_meta(&"phase_times", Vector3(DOWN_TIME, HOLD_END - DOWN_TIME, LENGTH - HOLD_END))

	if library.has_animation(CLIP):
		library.remove_animation(CLIP)
	library.add_animation(CLIP, out)
	var err := ResourceSaver.save(library, LIBRARY)

	# Report the bottom of the bend (model space, before the player's x1.8 scale).
	_pose(skeleton, out, _tracks_to_bones(out, skeleton), DOWN_TIME)
	for name: String in ["Hips", "LeftFoot", "RightFoot", "RightHand", "Head"]:
		print("  %s %s" % [name, _global(skeleton, skeleton.find_bone(P + name)).origin])
	print("saved %s (error %d)" % [LIBRARY, err])
	quit()


## Rotation track -> bone and position track -> bone, by the track's bone name.
static func _tracks_to_bones(anim: Animation, skeleton: Skeleton3D) -> Dictionary:
	var map := {}
	for track in anim.get_track_count():
		var bone := skeleton.find_bone(String(anim.track_get_path(track).get_concatenated_subnames()))
		if bone >= 0:
			map[track] = bone
	return map


static func _pose(skeleton: Skeleton3D, anim: Animation, bone_tracks: Dictionary, time: float) -> void:
	skeleton.reset_bone_poses()
	for track: int in bone_tracks:
		match anim.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				skeleton.set_bone_pose_rotation(bone_tracks[track], anim.rotation_track_interpolate(track, time))
			Animation.TYPE_POSITION_3D:
				skeleton.set_bone_pose_position(bone_tracks[track], anim.position_track_interpolate(track, time))


## Poses the squat on the skeleton (from the idle pose already on it) and
## returns the new local rotations by bone. Moves the hips' pose position too.
static func _bend_rotations(skeleton: Skeleton3D) -> Dictionary:
	var result := {}
	var up := Vector3.UP
	var forward := _forward(skeleton)
	var pitch_axis := up.cross(forward).normalized()
	var hips := skeleton.find_bone(P + "Hips")

	# Where the feet stand now, which the legs keep them at.
	var feet := {}
	var legs := {}
	for side: String in ["Left", "Right"]:
		var up_leg := skeleton.find_bone(P + side + "UpLeg")
		var leg := skeleton.find_bone(P + side + "Leg")
		var foot := skeleton.find_bone(P + side + "Foot")
		feet[side] = _global(skeleton, foot)
		legs[side] = Vector2(_global(skeleton, up_leg).origin.distance_to(_global(skeleton, leg).origin),
				_global(skeleton, leg).origin.distance_to(feet[side].origin))
	var leg_length: float = legs["Left"].x + legs["Left"].y

	# Hips down and tipped forward.
	var hips_global := _global(skeleton, hips)
	var dropped := hips_global.origin + Vector3.DOWN * leg_length * DROP
	var parent := skeleton.get_bone_parent(hips)
	var parent_global := _global(skeleton, parent) if parent >= 0 else Transform3D()
	skeleton.set_bone_pose_position(hips, parent_global.affine_inverse() * dropped)
	_turn(skeleton, hips, Quaternion(pitch_axis, deg_to_rad(HIP_PITCH)), result)
	for spine: String in ["Spine", "Spine1", "Spine2"]:
		_turn(skeleton, skeleton.find_bone(P + spine), Quaternion(pitch_axis, deg_to_rad(SPINE_PITCH)), result)
	_turn(skeleton, skeleton.find_bone(P + "Head"), Quaternion(pitch_axis, -deg_to_rad(HEAD_LIFT)), result)

	# Legs: knees forward, feet back where they were (same turn as before too).
	var knees := {}
	for side: String in ["Left", "Right"]:
		var up_leg := skeleton.find_bone(P + side + "UpLeg")
		var leg := skeleton.find_bone(P + side + "Leg")
		var foot := skeleton.find_bone(P + side + "Foot")
		var hip: Vector3 = _global(skeleton, up_leg).origin
		var target: Vector3 = feet[side].origin
		var lengths: Vector2 = legs[side]
		var knee := _knee(hip, target, lengths.x, lengths.y, forward)
		knees[side] = knee
		_point_bone(skeleton, up_leg, leg, knee - hip, result)
		_point_bone(skeleton, leg, foot, target - _global(skeleton, leg).origin, result)
		_set_global_basis(skeleton, foot, feet[side].basis, result)

	# Right hand down to the ground in front of the feet; left hand on its knee.
	var left_foot: Transform3D = feet["Left"]
	var right_foot: Transform3D = feet["Right"]
	var toes := (left_foot.origin + right_foot.origin) * 0.5
	var reach_point: Vector3 = toes + forward * leg_length * REACH_AHEAD
	var arm := skeleton.find_bone(P + "RightArm")
	var forearm := skeleton.find_bone(P + "RightForeArm")
	var hand := skeleton.find_bone(P + "RightHand")
	var aim := (reach_point - _global(skeleton, arm).origin).normalized()
	_point_bone(skeleton, arm, forearm, aim, result)
	var bent := aim.rotated(pitch_axis, -deg_to_rad(ELBOW_BEND_DEGREES))
	_point_bone(skeleton, forearm, hand, bent, result)
	_point_bone(skeleton, hand, skeleton.find_bone(P + "RightHandMiddle1"), bent, result)

	var left_arm := skeleton.find_bone(P + "LeftArm")
	var left_forearm := skeleton.find_bone(P + "LeftForeArm")
	var left_hand := skeleton.find_bone(P + "LeftHand")
	var knee_point: Vector3 = knees["Left"] + forward * leg_length * 0.05
	var shoulder := _global(skeleton, left_arm).origin
	var elbow := _knee(shoulder, knee_point, _global(skeleton, left_arm).origin.distance_to(_global(skeleton, left_forearm).origin),
			_global(skeleton, left_forearm).origin.distance_to(_global(skeleton, left_hand).origin), -forward)
	_point_bone(skeleton, left_arm, left_forearm, elbow - shoulder, result)
	_point_bone(skeleton, left_forearm, left_hand, knee_point - _global(skeleton, left_forearm).origin, result)
	return result


## Two-bone IK: the middle joint for a chain from start reaching target, with
## segment lengths a and b, bending toward bend_toward.
static func _knee(start: Vector3, target: Vector3, a: float, b: float, bend_toward: Vector3) -> Vector3:
	var to_target := target - start
	var distance := clampf(to_target.length(), absf(a - b) + 0.001, a + b - 0.001)
	var direction := to_target.normalized()
	var side := (bend_toward - direction * bend_toward.dot(direction)).normalized()
	var angle := acos(clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0))
	return start + (direction * cos(angle) + side * sin(angle)) * a


## Model forward, from the feet: the toes point the way the body faces.
static func _forward(skeleton: Skeleton3D) -> Vector3:
	var toe := Vector3.ZERO
	for side: String in ["Left", "Right"]:
		var toe_end := _global(skeleton, skeleton.find_bone(P + side + "Toe_End")).origin
		var foot := _global(skeleton, skeleton.find_bone(P + side + "Foot")).origin
		toe += (toe_end - foot).normalized()
	return Vector3(toe.x, 0.0, toe.z).normalized()


## Turns bone by turn in skeleton space; stores and applies its new local rotation.
static func _turn(skeleton: Skeleton3D, bone: int, turn: Quaternion, result: Dictionary) -> void:
	_set_global_basis(skeleton, bone, Basis(turn) * _global(skeleton, bone).basis, result)


static func _set_global_basis(skeleton: Skeleton3D, bone: int, global_basis: Basis, result: Dictionary) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := _global(skeleton, parent).basis if parent >= 0 else Basis()
	var local := (parent_basis.inverse() * global_basis).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, local)
	result[bone] = local


## Turns bone so the line from it to child lies along direction (skeleton
## space); stores and applies the new local rotation.
static func _point_bone(skeleton: Skeleton3D, bone: int, child: int, direction: Vector3, result: Dictionary) -> void:
	var global := _global(skeleton, bone)
	var current := (_global(skeleton, child).origin - global.origin).normalized()
	_set_global_basis(skeleton, bone, Basis(Quaternion(current, direction.normalized())) * global.basis, result)


## 0 standing, 1 fully down: ease down, hold, ease back up.
static func _bend_weight(time: float) -> float:
	if time <= DOWN_TIME:
		var u := time / DOWN_TIME
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
