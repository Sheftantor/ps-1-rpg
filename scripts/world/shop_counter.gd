class_name ShopCounter
extends Node3D
## The till in a shop. Interact (same prompt as loot and the save orb) to open
## the ShopMenu with this counter's stock. The menu is found in the "shop_menu"
## group, so any scene with a ShopMenu instance works (store_612.tscn has one).
## `opened` still fires, for anything else that wants to react (a clerk line,
## a sound, a custom UI of your own).

signal opened(player: Player)

## One word for the interact prompt.
@export var interact_verb: String = "SHOP"
## How close the player has to stand (m, flat).
@export var radius: float = 2.2
## What's for sale here.
@export var stock: ShopStock


func _ready() -> void:
	add_to_group(&"interactables")


func interact(player: Player) -> void:
	opened.emit(player)
	var menu := get_tree().get_first_node_in_group(&"shop_menu") as ShopMenu
	if menu == null:
		push_warning("ShopCounter: no ShopMenu in the scene (add res://scenes/shop_menu.tscn).")
		return
	if stock == null:
		push_warning("ShopCounter: no ShopStock set on %s." % name)
		return
	menu.open(stock)


func in_reach(point: Vector3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length() <= radius
