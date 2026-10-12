# Adds the bat swing clips to the player's (retargeted) animation library:
#   godot --headless --path . -s res://scripts/tools/build_bat_swing_clips.gd
#
# SwingRL is the Attack clip (right to left) and SwingLR the same clip played
# backwards (left to right); SwingFinisher, the combo's third hit, is SwingRL at
# the finisher's slower, heavier timing. Each is retimed to the phases in
# res://resources/combat_tuning.tres: windup, a fast ease-out strike over the
# clip's hit frames, and an ease-in-out recovery. The phase lengths are stored on
# each clip ("phase_times") so the BatSwing state can retime them live if the
# tuning changes later; rerun this after changing the source Attack clip.
# Also copies the clip metadata (hit_frames, trail_frames) from the source
# library, which the retarget to the Real_MainC rig had dropped.
extends SceneTree

const SOURCE_LIBRARY := "res://resources/player/player_animations.tres"
const LIBRARY := "res://resources/player/player_animations_real.tres"
const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")
const SOURCE_CLIP := &"Attack"
const FPS := 60.0


func _initialize() -> void:
	var source: AnimationLibrary = load(SOURCE_LIBRARY)
	var library: AnimationLibrary = load(LIBRARY)
	for clip_name: StringName in library.get_animation_list():
		if not source.has_animation(clip_name):
			continue
		var from := source.get_animation(clip_name)
		for key: StringName in from.get_meta_list():
			library.get_animation(clip_name).set_meta(key, from.get_meta(key))
	var attack := library.get_animation(SOURCE_CLIP)
	var normal: Array[float] = [TUNING.swing_windup_time, TUNING.swing_strike_time, TUNING.swing_recovery_time]
	var finisher: Array[float] = [TUNING.finisher_windup_time, TUNING.finisher_strike_time, TUNING.finisher_recovery_time]
	for clip_name: StringName in [&"SwingRL", &"SwingLR", &"SwingFinisher"]:
		if library.has_animation(clip_name):
			library.remove_animation(clip_name)
	library.add_animation(&"SwingRL", _swing(attack, false, normal))
	library.add_animation(&"SwingLR", _swing(attack, true, normal))
	library.add_animation(&"SwingFinisher", _swing(attack, false, finisher))
	var err := ResourceSaver.save(library, LIBRARY)
	print("saved %s (error %d)" % [LIBRARY, err])
	quit()


func _swing(source: Animation, reverse: bool, durations: Array[float]) -> Animation:
	var hit_frames: Vector2i = source.get_meta(&"hit_frames")
	var strike_start := hit_frames.x * source.step
	var strike_end := (hit_frames.y + 1) * source.step
	# Source time covered by each phase, in playback order.
	var spans: Array[Vector2] = [Vector2(0.0, strike_start), Vector2(strike_start, strike_end), Vector2(strike_end, source.length)]
	if reverse:
		spans = [Vector2(source.length, strike_end), Vector2(strike_end, strike_start), Vector2(strike_start, 0.0)]

	var out := Animation.new()
	out.step = 1.0 / FPS
	out.length = durations[0] + durations[1] + durations[2]
	var tracks := {}
	for track in source.get_track_count():
		var type := source.track_get_type(track)
		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue
		var copy := out.add_track(type)
		out.track_set_path(copy, source.track_get_path(track))
		tracks[track] = copy

	var phase_start := 0.0
	for phase in 3:
		var frames := maxi(1, ceili(durations[phase] * FPS))
		var last := frames if phase == 2 else frames - 1
		for i in last + 1:
			var u := float(i) / frames
			var source_time := lerpf(spans[phase].x, spans[phase].y, _ease(phase, u))
			var time := phase_start + u * durations[phase]
			for track: int in tracks:
				if source.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(tracks[track], time, source.rotation_track_interpolate(track, source_time))
				else:
					out.position_track_insert_key(tracks[track], time, source.position_track_interpolate(track, source_time))
		phase_start += durations[phase]
	out.set_meta(&"phase_times", Vector3(durations[0], durations[1], durations[2]))
	out.set_meta(&"trail_frames", Vector2i(floori(durations[0] * FPS), ceili((durations[0] + durations[1]) * FPS)))
	return out


## Windup and recovery ease in and out; the strike eases out (fast start).
static func _ease(phase: int, u: float) -> float:
	if phase == 1:
		return 1.0 - (1.0 - u) * (1.0 - u)
	return u * u * (3.0 - 2.0 * u)
