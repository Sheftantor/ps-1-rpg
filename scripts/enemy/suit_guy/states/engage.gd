extends SuitState
## Stands his ground, turns smoothly to face the player and starts a shot
## (Attack) whenever the cooldown allows. Goes back to Wander when the player is
## beyond lose_range, or out of sight for lose_sight_time.

var _unseen_timer: float = 0.0


func enter(msg: Dictionary) -> void:
	_unseen_timer = 0.0
	if msg.get("spotted", false):
		suit.shot_cooldown = maxf(suit.shot_cooldown, suit.first_shot_delay)


func physics_update(delta: float) -> void:
	suit.move_horizontal(Vector3.ZERO, suit.stats.acceleration, delta)
	if not suit.has_target() or suit.distance_to_target() > suit.lose_range:
		transition_to(WANDER)
		return
	suit.face_target(delta)
	if suit.has_line_of_sight():
		_unseen_timer = 0.0
	else:
		_unseen_timer += delta
		if _unseen_timer >= suit.lose_sight_time:
			transition_to(WANDER)
		return
	if suit.shot_cooldown <= 0.0:
		transition_to(ATTACK)
