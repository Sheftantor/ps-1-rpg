extends SuitState
## One shot: raises the gun quickly and holds it (aim_hold_seconds) over `windup` (still turning, then committed for the
## last COMMIT_TIME) with an orange flash as the tell, fires at the player's chest
## as it is at that instant (no tracking after), then lowers the gun and goes
## back to Engage.

## Stops turning this long before the shot, so a late side-step still reads.
const COMMIT_TIME: float = 0.1
## Recoil and hold after the shot before lowering the gun (s).
const RECOVER_TIME: float = 0.35
## Time to lower the gun back to the standing pose (s).
const LOWER_TIME: float = 0.3
const TELL_COLOR: Color = Color(1.0, 0.55, 0.1)
## Peak strength of the windup flash (0-1).
const TELL_STRENGTH: float = 0.5

var _timer: float = 0.0
var _fired: bool = false


func enter(_msg: Dictionary) -> void:
	_timer = suit.windup
	_fired = false
	# Quick raise, then a visible hold at chest height; the shot still comes
	# `windup` after this starts.
	suit.suit_model().raise_gun(maxf(suit.windup - suit.aim_hold_seconds, 0.05))


func exit() -> void:
	suit.reset_telegraph_visuals()
	suit.suit_model().lower_gun(LOWER_TIME)


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	suit.move_horizontal(Vector3.ZERO, suit.stats.acceleration, delta)
	_timer -= delta
	if not _fired:
		if _timer > COMMIT_TIME:
			suit.face_target(delta)
		var t := 1.0 - clampf(_timer / maxf(suit.windup, 0.01), 0.0, 1.0)
		suit.telegraph_flash = Color(TELL_COLOR, TELL_STRENGTH * t)
		if _timer <= 0.0:
			_fired = true
			suit.reset_telegraph_visuals()
			suit.fire_shot()
			_timer = RECOVER_TIME
		return
	if _timer <= 0.0:
		transition_to(ENGAGE)
