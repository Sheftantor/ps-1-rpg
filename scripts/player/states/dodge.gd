extends PlayerState
## Stamina-gated roll. It's timed in animation frames (stats.dodge_frame_rate) so
## the i-frames can be lined up with a real roll animation later: only frames
## dodge_iframe_first..dodge_iframe_last are invulnerable, not the whole roll.

const IFRAME_COLOR: Color = Color(0.4, 0.9, 1.0, 0.45)

var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	player.stamina.spend(player.stats.dodge_stamina_cost)
	_direction = player.get_move_direction().normalized()
	if _direction == Vector3.ZERO:
		_direction = -player.forward()  # No direction held: backstep.
	elif player.lock_target == null:
		player.snap_facing(_direction)


func current_frame() -> int:
	return int(_elapsed * player.stats.dodge_frame_rate)


func is_invulnerable() -> bool:
	var frame := current_frame()
	return frame >= player.stats.dodge_iframe_first and frame <= player.stats.dodge_iframe_last


func physics_update(delta: float) -> void:
	_elapsed += delta
	if current_frame() >= player.stats.dodge_frames:
		player.set_horizontal_velocity(_direction * player.stats.move_speed)
		transition_to(neutral_state())
		return
	player.set_horizontal_velocity(_direction * player.stats.dodge_speed)
	if is_invulnerable():
		player.state_flash = IFRAME_COLOR
