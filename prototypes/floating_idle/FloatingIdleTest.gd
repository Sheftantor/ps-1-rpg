extends Node3D
## Test bench for FloatingFigure: the figure alone on a neutral background.
## Tab (or 1 / 2) switches the camera between the front view and a 3/4 view.
## F8 opens the idle pose tuner.

enum View { FRONT, THREE_QUARTER }

## View on start (also lets screenshots pick a view without key presses).
@export var start_view: View = View.FRONT
## Point the camera looks at (about chest height on the figure).
@export var focus := Vector3(0.0, 0.56, 0.0)
@export var distance: float = 2.6
## Yaw of the 3/4 view, degrees; positive orbits toward the figure's left (+X).
@export var three_quarter_yaw: float = 45.0
## Camera height above the focus point, metres.
@export var height: float = 0.05

@onready var _camera: Camera3D = $Camera3D

var _view: View


func _ready() -> void:
	_set_view(start_view)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_TAB:
			_set_view(View.THREE_QUARTER if _view == View.FRONT else View.FRONT)
		KEY_1:
			_set_view(View.FRONT)
		KEY_2:
			_set_view(View.THREE_QUARTER)


func _set_view(view: View) -> void:
	_view = view
	var yaw := deg_to_rad(three_quarter_yaw if view == View.THREE_QUARTER else 0.0)
	_camera.position = focus + Vector3(sin(yaw) * distance, height, cos(yaw) * distance)
	_camera.look_at(focus)
