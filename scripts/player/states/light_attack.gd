extends AttackState
## One hit of the light combo (stats.light_combo). As the hitbox closes, the hit's
## cancel_window opens: a buffered light press chains the next hit, or a dodge cuts
## recovery short. Once the window passes, the swing commits through recovery.

var _combo_index: int = 0


func enter(msg: Dictionary) -> void:
	_combo_index = msg.get("combo_index", 0)
	begin(player.stats.light_combo[_combo_index])


func physics_update(delta: float) -> void:
	var finished := advance(delta)
	if in_cancel_window() and _try_cancel():
		return
	if finished:
		transition_to(neutral_state())


func _try_cancel() -> bool:
	match player.peek_buffer():
		Player.ACTION_LIGHT:
			var next := _combo_index + 1
			if next < player.stats.light_combo.size():
				player.consume_buffer()
				transition_to(LIGHT_ATTACK, {"combo_index": next})
				return true
		Player.ACTION_DODGE:
			if player.can_dodge():
				player.consume_buffer()
				transition_to(DODGE)
				return true
	return false
