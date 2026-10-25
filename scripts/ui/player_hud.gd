class_name PlayerHud
extends CanvasLayer
## Player HUD: top-left health and energy bars with values, the full-width XP
## bar along the bottom (SegmentedXpBar), the bottom-left
## loadout window (LoadoutPanel: both weapons, then the carried items with the
## selected one under the cursor), pickup prompt, the stack of short messages
## just above the loadout window (flash_message()), plus the gun-mode targeting
## overlay (connector web, reticle with target and range-state labels, mode
## label, queued-shot portrait slots centered under it, action prompts). Structure and logic only: layout,
## colors and fonts live in res://scenes/player_hud.tscn and
## res://resources/ui/hud_theme.tres for styling in the editor.

const SEGMENTED_XP_BAR := preload("res://scripts/ui/segmented_xp_bar.gd")

## Seconds a flash_message() stays up, including its fade.
@export var message_time: float = 2.0
## Fade-out at the end of a message (s).
@export var message_fade: float = 0.35
## Messages that arrive together (e.g. TAKE ALL) leave one after another, oldest
## first, this far apart (s).
@export var message_stagger: float = 0.4
## Oldest messages are dropped beyond this many lines.
@export var max_messages: int = 6
## Gap between the message stack and the top of the loadout window (pixels).
@export var message_gap: float = 8.0
@export var in_range_text: String = "IN RANGE"
@export var out_of_range_text: String = "TOO FAR"
## Reticle label for a target that isn't queued yet.
@export var target_text: String = "TARGET"
## Queue slot and reticle label for queued targets, numbered in queue order.
@export var queued_format: String = "ENEMY %s"
## Gun mode's TARGET / range boxes sit at the left edge, 4% in and centered
## vertically (anchors on Root/Targeting/TargetPanel); this nudges them (pixels).
@export var target_panel_offset: Vector2 = Vector2.ZERO:
	set(value):
		target_panel_offset = value
		if is_node_ready():
			_place_target_panel()

# Typed by path so the HUD loads before the editor has registered the class_name.
const LoadoutPanelScript := preload("res://scripts/ui/loadout_panel.gd")
const IconSlotScript := preload("res://scripts/ui/icon_slot.gd")
## Queue slot side (pixels): the ItemSlot frame's 8 px margins leave a 64 px
## picture, the portrait icons' own size, so they draw 1:1 with no rescaling.
const PORTRAIT_SLOT_SIZE := 80.0
## Queue slot portrait for an enemy whose stats have none.
const PORTRAIT_PLACEHOLDER: Texture2D = preload("res://textures/ui/icons/placeholder_portrait.png")

## Whether key labels show gamepad buttons; follows the last device used
## (ActiveDevice, the InputDevice autoload).
var using_gamepad: bool:
	get:
		return ActiveDevice.using_gamepad

## Shown messages, oldest first: [label, seconds left].
var _message_lines: Array = []
var _gun_drawn: bool = false
# Last set_loadout() arguments, redrawn when the drawn weapon changes.
var _melee: MeleeWeaponData = null
## The secondary slot: a gun, an off-hand melee weapon, or null.
var _secondary: Resource = null
var _dual_wielding: bool = false
var _inventory: Array[ItemStack] = []
var _selected_item: int = 0
var _slots: Array[Control] = []
var _level_up_tween: Tween = null
@onready var _level_up_y: float = $Root/LevelUp.position.y

@onready var _health_value: Label = $Root/Stats/HealthRow/Value
@onready var _health_bar: Range = $Root/Stats/HealthBar
@onready var _stamina_value: Label = $Root/Stats/StaminaRow/Value
@onready var _stamina_bar: Range = $Root/Stats/StaminaBar
@onready var _xp_bar: SEGMENTED_XP_BAR = $Root/XpBar
@onready var _xp_bar_alpha: float = _xp_bar.modulate.a
@onready var _level_up: Label = $Root/LevelUp
@onready var _loadout: LoadoutPanelScript = $Root/LoadoutPanel
@onready var _messages: VBoxContainer = $Root/Messages
## Interact prompt: an InputIcon for the bound input plus a one-word verb.
@onready var _interact: Control = $Root/Interact
@onready var _interact_icon: InputIcon = $Root/Interact/Icon
@onready var _interact_verb: Label = $Root/Interact/Verb
@onready var _targeting: Control = $Root/Targeting
@onready var _links: TargetLinks = $Root/Targeting/Links
@onready var _reticle: TargetReticle = $Root/Targeting/Reticle
@onready var _target_panel: Control = $Root/Targeting/TargetPanel
@onready var _target_label: Label = $Root/Targeting/TargetPanel/TargetLabel
@onready var _range_label: Label = $Root/Targeting/TargetPanel/RangeLabel
@onready var _mode_label: Label = $Root/Targeting/ModeLabel
@onready var _queue_row: HBoxContainer = $Root/Targeting/QueueRow
@onready var _gun_prompts: HBoxContainer = $Root/Targeting/Prompts


