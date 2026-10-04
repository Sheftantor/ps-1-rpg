class_name PlayerHud
extends CanvasLayer
## Player HUD: top-left health and stamina bars with values, the bottom-left
## loadout window (LoadoutPanel: both weapons, then the carried items with the
## selected one under the cursor), pickup prompt and short messages, plus the gun-mode targeting
## overlay (connector web, reticle with target and range-state labels, mode
## label, queued-shot portrait slots centered under it, action prompts). Structure and logic only: layout,
## colors and fonts live in res://scenes/player_hud.tscn and
## res://resources/ui/hud_theme.tres for styling in the editor.

## Seconds a flash_message() stays up before the prompt comes back.
@export var message_time: float = 1.2
@export var in_range_text: String = "IN RANGE"
@export var out_of_range_text: String = "TOO FAR"
## Reticle label for a target that isn't queued yet.
@export var target_text: String = "TARGET"
## Queue slot and reticle label for queued targets, numbered in queue order.
@export var queued_format: String = "ENEMY %s"

# Typed by path so the HUD loads before the editor has registered the class_name.
const LoadoutPanelScript := preload("res://scripts/ui/loadout_panel.gd")
## Queue slot portrait for an enemy whose stats have none.
const PORTRAIT_PLACEHOLDER: Texture2D = preload("res://textures/ui/icons/placeholder_portrait.png")

## Whether key labels show gamepad buttons; follows the last device used.
var using_gamepad: bool = false

var _message_timer: float = 0.0
var _gun_drawn: bool = false
# Last set_loadout() arguments, redrawn when the drawn weapon changes.
var _melee: MeleeWeaponData = null
var _gun: WeaponData = null
var _inventory: Array[ItemStack] = []
var _selected_item: int = 0
var _slots: Array[Control] = []

@onready var _health_value: Label = $Root/Stats/HealthRow/Value
@onready var _health_bar: Range = $Root/Stats/HealthBar
@onready var _stamina_value: Label = $Root/Stats/StaminaRow/Value
@onready var _stamina_bar: Range = $Root/Stats/StaminaBar
@onready var _loadout: LoadoutPanelScript = $Root/LoadoutPanel
@onready var _prompt: Label = $Root/Prompt
## Interact prompt: an InputIcon for the bound input plus a one-word verb.
@onready var _interact: Control = $Root/Interact
@onready var _interact_icon: InputIcon = $Root/Interact/Icon
@onready var _interact_verb: Label = $Root/Interact/Verb
@onready var _targeting: Control = $Root/Targeting
@onready var _links: TargetLinks = $Root/Targeting/Links
@onready var _reticle: TargetReticle = $Root/Targeting/Reticle
@onready var _target_label: Label = $Root/Targeting/Reticle/TargetLabel
@onready var _range_label: Label = $Root/Targeting/Reticle/RangeLabel
@onready var _mode_label: Label = $Root/Targeting/ModeLabel
@onready var _queue_row: HBoxContainer = $Root/Targeting/QueueRow
@onready var _slot_template: Control = $Root/Targeting/QueueRow/SlotTemplate
@onready var _gun_prompts: HBoxContainer = $Root/Targeting/Prompts


func _ready() -> void:
	_targeting.visible = false
	_slot_template.visible = false
	_prompt.text = ""
	_interact.visible = false
	_refresh_keybinds()


## Switches the key labels between keyboard/mouse and gamepad as either is used.
func _input(event: InputEvent) -> void:
	var gamepad := using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.5:
			gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		gamepad = false
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		_refresh_keybinds()


## Short name of the key/button bound to `action` on the current device.
func key_label(action: StringName) -> String:
	return InputBindings.label(action, using_gamepad)


func _refresh_keybinds() -> void:
	_interact_icon.gamepad = using_gamepad
	if _targeting.visible:
		_build_gun_prompts()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_prompt.text = ""


## Top-left stat block; connected to Health.changed / Stamina.changed.
func set_health(current: float, maximum: float) -> void:
	_set_stat(_health_bar, _health_value, current, maximum)


func set_stamina(current: float, maximum: float) -> void:
	_set_stat(_stamina_bar, _stamina_value, current, maximum)


func _set_stat(bar: Range, value_label: Label, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d/%d" % [roundi(current), roundi(maximum)]


## Bottom-left loadout window: both weapons, then the carried items with
## `selected_item` (the one use_item spends) under the cursor.
func set_loadout(melee: MeleeWeaponData, gun: WeaponData, inventory: Array[ItemStack], selected_item: int) -> void:
	_melee = melee
	_gun = gun
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
	_loadout.set_entries(_melee, _gun, _gun_drawn, _inventory, _selected_item)


## Shows the interact prompt while something interactable is in reach: the icon
## of whatever is bound to `action` on the current device, and a one-word verb
## ("PICKUP", "OPEN", "TALK"). An empty verb hides it.
func set_interact(action: StringName, verb: String) -> void:
	_interact.visible = not verb.is_empty()
	if verb.is_empty():
		return
	_interact_icon.action = action
	_interact_verb.text = verb.to_upper()


func flash_message(text: String) -> void:
	_prompt.text = text
	_message_timer = message_time


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
		icon.gamepad = using_gamepad
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


## One slot per queued shot, in queue order, copied from the hidden
## SlotTemplate: the target's portrait (placeholder if null) over "ENEMY 1", "ENEMY 2", ...
func set_queue(portraits: Array[Texture2D]) -> void:
	var count := portraits.size()
	while _slots.size() < count:
		var slot := _slot_template.duplicate() as Control
		slot.visible = true
		_queue_row.add_child(slot)
		_slots.append(slot)
	while _slots.size() > count:
		_slots.pop_back().queue_free()
	for i in _slots.size():
		(_slots[i].get_node("VBox/Label") as Label).text = queued_format % (i + 1)
		(_slots[i].get_node("VBox/Icon") as TextureRect).texture = 				portraits[i] if portraits[i] != null else PORTRAIT_PLACEHOLDER


## Projects the player and target points onto the screen: connector lines to
## every target, queued ones highlighted, and the reticle on `cursor` (index
## into targets, -1 for none) with its queue number, range state and distance.
## `queued` lists indices into targets in queue order (-1 for off-list ones).
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
