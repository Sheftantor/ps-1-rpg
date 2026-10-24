@tool
class_name PS1Settings
extends Resource
## Every PS1-look value for the 3D world (UI is never touched by any of it).
## One instance at res://settings/ps1_settings.tres, loaded by the PS1Renderer
## autoload at launch. At runtime, changing PS1Renderer.settings applies at once.
## Shift+F9 (debug builds) switches the whole effect off and on to compare.

enum InternalResolution { R640x360, R480x270, R320x240 }

const RESOLUTIONS: Dictionary[InternalResolution, Vector2i] = {
	InternalResolution.R640x360: Vector2i(640, 360),
	InternalResolution.R480x270: Vector2i(480, 270),
	InternalResolution.R320x240: Vector2i(320, 240),
}

## Virtual framebuffer the 3D world is pixelated to. Only the height matters:
## each virtual pixel is a square block of screen pixels (1080p: 360 = 3x3,
## 270 = 4x4, 240 = 5x5 blocks), and width follows the window's aspect.
@export var internal_resolution: InternalResolution = InternalResolution.R640x360:
	set(value):
		internal_resolution = value
		emit_changed()
## How hard vertices lock to the virtual pixel grid (the PS1 wobble).
## 0 = smooth, 1 = full snap.
@export_range(0.0, 1.0, 0.05) var vertex_snap_strength: float = 1.0:
	set(value):
		vertex_snap_strength = value
		emit_changed()
## 4x4 ordered dither before the color depth drop, like the PS1's 15-bit output.
@export var dither_enabled: bool = true:
	set(value):
		dither_enabled = value
		emit_changed()
## Bits per color channel of the virtual framebuffer. 5 = PS1 (15-bit color),
## lower = more banding, 8 = no reduction.
@export_range(1, 8) var color_depth_bits: int = 5:
	set(value):
		color_depth_bits = value
		emit_changed()
## Affine (non perspective-correct) texture mapping, the PS1 texture swim.
## 0 = perspective-correct, 1 = full PS1 warp. Big floor triangles warp the most.
@export_range(0.0, 1.0, 0.05) var affine_warp_amount: float = 0.0:
	set(value):
		affine_warp_amount = value
		emit_changed()


func get_virtual_height() -> int:
	return RESOLUTIONS[internal_resolution].y
