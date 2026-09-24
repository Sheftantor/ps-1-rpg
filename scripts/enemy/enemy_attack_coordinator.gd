class_name EnemyAttackCoordinator
extends RefCounted
## Turn-taking between enemies: only the enemy holding the attack token may
## approach/telegraph/attack. Releasing the token starts a shared cooldown before
## anyone (including the releaser) can take the next turn.

static var _holder: WeakRef = null
static var _available_at_msec: int = 0


static func try_acquire(enemy: Node) -> bool:
	if is_holder(enemy):
		return true
	if _holder != null and _holder.get_ref() != null:
		return false
	if Time.get_ticks_msec() < _available_at_msec:
		return false
	_holder = weakref(enemy)
	return true


## Does nothing if enemy isn't the holder, so callers can release unconditionally.
static func release(enemy: Node, cooldown: float) -> void:
	if not is_holder(enemy):
		return
	_holder = null
	_available_at_msec = Time.get_ticks_msec() + int(cooldown * 1000.0)


static func is_holder(enemy: Node) -> bool:
	return _holder != null and _holder.get_ref() == enemy
