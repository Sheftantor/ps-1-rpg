class_name Stamina
extends Node
## Stamina pool. The owner calls setup() with its stats, then regenerate() every
## physics tick. Spending pauses regeneration for regen_delay seconds.

signal changed(current: float, maximum: float)

var maximum: float = 100.0
var current: float = 0.0
var regen_delay: float = 0.0

var _delay_timer: float = 0.0


func setup(max_value: float, delay: float) -> void:
	maximum = max_value
	current = max_value
	regen_delay = delay
	changed.emit(current, maximum)


func has(amount: float) -> bool:
	return current >= amount


## Takes amount if there's enough; otherwise takes nothing and returns false.
func spend(amount: float) -> bool:
	if not has(amount):
		return false
	drain(amount)
	return true


## Takes up to amount even if that empties the pool.
func drain(amount: float) -> void:
	current = maxf(current - amount, 0.0)
	_delay_timer = regen_delay
	changed.emit(current, maximum)


func restore(amount: float) -> void:
	current = minf(current + amount, maximum)
	changed.emit(current, maximum)


## rate is stamina per second.
func regenerate(delta: float, rate: float) -> void:
	if _delay_timer > 0.0:
		_delay_timer -= delta
		return
	if current < maximum:
		restore(rate * delta)
