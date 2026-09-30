class_name AttackState
extends PlayerState
## Shared attack timeline: startup -> active (hitbox live) -> recovery, lunging
## forward until the hitbox closes. Subclasses decide what may cancel recovery.
## Basic swings open the horizontal swing hitbox on their clip's hit frames; strong
## attacks (no hit frames on the clip) use the wide hitbox on AttackData timing.

var attack: AttackData = null
var elapsed: float = 0.0
var hitbox: Hitbox = null


func begin(new_attack: AttackData) -> void:
	attack = new_attack
	elapsed = 0.0
	player.hitbox.deactivate()
	player.swing_hitbox.deactivate()
	hitbox = player.hitbox if is_strong() else player.swing_hitbox
	player.aim_attack()
	player.play_attack_animation(is_strong(), attack.startup_time + attack.active_time + attack.recovery_time)


func exit() -> void:
	hitbox.deactivate()


## Strong attacks play the heavier StrongAttack/AirStrongAttack swing.
func is_strong() -> bool:
	return false


func drives_animation() -> bool:
	return true


## Advances the timeline. Returns true once recovery is over.
func advance(delta: float) -> bool:
	elapsed += delta
	var active_end := attack.startup_time + attack.active_time
	if elapsed < active_end:
		player.set_horizontal_velocity(player.forward() * attack.lunge_speed)
	else:
		player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)

	var on_hit_frames := player.attack_hit_frame_state()
	var live := on_hit_frames == 1 if on_hit_frames >= 0 else elapsed >= attack.startup_time and elapsed < active_end
	# One activation per swing, so each enemy is hit at most once (Hitbox tracks it).
	if live and not hitbox.is_active():
		hitbox.activate(attack, player)
	elif not live and hitbox.is_active():
		hitbox.deactivate()
	return elapsed >= active_end + attack.recovery_time


## True during the attack's cancel_window, which opens as the hitbox closes.
func in_cancel_window() -> bool:
	var since_active := elapsed - (attack.startup_time + attack.active_time)
	return since_active >= 0.0 and since_active < minf(attack.cancel_window, attack.recovery_time)
