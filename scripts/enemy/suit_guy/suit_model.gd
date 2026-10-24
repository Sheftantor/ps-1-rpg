class_name SuitModel
extends EnemyModel
## Suit Guy's model: the rigged suit (under Visual, swappable for any rig with a
## Visual/Skeleton3D using mixamorig_ bone names) holding the SuppressedPistol in
## its right hand. Clips come from res://resources/enemies/suit_guy_animations.tres
## (the player's clips retargeted by res://scripts/tools/retarget_suit_guy_animations.gd).
## A SuitPosture modifier on the skeleton then fixes his bearing on top of every
## clip (upright, shoulders squared, gun at low-ready, side-on aim, recoil); its
## values come from SuitGuy's Posture group via posture.

const CLIP_IDLE: StringName = &"Idle"
const CLIP_WALK: StringName = &"Walk"
## Clip names the shared enemy states ask for (MincerModel's) -> this model's clips.
const CLIP_ALIASES: Dictionary[StringName, StringName] = {
	MincerModel.CLIP_IDLE: CLIP_IDLE,
	MincerModel.CLIP_WALK: CLIP_WALK,
	MincerModel.CLIP_STEP_BACK: CLIP_IDLE,
}
const LOOPING_CLIPS: Array[StringName] = [CLIP_IDLE, CLIP_WALK]
const BLEND_TIME: float = 0.15
## Recoil kick up and settle times (s).
const RECOIL_UP_TIME: float = 0.05
const RECOIL_SETTLE_TIME: float = 0.25
## How fast the posture eases between standing and walking (per second).
const MOVE_BLEND_SPEED: float = 4.0
## Walk playback speed limits when matching the clip to the body's ground speed.
const WALK_SPEED_SCALE_MIN: float = 0.4
const WALK_SPEED_SCALE_MAX: float = 2.0

## Applied to every mesh under Visual (the PS1 shader with the suit's texture).
@export var skin_material: Material
## Ground speed (m/s) at which the Walk clip plays at normal speed.
@export var walk_clip_speed: float = 1.2

var _meshes: Array[GeometryInstance3D] = []
var _base_scale: Vector3 = Vector3.ONE
var _moving: bool = false
var _aim_tween: Tween = null
var _recoil_tween: Tween = null

## The posture layer on the skeleton (made in _ready).
var posture: SuitPosture = null

@onready var gun: SuppressedPistol = $RightHandAttachment/GunMount/SuppressedPistol
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _skeleton: Skeleton3D = $Visual/Skeleton3D


func _ready() -> void:
	_base_scale = scale
	for node: Node in $Visual.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		if skin_material != null:
			mesh.material_override = skin_material
		_meshes.append(mesh)
	posture = SuitPosture.new()
	posture.name = &"Posture"
	posture.model_to_skeleton = (global_transform.affine_inverse() * _skeleton.global_transform) 			.basis.orthonormalized().inverse()
	# The gun's muzzle direction (its +Z) and up, as seen from the hand bone.
	var gun_in_hand := ($RightHandAttachment/GunMount as Node3D).transform.basis * gun.transform.basis
	posture.gun_dir_in_hand = gun_in_hand.z.normalized()
	posture.gun_up_in_hand = gun_in_hand.y.normalized()
	_skeleton.add_child(posture)
	play(CLIP_IDLE)


func _process(delta: float) -> void:
	posture.move_weight = move_toward(posture.move_weight, 1.0 if _moving else 0.0, MOVE_BLEND_SPEED * delta)


func play(clip: StringName, speed: float = 1.0, restart: bool = false) -> void:
	var mapped: StringName = CLIP_ALIASES.get(clip, clip)
	_moving = mapped == CLIP_WALK
	_play(mapped, speed, restart, BLEND_TIME)


func walk(ground_speed: float) -> void:
	play(CLIP_WALK, clampf(ground_speed / maxf(walk_clip_speed, 0.01), WALK_SPEED_SCALE_MIN, WALK_SPEED_SCALE_MAX))


## Raises the gun from low-ready to chest height over time seconds. The raise,
## aim and recoil are all SuitPosture's, over the standing Idle clip (the
## library's Aim / Fire clips crouch and kick far too high, so they're unused).
func raise_gun(time: float) -> void:
	play(CLIP_IDLE)
	_blend_aim(1.0, time)


## Kicks the gun up a little and cycles its slide and casing.
func fire() -> void:
	if _recoil_tween != null:
		_recoil_tween.kill()
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(posture, ^"recoil", 1.0, RECOIL_UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil_tween.tween_property(posture, ^"recoil", 0.0, RECOIL_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gun.fire()


## Back to the standing pose with the gun lowered to low-ready over time seconds.
func lower_gun(time: float) -> void:
	_play(CLIP_IDLE, 1.0, false, time)
	_blend_aim(0.0, time)


## Height of the jacket collar (the Neck bone) above his feet (m, world scale).
func collar_height() -> float:
	return (_skeleton.global_transform * posture.collar_position).y - global_position.y


func _blend_aim(weight: float, time: float) -> void:
	if _aim_tween != null:
		_aim_tween.kill()
	_aim_tween = create_tween()
	_aim_tween.tween_property(posture, ^"aim_weight", weight, maxf(time, 0.01)) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_playing_one_shot() -> bool:
	return _anim.is_playing() and not LOOPING_CLIPS.has(StringName(_anim.current_animation))


func freeze() -> void:
	_anim.speed_scale = 0.0


func set_flash(color: Color) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.set_instance_shader_parameter(&"flash_color", color)


func set_tint(color: Color) -> void:
	for mesh: GeometryInstance3D in _meshes:
		mesh.set_instance_shader_parameter(&"tint", color)


func set_pulse(amount: float) -> void:
	scale = _base_scale * amount


func _play(clip: StringName, speed: float, restart: bool, blend: float) -> void:
	if restart or _anim.current_animation != clip:
		_anim.play(clip, blend)
		if restart:
			_anim.seek(0.0, true)
	_anim.speed_scale = speed
