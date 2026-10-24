class_name ItemTooltip
extends CanvasLayer
## The one item tooltip for every screen (res://scenes/item_tooltip.tscn): a
## WoW-style Windows 95 panel that fades in next to the cursor after it rests on
## an icon, follows it, flips left / up at the screen edges, and sits above all
## other UI without ever taking the mouse. Made on first use by service() and
## kept under the tree root. Screens call hover() / leave() from their slots'
## mouse signals, and focus() for controller focus (placed beside the slot).
## Moving straight from one icon to the next swaps the text in place: no delay,
## no fade, no flicker. Holding Shift over gear that isn't equipped also shows
## the equipped piece for that slot.
##
## Content is a Resource (ItemStack, ItemData, WeaponData, MeleeWeaponData,
## ArmorData, LootCash) or, for an empty slot, {title, body}. Only real item fields are
## shown, and lines with no data are left out: the item has no rarity, level
## requirement or sell value yet, so names use the common colour.

const SCENE_PATH := "res://scenes/item_tooltip.tscn"

## Seconds the mouse must rest on an icon before the tooltip appears.
@export var hover_delay: float = 0.12
## Fade in / out time (s).
@export var fade_in: float = 0.12
@export var fade_out: float = 0.08
## From the cursor to the tooltip's corner (pixels).
@export var cursor_offset: Vector2 = Vector2(16, 16)
## Gap between the two panels when comparing (pixels).
@export var compare_gap: float = 8.0

## Name colour. No item has a rarity yet, so everything is common for now.
const COMMON := Color(1, 1, 1)
const GOOD := Color(0.4, 0.95, 0.4)
const BAD := Color(1.0, 0.35, 0.3)
const FLAVOR := Color(0.68, 0.68, 0.7)
const SLOT_NAMES := {
	ArmorData.Slot.SHIRT: "Shirt", ArmorData.Slot.NECK: "Neck", ArmorData.Slot.ARMS: "Arms",
	ArmorData.Slot.BELT: "Belt", ArmorData.Slot.PANTS: "Pants", ArmorData.Slot.SHOES: "Shoes",
	ArmorData.Slot.RING_1: "Ring", ArmorData.Slot.RING_2: "Ring", ArmorData.Slot.TRINKET_1: "Trinket",
	ArmorData.Slot.TRINKET_2: "Trinket", ArmorData.Slot.CHARM: "Charm",
}
## Wait after leaving an icon before fading out, so moving to the next one
## doesn't flash the tooltip off and on (s).
const LEAVE_GRACE := 0.12

static var _instance: ItemTooltip = null

var _owner: Control = null
var _content: Variant = null
## True when placed by the mouse, false when beside a focused slot.
var _follow_mouse: bool = true
var _delay: float = -1.0
var _grace: float = -1.0
var _shown: bool = false
var _comparing: bool = false
var _tween: Tween = null
var _italic: FontVariation = null

@onready var _panel: PanelContainer = $Panel
@onready var _lines: VBoxContainer = $Panel/Lines
@onready var _compare: PanelContainer = $Compare
@onready var _compare_lines: VBoxContainer = $Compare/Lines


## The shared tooltip, created under the tree root the first time.
static func service() -> ItemTooltip:
	if not is_instance_valid(_instance):
		_instance = (load(SCENE_PATH) as PackedScene).instantiate() as ItemTooltip
		(Engine.get_main_loop() as SceneTree).root.add_child(_instance)
	return _instance


func _ready() -> void:
	_panel.visible = false
	_compare.visible = false
	_panel.modulate.a = 0.0
	var base := _panel.get_theme_font(&"font", &"TooltipLabel")
	_italic = FontVariation.new()
	_italic.base_font = base
	_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)


## The mouse rests on owner, showing content.
func hover(owner: Control, content: Variant) -> void:
	_start(owner, content, true)


## Controller focus on owner: the tooltip goes beside it rather than the cursor.
func focus(owner: Control, content: Variant) -> void:
	_start(owner, content, false)