func _ready() -> void:
	_place_target_panel()
	_targeting.visible = false
	_interact.visible = false
	# Key icons switch between keyboard/mouse and gamepad as either is used.
	_interact_icon.follow_device = true


## Short name of the key/button bound to `action` on the current device.
func key_label(action: StringName) -> String:
	return InputBindings.label(action, using_gamepad)


func _process(delta: float) -> void:
	_update_messages(delta)


## Top-left stat block; connected to Health.changed / Stamina.changed.
func set_health(current: float, maximum: float) -> void:
	_set_stat(_health_bar, _health_value, current, maximum)


func set_stamina(current: float, maximum: float) -> void:
	_set_stat(_stamina_bar, _stamina_value, current, maximum)


## Level and the XP bar toward the next one (needed 0 = max level).
## Brightens the XP bar for a moment (kill feedback).
func pulse_xp_bar(seconds: float) -> void:
	# Keeps the bar's own see-through alpha (set in the scene).
	var alpha := _xp_bar_alpha
	var tween := _xp_bar.create_tween()
	tween.tween_property(_xp_bar, ^"modulate", Color(2.2, 2.2, 2.2, alpha), seconds * 0.3)
	tween.tween_property(_xp_bar, ^"modulate", Color(1, 1, 1, alpha), seconds * 0.7)


func set_xp(level: int, xp: int, needed: int) -> void:
	_xp_bar.set_progress(level, xp, needed)


## Big gold "LEVEL UP!" banner that rises a little and fades.
func show_level_up(level: int) -> void:
	if _level_up_tween != null:
		_level_up_tween.kill()
	_level_up.text = "LEVEL UP!  LV %d" % level
	_level_up.visible = true
	_level_up.modulate.a = 1.0
	_level_up.position.y = _level_up_y
	_level_up_tween = _level_up.create_tween()
	_level_up_tween.tween_interval(1.4)
	_level_up_tween.tween_property(_level_up, ^"modulate:a", 0.0, 0.8)
	_level_up_tween.parallel().tween_property(_level_up, ^"position:y", _level_up_y - 20.0, 0.8)
	_level_up_tween.tween_callback(_level_up.hide)


