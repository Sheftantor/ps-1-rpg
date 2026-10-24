extends MonkState
## Hovers facing the player, drifting toward preferred_distance and sideways,
## and charges a volley (Volley) whenever the bolt cooldown allows and the
## player is in sight. Once the player is within close_range and the combo is
## ready he rushes them (Rush). Goes back to Hover when the player is beyond
## lose_range, or out of sight for lose_sight_time.

## Seconds between flips of the sideways drift.
const STRAFE_FLIP_MIN := 1.5
const STRAFE_FLIP_MAX := 3.5
## Sideways drift (fraction of hover_speed).
const STRAFE_SHARE := 0.6
## Distance error (m) that gives full-speed drift in or out.
const DISTANCE_TOLERANCE := 2.0

var _unseen_timer: float = 0.0
var _strafe: float = 1.0
var _strafe_timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_unseen_timer = 0.0
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_strafe_timer = randf_range(STRAFE_FLIP_MIN, STRAFE_FLIP_MAX)
	if msg.get("spotted", false):
		monk.bolt_cooldown = maxf(monk.bolt_cooldown, monk.first_volley_delay)


func physics_update(delta: float) -> void:
	if not monk.has_target() or monk.distance_to_target() > monk.lose_range:
		transition_to(HOVER)
		return
	monk.face_target(delta)
	var distance := monk.distance_to_target()
	if distance <= monk.close_range and monk.combo_ready():
		transition_to(RUSH)
		return
	var in_sight := monk.has_line_of_sight()
	if in_sight:
		_unseen_timer = 0.0
	else:
		_unseen_timer += delta
		if _unseen_timer >= monk.lose_sight_time:
			transition_to(HOVER)
			return
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe = -_strafe
		_strafe_timer = randf_range(STRAFE_FLIP_MIN, STRAFE_FLIP_MAX)
	var toward := monk.direction_to_target()
	var radial := clampf((distance - monk.preferred_distance) / DISTANCE_TOLERANCE, -1.0, 1.0)
	var side := toward.cross(Vector3.UP) * _strafe * STRAFE_SHARE
	monk.move_horizontal((toward * radial + side) * monk.hover_speed, monk.stats.acceleration, delta)
	if in_sight and monk.bolt_cooldown <= 0.0 and distance > monk.close_range:
		transition_to(VOLLEY)
