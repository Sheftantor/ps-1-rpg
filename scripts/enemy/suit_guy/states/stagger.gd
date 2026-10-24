extends SuitState
## Hit reaction, as the Mincer's Stagger: knocked back and briefly helpless,
## which also cancels a windup, and he can't shoot again until the player's
## attack is over (SuitGuy.hold_fire_from_hit()). Then back to Engage (or Wander
## if the player is gone).

const FLINCH_SPEED: float = 2.5

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = suit.stats.stagger_time
	suit.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	suit.model.play(MincerModel.CLIP_IDLE, FLINCH_SPEED, true)
	suit.hold_fire_from_hit()


func is_exposed() -> bool:
	return true


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	# Flying back, it keeps more of its momentum.
	var air_scale: float = Enemy.TUNING.enemy_air_friction_scale if suit.is_airborne() else 1.0
	suit.move_horizontal(Vector3.ZERO, suit.stats.stagger_friction * air_scale, delta)
	_timer -= delta
	# A launched or knocked-down enemy stays helpless until it's back on its feet.
	if _timer <= 0.0 and not suit.is_airborne() and not suit.is_knocked_down():
		transition_to(ENGAGE if can_see_target(suit.lose_range) else WANDER)
