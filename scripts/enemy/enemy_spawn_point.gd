class_name EnemySpawnPoint
extends Marker3D
## Spawns one enemy here when the level starts, at a level relative to the
## player's starting level, wandering its own patrol area around this marker.

@export var enemy_scene: PackedScene = preload("res://scenes/suit_guy.tscn")
## Levels above the player's starting level (PlayerStats.level). Negative = below.
@export var levels_above_player: int = 0
## Size (world X/Z, m) of the box around this marker the enemy wanders in.
@export var patrol_area: Vector2 = Vector2(5.0, 5.0)
## Where the player's starting level comes from.
@export var player_stats: PlayerStats = preload("res://resources/player/player_stats.tres")


func _ready() -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.level_override = maxi(1, player_stats.level + levels_above_player)
	enemy.patrol_area = patrol_area
	enemy.name = name.trim_suffix("Spawn")
	add_child(enemy)
