class_name LoadoutPanel
extends Control
## Bottom-left loadout window, styled after the retro RPG UI template
## (res://Import/images (3).jpg): a charcoal rounded window with a light rim and
## corner studs, holding one row per entry. Each row is a short coloured pill tab
## (WPN 1, WPN 2, ITEM) beside a longer bar of the same hue with the name,
## led by the item's icon square (an IconSlot, the same size as the status
## screen's). Rows: the melee weapon, the gun, then the carried items with counts.
## The weapon in hand is lit and the other dimmed; the selected item (the one
## use_item spends, cycled with next_item) gets the cursor arrow and a bright
## rim. Shows at most max_item_rows items, scrolling to keep the selection in
## view. The window grows upward from its bottom-left corner. PlayerHud fills it
## through set_entries().

const FONT: Font = preload("res://resources/ui/hud_font_bold.tres")

@export_range(1, 6) var max_item_rows: int = 3
@export var font_size: int = 28
@export var tab_width: float = 104.0
## Template palette: charcoal window, light grey rim and studs.
@export var window_color: Color = Color(0.1, 0.1, 0.11, 0.92)
@export var rim_color: Color = Color(0.62, 0.64, 0.68, 1.0)
@export var text_color: Color = Color(0.95, 0.95, 0.97)
@export var cursor_color: Color = Color(1.0, 0.92, 0.55)
## Hues for the weapon rows and (cycled) item rows, as in the template's command bars.
@export var melee_color: Color = Color(0.72, 0.1, 0.1)
@export var gun_color: Color = Color(0.1, 0.32, 0.78)
@export var item_colors: Array[Color] = [Color(0.12, 0.55, 0.2), Color(0.62, 0.52, 0.08), Color(0.06, 0.5, 0.5)]
## Brightness of rows that aren't active (the weapon not in hand, unselected items).
@export_range(0.0, 1.0) var inactive_dim: float = 0.55
## Corner rounding (pixels); drawn without anti-aliasing so corners step like pixel art.
@export var corner_radius: int = 10

## Rows are as tall as an icon slot, so every icon square matches the status screen.
const ROW_HEIGHT := IconSlot.SIZE
const PADDING := 12.0
const ROW_GAP := 6.0
const STUD_SIZE := 6.0

var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var window := Panel.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(window_color, corner_radius)
	style.set_border_width_all(2)
	style.border_color = rim_color
	window.add_theme_stylebox_override(&"panel", style)
	add_child(window)
	# Corner studs, like the template's window rivets.
	for corner: Vector2 in [Vector2(1, 0), Vector2(1, 1), Vector2(0, 0)]:
		var stud := ColorRect.new()
		stud.color = rim_color
		stud.custom_minimum_size = Vector2(STUD_SIZE, STUD_SIZE)
		stud.size = Vector2(STUD_SIZE, STUD_SIZE)
		stud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stud.anchor_left = corner.x
		stud.anchor_right = corner.x
		stud.anchor_top = corner.y
		stud.anchor_bottom = corner.y
		var inset := Vector2(8, 8)
		stud.offset_left = -inset.x - STUD_SIZE if corner.x > 0 else inset.x
		stud.offset_top = -inset.y - STUD_SIZE if corner.y > 0 else inset.y
		stud.offset_right = stud.offset_left + STUD_SIZE
		stud.offset_bottom = stud.offset_top + STUD_SIZE
		add_child(stud)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PADDING))
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", int(ROW_GAP))
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_rows)


## melee/gun: the two weapon slots (null = empty). gun_drawn: which one is in
## hand. items: the inventory; selected: index into it of the item under the cursor.
func set_entries(melee: MeleeWeaponData, gun: WeaponData, gun_drawn: bool, items: Array[ItemStack], selected: int) -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_add_row("WPN 1", melee.icon if melee != null else null, melee.display_name if melee != null else "UNARMED",
		melee_color, melee != null and not gun_drawn, false)
	_add_row("WPN 2", gun.icon if gun != null else null, gun.display_name if gun != null else "-",
		gun_color, gun != null and gun_drawn, false)
	var visible_items := mini(items.size(), max_item_rows)
	var first := clampi(selected - visible_items + 1, 0, maxi(0, items.size() - visible_items))
	for i in range(first, first + visible_items):
		var stack := items[i]
		_add_row("ITEM", stack.item.icon, "%s x%d" % [stack.item.display_name, stack.count],
			item_colors[i % item_colors.size()], i == selected, i == selected)
	var rows := 2 + visible_items
	var height := rows * ROW_HEIGHT + (rows - 1) * ROW_GAP + PADDING * 2.0
	offset_top = offset_bottom - height


func _add_row(tab_text: String, icon: Texture2D, text: String, hue: Color, active: bool, cursor: bool) -> void:
	var shade := 1.0 if active else inactive_dim
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = ROW_HEIGHT
	line.add_theme_constant_override(&"separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(line)

	var arrow := _Arrow.new()
	arrow.color = cursor_color
	arrow.visible_arrow = cursor
	line.add_child(arrow)

	# The icon square, the same slot the status screen uses.
	var slot := IconSlot.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null or tab_text == "ITEM":
		slot.show_icon(icon, "", 0, cursor)
	else:
		slot.show_empty()
	slot.modulate = Color.WHITE if active else Color(0.7, 0.7, 0.72)
	line.add_child(slot)

	# Pill tab: the lighter, rounder label on the left of each template command bar.
	var tab := PanelContainer.new()
	tab.custom_minimum_size = Vector2(tab_width, ROW_HEIGHT)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tab_style := _box(hue.lightened(0.25) * Color(shade, shade, shade), int(ROW_HEIGHT * 0.5))
	tab_style.set_border_width_all(2)
	tab_style.border_color = (hue.lightened(0.55) if active else hue.darkened(0.3))
	tab.add_theme_stylebox_override(&"panel", tab_style)
	tab.add_child(_label(tab_text, shade, HORIZONTAL_ALIGNMENT_CENTER))
	line.add_child(tab)

	# Bar: the long, darker field holding the icon and name.
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_style := _box(hue.darkened(0.35) * Color(shade, shade, shade), 6)
	bar_style.set_border_width_all(2)
	bar_style.border_color = cursor_color if cursor else hue.darkened(0.6)
	bar_style.content_margin_left = 10
	bar_style.content_margin_right = 10
	bar.add_theme_stylebox_override(&"panel", bar_style)
	line.add_child(bar)
	var contents := HBoxContainer.new()
	contents.add_theme_constant_override(&"separation", 8)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(contents)
	var name_label := _label(text, shade, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(name_label)


func _label(text: String, shade: float, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_override(&"font", FONT)
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", text_color if shade >= 1.0 else text_color.darkened(0.35))
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 8)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
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
		draw_colored_polygon(PackedVector2Array([Vector2(2, mid - 7), Vector2(11, mid), Vector2(2, mid + 7)]), color)
