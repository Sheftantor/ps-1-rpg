class_name ActiveDevice
extends Node
## Autoload (InputDevice, class ActiveDevice): which device the player is on
## right now, keyboard / mouse or controller, switching the moment the other one
## is used, in menus, the start screen and in game alike. Prompts and key icons
## follow it (InputIcon.follow_device, the HUD, the loot window and the gear
## screens). While on the controller the mouse cursor is hidden wherever it would
## show; moving the mouse or pressing a key or mouse button brings it back.
##
## Reads every event from the window before the game sees it, so inputs another
## node swallows (combos, menus) still count. Runs through pauses.

## A stick or trigger counts as controller use past this (drift stays under it).
const AXIS_THRESHOLD := 0.5
## Mouse travel (pixels) that switches back to keyboard / mouse, so a bumped
## desk doesn't. Travel fades at MOUSE_TRAVEL_DECAY pixels per second.
const MOUSE_TRAVEL := 16.0
const MOUSE_TRAVEL_DECAY := 60.0

## True while the controller is the device in use.
static var using_gamepad: bool = false
static var _emitter: _ChangeEmitter = null

var _mouse_travel: float = 0.0


## Calls `callable(gamepad: bool)` whenever the player switches device.
static func connect_changed(callable: Callable) -> void:
	if _emitter == null:
		_emitter = _ChangeEmitter.new()
	if not _emitter.device_changed.is_connected(callable):
		_emitter.device_changed.connect(callable)


static func disconnect_changed(callable: Callable) -> void:
	if _emitter != null and _emitter.device_changed.is_connected(callable):
		_emitter.device_changed.disconnect(callable)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.window_input.connect(_on_window_input)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(delta: float) -> void:
	_mouse_travel = maxf(_mouse_travel - MOUSE_TRAVEL_DECAY * delta, 0.0)
	_apply_cursor()


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.is_pressed():
			_set_gamepad(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= AXIS_THRESHOLD:
			_set_gamepad(true)
	elif event is InputEventMouseMotion:
		if using_gamepad:
			_mouse_travel += (event as InputEventMouseMotion).relative.length()
			if _mouse_travel >= MOUSE_TRAVEL:
				_set_gamepad(false)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo():
			_set_gamepad(false)


## Unplugging the controller in use hands back to keyboard / mouse.
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected and using_gamepad and Input.get_connected_joypads().is_empty():
		_set_gamepad(false)


func _set_gamepad(gamepad: bool) -> void:
	_mouse_travel = 0.0
	if gamepad == using_gamepad:
		return
	using_gamepad = gamepad
	_apply_cursor()
	if _emitter != null:
		_emitter.device_changed.emit(gamepad)


## Hides a free cursor on the controller and shows it again on the mouse. A
## captured mouse (mouse-look in game) is left alone.
func _apply_cursor() -> void:
	if using_gamepad and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	elif not using_gamepad and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Holds the change signal (a static class can't declare one itself).
class _ChangeEmitter:
	extends Object
	signal device_changed(gamepad: bool)
