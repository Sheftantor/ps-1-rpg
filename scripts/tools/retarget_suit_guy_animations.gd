# Builds Suit Guy's AnimationLibrary by retargeting four of the player's clips
# (authored on the Mixamo rig in Idle.fbx) onto the suit model's skeleton.
# Re-run after replacing the suit model or the player clips:
#   godot --headless --path . -s res://scripts/tools/retarget_suit_guy_animations.gd
#
# Both rigs use mixamorig_ bone names but different rest poses (the suit rests
# in an A-pose), so each bone's rest is first turned to point the way the
# source rig's bone points, then the source's world-space rotation from rest is
# applied on top. Hips translation is scaled by the ratio of the hip heights.
# Also prints the GunMount transform for res://scenes/suit_guy_model.tscn: the
# gun grip in the right palm, level and pointing forward in the Aim pose, and
# scaled back to world size under the model's scale (MODEL_SCALE).
extends SceneTree

const SOURCE_RIG := "res://Import/Character/Idle.fbx"
const SOURCE_LIBRARY := "res://resources/player/player_animations.tres"
const TARGET_RIG := "res://Import/Character/Suit_Enemy1/tripo_convert_771ff019-bd4c-461b-804f-ef0993e8daf0.fbx"
const OUTPUT_PATH := "res://resources/enemies/suit_guy_animations.tres"
## Source clip -> clip name in the output library.
const CLIPS := {&"Idle": &"Idle", &"Walking": &"Walk", &"AimPistol": &"Aim", &"AimFire": &"Fire"}
const P := "mixamorig_"
## Scale of the model under Suit Guy's Facing node. Keep in sync with
## res://scenes/suit_guy.tscn (Facing/Model).
const MODEL_SCALE := 2.05
## Fraction of the way from the hand bone to the middle knuckle where the grip sits.
const PALM_FRACTION := 0.5
const FPS := 30.0

var _src: Skeleton3D
var _dst: Skeleton3D
var _src_rest: Array[Quaternion] = []
## Per target bone: its rest rotation turned to point like the source bone.
var _aligned_rest: Array[Quaternion] = []
var _to_src := PackedInt32Array()


func _initialize() -> void:
	_src = (load(SOURCE_RIG) as PackedScene).instantiate().get_node("Skeleton3D")
	_dst = (load(TARGET_RIG) as PackedScene).instantiate().get_node("Skeleton3D")
	for bone in _src.get_bone_count():
		_src_rest.append(_src.get_bone_global_rest(bone).basis.get_rotation_quaternion())
	for bone in _dst.get_bone_count():
		assert(_dst.get_bone_parent(bone) < bone)
		_to_src.append(_src.find_bone(_dst.get_bone_name(bone)))
	for bone in _dst.get_bone_count():
		_aligned_rest.append(_align(bone))

	var source: AnimationLibrary = load(SOURCE_LIBRARY)
	var library := AnimationLibrary.new()
	for clip_name: StringName in CLIPS:
		library.add_animation(CLIPS[clip_name], _retarget(source.get_animation(clip_name)))
		print("retargeted %s -> %s" % [clip_name, CLIPS[clip_name]])
	var err := ResourceSaver.save(library, OUTPUT_PATH)
	print("saved %s (error %d)" % [OUTPUT_PATH, err])
	_print_gun_mount(library.get_animation(&"Aim"))
	quit()


## The target bone's global rest, rotated so the bone points where the source's does.
func _align(bone: int) -> Quaternion:
	var rest := _dst.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var src_bone := _to_src[bone]
	var child := _direction_child(bone)
	if src_bone < 0 or child < 0 or _to_src[child] < 0:
		var parent := _dst.get_bone_parent(bone)
		if parent < 0:
			return rest
		# No direction to match: turn with the parent.
		var parent_rest := _dst.get_bone_global_rest(parent).basis.get_rotation_quaternion()
		return (_aligned_rest[parent] * parent_rest.inverse() * rest).normalized()
	var dst_dir := _dst.get_bone_global_rest(child).origin - _dst.get_bone_global_rest(bone).origin
	var src_dir := _src.get_bone_global_rest(_to_src[child]).origin - _src.get_bone_global_rest(src_bone).origin
	return (Quaternion(dst_dir.normalized(), src_dir.normalized()) * rest).normalized()


## The child that gives a bone its direction (the hand points at the middle finger).
func _direction_child(bone: int) -> int:
	var children := _dst.get_bone_children(bone)
	if children.is_empty():
		return -1
	for preferred in ["HandMiddle1", "Spine", "Neck", "Head"]:
		for child in children:
			if _dst.get_bone_name(child).trim_prefix(P).begins_with(preferred):
				return child
	return children[0]


