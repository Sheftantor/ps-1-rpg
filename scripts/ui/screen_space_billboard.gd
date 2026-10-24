class_name ScreenSpaceBillboard
extends Node
## Draws a billboarded Sprite3D (a FloatingHealthBar's Display) as a 2D sprite on
## the shared WorldUi CanvasLayer instead of inside the 3D render, so the PS1
## post effect never pixelates its text. The Sprite3D still drives everything
## (position, offset, pixel_size, modulate, visible); this only mirrors it each
## frame and hides it from cameras (layers = 0). The on-screen scale snaps to a
## whole number (never below 1), so the pixel font is never resampled by a
## fraction. Draws over the 3D world, under PlayerHud and every menu.
## Used by res://scenes/enemy_health_bar.tscn and player_health_bar.tscn.

const LAYER_NAME := &"WorldUiLayer"
## Over the 3D world, under PlayerHud (5) and the menus (20+).
const LAYER := 1

@export var display_path: NodePath = ^"../Display"

## Shared by every billboard; lives on the root so it survives scene changes.
static var _layer: CanvasLayer

var _display: Sprite3D
var _sprite: Sprite2D


func _ready() -> void:
	# After the bar has moved and scaled its Display this frame.
	process_priority = 100
	_display = get_node(display_path) as Sprite3D
	_display.layers = 0


func _exit_tree() -> void:
	if is_instance_valid(_sprite):
		_sprite.queue_free()
	_sprite = null


func _process(_delta: float) -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_get_layer().add_child(_sprite)
	var camera := _display.get_viewport().get_camera_3d()
	var shown := camera != null and _display.texture != null and _display.is_visible_in_tree() \
			and _display.modulate.a > 0.001 and not camera.is_position_behind(_display.global_position)
	_sprite.visible = shown
	if not shown:
		return
	var depth := -(camera.global_transform.affine_inverse() * _display.global_position).z
	var screen_height := _display.get_viewport().get_visible_rect().size.y
	var pixels_per_meter := screen_height / camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL \
			else screen_height / (2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5))
	# fixed_size sprites grow with depth, which cancels the perspective shrink.
	var meters_per_texel := _display.pixel_size * (depth if _display.fixed_size else 1.0)
	var pixel_scale := maxf(1.0, roundf(meters_per_texel * pixels_per_meter))
	var texture_size := _display.texture.get_size()
	var offset := Vector2(_display.offset.x, -_display.offset.y)
	var center := camera.unproject_position(_display.global_position)
	_sprite.texture = _display.texture
	_sprite.scale = Vector2.ONE * pixel_scale
	_sprite.position = (center + (offset - texture_size * 0.5) * pixel_scale).round()
	_sprite.modulate = _display.modulate
	# Nearer bars draw over farther ones.
	_sprite.z_index = clampi(-roundi(depth * 10.0), RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)


func _get_layer() -> CanvasLayer:
	if not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.name = LAYER_NAME
		_layer.layer = LAYER
		# Deferred: the root may still be adding the current scene.
		get_tree().root.add_child.call_deferred(_layer)
	return _layer
