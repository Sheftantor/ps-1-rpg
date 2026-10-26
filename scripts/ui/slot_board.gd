class_name SlotBoard
extends RefCounted
## Shared hover / pin / description behaviour for a screen of IconSlots (the
## status screen, the inventory). Hovering a slot gives it focus, so mouse and
## controller share one highlight; the focused slot shows a speech-bubble
## tooltip beside it and fills the description panel. Clicking (or ui_accept)
## pins a slot so its description stays up after the cursor leaves.
## The screen owns the nodes: a Bubble (PanelContainer with a Text label and a
## Tail polygon) and the description Title/Body labels.
## Tooltip mode (bubble and labels all null, as on the status screen): no bubble
## or panel; the shared ItemTooltip shows each slot's content instead, next to
## the cursor on hover or beside the slot under controller focus.

## Gap between a slot and its tooltip bubble (pixels).
const BUBBLE_GAP := 16.0

## Emitted when a registered slot is right-clicked (left click and ui_accept pin it).
signal slot_right_clicked(slot: IconSlot)
## Left click / ui_accept on a slot. While anything is connected to it, that
## click goes here instead of pinning (the gear screens pick items up with it).
signal slot_clicked(slot: IconSlot)

var pinned: IconSlot = null

var _bubble: PanelContainer
var _bubble_text: Label
var _bubble_tail: Polygon2D
var _title: Label
var _body: Label
var _empty_title: String
var _empty_body: String
## Per slot: {bubble, title, body, redraw, left, content}
var _info: Dictionary[IconSlot, Dictionary] = {}
var _use_tooltip: bool = false
## The slot the mouse is over (its tooltip follows the cursor, not focus).
var _mouse_slot: IconSlot = null


func _init(bubble: PanelContainer, title: Label, body: Label, empty_title: String, empty_body: String) -> void:
	_use_tooltip = bubble == null and title == null
	_bubble = bubble
	if bubble != null:
		_bubble_text = bubble.get_node(^"Text")
		_bubble_tail = bubble.get_node(^"Tail")
	_title = title
	_body = body
	_empty_title = empty_title
	_empty_body = empty_body
	if _title != null:
		_title.theme_type_variation = &"SectionLabel"


## Forgets all slots (the screen frees the nodes) and resets the panel.
func clear() -> void:
	_info.clear()
	pinned = null
	_mouse_slot = null
	hide_bubble()
	show_description(null)


func hide_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false
	if _use_tooltip:
		ItemTooltip.service().hide_now()


## Registers a slot. redraw draws it unhighlighted; bubble_left puts the
## tooltip on the slot's left (for slots on the right edge). content is what
## the ItemTooltip shows in tooltip mode (an item resource); null shows title
## and body (empty slots).
func add(slot: IconSlot, bubble: String, title: String, body: String, redraw: Callable, bubble_left := false,
		content: Variant = null) -> void:
	_info[slot] = {bubble = bubble, title = title, body = body, redraw = redraw, left = bubble_left,
			content = content if content != null else {title = title, body = body}}
	slot.focus_mode = Control.FOCUS_ALL
	redraw.call()
	slot.mouse_entered.connect(func() -> void:
		_mouse_slot = slot
		if _use_tooltip:
			ItemTooltip.service().hover(slot, _info[slot].content)
		slot.grab_focus())
	slot.mouse_exited.connect(func() -> void:
		if _mouse_slot == slot:
			_mouse_slot = null
		if _use_tooltip:
			ItemTooltip.service().leave(slot)
		if slot.has_focus():
			slot.release_focus())
	slot.focus_entered.connect(_on_focused.bind(slot))
	slot.focus_exited.connect(_on_unfocused.bind(slot))
	slot.gui_input.connect(_on_input.bind(slot))


## The registered slot under a screen position, or null.
func slot_at(point: Vector2) -> IconSlot:
	for slot: IconSlot in _info:
		if is_instance_valid(slot) and slot.is_visible_in_tree() and slot.get_global_rect().has_point(point):
			return slot
	return null


## Puts a one-off message in the description panel (until focus moves).
func say(title: String, body: String) -> void:
	if _title != null:
		_title.text = title
		_body.text = body


func show_description(slot: IconSlot) -> void:
	if _title == null:
		return
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
		if slot_clicked.get_connections().is_empty():
			_pin(slot)
		else:
			slot_clicked.emit(slot)
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
	if _use_tooltip:
		# Controller focus (the mouse's own hover is already showing it).
		if slot != _mouse_slot:
			ItemTooltip.service().focus(slot, _info[slot].content)
	else:
		_bubble_text.text = _info[slot].bubble
		_bubble.visible = true
		_place_bubble.call_deferred(slot)
	show_description(slot)


