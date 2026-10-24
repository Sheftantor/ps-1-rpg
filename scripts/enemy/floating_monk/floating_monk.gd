class_name FloatingMonk
extends Enemy
## A strong enemy: the floating multi-arm figure (FloatingFigure). Out of reach
## he hovers at a distance and fires volleys of electric bolts at the player;
## once the player is close he rushes in for a seven-strike multi-arm combo
## that ends in a double palm thrust, then is open to punishment. He has poise:
## only a few quick hits in a row (poise_hits) stagger him, and the combo itself
## can't be interrupted (stats.combo_stagger_immune). Health, hurtbox, hit
## flash, death, XP and the health bar are Enemy's. States
## (scripts/enemy/floating_monk/states/):
## Hover -> Engage -> Volley -> Engage ... ; Engage -> Rush -> Attack -> Recover -> Engage.

@export_group("Senses")
## Engages when the player is this close (m) and in line of sight.
@export var detect_range: float = 16.0
## Gives up beyond this distance (m).
@export var lose_range: float = 26.0
## Gives up after losing line of sight for this long (s).
@export var lose_sight_time: float = 4.0

@export_group("Movement")
## Drift speed while hovering at range (m/s).
@export var hover_speed: float = 1.6
## Distance he keeps while firing bolts (m).
@export var preferred_distance: float = 8.0
## Closer than this (m) and the combo is ready: he rushes the player.
@export var close_range: float = 4.0
## The combo starts once the rush brings him this close (m).
@export var combo_range: float = 1.9
## Dash speed of the rush (m/s).
@export var rush_speed: float = 10.0
## The tell before the rush: arms wound back, red flash (s). Still turning.
@export var rush_tell: float = 0.45
## Gives up closing in after dashing this long (s) and strikes anyway.
@export var rush_timeout: float = 0.9

@export_group("Bolts")
@export var projectile_scene: PackedScene = preload("res://scenes/electric_bolt.tscn")
@export var bolt_speed: float = 15.0
@export var bolt_lifetime: float = 3.0
## Raw bolt damage, used only when stats.damage_percent is 0 (still scaled by
## the level gap; see Enemy.scaled_damage()).
@export var bolt_damage: int = 12
## Bolt damage relative to a combo strike when stats.damage_percent is set.
@export_range(0.0, 2.0, 0.05) var bolt_damage_scale: float = 0.7
## Bolts per volley, alternating between bolt_arms.
@export var volley_count: int = 3
## Seconds between the bolts of a volley.
@export var volley_interval: float = 0.25
## The charge before a volley: arms raised at the player, cyan crackle (s).
@export var charge_time: float = 0.75
## From the end of one volley to the next charge (s).
@export var volley_cooldown: float = 2.4
## Delay before the first volley after spotting the player (s).
@export var first_volley_delay: float = 0.8
## The limbs the bolts leave from.
@export var bolt_arms: PackedStringArray = ["Yellow Right Arm", "Red Left Arm"]

@export_group("Combo")
## The last strike (both blue arms, palms first) multiplies damage and knockback.
@export var finisher_damage_scale: float = 1.6
@export var finisher_knockback: float = 9.0

@export_group("Poise")
## Hits in a row (each within poise_recover_time of the last) that stagger him.
@export var poise_hits: int = 4
@export var poise_recover_time: float = 2.0

## Line-of-sight checks start this high above his origin (m): about his eyes.
const EYE_HEIGHT: float = 2.1
## What blocks sight: the world (layer 1).
const SIGHT_MASK: int = 1

## Counts down to the next volley; Engage starts the charge when it reaches zero.
var bolt_cooldown: float = 0.0
var _poise_taken: int = 0
var _poise_timer: float = 0.0


func _ready() -> void:
	# Before Enemy's handler, so a staggering hit already counts toward poise.
	($Hurtbox as Hurtbox).hit_received.connect(_on_poise_hit)
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	bolt_cooldown = maxf(bolt_cooldown - delta, 0.0)
	_poise_timer -= delta
	if _poise_timer <= 0.0:
		_poise_taken = 0


func figure() -> FloatingFigure:
	return model as FloatingFigure


func poise_broken() -> bool:
	return _poise_taken >= poise_hits


func reset_poise() -> void:
	_poise_taken = 0


## Clear line from his eyes to the player's chest.
func has_line_of_sight() -> bool:
	if not has_target():
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * EYE_HEIGHT,
			_target_chest(), SIGHT_MASK, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Fires one electric bolt from a limb's hand at the player's chest as it is now.
func fire_bolt(arm: String) -> void:
	var from := figure().hand_position(arm)
	var bolt := projectile_scene.instantiate() as PistolBolt
	bolt.speed = bolt_speed
	bolt.lifetime = bolt_lifetime
	bolt.damage = scaled_damage(bolt_damage)
	if stats.damage_percent > 0.0:
		bolt.damage = maxi(1, roundi(bolt.damage * bolt_damage_scale))
	var world := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child(bolt)
	var direction := (_target_chest() - from) if has_target() else forward()
	bolt.launch(from, direction, self)


## The last strike of the combo: combo_attack() with the finisher's punch,
## knocking the player down.
func finisher_attack() -> AttackData:
	var attack := combo_attack()
	attack.damage = roundi(attack.damage * finisher_damage_scale)
	attack.knockback = finisher_knockback
	attack.knockdown = true
	attack.heavy_hit = true
	return attack


func _target_chest() -> Vector3:
	var player := target as Player
	return player.aim_origin() if player != null else target.global_position + Vector3.UP * 1.3


func _on_poise_hit(_attack: AttackData, _source: Node3D) -> void:
	_poise_taken += 1
	_poise_timer = poise_recover_time
