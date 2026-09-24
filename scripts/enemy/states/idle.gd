extends EnemyState
## Stands still until the player comes within detection range.


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	if enemy.distance_to_target() <= enemy.stats.detection_radius:
		transition_to(AWARE)
