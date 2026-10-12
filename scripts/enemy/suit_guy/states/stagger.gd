extends SuitState
## Hit reaction, as the Mincer's Stagger: knocked back and briefly helpless,
## which also cancels a windup. Then back to Engage (or Wander if the player is
## gone).

const FLINCH_SPEED: float = 2.5

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = suit.stats.stagger_time
	suit.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	suit.model.play(MincerModel.CLIP_IDLE, FLINCH_SPEED, true)


func is_exposed() -> bool:
	return true


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	suit.move_horizontal(Vector3.ZERO, suit.stats.stagger_friction, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(ENGAGE if can_see_target(suit.lose_range) else WANDER)
