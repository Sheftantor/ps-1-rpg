class_name LootDrop
extends Resource
## One line of an enemy's loot table (EnemyStats.loot): the item (or weapon),
## the chance it goes in the sack the enemy drops on death, and how many.

@export var item: ItemData
## A weapon instead of an item (MeleeWeaponData or WeaponData). A sack holds at
## most one weapon: the first weapon line that rolls wins.
@export var weapon: Resource
@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
@export var count_min: int = 1
@export var count_max: int = 1


## The weapon for the sack, or null when the roll misses (or this line is an item).
func roll_weapon() -> Resource:
	if weapon == null or randf() >= chance:
		return null
	return weapon


## A stack for the sack, or null when the roll misses.
func roll() -> ItemStack:
	if item == null or randf() >= chance:
		return null
	var stack := ItemStack.new()
	stack.item = item
	stack.count = randi_range(maxi(1, count_min), maxi(count_min, count_max))
	return stack
