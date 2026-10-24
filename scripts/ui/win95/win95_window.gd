@tool
class_name Win95Window
extends Container
## A Windows 95 window: raised bevelled frame with a hard drop shadow, a
## gradient title bar (title text, optional tag chip, optional minimize and
## close buttons) and a body. Put your controls straight in as children: they
## stack top to bottom in the body like a VBoxContainer (expand flags work),
## inside the body padding with the body gap between them. All sizes and colors
## come from the theme (types WindowPanel, TitleBar, TitleLabel, TagLabel,
## TitleButton and the Win95Window constants). Scene: res://scenes/win95_window.tscn.

signal close_requested
signal minimize_requested

@export var title: String = "Window":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value
## Text of the small chip on the right of the title bar; empty hides it.
@export var tag: String = "":
	set(value):
		tag = value
		if _tag_label != null:
			_tag_label.text = value
			_tag_label.visible = value != ""
@export var show_minimize: bool = false:
	set(value):
		show_minimize = value
		if _minimize_button != null:
			_minimize_button.visible = value
@export var show_close: bool = false:
	set(value):
		show_close = value
		if _close_button != null:
			_close_button.visible = value
## Off: just the bevelled frame and body (e.g. a tooltip-like panel).
@export var show_title_bar: bool = true:
	set(value):
		show_title_bar = value
		if _title_bar != null:
			_title_bar.visible = value and not _collapsed
		queue_sort()
		update_minimum_size()
## The close button also hides the window (it always emits close_requested).
@export var hide_on_close: bool = false
## Draw nothing (no frame, no title bar, no clicks caught) while every child is
## hidden, e.g. when a script shows and hides the content rather than the window.
@export var collapse_when_empty: bool = false:
	set(value):
		collapse_when_empty = value
		queue_sort()
		update_minimum_size()

var _title_bar: PanelContainer = null
var _title_label: Label = null
var _tag_label: Label = null
var _minimize_button: Button = null
var _close_button: Button = null
var _collapsed: bool = false


func _init() -> void:
	theme_type_variation = &"WindowPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar = PanelContainer.new()
	_title_bar.name = &"TitleBar"
	_title_bar.theme_type_variation = &"TitleBar"
	_title_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.name = &"Row"
	_title_bar.add_child(row)
	_title_label = Label.new()
	_title_label.name = &"Title"
	_title_label.theme_type_variation = &"TitleLabel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title_label)
	_tag_label = Label.new()
	_tag_label.name = &"Tag"
	_tag_label.theme_type_variation = &"TagLabel"
	_tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_tag_label)
	_minimize_button = _title_button(&"MinimizeButton", "_", minimize_requested.emit)
	row.add_child(_minimize_button)
	_close_button = _title_button(&"CloseButton", "X", _on_close_pressed)
	row.add_child(_close_button)
	add_child(_title_bar, false, Node.INTERNAL_MODE_FRONT)
	# Apply the exported values now that the nodes exist.
	title = title
	tag = tag
	show_minimize = show_minimize
	show_close = show_close
	show_title_bar = show_title_bar


## The window's controls (its children), for scripts that prefer to ask.
func get_body_children() -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in get_children():
		if child is Control:
			out.append(child)
	return out


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			var w := get_theme_constant(&"title_button_width", &"Win95Window")
			var h := get_theme_constant(&"title_button_height", &"Win95Window")
			for button: Button in [_minimize_button, _close_button]:
				button.custom_minimum_size = Vector2(w, h)
			_apply_glyph(_minimize_button, &"minimize", "_")
			_apply_glyph(_close_button, &"close", "X")
			(_title_bar.get_child(0) as HBoxContainer).add_theme_constant_override(
					&"separation", get_theme_constant(&"title_button_separation", &"Win95Window"))
			update_minimum_size()
			queue_sort()
		NOTIFICATION_SORT_CHILDREN:
			_sort()
		NOTIFICATION_DRAW:
			if not _collapsed:
				draw_style_box(_panel(), Rect2(Vector2.ZERO, size))


