class_name LootWindow
extends CanvasLayer
## Loot window, opened by interacting with a loot sack (Pickup). Lists what's in
## the sack, one row per entry (icon square, name, and what it is or how many).
## Right-click a row (or ui_accept on it with a controller) to take it: weapons
## go to the gun slot, items into the inventory. Interact again takes everything.
## The window closes when the sack is empty, or on pause / ui_cancel (anything
## left stays in the sack). Pauses the game and frees the mouse while open.
## Layout and styling live in res://scenes/loot_window.tscn.

## True while the window is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

const LABEL_SETTINGS: LabelSettings = preload("res://resources/ui/stat_label.tres")
const ROW_STYLE: StyleBox = preload("res://resources/ui/window_inset.tres")
const HOVER_COLOR := Color(1.0, 0.85, 0.35, 1.0)
const DETAIL_COLOR := Color(0.72, 0.74, 0.8)

var _was_paused: bool = false
var _player: Player = null
var _pickup: Pickup = null
var _hover_style: StyleBoxFlat

@onready var _root: Control = $Root
@onready var _rows: VBoxContainer = $Root/Window/Layout/Rows
@onready var _hint: Label = $Root/Window/Layout/Hint


func _ready() -> void:
	_root.visible = false
	_hover_style = ROW_STYLE.duplicate() as StyleBoxFlat
	_hover_style.border_color = HOVER_COLOR


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"interact"):
		_take_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		close()
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
	var gamepad := _player.hud.using_gamepad
	_hint.text = "%s: TAKE    %s: TAKE ALL" % ["A" if gamepad else "RIGHT-CLICK",
		InputBindings.label(&"interact", gamepad)]
	_build()
	_root.visible = true
	if gamepad and _rows.get_child_count() > 0:
		(_rows.get_child(0) as Control).grab_focus.call_deferred()


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
	_pickup = null


func _build() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if not is_instance_valid(_pickup):
		return
	for entry: Resource in _pickup.contents():
		_rows.add_child(_row(entry))


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
	var count := (entry as ItemStack).count if entry is ItemStack else 0
	slot.show_icon(Pickup.entry_icon(entry), "", count)
	line.add_child(slot)

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name_label := _label(Pickup.entry_name(entry).to_upper())
	text.add_child(name_label)
	var detail := _label("GUN" if entry is WeaponData else "ITEM  X%d" % count)
	detail.modulate = DETAIL_COLOR
	text.add_child(detail)

	row.mouse_entered.connect(row.grab_focus)
	row.focus_entered.connect(row.add_theme_stylebox_override.bind(&"panel", _hover_style))
	row.focus_exited.connect(row.add_theme_stylebox_override.bind(&"panel", ROW_STYLE))
	row.gui_input.connect(_on_row_input.bind(row, entry))
	return row


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = LABEL_SETTINGS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_row_input(event: InputEvent, row: Control, entry: Resource) -> void:
	var click := event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT) \
			or event.is_action_pressed(&"ui_accept"):
		row.accept_event()
		# Take after this input event: the row is about to be freed.
		_take.call_deferred(entry, _rows.get_children().find(row))


func _take(entry: Resource, index: int) -> void:
	if not is_open or not is_instance_valid(_pickup):
		return
	_player.take_loot(_pickup, entry)
	if _pickup.contents().is_empty():
		close()
		return
	_build()
	if index >= 0 and _rows.get_child_count() > 0:
		(_rows.get_child(mini(index, _rows.get_child_count() - 1)) as Control).grab_focus()


func _take_all() -> void:
	if is_instance_valid(_pickup):
		for entry: Resource in _pickup.contents():
			_player.take_loot(_pickup, entry)
	close()
