extends PlayerState
## Bending down to a loot sack (Pickup.interact): the player stops, turns to the
## sack and plays LootBend (knees bend, back leans over, the right hand reaches
## down to it). At the bottom the loot window opens on the sack, then they
## straighten up. Presses on the way down are dropped; on the way up, moving or
## any action cuts the rise short, so looting mid-fight stays quick. Hits still
## land (HitStun takes over). Clip built by
## res://scripts/tools/build_loot_bend_clip.gd.

const CLIP: StringName = &"LootBend"

var _pickup: Pickup = null
var _elapsed: float = 0.0
var _opened: bool = false
## Down, hold and up lengths of the clip (s).
var _phases: Vector3 = Vector3.ZERO


func enter(msg: Dictionary) -> void:
	_pickup = msg.get("pickup") as Pickup
	_elapsed = 0.0
	_opened = false
	_phases = player.action_clip_phase_times(CLIP)
	player.set_horizontal_velocity(Vector3.ZERO)
	if _pickup != null:
		player.snap_facing(_pickup.global_position - player.global_position)
	player.play_action_clip(CLIP, 1.0)


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
	if not _opened:
		if player.peek_buffer() != &"":
			player.consume_buffer()
		if _elapsed >= _phases.x:
			_opened = true
			if is_instance_valid(_pickup) and not _pickup.is_queued_for_deletion():
				player.loot_window.open(_pickup)
		return
	if player.peek_buffer() != &"" or player.get_move_direction() != Vector3.ZERO \
			or _elapsed >= _phases.x + _phases.y + _phases.z:
		transition_to(neutral_state())
