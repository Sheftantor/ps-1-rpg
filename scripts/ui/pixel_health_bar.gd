@tool
class_name PixelHealthBar
extends Range
## A PS1-menu-style health bar (Final Fantasy VII's party bars): a bevelled grey
## frame round a recessed groove, the fill a glossy tube with a dark band under its
## top edge and a bright highlight a third of the way down. Drawn pixel by pixel,
## so it stays crisp at whole-number scales (the ScreenSpaceBillboard never
## resamples it by a fraction). Pick fill_color and the shading follows. Size it
## like any Control: the frame is FRAME pixels a side and the groove takes the
## rest (10+ rows inside shows every shade; fewer skips some). While any health is
## left at least a sliver shows. The Bar of res://scenes/enemy_health_bar.tscn.

## Base colour of the fill; its lighter and darker rows are worked out from it.
@export var fill_color: Color = Color("e77c7c"):
	set(value):
		fill_color = value
		queue_redraw()

## Frame, outside in: a dark outline, then a grey bevel lit from above (outer
## ring shaded per side, inner ring one light grey). FRAME = its width a side.
const OUTLINE := Color("141418")
const BEVEL_TOP := Color("a8a8ac")
const BEVEL_SIDE := Color("7c7d7d")
const BEVEL_BOTTOM := Color("616161")
const BEVEL_INNER := Color("ababab")
const FRAME := 3
## The groove's left lip and the light it catches on the right.
const LIP := Color("626262")
const RIGHT_LIGHT := Color("9b9b9b")

## The empty groove, top to bottom (the reference bar's 13 rows): a mid-grey top
## edge, a dark shadow line, a rounded ramp up and back down, a light bottom edge.
const TRACK_ROWS: Array[Color] = [
	Color("616161"), Color("181818"), Color("3a3a3a"), Color("5a5a5a"), Color("626262"),
	Color("6b6b6b"), Color("727272"), Color("7b7b7b"), Color("7b7b7b"), Color("7b7b7b"),
	Color("727272"), Color("6d6d6d"), Color("8c8c8c"),
]
## How each of those rows shades fill_color: x = brightness, y = mix toward
## white, z = mix toward that row's groove grey (the tube sinks into the groove
## at the bottom), w = 1 squares the colour first (the deep band under the top).
const FILL_ROWS: Array[Vector4] = [
	Vector4(0.88, 0.0, 0.0, 0.0), Vector4(0.73, 0.0, 0.0, 1.0), Vector4(0.8, 0.0, 0.0, 0.0),
	Vector4(0.93, 0.25, 0.0, 0.0), Vector4(0.93, 0.45, 0.0, 0.0), Vector4(1.0, 0.6, 0.0, 0.0),
	Vector4(0.97, 0.0, 0.0, 0.0), Vector4(1.0, 0.0, 0.0, 0.0), Vector4(0.91, 0.0, 0.0, 0.0),
	Vector4(1.0, 0.0, 0.35, 0.0), Vector4(1.0, 0.0, 0.6, 0.0), Vector4(1.0, 0.0, 0.8, 0.0),
	Vector4(1.0, 0.0, 0.9, 0.0),
]


func _ready() -> void:
	# min/max changes; value changes come through _value_changed.
	changed.connect(queue_redraw)


func _value_changed(_new_value: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := roundi(size.x)
	var h := roundi(size.y)
	if w <= FRAME * 2 or h <= FRAME * 2:
		return
	draw_rect(Rect2(0, 0, w, h), OUTLINE)
	draw_rect(Rect2(1, 1, w - 2, h - 2), BEVEL_SIDE)
	draw_rect(Rect2(1, 1, w - 2, 1), BEVEL_TOP)
	draw_rect(Rect2(1, h - 2, w - 2, 1), BEVEL_BOTTOM)
	draw_rect(Rect2(2, 2, w - 4, h - 4), BEVEL_INNER)
	var inner := w - FRAME * 2
	var rows := h - FRAME * 2
	# The fill starts after the lip column and runs under the right-hand light.
	var span := inner - 1
	var filled := ceili(span * ratio)
	if value > min_value:
		filled = maxi(filled, mini(2, span))
	for row in rows:
		var shade := _shade_index(row, rows)
		var track := TRACK_ROWS[shade]
		var fill := _fill_shade(shade, track)
		var y := FRAME + row
		draw_rect(Rect2(FRAME, y, inner, 1), track)
		if filled > 0:
			draw_rect(Rect2(FRAME + 1, y, filled, 1), fill)
		var edge_row := row == 0 or row == rows - 1
		if not edge_row:
			# Inner shadow down the left: the lip, then a dark line over whatever is
			# there, then a slightly darker first fill column (the tube's curve).
			draw_rect(Rect2(FRAME, y, 1, 1), LIP)
			if span > 1:
				draw_rect(Rect2(FRAME + 1, y, 1, 1), (fill if filled > 0 else track).darkened(0.8))
			if filled > 2:
				draw_rect(Rect2(FRAME + 2, y, 1, 1), fill.darkened(0.12))
		draw_rect(Rect2(FRAME + inner - 1, y, 1, 1), track.lerp(RIGHT_LIGHT, 0.7))


## Which of the 13 reference rows inside row `row` of `rows` shows: the top edge,
## the dark band and the bottom edge stay one pixel each; the rows between stretch
## or squeeze to fit.
func _shade_index(row: int, rows: int) -> int:
	var last := TRACK_ROWS.size() - 1
	if rows < 4:
		return roundi(row * float(last) / maxi(rows - 1, 1))
	if row <= 1:
		return row
	if row == rows - 1:
		return last
	return 2 + floori((row - 1.5) * (last - 2) / (rows - 3))


func _fill_shade(shade: int, track: Color) -> Color:
	var recipe := FILL_ROWS[shade]
	var color := fill_color * fill_color if recipe.w > 0.0 else fill_color
	color = color.darkened(1.0 - recipe.x).lightened(recipe.y).lerp(track, recipe.z)
	color.a = fill_color.a
	return color
