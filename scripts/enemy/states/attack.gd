extends EnemyState
## The attack itself: hitbox live while the clip is inside the attack's
## hit_window (or for active_time without a clip), moving forward at the attack's
## lunge_speed. Committed: hits don't stagger out of it, but any hit still breaks
## the escalation chain. Plays faster, and with arm jitter, the further the chain
## has run; finishing the last attack of the chain loses the enemy its balance.

var _elapsed: float = 0.0
var _duration: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	var attack := enemy.current_attack
	var speed := enemy.attack_speed()
	_duration = attack.active_time
	if attack.animation != &"":
		_duration = (attack.hit_window.y - attack.hit_window.x) / speed
		enemy.model.play(attack.animation, speed)
		enemy.model.set_jitter(enemy.attack_jitter())
	enemy.hitbox.activate(enemy.escalated_attack(), enemy)
	enemy.begin_attack()


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.model.set_jitter(0.0)


func can_be_staggered() -> bool:
	return false


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	var attack := enemy.current_attack
	_elapsed += delta
	enemy.set_horizontal_velocity(enemy.forward() * attack.lunge_speed)
	if _elapsed >= _duration:
		transition_to(BALANCE_LOSS if enemy.finish_attack() else RECOVER)
