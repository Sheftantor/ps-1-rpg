class_name FloatingHealthBar
extends Node3D
## World-space health bar over a character's head, always facing the camera. Its
## on-screen size eases between max_scale up close and min_scale far away, so
## distant bars recede and nearby ones get big and readable. The bar is ordinary Controls
## drawn into the Canvas SubViewport and shown on a billboarded Sprite3D, so it
## can be styled in the editor. The optional Bar is a TextureProgressBar with a
## fixed texture: losing health shrinks how much of it shows (enemies have no
## bar, only the number). The white HealthValue always shows current health; each hit spawns a copy of the
## hidden DamageNumber (yellow, above the middle of the bar) that drifts up a
## little and fades out. Used by res://scenes/enemy_health_bar.tscn and
## player_health_bar.tscn.

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

@onready var _display: Sprite3D = $Display
@onready var _canvas: SubViewport = $Canvas
## Optional: enemy bars are just the number, the player's has a bar too.
@onready var _bar: Range = get_node_or_null(^"Canvas/Root/Bar")
@onready var _value: Label = $Canvas/Root/HealthValue
@onready var _damage_template: Label = $Canvas/Root/DamageNumber
@onready var _base_pixel_size: float = _display.pixel_size

var _scale := 1.0
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
	if not scale_with_distance or not _display.visible:
		return
	var target := _target_scale()
	if is_equal_approx(_scale, target):
		return
	_scale = lerpf(_scale, target, 1.0 - exp(-scale_smoothing * delta))
	_apply_scale()


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
