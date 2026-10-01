class_name ArmorData
extends Resource
## One piece of the player's armour set, worn in a single slot. Shown on the
## status screen; defense isn't applied to incoming damage yet.

enum Slot { SHIRT, NECK, ARMS, BELT, PANTS, SHOES }

@export var display_name: String = ""
@export var slot: Slot = Slot.SHIRT
@export var defense: int = 0
