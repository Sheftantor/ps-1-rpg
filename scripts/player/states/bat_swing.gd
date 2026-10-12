extends PlayerState
## The basic bat attack: one press, one deliberate side-to-side swing.
## Windup (the bat pulls back) -> strike (a fast ease-out sweep across the front:
## the arc hitbox is live and sweeps with it, with a small lunge) -> recovery
## (back to ready). Swings alternate like a pendulum, right-to-left then
## left-to-right, while each starts within swing_combo_window of the last one
## ending; after a longer pause the next starts from the right again. An attack
## press in the last swing_buffer_window of recovery queues the next swing;
## earlier presses are dropped. Only recovery can be cancelled, by the dodge.
## Damage and knockback are stats.light_combo[0]; every timing is in
## res://resources/combat_tuning.tres. Clips: SwingRL/SwingLR, built by
## res://scripts/tools/build_bat_swing_clips.gd from the Attack clip.

enum Phase { WINDUP, STRIKE, RECOVERY }

const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")
const CLIP_RIGHT_TO_LEFT: StringName = &"SwingRL"
const CLIP_LEFT_TO_RIGHT: StringName = &"SwingLR"

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _left_to_right: bool = false
var _queued: bool = false
var _clip: StringName = CLIP_RIGHT_TO_LEFT
## Direction the next swing takes if it starts within the combo window.
var _next_left_to_right: bool = false
## When the last swing ended (s since start, from Time).
var _last_end_time: float = -INF
var _pivot: Node3D = null
var _hitbox: Hitbox = null


func enter(_msg: Dictionary) -> void:
	if _pivot == null:
		_pivot = player.get_node(^"Facing/SwingArc")
		_hitbox = player.get_node(^"Facing/SwingArc/ArcHitbox")
		_hitbox.hit_landed.connect(_on_hit_landed)
	var within_combo := _now() - _last_end_time <= TUNING.swing_combo_window
	_left_to_right = _next_left_to_right if within_combo else false
	_clip = CLIP_LEFT_TO_RIGHT if _left_to_right else CLIP_RIGHT_TO_LEFT
	_queued = false
	player.hitbox.deactivate()
	player.swing_hitbox.deactivate()
	player.aim_attack()
	_pivot.rotation.y = _arc_angle(0.0)
	player.play_action_clip(_clip, 1.0)
	_start_phase(Phase.WINDUP)


func exit() -> void:
	_hitbox.deactivate()


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			_drop_attack_presses()
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			if _elapsed >= TUNING.swing_windup_time:
				_hitbox.activate(player.stats.light_combo[0], player)
				_start_phase(Phase.STRIKE)
		Phase.STRIKE:
			_drop_attack_presses()
			player.set_horizontal_velocity(player.forward() * TUNING.swing_lunge_distance / TUNING.swing_strike_time)
			var progress := clampf(_elapsed / TUNING.swing_strike_time, 0.0, 1.0)
			_pivot.rotation.y = _arc_angle(1.0 - (1.0 - progress) * (1.0 - progress))
			if _elapsed >= TUNING.swing_strike_time:
				_hitbox.deactivate()
				_start_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
			match player.peek_buffer():
				Player.ACTION_LIGHT:
					player.consume_buffer()
					_queued = TUNING.swing_recovery_time - _elapsed <= TUNING.swing_buffer_window
				Player.ACTION_DODGE:
					if player.can_dodge():
						player.consume_buffer()
						_end_swing()
						transition_to(DODGE)
						return
			if _elapsed >= TUNING.swing_recovery_time:
				_end_swing()
				transition_to(LIGHT_ATTACK if _queued else neutral_state())


## Presses during the windup and strike don't count.
func _drop_attack_presses() -> void:
	if player.peek_buffer() == Player.ACTION_LIGHT:
		player.consume_buffer()


func _start_phase(phase: Phase) -> void:
	_phase = phase
	_elapsed = 0.0
	# The clip was built with its own phase lengths; stretch each to the tuning.
	var built := player.action_clip_phase_times(_clip)
	var wanted := Vector3(TUNING.swing_windup_time, TUNING.swing_strike_time, TUNING.swing_recovery_time)
	if built[phase] > 0.0:
		player.set_action_speed(built[phase] / maxf(wanted[phase], 0.001))


func _end_swing() -> void:
	_last_end_time = _now()
	_next_left_to_right = not _left_to_right


## Hitbox yaw (Facing space, -Z forward, +X the player's right) at sweep progress t.
func _arc_angle(t: float) -> float:
	var half := deg_to_rad(TUNING.swing_arc_degrees) * 0.5
	# Rotating -Z by a negative yaw points it to +X (the right).
	return lerpf(half, -half, t) if _left_to_right else lerpf(-half, half, t)


func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	if TUNING.hit_stop_time <= 0.0 or Engine.time_scale != 1.0:
		return
	Engine.time_scale = TUNING.hit_stop_time_scale
	get_tree().create_timer(TUNING.hit_stop_time, true, false, true).timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	if is_equal_approx(Engine.time_scale, TUNING.hit_stop_time_scale):
		Engine.time_scale = 1.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
