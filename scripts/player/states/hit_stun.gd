extends PlayerState
## Hit reaction: knocked back and unable to act. Another hit restarts it.
## A knockdown hit (AttackData.knockdown, an enemy combo's final blow) throws
## the player back instead: turned to face the hit, launched up and away, the
## body tipping over backwards in the air (KnockdownPose), landing on their
## back, lying there and getting up (Player Knockdown in the combat tuning).
## Untouchable until standing again.

const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")
const KNOCKDOWN_POSE := preload("res://scripts/combat/knockdown_pose.gd")
## Height (m, in Facing space) the body turns about: the hips.
const PIVOT_HEIGHT := 0.9

var _timer: float = 0.0
var _knockdown: KNOCKDOWN_POSE = null
var _model: Node3D = null
var _model_rest: Transform3D


func enter(msg: Dictionary) -> void:
	_timer = player.stats.guard_break_stun_time if msg.get("guard_break", false) else player.stats.hit_stun_time
	_timer *= msg.get("stun_scale", 1.0)
	player.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	if not msg.get("knockdown", false):
		return
	if _model == null:
		_model = player.get_node(^"Facing/Model")
		_model_rest = _model.transform
	if _knockdown == null:
		_knockdown = KNOCKDOWN_POSE.new(false, TUNING.player_knockdown_tilt_degrees, TUNING.player_down_time, TUNING.player_get_up_time)
	var away: Vector3 = msg.get("away", -player.forward())
	player.snap_facing(-away)
	player.set_horizontal_velocity(away * TUNING.player_knockdown_speed)
	player.velocity.y = TUNING.player_knockdown_launch


func exit() -> void:
	if _knockdown != null:
		_knockdown = null
		_model.transform = _model_rest


func is_invulnerable() -> bool:
	return _knockdown != null


func physics_update(delta: float) -> void:
	if _knockdown != null:
		# Sails back through the air; slides to a stop once down.
		if player.is_on_floor():
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
		var pitch := _knockdown.update(delta, not player.is_on_floor())
		_model.transform = KNOCKDOWN_POSE.apply(_model_rest, pitch, PIVOT_HEIGHT, _knockdown.lying_amount())
		if _knockdown.done():
			transition_to(neutral_state())
		return
	player.move_horizontal(Vector3.ZERO, player.stats.deceleration * 0.5, delta)
	_timer -= delta
	if _timer <= 0.0:
		transition_to(neutral_state())
