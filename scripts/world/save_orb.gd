class_name SaveOrb
extends Node3D
## Souls-like rest point: a big low-poly pink orb floating over a stone plinth.
## Interacting (E / D-pad down) saves there: full health and energy, the orb
## becomes the checkpoint you return to on death (also written to disk by
## AreaTravel), and the area resets through the loading screen, so its regular
## enemies respawn. Looted sacks stay looted.

## One word for the interact prompt.
@export var interact_verb: String = "SAVE"
@export var radius: float = 2.6
## Shown on the loading screen while the area resets.
@export var area_name: String = "Resting"
## Orb float: bob height (m), bob and spin speed.
@export var bob_height: float = 0.18
@export var bob_speed: float = 0.6
@export var spin_speed: float = 0.35

## Spawn point name AreaTravel stands the player at after resting.
const SPAWN_NAME := &"SaveOrbSpawn"

var _time: float = 0.0
var _orb_height: float = 0.0
var _glow_energy: float = 0.0

@onready var _orb: Node3D = $Orb
@onready var _glow: OmniLight3D = $Glow
@onready var _spawn: Marker3D = $SaveOrbSpawn


func _ready() -> void:
	add_to_group(&"interactables")
	_spawn.add_to_group(AreaTravel.SPAWN_GROUP)
	_orb_height = _orb.position.y
	_glow_energy = _glow.light_energy


func _process(delta: float) -> void:
	_time += delta
	_orb.position.y = _orb_height + sin(_time * bob_speed * TAU) * bob_height
	_orb.rotation.y += spin_speed * delta
	_glow.light_energy = _glow_energy * (0.85 + 0.15 * sin(_time * bob_speed * TAU * 2.0))


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


func interact(player: Player) -> void:
	player.health.set_current(player.health.max_health)
	player.stamina.set_current(player.stamina.maximum)
	AreaTravel.service().rest_at(self)
