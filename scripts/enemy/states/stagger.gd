extends EnemyState
## Hit reaction: knocked back and briefly helpless. Cancels the combo at any point
## (that state turns its hitbox and pose off on the way out; a cancelled combo
## starts again from the telegraph), gives up the attack turn and holds off the
## next combo for a short cooldown. Getting hit again restarts the stagger.
## Plays the hesitation clip fast as a flinch.

const FLINCH_SPEED: float = 2.5

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = enemy.stats.stagger_time
	enemy.release_attack_token(enemy.stats.attack_token_cooldown)
	enemy.start_combo_cooldown(enemy.stats.attack_token_cooldown)
	enemy.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	enemy.model.play(MincerModel.CLIP_IDLE, FLINCH_SPEED, true)


func is_exposed() -> bool:
	return true


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.stagger_friction, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(IDLE if enemy.stats.passive else REPOSITION)
