# Builds the NewMain_Base player's animation library from the Real_MainC one:
#   godot --headless --path . -s res://scripts/tools/retarget_player_animations.gd
#
# Both rigs are Tripo humanoids with mixamorig_ bone names but different rest
# poses, so local rotations can't be copied as-is. Each bone instead keeps the
# same rotation away from its own rest pose, in model space:
#   target_global = source_global * source_rest_global^-1 * target_rest_global
# then turned back into local rotations. Hips motion is scaled by hip height.
# Clip lengths, loop modes, steps and metas (hit_frames, phase_times,
# trail_frames) carry over unchanged, so gameplay timing is identical.
#
# A light "organic" pass is baked in on top, keeping the clips very close to
# the originals: in looping clips the head, neck, forearms and hands trail the
# body by a frame or two (follow-through), one-shot clips get a one-frame head
# lag only (weapon arcs stay exact), Idle breathes (chest and shoulders rise and
# fall, the neck counters so the head stays steady), and rotation tracks use
# cubic interpolation. Fashion styling goes on top: Idle is rebuilt as an
# upright line-up stance and Walking / Running get a runway feel (FASHION_IDLE,
# RUNWAY). Also prints the melee weapon's grip transform for the new
# right hand. Rerun after changing the source library or the numbers below.
extends SceneTree

const SOURCE_LIBRARY := "res://resources/player/player_animations_real.tres"
const SOURCE_MODEL := "res://scenes/player_model.tscn"
const TARGET_MODEL := "res://Import/Character/MC-Rig/NewMain_Base.glb"
const TARGET_LIBRARY := "res://resources/player/player_animations_newmain.tres"
const P := "mixamorig_"

## Follow-through in looping clips: bone -> lag in seconds.
const LOOP_LAG := {
	"Neck": 0.03, "Head": 0.06,
	"LeftForeArm": 0.035, "RightForeArm": 0.035,
	"LeftHand": 0.06, "RightHand": 0.06,
}
## One-shot clips (attacks, rolls, ...): only the head trails.
const ACTION_LAG := {"Head": 0.033}
## Idle breathing: breaths per clip, chest tilt and shoulder lift (degrees).
const BREATH_CLIPS := ["Idle"]
const BREATHS_PER_IDLE := 3
const BREATH_CHEST_DEGREES := 1.3
const BREATH_SHOULDER_DEGREES := 1.0
## Share of the chest tilt the neck takes back out, steadying the head.
const BREATH_NECK_COUNTER := 0.6

