extends RigidBody3D
## A spent casing kicked out by SuppressedPistol.eject_casing(). Bounces off the
## world, then removes itself.

## Seconds before the casing is freed.
@export var lifetime: float = 2.0


func _ready() -> void:
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)
