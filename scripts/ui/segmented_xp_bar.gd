@tool
class_name SegmentedXpBar
extends Control
## The XP bar along the bottom of the screen, World of Warcraft style: a thin
## full-width bar split into `segments` bubbles, filling with purple as XP comes
## in, with "LV 2   XP 270/900   30%" centred on it (the Text child Label).
## The fill never jumps: it grows toward the real value at fill_speed, and on a
## level up runs to the end, empties and carries on from the start. Drawn with
## rounded StyleBoxFlats (no textures), unsmoothed so the corners stay pixelly.
## PlayerHud.set_xp() calls set_progress().

@export_range(1, 40) var segments: int = 20:
	set(value):
		segments = value
		queue_redraw()
## Share of the bar the fill covers per second while catching up.
@export var fill_speed: float = 0.8
## Roundness of the bar's ends (pixels); the fill and its inner edge follow it.
@export_range(0, 20) var corner_radius: int = 8:
	set(value):
		corner_radius = value
		queue_redraw()

@export_group("Colors")
## The border round the bar, the same grey as the dividers.
@export var outline_color: Color = Color(0.52, 0.53, 0.57, 1.0)
@export var empty_color: Color = Color(0.13, 0.15, 0.24, 0.85)
@export var fill_color: Color = Color(0.45, 0.13, 0.72, 1.0)
## Brighter band along the top of the fill.
@export var fill_shine_color: Color = Color(0.66, 0.36, 0.95, 1.0)
## The lines between segments.
@export var divider_color: Color = Color(0.52, 0.53, 0.57, 1.0)
## Thickness (pixels) of the dividers and the border.
@export_range(1, 6) var line_width: int = 3:
	set(value):
		line_width = value
		queue_redraw()

## The fill shown now and where it's heading (0..1), plus level-ups still to run
## through (each fills the bar to the end, then starts again from empty).
var _shown: float = 0.0
var _target: float = 0.0
var _wraps: int = 0
var _level: int = -1

@onready var _text: Label = get_node_or_null(^"Text")


## level, xp into it and xp needed for the next (0 = max level).
func set_progress(level: int, xp: int, needed: int) -> void:
	var ratio := clampf(float(xp) / needed, 0.0, 1.0) if needed > 0 else 1.0
	if _level < 0:
		# First update (spawn, load): show it as it is.
		_shown = ratio
	elif level > _level:
		_wraps += level - _level
	_level = level
	_target = ratio
	if _text != null:
		_text.text = "LV %d   XP %d/%d   %d%%" % [level, xp, needed, roundi(ratio * 100.0)] if needed > 0 \
				else "LV %d   MAX" % level
	queue_redraw()


func _process(delta: float) -> void:
	var goal := 1.0 if _wraps > 0 else _target
	if is_equal_approx(_shown, goal) and _wraps == 0:
		return
	_shown = move_toward(_shown, goal, fill_speed * delta)
	if _wraps > 0 and _shown >= 1.0:
		_wraps -= 1
		_shown = 0.0
	queue_redraw()


func _draw() -> void:
	var w := roundf(size.x)
	var h := roundf(size.y)
	if w < 4.0 or h < 4.0:
		return
	draw_style_box(_box(outline_color, corner_radius), Rect2(0, 0, w, h))
	var inner := Rect2(Vector2.ONE * line_width, Vector2(w, h) - Vector2.ONE * line_width * 2)
	var inner_radius := maxi(corner_radius - line_width, 0)
	draw_style_box(_box(empty_color, inner_radius), inner)
	var filled := roundf(inner.size.x * _shown)
	if filled > 0.0:
		var fill_rect := Rect2(inner.position, Vector2(filled, inner.size.y))
		draw_style_box(_box(fill_color, inner_radius), fill_rect)
		# The shine: the top of the fill, rounded only along its top edge.
		var shine := maxf(1.0, roundf(inner.size.y * 0.3))
		var top := _box(fill_shine_color, inner_radius)
		top.corner_radius_bottom_left = 0
		top.corner_radius_bottom_right = 0
		draw_style_box(top, Rect2(fill_rect.position, Vector2(filled, shine)))
	for i in range(1, segments):
		var x := roundf(inner.position.x + inner.size.x * i / segments)
		draw_rect(Rect2(x - floorf(line_width * 0.5), inner.position.y, line_width, inner.size.y), divider_color)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	return box
