extends MonkState
## Floats near his spawn point, drifting back to it if pushed away, until the
## player is within detect_range and in sight.

## Drift speed back toward the spawn point (fraction of hover_speed).
const RETURN_SPEED := 0.5


func enter(_msg: Dictionary) -> void:
	monk.reset_telegraph_visuals()
	monk.figure().clear_strikes()


func physics_update(delta: float) -> void:
	if can_see_target(monk.detect_range):
		transition_to(ENGAGE, {"spotted": true})
		return
	var home := monk.home_position - monk.global_position
	home.y = 0.0
	monk.move_horizontal(home.limit_length(1.0) * monk.hover_speed * RETURN_SPEED, monk.stats.acceleration, delta)
