class_name StatusMenu
extends CanvasLayer
## Character screen on the status_menu input (C / D-pad up). A 3D render of the
## player model (with the equipped melee weapon in hand) sits between two columns
## of gear slots: clothing on the left, rings, trinkets and the charm on the
## right, with the melee weapon, gun and carried items below. Under those, a
## description panel explains the slot under the cursor (or the one clicked to
## pin it), and two stat panels read the player's live numbers.
## Empty slots show a grey picture of what goes there; a slot's name only appears
## in a speech-bubble tooltip while the mouse is over it or controller focus is
## on it. Click (or ui_accept) pins a slot so its description stays up. Drag the
## model (or push the right stick) to turn it. Frees the mouse and pauses the
## game while open; status_menu, pause or ui_cancel closes it.
## Layout and styling live in res://scenes/status_menu.tscn.

## True while the screen is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

const LABEL_SETTINGS: LabelSettings = preload("res://resources/ui/stat_label.tres")
const SECTION_SETTINGS: LabelSettings = preload("res://resources/ui/menu_section.tres")
const ICONS := "res://textures/ui/icons/"
## [slot, tooltip name, empty-slot picture (its lit gear_* twin is the default
## for worn gear), what goes there]
const MAIN_SLOTS := [
	[ArmorData.Slot.SHIRT, "SHIRT", "slot_shirt", "Shirts, sweaters and jackets go here."],
	[ArmorData.Slot.NECK, "NECK", "slot_neck", "Chains, scarves and pendants go here."],
	[ArmorData.Slot.ARMS, "ARMS", "slot_arms", "Gloves, wraps and bracers go here."],
	[ArmorData.Slot.BELT, "BELT", "slot_belt", "Belts and holsters go here."],
	[ArmorData.Slot.PANTS, "PANTS", "slot_pants", "Jeans, slacks and work pants go here."],
	[ArmorData.Slot.SHOES, "SHOES", "slot_shoes", "Sneakers, boots and dress shoes go here."],
]
const ACCESSORY_SLOTS := [
	[ArmorData.Slot.RING_1, "RING", "slot_ring", "A ring goes here. You can wear two."],
	[ArmorData.Slot.RING_2, "RING", "slot_ring", "A ring goes here. You can wear two."],
	[ArmorData.Slot.TRINKET_1, "TRINKET", "slot_trinket", "Watches, lighters and lucky odds and ends go here."],
	[ArmorData.Slot.TRINKET_2, "TRINKET", "slot_trinket", "Watches, lighters and lucky odds and ends go here."],
	[ArmorData.Slot.CHARM, "CHARM", "slot_charm", "One charm, carried for luck, goes here."],
]
const EMPTY := "-"
## Shown in the description panel when nothing is hovered or pinned.
const DESCRIPTION_HINT := "Point at a slot or click it to see what it holds."
## Colour of a stat's name; the value is white.
const NAME_COLOR := Color(0.72, 0.74, 0.8)
## Unspent-point "+" buttons.
const POINT_COLOR := Color(1.0, 0.84, 0.3)
## Space between the weapons and the carried items (pixels).
const ITEM_GAP := 28.0
## Model turn speed: radians per pixel dragged, and per second at full stick.
const DRAG_TURN := 0.012
const STICK_TURN := 3.0
const STICK_DEADZONE := 0.25
## Overall size of the gear/stats window, scaled about its center.
const FRAME_SCALE := 0.85

var _was_paused: bool = false
## The player the screen was last built for.
var _player: Player = null
## Hover bubble, pinning and the description panel for the slots.
var _board: SlotBoard

