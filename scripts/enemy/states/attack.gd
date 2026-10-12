extends EnemyState
## The combo: five horizontal claw sweeps, alternating left, right, left, right,
## left. Swings 1 and 2 are slow (stats.slow_swing_time, split like the player's
## first bat swings), 3 to 5 rapid (stats.rapid_swing_time, barely any recovery).
## The hitbox is live only in each swing's strike phase, and every swing deals
## the same damage (Enemy.combo_attack()). Tracks the player through each windup,
## lunges forward on each strike. After swing 5: Recover. A hit cancels it at any
## point (Stagger), except swings 3 to 5 with stats.combo_stagger_immune.

const SWINGS := 5
## Windup / strike shares of a swing; the rest is recovery.
const SLOW_SPLIT := Vector2(0.17, 0.21)
const RAPID_SPLIT := Vector2(0.25, 0.55)
## Claw angle around the chest (degrees): wound back on its own side, then swept
## across the front to the other side.
const WIND_ANGLE := 105.0
const SWEEP_END := -70.0
## Arm height at the windup and through the sweep (arm lengths).
const WIND_HEIGHT := 0.2
const SWEEP_HEIGHT := -0.05
## How far the torso turns with the claw (fraction of its angle).
const TORSO_FOLLOW := 0.35
## Forward lean through the sweeps (degrees).
const SWING_LEAN := -8.0
## Swing 1 lunges harder out of the telegraph.
const FIRST_LUNGE_SCALE := 1.6
## Arm shake through the rapid swings: "going crazy" (degrees).
const FRENZY_JITTER := 4.0

var _elapsed: float = 0.0
var _swing: int = 0
var _striking: bool = false


func enter(_msg: Dictionary) -> void:
	enemy.model.play(MincerModel.CLIP_IDLE, 0.5)
	var pose := (enemy.model as MincerModel).pose
	pose.weight = 1.0
	pose.guard = 1.0
	_start_swing(1)


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.model.set_jitter(0.0)
	enemy.combo_swing = 0
	_striking = false
	if not _finished():
		# Cancelled: drop the pose now, the stagger plays on the plain clip.
		(enemy.model as MincerModel).reset_pose()


func can_be_staggered() -> bool:
	return not (enemy.stats.combo_stagger_immune and _swing >= 3)


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	var duration := _swing_time()
	var split := _split()
	var wind_end := duration * split.x
	var strike_end := duration * (split.x + split.y)
	var side := _side()
	var pose := (enemy.model as MincerModel).pose
	var angle: float
	var height: float
	if _elapsed < wind_end:
		var t := _elapsed / wind_end
		angle = lerpf(SWEEP_END * 0.5 if _swing > 1 else 30.0, WIND_ANGLE, _ease_out(t))
		height = lerpf(0.0, WIND_HEIGHT, t)
		pose.swing = minf(1.0, t * 2.0)
		enemy.face_target(delta)
		enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
		_set_striking(false)
	elif _elapsed < strike_end:
		var t := (_elapsed - wind_end) / (strike_end - wind_end)
		angle = lerpf(WIND_ANGLE, SWEEP_END, _ease_in_out(t))
		height = lerpf(WIND_HEIGHT, SWEEP_HEIGHT, t)
		pose.swing = 1.0
		var lunge := enemy.current_attack.lunge_speed * (FIRST_LUNGE_SCALE if _swing == 1 else 1.0)
		enemy.set_horizontal_velocity(enemy.forward() * lunge)
		_set_striking(true)
	else:
		var t := (_elapsed - strike_end) / maxf(duration - strike_end, 0.001)
		angle = lerpf(SWEEP_END, SWEEP_END * 0.75, t)
		height = SWEEP_HEIGHT
		pose.swing = 1.0
		enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
		_set_striking(false)
	pose.swing_side = side
	pose.swing_angle = angle
	pose.swing_height = height
	pose.yaw_degrees = side * angle * TORSO_FOLLOW
	pose.lean_degrees = move_toward(pose.lean_degrees, SWING_LEAN, 120.0 * delta)
	pose.rear = move_toward(pose.rear, 0.0, 8.0 * delta)
	pose.roll_degrees = 0.0
	if _elapsed >= duration:
		if _swing >= SWINGS:
			_swing += 1
			transition_to(RECOVER)
		else:
			_start_swing(_swing + 1)


func _start_swing(number: int) -> void:
	_swing = number
	_elapsed = 0.0
	enemy.combo_swing = number
	enemy.model.set_jitter(FRENZY_JITTER if number >= 3 else 0.0)


## Left claw on odd swings, right on even.
func _side() -> float:
	return 1.0 if _swing % 2 == 1 else -1.0


func _swing_time() -> float:
	return maxf(enemy.stats.slow_swing_time if _swing <= 2 else enemy.stats.rapid_swing_time, 0.05)


func _split() -> Vector2:
	return SLOW_SPLIT if _swing <= 2 else RAPID_SPLIT


func _finished() -> bool:
	return _swing > SWINGS


## Hitbox live only in the strike phase, freshly armed for each swing.
func _set_striking(striking: bool) -> void:
	if striking == _striking:
		return
	_striking = striking
	if striking:
		enemy.hitbox.activate(enemy.combo_attack(), enemy)
	else:
		enemy.hitbox.deactivate()


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
