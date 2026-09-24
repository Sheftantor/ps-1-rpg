extends EnemyState
## Holds the attack turn and closes to the chosen attack's range. Gives the turn
## back if it can't get there in time.

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = enemy.stats.approach_timeout


func physics_update(delta: float) -> void:
	if enemy.distance_to_target() <= enemy.current_attack.max_range:
		transition_to(TELEGRAPH)
		return
	_timer -= delta
	if _timer <= 0.0:
		enemy.release_attack_token(0.0)
		transition_to(REPOSITION)
		return
	enemy.move_horizontal(enemy.direction_to_target() * enemy.stats.move_speed, enemy.stats.acceleration, delta)
	enemy.face_target(delta)
