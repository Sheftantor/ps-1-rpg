extends Node
## Autoload that applies the PS1 look to the whole game:
## - puts the PS1 post-process compositor on whichever camera is active, and
## - swaps plain StandardMaterial3Ds (e.g. imported .glb models) for the PS1
##   shader as they enter the tree, so they get vertex snapping and affine warping.
## Set metadata "ps1_keep_materials" = true on a node to opt it (and its children) out.

const COMPOSITOR: Compositor = preload("res://resources/rendering/ps1_compositor.tres")
const PS1_SHADER: Shader = preload("res://shaders/ps1.gdshader")
const PS1_DOUBLE_SIDED_SHADER: Shader = preload("res://shaders/ps1_double_sided.gdshader")
const KEEP_MATERIALS_META := &"ps1_keep_materials"

var _converted: Dictionary[Material, Material] = {}


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.compositor == null:
		camera.compositor = COMPOSITOR


## Changes the virtual resolution for both vertex snapping and pixelation.
func set_virtual_height(height: int) -> void:
	RenderingServer.global_shader_parameter_set(&"ps1_snap_resolution", float(height))
	for effect in COMPOSITOR.compositor_effects:
		if effect is PS1PostEffect:
			effect.virtual_height = height


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
