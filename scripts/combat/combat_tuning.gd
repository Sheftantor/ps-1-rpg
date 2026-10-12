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
## After a swing ends, attacking again within this long carries the combo on to
## the next swing; any later and it starts again from swing 1 (s).
@export var swing_combo_window: float = 1.0
## The end of a swing's recovery: holding the button here chains the next
## swing, and during the finisher only a press here queues a new combo (s).
@export var swing_buffer_window: float = 0.15
## Forward step during the strike (m).
@export var swing_lunge_distance: float = 0.2

## Keep swinging while the attack button is held (a press still works too).
@export var swing_hold_to_combo: bool = true

@export_group("Bat Finisher")
## The third swing of the combo: a strong, wide sweep with a heavier recovery.
## Its damage and knockback are stats.light_combo[2] (Light 3).
@export var finisher_windup_time: float = 0.24
@export var finisher_strike_time: float = 0.22
## Longer than a normal swing: the finisher commits you.
@export var finisher_recovery_time: float = 0.55
## Into the recovery before a dodge can cancel it (s).
@export var finisher_dodge_delay: float = 0.3
@export var finisher_arc_degrees: float = 240.0
@export var finisher_lunge_distance: float = 0.7
## The hitbox reaches this much further than a normal swing.
@export var finisher_reach_scale: float = 1.3
## The body turns with the sweep: wound back this far before it, carried
## through the other way after (degrees, total).
@export var finisher_body_twist_degrees: float = 70.0

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
