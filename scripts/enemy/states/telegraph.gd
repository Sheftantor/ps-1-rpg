extends EnemyState
## The souls-like tell before the combo (no colour flash): he rears up, both claws
## spread wide and raised, torso leaning back, with a short tremble, held for
## stats.telegraph_time, then lunges into swing 1 (Attack). Stands his ground (no
## step back) and tracks the player until telegraph_commit_time before the end,
## so a late sidestep still makes swing 1 miss. Any hit cancels it (Stagger).

## Share of the telegraph spent rearing up; the rest is the trembling hold.
const RISE_SHARE := 0.4
const LEAN_BACK := 18.0
## Tremble: arm shake (degrees) and body shiver (degrees, per second).
const TREMBLE_JITTER := 6.0
const SHIVER_DEGREES := 2.5
const SHIVER_RATE := 22.0

var _elapsed: float = 0.0
var _duration: float = 0.0
## True when leaving into the combo (the pose carries on).
var _into_combo: bool = false


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_into_combo = false
	_duration = maxf(enemy.stats.telegraph_time, 0.05)
	enemy.combo_swing = 0
	enemy.model.play(MincerModel.CLIP_IDLE, 0.5)
	var pose := (enemy.model as MincerModel).pose
	pose.weight = 1.0
	pose.swing = 0.0
	pose.guard = 0.0
	pose.reach = 0.0


func exit() -> void:
	enemy.model.set_jitter(0.0)
	# Leading into the combo the pose carries on; anything else (a hit) drops it.
	if not _into_combo:
		(enemy.model as MincerModel).reset_pose()


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	if _duration - _elapsed > enemy.stats.telegraph_commit_time:
		enemy.face_target(delta)
	var rise := smoothstep(0.0, 1.0, _elapsed / (_duration * RISE_SHARE))
	var pose := (enemy.model as MincerModel).pose
	pose.rear = rise
	pose.lean_degrees = LEAN_BACK * rise
	pose.yaw_degrees = 0.0
	# Tremble once he's up.
	var held := clampf((_elapsed - _duration * RISE_SHARE) / (_duration * 0.15), 0.0, 1.0)
	pose.roll_degrees = sin(_elapsed * SHIVER_RATE) * SHIVER_DEGREES * held
	enemy.model.set_jitter(TREMBLE_JITTER * held)
	if _elapsed >= _duration:
		_into_combo = true
		transition_to(ATTACK)
