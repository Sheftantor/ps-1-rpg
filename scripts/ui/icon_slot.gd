class_name IconSlot
extends PanelContainer
## Square equipment/inventory slot: an icon picture in a sunken Windows 95
## field (theme type ItemSlot), an optional stack count in the bottom-right
## corner (SlotCount) and the theme's accent outline when selected. The name goes in the hover tooltip; the icon is the
## primary display. Used by the status screen and the HUD's loadout window, all
## at SIZE so every icon square matches (the loot window shrinks them with
## set_slot_scale()). Icon art is drawn on a transparent
## background. A null icon shows `placeholder` instead; an empty slot
## (show_empty()) is just the dimmed frame.

## Side length of every icon slot (pixels).
const SIZE := 56.0

## Shown when an icon is null, so nothing renders as a blank box.
@export var placeholder: Texture2D = preload("res://textures/ui/icons/placeholder_item.png")

var _selected: bool = false
## Size relative to SIZE (set_slot_scale); frame margins and the count shrink too.
var _scale: float = 1.0
var _icon := TextureRect.new()
var _count := Label.new()


func _init() -> void:
	theme_type_variation = &"ItemSlot"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.theme_type_variation = &"SlotCount"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	set_slot_size(SIZE)
	set_selected(false)


## Square side length in pixels.
func set_slot_size(side: float) -> void:
	custom_minimum_size = Vector2(side, side)


## The same slot at factor x SIZE, with the frame's inner margins and the stack
## count's font scaled to match (the bevel keeps its width).
func set_slot_scale(factor: float) -> void:
	_scale = factor
	set_slot_size(roundf(SIZE * factor))
	_apply_scale()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_apply_scale()


func _apply_scale() -> void:
	if not is_inside_tree() or is_equal_approx(_scale, 1.0):
		return
	remove_theme_stylebox_override(&"panel")
	_count.remove_theme_font_size_override(&"font_size")
	var box := get_theme_stylebox(&"panel").duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, maxf(2.0, roundf(box.get_content_margin(side) * _scale)))
	add_theme_stylebox_override(&"panel", box)
	_count.add_theme_font_size_override(&"font_size",
			maxi(8, roundi(_count.get_theme_font_size(&"font_size") * _scale)))


## Fills the slot. count > 0 shows a stack count; tooltip is the item's name.
func show_icon(texture: Texture2D, tooltip: String, count: int = 0, selected: bool = false) -> void:
	_icon.texture = texture if texture != null else placeholder
	_icon.modulate = Color.WHITE
	_count.text = str(count) if count > 0 else ""
	tooltip_text = tooltip
	set_selected(selected)


## An unfilled slot (e.g. no gun picked up yet): dimmed frame, no picture.
func show_empty(tooltip: String = "") -> void:
	_icon.texture = null
	_count.text = ""
	tooltip_text = tooltip
	set_selected(false)


## An empty gear slot: a greyed picture of what goes there (e.g. a ring outline)
## on a dimmed frame, so the slot type reads at a glance.
func show_placeholder(texture: Texture2D, tooltip: String = "") -> void:
	_icon.texture = texture
	_icon.modulate = Color(1, 1, 1, 0.75)
	_count.text = ""
	tooltip_text = tooltip
	set_selected(false)


## Accent outline for the active/selected slot.
func set_selected(selected: bool) -> void:
	_selected = selected
	queue_redraw()


func _draw() -> void:
	if _selected:
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))