func _retarget(clip: Animation) -> Animation:
	var rotation_tracks := {}
	var position_tracks := {}
	var times := {}
	for track in clip.get_track_count():
		var bone := _src.find_bone(String(clip.track_get_path(track).get_concatenated_subnames()))
		if bone < 0:
			continue
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[bone] = track
		elif clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
			position_tracks[bone] = track
		for key in clip.track_get_key_count(track):
			times[snappedf(clip.track_get_key_time(track, key), 0.0001)] = true
	for i in int(floor(clip.length * FPS)) + 1:
		times[snappedf(i / FPS, 0.0001)] = true
	times[snappedf(clip.length, 0.0001)] = true
	var samples: Array = times.keys().filter(func(t: float) -> bool: return t <= clip.length + 0.00001)
	samples.sort()

	var out := Animation.new()
	out.length = clip.length
	out.loop_mode = clip.loop_mode
	var rotation_out := PackedInt32Array()
	for bone in _dst.get_bone_count():
		var track := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(track, NodePath("Skeleton3D:" + _dst.get_bone_name(bone)))
		rotation_out.append(track)
	var hips := _dst.find_bone(P + "Hips")
	var src_hips := _src.find_bone(P + "Hips")
	var hips_track := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(hips_track, NodePath("Skeleton3D:" + P + "Hips"))
	var hips_ratio := _dst.get_bone_rest(hips).origin.y / _src.get_bone_rest(src_hips).origin.y

	var previous := {}
	for time: float in samples:
		var pose := _target_pose(clip, rotation_tracks, time)
		for bone in _dst.get_bone_count():
			var parent := _dst.get_bone_parent(bone)
			var local: Quaternion = (pose[parent].inverse() * pose[bone] if parent >= 0 else pose[bone]).normalized()
			if previous.has(bone) and (previous[bone] as Quaternion).dot(local) < 0.0:
				local = -local
			previous[bone] = local
			out.rotation_track_insert_key(rotation_out[bone], time, local)
		var offset := Vector3.ZERO
		if position_tracks.has(src_hips):
			offset = (clip.position_track_interpolate(position_tracks[src_hips], time) - _src.get_bone_rest(src_hips).origin) * hips_ratio
		out.position_track_insert_key(hips_track, time, _dst.get_bone_rest(hips).origin + offset)
	return out


## Global rotation of every target bone at time.
func _target_pose(clip: Animation, rotation_tracks: Dictionary, time: float) -> Array[Quaternion]:
	var src_global: Array[Quaternion] = []
	src_global.resize(_src.get_bone_count())
	for bone in _src.get_bone_count():
		var local: Quaternion = clip.rotation_track_interpolate(rotation_tracks[bone], time) \
				if rotation_tracks.has(bone) else _src.get_bone_rest(bone).basis.get_rotation_quaternion()
		var parent := _src.get_bone_parent(bone)
		src_global[bone] = (src_global[parent] * local if parent >= 0 else local).normalized()
	var pose: Array[Quaternion] = []
	pose.resize(_dst.get_bone_count())
	for bone in _dst.get_bone_count():
		var src_bone := _to_src[bone]
		if src_bone >= 0:
			pose[bone] = (src_global[src_bone] * _src_rest[src_bone].inverse() * _aligned_rest[bone]).normalized()
		else:
			var parent := _dst.get_bone_parent(bone)
			var rest_local := _dst.get_bone_rest(bone).basis.get_rotation_quaternion()
			pose[bone] = (pose[parent] * rest_local if parent >= 0 else rest_local).normalized()
	return pose


func _print_gun_mount(aim: Animation) -> void:
	# Forward kinematics on the last key of the (static) Aim pose.
	var global: Array[Transform3D] = []
	global.resize(_dst.get_bone_count())
	for bone in _dst.get_bone_count():
		var track := aim.find_track(NodePath("Skeleton3D:" + _dst.get_bone_name(bone)), Animation.TYPE_ROTATION_3D)
		var origin := _dst.get_bone_rest(bone).origin
		var position_track := aim.find_track(NodePath("Skeleton3D:" + _dst.get_bone_name(bone)), Animation.TYPE_POSITION_3D)
		if position_track >= 0:
			origin = aim.position_track_interpolate(position_track, aim.length)
		var local := Transform3D(Basis(aim.rotation_track_interpolate(track, aim.length)), origin)
		var parent := _dst.get_bone_parent(bone)
		global[bone] = global[parent] * local if parent >= 0 else local
	var hand := global[_dst.find_bone(P + "RightHand")]
	var knuckle := global[_dst.find_bone(P + "RightHandMiddle1")].origin
	var palm := hand.origin.lerp(knuckle, PALM_FRACTION)
	# The model faces +Z; the gun's muzzle is -Z of its parent, so turn the mount half way round.
	var wanted := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE / MODEL_SCALE), palm)
	print("GunMount transform = ", var_to_str(hand.affine_inverse() * wanted))
	print("right hand bone index = ", _dst.find_bone(P + "RightHand"))
	print("Aim pose: right hand at ", hand.origin, ", forearm dir ", (hand.origin - global[_dst.find_bone(P + "RightForeArm")].origin).normalized())