## The mouse left (or focus moved off) owner.
func leave(owner: Control) -> void:
	if owner == _owner:
		_grace = LEAVE_GRACE


func hide_now() -> void:
	_owner = null
	_content = null
	_delay = -1.0
	_grace = -1.0
	_shown = false
	if _tween != null:
		_tween.kill()
	_panel.modulate.a = 0.0
	_panel.visible = false
	_compare.visible = false


func _start(owner: Control, content: Variant, follow_mouse: bool) -> void:
	_owner = owner
	_content = content
	_follow_mouse = follow_mouse
	_grace = -1.0
	if _shown or _panel.visible:
		# Still up (or fading out) from another icon: swap the text in place
		# and come straight back, no delay.
		_shown = true
		_delay = -1.0
		_rebuild()
		_fade(1.0, fade_in * (1.0 - _panel.modulate.a))
	else:
		_delay = hover_delay


func _process(delta: float) -> void:
	# The icon was freed or its screen closed.
	if _owner != null and (not is_instance_valid(_owner) or not _owner.is_visible_in_tree()):
		hide_now()
		return
	if _grace >= 0.0:
		_grace -= delta
		if _grace < 0.0:
			_owner = null
			_content = null
			_delay = -1.0
			_shown = false
			_fade(0.0, fade_out)
	if _delay >= 0.0:
		_delay -= delta
		if _delay < 0.0 and _owner != null:
			_shown = true
			_rebuild()
			_fade(1.0, fade_in)
	if _panel.visible:
		var comparing := _owner != null and Input.is_key_pressed(KEY_SHIFT) and _equipped_for(_content) != null
		if comparing != _comparing:
			_comparing = comparing
			_rebuild()
		_place()


func _fade(to: float, time: float) -> void:
	if _tween != null:
		_tween.kill()
	_panel.visible = true
	if time <= 0.0:
		_panel.modulate.a = to
		_compare.modulate.a = to
		return
	_tween = create_tween().set_parallel()
	_tween.tween_property(_panel, ^"modulate:a", to, time)
	_tween.tween_property(_compare, ^"modulate:a", to, time)
	if to == 0.0:
		_tween.chain().tween_callback(func() -> void:
			_panel.visible = false
			_compare.visible = false)


func _rebuild() -> void:
	_fill(_lines, _content)
	var equipped: Variant = _equipped_for(_content) if _comparing else null
	_compare.visible = equipped != null
	if equipped != null:
		_fill(_compare_lines, equipped, "EQUIPPED")
	_panel.size = Vector2.ZERO
	_compare.size = Vector2.ZERO


## Next to the cursor (or the focused slot), flipped to stay on screen.
func _place() -> void:
	var screen := _panel.get_viewport_rect().size
	var size := _panel.get_combined_minimum_size()
	var total := size
	if _compare.visible:
		var extra := _compare.get_combined_minimum_size()
		total = Vector2(size.x + compare_gap + extra.x, maxf(size.y, extra.y))
	var anchor: Vector2
	var flip_anchor: Vector2
	if _follow_mouse or not is_instance_valid(_owner):
		var mouse := _panel.get_viewport().get_mouse_position()
		anchor = mouse + cursor_offset
		flip_anchor = mouse - cursor_offset
	else:
		var rect := _owner.get_global_rect()
		anchor = Vector2(rect.end.x + cursor_offset.x, rect.position.y)
		flip_anchor = Vector2(rect.position.x - cursor_offset.x, rect.end.y)
	var pos := anchor
	if pos.x + total.x > screen.x:
		pos.x = flip_anchor.x - total.x
	if pos.y + total.y > screen.y:
		pos.y = flip_anchor.y - total.y
	pos = pos.clamp(Vector2.ZERO, (screen - total).max(Vector2.ZERO)).round()
	_panel.position = pos
	if _compare.visible:
		_compare.position = Vector2(pos.x + size.x + compare_gap, pos.y)


