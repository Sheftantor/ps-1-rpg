extends EnemyState
## The readable wind-up before an attack lands: the mesh pulses and flashes in the
## attack's telegraph color, ramping up until it fires. Tracks the player until
## telegraph_commit_time before the end, then locks its aim so a well-timed
## sidestep or dash makes the attack miss. Hitting the enemy here staggers it.

var _elapsed: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0


func exit() -> void:
	enemy.reset_telegraph_visuals()


func physics_update(delta: float) -> void:
	var attack := enemy.current_attack
	_elapsed += delta
	var progress := clampf(_elapsed / attack.telegraph_time, 0.0, 1.0)

	enemy.move_horizontal(Vector3.ZERO, enemy.stats.acceleration, delta)
	if attack.telegraph_time - _elapsed > enemy.stats.telegraph_commit_time:
		enemy.face_target(delta)

	var wave := 0.5 + 0.5 * sin(_elapsed * TAU * attack.telegraph_pulse_rate)
	enemy.pulse_scale = 1.0 + attack.telegraph_pulse_amount * wave * (0.5 + 0.5 * progress)
	enemy.telegraph_flash = Color(attack.telegraph_color, lerpf(0.3, 0.9, progress))

	if _elapsed >= attack.telegraph_time:
		transition_to(ATTACK)
