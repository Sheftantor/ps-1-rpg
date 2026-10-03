extends PlayerState
## Gun mode (gun_mode input, with a gun in the secondary slot and some stamina):
## sheathes the sword, draws the gun and brings time to a stop so shots can be
## lined up. Time eases from normal to stats.gun_slow_time_scale over
## stats.gun_slowdown_time real seconds, then (stats.gun_pause_after_slowdown)
## the scene tree pauses with only the player, camera and HUD still running.
##
## While aiming, a cursor sits on one of the enemies within the gun's lock_range:
##   moving the mouse sideways jumps it to the next enemy on that side of the
##     screen; target_next / target_prev (mouse wheel, D-pad) and lock_on step
##     through the list (nearest first),
##   attack_light queues a shot at the cursor target (the same enemy can be
##     queued again, up to stats.gun_max_queued_shots) for the gun's
##     shot_energy_cost in stamina,
##   gun_undo takes one shot at the cursor target (or else the last one queued)
##     off the queue and refunds its cost,
##   attack_heavy executes the queue,
##   gun_mode cancels: back to the sword with nothing fired.
## After stats.gun_drain_delay real seconds, bullet time drains stamina
## (stats.gun_energy_drain per second); it doesn't regenerate meanwhile. When it
## runs out the queue executes by itself and can't be cancelled. Executing
## restores normal time and fires the queued shots in order,
## stats.gun_shot_interval apart; targets that died meanwhile are skipped.

enum Phase { SLOWING, STOPPED, EXECUTING, RECOVERING }

## Queued targets, in the order their shots will fire.
var queue: Array[Enemy] = []

var _phase: Phase = Phase.SLOWING
var _phase_time: float = 0.0
var _last_ticks: int = 0
var _shot_timer: float = 0.0
var _targets: Array[Enemy] = []
var _cursor: Enemy = null
var _previous_lock: Enemy = null
var _aim_time: float = 0.0
var _mouse_travel: float = 0.0


func enter(_msg: Dictionary) -> void:
	_phase = Phase.SLOWING
	_phase_time = 0.0
	_last_ticks = Time.get_ticks_usec()
	queue.clear()
	_previous_lock = player.lock_target
	_aim_time = 0.0
	_mouse_travel = 0.0
	# Keep running (with the camera and HUD under us) once the tree pauses.
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.set_gun_drawn(true)
	_refresh_targets()
	_cursor = _previous_lock if _previous_lock in _targets else (_targets[0] if not _targets.is_empty() else null)
	player.hud.set_queue([])
	player.hud.show_targeting(true)


func exit() -> void:
	_resume_time()
	queue.clear()
	# Presses made while aiming shouldn't leak into sword mode.
	player.consume_buffer()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_gun_drawn(false)
	player.hud.set_queue([])
	player.hud.show_targeting(false)
	var keep_lock := is_instance_valid(_previous_lock) and _previous_lock.is_alive()
	player.lock_target = _previous_lock if keep_lock else null


func drives_animation() -> bool:
	return true


## Gun mode spends stamina; it doesn't refill until back in sword mode.
func stamina_regen_scale() -> float:
	return 0.0


## Moves the cursor `step` places along the target list (nearest first).
func cycle_target(step: int = 1) -> void:
	if not _is_aiming() or _targets.is_empty():
		return
	_cursor = _targets[posmod(_targets.find(_cursor) + step, _targets.size())]


## Sideways mouse movement: once it has travelled stats.gun_mouse_switch_distance
## in one direction, the cursor jumps to the nearest enemy on that side of it on screen.
func on_mouse_motion(dx: float) -> void:
	if not _is_aiming():
		return
	if signf(dx) != signf(_mouse_travel):
		_mouse_travel = 0.0
	_mouse_travel += dx
	if absf(_mouse_travel) < player.stats.gun_mouse_switch_distance:
		return
	var side := signf(_mouse_travel)
	_mouse_travel = 0.0
	var camera := player.camera()
	if _cursor == null or camera.is_position_behind(player.aim_point(_cursor)):
		return
	var from := camera.unproject_position(player.aim_point(_cursor)).x
	var best: Enemy = null
	var best_gap := INF
	for enemy in _targets:
		var point := player.aim_point(enemy)
		if enemy == _cursor or camera.is_position_behind(point):
			continue
		var gap := (camera.unproject_position(point).x - from) * side
		if gap > 0.0 and gap < best_gap:
			best = enemy
			best_gap = gap
	if best != null:
		_cursor = best


