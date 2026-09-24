extends EnemyState
## The attack itself: hitbox live for active_time while moving forward at the
## attack's lunge_speed. Committed: hits don't stagger out of it.

var _elapsed: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	enemy.hitbox.activate(enemy.current_attack, enemy)


func exit() -> void:
	enemy.hitbox.deactivate()


func can_be_staggered() -> bool:
	return false


func physics_update(delta: float) -> void:
	var attack := enemy.current_attack
	_elapsed += delta
	enemy.set_horizontal_velocity(enemy.forward() * attack.lunge_speed)
	if _elapsed >= attack.active_time:
		transition_to(RECOVER)
