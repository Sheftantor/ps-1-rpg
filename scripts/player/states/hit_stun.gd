extends PlayerState
## Hit reaction: knocked back and unable to act. Another hit restarts it.

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = player.stats.guard_break_stun_time if msg.get("guard_break", false) else player.stats.hit_stun_time
	player.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))


func physics_update(delta: float) -> void:
	player.move_horizontal(Vector3.ZERO, player.stats.deceleration * 0.5, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(neutral_state())
