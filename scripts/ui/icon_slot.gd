class_name IconSlot
extends PanelContainer
## Square equipment/inventory slot: an icon picture in a sunken Windows 95
## field (theme type ItemSlot), an optional stack count in the bottom-right
## corner (SlotCount) and the theme's accent outline when selected. The name goes in the hover tooltip; the icon is the
## primary display. Used by the status screen and the HUD's loadout window, all
## at SIZE so every icon square matches. Icon art is drawn on a transparent
## background. A null icon shows `placeholder` instead; an empty slot
## (show_empty()) is just the dimmed frame.

## Side length of every icon slot (pixels).
const SIZE := 56.0

## Shown when an icon is null, so nothing renders as a blank box.
@export var placeholder: Texture2D = preload("res://textures/ui/icons/placeholder_item.png")

var _selected: bool = false
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
