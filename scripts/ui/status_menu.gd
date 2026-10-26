class_name StatusMenu
extends CanvasLayer
## Character screen, always open beside the bag (InventoryMenu opens, closes
## and pauses for both; the status_menu input opens the pair). A 3D render of
## the player model (with the equipped melee weapons in hand) sits between two
## columns of gear slots: clothing on the left, rings, trinkets and the charm on
## the right, with the main and secondary weapons and the QUICK_SLOTS quick
## items below, and two stat panels under those reading the player's live numbers.
## Clicking a slot picks up or puts down through the bag's GearHand; a slot
## the held piece doesn't fit flashes red.
## Empty slots show a grey picture of what goes there. Hovering a slot (or
## controller focus on it) shows the shared ItemTooltip: the item's name, type,
## numbers and description, or what goes in an empty slot. Drag the
## model (or push the right stick) to turn it.
## Layout and styling live in res://scenes/status_menu.tscn.

## True while the screen is up; the player ignores input and physics meanwhile.
static var is_open: bool = false

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
## Space between the weapons and the carried items (pixels).
const ITEM_GAP := 28.0
## Model turn speed: radians per pixel dragged, and per second at full stick.
const DRAG_TURN := 0.012
const STICK_TURN := 3.0
const STICK_DEADZONE := 0.25
## Overall size of the gear/stats window, scaled about its center.
const FRAME_SCALE := 0.85
const NO_FIT_COLOR := Color(1.0, 0.35, 0.35)

## The player the screen was last built for.
var _player: Player = null
## Hover, focus and the item tooltip for the slots.
var _board: SlotBoard
## The bag's hand (what's on the cursor), while open.
var _hand: GearHand = null
## Each slot of the current build -> its GearHand slot.
var _keys: Dictionary[IconSlot, Variant] = {}

@onready var _root: Control = $Root
@onready var _frame: Control = $Root/Frame
@onready var _main_slots: VBoxContainer = $Root/Frame/Layout/Gear/MainSlots
@onready var _accessory_slots: VBoxContainer = $Root/Frame/Layout/Gear/Accessories
@onready var _weapon_slots: HBoxContainer = $Root/Frame/Layout/Weapons
@onready var _combat_rows: VBoxContainer = $Root/Frame/Layout/Stats/Combat/Rows
@onready var _spirit_rows: VBoxContainer = $Root/Frame/Layout/Stats/Spirit/Rows
@onready var _model_view: SubViewportContainer = $Root/Frame/Layout/Gear/ModelFrame/ModelView
@onready var _turntable: Node3D = $Root/Frame/Layout/Gear/ModelFrame/ModelView/Viewport/Turntable
@onready var _model: Node3D = $Root/Frame/Layout/Gear/ModelFrame/ModelView/Viewport/Turntable/Model


func _ready() -> void:
	_root.visible = false
	_frame.scale = Vector2(FRAME_SCALE, FRAME_SCALE)
	_frame.resized.connect(func() -> void: _frame.pivot_offset = _frame.size * 0.5)
	# No bubble or description panel: tooltip mode.
	_board = SlotBoard.new(null, null, null, "", "")
	_board.slot_clicked.connect(_on_slot_clicked)
	_model_view.gui_input.connect(_on_model_input)
	($Root/Hint/Icon as InputIcon).follow_device = true
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


## Opens this screen (the status_menu input). The bag runs the session for both.
func open() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.inventory_menu.open_character()


func close() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.inventory_menu.close_character()


## Puts the controller cursor on the first gear slot.
func focus_first() -> void:
	if _main_slots.get_child_count() > 0:
		(_main_slots.get_child(0) as Control).grab_focus()


## Shown by InventoryMenu.open_character(), moving gear with its `hand`.
func show_for(player: Player, hand: GearHand) -> void:
	is_open = true
	_hand = hand
	_turntable.rotation = Vector3.ZERO
	_build(player)
	_root.visible = true


func hide_screen() -> void:
	is_open = false
	_hand = null
	_board.hide_bubble()
	_root.visible = false


func rebuild() -> void:
	_build(_player)


func owns(control: Control) -> bool:
	return _root.is_ancestor_of(control)


func slot_at(point: Vector2) -> IconSlot:
	return _board.slot_at(point) if is_open else null


## The GearHand slot of a focused control (null if it isn't one of ours), so
## focus can come back to the same slot after a rebuild (focus_slot).
func focus_key(control: Control) -> Variant:
	return _keys.get(control)


func focus_slot(key: Variant) -> void:
	for slot: IconSlot in _keys:
		# Armour keys are ints, the rest StringNames: compare types first.
		if typeof(_keys[slot]) == typeof(key) and _keys[slot] == key:
			slot.grab_focus()
			return


func _on_slot_clicked(slot: IconSlot) -> void:
	# After this input event: a move rebuilds the screen, freeing the slot.
	_click.call_deferred(slot, _keys[slot])


