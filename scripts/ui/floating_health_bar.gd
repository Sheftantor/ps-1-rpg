class_name FloatingHealthBar
extends Node3D
## World-space health bar over a character's head, always facing the camera. Its
## on-screen size eases between max_scale up close and min_scale far away, so
## distant bars recede and nearby ones get big and readable. The bar is ordinary Controls
## drawn into the Canvas SubViewport and shown on a billboarded Sprite3D, so it
## can be styled in the editor. The optional Bar is a TextureProgressBar with a
## fixed texture: losing health shrinks how much of it shows (enemies have no
## bar, only the number). Enemy bars also carry a LevelBadge over the number.
## The white HealthValue always shows current health; each hit spawns a copy of the
## hidden DamageNumber (yellow, above the middle of the bar) that drifts up a
## little and fades out. With place_to_side on, the display slides off to the
## side of the character facing away from the middle of the screen (where the
## player stands), so the number never covers the model. Used by
## res://scenes/enemy_health_bar.tscn and player_health_bar.tscn.

## The character's Health node.
@export var health_path: NodePath = ^"../Health"
## Seconds a damage number takes to drift up and fade out.
@export var number_time: float = 1.1
## How far (canvas pixels) a damage number drifts up while fading.
@export var number_rise: float = 18.0
@export var hide_on_death: bool = true

@export_group("Distance Scaling")
## Scale the bar with camera distance. Off = fixed on-screen size.
@export var scale_with_distance: bool = true
## On-screen size multiplier at far_distance and beyond.
@export_range(0.1, 2.0, 0.05) var min_scale: float = 0.5
## On-screen size multiplier at near_distance and closer. This is the cap, so
## the bar never grows past it however close the camera gets.
@export_range(0.5, 4.0, 0.05) var max_scale: float = 1.5
## Camera distance (m) at which the bar reaches max_scale.
@export var near_distance: float = 4.0
## Camera distance (m) at which the bar shrinks to min_scale.
@export var far_distance: float = 30.0
## How quickly the size eases toward its target. Higher = snappier.
@export var scale_smoothing: float = 8.0
## Outlines thicken as the bar shrinks so their on-screen width never drops
## below this fraction of the full-size outline.
@export_range(0.0, 1.0, 0.05) var min_outline_fraction: float = 0.8

@export_group("Side Placement")
## Move the display beside the character instead of straight over it.
@export var place_to_side: bool = false
## The character's half-width (m): the number's inner edge sits this far from
## its center, along the camera's right.
@export var side_distance: float = 0.45
## Gap (canvas pixels) between the character's edge and the number's inner edge.
## 0 = touching; negative tucks it in tighter.
@export var side_gap: float = 0.0
## Height change (m) while beside the character, so the number sits next to the
## head rather than floating off its top corner.
@export var side_drop: float = 0.6
## Fraction of the screen width either side of center where the side won't flip,
## so a character near the middle doesn't make the number jump back and forth.
@export_range(0.0, 0.5, 0.01) var side_deadzone: float = 0.05
## Past this fraction from center the number goes on the inner side instead, so it
## doesn't run off the screen edge.
@export_range(0.0, 0.5, 0.01) var side_edge: float = 0.4
## How quickly the display slides to its side. Higher = snappier.
@export var side_smoothing: float = 10.0

@onready var _display: Sprite3D = $Display
@onready var _canvas: SubViewport = $Canvas
## Optional: enemy bars are just the number, the player's has a bar too.
@onready var _bar: Range = get_node_or_null(^"Canvas/Root/Bar")
@onready var _value: Label = $Canvas/Root/HealthValue
@onready var _damage_template: Label = $Canvas/Root/DamageNumber
## Optional: the enemy level badge over the number (EnemyLevelBadge).
@onready var _badge: Control = get_node_or_null(^"Canvas/Root/LevelBadge")
@onready var _base_pixel_size: float = _display.pixel_size

var _scale := 1.0
# Side the display is heading for (-1 left, 1 right) and where it is now.
var _side := 1.0
var _side_now := 1.0
# Half the drawn width (canvas pixels) of the health number, outline included.
var _text_half_width := 0.0
# Per-instance label settings (shared .tres copies) with their base outline sizes.
var _outlines: Dictionary[LabelSettings, int] = {}


func _ready() -> void:
	_display.texture = _canvas.get_texture()
	_damage_template.visible = false
	# Own copies so changing outline thickness doesn't touch other bars. Damage
	# numbers are duplicated from the template, so they share its copy.
	for label: Label in [_value, _damage_template]:
		label.label_settings = label.label_settings.duplicate()
		_outlines[label.label_settings] = label.label_settings.outline_size
	if scale_with_distance:
		_scale = _target_scale()
		_apply_scale()
	var health := get_node(health_path) as Health
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_on_health_changed(health.current, health.max_health)


func _process(delta: float) -> void:
	if not _display.visible:
		return
	if place_to_side:
		_update_side(delta)
	if not scale_with_distance:
		return
	var target := _target_scale()
	if is_equal_approx(_scale, target):
		return
	_scale = lerpf(_scale, target, 1.0 - exp(-scale_smoothing * delta))
	_apply_scale()


## Slides the display to the side of the character away from the screen's center.
func _update_side(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from_center := camera.unproject_position(global_position).x / get_viewport().get_visible_rect().size.x - 0.5
	if absf(from_center) > side_edge:
		_side = -signf(from_center)
	elif absf(from_center) > side_deadzone:
		_side = signf(from_center)
	_side_now = lerpf(_side_now, _side, 1.0 - exp(-side_smoothing * delta))
	_display.global_position = global_position + camera.global_basis.x * side_distance * _side_now 			+ Vector3.DOWN * side_drop
	# The Sprite3D is a fixed_size billboard, so offset is a constant on-screen
	# push: just enough to put the number's inner edge at the character's edge.
	_display.offset.x = (_text_half_width + side_gap) * _side_now


func _target_scale() -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return _scale
	var distance := camera.global_position.distance_to(global_position)
	var t := inverse_lerp(near_distance, far_distance, distance)
	return lerpf(max_scale, min_scale, clampf(t, 0.0, 1.0))


func _apply_scale() -> void:
	# The Sprite3D is fixed_size, so pixel_size sets its on-screen size directly.
	_display.pixel_size = _base_pixel_size * _scale
	# Outlines shrink with the bar; below full size, thicken them in canvas
	# pixels so they stay at least min_outline_fraction as wide on screen.
	var boost := maxf(1.0, min_outline_fraction / _scale)
	for settings: LabelSettings in _outlines:
		var outline := roundi(_outlines[settings] * boost)
		if settings.outline_size != outline:
			settings.outline_size = outline


func _on_health_changed(current: int, maximum: int) -> void:
	if _bar != null:
		_bar.max_value = maximum
		_bar.value = current
	_value.text = str(current)
	var settings := _value.label_settings
	# Just the glyphs: the outline's dark edge may touch the character.
	_text_half_width = settings.font.get_string_size(_value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, settings.font_size).x * 0.5


func _on_damaged(amount: int) -> void:
	var number := _damage_template.duplicate() as Label
	number.text = str(amount)
	number.visible = true
	_damage_template.get_parent().add_child(number)
	var tween := number.create_tween().set_parallel()
	tween.tween_property(number, ^"position:y", number.position.y - number_rise, number_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(number, ^"modulate:a", 0.0, number_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(number.queue_free)


func _on_died() -> void:
	if hide_on_death:
		if _bar != null:
			_bar.visible = false
		_value.visible = false
		if _badge != null:
			_badge.visible = false