# --- Content -------------------------------------------------------------------

func _fill(box: VBoxContainer, content: Variant, header := "") -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	if header != "":
		_line(box, header, &"TooltipLabel", FLAVOR)
	if content is Dictionary:
		_line(box, String(content.get("title", "")), &"", COMMON)
		_line(box, String(content.get("body", "")), &"TooltipLabel", FLAVOR, true, true)
		return
	var player := _player()
	if content is LootCash:
		_line(box, "Cash", &"", COMMON)
		_line(box, "$%d" % (content as LootCash).amount, &"TooltipLabel", GOOD)
	elif content is ItemStack:
		var stack := content as ItemStack
		_item(box, stack.item)
		if stack.count > 1:
			_line(box, "Stack: %d" % stack.count, &"TooltipLabel")
		_flavor(box, stack.item.description)
	elif content is ItemData:
		_item(box, content as ItemData)
		_flavor(box, (content as ItemData).description)
	elif content is WeaponData:
		var gun := content as WeaponData
		_line(box, gun.display_name, &"", COMMON)
		_line(box, "Gun", &"TooltipLabel", FLAVOR)
		if gun.shot != null:
			_line(box, "%d Damage" % gun.shot.damage, &"TooltipLabel")
		_line(box, "Range %d m   Lock-on %d m" % [roundi(gun.effective_range), roundi(gun.lock_range)], &"TooltipLabel")
		if gun.shot_energy_cost > 0.0:
			_line(box, "%d Energy per shot" % roundi(gun.shot_energy_cost), &"TooltipLabel")
		_flavor(box, gun.description)
	elif content is MeleeWeaponData:
		var melee := content as MeleeWeaponData
		_line(box, melee.display_name, &"", COMMON)
		_line(box, "Melee Weapon", &"TooltipLabel", FLAVOR)
		var attack := GearText.melee_damage(player) if player != null else 0
		if attack > 0:
			_line(box, "%d Damage" % attack, &"TooltipLabel")
		_flavor(box, melee.description)
	elif content is ArmorData:
		var piece := content as ArmorData
		_line(box, piece.display_name, &"", COMMON)
		var accessory := piece.slot >= ArmorData.Slot.RING_1
		_line(box, ("Accessory" if accessory else "Armor") + "   " + String(SLOT_NAMES.get(piece.slot, "")),
				&"TooltipLabel", FLAVOR)
		if piece.defense > 0:
			_line(box, "+%d Defense" % piece.defense, &"TooltipLabel", GOOD)
		_flavor(box, piece.description)


func _item(box: VBoxContainer, item: ItemData) -> void:
	_line(box, item.display_name, &"", COMMON)
	_line(box, "Consumable", &"TooltipLabel", FLAVOR)
	if item.heal_amount > 0:
		_line(box, "+%d Health" % item.heal_amount, &"TooltipLabel", GOOD)
	if item.stamina_restore > 0.0:
		_line(box, "+%d Energy" % roundi(item.stamina_restore), &"TooltipLabel", GOOD)


func _flavor(box: VBoxContainer, text: String) -> void:
	if text.strip_edges() != "":
		_line(box, text, &"TooltipLabel", FLAVOR, true, true)


func _line(box: VBoxContainer, text: String, type: StringName, color := Color(), italic := false,
		wrap := false) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if type != &"":
		label.theme_type_variation = type
	if color != Color():
		label.add_theme_color_override(&"font_color", color)
	if italic:
		label.add_theme_font_override(&"font", _italic)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 340
	box.add_child(label)


## The piece the player has equipped where content would go, if it's different.
func _equipped_for(content: Variant) -> Variant:
	var player := _player()
	if player == null:
		return null
	var equipped: Variant = null
	if content is WeaponData:
		equipped = player.gun
	elif content is MeleeWeaponData:
		equipped = player.melee_weapon
	elif content is ArmorData:
		equipped = player.armor.get((content as ArmorData).slot)
	return null if equipped == null or equipped == content else equipped


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player
