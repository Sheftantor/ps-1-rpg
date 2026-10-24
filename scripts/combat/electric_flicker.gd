class_name ElectricFlicker
extends Node3D
## Makes an electric bolt crackle: every frame this node spins to a random roll
## around its own Z and jitters its width, so the cross-shaped spark meshes under
## it read as arcing. Used by res://scenes/electric_bolt.tscn.

## Width jitter: scale on X/Y is picked from 1 +/- this each frame.
@export_range(0.0, 1.0, 0.05) var width_jitter: float = 0.5


func _process(_delta: float) -> void:
	rotation.z = randf() * TAU
	var width := 1.0 + randf_range(-width_jitter, width_jitter)
	scale = Vector3(width, width, 1.0)
