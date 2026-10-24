extends MonkState
## Hit reaction once his poise is broken (or any hit while recovering): knocked
## back and briefly helpless for stats.stagger_time, which cancels a charge or
## a rush tell, limbs back to idle. Poise refills. Then Engage (or Hover if the
## player is gone). Another hit only re-staggers him once poise breaks again.

var _timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_timer = monk.stats.stagger_time
	monk.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	monk.reset_poise()
	monk.reset_telegraph_visuals()
	monk.figure().clear_strikes()


func is_exposed() -> bool:
	return true


func physics_update(delta: float) -> void:
	monk.move_horizontal(Vector3.ZERO, monk.stats.stagger_friction, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(ENGAGE if can_see_target(monk.lose_range) else HOVER)