## Fashion styling (model space: the model faces +Z, +X is its left).
## Idle becomes a line-up stance: upright, chest open, shoulders down, arms
## hanging straight and close with a soft elbow, legs straight, feet hip-width,
## with one slow weight shift per loop. Hands and fingers keep the source pose.
const FASHION_IDLE := "Idle"
## Left arm's hang direction (the right mirrors it): down, a little out.
const ARM_HANG := Vector3(0.12, -1.0, -0.02)
const ELBOW_BEND_DEGREES := 10.0
const IDLE_CHEST_OPEN_DEGREES := 2.5
const IDLE_CHIN_UP_DEGREES := 1.5
const IDLE_SHOULDER_DROP_DEGREES := 6.0
const IDLE_WEIGHT_SHIFT_DEGREES := 1.2
## Sideways hip travel of the weight shift (model units, x1.8 in game).
const IDLE_WEIGHT_SHIFT := 0.006
## Runway walk, strength per clip: torso straightened, chest open, head level,
## arm swing pulled in toward the hang, hips rolling and turning with each step.
const RUNWAY := {"Walking": 1.0, "Running": 0.5}
const RUNWAY_UPRIGHT := 0.75
const RUNWAY_CHEST_OPEN_DEGREES := 3.0
const RUNWAY_HIP_ROLL_DEGREES := 5.0
const RUNWAY_HIP_YAW_DEGREES := 7.0
const RUNWAY_ARM_TIDY := 0.35
const RUNWAY_HEAD_LEVEL := 0.7
## Foot spread (model units) that counts as a full step for the hip sway.
const RUNWAY_STRIDE := 0.12
## Each bone's main child: its rest offset gives the bone's direction.
const CHILD := {
	"Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head", "Head": "HeadTop_End",
	"LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "LeftHandMiddle1",
	"RightArm": "RightForeArm", "RightForeArm": "RightHand", "RightHand": "RightHandMiddle1",
}
const LEG_BONES := ["UpLeg", "Leg", "Foot", "ToeBase", "Toe_End"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var source_model: Node3D = (load(SOURCE_MODEL) as PackedScene).instantiate()
	var target_model: Node3D = (load(TARGET_MODEL) as PackedScene).instantiate()
	root.add_child(source_model)
	root.add_child(target_model)
	(source_model.get_node(^"AnimationTree") as AnimationTree).active = false
	var src: Skeleton3D = source_model.get_node(^"Skeleton3D")
	var dst: Skeleton3D = target_model.get_node(^"Skeleton3D")
	var src_rest := _rest_globals(src)
	var dst_rest := _rest_globals(dst)
	var dst_order := _parent_first(dst)
	var children := {}
	for b in dst.get_bone_count():
		children[b] = []
	for b in dst.get_bone_count():
		var parent := dst.get_bone_parent(b)
		if parent >= 0:
			children[parent].append(b)
	var src_hips := src.find_bone(P + "Hips")
	var dst_hips := dst.find_bone(P + "Hips")
	var hip_scale := dst.get_bone_rest(dst_hips).origin.y / src.get_bone_rest(src_hips).origin.y

	var source_lib: AnimationLibrary = load(SOURCE_LIBRARY)
	var out_lib := AnimationLibrary.new()
	for clip_name: StringName in source_lib.get_animation_list():
		var clip := source_lib.get_animation(clip_name)
		var looping := clip.loop_mode != Animation.LOOP_NONE
		var lag: Dictionary = LOOP_LAG if looping else ACTION_LAG
		# Source bone -> its rotation track; the hips position track.
		var rot_tracks := {}
		var hips_pos_track := -1
		for t in clip.get_track_count():
			var bone := src.find_bone(String(clip.track_get_path(t).get_concatenated_subnames()))
			if bone < 0:
				continue
			if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot_tracks[bone] = t
			elif clip.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == src_hips:
				hips_pos_track = t

		var out := Animation.new()
		out.length = clip.length
		out.loop_mode = clip.loop_mode
		out.step = clip.step
		for meta: StringName in clip.get_meta_list():
			out.set_meta(meta, clip.get_meta(meta))
		# Target tracks only for bones the source clip animates.
		var out_tracks := {}
		for b: int in rot_tracks:
			var tb := dst.find_bone(src.get_bone_name(b))
			if tb < 0:
				continue
			var track := out.add_track(Animation.TYPE_ROTATION_3D)
			out.track_set_path(track, NodePath("Skeleton3D:" + dst.get_bone_name(tb)))
			out.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
			out.track_set_interpolation_loop_wrap(track, looping)
			out_tracks[tb] = track
		var out_hips := -1
		if hips_pos_track >= 0:
			out_hips = out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(out_hips, NodePath("Skeleton3D:" + dst.get_bone_name(dst_hips)))
			out.track_set_interpolation_loop_wrap(out_hips, looping)

		var frames := roundi(clip.length / clip.step)
		var breath := String(clip_name) in BREATH_CLIPS
		for i in frames + 1:
			var time := minf(i * clip.step, clip.length)
			# Source globals at this frame (lagged bones sampled a little earlier).
			var src_global := {}
			for b in _parent_first(src):
				var local := src.get_bone_rest(b).basis.get_rotation_quaternion()
				if rot_tracks.has(b):
					var delay: float = lag.get(src.get_bone_name(b).trim_prefix(P), 0.0)
					local = clip.rotation_track_interpolate(rot_tracks[b], _shift(time, delay, clip.length, looping))
				var parent := src.get_bone_parent(b)
				src_global[b] = (src_global[parent] * local) if parent >= 0 else local
			# Same offset from rest on the target rig.
			var dst_global := {}
			for tb in dst_order:
				var sb := src.find_bone(dst.get_bone_name(tb))
				var parent := dst.get_bone_parent(tb)
				if sb >= 0:
					dst_global[tb] = (src_global[sb] as Quaternion) * (src_rest[sb] as Quaternion).inverse() * (dst_rest[tb] as Quaternion)
				else:
					var rest_local := dst.get_bone_rest(tb).basis.get_rotation_quaternion()
					dst_global[tb] = (dst_global[parent] * rest_local) if parent >= 0 else rest_local
			var hips_rest_offset := Vector3.ZERO
			var style_hips := false
			if String(clip_name) == FASHION_IDLE:
				hips_rest_offset = _fashion_idle(dst, dst_global, dst_order, dst_rest, time / clip.length)
				style_hips = true
			elif RUNWAY.has(String(clip_name)) and hips_pos_track >= 0:
				var hips_now := dst.get_bone_rest(dst_hips).origin \
						+ (clip.position_track_interpolate(hips_pos_track, time) - src.get_bone_rest(src_hips).origin) * hip_scale
				_runway(dst, dst_global, dst_order, dst_rest, hips_now, RUNWAY[String(clip_name)])
			if breath:
				_breathe(dst, dst_global, children, time / clip.length)
			for tb: int in out_tracks:
				var parent := dst.get_bone_parent(tb)
				var local: Quaternion = dst_global[tb]
				if parent >= 0:
					local = (dst_global[parent] as Quaternion).inverse() * local
				out.rotation_track_insert_key(out_tracks[tb], time, local.normalized())
			if out_hips >= 0:
				var offset := clip.position_track_interpolate(hips_pos_track, time) - src.get_bone_rest(src_hips).origin
				if style_hips:
					# Styled idle stands at full rest height (legs straight), no source bob.
					out.position_track_insert_key(out_hips, time, dst.get_bone_rest(dst_hips).origin + hips_rest_offset)
				else:
					out.position_track_insert_key(out_hips, time, dst.get_bone_rest(dst_hips).origin + offset * hip_scale)
		out_lib.add_animation(clip_name, out)
		print("  %s: %d tracks, %d frames%s" % [clip_name, out.get_track_count(), frames + 1, " (breathing)" if breath else ""])

	var err := ResourceSaver.save(out_lib, TARGET_LIBRARY)
	print("saved %s (error %d)" % [TARGET_LIBRARY, err])
	_print_grip(source_model, src, dst, src_rest, dst_rest)
	quit()


## Line-up idle at phase u (0-1 over the clip): rebuilds the body from the rest
## T-pose (upright spine and straight legs) with the arms dropped to hang at the
## sides; hands and fingers keep the source pose. Returns the hips' offset from
## rest for the slow weight shift.
func _fashion_idle(dst: Skeleton3D, glob: Dictionary, order: PackedInt32Array, rest: Dictionary, u: float) -> Vector3:
	var shift := sin(TAU * u)
	var roll := deg_to_rad(IDLE_WEIGHT_SHIFT_DEGREES) * shift
	var ov := {}
	var hips := dst.find_bone(P + "Hips")
	ov[hips] = Quaternion(Vector3.BACK, roll) * (rest[hips] as Quaternion)
	for side: String in ["Left", "Right"]:
		for leg: String in LEG_BONES:
			var bone := dst.find_bone(P + side + leg)
			ov[bone] = rest[bone]
	for name: String in ["Spine", "Spine1", "Neck"]:
		var bone := dst.find_bone(P + name)
		ov[bone] = rest[bone]
	# Chest a touch open (top back), countering the hips' roll.
	var spine2 := dst.find_bone(P + "Spine2")
	ov[spine2] = Quaternion(Vector3.RIGHT, -deg_to_rad(IDLE_CHEST_OPEN_DEGREES)) \
			* Quaternion(Vector3.BACK, -roll * 0.6) * (rest[spine2] as Quaternion)
	var head := dst.find_bone(P + "Head")
	ov[head] = Quaternion(Vector3.RIGHT, -deg_to_rad(IDLE_CHIN_UP_DEGREES)) * (rest[head] as Quaternion)
	for side: String in ["Left", "Right"]:
		var sign := 1.0 if side == "Left" else -1.0
		var shoulder := dst.find_bone(P + side + "Shoulder")
		ov[shoulder] = Quaternion(Vector3.BACK, -sign * deg_to_rad(IDLE_SHOULDER_DROP_DEGREES)) * (rest[shoulder] as Quaternion)
		var hang := _hang_rotations(dst, rest, side)
		ov[dst.find_bone(P + side + "Arm")] = hang[0]
		ov[dst.find_bone(P + side + "ForeArm")] = hang[1]
		ov[dst.find_bone(P + side + "Hand")] = hang[2]
	_rebuild(dst, glob, order, ov)
	return Vector3(IDLE_WEIGHT_SHIFT * shift, 0.0, 0.0)


## Runway styling of a locomotion frame at strength k: straightens the torso,
## opens the chest, levels the head, pulls the arm swing in toward the hang,
## and rolls / turns the pelvis with the step (the legs keep their motion).
func _runway(dst: Skeleton3D, glob: Dictionary, order: PackedInt32Array, rest: Dictionary, hips_pos: Vector3, k: float) -> void:
	var pos := _positions(dst, glob, order, hips_pos)
	var hips := dst.find_bone(P + "Hips")
	var chain: Vector3 = (pos[dst.find_bone(P + "Neck")] as Vector3) - (pos[hips] as Vector3)
	var upright := Quaternion.IDENTITY.slerp(Quaternion(chain.normalized(), Vector3.UP), RUNWAY_UPRIGHT * k)
	var spread: float = (pos[dst.find_bone(P + "LeftFoot")] as Vector3).z - (pos[dst.find_bone(P + "RightFoot")] as Vector3).z
	var step := clampf(spread / RUNWAY_STRIDE, -1.0, 1.0)
	var roll := -deg_to_rad(RUNWAY_HIP_ROLL_DEGREES) * k * step
	var yaw := deg_to_rad(RUNWAY_HIP_YAW_DEGREES) * k * step
	var ov := {}
	ov[hips] = Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.BACK, roll) * (glob[hips] as Quaternion)
	for side: String in ["Left", "Right"]:
		var up_leg := dst.find_bone(P + side + "UpLeg")
		ov[up_leg] = glob[up_leg]
	var spine := dst.find_bone(P + "Spine")
	ov[spine] = upright * (glob[spine] as Quaternion)
	var chest_open := Quaternion(Vector3.RIGHT, -deg_to_rad(RUNWAY_CHEST_OPEN_DEGREES) * k)
	var spine2 := dst.find_bone(P + "Spine2")
	ov[spine2] = func(new: Dictionary, local: Dictionary) -> Quaternion:
		return chest_open * (new[dst.get_bone_parent(spine2)] as Quaternion) * (local[spine2] as Quaternion)
	var head := dst.find_bone(P + "Head")
	var head_dir := _dir_local(dst, "Head")
	ov[head] = func(new: Dictionary, local: Dictionary) -> Quaternion:
		var q: Quaternion = (new[dst.get_bone_parent(head)] as Quaternion) * (local[head] as Quaternion)
		return Quaternion.IDENTITY.slerp(Quaternion((q * head_dir).normalized(), Vector3.UP), RUNWAY_HEAD_LEVEL * k) * q
	for side: String in ["Left", "Right"]:
		var arm := dst.find_bone(P + side + "Arm")
		var hang: Quaternion = _hang_rotations(dst, rest, side)[0]
		ov[arm] = func(new: Dictionary, local: Dictionary) -> Quaternion:
			var q: Quaternion = (new[dst.get_bone_parent(arm)] as Quaternion) * (local[arm] as Quaternion)
			return q.slerp(hang, RUNWAY_ARM_TIDY * k)
	_rebuild(dst, glob, order, ov)


