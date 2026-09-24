extends EnemyState
## Circles the player at medium range, periodically asking for the attack turn.
## Holding the turn, it picks an attack and telegraphs if already in range,
## otherwise approaches first.

var _strafe_sign: float = 1.0
var _decision_timer: float = 0.0
var _flip_timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	var stats := enemy.stats
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_decision_timer = randf_range(stats.reposition_time_min, stats.reposition_time_max)
	_flip_timer = randf_range(stats.strafe_flip_time_min, stats.strafe_flip_time_max)


func physics_update(delta: float) -> void:
	var stats := enemy.stats
	var distance := enemy.distance_to_target()
	if distance > stats.lose_interest_radius:
		transition_to(IDLE)
		return

	_strafe(distance, delta)

	_decision_timer -= delta
	if _decision_timer > 0.0:
		return
	if not enemy.try_acquire_attack_token():
		_decision_timer = stats.token_retry_interval
		return
	enemy.current_attack = enemy.pick_attack()
	transition_to(TELEGRAPH if distance <= enemy.current_attack.max_range else APPROACH)


func _strafe(distance: float, delta: float) -> void:
	var stats := enemy.stats
	var to_target := enemy.direction_to_target()
	var tangent := to_target.cross(Vector3.UP) * _strafe_sign
	# -1..1: back off when too close, close in when too far.
	var radial := clampf((distance - stats.preferred_distance) / stats.distance_tolerance, -1.0, 1.0)
	var desired := tangent * stats.strafe_speed + to_target * radial * stats.move_speed
	enemy.move_horizontal(desired, stats.acceleration, delta)
	enemy.face_target(delta)

	_flip_timer -= delta
	if _flip_timer <= 0.0 or enemy.is_on_wall():
		_strafe_sign = -_strafe_sign
		_flip_timer = randf_range(stats.strafe_flip_time_min, stats.strafe_flip_time_max)
