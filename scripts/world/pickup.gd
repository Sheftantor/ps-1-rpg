class_name Pickup
extends Node3D
## Loot lying in the world: always shown as a small burlap sack with a pulsing
## gold aura and sparkles (res://scenes/loot_sack.tscn), whatever is inside.
## Interact (E / D-pad down) within `radius` has the player bend down to it
## (the LootBend state), which opens the loot window, where the player takes
## the contents one at a time: a weapon for the gun slot, cash for the wallet
## and stacks of items for the inventory. The sack disappears once it's empty.
## Placed in a level, or dropped by a dying enemy (drop()).

const SACK: PackedScene = preload("res://scenes/loot_sack.tscn")
const LOOT_STATE := &"LootBend"
## Physics layers a dropped sack lands on (1 = world).
const GROUND_MASK := 1

@export var weapon: WeaponData
@export var item: ItemStack
## Cash inside (0 = none).
@export var money: int = 0
## More stacks of items, after `item`.
@export var items: Array[ItemStack] = []
## One word for the interact prompt (shown next to the interact button icon).
@export var interact_verb: String = "LOOT"
@export var radius: float = 1.6
## Aura pulse: cycles per second and how far it swells.
@export var pulse_speed: float = 1.6
@export_range(0.0, 1.0) var pulse_amount: float = 0.18

## Dropped at runtime (an enemy's loot), not placed in the scene: nothing to
## remember once it's emptied (AreaTravel.mark_collected).
var dropped: bool = false

var _aura: Node3D
var _glow: OmniLight3D
var _glow_energy: float = 0.0
var _time: float = 0.0
## The wallet entry for `money`, kept so the loot window sees the same one.
var _cash: LootCash = null


func _ready() -> void:
	if contents().is_empty():
		# A placed sack whose contents didn't load (e.g. `item` pointing at the
		# wrong sub-resource): say so instead of leaving an empty sack to find.
		push_warning("Loot sack %s is empty; removed." % get_path())
		queue_free()
		return
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


## Drops a sack holding money and stacks into the current scene: it pops out
## of `from` and lands on the ground below in a short arc. Null (and no sack)
## when there's nothing to put in it.
static func drop(tree: SceneTree, from: Vector3, cash: int, stacks: Array[ItemStack]) -> Pickup:
	var scene := tree.current_scene
	if scene == null or (cash <= 0 and stacks.is_empty()):
		return null
	var pickup := Pickup.new()
	pickup.dropped = true
	pickup.money = cash
	pickup.items = stacks
	scene.add_child(pickup)
	var ground := _ground_below(pickup, from)
	pickup.global_position = from
	pickup.toss_to(ground)
	return pickup


## Flies from where it is to `landing` in a small hop, with a little bounce.
func toss_to(landing: Vector3, time: float = 0.45) -> void:
	var start := global_position
	var peak := maxf(start.y, landing.y) + 0.6
	var tween := create_tween()
	tween.tween_method(_toss_step.bind(start, peak, landing), 0.0, 1.0, time)
	tween.tween_property(self, ^"global_position:y", landing.y + 0.08, 0.08).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"global_position:y", landing.y, 0.1).set_ease(Tween.EASE_IN)


## Point t (0-1) along the toss: straight across, on a parabola through the peak.
func _toss_step(t: float, start: Vector3, peak: float, landing: Vector3) -> void:
	var point := start.lerp(landing, t)
	point.y = lerpf(lerpf(start.y, peak, t), lerpf(peak, landing.y, t), t)
	global_position = point


static func _ground_below(node: Node3D, from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.5, from + Vector3.DOWN * 8.0, GROUND_MASK)
	var hit := node.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else from


## What's still in the sack: WeaponData, LootCash and/or ItemStacks.
func contents() -> Array[Resource]:
	var out: Array[Resource] = []
	if weapon != null:
		out.append(weapon)
	if money > 0:
		if _cash == null:
			_cash = LootCash.new()
		_cash.amount = money
		out.append(_cash)
	for stack: ItemStack in [item] + items:
		if stack != null and stack.item != null and stack.count > 0:
			out.append(stack)
	return out


## Removes one entry (after the player takes it); an empty sack goes away.
func remove(entry: Resource) -> void:
	if entry == weapon:
		weapon = null
	elif entry == item:
		item = null
	elif entry is LootCash:
		money = 0
	else:
		items.erase(entry)
	if contents().is_empty():
		remove_from_group(&"interactables")
		if not dropped:
			AreaTravel.service().mark_collected(self)
		queue_free()


## Bend down to it first (LootBend opens the window at the bottom); straight to
## the window when the player can't.
func interact(player: Player) -> void:
	if player.state_machine.has_state(LOOT_STATE):
		player.state_machine.transition_to(LOOT_STATE, {pickup = self})
	else:
		player.loot_window.open(self)


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius


## Name of one entry as the loot window lists it.
static func entry_name(entry: Resource) -> String:
	if entry is WeaponData:
		return (entry as WeaponData).display_name
	if entry is LootCash:
		return "$%d" % (entry as LootCash).amount
	if entry is ItemStack:
		return (entry as ItemStack).item.display_name
	return "?"


static func entry_icon(entry: Resource) -> Texture2D:
	if entry is WeaponData:
		return (entry as WeaponData).icon
	if entry is LootCash:
		return LootCash.ICON
	if entry is ItemStack:
		return (entry as ItemStack).item.icon
	return null
