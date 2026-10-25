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
## fresh press in the last swing_buffer_window of its recovery queues a new
## combo: holding the button plays the combo once and stops at the finisher. Each swing: windup (the weapon pulls back) -> strike (a fast
## ease-out sweep; the arc hitbox is live and sweeps with it, with a small
## lunge) -> recovery. Only recovery can be cancelled, by the dodge.
## The ground finisher launches what it staggers into the air. Swinging while
## airborne is the air combo: the air clips (AirSwingRL / AirSwingLR /
## AirSwingFinisher, legs tucked under) with the body leaning into each swing
## and spinning round with the sweep, the finisher somersaulting forward into
## an overhead slam. Each swing hops the player up a little and cuts gravity,
## homes toward a locked target's height, and pops the target up to keep it
## floating; the third air swing slams it down (Air Combo in the tuning).
## Damage and knockback: stats.light_combo[0], [1], [2] (Light 1-3). Timing in
## res://resources/combat_tuning.tres. Clips SwingRL / SwingLR / SwingFinisher,
## built by res://scripts/tools/build_melee_swing_clips.gd from the Attack clip.

enum Phase { WINDUP, STRIKE, RECOVERY }

const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")
const COMBO_CLIPS: Array[StringName] = [&"SwingRL", &"SwingLR", &"SwingFinisher"]
const AIR_COMBO_CLIPS: Array[StringName] = [&"AirSwingRL", &"AirSwingLR", &"AirSwingFinisher"]
const KNOCKDOWN_POSE := preload("res://scripts/combat/knockdown_pose.gd")
## Height (m, in Facing space) the air somersault turns about: the hips.
const FLIP_PIVOT_HEIGHT := 0.9
## Share of the air finisher's somersault done during its windup (the rest in the strike).
const FLIP_IN_WINDUP := 0.45
## Swing direction per combo step (the finisher sweeps right-to-left).
const COMBO_LEFT_TO_RIGHT: Array[bool] = [false, true, false]
const FINISHER := 2

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _left_to_right: bool = false
var _queued: bool = false
## Started in the air: an air combo swing.
var _airborne: bool = false
## Combo step of this swing (0, 1, or FINISHER) and of the next if it chains.
var _step: int = 0
var _next_step: int = 0
## When the last swing ended (s since start, from Time).
var _last_end_time: float = -INF
var _pivot: Node3D = null
var _hitbox: Hitbox = null
var _model: Node3D = null
var _model_rest: Transform3D
## Knows where the blade tip is (WeaponTrail.blade_tip on the weapon mount).
var _trail: WeaponTrail = null
var _pivot_rest_scale: Vector3 = Vector3.ONE


func enter(_msg: Dictionary) -> void:
	if _pivot == null:
		_pivot = player.get_node(^"Facing/SwingArc")
		_hitbox = player.get_node(^"Facing/SwingArc/ArcHitbox")
		_model = player.get_node(^"Facing/Model")
		_model_rest = _model.transform
		_trail = player.get_node(^"Facing/Model/Skeleton3D/RightHandAttachment/MeleeWeapon/WeaponTrail")
		_pivot_rest_scale = _pivot.scale
	var chained := _now() - _last_end_time <= TUNING.swing_combo_window
	_step = _next_step if chained else 0
	_left_to_right = COMBO_LEFT_TO_RIGHT[_step]
	_queued = false
	_airborne = not player.is_on_floor()
	if _airborne:
		# Swinging stops the jump's rise (gravity is low now, so it would carry
		# on for seconds): just the small hop.
		player.velocity.y = TUNING.air_swing_hop
	player.hitbox.deactivate()
	player.swing_hitbox.deactivate()
	player.aim_attack()
	# Whole rotation: the air finisher tips the hitbox over with the flip.
	_pivot.rotation = Vector3(0.0, _arc_angle(0.0), 0.0)
	_pivot.scale = _pivot_rest_scale * (TUNING.finisher_reach_scale if _is_finisher() else 1.0)
	player.play_action_clip(_clip(), 1.0)
	_start_phase(Phase.WINDUP)


func exit() -> void:
	_hitbox.deactivate()
	_pivot.scale = _pivot_rest_scale
	_pivot.rotation = Vector3.ZERO
	_model.transform = _model_rest


func drives_animation() -> bool:
	return true


func gravity_scale() -> float:
	return TUNING.air_swing_gravity_scale if _airborne else 1.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			_take_attack_presses()
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			_twist(-0.4 * _ease_in_out(_elapsed / _windup()))
			var wound := _ease_in_out(_elapsed / _windup())
			# The air finisher's somersault starts in the windup.
			_air_motion(wound, FLIP_IN_WINDUP * wound if _is_finisher() else 0.0)
			if _elapsed >= _windup():
				_follow_weapon()
				_hitbox.activate(player.melee_attack(_swing_attack()), player)
				_start_phase(Phase.STRIKE)
		Phase.STRIKE:
			_take_attack_presses()
			player.set_horizontal_velocity(player.forward() * _lunge() / _strike())
			_home_to_target_height()
			var progress := clampf(_elapsed / _strike(), 0.0, 1.0)
			var sweep := 1.0 - (1.0 - progress) * (1.0 - progress)
			_pivot.rotation.y = _arc_angle(sweep)
			_twist(lerpf(-0.4, 0.6, sweep))
			_air_motion(1.0, lerpf(FLIP_IN_WINDUP, 1.0, sweep) if _is_finisher() else sweep)
			_follow_weapon()
			if _elapsed >= _strike():
				_hitbox.deactivate()
				_start_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			_twist(0.6 * (1.0 - _ease_in_out(_elapsed / _recovery())))
			_air_motion(1.0 - _ease_in_out(_elapsed / _recovery()), 1.0)
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
			# Holding carries swings 1 and 2 on, but not past the finisher: one
			# combo per hold, so it never loops.
			if in_buffer and TUNING.swing_hold_to_combo and not _is_finisher() \
					and Input.is_action_pressed(Player.ACTION_LIGHT):
				_queued = true
			if _elapsed >= _recovery():
				_end_swing()
				transition_to(LIGHT_ATTACK if _queued else neutral_state())