## Arm, forearm and hand rotations (model space) for an arm hanging at the side
## with a soft elbow, turned down from the rest T-pose.
func _hang_rotations(dst: Skeleton3D, rest: Dictionary, side: String) -> Array:
	var sign := 1.0 if side == "Left" else -1.0
	var arm := dst.find_bone(P + side + "Arm")
	var fore := dst.find_bone(P + side + "ForeArm")
	var hand := dst.find_bone(P + side + "Hand")
	var aim := Vector3(ARM_HANG.x * sign, ARM_HANG.y, ARM_HANG.z).normalized()
	var aim_fore := aim.rotated(aim.cross(Vector3.BACK).normalized(), deg_to_rad(ELBOW_BEND_DEGREES))
	var drop := Quaternion(((rest[arm] as Quaternion) * _dir_local(dst, side + "Arm")).normalized(), aim)
	var q_arm := drop * (rest[arm] as Quaternion)
	var fore0 := drop * (rest[fore] as Quaternion)
	var bend := Quaternion((fore0 * _dir_local(dst, side + "ForeArm")).normalized(), aim_fore)
	var q_fore := bend * fore0
	var hand0 := bend * drop * (rest[hand] as Quaternion)
	var q_hand := Quaternion((hand0 * _dir_local(dst, side + "Hand")).normalized(), aim_fore) * hand0
	return [q_arm, q_fore, q_hand]


