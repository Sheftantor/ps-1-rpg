class_name InventoryMenu
extends CanvasLayer
## The bag, on the inventory input (I / D-pad right). It and the character
## screen (StatusMenu, status_menu input) open and close on their own buttons,
## over the in-game HUD (nothing is dimmed), with the game paused while either
## is up. Moving pieces between them needs both open.
## The bag is a grid of GearHand.BAG_SLOTS icon slots holding the owned weapons
## and armour and the carried item stacks that aren't in a quick slot (counts in
## the corner), each in the square it was put in.
## This screen also runs the gear session for the pair: the pause, the
## GearHand (`hand`, what's on the cursor), its icon following the mouse (or
## the focused slot on a controller), and the keys: Esc / Cancel or clicking off
## the slots undoes one step of a move, and with nothing held closes whatever
## is open. Hover or controller focus shows a slot's name in a speech bubble and
## its details in the description panel. Right-click an item to use it.
## Layout and styling: res://scenes/inventory_menu.tscn.

## True while the bag is up.
static var is_open: bool = false

const DESCRIPTION_HINT := "Click a slot to pick it up, then click where it goes. Open the character screen too to equip. Right-click an item to use it. Esc puts it back."
## Where the held piece's icon sits from the mouse pointer (pixels): up and
## left, clear of the hover tooltip, which opens down and right.
const HELD_OFFSET := Vector2(-IconSlot.SIZE - 4.0, -IconSlot.SIZE - 4.0)

## The piece on the cursor and its undo steps, while the bag or the character
## screen is up (null otherwise); the character screen moves gear with it too.
var hand: GearHand = null

var _was_paused: bool = false
var _player: Player = null
var _board: SlotBoard
## Bag square -> its index in the layout (GearHand.bag()).
var _bag_index: Dictionary[IconSlot, int] = {}
var _held_layer := CanvasLayer.new()
var _held_icon := IconSlot.new()

@onready var _root: Control = $Root
@onready var _bag: GridContainer = $Root/Window/Layout/Bag
@onready var _close_icon: InputIcon = $Root/Hint/Icon


func _ready() -> void:
	_root.visible = false
	_board = SlotBoard.new($Root/Bubble, $Root/Window/Layout/Description/Lines/Title,
		$Root/Window/Layout/Description/Lines/Body, "BAG", DESCRIPTION_HINT)
	_board.slot_right_clicked.connect(_on_right_clicked)
	_board.slot_clicked.connect(_on_bag_clicked)
	_close_icon.follow_device = true
	ActiveDevice.connect_changed(_on_device_changed)
	# The held piece draws over both screens.
	_held_layer.layer = layer + 5
	_held_layer.visible = false
	add_child(_held_layer)
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_layer.add_child(_held_icon)


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	if hand == null:
		return
	# _input, not _unhandled_input: the D-pad menu buttons are also ui_up /
	# ui_right, which focus navigation would swallow before they got here.
	if event.is_action_pressed(&"inventory"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"status_menu"):
		if StatusMenu.is_open:
			close_character()
		else:
			open_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		# Esc / Cancel: put back the last move, or close with nothing held.
		if not hand.undo():
			close()
			close_character()
		get_viewport().set_input_as_handled()
	else:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
				and hand.held != null and not _on_a_slot(click.position):
			# Let go off the slots: same as Esc.
			hand.undo()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if hand == null or hand.held == null:
		return
	var focused := _root.get_viewport().gui_get_focus_owner()
	if ActiveDevice.using_gamepad and focused != null:
		var rect := focused.get_global_rect()
		_held_icon.position = rect.end - rect.size * 0.35
	else:
		_held_icon.position = _root.get_viewport().get_mouse_position() + HELD_OFFSET


## Opens the bag (the inventory input).
func open() -> void:
	if is_open or not _begin_session():
		return
	is_open = true
	_build()
	_root.visible = true
	_on_device_changed(ActiveDevice.using_gamepad)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_board.hide_bubble()
	_root.visible = false
	_end_session_if_done()


