@tool
class_name EnemyHudLayout
extends Node
## Sizes and positions the parts of an enemy's floating HUD
## (res://scenes/enemy_health_bar.tscn); a child of the EnemyHealthBar root.
## Scales change the real font and outline sizes (rounded to whole pixels) rather
## than scaling the Controls, so the pixel font stays crisp. The label boxes
## shrink by the same amount. The health number hangs just under the level
## badge (number_gap apart) whatever their sizes. Applies live in the editor.
## Only enemy HUDs have this; the player's bar is unaffected.

## The health number: font, outline and box. 1.0 = the original 56 px font.
@export_range(0.2, 1.5, 0.05) var health_number_scale: float = 0.5:
	set(value):
		health_number_scale = value
		_refresh()
## The level number over the health number. 1.0 = the original 40 px font.
@export_range(0.2, 1.5, 0.05) var level_badge_scale: float = 1.0:
	set(value):
		level_badge_scale = value
		_refresh()
## Space (canvas pixels) between the level digits and the health digits.
## 0 = just touching; negative overlaps them, positive spreads them apart.
@export var number_gap: float = 0.0:
	set(value):
		number_gap = value
		_refresh()
## How far (canvas pixels) the whole HUD sits above its anchor over the head.
## Higher = higher on screen. Constant on screen, like the rest of the HUD.
@export var hud_height_offset: float = 30.0:
	set(value):
		hud_height_offset = value
		_refresh()

## Unscaled styles and boxes; scaled copies are made from these each time, so
## changes never pile up or leak into the shared .tres files.
const HEALTH_SETTINGS: LabelSettings = preload("res://resources/ui/health_value.tres")
const BADGE_SETTINGS: LabelSettings = preload("res://resources/ui/level_badge.tres")
const HEALTH_RECT := Rect2(120, 116, 200, 80)
const BADGE_RECT := Rect2(197, 102, 46, 46)
## Roughly half a digit's drawn height as a fraction of the font size (this
## font's digits are about 70% of it), used to stack the two numbers.
const DIGIT_HALF_HEIGHT := 0.35


func _ready() -> void:
	# Runs before the FloatingHealthBar's _ready, so it picks up the scaled sizes.
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	var root := get_parent()
	var display := root.get_node_or_null(^"Display") as Sprite3D
	var value := root.get_node_or_null(^"Canvas/Root/HealthValue") as Label
	var badge := root.get_node_or_null(^"Canvas/Root/LevelBadge") as Control
	var badge_label := root.get_node_or_null(^"Canvas/Root/LevelBadge/LevelLabel") as Label
	if display != null:
		display.offset.y = hud_height_offset
	var badge_settings := _scaled(BADGE_SETTINGS, level_badge_scale)
	var health_settings := _scaled(HEALTH_SETTINGS, health_number_scale)
	if badge != null and badge_label != null:
		badge_label.label_settings = badge_settings
		_set_rect(badge, BADGE_RECT.get_center(), BADGE_RECT.size * level_badge_scale)
	if value != null:
		value.label_settings = health_settings
		# Centre the health digits just below the badge digits.
		var drop := (badge_settings.font_size + health_settings.font_size) * DIGIT_HALF_HEIGHT + number_gap
		_set_rect(value, BADGE_RECT.get_center() + Vector2(0, drop), HEALTH_RECT.size * health_number_scale)


func _scaled(base: LabelSettings, factor: float) -> LabelSettings:
	var settings := base.duplicate() as LabelSettings
	settings.font_size = maxi(1, roundi(base.font_size * factor))
	if base.outline_size > 0:
		settings.outline_size = maxi(1, roundi(base.outline_size * factor))
	return settings


## Places a box of the given size around a centre, snapped to whole pixels.
func _set_rect(control: Control, center: Vector2, box_size: Vector2) -> void:
	var size := box_size.round()
	control.position = (center - size * 0.5).round()
	control.size = size
