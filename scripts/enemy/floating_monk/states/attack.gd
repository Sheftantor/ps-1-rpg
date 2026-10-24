extends MonkState
## The multi-arm combo: seven strikes, each a windup (the limbs pull back), a
## strike (they fly out ahead, hitbox live, a short lunge) and a recovery (they
## drift back). Strikes 1 and 2 are slow (stats.slow_swing_time), 3 to 6 rapid
## (stats.rapid_swing_time), two of them with two arms at once; strike 7 is the
## finisher, both blue arms thrust palms first (slow, FloatingMonk.finisher_*).
## Every strike tracks the player through its windup. With
## stats.combo_stagger_immune nothing interrupts it; then Recover.

## Each strike: [limbs, rapid].
const STRIKES := [
	[["Yellow Right Arm"], false],
	[["Red Left Arm"], false],
	[["Green Right Arm"], true],
	[["Purple Left Arm"], true],
	[["Yellow Right Arm", "Green Right Arm"], true],
	[["Red Left Arm", "Purple Left Arm"], true],
	[["Main Blue Right Arm", "Main Blue Left Arm"], false],
]
## Windup / strike shares of a strike; the rest is recovery.
const SLOW_SPLIT := Vector2(0.35, 0.2)
const RAPID_SPLIT := Vector2(0.3, 0.4)
## Limbs of the last strike stay out this far through recovery (Recover pulls
## them in).
const HELD_OUT := 0.6

var _elapsed: float = 0.0
var _strike: int = 0
var _striking: bool = false


func enter(_msg: Dictionary) -> void:
	monk.figure().clear_strikes()
	_start_strike(0)


func exit() -> void:
	monk.hitbox.deactivate()
	monk.combo_swing = 0
	_striking = false
	if not _finished():
		monk.figure().clear_strikes()


func can_be_staggered() -> bool:
	return not monk.stats.combo_stagger_immune and monk.poise_broken()


func physics_update(delta: float) -> void:
	_elapsed += delta
	var rapid: bool = STRIKES[_strike][1]
	var duration := maxf(monk.stats.rapid_swing_time if rapid else monk.stats.slow_swing_time, 0.05)
	var split := RAPID_SPLIT if rapid else SLOW_SPLIT
	var wind_end := duration * split.x
	var strike_end := duration * (split.x + split.y)
	var amount: float
	if _elapsed < wind_end:
		amount = -_ease_out(_elapsed / wind_end)
		monk.face_target(delta)
		monk.move_horizontal(Vector3.ZERO, monk.stats.acceleration, delta)
		_set_striking(false)
	elif _elapsed < strike_end:
		var t := (_elapsed - wind_end) / (strike_end - wind_end)
		amount = lerpf(-1.0, 1.0, minf(1.0, t * 2.5))
		monk.set_horizontal_velocity(monk.forward() * monk.current_attack.lunge_speed)
		_set_striking(true)
	else:
		var t := (_elapsed - strike_end) / maxf(duration - strike_end, 0.001)
		var last := _strike == STRIKES.size() - 1
		amount = lerpf(1.0, HELD_OUT if last else 0.0, t)
		monk.move_horizontal(Vector3.ZERO, monk.stats.acceleration, delta)
		_set_striking(false)
	for limb: String in STRIKES[_strike][0]:
		monk.figure().set_strike(limb, amount)
	if _elapsed >= duration:
		if _strike >= STRIKES.size() - 1:
			_strike += 1
			transition_to(RECOVER)
		else:
			for limb: String in STRIKES[_strike][0]:
				monk.figure().set_strike(limb, 0.0)
			_start_strike(_strike + 1)


func _start_strike(index: int) -> void:
	_strike = index
	_elapsed = 0.0
	monk.combo_swing = index + 1


func _finished() -> bool:
	return _strike >= STRIKES.size()


## Hitbox live only in the strike phase, freshly armed for each strike.
func _set_striking(striking: bool) -> void:
	if striking == _striking:
		return
	_striking = striking
	if striking:
		var finisher := _strike == STRIKES.size() - 1
		monk.hitbox.activate(monk.finisher_attack() if finisher else monk.combo_attack(), monk)
	else:
		monk.hitbox.deactivate()


static func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)
