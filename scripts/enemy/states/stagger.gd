extends EnemyState
## Hit reaction: knocked back and briefly helpless. Interrupts a pending attack
## and gives up the attack turn. Getting hit again restarts the stagger.

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = enemy.stats.stagger_time
	enemy.release_attack_token(enemy.stats.attack_token_cooldown)
	enemy.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.stagger_friction, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(REPOSITION)
