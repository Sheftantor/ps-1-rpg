extends PlayerState
## Touching a save orb: the player stops, turns to the orb and plays TouchOrb
## (the free left hand reaches out, holds, comes back down). The orb dips to
## meet the hand as it reaches (SaveOrb.set_touch), and when the hand arrives
## the orb saves the game (SaveOrb.activate). Can't be hit or interrupted;
## presses during it are dropped. Clip built by
## res://scripts/tools/build_orb_touch_clip.gd.

const CLIP: StringName = &"TouchOrb"
const HAND_BONE: String = "mixamorig_LeftHand"

## Delay after the arm is fully out before the save happens (s).
@export var touch_delay: float = 0.05

var _orb: SaveOrb = null
var _elapsed: float = 0.0
var _touched: bool = false
## Reach, hold and lower lengths of the clip (s).
var _phases: Vector3 = Vector3.ZERO
var _skeleton: Skeleton3D = null
var _hand: int = -1


func enter(msg: Dictionary) -> void:
	_orb = msg.get("orb") as SaveOrb
	_elapsed = 0.0
	_touched = false
	if _skeleton == null:
		_skeleton = player.get_node(^"Facing/Model").find_children("*", "Skeleton3D")[0]
		_hand = _skeleton.find_bone(HAND_BONE)
	_phases = player.action_clip_phase_times(CLIP)
	player.set_horizontal_velocity(Vector3.ZERO)
	if _orb != null:
		player.snap_facing(_orb.global_position - player.global_position)
	player.play_action_clip(CLIP, 1.0)


func exit() -> void:
	if is_instance_valid(_orb):
		_orb.end_touch()


func drives_animation() -> bool:
	return true


func is_invulnerable() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	if player.peek_buffer() != &"":
		player.consume_buffer()
	player.move_horizontal(Vector3.ZERO, player.stats.deceleration, delta)
	if is_instance_valid(_orb):
		var hand_point := _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand).origin
		_orb.set_touch(hand_point, _reach_weight())
		if not _touched and _elapsed >= _phases.x + touch_delay:
			_touched = true
			_orb.activate(player)
	if _elapsed >= _phases.x + _phases.y + _phases.z:
		transition_to(neutral_state())


## How far the hand is out (0-1), following the clip's reach/hold/lower.
func _reach_weight() -> float:
	if _elapsed <= _phases.x:
		var u := _elapsed / maxf(_phases.x, 0.001)
		return u * u * (3.0 - 2.0 * u)
	if _elapsed <= _phases.x + _phases.y:
		return 1.0
	var v := clampf((_elapsed - _phases.x - _phases.y) / maxf(_phases.z, 0.001), 0.0, 1.0)
	return 1.0 - v * v * (3.0 - 2.0 * v)
