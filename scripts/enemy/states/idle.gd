extends EnemyState
## Shambles between random points in its patrol area (Enemy.patrol_area around
## where it spawned) until the player comes within detection range. Passive
## enemies and a zero-size area just stand.

## Patrol legs shorter than this are re-rolled so it doesn't shuffle in place (m).
const MIN_LEG_LENGTH: float = 1.0
## Close enough to the patrol point to stop (m).
const ARRIVE_DISTANCE: float = 0.3
## Gives up on a point it can't reach (blocked by a wall) after this long (s).
const LEG_TIMEOUT: float = 8.0

var _point: Vector3 = Vector3.ZERO
var _pause_timer: float = 0.0
var _leg_timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	enemy.break_chain()
	_pick_point()
	_pause_timer = randf_range(0.0, enemy.stats.patrol_pause_max)


func physics_update(delta: float) -> void:
	var stats := enemy.stats
	if not stats.passive and enemy.distance_to_target() <= stats.detection_radius:
		transition_to(AWARE)
		return
	if stats.passive or enemy.patrol_area == Vector2.ZERO or _pause_timer > 0.0:
		_pause_timer -= delta
		enemy.move_horizontal(Vector3.ZERO, stats.acceleration, delta)
		return

	var offset := _point - enemy.global_position
	offset.y = 0.0
	_leg_timer -= delta
	if offset.length() <= ARRIVE_DISTANCE or _leg_timer <= 0.0:
		_pause_timer = randf_range(stats.patrol_pause_min, stats.patrol_pause_max)
		_pick_point()
		return
	var direction := offset.normalized()
	enemy.move_horizontal(direction * stats.patrol_speed, stats.acceleration, delta)
	enemy.face_direction(direction, delta)


func _pick_point() -> void:
	var half := enemy.patrol_area * 0.5
	var here := enemy.global_position
	for attempt in 8:
		_point = enemy.home_position + Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y))
		if Vector2(_point.x - here.x, _point.z - here.z).length() >= MIN_LEG_LENGTH:
			break
	_leg_timer = LEG_TIMEOUT