## Recomputes model-space rotations parent-first: bones in `ov` take their
## value (a Quaternion, or a Callable(new, local) for one that depends on its
## new parent); the rest keep their local rotation, so they follow their parent.
func _rebuild(dst: Skeleton3D, glob: Dictionary, order: PackedInt32Array, ov: Dictionary) -> void:
	var local := {}
	for bone in order:
		var parent := dst.get_bone_parent(bone)
		local[bone] = ((glob[parent] as Quaternion).inverse() * (glob[bone] as Quaternion)) if parent >= 0 else glob[bone]
	var new := {}
	for bone in order:
		var parent := dst.get_bone_parent(bone)
		if ov.has(bone):
			new[bone] = (ov[bone] as Callable).call(new, local) if ov[bone] is Callable else ov[bone]
		else:
			new[bone] = ((new[parent] as Quaternion) * (local[bone] as Quaternion)) if parent >= 0 else local[bone]
	for bone in order:
		glob[bone] = new[bone]


## Model-space bone positions from rotations, rest offsets and the hips position.
func _positions(dst: Skeleton3D, glob: Dictionary, order: PackedInt32Array, hips_pos: Vector3) -> Dictionary:
	var pos := {}
	for bone in order:
		var parent := dst.get_bone_parent(bone)
		pos[bone] = ((pos[parent] as Vector3) + (glob[parent] as Quaternion) * dst.get_bone_rest(bone).origin) if parent >= 0 else hips_pos
	return pos


