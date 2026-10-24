extends SuitState
## Strolls between random points in the patrol area around the spawn point (the
## same approach as the Mincer's Idle) with the gun lowered. A short ray ahead
## turns him away from walls. Engages once the player is in range and in sight.

## Patrol legs shorter than this are re-rolled so he doesn't shuffle in place (m).
const MIN_LEG_LENGTH: float = 1.0
## Close enough to the patrol point to stop (m).
const ARRIVE_DISTANCE: float = 0.3
## Gives up on a point it can't reach after this long (s).
const LEG_TIMEOUT: float = 8.0
## How far ahead to look for walls (m), and at what height.
const WALL_PROBE_LENGTH: float = 0.9
const WALL_PROBE_HEIGHT: float = 0.6

var _point: Vector3 = Vector3.ZERO
var _pause_timer: float = 0.0
var _leg_timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	suit.reset_telegraph_visuals()
	_pick_point()
	_pause_timer = randf_range(0.0, suit.stats.patrol_pause_max)


func physics_update(delta: float) -> void:
	var stats := suit.stats
	if can_see_target(suit.detect_range):
		transition_to(ENGAGE, {"spotted": true})
		return
	if suit.patrol_area == Vector2.ZERO or _pause_timer > 0.0:
		_pause_timer -= delta
		suit.move_horizontal(Vector3.ZERO, stats.acceleration, delta)
		return

	var offset := _point - suit.global_position
	offset.y = 0.0
	_leg_timer -= delta
	if offset.length() <= ARRIVE_DISTANCE or _leg_timer <= 0.0 or _wall_ahead(offset.normalized()):
		_pause_timer = randf_range(stats.patrol_pause_min, stats.patrol_pause_max)
		_pick_point()
		return
	var direction := offset.normalized()
	suit.move_horizontal(direction * suit.walk_speed, stats.acceleration, delta)
	suit.face_direction(direction, delta)


func _wall_ahead(direction: Vector3) -> bool:
	var from := suit.global_position + Vector3.UP * WALL_PROBE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * WALL_PROBE_LENGTH, SuitGuy.SIGHT_MASK, [suit.get_rid()])
	return not suit.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _pick_point() -> void:
	var half := suit.patrol_area * 0.5
	var here := suit.global_position
	for attempt in 8:
		_point = suit.home_position + Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y))
		if Vector2(_point.x - here.x, _point.z - here.z).length() >= MIN_LEG_LENGTH:
			break
	_leg_timer = LEG_TIMEOUT
