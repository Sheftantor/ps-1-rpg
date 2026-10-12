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

@export_group("Projectile")
@export var projectile_scene: PackedScene = preload("res://scenes/pistol_bolt.tscn")
@export var projectile_speed: float = 18.0
## Raw bullet damage, used only when stats.damage_percent is 0 (still scaled by
## the level gap; see Enemy.scaled_damage()).
@export var damage: int = 10
@export var projectile_lifetime: float = 3.0

## Height of this body's eyes for line-of-sight checks (m). It has no head, so
## this is about where one would be.
const EYE_HEIGHT: float = 1.5
## What blocks sight: the world (layer 1).
const SIGHT_MASK: int = 1

## Counts down to the next shot; Engage starts the windup when it reaches zero.
var shot_cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	shot_cooldown = maxf(shot_cooldown - delta, 0.0)


func suit_model() -> SuitModel:
	return model as SuitModel


## Clear line from this body's eye height to the player's chest.
func has_line_of_sight() -> bool:
	if not has_target():
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * EYE_HEIGHT,
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
