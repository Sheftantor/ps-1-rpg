@tool
class_name Win95Palette
extends Resource
## Every color and size of the Windows 95 look, in one place. The theme
## builder (res://scripts/tools/build_win95_theme.gd) turns a palette into a
## Theme: res://resources/ui/win95/palette_dark.tres -> win95_dark.tres (the
## project theme), palette_light.tres -> win95_light.tres. Change a value here
## and rerun the builder; or tweak the generated Theme directly in the editor.

@export_group("Colors")
## Behind windows: the "desktop".
@export var desktop: Color = Color("12302f")
## Window and panel face; raised buttons.
@export var face: Color = Color("2a2c31")
## Sunken fields: text inputs, dropdowns, lists, item slots, bar troughs.
@export var field: Color = Color("17181b")
@export var text: Color = Color("e8e6df")
## Hints, disabled text.
@export var muted: Color = Color("a8a59b")
## Bevel: top and left of raised things (bottom and right of sunken ones).
@export var highlight: Color = Color("44474f")
## Bevel: bottom and right of raised things; drop shadows; outlines.
@export var shadow: Color = Color("0d0e10")
@export var title_left: Color = Color("26418a")
@export var title_right: Color = Color("4a72cc")
@export var title_text: Color = Color("ffffff")
## Focus outline, selection bar.
@export var accent: Color = Color("fb923c")
## Mouse cursor (the classic arrow): fill and outline.
@export var cursor_fill: Color = Color("ffffff")
@export var cursor_outline: Color = Color("000000")
## How much lighter a hovered button's face is (0-1).
@export_range(0.0, 0.5) var hover_lighten: float = 0.07

@export_group("Bar Fills")
@export var health_fill: Color = Color("c8463c")
@export var energy_fill: Color = Color("d6b23a")
@export var xp_fill: Color = Color("8a5cd6")
@export var enemy_health_fill: Color = Color("c8463c")
## Damage just taken, shown behind the fill as it drains.
@export var under_fill: Color = Color("e8e6df")

@export_group("Sizes (px)")
## Multiplies every size below (and font sizes). 1 = the sizes as designed;
## 2 = pixel-doubled, for a 1080p screen.
@export_range(1, 4) var scale: int = 1
@export var body_font_size: int = 14
@export var small_font_size: int = 12
@export var title_font_size: int = 15
@export var heading_font_size: int = 26
@export var tag_font_size: int = 11
@export var bevel: int = 2
@export var drop_shadow: int = 2
@export var focus_outline: int = 2
@export var bar_outline: int = 1
@export var title_height: int = 30
@export var title_padding: int = 8
@export var body_padding: int = 12
@export var body_separation: int = 10
@export var selection_bar: int = 3
@export var scrollbar_width: int = 16
## Button text inset from the bevel.
@export var button_padding_x: int = 10
@export var button_padding_y: int = 4
@export var field_padding: int = 5
## Title bar buttons (minimize, close).
@export var title_button_size: Vector2i = Vector2i(16, 14)
@export var checkbox_size: int = 13
## Keyboard focus: the dotted rectangle's dot size and its inset from the edge.
@export var focus_dots: int = 1
@export var focus_dots_inset: int = 4

@export_group("Fonts")
@export var title_font: Font
@export var body_font: Font
@export var mono_font: Font


## size * scale.
func px(size: int) -> int:
	return size * scale
