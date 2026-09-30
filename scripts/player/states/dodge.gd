extends PlayerState
## Dark Souls-style dodge roll on the dodge input. Commits for the whole roll
## (buffered inputs wait until it ends), travels stats.roll_distance at
## stats.roll_speed toward the held direction (or straight ahead along facing if
## nothing is held), and is invulnerable only on the i-frame window
## (stats.roll_iframe_start / roll_iframe_frames, in Roll animation frames).

const IFRAME_COLOR: Color = Color(0.4, 0.9, 1.0, 0.45)

var _direction: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _duration: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	player.stamina.spend(player.stats.dodge_stamina_cost)
	_direction = player.get_move_direction().normalized()
	if _direction == Vector3.ZERO:
		_direction = player.forward()
	# Face the roll so the forward roll matches travel; lock-on turns back after.
	player.snap_facing(_direction)
	_duration = player.stats.roll_distance / maxf(player.stats.roll_speed, 0.01)
	player.play_roll_animation(_duration)


func drives_animation() -> bool:
	return true


## Current frame of the Roll animation, however long the roll is tuned to last.
func current_frame() -> int:
	return int(_elapsed / _duration * player.roll_clip_frames())


func is_invulnerable() -> bool:
	var frame := current_frame()
	return frame >= player.stats.roll_iframe_start \
			and frame < player.stats.roll_iframe_start + player.stats.roll_iframe_frames


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		player.set_horizontal_velocity(_direction * player.stats.move_speed)
		transition_to(neutral_state())
		return
	player.set_horizontal_velocity(_direction * player.stats.roll_speed)
	if is_invulnerable():
		player.state_flash = IFRAME_COLOR
