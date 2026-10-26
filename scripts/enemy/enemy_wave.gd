class_name EnemyWave
extends Resource
## One wave for a WaveSpawner: the enemies it sends (one entry per enemy, so
## repeat a scene to send several) and the level they come in at.

@export var enemies: Array[PackedScene] = []
@export_range(1, 99) var level: int = 1
