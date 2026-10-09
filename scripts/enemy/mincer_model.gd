class_name MincerModel
extends Node3D
## The Mincer's rigged model (res://Import/Character/Mincer.glb). Gives its clips
## short names, makes them play in place (the body is moved by Enemy, not by root
## motion), and wraps playback, flashes and the arm jitter for the enemy states.

const CLIP_WALK: StringName = &"Walk"
## Weight-shifting hesitation; doubles as the standing idle and the hit flinch.
const CLIP_IDLE: StringName = &"Hesitate"
const CLIP_STEP_BACK: StringName = &"StepBack"
const CLIP_SLASH: StringName = &"Slash"
## Substring of each imported clip's (long, prompt-generated) name -> short name.
const SOURCE_CLIPS: Dictionary[String, StringName] = {
	"walk forward": CLIP_WALK,
	"hesitate": CLIP_IDLE,
	"step backward": CLIP_STEP_BACK,
	"Slashing": CLIP_SLASH,
}
const LOOPING_CLIPS: Array[StringName] = [CLIP_WALK, CLIP_IDLE]
const HIPS_BONE := "mixamorig_Hips"
const BLEND_TIME: float = 0.15
## Walk playback speed limits when matching the clip to the body's ground speed.
const WALK_SPEED_SCALE_MIN: float = 0.4
const WALK_SPEED_SCALE_MAX: float = 3.0

## Built once from the imported clips and shared by every Mincer.
static var _library: AnimationLibrary = null
## Forward travel of the Walk clip before it was made in place (rig units/s).
static var _walk_rig_speed: float = 0.3

var _meshes: Array[GeometryInstance3D] = []
var _base_scale: Vector3 = Vector3.ONE

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _jitter: ArmJitter = $Mincer/Skeleton3D/ArmJitter


func _ready() -> void:
	_base_scale = scale
	if _library == null:
		_library = _build_library(_anim)
	for library_name: StringName in _anim.get_animation_library_list():
		_anim.remove_animation_library(library_name)
	_anim.add_animation_library(&"", _library)
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(node as GeometryInstance3D)
	play(CLIP_IDLE)


## Plays clip at speed (AnimationPlayer.speed_scale). Keeps an already-playing
## clip going (only the speed changes) unless restart is set.
func play(clip: StringName, speed: float = 1.0, restart: bool = false) -> void:
	if restart or _anim.current_animation != clip:
		_anim.play(clip, BLEND_TIME)
		if restart:
			_anim.seek(0.0, true)
	_anim.speed_scale = speed


## Walk cycle with its playback speed matched to ground_speed (m/s).
func walk(ground_speed: float) -> void:
	var clip_speed := _walk_rig_speed * absf(_base_scale.z)
	play(CLIP_WALK, clampf(ground_speed / maxf(clip_speed, 0.01), WALK_SPEED_SCALE_MIN, WALK_SPEED_SCALE_MAX))


## Whether a non-looping clip (slash, flinch, stumble) is still running.
func is_playing_one_shot() -> bool:
	return _anim.is_playing() and not LOOPING_CLIPS.has(StringName(_anim.current_animation))


func freeze() -> void:
	_anim.speed_scale = 0.0
	set_jitter(0.0)


## Random arm shake layered on the animated pose, in degrees (0 = off).
func set_jitter(degrees: float) -> void:
	_jitter.amount_degrees = degrees


func set_flash(color: Color) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.set_instance_shader_parameter(&"flash_color", color)


## Multiplies the skin colour (the PS1 shader's per-instance tint).
func set_tint(color: Color) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.set_instance_shader_parameter(&"tint", color)


func set_pulse(amount: float) -> void:
	scale = _base_scale * amount


static func _build_library(source: AnimationPlayer) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for source_name: StringName in source.get_animation_list():
		for key: String in SOURCE_CLIPS:
			if not String(source_name).contains(key):
				continue
			var clip_name: StringName = SOURCE_CLIPS[key]
			var clip := source.get_animation(source_name).duplicate(true) as Animation
			if clip_name == CLIP_WALK:
				_walk_rig_speed = _root_travel_speed(clip)
			_make_in_place(clip)
			clip.loop_mode = Animation.LOOP_LINEAR if LOOPING_CLIPS.has(clip_name) else Animation.LOOP_NONE
			library.add_animation(clip_name, clip)
	for clip_name: StringName in SOURCE_CLIPS.values():
		if not library.has_animation(clip_name):
			push_error("MincerModel: Mincer.glb has no clip for '%s'." % clip_name)
	return library


static func _hips_track(clip: Animation) -> int:
	for track in clip.get_track_count():
		if clip.track_get_type(track) == Animation.TYPE_POSITION_3D \
				and String(clip.track_get_path(track)).ends_with(":" + HIPS_BONE):
			return track
	return -1


## Pins the hips' horizontal position to the first key; keeps the vertical bob.
static func _make_in_place(clip: Animation) -> void:
	var track := _hips_track(clip)
	if track < 0 or clip.track_get_key_count(track) == 0:
		return
	var first: Vector3 = clip.track_get_key_value(track, 0)
	for key in clip.track_get_key_count(track):
		var value: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, Vector3(first.x, value.y, first.z))


static func _root_travel_speed(clip: Animation) -> float:
	var track := _hips_track(clip)
	if track < 0 or clip.length <= 0.0:
		return _walk_rig_speed
	var travel := clip.position_track_interpolate(track, clip.length) - clip.position_track_interpolate(track, 0.0)
	travel.y = 0.0
	return travel.length() / clip.length
