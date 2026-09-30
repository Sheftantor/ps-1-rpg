@tool
class_name TargetReticle
extends Control
## Placeholder lock-on reticle: a circle with four ticks, drawn in the in-range or
## out-of-range color. PlayerHud centers it on the locked target. Restyle freely:
## change the exports, or hide the drawing (draw_placeholder) and add art as children.

@export var in_range_color: Color = Color(1.0, 0.35, 0.25):
	set(value):
		in_range_color = value
		queue_redraw()
@export var out_of_range_color: Color = Color(0.6, 0.6, 0.6):
	set(value):
		out_of_range_color = value
		queue_redraw()
@export var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()
@export var draw_placeholder: bool = true:
	set(value):
		draw_placeholder = value
		queue_redraw()

var in_range: bool = true:
	set(value):
		if in_range != value:
			in_range = value
			queue_redraw()


func current_color() -> Color:
	return in_range_color if in_range else out_of_range_color


func _draw() -> void:
	if not draw_placeholder:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - line_width
	var color := current_color()
	draw_arc(center, radius, 0.0, TAU, 32, color, line_width)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(center + direction * radius * 0.55, center + direction * (radius + 6.0), color, line_width)
