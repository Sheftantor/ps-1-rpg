extends MonkState
## Into the combo: the tell (the combo arms wind back, red flash, still
## turning) for rush_tell, then he flies straight at the player at rush_speed
## until within combo_range, or rush_timeout runs out, and strikes (Attack).
## Poise holds through the tell; the dash itself can't be interrupted.

const TELL_COLOR := Color(1.0, 0.2, 0.15)
const TELL_FLASH := 0.6

var _elapsed: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	monk.current_attack = monk.pick_attack()


func exit() -> void:
	monk.reset_telegraph_visuals()


func can_be_staggered() -> bool:
	return _elapsed < monk.rush_tell and monk.poise_broken()


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed < monk.rush_tell:
		var t := _elapsed / maxf(monk.rush_tell, 0.01)
		monk.face_target(delta)
		monk.move_horizontal(Vector3.ZERO, monk.stats.acceleration, delta)
		for arm in COMBO_ARMS:
			monk.figure().set_strike(arm, -smoothstep(0.0, 1.0, t))
		monk.telegraph_flash = Color(TELL_COLOR, TELL_FLASH * t)
		return
	monk.telegraph_flash = Color(TELL_COLOR, TELL_FLASH)
	monk.face_target(delta)
	monk.set_horizontal_velocity(monk.direction_to_target() * monk.rush_speed)
	if monk.distance_to_target() <= monk.combo_range or _elapsed >= monk.rush_tell + monk.rush_timeout:
		transition_to(ATTACK)
