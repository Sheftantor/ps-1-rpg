class_name LootDrop
extends Resource
## One line of an enemy's loot table (EnemyStats.loot): the item, the chance it
## goes in the sack the enemy drops on death, and how many.

@export var item: ItemData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.25
@export var count_min: int = 1
@export var count_max: int = 1


## A stack for the sack, or null when the roll misses.
func roll() -> ItemStack:
	if item == null or randf() >= chance:
		return null
	var stack := ItemStack.new()
	stack.item = item
	stack.count = randi_range(maxi(1, count_min), maxi(count_min, count_max))
	return stack
