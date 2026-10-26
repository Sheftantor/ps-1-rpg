extends Node
## Autoload that applies the PS1 look to the whole game:
## - puts the PS1 post-process compositor on whichever camera is active, and
## - swaps plain StandardMaterial3Ds (e.g. imported .glb models) for the PS1
##   shader as they enter the tree, so they get vertex snapping and PS1 lighting.
## Set metadata "ps1_keep_materials" = true on a node to opt it (and its children) out.
## Set metadata "ps1_no_vertex_snap" = true to keep its vertices off the snap grid
## (big flat ground: its few huge triangles slide in steps and tiles split apart).
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
const NO_SNAP_META := &"ps1_no_vertex_snap"

var settings: PS1Settings
## False while the debug toggle has the look switched off.
var effect_enabled: bool = true

## Animation mixers advanced by hand at settings.animation_fps ("classic delay").
var _stepped: Array[AnimationMixer] = []
var _step_accum: float = 0.0
var _converted: Dictionary[Material, Material] = {}
var _converted_no_snap: Dictionary[Material, Material] = {}


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


func _process(delta: float) -> void:
	_step_animations(delta)
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
	for mixer in _stepped:
		if is_instance_valid(mixer):
			_apply_step_mode(mixer)


func _on_node_added(node: Node) -> void:
	if node is AnimationMixer:
		_register_mixer.call_deferred(node as AnimationMixer)
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or _has_meta_up(node, KEEP_MATERIALS_META):
		return
	var snap := not _has_meta_up(node, NO_SNAP_META)
	if mesh_instance.material_override != null:
		mesh_instance.material_override = _to_ps1(mesh_instance.material_override, snap)
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface)
		var converted := _to_ps1(material, snap)
		if converted != material:
			mesh_instance.set_surface_override_material(surface, converted)


## Whether node or any of its ancestors has meta set to true.
func _has_meta_up(node: Node, meta: StringName) -> bool:
	while node != null:
		if node.get_meta(meta, false):
			return true
		node = node.get_parent()
	return false


## Returns a PS1 shader copy of an opaque, lit StandardMaterial3D, or the
## material unchanged. Transparent and unshaded materials (debug volumes,
## markers) are left alone. snap false turns the shader's vertex_snap off.
func _to_ps1(material: Material, snap: bool = true) -> Material:
	var base := material as BaseMaterial3D
	if base == null \
			or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return material
	var cache := _converted if snap else _converted_no_snap
	if cache.has(base):
		return cache[base]

	var ps1 := ShaderMaterial.new()
	ps1.shader = PS1_DOUBLE_SIDED_SHADER if base.cull_mode == BaseMaterial3D.CULL_DISABLED else PS1_SHADER
	ps1.set_shader_parameter(&"albedo_color", base.albedo_color)
	ps1.set_shader_parameter(&"albedo_texture", base.albedo_texture)
	ps1.set_shader_parameter(&"uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
	ps1.set_shader_parameter(&"vertex_snap", snap)
	if base.emission_enabled:
		ps1.set_shader_parameter(&"emission_color", base.emission)
		ps1.set_shader_parameter(&"emission_texture", base.emission_texture)
		ps1.set_shader_parameter(&"emission_energy", base.emission_energy_multiplier)
	cache[base] = ps1
	return ps1


# --- Stepped animation ("classic delay") -----------------------------------------
# PS1 characters animated at a low, fixed rate. Mixers are switched to manual
# advance and ticked together every 1/animation_fps seconds. A mixer that can't
# process (hit stop disables it, the tree is paused) is simply skipped.

func _register_mixer(mixer: AnimationMixer) -> void:
	if not is_instance_valid(mixer) or mixer in _stepped or _has_meta_up(mixer, KEEP_MATERIALS_META):
		return
	# A player driven by an AnimationTree is advanced by that tree, not by us.
	if mixer is AnimationPlayer:
		for sibling in mixer.get_parent().get_children():
			var tree := sibling as AnimationTree
			if tree != null and tree.get_node_or_null(tree.anim_player) == mixer:
				return
	_stepped.append(mixer)
	mixer.tree_exiting.connect(_stepped.erase.bind(mixer), CONNECT_ONE_SHOT)
	_apply_step_mode(mixer)


func _apply_step_mode(mixer: AnimationMixer) -> void:
	var stepping := effect_enabled and settings.animation_fps > 0
	mixer.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if stepping \
			else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func _step_animations(delta: float) -> void:
	if not effect_enabled or settings.animation_fps <= 0:
		return
	_step_accum += delta
	var interval := 1.0 / float(settings.animation_fps)
	if _step_accum < interval:
		return
	var elapsed := _step_accum
	_step_accum = fmod(_step_accum, interval)
	elapsed -= _step_accum
	for mixer in _stepped:
		if is_instance_valid(mixer) and mixer.is_inside_tree() and mixer.can_process():
			mixer.advance(elapsed)
