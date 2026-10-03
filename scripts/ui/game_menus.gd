class_name GameMenus
## The full-screen menus that pause the game and take over input (pause, status,
## inventory, loot). Only one opens at a time; the player ignores input and
## physics while any is up.


static func any_open() -> bool:
	return PauseMenu.is_open or StatusMenu.is_open or InventoryMenu.is_open or LootWindow.is_open
