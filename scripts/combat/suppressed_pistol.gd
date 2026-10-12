class_name SuppressedPistol
extends Node3D
## The suppressed pistol (res://Import/Weapons/Silencer_gun/Silencer_Pistol.glb).
## The root carries the rotation and the uniform scale that makes the gun 0.36 m
## long; the six pieces are never scaled. In this node's local space (the GLB's)
## the muzzle is +Z, so the slide recoils along -Z. No muzzle flash: it's suppressed.
## fire() cycles the slide and kicks a casing out of the Eject marker.

@export var casing_scene: PackedScene = preload("res://scenes/bullet_casing.tscn")

@export_group("Slide")
## How far the slide travels back on each shot (world metres).
@export var slide_travel: float = 0.02
## Time for the slide to snap back (s).
@export var slide_back_time: float = 0.03
## Time for the slide to return forward (s).
@export var slide_return_time: float = 0.08

@export_group("Casing")
## Ejection speed to the gun's right (m/s).
@export var eject_side_speed: float = 1.6
## Ejection speed upward (m/s).
@export var eject_up_speed: float = 1.2
## Random extra speed in every direction (m/s).
@export var eject_jitter: float = 0.3

var _slider_rest: Vector3 = Vector3.ZERO
var _slide_tween: Tween = null

@onready var muzzle: Marker3D = $Muzzle
@onready var eject: Marker3D = $Eject
@onready var _slider: Node3D = $Slider


func _ready() -> void:
	_slider_rest = _slider.position
	# A round sitting in the chamber, not a projectile.
	$Bullet.visible = false


func fire() -> void:
	cycle_slide()
	eject_casing()


## Moves only the Slider back along the barrel axis and returns it.
func cycle_slide() -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	_slider.position = _slider_rest
	# Local -Z is toward the rear here (the muzzle is +Z). slide_travel is in world
	# metres; convert through this node's world scale.
	var back := _slider_rest + Vector3.FORWARD * slide_travel / global_basis.get_scale().x
	_slide_tween = create_tween()
	_slide_tween.tween_property(_slider, ^"position", back, slide_back_time)
	_slide_tween.tween_property(_slider, ^"position", _slider_rest, slide_return_time)


func eject_casing() -> void:
	if casing_scene == null:
		return
	var casing := casing_scene.instantiate() as RigidBody3D
	var world := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	world.add_child(casing)
	var forward := muzzle_direction()
	var up := global_basis.y.normalized()
	var right := forward.cross(up).normalized()
	casing.global_transform = Transform3D(Basis.looking_at(right, up), eject.global_position)
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * eject_jitter
	casing.linear_velocity = right * eject_side_speed + up * eject_up_speed + jitter
	casing.angular_velocity = Vector3(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))


## World direction the suppressor points.
func muzzle_direction() -> Vector3:
	return global_basis.z.normalized()
