class_name Hurtbox
extends Area3D
## The region of a character that can be hit. Hitboxes find it via collision layers
## and call receive_hit(); the owning character reacts to hit_received. Every hit
## in the game (bat, gun, enemy attacks) comes through here, so this is where
## the combat feedback (Feel.on_hit) is told, with the damage actually taken.

signal hit_received(attack: AttackData, source: Node3D)

## While true, hits are ignored (dash i-frames, post-hit grace, death).
var invulnerable: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true


## Returns true if the hit connected.
func receive_hit(attack: AttackData, source: Node3D) -> bool:
	if invulnerable:
		return false
	# The owner applies the damage in its hit_received handler; count what it took.
	var health := get_parent().get_node_or_null(^"Health") as Health
	var taken := [0]
	var count := func(amount: int) -> void: taken[0] += amount
	if health != null:
		health.damaged.connect(count)
	hit_received.emit(attack, source)
	if health != null:
		health.damaged.disconnect(count)
	Feel.on_hit(source, get_parent(), taken[0])
	return true
