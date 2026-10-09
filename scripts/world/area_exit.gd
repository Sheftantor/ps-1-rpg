class_name AreaExit
extends Area3D
## A walk-through gate to another area: when the player enters it, AreaTravel
## fades to the loading screen and moves them to target_spawn in target_scene.
## Shown as a sheet of gold haze with a sign naming where it leads. The gate is
## size wide and faces its local -Z (the sign reads from the +Z side, the side
## the player walks in from).

## The area scene this gate leads to.
@export_file("*.tscn") var target_scene: String = ""
## Name of the spawn point (a Marker3D in the "spawn_points" group) to arrive at.
@export var target_spawn: StringName = &""
## Shown on the gate's sign and the loading screen.
@export var area_name: String = ""
@export var size: Vector3 = Vector3(16.0, 4.0, 1.5)
@export var haze_color: Color = Color(1.0, 0.82, 0.35, 0.35)

const SIGN_FONT: Font = preload("res://resources/ui/hud_font_bold.tres")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	add_child(shape)
	_build_visuals()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and target_scene != "" and not AreaTravel.service().busy:
		AreaTravel.service().travel(target_scene, target_spawn, area_name)


func _build_visuals() -> void:
	# A fading curtain of light: brightest at the ground, gone at the top.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(haze_color, 0.0))
	gradient.set_color(1, haze_color)
	var fade := GradientTexture2D.new()
	fade.gradient = gradient
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(0, 1)
	fade.width = 4
	fade.height = 32
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = fade
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var curtain := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x, size.y)
	curtain.mesh = quad
	curtain.material_override = material
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.position.y = size.y * 0.5
	add_child(curtain)

	var sign := Label3D.new()
	sign.text = "TO " + area_name.to_upper()
	sign.font = SIGN_FONT
	sign.font_size = 64
	sign.outline_size = 16
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.9, 0.6)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign.position.y = size.y + 0.6
	add_child(sign)
