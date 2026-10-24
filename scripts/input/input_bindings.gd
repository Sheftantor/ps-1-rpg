class_name InputBindings
extends RefCounted
## Default keyboard/mouse and gamepad bindings, registered at runtime for any
## action not already defined in Project Settings > Input Map (which takes
## precedence), plus the player's own rebinds from the Key Bindings screen,
## saved to SAVE_PATH. Gamepad names follow the Xbox layout.
##
## A binding is a chord of one or two inputs, written as ids (event_id):
## ["key:4194325"] is one key, ["joy:9", "joy:2"] is "hold LB, then press X".
## Single inputs live in the InputMap as usual. Two-input combos are kept out
## of it (the second input alone would set the action off) and fired by the
## ComboInput autoload (InputCombos) instead, which sends the action as an InputEventAction
## when the second input is pressed while the first is held, so game code
## reads both kinds the same way (is_action_pressed, Input.get_vector...).

const ALL_DEVICES: int = -1
const SAVE_PATH := "user://input_bindings.cfg"
## How far a stick or trigger must go to count as pressed (and to be captured).
const AXIS_PRESS: float = 0.5

const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_WHEEL_UP: "WHEEL UP", MOUSE_BUTTON_WHEEL_DOWN: "WHEEL DOWN",
	MOUSE_BUTTON_WHEEL_LEFT: "WHEEL LEFT", MOUSE_BUTTON_WHEEL_RIGHT: "WHEEL RIGHT",
	MOUSE_BUTTON_XBUTTON1: "MOUSE 4", MOUSE_BUTTON_XBUTTON2: "MOUSE 5",
}
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START", JOY_BUTTON_GUIDE: "GUIDE",
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
	JOY_BUTTON_MISC1: "SHARE", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
	JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2", JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4",
}

## Actions the Key Bindings screen lets the player change.
const REBINDABLE: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"dodge", &"block",
	&"attack_light", &"attack_heavy", &"lock_on", &"target_prev", &"target_next",
	&"use_item", &"next_item", &"gun_mode", &"gun_undo",
	&"interact", &"status_menu", &"inventory", &"pause", &"debug_hurt", &"debug_level_up",
]
## Rebindable actions that only take one input (movement is held, not pressed).
const SINGLE_ONLY: Array[StringName] = [&"move_forward", &"move_back", &"move_left", &"move_right"]


static var _initialized: bool = false
## action -> {gamepad (bool) -> PackedStringArray of two ids}: the combos.
static var _combos: Dictionary = {}
## action -> {gamepad (bool) -> PackedStringArray}: what the player rebound
## (saved); everything else is on its default.
static var _overrides: Dictionary = {}
static var _emitter: Object = null


static func ensure_defaults() -> void:
	if _initialized:
		return
	_initialized = true
	_emitter = _ChangeEmitter.new()
	_register_defaults()
	# Menus. Godot's ui_accept / ui_cancel ship with no gamepad buttons, so menus
	# (focused rows, closing) ignored the pad: give them A and B.
	_add_events(&"ui_accept", [_button(JOY_BUTTON_A)])
	_add_events(&"ui_cancel", [_button(JOY_BUTTON_B)])
	_load()


static func _defaults() -> Dictionary:
	return {
		&"move_forward": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		&"move_back": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		&"move_left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1.0)],
		&"move_right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1.0)],
		&"look_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		&"look_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		&"look_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		&"look_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		&"jump": [_key(KEY_SPACE), _button(JOY_BUTTON_A)],
		&"dodge": [_key(KEY_SHIFT), _button(JOY_BUTTON_B)],
		&"attack_light": [_mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_X)],
		&"attack_heavy": [_mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_Y)],
		&"block": [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)],
		&"lock_on": [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE), _button(JOY_BUTTON_RIGHT_STICK)],
		&"interact": [_key(KEY_E), _button(JOY_BUTTON_DPAD_DOWN)],
		# Draw the gun and enter the time-stop targeting mode (again to back out).
		&"gun_mode": [_key(KEY_CTRL), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		# Move the lock between nearby enemies (gun-mode cursor, or melee lock-on). On a
		# gamepad it's a right-stick flick: the camera is locked whenever this applies.
		&"target_next": [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _axis(JOY_AXIS_RIGHT_X, 1.0)],
		&"target_prev": [_mouse(MOUSE_BUTTON_WHEEL_UP), _axis(JOY_AXIS_RIGHT_X, -1.0)],
		# Gun mode: take a target back off the shot queue.
		&"gun_undo": [_key(KEY_R), _button(JOY_BUTTON_DPAD_LEFT)],
		# Player stats and gear screen.
		&"status_menu": [_key(KEY_C), _button(JOY_BUTTON_DPAD_UP)],
		# Inventory screen (the bag).
		&"inventory": [_key(KEY_I), _button(JOY_BUTTON_DPAD_RIGHT)],
		# Items: use the selected one, or step the selection to the next.
		&"use_item": [_key(KEY_F), _button(JOY_BUTTON_RIGHT_SHOULDER)],
		&"next_item": [_key(KEY_G), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		&"pause": [_key(KEY_ESCAPE), _button(JOY_BUTTON_START)],
		# Loot window: take the row under the cursor (right-click) or with focus (A).
		&"loot_take": [_mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_A)],
		&"debug_hurt": [_key(KEY_K), _button(JOY_BUTTON_BACK)],
		&"debug_level_up": [_key(KEY_L)],
	}


static func _register_defaults() -> void:
	var defaults := _defaults()
	for action: StringName in defaults:
		_bind(action, defaults[action])


## Calls `callable` after any binding changes, so on-screen icons can redraw.
static func connect_changed(callable: Callable) -> void:
	ensure_defaults()
	if not _emitter.is_connected(&"bindings_changed", callable):
		_emitter.connect(&"bindings_changed", callable)