func _get_minimum_size() -> Vector2:
	if _is_empty_collapsed():
		return Vector2.ZERO
	var panel := _panel()
	var padding := get_theme_constant(&"body_padding", &"Win95Window")
	var gap := get_theme_constant(&"body_separation", &"Win95Window")
	var body := Vector2.ZERO
	var count := 0
	for child: Control in _layout_children():
		var child_min := child.get_combined_minimum_size()
		body.x = maxf(body.x, child_min.x)
		body.y += child_min.y
		count += 1
	body.y += gap * maxi(0, count - 1)
	var result := body + Vector2(padding, padding) * 2.0
	if show_title_bar:
		var bar := _title_bar.get_combined_minimum_size()
		result.x = maxf(result.x, bar.x)
		result.y += maxf(bar.y, get_theme_constant(&"title_height", &"Win95Window"))
	return result + panel.get_minimum_size()


func _sort() -> void:
	var collapsed := _is_empty_collapsed()
	if collapsed != _collapsed:
		_collapsed = collapsed
		_title_bar.visible = show_title_bar and not collapsed
		mouse_filter = Control.MOUSE_FILTER_IGNORE if collapsed else Control.MOUSE_FILTER_STOP
		queue_redraw()
		update_minimum_size()
	if collapsed:
		return
	var panel := _panel()
	var inner := Rect2(Vector2(panel.get_margin(SIDE_LEFT), panel.get_margin(SIDE_TOP)),
			size - panel.get_minimum_size())
	if show_title_bar:
		var height := maxf(_title_bar.get_combined_minimum_size().y, get_theme_constant(&"title_height", &"Win95Window"))
		fit_child_in_rect(_title_bar, Rect2(inner.position, Vector2(inner.size.x, height)))
		inner.position.y += height
		inner.size.y -= height
	var padding := get_theme_constant(&"body_padding", &"Win95Window")
	var gap := get_theme_constant(&"body_separation", &"Win95Window")
	var body := inner.grow(-padding)
	var children := _layout_children()
	if children.is_empty():
		return
	# Like a VBoxContainer: everyone gets their minimum height, and what's left
	# is shared by the children that expand vertically (by stretch ratio).
	var used := gap * (children.size() - 1)
	var stretch := 0.0
	for child: Control in children:
		used += child.get_combined_minimum_size().y
		if child.size_flags_vertical & Control.SIZE_EXPAND:
			stretch += child.size_flags_stretch_ratio
	var extra := maxf(0.0, body.size.y - used)
	var y := body.position.y
	for child: Control in children:
		var height := child.get_combined_minimum_size().y
		if stretch > 0.0 and child.size_flags_vertical & Control.SIZE_EXPAND:
			height += extra * child.size_flags_stretch_ratio / stretch
		fit_child_in_rect(child, Rect2(body.position.x, y, body.size.x, height))
		y += height + gap


func _layout_children() -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in get_children():
		var control := child as Control
		if control != null and control.visible and not control.top_level:
			out.append(control)
	return out


func _is_empty_collapsed() -> bool:
	return collapse_when_empty and _layout_children().is_empty()


func _panel() -> StyleBox:
	return get_theme_stylebox(&"panel", &"WindowPanel")


func _title_button(button_name: StringName, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.theme_type_variation = &"TitleButton"
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	return button


## The theme's pixel glyph for a title button, or its text if there is none.
func _apply_glyph(button: Button, icon_name: StringName, fallback: String) -> void:
	if has_theme_icon(icon_name, &"Win95Window"):
		button.icon = get_theme_icon(icon_name, &"Win95Window")
		button.text = ""
	else:
		button.icon = null
		button.text = fallback


func _on_close_pressed() -> void:
	close_requested.emit()
	if hide_on_close:
		hide()