@onready var _root: Control = $Root
@onready var _frame: Control = $Root/Frame
@onready var _main_slots: VBoxContainer = $Root/Frame/Layout/Gear/MainSlots
@onready var _accessory_slots: VBoxContainer = $Root/Frame/Layout/Gear/Accessories
@onready var _weapon_slots: HBoxContainer = $Root/Frame/Layout/Weapons
@onready var _combat_rows: VBoxContainer = $Root/Frame/Layout/Stats/Combat/Rows
@onready var _spirit_rows: VBoxContainer = $Root/Frame/Layout/Stats/Spirit/Rows
@onready var _title: Label = $Root/Title
@onready var _description_title: Label = $Root/Frame/Layout/Description/Lines/Title
@onready var _description_body: Label = $Root/Frame/Layout/Description/Lines/Body
@onready var _model_view: SubViewportContainer = $Root/Frame/Layout/Gear/ModelFrame/ModelView
@onready var _turntable: Node3D = $Root/Frame/Layout/Gear/ModelFrame/ModelView/Viewport/Turntable
@onready var _model: Node3D = $Root/Frame/Layout/Gear/ModelFrame/ModelView/Viewport/Turntable/Model
@onready var _bubble: PanelContainer = $Root/Bubble
@onready var _close_icon: InputIcon = $Root/Hint/Icon


func _ready() -> void:
	_root.visible = false
	_frame.scale = Vector2(FRAME_SCALE, FRAME_SCALE)
	_frame.resized.connect(func() -> void: _frame.pivot_offset = _frame.size * 0.5)
	_board = SlotBoard.new(_bubble, _description_title, _description_body, "GEAR", DESCRIPTION_HINT)
	_model_view.gui_input.connect(_on_model_input)
	# Same as the player: a private copy of the tree so its parameters are its own.
	var anim_tree := _model.get_node(^"AnimationTree") as AnimationTree
	anim_tree.tree_root = anim_tree.tree_root.duplicate(true)
	anim_tree.active = true
	# Standing still on the ground, arms down, not aiming.
	anim_tree.set(Player.TREE_AIR_REQUEST, "ground")
	anim_tree.set(Player.TREE_JUMP_ARMS, 0.0)
	anim_tree.set(Player.TREE_AIM, 0.0)
	anim_tree.set(Player.TREE_LOCOMOTION, Vector2.ZERO)
	anim_tree.set(Player.TREE_LOCOMOTION_SPEED, 1.0)


func _exit_tree() -> void:
	is_open = false


func _input(event: InputEvent) -> void:
	# _input, not _unhandled_input: D-pad up is also ui_up, which focus
	# navigation would swallow before it got here.
	if is_open and (event.is_action_pressed(&"status_menu") or event.is_action_pressed(&"pause")):
		close()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > STICK_DEADZONE:
		_turntable.rotate_y(stick * STICK_TURN * delta)


func open() -> void:
	if is_open or GameMenus.any_open():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.visible = false
	_close_icon.gamepad = player.hud.using_gamepad
	_turntable.rotation = Vector3.ZERO
	_build(player)
	_root.visible = true
	if player.hud.using_gamepad and _main_slots.get_child_count() > 0:
		(_main_slots.get_child(0) as Control).grab_focus.call_deferred()


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
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.hud.visible = true


func _build(player: Player) -> void:
	_player = player
	for box: Node in [_main_slots, _accessory_slots, _weapon_slots, _combat_rows, _spirit_rows]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_board.clear()

	for spec: Array in MAIN_SLOTS:
		_gear_slot(_main_slots, player, spec)
	for spec: Array in ACCESSORY_SLOTS:
		_gear_slot(_accessory_slots, player, spec)
	_board.add_weapons(_weapon_slots, player)
	_item_slots_for(player)

	var needed := player.xp_to_next()
	_title.text = "STATUS   LV %d   XP %s" % [player.level, "%d/%d" % [player.xp, needed] if needed > 0 else "MAX"]

	_section(_combat_rows, "COMBAT")
	_stat(_combat_rows, "HEALTH", "%d/%d" % [player.health.current, player.health.max_health])
	_stat(_combat_rows, "STRENGTH", str(player.attributes.strength), &"strength")
	_stat(_combat_rows, "AGILITY", str(player.attributes.agility), &"agility")
	var attack := GearText.melee_damage(player)
	_stat(_combat_rows, "ATTACK", str(attack) if attack > 0 else EMPTY)
	_stat(_combat_rows, "DEFENSE", str(player.armor_defense()))

	_section(_spirit_rows, "SPIRIT")
	_stat(_spirit_rows, "ENERGY", "%d/%d" % [roundi(player.stamina.current), roundi(player.stamina.maximum)])
	_stat(_spirit_rows, "FOCUS", str(player.attributes.focus), &"focus")
	_stat(_spirit_rows, "MEMES", str(player.attributes.memes), &"memes")
	var gun := player.gun
	_stat(_spirit_rows, "GUN DMG", str(gun.shot.damage) if gun != null and gun.shot != null else EMPTY)
	_stat(_spirit_rows, "POINTS", str(player.stat_points))

	_dress_model(player)


