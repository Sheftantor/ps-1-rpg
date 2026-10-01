class_name LevelExit
extends Area3D
## Loads `next_scene` when the player walks in. Needs a CollisionShape3D child;
## the mask should include the player's layer (2).

@export_file("*.tscn") var next_scene: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not next_scene.is_empty():
		get_tree().change_scene_to_file.call_deferred(next_scene)