func _click(slot: IconSlot, key: Variant) -> void:
	if _hand == null or _hand.click_slot(key):
		return
	# Doesn't fit: flash the slot and say why.
	_player.inventory_menu.explain(_hand.why_not(key, _hand.held))
	if is_instance_valid(slot):
		slot.modulate = NO_FIT_COLOR
		slot.create_tween().tween_property(slot, ^"modulate", Color.WHITE, 0.35)


func _process(delta: float) -> void:
	if not is_open:
		return
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > STICK_DEADZONE:
		_turntable.rotate_y(stick * STICK_TURN * delta)


func _build(player: Player) -> void:
	_player = player
	for box: Node in [_main_slots, _accessory_slots, _weapon_slots, _combat_rows, _spirit_rows]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_board.clear()
	_keys.clear()

	for spec: Array in MAIN_SLOTS:
		_gear_slot(_main_slots, player, spec)
	for spec: Array in ACCESSORY_SLOTS:
		_gear_slot(_accessory_slots, player, spec)
	var weapons := _board.add_weapons(_weapon_slots, player)
	_keys[weapons[0]] = GearHand.MAIN
	_keys[weapons[1]] = GearHand.SECONDARY
	_quick_slots_for(player)

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
	_keys[slot] = spec[0]
	var slot_name: String = spec[1]
	# The right-hand column's bubbles open toward the model.
	var left := column == _accessory_slots
	if piece == null:
		_board.add(slot, slot_name, slot_name.capitalize(), "Empty. " + spec[3], slot.show_placeholder.bind(empty_icon), left)
		return
	var body := piece.description
	if piece.defense > 0:
		body = GearText.join(body, "+%d DEFENSE" % piece.defense)
	var item_name := piece.display_name.to_upper()
	_board.add(slot, slot_name + "\n" + item_name, slot_name + ": " + item_name, body,
		slot.show_icon.bind(piece.icon if piece.icon != null else worn_icon, ""), left, piece)


## The quick-access items (what use_item / next_item reach in the field).
func _quick_slots_for(player: Player) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.x = ITEM_GAP
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_slots.add_child(gap)
	for i in Player.QUICK_SLOTS:
		var stack := player.quick_items[i]
		var kind := player.quick_item_kinds[i]
		var slot: IconSlot
		if stack != null:
			slot = _board.add_item(_weapon_slots, stack)
		elif kind != null:
			# Ran out: the item's picture, greyed, until more is picked up.
			slot = SlotBoard.new_slot(_weapon_slots)
			var item_name := kind.display_name.to_upper()
			_board.add(slot, "QUICK ITEM\n" + item_name, "QUICK ITEM: " + item_name,
				"None left. Picking up more %s refills this slot." % kind.display_name,
				SlotBoard.greyed.bind(slot, kind.icon))
		else:
			slot = SlotBoard.new_slot(_weapon_slots)
			_board.add(slot, "QUICK ITEM", "QUICK ITEM",
				"Empty. An item here can be used in the field.", slot.show_empty.bind(""))
		_keys[slot] = GearHand.QUICK[i]


# --- Stats --------------------------------------------------------------------

func _section(box: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"SectionLabel"
	box.add_child(label)


## A stat row. With an attribute key, a "+" button spends an unspent level-up
## point on it while the player has any.
func _stat(box: VBoxContainer, stat_name: String, value_text: String, attribute: StringName = &"") -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.theme_type_variation = &"HintLabel"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.text = value_text
	value.theme_type_variation = &"MonoLabel"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	if attribute != &"" and _player.stat_points > 0:
		var plus := Button.new()
		plus.text = "+"
		plus.theme_type_variation = &"PointButton"
		plus.pressed.connect(_spend.bind(attribute))
		row.add_child(plus)
	box.add_child(row)


## Puts a level-up point into an attribute and redraws the screen.
func _spend(attribute: StringName) -> void:
	if _player.spend_stat_point(attribute):
		# After this button's press: the rebuild frees it.
		_build.call_deferred(_player)


# --- Model preview ------------------------------------------------------------

## Puts the equipped melee weapons' models in the preview's hands (the main one
## right, an off-hand one left), as the player does.
func _dress_model(player: Player) -> void:
	_dress_hand(^"Skeleton3D/RightHandAttachment/MeleeWeapon", player.melee_weapon)
	_dress_hand(^"Skeleton3D/LeftHandAttachment/OffHandWeapon", player.off_hand)


func _dress_hand(mount_path: NodePath, weapon_data: MeleeWeaponData) -> void:
	var mount := _model.get_node_or_null(mount_path)
	if mount == null:
		return
	var current := mount.get_node_or_null(^"Model")
	if current != null:
		mount.remove_child(current)
		current.queue_free()
	if weapon_data != null and weapon_data.model != null:
		var weapon: Node3D = weapon_data.model.instantiate()
		weapon.name = &"Model"
		mount.add_child(weapon)
		mount.move_child(weapon, 0)


func _on_model_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turntable.rotate_y(motion.relative.x * DRAG_TURN)
