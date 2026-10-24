class_name SaveOrb
extends Node3D
## Souls-like rest point: a big low-poly pink orb floating over a stone plinth.
## Interacting (E / D-pad down) plays the player's OrbTouch state: they reach
## out and the orb dips to meet the hand. On contact (activate): full health
## and energy, the orb becomes the checkpoint you return to on death, the
## area's enemies come back at their posts and the game saves to the current
## slot (AreaTravel.rest_at). No loading screen or fade. Looted sacks stay looted.

## One word for the interact prompt.
@export var interact_verb: String = "SAVE"
@export var radius: float = 2.6
## Names the checkpoint (shown on the loading screen when respawning here).
@export var area_name: String = "Resting"
## Orb float: bob height (m), bob and spin speed.
@export var bob_height: float = 0.18
@export var bob_speed: float = 0.6
@export var spin_speed: float = 0.35
@export_group("Touch")
## How much of the orb's surface the hand sinks into at full reach (m), so it
## reads as contact rather than a near miss.
@export var touch_overlap: float = 0.04
## Glow flash when the game saves: peak multiplier on the glow and how long
## it takes to fade back (s).
@export var save_flash_energy: float = 4.0
@export var save_flash_time: float = 0.8
## HUD message on saving.
@export var saved_message: String = "GAME SAVED"

## Spawn point name AreaTravel stands the player at after a respawn.
const SPAWN_NAME := &"SaveOrbSpawn"
## The player state that plays the touch.
const TOUCH_STATE := &"OrbTouch"

var _time: float = 0.0
var _orb_height: float = 0.0
var _glow_energy: float = 0.0
var _flash: float = 1.0
## World point the orb's surface should meet, and how far towards it (0-1).
var _touch_point: Vector3 = Vector3.ZERO
var _touch_weight: float = 0.0

@onready var _orb: Node3D = $Orb
@onready var _body: MeshInstance3D = $Orb/Body
@onready var _glow: OmniLight3D = $Glow
@onready var _spawn: Marker3D = $SaveOrbSpawn


func _ready() -> void:
	add_to_group(&"interactables")
	_spawn.add_to_group(AreaTravel.SPAWN_GROUP)
	_orb_height = _orb.position.y
	_glow_energy = _glow.light_energy


func _process(delta: float) -> void:
	_time += delta
	var home := Vector3(0.0, _orb_height + sin(_time * bob_speed * TAU) * bob_height, 0.0)
	_orb.position = home
	if _touch_weight > 0.0:
		# Slide the orb along the line from the hand to its centre until its
		# surface reaches the hand.
		var center := to_global(home)
		var to_center := center - _touch_point
		var reach := to_center.length() - (orb_radius() - touch_overlap)
		if reach > 0.0:
			var touched := center - to_center.normalized() * reach
			_orb.position = home.lerp(to_local(touched), _touch_weight)
	_orb.rotation.y += spin_speed * delta
	_glow.light_energy = _glow_energy * _flash * (0.85 + 0.15 * sin(_time * bob_speed * TAU * 2.0))


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


func interact(player: Player) -> void:
	if player.state_machine.has_state(TOUCH_STATE):
		player.state_machine.transition_to(TOUCH_STATE, {orb = self})
	else:
		activate(player)


## World radius of the orb sphere.
func orb_radius() -> float:
	return (_body.mesh as SphereMesh).radius * _body.global_basis.get_scale().x


## Called every frame by the touch: the orb's surface moves weight (0-1) of
## the way to point.
func set_touch(point: Vector3, weight: float) -> void:
	_touch_point = point
	_touch_weight = clampf(weight, 0.0, 1.0)


func end_touch() -> void:
	_touch_weight = 0.0


## The hand reached the orb: refill, checkpoint, enemies back, save.
func activate(player: Player) -> void:
	player.health.set_current(player.health.max_health)
	player.stamina.set_current(player.stamina.maximum)
	AreaTravel.service().rest_at(self)
	player.hud.flash_message(saved_message)
	var tween := create_tween()
	tween.tween_property(self, ^"_flash", 1.0, save_flash_time).from(save_flash_energy) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
