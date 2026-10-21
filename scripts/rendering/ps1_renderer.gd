extends Node
## Autoload that applies the PS1 look to the whole game:
## - puts the PS1 post-process compositor on whichever camera is active, and
## - swaps plain StandardMaterial3Ds (e.g. imported .glb models) for the PS1
##   shader as they enter the tree, so they get vertex snapping and PS1 lighting.
## Set metadata "ps1_keep_materials" = true on a node to opt it (and its children) out.
## Every look value comes from res://settings/ps1_settings.tres (PS1Settings).
## The compositor runs inside the 3D render, before any CanvasLayer is drawn, so
## the UI is never pixelated. Shift+F9 (debug) switches the whole look off and on.

const SETTINGS_PATH := "res://settings/ps1_settings.tres"
## F9 alone opens the Feel panel (FeelPanel), so the toggle needs Shift.
const TOGGLE_KEY := KEY_F9
const COMPOSITOR: Compositor = preload("res://resources/rendering/ps1_compositor.tres")
const PS1_SHADER: Shader = preload("res://shaders/ps1.gdshader")
const PS1_DOUBLE_SIDED_SHADER: Shader = preload("res://shaders/ps1_double_sided.gdshader")
const KEEP_MATERIALS_META := &"ps1_keep_materials"

var settings: PS1Settings
## False while the debug toggle has the look switched off.
var effect_enabled: bool = true

var _converted: Dictionary[Material, Material] = {}


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	settings = load(SETTINGS_PATH) as PS1Settings
	if settings == null:
		settings = PS1Settings.new()
	settings.changed.connect(apply_settings)
	apply_settings()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.is_debug_build() and key != null and key.pressed and not key.echo 			and key.shift_pressed and key.physical_keycode == TOGGLE_KEY:
		set_effect_enabled(not effect_enabled)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.compositor == null:
		camera.compositor = COMPOSITOR


## Turns the whole PS1 look (post effect, vertex snap, affine warp) on or off.
func set_effect_enabled(enabled: bool) -> void:
	effect_enabled = enabled
	apply_settings()
	print("PS1 effect ", "on" if enabled else "off")


## Pushes the settings resource to the post effect and the shader globals.
func apply_settings() -> void:
	var on := effect_enabled
	RenderingServer.global_shader_parameter_set(&"ps1_snap_resolution", float(settings.get_virtual_height()))
	RenderingServer.global_shader_parameter_set(&"ps1_snap_strength", settings.vertex_snap_strength if on else 0.0)
	RenderingServer.global_shader_parameter_set(&"ps1_affine_warp", settings.affine_warp_amount if on else 0.0)
	for effect in COMPOSITOR.compositor_effects:
		if effect is PS1PostEffect:
			effect.enabled = on
			effect.virtual_height = settings.get_virtual_height()
			effect.dither = settings.dither_enabled
			effect.color_levels = 0 if settings.color_depth_bits >= 8 else 1 << settings.color_depth_bits


func _on_node_added(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or _is_opted_out(node):
		return
	if mesh_instance.material_override != null:
		mesh_instance.material_override = _to_ps1(mesh_instance.material_override)
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface)
		var converted := _to_ps1(material)
		if converted != material:
			mesh_instance.set_surface_override_material(surface, converted)


func _is_opted_out(node: Node) -> bool:
	while node != null:
		if node.get_meta(KEEP_MATERIALS_META, false):
			return true
		node = node.get_parent()
	return false


## Returns a PS1 shader copy of an opaque, lit StandardMaterial3D, or the
## material unchanged. Transparent and unshaded materials (debug volumes,
## markers) are left alone.
func _to_ps1(material: Material) -> Material:
	var base := material as BaseMaterial3D
	if base == null \
			or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return material
	if _converted.has(base):
		return _converted[base]

	var ps1 := ShaderMaterial.new()
	ps1.shader = PS1_DOUBLE_SIDED_SHADER if base.cull_mode == BaseMaterial3D.CULL_DISABLED else PS1_SHADER
	ps1.set_shader_parameter(&"albedo_color", base.albedo_color)
	ps1.set_shader_parameter(&"albedo_texture", base.albedo_texture)
	ps1.set_shader_parameter(&"uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
	if base.emission_enabled:
		ps1.set_shader_parameter(&"emission_color", base.emission)
		ps1.set_shader_parameter(&"emission_texture", base.emission_texture)
		ps1.set_shader_parameter(&"emission_energy", base.emission_energy_multiplier)
	_converted[base] = ps1
	return ps1
