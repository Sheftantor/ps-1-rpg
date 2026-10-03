class_name ArmorData
extends Resource
## One piece of the player's gear, worn in a single slot: clothing (shirt, neck,
## arms, belt, pants, shoes) or an accessory (two rings, two trinkets, a charm).
## Shown on the status screen; defense isn't applied to incoming damage yet.

## New slots go at the end so existing gear resources keep their slot.
enum Slot { SHIRT, NECK, ARMS, BELT, PANTS, SHOES, RING_1, RING_2, TRINKET_1, TRINKET_2, CHARM }

@export var display_name: String = ""
## Flavour/help text shown under the gear on the status screen.
@export_multiline var description: String = ""
@export var slot: Slot = Slot.SHIRT
@export var defense: int = 0
## Square picture for the status screen. Empty uses the slot's grey placeholder.
@export var icon: Texture2D
