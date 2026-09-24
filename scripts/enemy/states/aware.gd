extends EnemyState
## Brief "spotted you" beat: stops, turns to the player and blinks before engaging.

const BLINK_COLOR: Color = Color(1.0, 1.0, 0.7, 0.6)
const BLINK_INTERVAL: float = 0.1

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = enemy.stats.aware_time


func exit() -> void:
	enemy.reset_telegraph_visuals()


func physics_update(delta: float) -> void:
	_timer -= delta
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	enemy.face_target(delta)
	var blink_on := int(_timer / BLINK_INTERVAL) % 2 == 0
	enemy.telegraph_flash = BLINK_COLOR if blink_on else Color(0.0, 0.0, 0.0, 0.0)
	if _timer <= 0.0:
		transition_to(REPOSITION)
