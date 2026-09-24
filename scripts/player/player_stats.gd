class_name PlayerStats
extends Resource
## Tunable player numbers. Edit res://resources/player/player_stats.tres in the inspector.

@export var max_health: int = 100
@export var max_stamina: float = 100.0
## Unspent level-up points. Nothing spends them yet.
@export var stat_points: int = 0

@export_group("Stamina")
## Per second, once regeneration resumes.
@export var stamina_regen: float = 35.0
## Pause after spending stamina before it starts refilling.
@export var stamina_regen_delay: float = 0.6

@export_group("Movement")
@export var move_speed: float = 6.0
@export var acceleration: float = 45.0
@export var deceleration: float = 55.0
@export var air_acceleration: float = 15.0
@export var jump_velocity: float = 5.5
## How quickly the character turns to face its movement direction.
@export var turn_speed: float = 14.0

@export_group("Dodge")
@export var dodge_stamina_cost: float = 25.0
@export var dodge_speed: float = 11.0
## The roll is timed in frames of its (future) animation, at this rate.
@export var dodge_frame_rate: float = 30.0
@export var dodge_frames: int = 12
## Invulnerable on frames dodge_iframe_first..dodge_iframe_last (0-based, inclusive).
## Frames outside that window can still be hit.
@export var dodge_iframe_first: int = 2
@export var dodge_iframe_last: int = 7

@export_group("Block")
@export var block_move_speed: float = 2.5
## Fraction of a blocked hit's damage that still gets through.
@export_range(0.0, 1.0) var block_damage_multiplier: float = 0.1
## Stamina spent per point of damage blocked. Too little stamina breaks the guard.
@export var block_stamina_per_damage: float = 1.5
## Multiplier on stamina regeneration while blocking.
@export_range(0.0, 1.0) var block_stamina_regen_scale: float = 0.4
## Multiplier on a blocked hit's knockback.
@export var block_knockback_scale: float = 0.4

@export_group("Combat")
## Each hit's cancel_window is when the next hit (or a dodge) can cut in.
@export var light_combo: Array[AttackData] = []
## Has no cancel window: commits through recovery.
@export var heavy_attack: AttackData
## Presses this long before an action is possible still count.
@export var input_buffer_time: float = 0.25
@export var hit_stun_time: float = 0.35
@export var guard_break_stun_time: float = 0.8
## Grace period after taking a hit so one attack can't hit twice in a row.
@export var post_hit_invulnerability: float = 0.6

@export_group("Lock-on")
@export var lock_on_range: float = 15.0
## The lock breaks once the target is farther than this.
@export var lock_on_break_range: float = 20.0
@export var lock_on_camera_speed: float = 8.0
@export var lock_on_pitch_degrees: float = -20.0
