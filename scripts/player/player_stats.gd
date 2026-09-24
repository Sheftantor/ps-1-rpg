class_name PlayerStats
extends Resource
## Tunable player numbers. Edit res://resources/player/player_stats.tres in the inspector.

@export var max_health: int = 100

@export_group("Movement")
@export var move_speed: float = 6.0
@export var acceleration: float = 45.0
@export var deceleration: float = 55.0
@export var air_acceleration: float = 15.0
@export var jump_velocity: float = 5.5
## How quickly the character turns to face its movement direction.
@export var turn_speed: float = 14.0

@export_group("Dash")
@export var dash_speed: float = 15.0
@export var dash_duration: float = 0.2
## Invulnerable for this long from the start of the dash.
@export var dash_iframe_time: float = 0.16
@export var dash_cooldown: float = 0.3

@export_group("Combat")
@export var light_combo: Array[AttackData] = []
@export var heavy_attack: AttackData
## Presses this long before an action is possible still count.
@export var input_buffer_time: float = 0.25
@export var hurt_stun_time: float = 0.3
## Grace period after taking a hit so one attack can't hit twice in a row.
@export var post_hit_invulnerability: float = 0.6

@export_group("Lock-on")
@export var lock_on_range: float = 15.0
## The lock breaks once the target is farther than this.
@export var lock_on_break_range: float = 20.0
@export var lock_on_camera_speed: float = 8.0
@export var lock_on_pitch_degrees: float = -20.0
