class_name LootWindow
extends CanvasLayer
## Loot window, opened by interacting with a loot sack (Pickup). Lists what's in
## the sack, one row per entry (icon square, name, and what it is or how many).
## Take a row with loot_take (right-click it, or A on the focused row), or drag it
## with the mouse onto the HUD's loadout window. Weapons go to the gun slot,
## items into the inventory. Interact takes everything; ui_cancel (Esc / B) or
## pause backs out, leaving the rest in the sack. The prompt row under the list
## shows each of these as the bound button's icon for the device in use, and its
## TAKE ALL / CANCEL prompts can be clicked. The window closes when the sack is
## empty. Pauses the game and frees the mouse while open.
## Layout and styling live in res://scenes/loot_window.tscn.

## True while the window is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

const LABEL_SETTINGS: LabelSettings = preload("res://resources/ui/stat_label.tres")
const ROW_STYLE: StyleBox = preload("res://resources/ui/window_inset.tres")
const HOVER_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const DETAIL_COLOR := Color(0.72, 0.74, 0.8)
## [action, word, clickable] for each prompt under the list.
const PROMPTS: Array = [
	[&"loot_take", "TAKE", false],
	[&"interact", "TAKE ALL", true],
	[&"ui_cancel", "CANCEL", true],
]
## Drag data key marking a loot entry (see LoadoutPanel.drop_handler).
const DRAG_KEY := "loot_entry"

var _was_paused: bool = false
var _player: Player = null
var _pickup: Pickup = null
var _hover_style: StyleBoxFlat
var _gamepad: bool = false
## Row -> the sack entry it shows.
var _entries: Dictionary[Control, Resource] = {}
var _prompt_icons: Array[InputIcon] = []

@onready var _root: Control = $Root
@onready var _rows: VBoxContainer = $Root/Window/Layout/Rows
@onready var _prompts: HBoxContainer = $Root/Window/Layout/Prompts


func _ready() -> void:
	_root.visible = false
	_hover_style = ROW_STYLE.duplicate() as StyleBoxFlat
	_hover_style.border_color = HOVER_COLOR
	_build_prompts()


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	_track_device(event)
	if event.is_action_pressed(&"interact"):
		_take_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.is_action_pressed(&"loot_take"):
		# Handled here rather than through focus so A always takes the row under
		# the cursor (the first one if nothing has focus yet).
		var row := _focused_row()
		if row == null and _rows.get_child_count() > 0:
			row = _rows.get_child(0) as Control
		if row != null:
			_take.call_deferred(_entries[row], row.get_index())
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open(pickup: Pickup) -> void:
	if is_open or GameMenus.any_open() or pickup == null:
		return
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_pickup = pickup
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player.hud.set_loot_drop_handler(_on_dropped)
	_build()
	_root.visible = true
	_set_gamepad(_player.hud.using_gamepad)


func close() -> void:
	if not is_open:
		return
	is_open = false
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root.visible = false
	if _player != null:
		_player.hud.set_loot_drop_handler(Callable())
	_pickup = null


# --- Device / prompts -------------------------------------------------------------

## Follows the last device used (the HUD can't while the game is paused).
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
	if gamepad and _focused_row() == null and _rows.get_child_count() > 0:
		(_rows.get_child(0) as Control).grab_focus.call_deferred()


## Icon + word per PROMPTS entry; the clickable ones act on a left click.
func _build_prompts() -> void:
	for i in PROMPTS.size():
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 8)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := InputIcon.new()
		icon.action = PROMPTS[i][0]
		icon.press_phase = -0.15 * i
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		_prompt_icons.append(icon)
		var word := _label(PROMPTS[i][1])
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(word)
		if PROMPTS[i][2]:
			pair.mouse_filter = Control.MOUSE_FILTER_STOP
			pair.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			pair.mouse_entered.connect(func() -> void: word.modulate = HOVER_COLOR)
			pair.mouse_exited.connect(func() -> void: word.modulate = Color.WHITE)
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


# --- Rows -----------------------------------------------------------------------

func _build() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_entries.clear()
	if not is_instance_valid(_pickup):
		return
	for entry: Resource in _pickup.contents():
		var row := _row(entry)
		_entries[row] = entry
		_rows.add_child(row)


func _row(entry: Resource) -> PanelContainer:
	var row := PanelContainer.new()
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override(&"panel", ROW_STYLE)
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var slot := IconSlot.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.show_icon(Pickup.entry_icon(entry), "", _count(entry))
	line.add_child(slot)

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name_label := _label(Pickup.entry_name(entry).to_upper())
	text.add_child(name_label)
	var detail := _label("GUN" if entry is WeaponData else "ITEM  X%d" % _count(entry))
	detail.modulate = DETAIL_COLOR
	text.add_child(detail)

	row.mouse_entered.connect(row.grab_focus)
	row.focus_entered.connect(row.add_theme_stylebox_override.bind(&"panel", _hover_style))
	row.focus_exited.connect(row.add_theme_stylebox_override.bind(&"panel", ROW_STYLE))
	row.gui_input.connect(_on_row_input.bind(row))
	# Left-drag the row onto the HUD's loadout window to take it.
	row.set_drag_forwarding(_drag_data.bind(row), Callable(), Callable())
	return row


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = LABEL_SETTINGS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _count(entry: Resource) -> int:
	return (entry as ItemStack).count if entry is ItemStack else 0


func _focused_row() -> Control:
	var focused := _root.get_viewport().gui_get_focus_owner()
	return focused if focused != null and _entries.has(focused) else null


func _on_row_input(event: InputEvent, row: Control) -> void:
	# Right-click (loot_take on the mouse) or ui_accept (Enter) takes the row.
	if (event is InputEventMouseButton and event.is_action_pressed(&"loot_take")) \
			or event.is_action_pressed(&"ui_accept"):
		row.accept_event()
		# Take after this input event: the row is about to be freed.
		_take.call_deferred(_entries[row], row.get_index())


## Drag source: the row's entry, previewed as its icon square under the cursor.
func _drag_data(_at_position: Vector2, row: Control) -> Variant:
	var entry: Resource = _entries.get(row)
	if entry == null:
		return null
	var slot := IconSlot.new()
	slot.show_icon(Pickup.entry_icon(entry), "", _count(entry), true)
	slot.position = -Vector2.ONE * IconSlot.SIZE * 0.5
	var preview := Control.new()
	preview.modulate.a = 0.85
	preview.add_child(slot)
	row.set_drag_preview(preview)
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
	_player.take_loot(_pickup, entry)
	if _pickup.contents().is_empty():
		close()
		return
	_build()
	if index >= 0 and _rows.get_child_count() > 0:
		(_rows.get_child(mini(index, _rows.get_child_count() - 1)) as Control).grab_focus()


func _take_all() -> void:
	if not is_open:
		return
	if is_instance_valid(_pickup):
		for entry: Resource in _pickup.contents():
			_player.take_loot(_pickup, entry)
	close()
