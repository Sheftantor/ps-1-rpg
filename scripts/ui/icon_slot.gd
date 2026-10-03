class_name IconSlot
extends PanelContainer
## Square equipment/inventory slot: a framed icon picture, an optional stack
## count in the bottom-right corner and a bright frame when selected. The name
## goes in the hover tooltip; the icon is the primary display. Used by the HUD's
## loadout row and the status screen. A null icon shows `placeholder` instead;
## an empty slot (show_empty()) is just the dimmed frame.

## Shown when an icon is null, so nothing renders as a blank box.
@export var placeholder: Texture2D = preload("res://textures/ui/icons/placeholder_item.png")
@export var frame_color: Color = Color(0.55, 0.55, 0.6, 0.9)
@export var selected_color: Color = Color(1.0, 0.85, 0.35, 1.0)

var _style := StyleBoxFlat.new()
var _icon := TextureRect.new()
var _count := Label.new()


func _init() -> void:
	_style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	_style.set_border_width_all(2)
	_style.set_content_margin_all(3)
	add_theme_stylebox_override(&"panel", _style)

	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override(&"font_size", 28)
	_count.add_theme_constant_override(&"outline_size", 6)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	set_slot_size(52.0)
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
	_style.border_color = frame_color * Color(1, 1, 1, 0.45)


## Bright frame for the active/selected slot.
func set_selected(selected: bool) -> void:
	_style.border_color = selected_color if selected else frame_color
