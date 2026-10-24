class_name CombatTuning
extends Resource
## Combat feel and difficulty in one place: the player's melee swing and how enemies
## scale with the level gap (enemy level - player level). Edit
## res://resources/combat_tuning.tres. Per-enemy bases (damage as a share of the
## player's health, health in melee hits) are in each EnemyStats resource.

@export_group("Melee Swing")
## The melee weapon pulls back (s).
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

@export_group("Melee Finisher")
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
## The ground finisher launches what it staggers into the air (m/s up), ready
## for an air combo; 0 = just knocks it back.
@export var finisher_launch_speed: float = 6.0
## How long a launched enemy floats near the top (s).
@export var finisher_hang_time: float = 0.9

@export_group("Air Combo")
## Swinging in the air hangs the player there, Kingdom Hearts style: each swing
## gives this small hop (m/s up) ...
@export var air_swing_hop: float = 0.9
## ... and gravity is cut to this fraction for the swing.
@export var air_swing_gravity_scale: float = 0.2
## Locked on to a target above or below: how fast the air swing closes the
## height gap (per second of difference, capped at air_home_max_speed m/s).
@export var air_home_rate: float = 4.0
@export var air_home_max_speed: float = 4.0
## Air swings 1 and 2 pop the target up this much (m/s) so it stays in reach...
@export var air_hit_lift: float = 3.0
## ... and float it this long (s).
@export var air_hit_hang_time: float = 0.6
## Air hits push sideways less, so the target stays in front of you.
@export var air_knockback_scale: float = 0.35
## The air finisher slams the target down (m/s, negative = down).
@export var air_finisher_slam: float = -9.0

## Air swings 1 and 2: the body leans into the swing (degrees forward) and
## spins once around with the sweep; the air finisher somersaults forward into
## its slam. Visual only.
@export var air_swing_lean_degrees: float = 20.0
@export var air_swing_spin: bool = true

@export_group("Juggle")
## Launched enemies fall at this fraction of gravity while hanging.
@export var juggle_hang_gravity_scale: float = 0.15

@export_group("Enemy Knockdown")
## Finishers and launches send enemies flying back (KnockdownPose): in the air
## they lean back this far (degrees) at this speed (degrees/s) ...
@export var enemy_flyback_lean_degrees: float = 50.0
@export var enemy_flyback_lean_speed: float = 300.0
## ... spin round (degrees/s; 0 = no spin) ...
@export var enemy_flyback_spin_degrees: float = 360.0
## ... and flail their arms and legs (FlailLimbs): an upper arm's peak swing
## (degrees) and swings per second ...
@export var enemy_flail_degrees: float = 65.0
@export var enemy_flail_speed: float = 3.0
## ... all turning about this height (m, the hips) ...
@export var enemy_tumble_pivot_height: float = 1.0
## ... keep this fraction of their ground friction while airborne, so they
## sail back further ...
@export var enemy_air_friction_scale: float = 0.35
## ... then lie on their back this long (s) and take this long to get up (s).
@export var enemy_down_time: float = 0.6
@export var enemy_get_up_time: float = 0.35

@export_group("Player Knockdown")
## An enemy combo's final hit (AttackData.knockdown) throws the player back:
## up at this speed (m/s) ...
@export var player_knockdown_launch: float = 4.5
## ... and away at this speed (m/s), tipping over backwards (degrees/s) ...
@export var player_knockdown_speed: float = 6.0
@export var player_knockdown_tilt_degrees: float = 420.0
## ... to lie on the ground this long (s), then get up over this long (s).
## Hits can't land on the player until they're up.
@export var player_down_time: float = 0.55
@export var player_get_up_time: float = 0.35

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
