extends EnemyState
## Brief "spotted you" beat: stops, turns to the player, shifts its weight back
## and blinks before engaging.

const BLINK_COLOR: Color = Color(1.0, 1.0, 0.7, 0.6)
const BLINK_INTERVAL: float = 0.1
const STARTLE_SPEED: float = 1.5

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = enemy.stats.aware_time
	enemy.model.play(MincerModel.CLIP_IDLE, STARTLE_SPEED, true)


func exit() -> void:
	enemy.reset_telegraph_visuals()


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_timer -= delta
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	enemy.face_target(delta)
	var blink_on := int(_timer / BLINK_INTERVAL) % 2 == 0
	enemy.telegraph_flash = BLINK_COLOR if blink_on else Color(0.0, 0.0, 0.0, 0.0)
	if _timer <= 0.0:
		transition_to(REPOSITION)
