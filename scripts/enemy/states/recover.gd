extends EnemyState
## After swing 5 he overextends, every combo, hit or miss: stumbles a little
## forward, steps back about STEP_DISTANCE over STEP_TIME to catch his balance
## (with a wobble), then straightens up. The whole stats.vulnerable_time window
## he can't attack and takes stats.vulnerable_damage_multiplier damage. Gives the
## attack turn back at the start; stats.combo_cooldown runs from the end. A hit
## still staggers him (the vulnerability keeps running through the stagger).

const STUMBLE_TIME := 0.25
const STUMBLE_SPEED := 1.4
const STUMBLE_LEAN := -24.0
const STEP_TIME := 0.5
const STEP_DISTANCE := 1.2
const STEP_LEAN := 8.0
## Wobble while stepping back: sideways tilt (degrees) and its rate (per second).
const WOBBLE_DEGREES := 7.0
const WOBBLE_RATE := 14.0
## Seconds of the StepBack clip covering one step; played to fit STEP_TIME.
const STEP_CLIP_SPAN := 1.25

var _elapsed: float = 0.0
var _duration: float = 0.0
var _stepping: bool = false


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_stepping = false
	_duration = maxf(enemy.stats.vulnerable_time, STUMBLE_TIME + STEP_TIME + 0.1)
	enemy.set_vulnerable(enemy.stats.vulnerable_time)
	enemy.release_attack_token(enemy.stats.attack_token_cooldown)
	var pose := (enemy.model as MincerModel).pose
	pose.weight = 1.0
	pose.swing = 0.0
	pose.guard = 0.0


func exit() -> void:
	(enemy.model as MincerModel).reset_pose()
	enemy.start_combo_cooldown(enemy.stats.combo_cooldown)


func is_exposed() -> bool:
	return true


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	var pose := (enemy.model as MincerModel).pose
	if _elapsed < STUMBLE_TIME:
		var t := _elapsed / STUMBLE_TIME
		enemy.set_horizontal_velocity(enemy.forward() * STUMBLE_SPEED * (1.0 - t))
		pose.lean_degrees = lerpf(pose.lean_degrees, STUMBLE_LEAN, minf(1.0, 20.0 * delta))
		pose.reach = minf(1.0, t * 3.0)
		pose.yaw_degrees = lerpf(pose.yaw_degrees, 0.0, minf(1.0, 12.0 * delta))
	elif _elapsed < STUMBLE_TIME + STEP_TIME:
		if not _stepping:
			_stepping = true
			enemy.model.play(MincerModel.CLIP_STEP_BACK, STEP_CLIP_SPAN / STEP_TIME, true)
		var t := (_elapsed - STUMBLE_TIME) / STEP_TIME
		enemy.set_horizontal_velocity(-enemy.forward() * STEP_DISTANCE / STEP_TIME)
		pose.lean_degrees = lerpf(STUMBLE_LEAN, STEP_LEAN, smoothstep(0.0, 1.0, t))
		pose.roll_degrees = sin(t * TAU * WOBBLE_RATE * STEP_TIME) * WOBBLE_DEGREES * (1.0 - t)
		pose.reach = 1.0 - t
		pose.yaw_degrees = 0.0
	else:
		if _stepping:
			_stepping = false
			enemy.model.play(MincerModel.CLIP_IDLE)
		var t := clampf((_elapsed - STUMBLE_TIME - STEP_TIME) / maxf(_duration - STUMBLE_TIME - STEP_TIME, 0.01), 0.0, 1.0)
		enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
		pose.lean_degrees = lerpf(STEP_LEAN, 0.0, t)
		pose.roll_degrees = 0.0
		pose.reach = 0.0
		pose.weight = 1.0 - smoothstep(0.6, 1.0, t)
	if _elapsed >= _duration:
		transition_to(IDLE if enemy.stats.passive else REPOSITION)
