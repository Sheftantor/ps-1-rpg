class_name CombatTuning
extends Resource
## Combat feel and difficulty in one place: the player's bat swing and how enemies
## scale with the level gap (enemy level - player level). Edit
## res://resources/combat_tuning.tres. Per-enemy bases (damage as a share of the
## player's health, health in bat hits) are in each EnemyStats resource.

@export_group("Bat Swing")
## The bat pulls back (s).
@export var swing_windup_time: float = 0.15
## The fast sweep across the front; the hitbox is live only now (s).
@export var swing_strike_time: float = 0.18
## Back to ready (s).
@export var swing_recovery_time: float = 0.30
## Width of the sweep in front of the player (degrees).
@export var swing_arc_degrees: float = 120.0
## Start the next swing within this long of the last one ending and it swings back
## the other way; any later and it starts from the right again (s).
@export var swing_combo_window: float = 0.5
## An attack press in this last part of recovery queues the next swing (s).
@export var swing_buffer_window: float = 0.15
## Forward step during the strike (m).
@export var swing_lunge_distance: float = 0.2
## Freeze when a swing connects (real seconds).
@export var hit_stop_time: float = 0.05
## How slow the game runs during the hit-stop.
@export_range(0.0, 1.0, 0.01) var hit_stop_time_scale: float = 0.05

@export_group("Level Gap: Enemy Health")
## Health multiplier per level the enemy is above the player.
@export var health_gain_per_level_above: float = 0.40
## Health multiplier lost per level the enemy is below the player.
@export var health_loss_per_level_below: float = 0.25
## Lowest health multiplier for much weaker enemies.
@export var health_multiplier_floor: float = 0.3

@export_group("Level Gap: Enemy Damage")
## Damage multiplier per level the enemy is above the player.
@export var damage_gain_per_level_above: float = 0.20
## Damage multiplier lost per level the enemy is below the player.
@export var damage_loss_per_level_below: float = 0.25
## Lowest damage multiplier for much weaker enemies.
@export var damage_multiplier_floor: float = 0.2
