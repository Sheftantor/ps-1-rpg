class_name ShopMenu
extends CanvasLayer
## Shop screen, opened by interacting with a ShopCounter (which passes its
## ShopStock). Two tabs: BUY (the stock's entries, at their prices) and SELL
## (what the player carries, at the stock's sell rate). The goods are a grid of
## the inventory's IconSlots; hover or controller focus shows the speech bubble
## and the description panel, click pins. Trade the selected slot with a
## right-click, the interact input (E), or the button under the grid. The
## next_item input (or the tab buttons) switches tabs. ui_cancel, pause or the
## window's close button leaves. Pauses the game and frees the mouse while open,
## like the inventory.
## Layout and styling live in res://scenes/shop_menu.tscn: restyle it freely,
## just keep the node names this script looks up.

## True while the screen is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

enum Mode { BUY, SELL }

const CURRENCY := "$"
## [action, word] for each prompt under the grid (all clickable).
const PROMPTS: Array = [
	[&"interact", "BUY / SELL"],
	[&"next_item", "SWITCH TAB"],
	[&"ui_cancel", "LEAVE"],
]
const PROMPT_PIXEL_SCALE := 2
const EMPTY_HINT := "Point at something for details. Right-click (or E) to trade it."

var _player: Player = null
var _stock: ShopStock = null
var _mode: Mode = Mode.BUY
var _was_paused: bool = false
var _board: SlotBoard
## Slot -> {item: ItemData, price: int}
var _goods: Dictionary[IconSlot, Dictionary] = {}
## The slot last pointed at, so the button still knows what to trade after
## the mouse leaves the grid.
var _last_slot: IconSlot = null

@onready var _root: Control = $Root
@onready var _title: Label = $Root/Title
@onready var _window: Win95Window = $Root/Window
@onready var _greeting: Label = $Root/Window/Layout/Greeting
@onready var _buy_tab: Button = $Root/Window/Layout/Tabs/BuyTab
@onready var _sell_tab: Button = $Root/Window/Layout/Tabs/SellTab
@onready var _grid: GridContainer = $Root/Window/Layout/Grid
@onready var _wallet: Label = $Root/Window/Layout/Footer/Wallet
@onready var _action: Button = $Root/Window/Layout/Footer/Action
@onready var _prompts: HBoxContainer = $Root/Window/Layout/Prompts


func _ready() -> void:
	add_to_group(&"shop_menu")
	_root.visible = false
	_board = SlotBoard.new($Root/Bubble, $Root/Window/Layout/Description/Lines/Title,
		$Root/Window/Layout/Description/Lines/Body, "SHELF", EMPTY_HINT)
	_board.slot_right_clicked.connect(_trade)
	_buy_tab.pressed.connect(_set_mode.bind(Mode.BUY))
	_sell_tab.pressed.connect(_set_mode.bind(Mode.SELL))
	_action.pressed.connect(func() -> void: _trade(_current_slot()))
	_window.close_requested.connect(close)
	_build_prompts()
	ActiveDevice.connect_changed(_on_device_changed)


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"interact"):
		_trade(_current_slot())
	elif event.is_action_pressed(&"next_item"):
		_set_mode(Mode.SELL if _mode == Mode.BUY else Mode.BUY)
	else:
		return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Opens the shop with stock. Does nothing if another full-screen menu is up.
func open(stock: ShopStock) -> void:
	if is_open or stock == null or GameMenus.any_open():
		return
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_stock = stock
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.hud.visible = false
	_title.text = stock.shop_name.to_upper()
	_window.tag = stock.shop_name.to_upper()
	_greeting.text = stock.greeting
	_sell_tab.visible = stock.buys_items
	_mode = Mode.BUY
	_last_slot = null
	_build()
	_root.visible = true
	_on_device_changed(ActiveDevice.using_gamepad)


func close() -> void:
	if not is_open:
		return
	is_open = false
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_board.hide_bubble()
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root.visible = false
	if is_instance_valid(_player):
		_player.hud.visible = true


# --- Grid -----------------------------------------------------------------------

func _build() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_board.clear()
	_goods.clear()
	_last_slot = null
	_buy_tab.button_pressed = _mode == Mode.BUY
	_sell_tab.button_pressed = _mode == Mode.SELL
	_wallet.text = "CASH  %s%d" % [CURRENCY, _player.money]
	if _mode == Mode.BUY:
		for entry: ShopEntry in _stock.entries:
			if entry != null and entry.item != null:
				_add_good(entry.item, entry.unit_price(), _carried(entry.item))
	else:
		for stack: ItemStack in _player.inventory:
			if stack.item != null:
				_add_good(stack.item, _stock.sell_price(stack.item), stack.count)
	if _goods.is_empty():
		var slot := SlotBoard.new_slot(_grid)
		var body := "Your bag is empty." if _mode == Mode.SELL else "Sold out."
		_board.add(slot, "EMPTY", "NOTHING HERE", body, slot.show_empty.bind(""))
	_refresh_action()


