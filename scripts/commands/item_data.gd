class_name ItemData
extends Resource
## A consumable. Takes effect as soon as the player is free to act (no use
## animation yet).

@export var display_name: String = ""
## Flavour/help text shown under the gear on the status screen.
@export_multiline var description: String = ""
## Square picture for the HUD loadout row and status screen. Defaults to a placeholder.
@export var icon: Texture2D = preload("res://textures/ui/icons/placeholder_item.png")
@export var heal_amount: int = 0
@export var stamina_restore: float = 0.0
