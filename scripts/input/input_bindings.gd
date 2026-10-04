class_name InputBindings
extends RefCounted
## Default keyboard/mouse and gamepad bindings, registered at runtime for any
## action not already defined in Project Settings > Input Map (which takes
## precedence). Gamepad names follow the Xbox layout.

const ALL_DEVICES: int = -1

const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL UP", MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
}
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START",
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}

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
	_bind(&"interact", [_key(KEY_E), _button(JOY_BUTTON_DPAD_DOWN)])
	# Draw the gun and enter the time-stop targeting mode (again to back out).
	_bind(&"gun_mode", [_key(KEY_CTRL), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	# Move the lock between nearby enemies (gun-mode cursor, or melee lock-on). On a
	# gamepad it's a right-stick flick: the camera is locked whenever this applies.
	_bind(&"target_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind(&"target_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP), _axis(JOY_AXIS_RIGHT_X, -1.0)])
	# Gun mode: take a target back off the shot queue.
	_bind(&"gun_undo", [_key(KEY_R), _button(JOY_BUTTON_DPAD_LEFT)])
	# Player stats and gear screen.
	_bind(&"status_menu", [_key(KEY_C), _button(JOY_BUTTON_DPAD_UP)])
	# Inventory screen (the bag).
	_bind(&"inventory", [_key(KEY_I), _button(JOY_BUTTON_DPAD_RIGHT)])

	# Items: use the selected one, or step the selection to the next.
	_bind(&"use_item", [_key(KEY_F), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_bind(&"next_item", [_key(KEY_G), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])

	_bind(&"pause", [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)])

	# Menus. Godot's ui_accept / ui_cancel ship with no gamepad buttons, so menus
	# (focused rows, closing) ignored the pad: give them A and B.
	_add_events(&"ui_accept", [_button(JOY_BUTTON_A)])
	_add_events(&"ui_cancel", [_button(JOY_BUTTON_B)])
	# Loot window: take the row under the cursor (right-click) or with focus (A).
	_bind(&"loot_take", [_mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_A)])
	_bind(&"debug_hurt", [_key(KEY_K), _button(JOY_BUTTON_BACK)])


## Short on-screen name for the first binding of `action` on the given device
## ("LMB", "SHIFT", "X", "RB"...), or "?" if it has none there.
static func label(action: StringName, gamepad: bool) -> String:
	var event := event_for(action, gamepad)
	return event_label(event) if event != null else "?"


## The first event bound to `action` for gamepad or keyboard/mouse, or null.
static func event_for(action: StringName, gamepad: bool) -> InputEvent:
	ensure_defaults()
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad == gamepad:
			return event
	return null


static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code).to_upper()
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get((event as InputEventMouseButton).button_index, "MOUSE")
	if event is InputEventJoypadButton:
		return PAD_BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "PAD")
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y:
				return "L STICK"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				return "R STICK"
	return "?"


static func _bind(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


## Adds events to an action that already exists (e.g. a built-in ui_* one),
## skipping any it already has.
static func _add_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in events:
		if not InputMap.action_has_event(action, event):
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
