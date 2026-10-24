extends MonkState
## After the finisher he's spent: the blue arms slowly come back to prayer
## while he drifts backwards. For stats.vulnerable_time he can't attack, takes
## stats.vulnerable_damage_multiplier damage, and any hit staggers him whatever
## his poise. stats.combo_cooldown runs from the end, then Engage.

const DRIFT_BACK_SPEED := 1.2
## The finisher's limbs (held out by Attack).
const FINISHER_LIMBS: PackedStringArray = ["Main Blue Right Arm", "Main Blue Left Arm"]

var _elapsed: float = 0.0
var _duration: float = 0.0


func enter(_msg: Dictionary) -> void:
	_elapsed = 0.0
	_duration = maxf(monk.stats.vulnerable_time, 0.1)
	monk.set_vulnerable(monk.stats.vulnerable_time)


func exit() -> void:
	monk.figure().clear_strikes()
	monk.start_combo_cooldown(monk.stats.combo_cooldown)


func can_be_staggered() -> bool:
	return true


func is_exposed() -> bool:
	return true


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	monk.set_horizontal_velocity(-monk.forward() * DRIFT_BACK_SPEED * (1.0 - t))
	for limb in FINISHER_LIMBS:
		monk.figure().set_strike(limb, lerpf(0.6, 0.0, smoothstep(0.0, 1.0, t)))
	if _elapsed >= _duration:
		transition_to(ENGAGE)
