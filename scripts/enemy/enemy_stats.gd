class_name EnemyStats
extends Resource
## Tunable enemy numbers. Edit res://resources/enemies/*.tres in the inspector.

@export var max_health: int = 80

@export_group("Movement")
@export var move_speed: float = 3.5
@export var strafe_speed: float = 2.2
@export var acceleration: float = 20.0
@export var turn_speed: float = 8.0

@export_group("Awareness")
@export var detection_radius: float = 12.0
## Gives up and returns to idle beyond this distance.
@export var lose_interest_radius: float = 22.0
## Length of the "spotted you" beat before engaging.
@export var aware_time: float = 0.6

@export_group("Reposition")
## Circling distance while waiting for a turn to attack (m).
@export var preferred_distance: float = 4.5
## Distance error that produces full-speed correction toward/away from the player.
@export var distance_tolerance: float = 1.5
@export var reposition_time_min: float = 1.2
@export var reposition_time_max: float = 2.8
@export var strafe_flip_time_min: float = 1.5
@export var strafe_flip_time_max: float = 3.5
## When another enemy has the attack turn, retry after this long.
@export var token_retry_interval: float = 0.4
## Gives up the attack turn if it can't close to range in time.
@export var approach_timeout: float = 2.5

@export_group("Combat")
@export var attacks: Array[AttackData] = []
## Stops tracking the player this long before a telegraph ends, so side-dodges work.
@export var telegraph_commit_time: float = 0.15
## After an attack, no enemy may take the next turn for this long.
@export var attack_token_cooldown: float = 0.9
@export var stagger_time: float = 0.4
@export var stagger_friction: float = 18.0
