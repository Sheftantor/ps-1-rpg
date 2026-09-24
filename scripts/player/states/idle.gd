extends PlayerState
## No movement input: coming to a stop (or falling). Acts on buffered input.


func physics_update(delta: float) -> void:
	player.locomote(delta, player.stats.move_speed)
	if try_neutral_action():
		return
	if player.get_move_direction() != Vector3.ZERO:
		transition_to(MOVE)
