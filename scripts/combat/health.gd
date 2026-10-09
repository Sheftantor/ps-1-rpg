class_name Health
extends Node
## Hit points for a character. The owner calls setup() with its stats' max health.

signal changed(current: int, maximum: int)
## A hit landed for `amount` (the hit's damage, even if less health was left).
signal damaged(amount: int)
signal died

@export var max_health: int = 100

var current: int = 0
var is_dead: bool:
	get:
		return current <= 0


func _ready() -> void:
	current = max_health


func setup(maximum: int) -> void:
	max_health = maximum
	current = maximum
	changed.emit(current, max_health)


## Sets health directly (e.g. carried over from the last area); no damage events.
func set_current(value: int) -> void:
	current = clampi(value, 0, max_health)
	changed.emit(current, max_health)


func heal(amount: int) -> void:
	if is_dead:
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, max_health)
	if amount > 0:
		damaged.emit(amount)
	if is_dead:
		died.emit()
