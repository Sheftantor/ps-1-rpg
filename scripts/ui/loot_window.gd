class_name LootWindow
extends CanvasLayer
## Loot window, opened by interacting with a loot sack (Pickup). Shows what's in
## the sack as a grid of icon slots (the inventory's IconSlot at loot_slot_scale,
## with the same stack count), each with the shared ItemTooltip on hover.
## Take a slot with loot_take (right-click it, or A on the focused slot), or drag
## it with the mouse onto the HUD's loadout window. Weapons go to the gun slot,
## items into the inventory. Interact (E) takes everything; ui_cancel or pause
## (Esc) closes it, leaving the rest in the sack (that Esc doesn't also open the
## pause menu). The window closes when the sack is empty.
##
## The game keeps running while it's open: enemies, projectiles and the player
## (movement, keyboard / controller combat, right-stick camera) carry on. The
## cursor is shown for the window, so mouse-look waits; clicking anywhere
## outside the window closes it and gives the mouse back to the camera. It also
## closes when the player walks loot_close_distance away from the sack, the sack
## goes, the player dies (or is hit, with close_on_damage), or a full-screen
## menu opens. Opening another sack replaces this one.
## Layout and styling live in res://scenes/loot_window.tscn.

## True while the window is up. Not a GameMenus menu: the player keeps playing.
static var is_open: bool = false

## Closes the window when the player gets this far from the sack (m, flat).
@export var loot_close_distance: float = 4.0
## Also close when the player takes damage.
@export var close_on_damage: bool = false
## Loot slot size as a fraction of the inventory's (IconSlot.SIZE).
@export_range(0.3, 1.5, 0.05) var loot_slot_scale: float = 0.65
## Slots per row; more rows grow downward.
@export_range(1, 12) var columns: int = 4:
	set(value):
		columns = value
		if is_node_ready():
			_grid.columns = columns

## [action, word, clickable] for each prompt under the grid.
const PROMPTS: Array = [
	[&"loot_take", "TAKE", false],
	[&"interact", "TAKE ALL", true],
	[&"ui_cancel", "CANCEL", true],
]
## Drag data key marking a loot entry (see LoadoutPanel.drop_handler).
const DRAG_KEY := "loot_entry"
## Prompt key art size (InputIcon.pixel_scale): smaller than the HUD's.
const PROMPT_PIXEL_SCALE := 2

var _player: Player = null
var _pickup: Pickup = null
var _gamepad: bool = false
## Whether the mouse was driving the camera when the window opened.
var _mouse_was_captured: bool = false
## Slot -> the sack entry it shows.
var _entries: Dictionary[Control, Resource] = {}
var _prompt_icons: Array[InputIcon] = []

@onready var _root: Control = $Root
@onready var _window: Control = $Root/Window
@onready var _grid: GridContainer = $Root/Window/Layout/Grid
@onready var _prompts: HBoxContainer = $Root/Window/Layout/Prompts


func _ready() -> void:
	_root.visible = false
	_grid.columns = columns
	_build_prompts()


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	_track_device(event)
	if event.is_action_pressed(&"interact"):
		# Interact at a different sack opens that one instead; here, takes all.
		var nearest := _player.nearest_interactable()
		if nearest is Pickup and nearest != _pickup:
			open(nearest as Pickup)
		else:
			_take_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.is_action_pressed(&"loot_take"):
		# Handled here rather than through focus so A always takes the slot under
		# the cursor (the first one if nothing has focus yet).
		var slot := _focused_slot()
		if slot == null and _grid.get_child_count() > 0:
			slot = _grid.get_child(0) as Control
		if slot != null:
			_take.call_deferred(_entries[slot], slot.get_index())
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed():
		# A click outside the window: back to the fight. Only gives the mouse
		# back to the camera; it doesn't also attack.
		close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if GameMenus.any_open() or not is_instance_valid(_pickup) or _pickup.is_queued_for_deletion() \
			or not is_instance_valid(_player) or _player.health.current <= 0:
		close()
		return
	var offset := _player.global_position - _pickup.global_position
	offset.y = 0.0
	if offset.length() > loot_close_distance:
		close()


## Opens pickup's loot. Another sack's window already open is replaced.
func open(pickup: Pickup) -> void:
	if GameMenus.any_open() or pickup == null:
		return
	if is_open:
		if pickup == _pickup:
			return
		close()
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_pickup = pickup
	is_open = true
	_mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.hud.set_loot_drop_handler(_on_dropped)
	_player.health.damaged.connect(_on_player_damaged)
	_build()
	_root.visible = true
	_set_gamepad(_player.hud.using_gamepad)


func close() -> void:
	if not is_open:
		return
	is_open = false
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_root.visible = false
	ItemTooltip.service().hide_now()
	# Give the mouse back to the camera, unless a menu that wants it is opening.
	if _mouse_was_captured and not GameMenus.any_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_player):
		_player.hud.set_loot_drop_handler(Callable())
		if _player.health.damaged.is_connected(_on_player_damaged):
			_player.health.damaged.disconnect(_on_player_damaged)
	_pickup = null


func _on_player_damaged(_amount: int) -> void:
	if close_on_damage:
		close()


# --- Device / prompts -------------------------------------------------------------

## Follows the last device used.
func _track_device(event: InputEvent) -> void:
	var gamepad := _gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		gamepad = false
	if gamepad != _gamepad:
		_set_gamepad(gamepad)


