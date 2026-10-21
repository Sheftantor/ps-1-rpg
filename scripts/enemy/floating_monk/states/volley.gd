extends MonkState
## The ranged attack: the bolt arms (FloatingMonk.bolt_arms) swing up toward the
## player and he crackles cyan for charge_time (the tell, still turning), then
## fires volley_count electric bolts, alternating arms every volley_interval,
## each at the player's chest as it is at that instant. Then back to Engage.
## If the player closes in during the charge and the combo is ready, he drops
## the volley and rushes instead.

const CHARGE_COLOR := Color(0.35, 0.85, 1.0)
## Peak strength of the charge flash, and of the pop on each shot (0-1).
const CHARGE_FLASH := 0.55
const SHOT_FLASH := 0.8
## How far the bolt arms swing out toward the player (strike amount).
const AIM_STRIKE := 0.55
## Arm shake while charging (degrees of strike amount, as a crackle).
const CRACKLE := 0.06
const CRACKLE_RATE := 40.0

var _timer: float = 0.0
var _shots: int = 0
var _charging: bool = true


func enter(_msg: Dictionary) -> void:
	_timer = monk.charge_time
	_shots = 0
	_charging = true


func exit() -> void:
	monk.reset_telegraph_visuals()
	for arm in monk.bolt_arms:
		monk.figure().set_strike(arm, 0.0)


func physics_update(delta: float) -> void:
	monk.move_horizontal(Vector3.ZERO, monk.stats.acceleration, delta)
	monk.face_target(delta)
	_timer -= delta
	if _charging:
		if monk.distance_to_target() <= monk.close_range and monk.combo_ready():
			transition_to(RUSH)
			return
		var t := 1.0 - clampf(_timer / maxf(monk.charge_time, 0.01), 0.0, 1.0)
		for i in monk.bolt_arms.size():
			var crackle := sin((_timer + i) * CRACKLE_RATE) * CRACKLE * t
			monk.figure().set_strike(monk.bolt_arms[i], AIM_STRIKE * smoothstep(0.0, 1.0, t) + crackle)
		monk.telegraph_flash = Color(CHARGE_COLOR, CHARGE_FLASH * t)
		if _timer <= 0.0:
			_charging = false
		return
	monk.telegraph_flash = Color(CHARGE_COLOR, monk.telegraph_flash.a * 0.85)
	if _timer > 0.0:
		return
	if _shots >= monk.volley_count:
		monk.bolt_cooldown = monk.volley_cooldown
		transition_to(ENGAGE)
		return
	monk.fire_bolt(monk.bolt_arms[_shots % monk.bolt_arms.size()])
	monk.telegraph_flash = Color(CHARGE_COLOR, SHOT_FLASH)
	_shots += 1
	_timer = monk.volley_interval
