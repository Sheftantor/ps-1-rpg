class_name InputBindings
extends RefCounted
## Default keyboard/mouse bindings, registered at runtime for any action not
## already defined in Project Settings > Input Map (which takes precedence).

static var _initialized: bool = false


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	_bind(&"move_forward", [_key(KEY_W)])
	_bind(&"move_back", [_key(KEY_S)])
	_bind(&"move_left", [_key(KEY_A)])
	_bind(&"move_right", [_key(KEY_D)])
	_bind(&"jump", [_key(KEY_SPACE)])
	_bind(&"dash", [_key(KEY_SHIFT)])
	_bind(&"attack_light", [_mouse(MOUSE_BUTTON_LEFT)])
	_bind(&"attack_heavy", [_mouse(MOUSE_BUTTON_RIGHT)])
	_bind(&"lock_on", [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE)])


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