static func disconnect_changed(callable: Callable) -> void:
	if _emitter != null and _emitter.is_connected(&"bindings_changed", callable):
		_emitter.disconnect(&"bindings_changed", callable)


# --- Reading bindings ------------------------------------------------------------

## The chord (one or two event ids) bound to `action` on gamepad or
## keyboard/mouse, or empty if it has none there. With several single bindings
## (lock-on's Tab and middle mouse) this is the first.
static func chord_for(action: StringName, gamepad: bool) -> PackedStringArray:
	ensure_defaults()
	if _combos.has(action) and (_combos[action] as Dictionary).has(gamepad):
		return _combos[action][gamepad]
	var event := _first_map_event(action, gamepad)
	return PackedStringArray([event_id(event)]) if event != null else PackedStringArray()


## Short on-screen name for the binding of `action` on the given device
## ("LMB", "SHIFT", "LB + X"...), or "?" if it has none there.
static func label(action: StringName, gamepad: bool) -> String:
	var chord := chord_for(action, gamepad)
	if chord.is_empty():
		return "?"
	var names := PackedStringArray()
	for id in chord:
		names.append(event_label(event_from_id(id)))
	return " + ".join(names)


## The event that sets `action` off on the given device (a combo's second
## input), or null.
static func event_for(action: StringName, gamepad: bool) -> InputEvent:
	var chord := chord_for(action, gamepad)
	return event_from_id(chord[chord.size() - 1]) if not chord.is_empty() else null


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


## Every combo as [action, gamepad, first id, second id] (for ComboInput).
static func combos() -> Array:
	ensure_defaults()
	var out: Array = []
	for action: StringName in _combos:
		for gamepad: bool in _combos[action]:
			var chord: PackedStringArray = _combos[action][gamepad]
			out.append([action, gamepad, chord[0], chord[1]])
	return out


# --- Event ids -------------------------------------------------------------------

## A short string naming a physical input, the same for its press and release:
## "key:<physical keycode>", "mouse:<button>", "joy:<button>",
## "axis:<axis>:+" / "axis:<axis>:-". Empty for anything else.
static func event_id(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "key:%d" % code if code != KEY_NONE else ""
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "axis:%d:%s" % [motion.axis, "-" if motion.axis_value < 0.0 else "+"]
	return ""


static func event_from_id(id: String) -> InputEvent:
	var parts := id.split(":")
	if parts.size() < 2:
		return null
	var value := parts[1].to_int()
	match parts[0]:
		"key":
			return _key(value as Key)
		"mouse":
			return _mouse(value as MouseButton)
		"joy":
			return _button(value as JoyButton)
		"axis":
			return _axis(value as JoyAxis, -1.0 if parts.size() > 2 and parts[2] == "-" else 1.0)
	return null


static func is_gamepad_id(id: String) -> bool:
	return id.begins_with("joy:") or id.begins_with("axis:")


# --- Rebinding -------------------------------------------------------------------

## Binds `action` on one device to `chord` (one or two ids), replacing what it
## had there, and saves. Another rebindable action already on exactly that
## chord takes this one's old binding instead (a swap); its name is returned,
## or &"" if nothing had to move.
static func rebind(action: StringName, gamepad: bool, chord: PackedStringArray) -> StringName:
	ensure_defaults()
	var old := chord_for(action, gamepad)
	var swapped := &""
	for other: StringName in REBINDABLE:
		if other != action and chord_for(other, gamepad) == chord:
			# Movement can't take a combo; leave it and let them share.
			if old.size() > 1 and other in SINGLE_ONLY:
				continue
			_set_chord(other, gamepad, old)
			swapped = other
	_set_chord(action, gamepad, chord)
	_save()
	_emitter.emit_signal(&"bindings_changed")
	return swapped


## Every rebindable action back to its default, and the save file cleared.
static func reset_to_defaults() -> void:
	ensure_defaults()
	var defaults := _defaults()
	for action: StringName in REBINDABLE:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		_bind(action, defaults[action])
	_combos.clear()
	_overrides.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_emitter.emit_signal(&"bindings_changed")


static func _set_chord(action: StringName, gamepad: bool, chord: PackedStringArray) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if _is_pad(event) == gamepad:
			InputMap.action_erase_event(action, event)
	if _combos.has(action):
		(_combos[action] as Dictionary).erase(gamepad)
	if chord.size() == 1:
		var event := event_from_id(chord[0])
		if event != null:
			InputMap.action_add_event(action, event)
	elif chord.size() >= 2:
		if not _combos.has(action):
			_combos[action] = {}
		_combos[action][gamepad] = PackedStringArray([chord[0], chord[1]])
	if not _overrides.has(action):
		_overrides[action] = {}
	_overrides[action][gamepad] = chord


static func _save() -> void:
	var file := ConfigFile.new()
	for action: StringName in _overrides:
		for gamepad: bool in _overrides[action]:
			file.set_value("bindings", "%s/%s" % [action, "pad" if gamepad else "kbm"], _overrides[action][gamepad])
	file.save(SAVE_PATH)


static func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	for key: String in file.get_section_keys("bindings"):
		var parts := key.split("/")
		var action := StringName(parts[0])
		if parts.size() != 2 or action not in REBINDABLE:
			continue
		var chord := PackedStringArray(file.get_value("bindings", key, PackedStringArray()))
		_set_chord(action, parts[1] == "pad", chord)


static func _first_map_event(action: StringName, gamepad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if _is_pad(event) == gamepad:
			return event
	return null


static func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _bind(action: StringName, events: Array) -> void:
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


## Holds the `changed` signal (a static class can't declare one itself).
class _ChangeEmitter:
	extends Object
	signal bindings_changed
