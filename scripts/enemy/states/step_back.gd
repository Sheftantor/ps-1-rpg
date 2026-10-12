extends EnemyState
## The rare spacing reset (stats.random_step_back_chance, rolled when he's about
## to start a combo): steps back about DISTANCE facing the player, then goes back
## to circling and decides again. Gives the attack turn back.

const DISTANCE := 1.5
const TIME := 0.6
## Seconds of the StepBack clip covering one step; played to fit TIME.
const CLIP_SPAN := 1.25

var _elapsed: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	enemy.release_attack_token(0.0)
	enemy.model.play(MincerModel.CLIP_STEP_BACK, CLIP_SPAN / TIME, true)


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.face_target(delta)
	enemy.set_horizontal_velocity(-enemy.direction_to_target() * DISTANCE / TIME)
	if _elapsed >= TIME:
		enemy.set_horizontal_velocity(Vector3.ZERO)
		transition_to(REPOSITION)
