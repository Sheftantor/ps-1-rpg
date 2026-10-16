class_name InputCombos
extends Node
## Autoload (ComboInput, class InputCombos): fires two-input bindings ("hold LB, then press X")
## set up on the Key Bindings screen (see InputBindings). Tracks which inputs
## are held; when a combo's second input is pressed while its first is held,
## sends the action as an InputEventAction (so is_action_pressed, held checks
## and Input.get_vector all see it) and swallows the raw press, so an action
## bound to that second input alone doesn't go off too. The action is released
## when either input lets go. Runs through pauses; idle while a binding is
## being captured.

## Set by the Key Bindings screen while it listens for a new binding.
static var capturing: bool = false

## Event ids currently held down.
var _held: Dictionary[String, bool] = {}
## Combos currently firing: [action, first id, second id].
var _active: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.ensure_defaults()


func _input(event: InputEvent) -> void:
	if event is InputEventAction or event is InputEventMouseMotion or event.is_echo():
		return
	if event is InputEventJoypadMotion:
		# Each direction of an axis is its own input.
		var motion := event as InputEventJoypadMotion
		for sign: String in ["+", "-"]:
			var down := motion.axis_value * (1.0 if sign == "+" else -1.0) >= InputBindings.AXIS_PRESS
			_update("axis:%d:%s" % [motion.axis, sign], down, event)
		return
	var id := InputBindings.event_id(event)
	if not id.is_empty():
		_update(id, event.is_pressed(), event)


func _update(id: String, pressed: bool, event: InputEvent) -> void:
	var was_held := _held.has(id)
	if pressed == was_held:
		return
	if pressed:
		_held[id] = true
	else:
		_held.erase(id)
	if capturing:
		return
	if pressed:
		_on_pressed(id, event)
	else:
		_on_released(id)


func _on_pressed(id: String, event: InputEvent) -> void:
	for combo: Array in InputBindings.combos():
		var first: String = combo[2]
		if combo[3] != id or not _held.has(first):
			continue
		var action: StringName = combo[0]
		_active.append([action, first, id])
		# The raw press already pressed any action bound to it alone; undo that.
		for other: StringName in InputMap.get_actions():
			if other != action and InputMap.event_is_action(event, other, true):
				Input.action_release(other)
		_send(action, true)
		get_viewport().set_input_as_handled()
		return


func _on_released(id: String) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var combo: Array = _active[i]
		if combo[1] == id or combo[2] == id:
			_active.remove_at(i)
			_send(combo[0], false)


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