func _add_good(item: ItemData, price: int, carried: int) -> void:
	var slot := SlotBoard.new_slot(_grid)
	var item_name := item.display_name.to_upper()
	var price_text := "%s%d" % [CURRENCY, price] if price > 0 else ("FREE" if _mode == Mode.BUY else "NO VALUE")
	var effects := PackedStringArray()
	if item.heal_amount > 0:
		effects.append("RESTORES %d HP" % item.heal_amount)
	if item.stamina_restore > 0.0:
		effects.append("RESTORES %d ENERGY" % roundi(item.stamina_restore))
	effects.append("%s %s" % ["PRICE" if _mode == Mode.BUY else "PAYS", price_text])
	effects.append("CARRYING %d" % carried)
	var column := (_grid.get_child_count() - 1) % _grid.columns
	_board.add(slot, item_name + "\n" + price_text, item_name, GearText.join(item.description, "   ".join(effects)),
		slot.show_icon.bind(item.icon, "", carried if _mode == Mode.SELL else 0), column >= _grid.columns - 2)
	slot.focus_entered.connect(_on_slot_focused.bind(slot))
	_goods[slot] = {item = item, price = price}


func _carried(item: ItemData) -> int:
	for stack: ItemStack in _player.inventory:
		if stack.item == item:
			return stack.count
	return 0


func _on_slot_focused(slot: IconSlot) -> void:
	_last_slot = slot
	_refresh_action()


## The slot a trade applies to: the focused one, else the pinned one, else the
## last one pointed at.
func _current_slot() -> IconSlot:
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused is IconSlot and _goods.has(focused):
		return focused as IconSlot
	if _board.pinned != null and _goods.has(_board.pinned):
		return _board.pinned
	if is_instance_valid(_last_slot) and _goods.has(_last_slot):
		return _last_slot
	return null


func _refresh_action() -> void:
	var verb := "BUY" if _mode == Mode.BUY else "SELL"
	var slot := _current_slot()
	if slot == null:
		_action.text = verb
		_action.disabled = true
		return
	var good: Dictionary = _goods[slot]
	_action.text = "%s %s  %s%d" % [verb, (good.item as ItemData).display_name.to_upper(), CURRENCY, good.price]
	_action.disabled = _mode == Mode.SELL and good.price <= 0


# --- Trading --------------------------------------------------------------------

func _trade(slot: IconSlot) -> void:
	if not is_open or slot == null or not _goods.has(slot):
		return
	var item: ItemData = _goods[slot].item
	var price: int = _goods[slot].price
	if _mode == Mode.BUY:
		if not _player.spend_money(price):
			_greeting.text = _stock.broke_line
			return
		var stack := ItemStack.new()
		stack.item = item
		stack.count = 1
		_player.add_item(stack)
		_greeting.text = _stock.thanks_line
	else:
		if price <= 0:
			_greeting.text = "Can't do anything with that."
			return
		if not _player.remove_item(item, 1):
			return
		_player.add_money(price)
		_greeting.text = _stock.sold_line
	# Rebuild after this input event: the clicked slot is about to be freed.
	_rebuild_at.call_deferred(_grid.get_children().find(slot))


func _rebuild_at(index: int) -> void:
	if not is_open:
		return
	_build()
	if index >= 0 and _grid.get_child_count() > 0:
		var slot := _grid.get_child(mini(index, _grid.get_child_count() - 1)) as Control
		slot.grab_focus()


func _set_mode(mode: Mode) -> void:
	if not is_open:
		return
	if mode == Mode.SELL and not _stock.buys_items:
		mode = Mode.BUY
	_mode = mode
	_build()
	if ActiveDevice.using_gamepad and _grid.get_child_count() > 0:
		(_grid.get_child(0) as Control).grab_focus.call_deferred()


# --- Device / prompts -------------------------------------------------------------

## Picking up the controller with nothing focused puts the cursor on the grid.
func _on_device_changed(gamepad: bool) -> void:
	if not is_open or not gamepad or _grid.get_child_count() == 0:
		return
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused == null or not _root.is_ancestor_of(focused):
		(_grid.get_child(0) as Control).grab_focus.call_deferred()


## Key icon + word per PROMPTS entry; a left click does the same thing.
func _build_prompts() -> void:
	for i in PROMPTS.size():
		var action: StringName = PROMPTS[i][0]
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 6)
		pair.mouse_filter = Control.MOUSE_FILTER_STOP
		pair.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var icon := InputIcon.new()
		icon.action = action
		icon.pixel_scale = PROMPT_PIXEL_SCALE
		icon.follow_device = true
		icon.press_phase = -0.15 * i
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(icon)
		var word := Label.new()
		word.text = PROMPTS[i][1]
		word.theme_type_variation = &"HintLabel"
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(word)
		pair.mouse_entered.connect(func() -> void:
			word.add_theme_color_override(&"font_color", word.get_theme_color(&"accent", &"Win95")))
		pair.mouse_exited.connect(word.remove_theme_color_override.bind(&"font_color"))
		pair.gui_input.connect(_on_prompt_input.bind(action))
		_prompts.add_child(pair)


func _on_prompt_input(event: InputEvent, action: StringName) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_prompts.accept_event()
	match action:
		&"interact":
			_trade.call_deferred(_current_slot())
		&"next_item":
			_set_mode.call_deferred(Mode.SELL if _mode == Mode.BUY else Mode.BUY)
		_:
			close.call_deferred()