func _set_gamepad(gamepad: bool) -> void:
	_gamepad = gamepad
	_player.hud.using_gamepad = gamepad
	for icon: InputIcon in _prompt_icons:
		icon.gamepad = gamepad
	if gamepad and _focused_slot() == null and _grid.get_child_count() > 0:
		(_grid.get_child(0) as Control).grab_focus.call_deferred()


## Icon + word per PROMPTS entry; the clickable ones act on a left click.
func _build_prompts() -> void:
	for i in PROMPTS.size():
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 6)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := InputIcon.new()
		icon.action = PROMPTS[i][0]
		icon.pixel_scale = PROMPT_PIXEL_SCALE
		icon.press_phase = -0.15 * i
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		_prompt_icons.append(icon)
		var word := Label.new()
		word.text = PROMPTS[i][1]
		word.theme_type_variation = &"HintLabel"
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(word)
		if PROMPTS[i][2]:
			pair.mouse_filter = Control.MOUSE_FILTER_STOP
			pair.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pair.mouse_entered.connect(func() -> void:
				word.add_theme_color_override(&"font_color", word.get_theme_color(&"accent", &"Win95")))
			pair.mouse_exited.connect(word.remove_theme_color_override.bind(&"font_color"))
			pair.gui_input.connect(_on_prompt_input.bind(PROMPTS[i][0]))
		_prompts.add_child(pair)


func _on_prompt_input(event: InputEvent, action: StringName) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_prompts.accept_event()
	if action == &"interact":
		_take_all.call_deferred()
	else:
		close.call_deferred()


# --- Grid -----------------------------------------------------------------------

func _build() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_entries.clear()
	if not is_instance_valid(_pickup):
		return
	for entry: Resource in _pickup.contents():
		var slot := _slot(entry)
		_entries[slot] = entry
		_grid.add_child(slot)
	# Shrink the window to the new grid.
	_window.reset_size.call_deferred()


func _slot(entry: Resource) -> IconSlot:
	var slot := IconSlot.new()
	slot.set_slot_scale(loot_slot_scale)
	slot.focus_mode = Control.FOCUS_ALL
	slot.show_icon(Pickup.entry_icon(entry), "", _count(entry))
	var tooltip := ItemTooltip.service()
	slot.mouse_entered.connect(func() -> void:
		slot.grab_focus()
		tooltip.hover(slot, entry))
	slot.mouse_exited.connect(tooltip.leave.bind(slot))
	slot.focus_entered.connect(func() -> void:
		slot.set_selected(true)
		if _gamepad:
			tooltip.focus(slot, entry))
	slot.focus_exited.connect(func() -> void:
		slot.set_selected(false)
		if _gamepad:
			tooltip.leave(slot))
	slot.gui_input.connect(_on_slot_input.bind(slot))
	# Left-drag the slot onto the HUD's loadout window to take it.
	slot.set_drag_forwarding(_drag_data.bind(slot), Callable(), Callable())
	return slot


static func _count(entry: Resource) -> int:
	return (entry as ItemStack).count if entry is ItemStack else 0


func _focused_slot() -> Control:
	var focused := _root.get_viewport().gui_get_focus_owner()
	return focused if focused != null and _entries.has(focused) else null


func _on_slot_input(event: InputEvent, slot: Control) -> void:
	# Right-click (loot_take on the mouse) or ui_accept (Enter) takes the slot.
	if (event is InputEventMouseButton and event.is_action_pressed(&"loot_take")) \
			or event.is_action_pressed(&"ui_accept"):
		slot.accept_event()
		# Take after this input event: the slot is about to be freed.
		_take.call_deferred(_entries[slot], slot.get_index())


## Drag source: the slot's entry, previewed as a full-size icon square under the cursor.
func _drag_data(_at_position: Vector2, slot: Control) -> Variant:
	var entry: Resource = _entries.get(slot)
	if entry == null:
		return null
	ItemTooltip.service().hide_now()
	var preview_slot := IconSlot.new()
	preview_slot.show_icon(Pickup.entry_icon(entry), "", _count(entry), true)
	preview_slot.position = -Vector2.ONE * IconSlot.SIZE * 0.5
	var preview := Control.new()
	preview.modulate.a = 0.85
	preview.add_child(preview_slot)
	slot.set_drag_preview(preview)
	return {DRAG_KEY: entry}


## Drop target (the HUD's loadout window): takes the dragged entry.
func _on_dropped(data: Variant) -> void:
	if data is Dictionary and data.has(DRAG_KEY):
		var entry: Resource = data[DRAG_KEY]
		var index := _entries.values().find(entry)
		_take.call_deferred(entry, index)


func _take(entry: Resource, index: int) -> void:
	if not is_open or not is_instance_valid(_pickup) or not _pickup.contents().has(entry):
		return
	ItemTooltip.service().hide_now()
	_player.take_loot(_pickup, entry)
	if _pickup.contents().is_empty():
		close()
		return
	_build()
	if _gamepad and index >= 0 and _grid.get_child_count() > 0:
		(_grid.get_child(mini(index, _grid.get_child_count() - 1)) as Control).grab_focus()


func _take_all() -> void:
	if not is_open:
		return
	if is_instance_valid(_pickup):
		for entry: Resource in _pickup.contents():
			_player.take_loot(_pickup, entry)
	close()
