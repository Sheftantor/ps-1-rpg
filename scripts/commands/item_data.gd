class_name ItemData
extends Resource
## A consumable. Takes effect as soon as the player is free to act (no use
## animation yet).

@export var display_name: String = ""
@export var icon: Texture2D
@export var heal_amount: int = 0
@export var stamina_restore: float = 0.0
