class_name FeelPanel
extends CanvasLayer
## F9 live tuning for the Feel autoload's FeelSettings: a Windows 95 window on top
## of everything with a checkbox, slider or colour picker per value, grouped like
## the Inspector. Changes apply at once. "Save to resource" writes
## res://settings/feel_settings.tres; "Reset" restores the defaults. Doesn't pause
## the game; while open the cursor is free (mouse-look waits), and closed it
## takes no input at all. Sound slots are shown but set in the Inspector.

const TOGGLE_KEY := KEY_F9
const PANEL_SIZE := Vector2(560, 760)
const LABEL_WIDTH := 250.0

var _window: Win95Window
var _rows: VBoxContainer
var _status: Label
var _mouse_was_captured: bool = false


func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_window = Win95Window.new()
	_window.title = "Feel (F9)"
	_window.show_close = true
	_window.close_requested.connect(toggle)
	_window.position = Vector2(24, 140)
	_window.size = PANEL_SIZE
	root.add_child(_window)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_SIZE - Vector2(40, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme_type_variation = &"FieldScroll"
	_window.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	var buttons := HBoxContainer.new()
	_window.add_child(buttons)
	for spec in [["Save to resource", _save], ["Reset", _reset]]:
		var button := Button.new()
		button.text = spec[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(spec[1])
		buttons.add_child(button)
	_status = Label.new()
	_status.theme_type_variation = &"HintLabel"
	buttons.add_child(_status)
	_window.visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	# Shift+F9 is the PS1Renderer's effect toggle.
	if key != null and key.pressed and not key.echo and not key.shift_pressed and key.physical_keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_window.visible = not _window.visible
	if _window.visible:
		_build()
		_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _mouse_was_captured and not GameMenus.any_open() and not LootWindow.is_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var settings: FeelSettings = Feel.settings
	# Only FeelSettings' own values: skip Resource's built-in properties and group.
	var own := false
	for property in settings.get_property_list():
		if property.usage & PROPERTY_USAGE_CATEGORY:
			own = String(property.name).ends_with("feel_settings.gd") or property.name == &"FeelSettings"
			continue
		if not own:
			continue
		if property.usage & PROPERTY_USAGE_GROUP:
			var heading := Label.new()
			heading.text = String(property.name).to_upper()
			heading.theme_type_variation = &"SectionLabel"
			_rows.add_child(heading)
		elif property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR:
			_row(settings, property)


func _row(settings: FeelSettings, property: Dictionary) -> void:
	var key: StringName = property.name
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = String(key)
	name_label.theme_type_variation = &"HintLabel"
	name_label.custom_minimum_size.x = LABEL_WIDTH
	name_label.clip_text = true
	row.add_child(name_label)
	match property.type:
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = settings.get(key)
			check.focus_mode = Control.FOCUS_NONE
			check.toggled.connect(func(on: bool) -> void: settings.set(key, on))
			row.add_child(check)
		TYPE_FLOAT, TYPE_INT:
			var slider := HSlider.new()
			var hint := String(property.hint_string).split(",")
			var is_int: bool = property.type == TYPE_INT
			slider.min_value = float(hint[0]) if hint.size() >= 2 else 0.0
			slider.max_value = float(hint[1]) if hint.size() >= 2 else 10.0
			slider.step = float(hint[2]) if hint.size() >= 3 else (1.0 if is_int else 0.01)
			slider.value = settings.get(key)
			slider.focus_mode = Control.FOCUS_NONE
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var value_label := Label.new()
			value_label.theme_type_variation = &"MonoLabel"
			value_label.custom_minimum_size.x = 90
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.text = _format(slider.value, is_int)
			slider.value_changed.connect(func(value: float) -> void:
				settings.set(key, int(value) if is_int else value)
				value_label.text = _format(value, is_int))
			row.add_child(slider)
			row.add_child(value_label)
		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = settings.get(key)
			picker.custom_minimum_size = Vector2(80, 0)
			picker.focus_mode = Control.FOCUS_NONE
			picker.color_changed.connect(func(color: Color) -> void: settings.set(key, color))
			row.add_child(picker)
		_:
			var value := Label.new()
			var stream: Variant = settings.get(key)
			value.text = (stream as Resource).resource_path.get_file() if stream is Resource else "(empty: set in Inspector)"
			value.theme_type_variation = &"HintLabel"
			row.add_child(value)
	_rows.add_child(row)


static func _format(value: float, is_int: bool) -> String:
	return str(int(value)) if is_int else ("%.3f" % value).rstrip("0").rstrip(".")


func _save() -> void:
	var err := Feel.save_settings()
	_status.text = "Saved." if err == OK else "Save failed (%s)" % error_string(err)


func _reset() -> void:
	Feel.reset_settings()
	_build()
	_status.text = "Defaults restored (not saved)."
