class_name TargetLinks
extends Control
## Placeholder "web" of connector lines from the player to every valid target in
## gun mode. The cursor target and queued targets are drawn in locked_color.
## PlayerHud feeds it screen positions each frame.

@export var line_color: Color = Color(0.55, 0.85, 1.0, 0.6)
@export var locked_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var line_width: float = 1.5
## Size of the marker drawn where a line meets a target (doubled when queued).
@export var node_size: float = 4.0

var _origin := Vector2.ZERO
var _points := PackedVector2Array()
var _cursor := -1
var _queued := PackedInt32Array()


## `cursor` and `queued` index into `points`.
func set_links(origin: Vector2, points: PackedVector2Array, cursor: int, queued: PackedInt32Array) -> void:
	_origin = origin
	_points = points
	_cursor = cursor
	_queued = queued
	queue_redraw()


func _draw() -> void:
	for i in _points.size():
		var queued := i in _queued
		var color := locked_color if i == _cursor or queued else line_color
		draw_line(_origin, _points[i], color, line_width)
		var size := node_size * (2.0 if queued else 1.0)
		draw_rect(Rect2(_points[i] - Vector2.ONE * size * 0.5, Vector2.ONE * size), color)
