extends EnemyState
## Terminal state: stops taking hits, shrinks away, then frees the enemy.

const SHRINK_TIME: float = 0.4


func enter(msg: Dictionary) -> void:
	enemy.release_attack_token(0.0)
	enemy.hurtbox.invulnerable = true
	enemy.hurtbox.set_deferred(&"monitorable", false)
	enemy.set_deferred(&"collision_layer", 0)
	enemy.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	var tween := enemy.create_tween()
	tween.tween_property(enemy.facing, ^"scale", Vector3.ONE * 0.05, SHRINK_TIME)
	tween.tween_callback(enemy.queue_free)


func can_be_staggered() -> bool:
	return false


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.stagger_friction, delta)
