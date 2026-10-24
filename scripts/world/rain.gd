class_name RainEmitter
extends Node3D
## Night rain for the street areas: a box of falling streaks that follows the
## active camera, so rain is always around the player without filling the whole
## level with particles. Every look value is an export; tune them in the editor.

## Number of drops alive at once.
@export var amount: int = 900
## Width and depth of the rain box around the camera (m).
@export var area: float = 34.0
## How far above the camera the drops start (m).
@export var height: float = 16.0
@export var fall_speed: float = 22.0
## Streak length (m) and colour.
@export var streak_length: float = 0.7
@export var rain_color: Color = Color(0.72, 0.8, 1.0, 0.5)
## Drops are invisible closer to the camera than x (m) and fully shown from y.
@export var near_fade: Vector2 = Vector2(1.0, 3.5)

var _drops: GPUParticles3D


func _ready() -> void:
	_drops = GPUParticles3D.new()
	_drops.name = &"Drops"
	_drops.amount = amount
	_drops.lifetime = (height + 6.0) / fall_speed
	_drops.local_coords = false
	_drops.visibility_aabb = AABB(Vector3(-area, -height - 8.0, -area), Vector3(area * 2.0, height + 12.0, area * 2.0))
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(area * 0.5, 0.2, area * 0.5)
	process.direction = Vector3(0.12, -1.0, 0.0)
	process.spread = 2.0
	process.initial_velocity_min = fall_speed * 0.9
	process.initial_velocity_max = fall_speed * 1.1
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	_drops.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, streak_length)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = rain_color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.disable_fog = true
	# Drops passing right by the lens would fill the screen as big bars: fade them out up close.
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = near_fade.x
	material.distance_fade_max_distance = near_fade.y
	streak.material = material
	_drops.draw_pass_1 = streak
	add_child(_drops)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + Vector3(0.0, height, 0.0)
