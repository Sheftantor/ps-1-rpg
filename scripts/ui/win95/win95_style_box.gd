@tool
class_name Win95StyleBox
extends StyleBox
## The Windows 95 look as one StyleBox: a flat face (or a left-to-right
## gradient), a two-tone bevel (raised: light top/left, dark bottom/right;
## sunken: swapped), an optional flat outline, a hard drop shadow, and an
## optional accent bar on the left (the selected list row). StyleBoxFlat can't
## color each side differently, hence this. No rounded corners, no smoothing.
## Colors normally come from the theme builder (Win95Palette).

enum Bevel { NONE, RAISED, SUNKEN }

@export var bevel: Bevel = Bevel.RAISED:
	set(value):
		bevel = value
		emit_changed()
## Bevel thickness (px). The outer pixel uses light_color / dark_color, the
## inner ones a half step towards the face, like classic Windows.
@export var bevel_width: int = 2:
	set(value):
		bevel_width = value
		emit_changed()
## Transparent: no face (a frame only, e.g. the focus outline).
@export var face_color: Color = Color("2a2c31"):
	set(value):
		face_color = value
		emit_changed()
## Opaque: the face is a horizontal gradient from face_color to this.
@export var gradient_end_color: Color = Color(0, 0, 0, 0):
	set(value):
		gradient_end_color = value
		emit_changed()
@export var light_color: Color = Color("44474f"):
	set(value):
		light_color = value
		emit_changed()
@export var dark_color: Color = Color("0d0e10"):
	set(value):
		dark_color = value
		emit_changed()
## Flat outline around the edge (inside the rect); the bevel sits inside it.
@export var outline_color: Color = Color("0d0e10"):
	set(value):
		outline_color = value
		emit_changed()
@export var outline_width: int = 0:
	set(value):
		outline_width = value
		emit_changed()
## Hard drop shadow offset down and right (px); 0 for none.
@export var shadow_color: Color = Color("0d0e10"):
	set(value):
		shadow_color = value
		emit_changed()
@export var shadow_size: int = 0:
	set(value):
		shadow_size = value
		emit_changed()
## Bar down the left edge (the selected list row); 0 for none.
@export var accent_color: Color = Color("fb923c"):
	set(value):
		accent_color = value
		emit_changed()
@export var accent_width: int = 0:
	set(value):
		accent_width = value
		emit_changed()
## Shrinks (positive) or grows (negative) the drawn rect on every side (px),
## e.g. to sit a focus outline outside the bevel.
@export var draw_inset: int = 0:
	set(value):
		draw_inset = value
		emit_changed()

## Dotted rectangle (classic Windows keyboard focus) drawn dotted_inset px
## inside the edge, dots dotted_width px square with equal gaps; 0 for none.
@export var dotted_color: Color = Color("e8e6df"):
	set(value):
		dotted_color = value
		emit_changed()
@export var dotted_width: int = 0:
	set(value):
		dotted_width = value
		emit_changed()
@export var dotted_inset: int = 4:
	set(value):
		dotted_inset = value
		emit_changed()
## Extends the drawn rect upwards (px), past the content: Godot draws an
## embedded Window's title there.
@export var expand_margin_top: int = 0:
	set(value):
		expand_margin_top = value
		emit_changed()


func _draw(canvas_item: RID, rect: Rect2) -> void:
	var r := rect.grow(-draw_inset).grow_side(SIDE_TOP, expand_margin_top)
	if shadow_size > 0:
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(r.position + Vector2(shadow_size, shadow_size), r.size), shadow_color)
	if gradient_end_color.a > 0.0:
		var points := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var colors := PackedColorArray([face_color, gradient_end_color, gradient_end_color, face_color])
		RenderingServer.canvas_item_add_polygon(canvas_item, points, colors)
	elif face_color.a > 0.0:
		RenderingServer.canvas_item_add_rect(canvas_item, r, face_color)

	if bevel != Bevel.NONE:
		var top_left := light_color if bevel == Bevel.RAISED else dark_color
		var bottom_right := dark_color if bevel == Bevel.RAISED else light_color
		var base := face_color if face_color.a > 0.0 else top_left.lerp(bottom_right, 0.5)
		# Outer half of the bevel in the full colors, inner half a step towards
		# the face; inside the outline, if there is one.
		for i in mini(bevel_width, int(minf(r.size.x, r.size.y) * 0.5) - outline_width):
			var t := 0.0 if i < ceili(bevel_width * 0.5) else 0.5
			var ring := r.grow(-(i + outline_width))
			_frame(canvas_item, ring, 1.0, top_left.lerp(base, t), bottom_right.lerp(base, t))

	if outline_width > 0:
		_frame(canvas_item, r, outline_width, outline_color, outline_color)
	if accent_width > 0:
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(r.position, Vector2(accent_width, r.size.y)), accent_color)
	if dotted_width > 0:
		_dotted(canvas_item, r.grow(-dotted_inset), dotted_width, dotted_color)


## A frame `width` px thick just inside rect: top and left in first, bottom
## and right in second (drawn last, so they own the shared corners).
static func _frame(canvas_item: RID, rect: Rect2, width: float, first: Color, second: Color) -> void:
	var w := minf(width, minf(rect.size.x, rect.size.y))
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position, Vector2(rect.size.x, w)), first)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position, Vector2(w, rect.size.y)), first)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position.x, rect.end.y - w, rect.size.x, w), second)
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.end.x - w, rect.position.y, w, rect.size.y), second)


## A dotted frame just inside rect: dots `dot` px square, one dot apart.
static func _dotted(canvas_item: RID, rect: Rect2, dot: int, color: Color) -> void:
	if rect.size.x < dot * 2 or rect.size.y < dot * 2:
		return
	var step := dot * 2
	var x := rect.position.x
	while x <= rect.end.x - dot:
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x, rect.position.y, dot, dot), color)
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x, rect.end.y - dot, dot, dot), color)
		x += step
	var y := rect.position.y + step
	while y <= rect.end.y - dot * 2:
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.position.x, y, dot, dot), color)
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(rect.end.x - dot, y, dot, dot), color)
		y += step
