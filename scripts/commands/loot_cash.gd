class_name LootCash
extends Resource
## Cash in a loot sack (Pickup.money). Taking it adds amount to the wallet.

const ICON: Texture2D = preload("res://textures/ui/icons/item_cash.png")

@export var amount: int = 0
