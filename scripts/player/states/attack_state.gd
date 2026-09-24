class_name AttackState
extends PlayerState
## Shared attack timeline: startup -> active (hitbox live) -> recovery, lunging
## forward until the hitbox closes. Subclasses decide what may cancel recovery.

var attack: AttackData = null
var elapsed: float = 0.0


func begin(new_attack: AttackData) -> void:
	attack = new_attack
	elapsed = 0.0
	player.hitbox.deactivate()
	player.aim_attack()


func exit() -> void:
	player.hitbox.deactivate()


## Advances the timeline. Returns true once recovery is over.
func advance(delta: float) -> bool:
	elapsed += delta
	var active_end := attack.startup_time + attack.active_time
	if elapsed < active_end:
		player.set_horizontal_velocity(player.forward() * attack.lunge_speed)
	else:
		player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)

	if elapsed >= attack.startup_time and elapsed < active_end:
		if not player.hitbox.is_active():
			player.hitbox.activate(attack, player)
	elif player.hitbox.is_active():
		player.hitbox.deactivate()
	return elapsed >= active_end + attack.recovery_time


## True during the attack's cancel_window, which opens as the hitbox closes.
func in_cancel_window() -> bool:
	var since_active := elapsed - (attack.startup_time + attack.active_time)
	return since_active >= 0.0 and since_active < minf(attack.cancel_window, attack.recovery_time)
