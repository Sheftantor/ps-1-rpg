class_name InventoryMenu
extends CanvasLayer
## Inventory screen on the inventory input (I / D-pad right): the two weapon
## slots, then the bag, a grid of BAG_SLOTS icon slots holding the carried item
## stacks (counts in the corner) with the rest empty. Hover or controller focus
## shows a slot's name in a speech bubble and its details in the description
## panel; click pins it. Right-click an item to use it, as in the field. Frees
## the mouse and pauses the game while open; inventory, pause or ui_cancel
## closes it. Layout and styling live in res://scenes/inventory_menu.tscn.

## True while the screen is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

const BAG_SLOTS := 24
const DESCRIPTION_HINT := "Point at a slot or click it for details. Right-click an item to use it."

var _was_paused: bool = false
var _player: Player = null
var _board: SlotBoard
## Bag slot -> the stack in it.
var _stacks: Dictionary[IconSlot, ItemStack] = {}

@onready var _root: Control = $Root
@onready var _weapons: HBoxContainer = $Root/Window/Layout/Weapons
@onready var _bag: GridContainer = $Root/Window/Layout/Bag
@onready var _close_icon: InputIcon = $Root/Hint/Icon


func _ready() -> void:
	_root.visible = false
	_board = SlotBoard.new($Root/Bubble, $Root/Window/Layout/Description/Lines/Title,
		$Root/Window/Layout/Description/Lines/Body, "BAG", DESCRIPTION_HINT)
	_board.slot_right_clicked.connect(_on_right_clicked)


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: D-pad right is also ui_right, which focus
	# navigation would swallow before it got here.
	if is_open and (event.is_action_pressed(&"inventory") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or GameMenus.any_open():
		return
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.hud.visible = false
	_close_icon.gamepad = _player.hud.using_gamepad
	_build()
	_root.visible = true
	if _player.hud.using_gamepad and _bag.get_child_count() > 0:
		(_bag.get_child(0) as Control).grab_focus.call_deferred()


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
	if _player != null:
		_player.hud.visible = true


func _build() -> void:
	for box: Node in [_weapons, _bag]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_board.clear()
	_stacks.clear()
	_board.add_weapons(_weapons, _player)
	for i in BAG_SLOTS:
		if i < _player.inventory.size():
			var stack := _player.inventory[i]
			_stacks[_board.add_item(_bag, stack)] = stack
		else:
			var slot := SlotBoard.new_slot(_bag)
			_board.add(slot, "EMPTY", "EMPTY", "An empty bag slot.", slot.show_empty.bind(""))


## Right-click uses the item, then redraws the bag with the new counts.
func _on_right_clicked(slot: IconSlot) -> void:
	var stack: ItemStack = _stacks.get(slot)
	if stack == null:
		return
	_player.use_item(stack)
	# Rebuild after this input event: the clicked slot is about to be freed.
	_rebuild_at.call_deferred(_bag.get_children().find(slot))


func _rebuild_at(index: int) -> void:
	_build()
	# Keep the cursor on the same bag square.
	if index >= 0 and index < _bag.get_child_count():
		(_bag.get_child(index) as Control).grab_focus()
