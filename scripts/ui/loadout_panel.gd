class_name LoadoutPanel
extends Control
## Bottom-left loadout window in the Windows 95 theme: a raised window
## (WindowPanel) holding one row per entry. Each row is a list row with the
## name (ListRow), led by the item's icon square (an IconSlot, the same size as
## the status screen's). Rows: the melee weapon, the gun, then the carried items
## with counts. The weapon in hand is lit and the other muted (HintLabel); the
## selected item (the one use_item spends, cycled with next_item) gets the
## cursor arrow and the accent bar (ListRowSelected). Colors, fonts and sizes
## come from the theme. Shows at most max_item_rows items, scrolling to keep the selection in
## view. The window grows upward from its bottom-left corner and is only as wide
## as its longest name needs. PlayerHud fills it through set_entries(). While
## drop_handler is set (the loot window is open) it accepts loot dragged onto it.

@export_range(1, 6) var max_item_rows: int = 3
## Overall size of the window, scaled from its bottom-left corner. Keep it at 1
## so the theme's pixel bevels stay crisp.
@export_range(0.5, 1.5) var ui_scale: float = 1.0

## Rows are as tall as an icon slot, so every icon square matches the status screen.
const ROW_HEIGHT := IconSlot.SIZE
## Space inside the window's rim: tight at the sides, roomier top and bottom.
const PADDING_X := 6.0
const PADDING_Y := 12.0
const ROW_GAP := 6.0
## Spacing inside a row: between arrow, icon and bar, and the bar's text margins.
const ROW_SEPARATION := 6.0
const ARROW_WIDTH := 12.0

## Called with the drag data when something is dropped on the window; while
## it's set the window takes drops (PlayerHud.set_loot_drop_handler).
var drop_handler: Callable = Callable():
	set(value):
		drop_handler = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value.is_valid() else Control.MOUSE_FILTER_IGNORE

var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Drops arrive while menus have the game paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	scale = Vector2(ui_scale, ui_scale)
	# Keep the bottom-left corner pinned as the window grows upward.
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))
	pivot_offset = Vector2(0.0, size.y)
	var window := Panel.new()
	window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.theme_type_variation = &"WindowPanel"
	add_child(window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(PADDING_X))
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PADDING_Y))
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
	var names: Array[String] = []
	names.append(melee.display_name if melee != null else "UNARMED")
	names.append(gun.display_name if gun != null else "-")
	_add_row(false, melee.icon if melee != null else null, names[0],
		melee != null and not gun_drawn, false)
	_add_row(false, gun.icon if gun != null else null, names[1],
		gun != null and gun_drawn, false)
	var visible_items := mini(items.size(), max_item_rows)
	var first := clampi(selected - visible_items + 1, 0, maxi(0, items.size() - visible_items))
	for i in range(first, first + visible_items):
		var stack := items[i]
		names.append("%s x%d" % [stack.item.display_name, stack.count])
		_add_row(true, stack.item.icon, names[-1], i == selected, i == selected)
	var rows := 2 + visible_items
	var height := rows * ROW_HEIGHT + (rows - 1) * ROW_GAP + PADDING_Y * 2.0
	offset_top = offset_bottom - height
	offset_right = offset_left + _width_for(names)


## Window width that fits the longest name without clipping.
func _width_for(names: Array[String]) -> float:
	var font := get_theme_font(&"font", &"Label")
	var font_size := get_theme_font_size(&"font_size", &"Label")
	var text_width := 0.0
	for text: String in names:
		text_width = maxf(text_width, font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var bar := text_width + get_theme_stylebox(&"panel", &"ListRowSelected").get_minimum_size().x
	return PADDING_X * 2.0 + ARROW_WIDTH + IconSlot.SIZE + ROW_SEPARATION * 2.0 + ceilf(bar)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return drop_handler.is_valid() and data is Dictionary


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_handler.call(data)


func _add_row(is_item: bool, icon: Texture2D, text: String, active: bool, cursor: bool) -> void:
	var line := HBoxContainer.new()
	line.custom_minimum_size.y = ROW_HEIGHT
	line.add_theme_constant_override(&"separation", int(ROW_SEPARATION))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(line)

	var arrow := _Arrow.new()
	arrow.color = get_theme_color(&"accent", &"Win95")
	arrow.visible_arrow = cursor
	line.add_child(arrow)

	# The icon square, the same slot the status screen uses.
	var slot := IconSlot.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null or is_item:
		slot.show_icon(icon, "", 0, cursor)
	else:
		slot.show_empty()
	line.add_child(slot)

	# Bar: the list row holding the name; the selected item's has the accent bar.
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.theme_type_variation = &"ListRowSelected" if cursor else &"ListRow"
	line.add_child(bar)
	var contents := HBoxContainer.new()
	contents.add_theme_constant_override(&"separation", 8)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(contents)
	var name_label := _label(text, active, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(name_label)


func _label(text: String, active: bool, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	# Plain label font and size (the width maths assumes them); muted when the
	# row is not active.
	label.add_theme_color_override(&"font_color", get_theme_color(&"font_color", &"Label" if active else &"HintLabel"))
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Pixel cursor arrow pointing at the selected row.
class _Arrow extends Control:
	var color := Color.WHITE
	var visible_arrow := false

	func _init() -> void:
		custom_minimum_size = Vector2(ARROW_WIDTH, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if not visible_arrow:
			return
		var mid := size.y * 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(2, mid - 7), Vector2(11, mid), Vector2(2, mid + 7)]), color)
