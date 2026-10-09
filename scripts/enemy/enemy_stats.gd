class_name EnemyStats
extends Resource
## Tunable enemy numbers. Edit res://resources/enemies/*.tres in the inspector.

@export var max_health: int = 80
## Shown on the level badge over the health number, coloured against the
## player's level. An Enemy's level_override replaces it per instance.
@export_range(1, 99) var level: int = 1
## Face shown in gun mode's target queue slots. Defaults to a generic placeholder.
@export var portrait: Texture2D = preload("res://textures/ui/icons/placeholder_portrait.png")

@export_group("Movement")
@export var move_speed: float = 3.5
@export var strafe_speed: float = 2.2
@export var acceleration: float = 20.0
@export var turn_speed: float = 8.0

@export_group("Awareness")
## Training dummy: never engages the player, and goes back to standing still
## after a stagger.
@export var passive: bool = false
@export var detection_radius: float = 12.0
## Gives up and returns to idle beyond this distance.
@export var lose_interest_radius: float = 22.0
## Length of the "spotted you" beat before engaging.
@export var aware_time: float = 0.6

@export_group("Patrol")
## Shambling speed while wandering its patrol area (Enemy.patrol_area).
@export var patrol_speed: float = 0.65
## Pause at each patrol point (s).
@export var patrol_pause_min: float = 0.2
@export var patrol_pause_max: float = 1.2

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

@export_group("Escalation")
## Attacks finished in a row without the player landing a hit. The last one
## costs the enemy its balance (BalanceLoss state).
@export_range(1, 10) var escalation_chain_length: int = 4
## Extra playback speed per attack already in the chain (0.25 = +25% each).
## Also shortens the telegraph, recovery and wait between attacks.
@export var escalation_speed_step: float = 0.25
## First attack in the chain (1-based) whose swing gets random arm jitter.
@export_range(1, 10) var jitter_start_attack: int = 2
## Arm jitter on that attack (degrees); grows by this much per attack after it.
@export var jitter_degrees_per_attack: float = 7.0
## The chain is dropped if the enemy goes this long without finishing an attack.
@export var escalation_chain_timeout: float = 6.0
## How many attacks at the top of the chain hit harder.
@export_range(0, 10) var top_attack_count: int = 1
## Knockback and player hit-stun multipliers for those top attacks (applied on
## top of the attack's own knockback / hit_stun_multiplier).
@export var top_attack_knockback_multiplier: float = 1.8
@export var top_attack_hit_stun_multiplier: float = 2.0
## Stumble after the last attack in the chain: can't attack or move, and is open
## to punishment like a stagger (hits don't cut it short).
@export var balance_loss_time: float = 1.5
