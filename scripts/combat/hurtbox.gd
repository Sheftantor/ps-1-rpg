class_name Hurtbox
extends Area3D
## The region of a character that can be hit. Hitboxes find it via collision layers
## and call receive_hit(); the owning character reacts to hit_received.

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
	hit_received.emit(attack, source)
	return true
