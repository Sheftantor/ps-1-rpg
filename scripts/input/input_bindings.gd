class_name InputBindings
extends RefCounted
## Default keyboard/mouse and gamepad bindings, registered at runtime for any
## action not already defined in Project Settings > Input Map (which takes
## precedence). Gamepad names follow the Xbox layout.

const ALL_DEVICES: int = -1

static var _initialized: bool = false


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	_bind(&"move_forward", [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind(&"move_back", [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind(&"move_left", [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind(&"move_right", [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind(&"look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind(&"look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind(&"look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind(&"look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_bind(&"jump", [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_bind(&"dodge", [_key(KEY_SHIFT), _button(JOY_BUTTON_B)])
	_bind(&"attack_light", [_mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_X)])
	_bind(&"attack_heavy", [_mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_Y)])
	_bind(&"block", [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_bind(&"lock_on", [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE), _button(JOY_BUTTON_RIGHT_STICK)])

	# Command menu. Hold to open; while it's open the player ignores gameplay
	# input, so sharing keys/buttons with movement and actions is fine.
	_bind(&"command_menu", [_key(KEY_F), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind(&"menu_up", [_key(KEY_UP), _key(KEY_W), _button(JOY_BUTTON_DPAD_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind(&"menu_down", [_key(KEY_DOWN), _key(KEY_S), _button(JOY_BUTTON_DPAD_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind(&"menu_confirm", [_key(KEY_ENTER), _key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_bind(&"menu_cancel", [_key(KEY_BACKSPACE), _button(JOY_BUTTON_B)])

	_bind(&"debug_hurt", [_key(KEY_K), _button(JOY_BUTTON_BACK)])


static func _bind(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(key: Key) -> InputEvent:
	var event := InputEventKey.new()
	event.physical_keycode = key
	return event


static func _mouse(button: MouseButton) -> InputEvent:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


static func _button(button: JoyButton) -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.device = ALL_DEVICES
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, direction: float) -> InputEvent:
	var event := InputEventJoypadMotion.new()
	event.device = ALL_DEVICES
	event.axis = axis
	event.axis_value = direction
	return event