## A bone's direction toward its main child, in its own space.
func _dir_local(dst: Skeleton3D, bone_name: String) -> Vector3:
	return dst.get_bone_rest(dst.find_bone(P + CHILD[bone_name])).origin.normalized()


## Idle breathing at phase u (0-1 over the clip): the upper body tilts back a
## little on each breath, the neck takes most of it back out and the shoulders
## rise. Rotations in model space; the model faces +Z, so +X is its left.
func _breathe(dst: Skeleton3D, glob: Dictionary, children: Dictionary, u: float) -> void:
	var breath := pow(sin(PI * u * BREATHS_PER_IDLE), 2.0)   # 0 -> 1 -> 0, BREATHS_PER_IDLE times
	var chest := deg_to_rad(BREATH_CHEST_DEGREES) * breath
	var shoulder := deg_to_rad(BREATH_SHOULDER_DEGREES) * breath
	# Negative about +X tips the top back (away from +Z, the way it faces).
	_rotate_branch(dst.find_bone(P + "Spine1"), Quaternion(Vector3.RIGHT, -chest), glob, children)
	_rotate_branch(dst.find_bone(P + "Neck"), Quaternion(Vector3.RIGHT, chest * BREATH_NECK_COUNTER), glob, children)
	# About +Z: positive lifts the +X (left) arm, negative the right.
	_rotate_branch(dst.find_bone(P + "LeftShoulder"), Quaternion(Vector3.BACK, shoulder), glob, children)
	_rotate_branch(dst.find_bone(P + "RightShoulder"), Quaternion(Vector3.BACK, -shoulder), glob, children)


## Turns a bone and everything below it (model space; only rotations matter).
func _rotate_branch(bone: int, turn: Quaternion, glob: Dictionary, children: Dictionary) -> void:
	if bone < 0:
		return
	glob[bone] = turn * (glob[bone] as Quaternion)
	for child: int in children[bone]:
		_rotate_branch(child, turn, glob, children)


## Sample time `delay` earlier: wrapped for loops, held at the start otherwise.
static func _shift(time: float, delay: float, length: float, looping: bool) -> float:
	if delay <= 0.0:
		return time
	var t := time - delay
	return fposmod(t, length) if looping else maxf(t, 0.0)


## The bat's grip on the new right hand: the same pose relative to the hand's
## rest orientation, so it sits the same way once the hand is animated.
func _print_grip(source_model: Node3D, src: Skeleton3D, dst: Skeleton3D, src_rest: Dictionary, dst_rest: Dictionary) -> void:
	var weapon: Node3D = source_model.get_node(^"Skeleton3D/RightHandAttachment/MeleeWeapon")
	var sb := src.find_bone(P + "RightHand")
	var tb := dst.find_bone(P + "RightHand")
	var src_basis := Basis(src_rest[sb] as Quaternion)
	var dst_basis := Basis(dst_rest[tb] as Quaternion)
	var to_target := dst_basis.inverse() * src_basis
	var grip := Transform3D(to_target * weapon.transform.basis, to_target * weapon.transform.origin)
	print("RightHand bone_idx %d grip %s" % [tb, var_to_str(grip)])


## Each bone's rest rotation in model space.
static func _rest_globals(skeleton: Skeleton3D) -> Dictionary:
	var out := {}
	for b in _parent_first(skeleton):
		var parent := skeleton.get_bone_parent(b)
		var local := skeleton.get_bone_rest(b).basis.get_rotation_quaternion()
		out[b] = (out[parent] * local) if parent >= 0 else local
	return out


static func _parent_first(skeleton: Skeleton3D) -> PackedInt32Array:
	var order := PackedInt32Array()
	var placed := {}
	while order.size() < skeleton.get_bone_count():
		for b in skeleton.get_bone_count():
			if placed.has(b):
				continue
			var parent := skeleton.get_bone_parent(b)
			if parent < 0 or placed.has(parent):
				order.append(b)
				placed[b] = true
	return order