## Opens the character screen (the status_menu input; StatusMenu.open()).
func open_character() -> void:
	if StatusMenu.is_open or not _begin_session():
		return
	_player.status_menu.show_for(_player, hand)
	_on_device_changed(ActiveDevice.using_gamepad)


func close_character() -> void:
	if not StatusMenu.is_open:
		return
	_player.status_menu.hide_screen()
	_end_session_if_done()


## Starts the gear session with the first screen: pauses, frees the mouse, and
## makes the hand. False when another menu (pause, shop) has the game.
func _begin_session() -> bool:
	if hand != null:
		return true
	if GameMenus.any_open():
		return false
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return false
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hand = GearHand.new(_player)
	hand.changed.connect(_refresh)
	return true


## Ends the session once neither screen is up. A move still in progress is
## undone first, so nothing is left on the cursor.
func _end_session_if_done() -> void:
	if is_open or StatusMenu.is_open or hand == null:
		return
	hand.undo_all()
	hand = null
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	_held_layer.visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Picking up the controller with nothing focused puts the cursor on the open
## screen (the bag first).
func _on_device_changed(gamepad: bool) -> void:
	if hand == null or not gamepad:
		return
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and (_root.is_ancestor_of(focused) or _player.status_menu.owns(focused)):
		return
	if is_open and _bag.get_child_count() > 0:
		(_bag.get_child(0) as Control).grab_focus.call_deferred()
	elif StatusMenu.is_open:
		_player.status_menu.focus_first.call_deferred()


## Says why a move didn't work: a HUD message, and in the bag's description
## panel while the bag is up (its window covers the HUD's message corner).
func explain(text: String) -> void:
	_player.hud.flash_message(text)
	if is_open:
		_board.say("CAN'T GO THERE", text)


func _on_a_slot(point: Vector2) -> bool:
	return (is_open and _board.slot_at(point) != null) or _player.status_menu.slot_at(point) != null


func _build() -> void:
	for child in _bag.get_children():
		_bag.remove_child(child)
		child.queue_free()
	_board.clear()
	_bag_index.clear()
	var layout := hand.bag()
	for i in layout.size():
		var piece := layout[i]
		var slot: IconSlot
		if piece is ItemStack:
			slot = _board.add_item(_bag, piece as ItemStack)
		elif piece != null:
			slot = _board.add_gear(_bag, piece)
		else:
			slot = SlotBoard.new_slot(_bag)
			_board.add(slot, "EMPTY", "EMPTY", "An empty bag slot.", slot.show_empty.bind(""))
		_bag_index[slot] = i


## Redraws the open screens after a move, keeping the controller cursor where it was.
func _refresh() -> void:
	var focused := _root.get_viewport().gui_get_focus_owner()
	var bag_index := _bag.get_children().find(focused)
	var status_focus: Variant = _player.status_menu.focus_key(focused)
	if is_open:
		_build()
	if StatusMenu.is_open:
		_player.status_menu.rebuild()
	_held_layer.visible = hand.held != null
	var stack := hand.held as ItemStack
	if stack != null:
		_held_icon.show_icon(stack.item.icon, "", stack.count, true)
	elif hand.held != null:
		_held_icon.show_icon(hand.held.get(&"icon") as Texture2D, "", 0, true)
	if is_open and bag_index >= 0:
		(_bag.get_child(mini(bag_index, _bag.get_child_count() - 1)) as Control).grab_focus()
	elif status_focus != null:
		_player.status_menu.focus_slot(status_focus)


## Left click / accept on a bag square: put the held piece in that square
## (swapping with what's there), or pick one up.
func _on_bag_clicked(slot: IconSlot) -> void:
	# After this input event: the rebuild frees the clicked slot.
	hand.click_bag.call_deferred(_bag_index[slot])


## Right-click uses the item, then redraws the bag with the new counts.
func _on_right_clicked(slot: IconSlot) -> void:
	var stack := hand.bag()[_bag_index[slot]] as ItemStack
	if stack == null or hand.held != null:
		return
	_player.use_item(stack)
	_refresh.call_deferred()
