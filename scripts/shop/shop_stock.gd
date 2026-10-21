class_name ShopStock
extends Resource
## What a shop sells and how it deals. One per shop; edit it in the inspector
## (the 6-12's is res://resources/shop/store_612_stock.tres). A ShopCounter
## points at one and opens the ShopMenu with it.

## Shown as the shop screen's heading and window tag.
@export var shop_name: String = "6-12"
## The clerk's line when the screen opens.
@export_multiline var greeting: String = "Welcome in. Don't mind the rain."
## Said after a purchase / when the player can't afford something / after a sale.
@export var thanks_line: String = "Thank you, come again."
@export var broke_line: String = "You're short, friend."
@export var sold_line: String = "I'll take it off your hands."
@export var entries: Array[ShopEntry] = []
## Whether the SELL tab is offered.
@export var buys_items: bool = true
## Fraction of an item's price this shop pays when buying it from the player.
@export_range(0.0, 1.0, 0.05) var sell_rate: float = 0.5


## What this shop pays for one of item (at least 1 if the item has any value).
func sell_price(item: ItemData) -> int:
	if item == null or item.price <= 0:
		return 0
	return maxi(1, floori(item.price * sell_rate))
