class_name SlotBoard
extends RefCounted
## Shared hover / pin / description behaviour for a screen of IconSlots (the
## status screen, the inventory). Hovering a slot gives it focus, so mouse and
## controller share one highlight; the focused slot shows a speech-bubble
## tooltip beside it and fills the description panel. Clicking (or ui_accept)
## pins a slot so its description stays up after the cursor leaves.
## The screen owns the nodes: a Bubble (PanelContainer with a Text label and a
## Tail polygon) and the description Title/Body labels.

const LABEL_SETTINGS: LabelSettings = preload("res://resources/ui/stat_label.tres")
const TITLE_COLOR := Color(1.0, 0.82, 0.4)
## Gap between a slot and its tooltip bubble (pixels).
const BUBBLE_GAP := 16.0

## Emitted when a registered slot is right-clicked (left click and ui_accept pin it).
signal slot_right_clicked(slot: IconSlot)

var pinned: IconSlot = null

var _bubble: PanelContainer
var _bubble_text: Label
var _bubble_tail: Polygon2D
var _title: Label
var _body: Label
var _empty_title: String
var _empty_body: String
## Per slot: {bubble, title, body, redraw, left}
var _info: Dictionary[IconSlot, Dictionary] = {}


func _init(bubble: PanelContainer, title: Label, body: Label, empty_title: String, empty_body: String) -> void:
	_bubble = bubble
	_bubble_text = bubble.get_node(^"Text")
	_bubble_tail = bubble.get_node(^"Tail")
	_title = title
	_body = body
	_empty_title = empty_title
	_empty_body = empty_body
	_bubble_text.label_settings = LABEL_SETTINGS
	_title.label_settings = LABEL_SETTINGS
	_title.modulate = TITLE_COLOR
	_body.label_settings = LABEL_SETTINGS


## Forgets all slots (the screen frees the nodes) and resets the panel.
func clear() -> void:
	_info.clear()
	pinned = null
	_bubble.visible = false
	show_description(null)


func hide_bubble() -> void:
	_bubble.visible = false


## Registers a slot. redraw draws it unhighlighted; bubble_left puts the
## tooltip on the slot's left (for slots on the right edge).
func add(slot: IconSlot, bubble: String, title: String, body: String, redraw: Callable, bubble_left := false) -> void:
	_info[slot] = {bubble = bubble, title = title, body = body, redraw = redraw, left = bubble_left}
	slot.focus_mode = Control.FOCUS_ALL
	redraw.call()
	slot.mouse_entered.connect(slot.grab_focus)
	slot.mouse_exited.connect(func() -> void:
		if slot.has_focus():
			slot.release_focus())
	slot.focus_entered.connect(_on_focused.bind(slot))
	slot.focus_exited.connect(_on_unfocused.bind(slot))
	slot.gui_input.connect(_on_input.bind(slot))


func show_description(slot: IconSlot) -> void:
	if slot == null or not _info.has(slot):
		_title.text = _empty_title
		_body.text = _empty_body
		return
	_title.text = _info[slot].title
	_body.text = _info[slot].body


func _on_input(event: InputEvent, slot: IconSlot) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		slot_right_clicked.emit(slot)
		slot.accept_event()
	elif (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed(&"ui_accept"):
		_pin(slot)
		slot.accept_event()


func _pin(slot: IconSlot) -> void:
	var previous := pinned
	pinned = null if previous == slot else slot
	if previous != null and previous != slot and _info.has(previous):
		_redraw(previous)
	_redraw(slot)
	show_description(slot if pinned == slot or slot.has_focus() else null)


## Draws a slot in its resting look: highlighted only if pinned or focused.
func _redraw(slot: IconSlot) -> void:
	slot.modulate = Color.WHITE
	_info[slot].redraw.call()
	if slot == pinned or slot.has_focus():
		slot.set_selected(true)


func _on_focused(slot: IconSlot) -> void:
	if not _info.has(slot):
		return
	slot.set_selected(true)
	_bubble_text.text = _info[slot].bubble
	_bubble.visible = true
	_place_bubble.call_deferred(slot)
	show_description(slot)


func _on_unfocused(slot: IconSlot) -> void:
	if _info.has(slot):
		_redraw(slot)
	_bubble.visible = false
	show_description(pinned)


## Puts the bubble beside the slot with its tail pointing back at it.
func _place_bubble(slot: IconSlot) -> void:
	if not is_instance_valid(slot) or not slot.has_focus():
		return
	var size := _bubble.get_combined_minimum_size()
	_bubble.size = size
	var rect := slot.get_global_rect()
	var y := rect.get_center().y - size.y * 0.5
	if _info[slot].left:
		_bubble.global_position = Vector2(rect.position.x - BUBBLE_GAP - size.x, y)
		_bubble_tail.position = Vector2(size.x, size.y * 0.5)
		_bubble_tail.scale = Vector2(-1, 1)
	else:
		_bubble.global_position = Vector2(rect.end.x + BUBBLE_GAP, y)
		_bubble_tail.position = Vector2(0, size.y * 0.5)
		_bubble_tail.scale = Vector2.ONE


# --- Common slots ---------------------------------------------------------------

const MELEE_PLACEHOLDER: Texture2D = preload("res://textures/ui/icons/placeholder_melee.png")
const GUN_PLACEHOLDER: Texture2D = preload("res://textures/ui/icons/placeholder_gun.png")


## A new icon slot at the shared size, added to `parent`.
static func new_slot(parent: Container) -> IconSlot:
	var slot := IconSlot.new()
	slot.set_slot_size(IconSlot.SIZE)
	parent.add_child(slot)
	return slot


## The melee weapon and gun slots (greyed placeholders when empty).
func add_weapons(parent: Container, player: Player) -> void:
	var melee := player.melee_weapon
	var slot := new_slot(parent)
	if melee == null:
		add(slot, "WEAPON", "WEAPON", "Empty. Your melee weapon goes here.", _greyed.bind(slot, MELEE_PLACEHOLDER))
	else:
		var item_name := melee.display_name.to_upper()
		add(slot, "WEAPON\n" + item_name, "WEAPON: " + item_name, GearText.melee(player), slot.show_icon.bind(melee.icon, ""))
	var gun := player.gun
	slot = new_slot(parent)
	if gun == null:
		add(slot, "GUN", "GUN", "Empty. Pick up a gun to carry it here.", _greyed.bind(slot, GUN_PLACEHOLDER))
	else:
		var item_name := gun.display_name.to_upper()
		add(slot, "GUN\n" + item_name, "GUN: " + item_name, GearText.gun(gun), slot.show_icon.bind(gun.icon, ""))


## A carried item stack, with its count in the corner.
func add_item(parent: Container, stack: ItemStack) -> IconSlot:
	var slot := new_slot(parent)
	var item_name := stack.item.display_name.to_upper()
	add(slot, "ITEM\n" + item_name, "ITEM: " + item_name, GearText.item(stack),
		slot.show_icon.bind(stack.item.icon, "", stack.count))
	return slot


## The weapon placeholders are coloured; grey one out like the empty gear slots.
static func _greyed(slot: IconSlot, texture: Texture2D) -> void:
	slot.show_placeholder(texture)
	slot.modulate = Color(0.55, 0.55, 0.58)
