class_name ShopEntry
extends Resource
## One line on a shop's shelf: an item and what this shop charges for it.

@export var item: ItemData
## Price for one. -1 uses the item's own price (ItemData.price).
@export var price: int = -1


func unit_price() -> int:
	if price >= 0:
		return price
	return item.price if item != null else 0
