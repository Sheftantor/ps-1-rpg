extends EnemyState
## Post-attack punish window while the swing follows through. Hands the attack
## turn back (with the shared cooldown) as soon as it starts, then returns to
## circling. Shortened as the escalation chain speeds the enemy up.

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = enemy.current_attack.recovery_time / enemy.attack_speed()
	enemy.release_attack_token(enemy.stats.attack_token_cooldown)


func drives_animation() -> bool:
	return enemy.model.is_playing_one_shot()


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(REPOSITION)
