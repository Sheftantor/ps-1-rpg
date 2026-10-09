class_name Pickup
extends Node3D
## Loot lying in the world: always shown as a small burlap sack with a pulsing
## gold aura and sparkles (res://scenes/loot_sack.tscn), whatever is inside.
## Interact (E / D-pad down) within `radius` opens the loot window, where the
## player takes the contents one at a time: a weapon for the gun slot and/or a
## stack of items for the inventory. The sack disappears once it's empty.

const SACK: PackedScene = preload("res://scenes/loot_sack.tscn")

@export var weapon: WeaponData
@export var item: ItemStack
## One word for the interact prompt (shown next to the interact button icon).
@export var interact_verb: String = "LOOT"
@export var radius: float = 1.6
## Aura pulse: cycles per second and how far it swells.
@export var pulse_speed: float = 1.6
@export_range(0.0, 1.0) var pulse_amount: float = 0.18

var _aura: Node3D
var _glow: OmniLight3D
var _glow_energy: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"interactables")
	var sack: Node3D = SACK.instantiate()
	add_child(sack)
	_aura = sack.get_node(^"Aura")
	_glow = sack.get_node(^"Glow")
	_glow_energy = _glow.light_energy
	# Each sack starts at a different point in the pulse.
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	var pulse := sin(_time * pulse_speed * TAU) * 0.5 + 0.5
	_aura.scale = Vector3.ONE * (1.0 + pulse * pulse_amount)
	_glow.light_energy = _glow_energy * (0.75 + pulse * 0.5)


## What's still in the sack: WeaponData and/or ItemStack.
func contents() -> Array[Resource]:
	var out: Array[Resource] = []
	if weapon != null:
		out.append(weapon)
	if item != null and item.item != null and item.count > 0:
		out.append(item)
	return out


## Removes one entry (after the player takes it); an empty sack goes away.
func remove(entry: Resource) -> void:
	if entry == weapon:
		weapon = null
	elif entry == item:
		item = null
	if contents().is_empty():
		remove_from_group(&"interactables")
		AreaTravel.service().mark_collected(self)
		queue_free()


func interact(player: Player) -> void:
	player.loot_window.open(self)


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


## Name of one entry as the loot window lists it.
static func entry_name(entry: Resource) -> String:
	if entry is WeaponData:
		return (entry as WeaponData).display_name
	if entry is ItemStack:
		return (entry as ItemStack).item.display_name
	return "?"


static func entry_icon(entry: Resource) -> Texture2D:
	if entry is WeaponData:
		return (entry as WeaponData).icon
	if entry is ItemStack:
		return (entry as ItemStack).item.icon
	return null
