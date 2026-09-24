extends PlayerState
## Guarding while the block input is held: slow movement, facing locked. Hits
## cost stamina instead of health (see Player._on_hit_received); not having
## enough stamina breaks the guard. Can roll out of it.

const GUARD_COLOR: Color = Color(0.5, 0.7, 1.0, 0.25)


func is_blocking() -> bool:
	return true


func stamina_regen_scale() -> float:
	return player.stats.block_stamina_regen_scale


func physics_update(delta: float) -> void:
	player.locomote(delta, player.stats.block_move_speed, false)
	player.state_flash = GUARD_COLOR
	if player.peek_buffer() == Player.ACTION_DODGE and player.can_dodge():
		player.consume_buffer()
		transition_to(DODGE)
		return
	if not player.wants_block():
		transition_to(neutral_state())