# --- Slots --------------------------------------------------------------------

func _gear_slot(column: VBoxContainer, player: Player, spec: Array) -> void:
	var piece: ArmorData = player.armor.get(spec[0])
	var empty_icon: Texture2D = load(ICONS + spec[2] + ".png")
	# Worn gear without its own picture gets the slot shape, lit up.
	var worn_icon: Texture2D = load(ICONS + spec[2].replace("slot_", "gear_") + ".png")
	var slot := SlotBoard.new_slot(column)
	var slot_name: String = spec[1]
	# The right-hand column's bubbles open toward the model.
	var left := column == _accessory_slots
	if piece == null:
		_board.add(slot, slot_name, slot_name, "Empty. " + spec[3], slot.show_placeholder.bind(empty_icon), left)
		return
	var body := piece.description
	if piece.defense > 0:
		body = GearText.join(body, "+%d DEFENSE" % piece.defense)
	var item_name := piece.display_name.to_upper()
	_board.add(slot, slot_name + "\n" + item_name, slot_name + ": " + item_name, body,
		slot.show_icon.bind(piece.icon if piece.icon != null else worn_icon, ""), left)


func _item_slots_for(player: Player) -> void:
	if player.inventory.is_empty():
		return
	var gap := Control.new()
	gap.custom_minimum_size.x = ITEM_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_slots.add_child(gap)
	for stack: ItemStack in player.inventory:
		_board.add_item(_weapon_slots, stack)


# --- Stats --------------------------------------------------------------------

func _section(box: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.label_settings = SECTION_SETTINGS
	box.add_child(label)


## A stat row. With an attribute key, a "+" button spends an unspent level-up
## point on it while the player has any.
func _stat(box: VBoxContainer, stat_name: String, value_text: String, attribute: StringName = &"") -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.label_settings = LABEL_SETTINGS
	name_label.modulate = NAME_COLOR
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.text = value_text
	value.label_settings = LABEL_SETTINGS
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	if attribute != &"" and _player.stat_points > 0:
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(34, 30)
		plus.add_theme_font_override(&"font", LABEL_SETTINGS.font)
		plus.add_theme_font_size_override(&"font_size", 26)
		plus.add_theme_color_override(&"font_color", POINT_COLOR)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.1, 0.11) if state == &"normal" else Color(0.3, 0.26, 0.12)
			style.set_border_width_all(2)
			style.border_color = POINT_COLOR
			plus.add_theme_stylebox_override(state, style)
		plus.pressed.connect(_spend.bind(attribute))
		row.add_child(plus)
	box.add_child(row)


## Puts a level-up point into an attribute and redraws the screen.
func _spend(attribute: StringName) -> void:
	if _player.spend_stat_point(attribute):
		# After this button's press: the rebuild frees it.
		_build.call_deferred(_player)


# --- Model preview ------------------------------------------------------------

## Puts the equipped melee weapon's model in the preview's hand, as the player does.
func _dress_model(player: Player) -> void:
	var mount := _model.get_node_or_null(^"Skeleton3D/RightHandAttachment/MeleeWeapon")
	if mount == null:
		return
	var current := mount.get_node_or_null(^"Model")
	if current != null:
		mount.remove_child(current)
		current.queue_free()
	if player.melee_weapon != null and player.melee_weapon.model != null:
		var weapon: Node3D = player.melee_weapon.model.instantiate()
		weapon.name = &"Model"
		mount.add_child(weapon)
		mount.move_child(weapon, 0)


func _on_model_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(motion.relative.x * DRAG_TURN)
