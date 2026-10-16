extends PlayerState
## The melee combo (every melee weapon): three swings, each one press (or keep the button held).
## Swing 1 goes right-to-left, swing 2 left-to-right, swing 3 is the finisher: a
## strong, wide right-to-left sweep (finisher_arc_degrees) with a longer reach,
## a bigger step forward, the body twisting through it and
## a longer recovery that can't be dodged out of at first, like the end of a
## Kingdom Hearts ground combo.
## Chaining: a press any time during swing 1 or 2 queues the next swing, which
## starts as this one ends; holding the button through the end of the swing
## does the same (swing_hold_to_combo), letting go before then doesn't. After
## a swing ends there's swing_combo_window (1 s) to move about and press again
## to carry on with the next swing; after a longer pause, or after the
## finisher, the combo starts again from swing 1. During the finisher only a
## press (or hold) in the last swing_buffer_window of its recovery queues a
## new combo. Each swing: windup (the weapon pulls back) -> strike (a fast
## ease-out sweep; the arc hitbox is live and sweeps with it, with a small
## lunge) -> recovery. Only recovery can be cancelled, by the dodge.
## Damage and knockback: stats.light_combo[0], [1], [2] (Light 1-3). Timing in
## res://resources/combat_tuning.tres. Clips SwingRL / SwingLR / SwingFinisher,
## built by res://scripts/tools/build_melee_swing_clips.gd from the Attack clip.

enum Phase { WINDUP, STRIKE, RECOVERY }

const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")
const COMBO_CLIPS: Array[StringName] = [&"SwingRL", &"SwingLR", &"SwingFinisher"]
## Swing direction per combo step (the finisher sweeps right-to-left).
const COMBO_LEFT_TO_RIGHT: Array[bool] = [false, true, false]
const FINISHER := 2

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _left_to_right: bool = false
var _queued: bool = false
## Combo step of this swing (0, 1, or FINISHER) and of the next if it chains.
var _step: int = 0
var _next_step: int = 0
## When the last swing ended (s since start, from Time).
var _last_end_time: float = -INF
var _pivot: Node3D = null
var _hitbox: Hitbox = null
var _model: Node3D = null
var _model_rest: Transform3D
var _pivot_rest_scale: Vector3 = Vector3.ONE


func enter(_msg: Dictionary) -> void:
	if _pivot == null:
		_pivot = player.get_node(^"Facing/SwingArc")
		_hitbox = player.get_node(^"Facing/SwingArc/ArcHitbox")
		_model = player.get_node(^"Facing/Model")
		_model_rest = _model.transform
		_pivot_rest_scale = _pivot.scale
	var chained := _now() - _last_end_time <= TUNING.swing_combo_window
	_step = _next_step if chained else 0
	_left_to_right = COMBO_LEFT_TO_RIGHT[_step]
	_queued = false
	player.hitbox.deactivate()
	player.swing_hitbox.deactivate()
	player.aim_attack()
	_pivot.rotation.y = _arc_angle(0.0)
	_pivot.scale = _pivot_rest_scale * (TUNING.finisher_reach_scale if _is_finisher() else 1.0)
	player.play_action_clip(_clip(), 1.0)
	_start_phase(Phase.WINDUP)


func exit() -> void:
	_hitbox.deactivate()
	_pivot.scale = _pivot_rest_scale
	_model.transform = _model_rest


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			_take_attack_presses()
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			_twist(-0.4 * _ease_in_out(_elapsed / _windup()))
			if _elapsed >= _windup():
				_hitbox.activate(_attack(), player)
				_start_phase(Phase.STRIKE)
		Phase.STRIKE:
			_take_attack_presses()
			player.set_horizontal_velocity(player.forward() * _lunge() / _strike())
			var progress := clampf(_elapsed / _strike(), 0.0, 1.0)
			var sweep := 1.0 - (1.0 - progress) * (1.0 - progress)
			_pivot.rotation.y = _arc_angle(sweep)
			_twist(lerpf(-0.4, 0.6, sweep))
			if _elapsed >= _strike():
				_hitbox.deactivate()
				_start_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			_twist(0.6 * (1.0 - _ease_in_out(_elapsed / _recovery())))
			var in_buffer := _recovery() - _elapsed <= TUNING.swing_buffer_window
			match player.peek_buffer():
				Player.ACTION_LIGHT:
					player.consume_buffer()
					_queued = _queued or in_buffer or not _is_finisher()
				Player.ACTION_DODGE:
					if player.can_dodge() and _can_dodge_cancel():
						player.consume_buffer()
						_end_swing()
						transition_to(DODGE)
						return
			if in_buffer and TUNING.swing_hold_to_combo and Input.is_action_pressed(Player.ACTION_LIGHT):
				_queued = true
			if _elapsed >= _recovery():
				_end_swing()
				transition_to(LIGHT_ATTACK if _queued else neutral_state())


func _is_finisher() -> bool:
	return _step == FINISHER


func _clip() -> StringName:
	return COMBO_CLIPS[_step]


func _attack() -> AttackData:
	var combo := player.stats.light_combo
	return combo[mini(_step, combo.size() - 1)]


func _windup() -> float:
	return TUNING.finisher_windup_time if _is_finisher() else TUNING.swing_windup_time


func _strike() -> float:
	return TUNING.finisher_strike_time if _is_finisher() else TUNING.swing_strike_time


func _recovery() -> float:
	return TUNING.finisher_recovery_time if _is_finisher() else TUNING.swing_recovery_time


func _lunge() -> float:
	return TUNING.finisher_lunge_distance if _is_finisher() else TUNING.swing_lunge_distance


func _can_dodge_cancel() -> bool:
	return not _is_finisher() or _elapsed >= TUNING.finisher_dodge_delay


## Windup and strike: a press queues the next swing during swings 1 and 2; during
## the finisher it doesn't count.
func _take_attack_presses() -> void:
	if player.peek_buffer() == Player.ACTION_LIGHT:
		player.consume_buffer()
		if not _is_finisher():
			_queued = true


func _start_phase(phase: Phase) -> void:
	_phase = phase
	_elapsed = 0.0
	# The clip was built with its own phase lengths; stretch each to the tuning.
	var built := player.action_clip_phase_times(_clip())
	var wanted := Vector3(_windup(), _strike(), _recovery())
	if built[phase] > 0.0:
		player.set_action_speed(built[phase] / maxf(wanted[phase], 0.001))


func _end_swing() -> void:
	_last_end_time = _now()
	_next_step = (_step + 1) % COMBO_CLIPS.size()


## Hitbox yaw (Facing space, -Z forward, +X the player's right) at sweep progress t.
func _arc_angle(t: float) -> float:
	var degrees := TUNING.finisher_arc_degrees if _is_finisher() else TUNING.swing_arc_degrees
	var half := deg_to_rad(degrees) * 0.5
	# Rotating -Z by a negative yaw points it to +X (the right).
	return lerpf(half, -half, t) if _left_to_right else lerpf(-half, half, t)


## Finisher only: turns the model about its vertical axis by amount (-1..1) of
## finisher_body_twist_degrees, negative toward the right (wound up), positive
## toward the left (carried through the sweep). Visual only.
func _twist(amount: float) -> void:
	if not _is_finisher():
		return
	var yaw := deg_to_rad(TUNING.finisher_body_twist_degrees) * amount
	_model.transform = Transform3D(Basis(Vector3.UP, yaw) * _model_rest.basis, _model_rest.origin)


static func _ease_in_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
