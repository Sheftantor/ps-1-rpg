class_name PlayerHud
extends CanvasLayer
## Player HUD: top-left health and stamina bars with values, current-weapon
## indicator, pickup prompt and short messages, plus the gun-mode targeting
## overlay (connector web, reticle with target and range-state labels, mode
## label, queued-shot slots, action prompts). Structure and logic only: layout,
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

var _hint: String = ""
var _message_timer: float = 0.0
var _slots: Array[Control] = []

@onready var _health_value: Label = $Root/Stats/HealthRow/Value
@onready var _health_bar: Range = $Root/Stats/HealthBar
@onready var _stamina_value: Label = $Root/Stats/StaminaRow/Value
@onready var _stamina_bar: Range = $Root/Stats/StaminaBar
@onready var _weapon_label: Label = $Root/WeaponLabel
@onready var _prompt: Label = $Root/Prompt
@onready var _targeting: Control = $Root/Targeting
@onready var _links: TargetLinks = $Root/Targeting/Links
@onready var _reticle: TargetReticle = $Root/Targeting/Reticle
@onready var _target_label: Label = $Root/Targeting/Reticle/TargetLabel
@onready var _range_label: Label = $Root/Targeting/Reticle/RangeLabel
@onready var _mode_label: Label = $Root/Targeting/ModeLabel
@onready var _queue_row: HBoxContainer = $Root/Targeting/QueueRow
@onready var _slot_template: Control = $Root/Targeting/QueueRow/SlotTemplate


func _ready() -> void:
	_targeting.visible = false
	_slot_template.visible = false
	_prompt.text = ""


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_prompt.text = _hint


## Top-left stat block; connected to Health.changed / Stamina.changed.
func set_health(current: float, maximum: float) -> void:
	_set_stat(_health_bar, _health_value, current, maximum)


func set_stamina(current: float, maximum: float) -> void:
	_set_stat(_stamina_bar, _stamina_value, current, maximum)


func _set_stat(bar: Range, value_label: Label, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	value_label.text = "%d/%d" % [roundi(current), roundi(maximum)]


func set_weapon(weapon_name: String) -> void:
	_weapon_label.text = weapon_name.to_upper()


## Standing hint (e.g. a pickup in reach); a flash_message() temporarily covers it.
func set_prompt(text: String) -> void:
	_hint = text
	if _message_timer <= 0.0:
		_prompt.text = text


func flash_message(text: String) -> void:
	_prompt.text = text
	_message_timer = message_time


func show_targeting(shown: bool) -> void:
	_targeting.visible = shown


func set_mode_text(text: String) -> void:
	_mode_label.text = text


## One slot per queued shot ("ENEMY 1", "ENEMY 2", ... in queue order), copied
## from the hidden SlotTemplate.
func set_queue(count: int) -> void:
	while _slots.size() < count:
		var slot := _slot_template.duplicate() as Control
		slot.visible = true
		_queue_row.add_child(slot)
		_slots.append(slot)
	while _slots.size() > count:
		_slots.pop_back().queue_free()
	for i in _slots.size():
		(_slots[i].get_node("VBox/Label") as Label).text = queued_format % (i + 1)


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
