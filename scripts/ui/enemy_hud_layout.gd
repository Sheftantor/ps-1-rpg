@tool
class_name EnemyHudLayout
extends Node
## Sizes and positions the parts of an enemy's floating HUD
## (res://scenes/enemy_health_bar.tscn); a child of the EnemyHealthBar root.
## The level badge's scale changes its real font and outline sizes rather than
## scaling the Control, so the pixel font stays crisp: font sizes snap to whole
## multiples of the font's 16 px em (each font pixel = a whole number of screen
## pixels), and the badge box shrinks by the same amount. The health bar
## (a PixelHealthBar) hangs just under the badge digits (bar_gap apart) whatever
## their size. Applies live in the editor. Only enemy HUDs have this; the
## player's bar is unaffected.

## The health bar's size in canvas pixels, its 3 px frame included. 16+ tall
## shows every shade of its gloss; shorter skips a few.
@export var health_bar_size: Vector2i = Vector2i(64, 14):
	set(value):
		health_bar_size = value
		_refresh()
## The level number over the bar. 1.0 = the 48 px font.
@export_range(0.2, 1.5, 0.05) var level_badge_scale: float = 1.0:
	set(value):
		level_badge_scale = value
		_refresh()
## Space (canvas pixels) between the level digits and the top of the bar.
## 0 = just touching; negative overlaps them, positive spreads them apart.
@export var bar_gap: float = 0.0:
	set(value):
		bar_gap = value
		_refresh()
## How far (canvas pixels) the whole HUD sits above its anchor over the head.
## Higher = higher on screen. Constant on screen, like the rest of the HUD.
@export var hud_height_offset: float = 30.0:
	set(value):
		hud_height_offset = value
		_refresh()

## Unscaled badge style and box; scaled copies are made from these each time, so
## changes never pile up or leak into the shared .tres file.
const BADGE_SETTINGS: LabelSettings = preload("res://resources/ui/level_badge.tres")
const BADGE_RECT := Rect2(197, 102, 46, 46)
## Roughly half a digit's drawn height as a fraction of the font size (this
## font's digits are about 70% of it), used to hang the bar under the digits.
const DIGIT_HALF_HEIGHT := 0.35
## The pixel font's em in font pixels (MGS1 HUD: 1024 units, 64 per pixel).
const PIXEL_FONT_GRID := 16


func _ready() -> void:
	# Runs before the FloatingHealthBar's _ready, so it picks up the final sizes.
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var root := get_parent()
	var display := root.get_node_or_null(^"Display") as Sprite3D
	var bar := root.get_node_or_null(^"Canvas/Root/Bar") as Control
	var badge := root.get_node_or_null(^"Canvas/Root/LevelBadge") as Control
	var badge_label := root.get_node_or_null(^"Canvas/Root/LevelBadge/LevelLabel") as Label
	if display != null:
		display.offset.y = hud_height_offset
	var badge_settings := _scaled(BADGE_SETTINGS, level_badge_scale)
	if badge != null and badge_label != null:
		badge_label.label_settings = badge_settings
		_set_rect(badge, BADGE_RECT.get_center(), BADGE_RECT.size * level_badge_scale)
	if bar != null:
		# Centre the bar just below the badge digits.
		var drop := badge_settings.font_size * DIGIT_HALF_HEIGHT + bar_gap + health_bar_size.y * 0.5
		_set_rect(bar, BADGE_RECT.get_center() + Vector2(0, drop), Vector2(health_bar_size))


func _scaled(base: LabelSettings, factor: float) -> LabelSettings:
	var settings := base.duplicate() as LabelSettings
	settings.font_size = PIXEL_FONT_GRID * maxi(1, roundi(base.font_size * factor / PIXEL_FONT_GRID))
	if base.outline_size > 0:
		settings.outline_size = maxi(1, roundi(base.outline_size * factor))
	return settings


## Places a box of the given size around a centre, snapped to whole pixels.
func _set_rect(control: Control, center: Vector2, box_size: Vector2) -> void:
	var size := box_size.round()
	control.position = (center - size * 0.5).round()
	control.size = size