func _set_stat(bar: Range, value_label: Label, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d/%d" % [roundi(current), roundi(maximum)]


## Bottom-left loadout window: both weapon slots (secondary: a gun or an
## off-hand melee weapon), then the carried items with `selected_item` (the one
## use_item spends) under the cursor. dual_wielding lights both weapons.
func set_loadout(melee: MeleeWeaponData, secondary: Resource, inventory: Array[ItemStack], selected_item: int,
		dual_wielding: bool = false) -> void:
	_melee = melee
	_secondary = secondary
	_dual_wielding = dual_wielding
	_inventory = inventory
	_selected_item = selected_item
	_refresh_loadout()


## While the loot window is open, loot dragged onto the loadout window is
## passed to `handler` (an empty Callable stops it taking drops).
func set_loot_drop_handler(handler: Callable) -> void:
	_loadout.drop_handler = handler


## Lights the weapon in hand: the gun in gun mode, else the melee weapon.
func set_gun_drawn(drawn: bool) -> void:
	_gun_drawn = drawn
	_refresh_loadout()


func _refresh_loadout() -> void:
	_loadout.set_entries(_melee, _secondary, _gun_drawn, _inventory, _selected_item, _dual_wielding)


## Shows the interact prompt while something interactable is in reach: the icon
## of whatever is bound to `action` on the current device, and a one-word verb
## ("PICKUP", "OPEN", "TALK"). An empty verb hides it.
func set_interact(action: StringName, verb: String) -> void:
	_interact.visible = not verb.is_empty()
	if verb.is_empty():
		return
	_interact_icon.action = action
	_interact_verb.text = verb.to_upper()


## Adds a line to the message stack above the loadout window. Newest at the
## bottom; each leaves after message_time, never before the one above it.
func flash_message(text: String) -> void:
	var label := Win95MessageLabel.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_messages.add_child(label)
	var time := message_time
	if not _message_lines.is_empty():
		time = maxf(time, _message_lines.back()[1] + message_stagger)
	_message_lines.append([label, time])
	while _message_lines.size() > max_messages:
		_message_lines.pop_front()[0].queue_free()


func _update_messages(delta: float) -> void:
	# The loadout window grows with the inventory: keep the stack sitting on it.
	_messages.offset_bottom = _loadout.offset_top - message_gap
	_messages.offset_top = _messages.offset_bottom - _messages.get_combined_minimum_size().y
	for line: Array in _message_lines:
		line[1] -= delta
		(line[0] as Control).modulate.a = clampf(line[1] / message_fade, 0.0, 1.0)
	while not _message_lines.is_empty() and _message_lines[0][1] <= 0.0:
		_message_lines.pop_front()[0].queue_free()


## Gun mode has its own prompt row; its queue sits top center.
func show_targeting(shown: bool) -> void:
	_targeting.visible = shown
	if shown:
		_build_gun_prompts()


## Gun-mode prompt row: [action, word] pairs, each shown as the bound input's
## icon (current device) and one word.
const GUN_PROMPTS: Array = [
	[&"attack_light", "LOCK"], [&"target_next", "SWITCH"], [&"gun_undo", "UNDO"],
	[&"attack_heavy", "EXECUTE"], [&"gun_mode", "CANCEL"],
]


func _build_gun_prompts() -> void:
	for child in _gun_prompts.get_children():
		child.queue_free()
	for i in GUN_PROMPTS.size():
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override(&"separation", 8)
		var icon := InputIcon.new()
		icon.follow_device = true
		icon.press_phase = -0.15 * i
		icon.action = GUN_PROMPTS[i][0]
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(icon)
		var word := Label.new()
		word.text = GUN_PROMPTS[i][1]
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(word)
		_gun_prompts.add_child(pair)


func set_mode_text(text: String) -> void:
	_mode_label.text = text


## One slot per queued shot, in queue order: the target's portrait in an item
## icon slot (same frame and filtering as every other icon, at
## PORTRAIT_SLOT_SIZE; placeholder if it has none). No name label: the name
## is only the slot's tooltip. null = a target that's gone (placeholder).
func set_queue(targets: Array[EnemyStats]) -> void:
	var count := targets.size()
	while _slots.size() < count:
		var slot := IconSlotScript.new()
		slot.placeholder = PORTRAIT_PLACEHOLDER
		slot.set_slot_size(PORTRAIT_SLOT_SIZE)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_queue_row.add_child(slot)
		_slots.append(slot)
	while _slots.size() > count:
		_slots.pop_back().queue_free()
	for i in _slots.size():
		var stats := targets[i]
		_slots[i].show_icon(stats.portrait if stats != null else null,
				stats.display_name if stats != null else "")


## Projects the player and target points onto the screen: connector lines to
## every target, queued ones highlighted, and the reticle on `cursor` (index
## into targets, -1 for none) with its queue number, range state and distance.
## `queued` lists indices into targets in queue order (-1 for off-list ones).
## Applies target_panel_offset to the panel's left-edge anchor point.
func _place_target_panel() -> void:
	_target_panel.offset_left = target_panel_offset.x
	_target_panel.offset_right = target_panel_offset.x
	_target_panel.offset_top = target_panel_offset.y
	_target_panel.offset_bottom = target_panel_offset.y


func update_targeting(camera: Camera3D, origin: Vector3, targets: Array[Vector3], cursor: int,
		queued: PackedInt32Array, in_range: bool, distance: float) -> void:
	var points := PackedVector2Array()
	var screen_index := PackedInt32Array()  # targets index -> points index, -1 if behind the camera
	for target in targets:
		if camera.is_position_behind(target):
			screen_index.append(-1)
		else:
			screen_index.append(points.size())
			points.append(camera.unproject_position(target))
	var queued_2d := PackedInt32Array()
	for index in queued:
		if index >= 0 and screen_index[index] >= 0:
			queued_2d.append(screen_index[index])
	var cursor_2d := screen_index[cursor] if cursor >= 0 else -1
	_links.set_links(camera.unproject_position(origin), points, cursor_2d, queued_2d)

	_reticle.visible = cursor_2d >= 0
	# The TARGET / range boxes show while there's a reticle, as when they rode on it.
	_target_panel.visible = _reticle.visible
	if cursor_2d < 0:
		return
	_reticle.position = points[cursor_2d] - _reticle.size * 0.5
	_reticle.in_range = in_range
	# The same enemy can hold several queued shots: "ENEMY 1 & 3".
	var slots := PackedStringArray()
	for i in queued.size():
		if queued[i] == cursor:
			slots.append(str(i + 1))
	_target_label.text = queued_format % " & ".join(slots) if not slots.is_empty() else target_text
	_range_label.text = "%s  %.1fM" % [in_range_text if in_range else out_of_range_text, distance]
	_range_label.modulate = _reticle.current_color()