func physics_update(_delta: float) -> void:
	# Engine.time_scale scales delta, so gun mode keeps its own real-time clock.
	var now := Time.get_ticks_usec()
	# Clamped so time spent in the pause menu isn't counted as slowdown or drain.
	var real_delta := minf((now - _last_ticks) / 1_000_000.0, 0.1)
	_last_ticks = now
	_phase_time += real_delta
	player.set_horizontal_velocity(Vector3.ZERO)

	match _phase:
		Phase.SLOWING:
			var t := clampf(_phase_time / maxf(player.stats.gun_slowdown_time, 0.001), 0.0, 1.0)
			Engine.time_scale = lerpf(1.0, player.stats.gun_slow_time_scale, ease(t, 0.4))
			if t >= 1.0 and player.stats.gun_pause_after_slowdown:
				_stop_time()
		Phase.EXECUTING:
			_fire_next(real_delta)
		Phase.RECOVERING:
			if _phase_time >= player.stats.gun_fire_recovery:
				transition_to(neutral_state())
				return

	_refresh_targets()
	if _is_aiming():
		_aim_time += real_delta
		if _aim_time > player.stats.gun_drain_delay:
			player.stamina.drain(player.stats.gun_energy_drain * real_delta)
		if player.stamina.current <= 0.0:
			_execute()  # Out of energy: whatever is queued fires, no backing out.
		elif _handle_input():
			return
	if _cursor not in _targets:
		_cursor = _targets[0] if not _targets.is_empty() else null
	if _is_aiming():
		# The lock-on camera frames the cursor target while aiming.
		player.lock_target = _cursor
		if _cursor != null:
			player.snap_facing(_cursor.global_position - player.global_position)
	_update_hud()


## Returns true if it left the state.
func _handle_input() -> bool:
	match player.peek_buffer():
		Player.ACTION_LIGHT:
			player.consume_buffer()
			_queue_cursor()
		Player.ACTION_GUN_UNDO:
			player.consume_buffer()
			_undo()
		Player.ACTION_HEAVY:
			player.consume_buffer()
			_execute()
		Player.ACTION_GUN:
			player.consume_buffer()
			transition_to(neutral_state())  # Cancel: nothing fires.
			return true
	return false


func _queue_cursor() -> void:
	if _cursor == null:
		return
	if queue.size() >= player.stats.gun_max_queued_shots:
		player.hud.flash_message("QUEUE FULL")
		return
	if not player.stamina.has(player.gun.shot_energy_cost):
		player.hud.flash_message("NO ENERGY")
		return
	# Paid now; if that empties stamina, the queue executes next tick.
	player.stamina.drain(player.gun.shot_energy_cost)
	queue.append(_cursor)


func _undo() -> void:
	var index := queue.rfind(_cursor)
	if index == -1:
		index = queue.size() - 1
	if index == -1:
		return
	queue.remove_at(index)
	player.stamina.restore(player.gun.shot_energy_cost)


func _execute() -> void:
	_resume_time()
	_phase = Phase.EXECUTING
	_phase_time = 0.0
	_shot_timer = 0.0


## Fires the next queued shot once the interval has passed; recovers once the
## queue is empty.
func _fire_next(real_delta: float) -> void:
	_shot_timer -= real_delta
	if _shot_timer > 0.0:
		return
	while not queue.is_empty():
		var target: Enemy = queue.pop_front()
		if not is_instance_valid(target) or not target.is_alive():
			continue
		player.lock_target = target
		player.snap_facing(target.global_position - player.global_position)
		player.fire_gun(target)
		_shot_timer = player.stats.gun_shot_interval
		return
	_phase = Phase.RECOVERING
	_phase_time = 0.0


func _is_aiming() -> bool:
	return _phase == Phase.SLOWING or _phase == Phase.STOPPED


func _stop_time() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = true
	_phase = Phase.STOPPED
	_phase_time = 0.0


func _resume_time() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


## Living enemies within the gun's lock_range, nearest first.
func _refresh_targets() -> void:
	_targets.clear()
	var lock_range := player.gun.lock_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() and player.global_position.distance_to(enemy.global_position) <= lock_range:
			_targets.append(enemy)
	_targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))


func _update_hud() -> void:
	var hud := player.hud
	match _phase:
		Phase.SLOWING:
			hud.set_mode_text("BULLET TIME")
		Phase.STOPPED:
			hud.set_mode_text("TIME STOP")
		Phase.EXECUTING:
			hud.set_mode_text("EXECUTE")
		Phase.RECOVERING:
			hud.set_mode_text("")
	var portraits: Array[Texture2D] = []
	for enemy in queue:
		portraits.append(enemy.stats.portrait if is_instance_valid(enemy) else null)
	hud.set_queue(portraits)
	var points: Array[Vector3] = []
	for enemy in _targets:
		points.append(player.aim_point(enemy))
	var queued := PackedInt32Array()
	for enemy in queue:
		queued.append(_targets.find(enemy))
	var cursor := _cursor if _is_aiming() else null
	var distance := player.flat_distance_to(cursor) if cursor != null else INF
	hud.update_targeting(player.camera(), player.aim_origin(), points, _targets.find(cursor), queued,
			distance <= player.gun.effective_range, distance)
