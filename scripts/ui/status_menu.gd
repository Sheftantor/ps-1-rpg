class_name StatusMenu
extends CanvasLayer
## Player stats and gear screen on the status_menu input (C / D-pad up): health,
## stamina, defense and stat points, the melee weapon and gun, and the six armour
## slots (shirt, neck, arms, belt, pants, shoes). Pauses the game while open;
## status_menu or pause closes it. Rows are built from the player's live data
## each time it opens; layout and styling live in res://scenes/status_menu.tscn.

## True while the screen is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

const NAME_SETTINGS: LabelSettings = preload("res://resources/ui/menu_label.tres")
const SECTION_SETTINGS: LabelSettings = preload("res://resources/ui/menu_section.tres")
const SLOT_NAMES := {
	ArmorData.Slot.SHIRT: "SHIRT", ArmorData.Slot.NECK: "NECK", ArmorData.Slot.ARMS: "ARMS",
	ArmorData.Slot.BELT: "BELT", ArmorData.Slot.PANTS: "PANTS", ArmorData.Slot.SHOES: "SHOES",
}
## Shown for an empty slot.
const EMPTY := "-"
## Width of the left-hand name column (pixels).
const NAME_WIDTH := 220

var _was_paused: bool = false

@onready var _root: Control = $Root
@onready var _stats: VBoxContainer = $Root/Panels/Stats/Content
@onready var _gear: VBoxContainer = $Root/Panels/Gear/Content
@onready var _close_icon: InputIcon = $Root/Hint/Icon


func _ready() -> void:
	_root.visible = false


func _exit_tree() -> void:
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed(&"status_menu") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or PauseMenu.is_open:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	player.hud.visible = false
	_close_icon.gamepad = player.hud.using_gamepad
	_build(player)
	_root.visible = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = _was_paused
	_root.visible = false
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.hud.visible = true


func _build(player: Player) -> void:
	for box: Node in [_stats, _gear]:
		for child in box.get_children():
			child.queue_free()

	_section(_stats, "PLAYER")
	_row(_stats, "HP", "%d / %d" % [player.health.current, player.health.max_health])
	_row(_stats, "STAMINA", "%d / %d" % [roundi(player.stamina.current), roundi(player.stamina.maximum)])
	_row(_stats, "DEFENSE", str(player.armor_defense()))
	_row(_stats, "STAT POINTS", str(player.stats.stat_points))

	_section(_gear, "WEAPONS")
	_row(_gear, "MELEE", player.melee_name().to_upper())
	_row(_gear, "GUN", player.gun.display_name.to_upper() if player.gun != null else EMPTY)
	_section(_gear, "ARMOR")
	for slot: ArmorData.Slot in SLOT_NAMES:
		var piece: ArmorData = player.armor.get(slot)
		var value := EMPTY
		if piece != null:
			value = "%s  +%d" % [piece.display_name.to_upper(), piece.defense]
		_row(_gear, SLOT_NAMES[slot], value)


func _section(box: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.label_settings = SECTION_SETTINGS
	box.add_child(label)


func _row(box: VBoxContainer, name_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = name_text
	name_label.label_settings = NAME_SETTINGS
	name_label.custom_minimum_size.x = NAME_WIDTH
	name_label.modulate = Color(0.75, 0.75, 0.78)
	row.add_child(name_label)
	var value := Label.new()
	value.text = value_text
	value.label_settings = NAME_SETTINGS
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(value)
	box.add_child(row)
