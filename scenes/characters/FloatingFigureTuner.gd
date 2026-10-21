class_name FloatingFigureTuner
extends CanvasLayer
## F8 live tuning for a FloatingFigure's IdlePose: a Windows 95 window with a part
## picker, a slider per pos_offset / rot_deg axis (plus drift, phase, speed) for
## the picked part, and the whole-figure and limb-drift motion values. Changes
## apply at once. "Print / Save" prints the pose to the output and writes it to
## its .tres (res://resources/idle_pose_default.tres by default).
## (F9 is the Feel panel, Shift+F9 the PS1 effect, F10 the arm orbit panel.)

const TOGGLE_KEY := KEY_F8
const PANEL_SIZE := Vector2(620, 900)
const LABEL_WIDTH := 170.0
## [key, axis (-1 = scalar), min, max, step] for each slider of the picked part.
const PART_SLIDERS := [
	["pos_offset", 0, -0.4, 0.4, 0.001], ["pos_offset", 1, -0.4, 0.4, 0.001], ["pos_offset", 2, -0.4, 0.4, 0.001],
	["rot_deg", 0, -180.0, 180.0, 0.1], ["rot_deg", 1, -180.0, 180.0, 0.1], ["rot_deg", 2, -180.0, 180.0, 0.1],
	["drift", -1, 0.0, 1.0, 0.01], ["phase", -1, 0.0, 1.0, 0.01], ["speed", -1, 0.0, 2.0, 0.01],
]
const AXES := ["x", "y", "z"]

@export var figure_path: NodePath

var _figure: FloatingFigure
var _window: Win95Window
var _picker: OptionButton
var _part_rows: VBoxContainer
var _status: Label


func _ready() -> void:
	layer = 126
	_figure = get_node(figure_path) as FloatingFigure
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_window = Win95Window.new()
	_window.title = "Idle pose (F8)"
	_window.show_close = true
	_window.close_requested.connect(toggle)
	_window.position = Vector2(24, 24)
	_window.size = PANEL_SIZE
	root.add_child(_window)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_SIZE - Vector2(40, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.theme_type_variation = &"FieldScroll"
	_window.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	rows.add_child(_heading("PART"))
	_picker = OptionButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.item_selected.connect(func(_index: int) -> void: _build_part())
	rows.add_child(_picker)
	_part_rows = VBoxContainer.new()
	rows.add_child(_part_rows)
	rows.add_child(_heading("MOTION"))
	var still := CheckBox.new()
	still.text = "Hold pose still"
	still.focus_mode = Control.FOCUS_NONE
	still.toggled.connect(func(on: bool) -> void: _figure.animate = not on)
	rows.add_child(still)
	_build_motion(rows)
	var buttons := HBoxContainer.new()
	_window.add_child(buttons)
	var save := Button.new()
	save.text = "Print / Save to %s" % _figure.pose.resource_path.get_file()
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_save)
	buttons.add_child(save)
	_status = Label.new()
	_status.theme_type_variation = &"HintLabel"
	buttons.add_child(_status)
	_window.visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_window.visible = not _window.visible
	if _window.visible and _picker.item_count == 0:
		for part_name in _figure.get_part_names():
			_picker.add_item(part_name)
		_build_part()


func _build_part() -> void:
	for child in _part_rows.get_children():
		_part_rows.remove_child(child)
		child.queue_free()
	var part := _figure.pose.get_part(_picker.get_item_text(_picker.selected))
	for spec in PART_SLIDERS:
		var key: String = spec[0]
		var axis: int = spec[1]
		var label := key if axis < 0 else "%s.%s" % [key, AXES[axis]]
		var value: float = part[key] if axis < 0 else (part[key] as Vector3)[axis]
		_part_rows.add_child(_slider_row(label, value, spec[2], spec[3], spec[4], func(v: float) -> void:
			if axis < 0:
				part[key] = v
			else:
				var vector: Vector3 = part[key]
				vector[axis] = v
				part[key] = vector))


func _build_motion(rows: VBoxContainer) -> void:
	var pose := _figure.pose
	# Only IdlePose's own float values (parts has its own section above).
	for property in pose.get_property_list():
		if property.type == TYPE_FLOAT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR:
			var key: StringName = property.name
			var hint := String(property.hint_string).split(",")
			rows.add_child(_slider_row(String(key), pose.get(key), float(hint[0]), float(hint[1]), float(hint[2]),
					func(v: float) -> void: pose.set(key, v)))


func _slider_row(text: String, value: float, min_value: float, max_value: float, step: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = text
	name_label.theme_type_variation = &"HintLabel"
	name_label.custom_minimum_size.x = LABEL_WIDTH
	name_label.clip_text = true
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.theme_type_variation = &"MonoLabel"
	value_label.custom_minimum_size.x = 90
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format(value)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		value_label.text = _format(v))
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _save() -> void:
	var pose := _figure.pose
	var lines := PackedStringArray()
	for part_name in pose.parts:
		var part: Dictionary = pose.parts[part_name]
		lines.append('"%s": { pos_offset = %s, rot_deg = %s, drift = %s, phase = %s, speed = %s }' % [
				part_name, part.pos_offset, part.rot_deg, part.drift, part.phase, part.speed])
	print("IdlePose %s\n%s" % [pose.resource_path, "\n".join(lines)])
	var error := ResourceSaver.save(pose, pose.resource_path)
	_status.text = "Saved" if error == OK else "Save failed (%s)" % error_string(error)


static func _heading(text: String) -> Label:
	var heading := Label.new()
	heading.text = text
	heading.theme_type_variation = &"SectionLabel"
	return heading


static func _format(value: float) -> String:
	return ("%.3f" % value).rstrip("0").rstrip(".")
