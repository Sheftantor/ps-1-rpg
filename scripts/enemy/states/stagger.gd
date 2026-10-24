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
	# Flying back, it keeps more of its momentum.
	var air_scale: float = Enemy.TUNING.enemy_air_friction_scale if enemy.is_airborne() else 1.0
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.stagger_friction * air_scale, delta)
	_timer -= delta
	# A launched or knocked-down enemy stays helpless until it's back on its feet.
	if _timer <= 0.0 and not enemy.is_airborne() and not enemy.is_knocked_down():
		transition_to(IDLE if enemy.stats.passive else REPOSITION)
