class_name EnemySpawner
extends Node3D
## Spawns one enemy at each Marker3D child when the scene starts.

@export var enemy_scene: PackedScene


func _ready() -> void:
	var index := 0
	for child: Node in get_children():
		var marker := child as Marker3D
		if marker == null:
			continue
		index += 1
		var enemy := enemy_scene.instantiate() as Node3D
		enemy.name = "Enemy%d" % index
		add_child(enemy)
		enemy.global_position = marker.global_position
