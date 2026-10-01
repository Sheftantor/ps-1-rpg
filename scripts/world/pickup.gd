class_name Pickup
extends Node3D
## Something lying in the world that the player collects with the interact input
## (E / D-pad down) while within `radius`: a weapon for the gun slot, or a stack
## of loot for the inventory. Set one of `weapon` / `item`.

@export var weapon: WeaponData
@export var item: ItemStack
## One word for the interact prompt (shown next to the interact button icon).
@export var interact_verb: String = "PICKUP"
@export var radius: float = 1.6
## Scale of the displayed model. Weapon models are built in the character rig's
## units (the player model is scaled 1.8x), so they need enlarging to read here.
@export var display_scale: float = 2.5
@export var spin_speed: float = 1.5
@export var bob_height: float = 0.08

var _display: Node3D
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"pickups")
	_display = Node3D.new()
	_display.position.y = 0.6
	add_child(_display)
	if weapon != null and weapon.model != null:
		var model: Node3D = weapon.model.instantiate()
		model.scale = Vector3.ONE * display_scale
		_display.add_child(model)
	else:
		# Placeholder for loot until items have their own models.
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		(box.mesh as BoxMesh).size = Vector3(0.25, 0.25, 0.25)
		_display.add_child(box)


func _process(delta: float) -> void:
	_time += delta
	_display.rotation.y += spin_speed * delta
	_display.position.y = 0.6 + sin(_time * 2.0) * bob_height


func display_name() -> String:
	if weapon != null:
		return weapon.display_name
	if item != null and item.item != null:
		return "%s x%d" % [item.item.display_name, item.count]
	return "?"


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius
