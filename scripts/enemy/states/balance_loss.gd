extends EnemyState
## Thrown off balance by the last, wildest attack of an escalation chain: stumbles
## back and can't attack or move for stats.balance_loss_time. Exposed like a
## stagger (gives up the attack turn, blinks), but hits don't cut it short, so
## the whole window is open to punishment.

const BLINK_COLOR: Color = Color(0.55, 0.8, 1.0, 0.45)
const BLINK_INTERVAL: float = 0.15
## Seconds of the StepBack clip that hold the stumble; played fast enough to fit.
const STUMBLE_CLIP_SPAN: float = 2.5
## Backward drift at the start (m/s), standing in for the clip's root motion.
const STUMBLE_DRIFT: float = 1.4
const STUMBLE_FRICTION: float = 3.0
## Arm flail during the stumble (degrees); eases out as the stumble settles.
const FLAIL_DEGREES: float = 10.0

var _timer: float = 0.0


func enter(_msg: Dictionary) -> void:
	_timer = enemy.stats.balance_loss_time
	enemy.break_chain()
	enemy.release_attack_token(enemy.stats.attack_token_cooldown)
	enemy.set_horizontal_velocity(-enemy.forward() * STUMBLE_DRIFT)
	enemy.model.play(MincerModel.CLIP_STEP_BACK, STUMBLE_CLIP_SPAN / maxf(_timer, 0.1), true)
	enemy.model.set_jitter(FLAIL_DEGREES)


func exit() -> void:
	enemy.reset_telegraph_visuals()
	enemy.model.set_jitter(0.0)


func can_be_staggered() -> bool:
	return false


func is_exposed() -> bool:
	return true


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, STUMBLE_FRICTION, delta)
	_timer -= delta
	if _timer < enemy.stats.balance_loss_time * 0.5:
		enemy.model.set_jitter(0.0)
	var blink_on := int(_timer / BLINK_INTERVAL) % 2 == 0
	enemy.telegraph_flash = BLINK_COLOR if blink_on else Color(0.0, 0.0, 0.0, 0.0)
	if _timer <= 0.0:
		transition_to(IDLE if enemy.stats.passive else REPOSITION)
