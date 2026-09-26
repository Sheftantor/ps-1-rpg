@tool
class_name PS1PostEffect
extends CompositorEffect
## Whole-frame PS1 framebuffer look: low virtual resolution with nearest-neighbor
## upscaling, reduced color depth and ordered dithering. Runs on the 3D image only,
## so 2D UI stays crisp. Applied to every camera by the PS1Renderer autoload.

const SHADER_PATH := "res://shaders/ps1_post.glsl"

## Virtual vertical resolution. Keep in sync with the ps1_snap_resolution shader
## global (PS1Renderer.set_virtual_height() updates both).
@export_range(120, 720) var virtual_height: int = 240
@export var pixelate: bool = true
@export_range(0, 256) var color_levels: int = 32
@export_range(0.0, 1.0) var dither_strength: float = 1.0

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_create_pipeline)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _shader.is_valid():
		# Freeing the shader also frees the pipeline that depends on it.
		_rd.free_rid(_shader)


func _create_pipeline() -> void:
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		return # Compatibility renderer or headless: effect is a no-op.
	var shader_file: RDShaderFile = load(SHADER_PATH)
	_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var block := maxi(1, roundi(float(size.y) / virtual_height)) if pixelate else 1
	var push_constant := PackedFloat32Array([
		size.x, size.y, block, color_levels, dither_strength, 0.0, 0.0, 0.0,
	]).to_byte_array()
	var blocks := Vector2i(ceili(float(size.x) / block), ceili(float(size.y) / block))

	for view in buffers.get_view_count():
		var image := RDUniform.new()
		image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		image.binding = 0
		image.add_id(buffers.get_color_layer(view))
		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [image])

		var list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(list, _pipeline)
		_rd.compute_list_bind_uniform_set(list, uniform_set, 0)
		_rd.compute_list_set_push_constant(list, push_constant, push_constant.size())
		_rd.compute_list_dispatch(list, ceili(blocks.x / 8.0), ceili(blocks.y / 8.0), 1)
		_rd.compute_list_end()
