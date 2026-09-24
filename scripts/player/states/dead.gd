extends PlayerState
## Out of health. Player._on_died reloads the scene after a delay.


func is_invulnerable() -> bool:
	return true


func physics_update(delta: float) -> void:
	player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
