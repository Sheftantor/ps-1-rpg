class_name SuitGuy
extends Enemy
## Ranged enemy: a headless man in a suit with a suppressed pistol. Health,
## hurtbox, hit flash, stagger, death, XP and the health bar / level badge are
## Enemy's; this adds the senses and the shot. States (scripts/enemy/suit_guy/states/):
## Wander -> Engage -> Attack (windup, shot, lower) -> Engage ... -> Wander.

## Wandering speed around the spawn point (m/s). The area is Enemy.patrol_area.
@export var walk_speed: float = 0.9
## Engages when the player is this close (m) and in line of sight.
@export var detect_range: float = 14.0
## Gives up beyond this distance (m).
@export var lose_range: float = 22.0
## Gives up after losing line of sight for this long (s).
@export var lose_sight_time: float = 3.0
## Seconds from one shot to the next.
@export var fire_interval: float = 3.0
## Gun-raise before each shot (s): the tell for the player's dodge.
@export var windup: float = 0.4
## Delay before the first windup after spotting the player (s).
@export var first_shot_delay: float = 0.6
## Of the windup, how long the gun is held at chest height before the shot (s);
## the rest is the raise. The shot still comes `windup` after the raise starts.
@export_range(0.0, 1.0, 0.01) var aim_hold_seconds: float = 0.25

@export_group("Posture")
## Legs and torso length (arms untouched): 1 = the model as built. Taller or
## lower stance.
@export_range(0.8, 1.4, 0.01) var stand_height_scale: float = 1.12:
	set(value):
		stand_height_scale = value
		_apply_posture()
## Torso lean behind vertical (degrees); negative leans forward.
@export_range(-10.0, 20.0, 0.5) var lean_back_degrees: float = 4.0:
	set(value):
		lean_back_degrees = value
		_apply_posture()
## Torso turn while aiming, gun side toward the player (degrees).
@export_range(0.0, 60.0, 1.0) var aim_turn_degrees: float = 30.0:
	set(value):
		aim_turn_degrees = value
		_apply_posture()
## Clavicles raised (degrees): higher shoulders, collar higher.
@export_range(0.0, 30.0, 0.5) var shoulder_raise_degrees: float = 10.0:
	set(value):
		shoulder_raise_degrees = value
		_apply_posture()
## Shoulders pulled back (degrees): squarer, broader chest.
@export_range(0.0, 30.0, 0.5) var shoulder_square_degrees: float = 8.0:
	set(value):
		shoulder_square_degrees = value
		_apply_posture()
## Silencer angle below level at low-ready (degrees).
@export_range(0.0, 60.0, 1.0) var low_ready_pitch_degrees: float = 25.0:
	set(value):
		low_ready_pitch_degrees = value
		_apply_posture()
## Hip bob kept while walking (1 = the walk clip's own).
@export_range(0.0, 1.0, 0.05) var walk_bob_scale: float = 0.4:
	set(value):
		walk_bob_scale = value
		_apply_posture()
## Gun kick on each shot (degrees).
@export_range(0.0, 30.0, 0.5) var recoil_degrees: float = 8.0:
	set(value):
		recoil_degrees = value
		_apply_posture()
## Gap from the collar up to the health bar's anchor (m). The bar follows the
## collar, so it stays above him at any stand_height_scale.
@export var health_bar_clearance: float = 0.5

@export_group("Projectile")
@export var projectile_scene: PackedScene = preload("res://scenes/pistol_bolt.tscn")
@export var projectile_speed: float = 18.0
## Raw bullet damage, used only when stats.damage_percent is 0 (still scaled by
## the level gap; see Enemy.scaled_damage()).
@export var damage: int = 10
@export var projectile_lifetime: float = 3.0

## Line-of-sight checks start this far above the collar (m): about where his
## eyes would be. He has no head.
const EYE_ABOVE_COLLAR: float = 0.15
## How quickly the health bar follows the collar's height (per second).
const HEALTH_BAR_FOLLOW: float = 6.0
## What blocks sight: the world (layer 1).
const SIGHT_MASK: int = 1

## Counts down to the next shot; Engage starts the windup when it reaches zero.
var shot_cooldown: float = 0.0

@onready var _health_bar: Node3D = $HealthBar


func _ready() -> void:
	super()
	_apply_posture()
	_health_bar.position.y = suit_model().collar_height() + health_bar_clearance


func _process(delta: float) -> void:
	var target := suit_model().collar_height() + health_bar_clearance
	_health_bar.position.y = lerpf(_health_bar.position.y, target, 1.0 - exp(-HEALTH_BAR_FOLLOW * delta))


func _physics_process(delta: float) -> void:
	super(delta)
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)


func suit_model() -> SuitModel:
	return model as SuitModel


## Clear line from this body's eye height to the player's chest.
func has_line_of_sight() -> bool:
	if not has_target():
		return false
	var eye := global_position + Vector3.UP * (suit_model().collar_height() + EYE_ABOVE_COLLAR)
	var query := PhysicsRayQueryParameters3D.create(eye,
			_target_chest(), SIGHT_MASK, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Fires one bolt from the muzzle at the player's chest as it is right now.
func fire_shot() -> void:
	var gun := suit_model().gun
	var muzzle := gun.muzzle.global_position
	var direction := (_target_chest() - muzzle) if has_target() else gun.muzzle_direction()
	var bolt := projectile_scene.instantiate() as PistolBolt
	bolt.speed = projectile_speed
	bolt.damage = scaled_damage(damage)
	bolt.lifetime = projectile_lifetime
	var world := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child(bolt)
	bolt.launch(muzzle, direction, self)
	suit_model().fire()
	shot_cooldown = fire_interval - windup


func _target_chest() -> Vector3:
	var player := target as Player
	return player.aim_origin() if player != null else target.global_position + Vector3.UP * 1.3


## Pushes the Posture group to the model's SuitPosture.
func _apply_posture() -> void:
	if not is_node_ready():
		return
	var posture := suit_model().posture
	posture.stand_height_scale = stand_height_scale
	posture.lean_back_degrees = lean_back_degrees
	posture.aim_turn_degrees = aim_turn_degrees
	posture.shoulder_raise_degrees = shoulder_raise_degrees
	posture.shoulder_square_degrees = shoulder_square_degrees
	posture.low_ready_pitch_degrees = low_ready_pitch_degrees
	posture.walk_bob_scale = walk_bob_scale
	posture.recoil_degrees = recoil_degrees
