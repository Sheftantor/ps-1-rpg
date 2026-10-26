class_name WaveSpawner
extends Node3D
## Sends `waves` at the player one after another: each wave comes `interval`
## seconds after every enemy of the last one is dead. Enemies appear at the Marker3D
## children nearest the player (but not on top of them) and hunt: their patrol
## centre follows the player, so they wander in until they spot them. After the
## last wave it repeats that one, a level higher each time.

@export var waves: Array[EnemyWave] = []
## Seconds from clearing a wave to the next one.
@export var interval: float = 30.0
## Seconds before the first wave.
@export var first_wave_delay: float = 3.0
## Spawn markers closer to the player than this (m) are skipped.
@export var min_spawn_distance: float = 7.0
## How many of the nearest usable markers a wave spreads over.
@export var spawn_marker_count: int = 4
## Wave enemies spot the player from this far (m) and never lose interest
## (ranged ones still need line of sight).
@export var hunt_range: float = 80.0

var _wave_index: int = 0
var _timer: float = 0.0
var _alive: Array[Enemy] = []


func _ready() -> void:
	_timer = first_wave_delay


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or waves.is_empty():
		return
	for i in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]) or not _alive[i].is_alive():
			_alive.remove_at(i)
		else:
			_alive[i].home_position = player.global_position
	if not _alive.is_empty():
		return
	if _wave_index > 0 and _timer <= 0.0:
		# The last wave just fell: the countdown to the next one starts now.
		_timer = interval
		player.hud.flash_message("WAVE %d CLEARED - NEXT IN %ds" % [_wave_index, roundi(interval)])
	_timer -= delta
	if _timer <= 0.0:
		_send_wave(player)


func _send_wave(player: Player) -> void:
	var wave := waves[mini(_wave_index, waves.size() - 1)]
	var level := wave.level + maxi(0, _wave_index - (waves.size() - 1))
	_wave_index += 1
	player.hud.flash_message("WAVE %d INCOMING" % _wave_index)
	var markers := _spawn_markers(player.global_position)
	if markers.is_empty():
		push_warning("WaveSpawner %s has no Marker3D children to spawn at." % get_path())
		return
	for i in wave.enemies.size():
		var enemy := wave.enemies[i].instantiate() as Enemy
		enemy.level_override = level
		enemy.patrol_area = Vector2(4.0, 4.0)
		_hunt(enemy)
		var spread := Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		enemy.position = to_local(markers[i % markers.size()].global_position + spread)
		add_child(enemy)
		_alive.append(enemy)


## Stretches the enemy's senses to hunt_range: its own copy of the stats (the
## shared ones stay as they are) and, for the ranged kinds, their sight ranges.
func _hunt(enemy: Enemy) -> void:
	enemy.stats = enemy.stats.duplicate()
	enemy.stats.detection_radius = hunt_range
	enemy.stats.lose_interest_radius = hunt_range
	for property: StringName in [&"detect_range", &"lose_range"]:
		if property in enemy:
			enemy.set(property, hunt_range)


## The markers nearest the player outside min_spawn_distance, nearest first.
func _spawn_markers(player_position: Vector3) -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	for child: Node in get_children():
		var marker := child as Marker3D
		if marker != null and marker.global_position.distance_to(player_position) >= min_spawn_distance:
			markers.append(marker)
	markers.sort_custom(func(a: Marker3D, b: Marker3D) -> bool:
		return a.global_position.distance_squared_to(player_position) < b.global_position.distance_squared_to(player_position))
	return markers.slice(0, spawn_marker_count)
