extends EnemyState
## The readable wind-up before an attack lands: the mesh pulses and flashes in the
## attack's telegraph color, ramping up until it fires, while the attack clip
## plays up to its hit window. Tracks the player until telegraph_commit_time
## before the end, then locks its aim so a well-timed sidestep or dash makes the
## attack miss. Hitting the enemy here staggers it. Shortened by escalation.

var _elapsed: float = 0.0
var _duration: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	var attack := enemy.current_attack
	_duration = attack.telegraph_time / enemy.attack_speed()
	if attack.animation != &"":
		enemy.model.play(attack.animation, attack.hit_window.x / _duration, true)


func exit() -> void:
	enemy.reset_telegraph_visuals()


func drives_animation() -> bool:
	return enemy.current_attack.animation != &""


func physics_update(delta: float) -> void:
	var attack := enemy.current_attack
	_elapsed += delta
	var progress := clampf(_elapsed / _duration, 0.0, 1.0)

	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	if _duration - _elapsed > enemy.stats.telegraph_commit_time:
		enemy.face_target(delta)

	var wave := 0.5 + 0.5 * sin(_elapsed * TAU * attack.telegraph_pulse_rate)
	enemy.pulse_scale = 1.0 + attack.telegraph_pulse_amount * wave * (0.5 + 0.5 * progress)
	enemy.telegraph_flash = Color(attack.telegraph_color, lerpf(0.3, 0.9, progress))

	if _elapsed >= _duration:
		transition_to(ATTACK)