func _on_unfocused(slot: IconSlot) -> void:
	if _info.has(slot):
		_redraw(slot)
	if _use_tooltip:
		if slot != _mouse_slot:
			ItemTooltip.service().leave(slot)
	elif _bubble != null:
		_bubble.visible = false
	show_description(pinned)


## Puts the bubble beside the slot with its tail pointing back at it.
## Deferred, so the slot may have been freed by a rebuild meanwhile (untyped:
## a freed object can't even be passed as an IconSlot).
func _place_bubble(slot_or_freed: Variant) -> void:
	if not is_instance_valid(slot_or_freed) or not (slot_or_freed as IconSlot).has_focus():
		return
	var slot := slot_or_freed as IconSlot
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
## Shown on the weapon slots: how to swap in a weapon from the bag.
const SWAP_HINT := "Click to pick it up, then click a slot or the bag."


## A new icon slot at the shared size, added to `parent`.
static func new_slot(parent: Container) -> IconSlot:
	var slot := IconSlot.new()
	slot.set_slot_size(IconSlot.SIZE)
	parent.add_child(slot)
	return slot


## The main and secondary weapon slots (greyed placeholders when empty).
## Returns [main slot, secondary slot].
func add_weapons(parent: Container, player: Player) -> Array[IconSlot]:
	var swap := "\n" + SWAP_HINT
	var melee := player.melee_weapon
	var main_slot := new_slot(parent)
	if melee == null:
		add(main_slot, "MAIN", "MAIN", "Empty. Any melee weapon goes here." + swap,
				greyed.bind(main_slot, MELEE_PLACEHOLDER))
	else:
		var item_name := melee.display_name.to_upper()
		add(main_slot, "MAIN\n" + item_name, "MAIN: " + item_name, GearText.melee(player) + swap,
				main_slot.show_icon.bind(melee.icon, ""), false, melee)
	var second := player.secondary_weapon()
	var second_slot := new_slot(parent)
	if second == null:
		add(second_slot, "SECONDARY", "SECONDARY",
				"Empty. A gun goes here, or a second dual-wield blade next to a dual-wield main weapon." + swap,
				greyed.bind(second_slot, GUN_PLACEHOLDER))
	elif second is WeaponData:
		var item_name := (second as WeaponData).display_name.to_upper()
		add(second_slot, "SECONDARY\n" + item_name, "SECONDARY: " + item_name, GearText.gun(second) + swap,
				second_slot.show_icon.bind((second as WeaponData).icon, ""), false, second)
	else:
		var blade := second as MeleeWeaponData
		var item_name := blade.display_name.to_upper()
		add(second_slot, "SECONDARY\n" + item_name, "SECONDARY: " + item_name + "  (DUAL WIELD)",
				GearText.join(blade.description, "Dual wielded with the main weapon.") + swap,
				second_slot.show_icon.bind(blade.icon, ""), false, blade)
	return [main_slot, second_slot]


## A carried item stack, with its count in the corner.
func add_item(parent: Container, stack: ItemStack) -> IconSlot:
	var slot := new_slot(parent)
	var item_name := stack.item.display_name.to_upper()
	add(slot, "ITEM\n" + item_name, "ITEM: " + item_name, GearText.item(stack),
		slot.show_icon.bind(stack.item.icon, "", stack.count), false, stack)
	return slot


## A weapon or piece of armour lying in the bag.
func add_gear(parent: Container, piece: Resource) -> IconSlot:
	var slot := new_slot(parent)
	var item_name := String(piece.get(&"display_name")).to_upper()
	var kind := "GUN" if piece is WeaponData else ("WEAPON" if piece is MeleeWeaponData else "GEAR")
	var body: String = piece.get(&"description")
	if piece is WeaponData:
		body = GearText.gun(piece)
	elif piece is MeleeWeaponData and (piece as MeleeWeaponData).dual_wieldable:
		body = GearText.join(body, "DUAL WIELD")
	elif piece is ArmorData and (piece as ArmorData).defense > 0:
		body = GearText.join(body, "+%d DEFENSE" % (piece as ArmorData).defense)
	add(slot, kind + "\n" + item_name, kind + ": " + item_name, body,
		slot.show_icon.bind(piece.get(&"icon") as Texture2D, ""), false, piece)
	return slot


## The weapon placeholders are coloured; grey one out like the empty gear slots.
static func greyed(slot: IconSlot, texture: Texture2D) -> void:
	slot.show_placeholder(texture)
	slot.modulate = Color(0.55, 0.55, 0.58)
