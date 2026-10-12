extends Node
## Sets the Windows 95 arrow as the mouse cursor (autoload "Win95Cursor").
## Done here rather than in Project Settings > Display > Mouse Cursor, which
## makes Godot report a leaked texture on quit; this clears it on the way out.

## The cursor image, written by res://scripts/tools/build_win95_theme.gd.
const CURSOR_PATH := "res://resources/ui/win95/cursor_dark.png"
## Pixel of the image that is the click point (the arrow's tip).
const HOTSPOT := Vector2.ZERO


func _ready() -> void:
	set_cursor(CURSOR_PATH)


func _exit_tree() -> void:
	Input.set_custom_mouse_cursor(null)


## Switches the arrow image (e.g. to cursor_light.png with the light theme).
func set_cursor(path: String) -> void:
	Input.set_custom_mouse_cursor(load(path), Input.CURSOR_ARROW, HOTSPOT)
