class_name Health
extends Node
## Hit points for a character. The owner calls setup() with its stats' max health.

signal changed(current: int, maximum: int)
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


func take_damage(amount: int) -> void:
	if is_dead:
		return
	current = maxi(current - amount, 0)
	changed.emit(current, max_health)
	if is_dead:
		died.emit()