func _is_finisher() -> bool:
	return _step == FINISHER


func _clip() -> StringName:
	return AIR_COMBO_CLIPS[_step] if _airborne else COMBO_CLIPS[_step]


func _attack() -> AttackData:
	var combo := player.stats.light_combo
	return combo[mini(_step, combo.size() - 1)]


## This swing's hit: the combo step's numbers, plus the ground finisher's
## launch, or on an air swing the lift that keeps the target floating (the air
## finisher's slam instead). Finishers get the heavy hit feedback.
func _swing_attack() -> AttackData:
	var attack := _attack().duplicate() as AttackData
	attack.heavy_hit = attack.heavy_hit or _is_finisher()
	if not _airborne:
		if _is_finisher():
			attack.launch_speed = TUNING.finisher_launch_speed
			attack.hang_time = TUNING.finisher_hang_time
	elif _is_finisher():
		attack.launch_speed = TUNING.air_finisher_slam
	else:
		attack.launch_speed = TUNING.air_hit_lift
		attack.hang_time = TUNING.air_hit_hang_time
		attack.knockback *= TUNING.air_knockback_scale
	return attack


## Air swing at a locked target: rise or sink toward its height so the arc reaches it.
func _home_to_target_height() -> void:
	if not _airborne or player.is_on_floor() or player.lock_target == null:
		return
	var gap := player.lock_target.global_position.y - player.global_position.y
	player.velocity.y = clampf(gap * TUNING.air_home_rate, -TUNING.air_home_max_speed, TUNING.air_home_max_speed)


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
	if not _is_finisher() or _airborne:
		return
	var yaw := deg_to_rad(TUNING.finisher_body_twist_degrees) * amount
	_model.transform = Transform3D(Basis(Vector3.UP, yaw) * _model_rest.basis, _model_rest.origin)


## Air swings 1 and 2 with the spin on: the body turns a full circle.
func _spins() -> bool:
	return _airborne and not _is_finisher() and TUNING.air_swing_spin


## Air swings, where the body's spin or somersault carries the weapon off the
## fixed arc: keep the hitbox on the weapon instead. The spins turn it round
## (yaw only, staying level); the finisher's flip points it straight at the
## blade tip, tipping over with the body.
func _follow_weapon() -> void:
	if _spins():
		_pivot.rotation.y = _weapon_yaw()
	elif _airborne and _is_finisher():
		var to_tip := _blade_tip_local() - _pivot.position
		if to_tip.length_squared() < 0.0001:
			return
		# Roll it with the body, so it doesn't twist as the flip goes overhead.
		var up := _model.transform.basis.y.normalized()
		if absf(to_tip.normalized().dot(up)) > 0.98:
			up = _model.transform.basis.z.normalized()
		# Setting the quaternion keeps the finisher's reach scale.
		_pivot.quaternion = Basis.looking_at(to_tip, up).get_rotation_quaternion()


## The blade tip in Facing space (the hitbox pivot's parent).
func _blade_tip_local() -> Vector3:
	var mount := _trail.get_parent() as Node3D
	return (_pivot.get_parent() as Node3D).global_transform.affine_inverse() * (mount.global_transform * _trail.blade_tip)


## Yaw (Facing space, as _arc_angle) pointing from the player's centre at the
## blade tip right now.
func _weapon_yaw() -> float:
	var local := _blade_tip_local()
	if Vector2(local.x, local.z).length_squared() < 0.0001:
		return _pivot.rotation.y
	# Rotating -Z by yaw gives (-sin yaw, -cos yaw).
	return atan2(-local.x, -local.z)


## Air swings only, visual: the body leans forward by `lean` (0..1) of
## air_swing_lean_degrees, and `turn` (0..1) is how far through its spin (swings
## 1 and 2, once round with the sweep) or its forward somersault (the finisher).
func _air_motion(lean: float, turn: float) -> void:
	if not _airborne:
		return
	var pitch := -deg_to_rad(TUNING.air_swing_lean_degrees) * lean
	var yaw := 0.0
	if _is_finisher():
		pitch -= TAU * turn
	elif TUNING.air_swing_spin:
		# Right-to-left sweeps spin to the left (positive yaw), and vice versa.
		yaw = TAU * turn * (-1.0 if _left_to_right else 1.0)
	_model.transform = Transform3D(Basis(Vector3.UP, yaw)) * KNOCKDOWN_POSE.apply(_model_rest, pitch, FLIP_PIVOT_HEIGHT)


static func _ease_in_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
