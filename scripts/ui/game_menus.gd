class_name GameMenus
## The full-screen menus that pause the game and take over input (pause, status,
## inventory). Only one opens at a time; the player ignores input and physics
## while any is up. The loot window isn't one: the game runs on behind it.


static func any_open() -> bool:
	return PauseMenu.is_open or StatusMenu.is_open or InventoryMenu.is_open
