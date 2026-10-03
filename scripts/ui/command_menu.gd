class_name CommandMenu
extends Control
## Bottom-right quick-reference command list: a rounded dark panel (navy to
## black gradient, chunky stepped corners) with one row per entry, icon on the
## left and name on the right. Row 0 is the weapon in hand; the rest are the
## carried items with their counts. The selected item (the one use_item spends,
## cycled with next_item) gets the cursor: an arrow and a bright frame. Shows at
## most max_rows rows, scrolling the item list to keep the selection in view.
## PlayerHud fills it through set_entries().

const FONT: Font = preload("res://Import/MGS1 HUD.ttf")
const ITEM_PLACEHOLDER: Texture2D = preload("res://textures/ui/icons/placeholder_item.png")

## Weapon row plus up to max_rows - 1 item rows.
@export_range(2, 5) var max_rows: int = 5
@export var row_height: float = 40.0
@export var font_size: int = 40
@export var top_color: Color = Color(0.13, 0.17, 0.3, 0.85)
@export var bottom_color: Color = Color(0.02, 0.03, 0.07, 0.85)
@export var border_color: Color = Color(0.55, 0.6, 0.72, 0.9)
@export var text_color: Color = Color(0.86, 0.87, 0.9)
@export var weapon_text_color: Color = Color(0.95, 0.82, 0.5)
@export var cursor_color: Color = Color(1.0, 0.9, 0.55)
## Corner rounding (pixels); drawn without anti-aliasing so corners step like pixel art.
@export var corner_radius: int = 10

var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The gradient child is clipped to the rounded panel shape.
	back.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	back.add_theme_stylebox_override(&"panel", _box(Color.WHITE, 0))
	add_child(back)
	var gradient := Gradient.new()
	gradient.set_color(0, top_color)
	gradient.set_color(1, bottom_color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var fill := TextureRect.new()
	fill.texture = texture
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)

	var border := Panel.new()
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_box := _box(border_color, 2)
	border_box.draw_center = false
	border_box.border_color = border_color
	border.add_theme_stylebox_override(&"panel", border_box)
	add_child(border)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 2)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_rows)


## weapon_icon/weapon_name: the weapon in hand. items: the inventory;
## selected: index into it of the item under the cursor.
func set_entries(weapon_icon: Texture2D, weapon_name: String, items: Array[ItemStack], selected: int) -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_add_row(weapon_icon, weapon_name, weapon_text_color, false)
	# Scroll the item rows so the selection stays visible.
	var visible_items := mini(items.size(), max_rows - 1)
	var first := clampi(selected - visible_items + 1, 0, maxi(0, items.size() - visible_items))
	for i in range(first, first + visible_items):
		var stack := items[i]
		_add_row(stack.item.icon, "%s x%d" % [stack.item.display_name, stack.count], text_color, i == selected)
	# Fit the panel to its rows, growing upward from the bottom-right corner.
	var height := (1 + visible_items) * (row_height + 2.0) - 2.0 + 16.0
	offset_top = offset_bottom - height


func _add_row(icon: Texture2D, text: String, color: Color, selected: bool) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = row_height
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(Color(0.4, 0.45, 0.6, 0.35) if selected else Color.TRANSPARENT, 2 if selected else 0)
	style.border_color = cursor_color
	style.set_corner_radius_all(maxi(2, corner_radius / 2))
	style.content_margin_left = 4
	style.content_margin_right = 8
	row.add_theme_stylebox_override(&"panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var arrow := _Arrow.new()
	arrow.color = cursor_color
	arrow.visible_arrow = selected
	line.add_child(arrow)
	var picture := TextureRect.new()
	picture.texture = icon if icon != null else ITEM_PLACEHOLDER
	picture.custom_minimum_size = Vector2(row_height - 8.0, row_height - 8.0)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(picture)
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 6)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(label)
	_rows.add_child(row)


func _box(color: Color, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(border)
	box.set_corner_radius_all(corner_radius)
	# Few segments and no smoothing: stepped, pixel-art corners.
	box.corner_detail = 3
	box.anti_aliasing = false
	return box


## Pixel cursor arrow pointing at the selected row.
class _Arrow extends Control:
	var color := Color.WHITE
	var visible_arrow := false

	func _init() -> void:
		custom_minimum_size = Vector2(12, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not visible_arrow:
			return
		var mid := size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(2, mid - 6), Vector2(10, mid), Vector2(2, mid + 6)]), color)
