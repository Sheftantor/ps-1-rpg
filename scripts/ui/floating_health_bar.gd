class_name FloatingHealthBar
extends Node3D
## World-space health bar over a character's head, always facing the camera at a
## fixed on-screen size (readable at any distance). The bar is ordinary Controls
## drawn into the Canvas SubViewport and shown on a billboarded Sprite3D, so it
## can be styled in the editor. The fill is a TextureProgressBar with a fixed
## texture: losing health shrinks how much of it shows. The white HealthValue
## beside the bar always shows current health; each hit spawns a copy of the
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

@onready var _display: Sprite3D = $Display
@onready var _canvas: SubViewport = $Canvas
@onready var _bar: Range = $Canvas/Root/Bar
@onready var _value: Label = $Canvas/Root/HealthValue
@onready var _damage_template: Label = $Canvas/Root/DamageNumber


func _ready() -> void:
	_display.texture = _canvas.get_texture()
	_damage_template.visible = false
	var health := get_node(health_path) as Health
	health.changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_on_health_changed(health.current, health.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
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
		_bar.visible = false
		_value.visible = false
