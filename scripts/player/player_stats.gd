class_name PlayerStats
extends Resource
## Tunable player numbers. Edit res://resources/player/player_stats.tres in the inspector.

@export var max_health: int = 100
@export var max_stamina: float = 100.0
## Unspent level-up points. Nothing spends them yet.
@export var stat_points: int = 0

@export_group("Attributes")
## Shown on the status screen. Not yet wired into combat, stealth or dialogue.
@export var strength: int = 10
@export var agility: int = 10
@export var stealth: int = 5
@export var memes: int = 5

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

@export_group("Dodge Roll")
@export var dodge_stamina_cost: float = 25.0
## How far one roll carries the player (m).
@export var roll_distance: float = 4.4
## Travel speed during the roll (m/s). The roll lasts roll_distance / roll_speed
## seconds (0.4s at the defaults) and the Roll animation is stretched to fit.
@export var roll_speed: float = 11.0
## I-frames are counted in frames of the 12-frame Roll animation, so they scale
## with the roll's duration (at 0.4s one frame is ~33ms). The player can't be hit
## from frame roll_iframe_start (0-based) for roll_iframe_frames frames; the rest
## of the roll is vulnerable. The clip's tumble spans frames 2-8.
@export_range(0, 12) var roll_iframe_start: int = 2
@export_range(0, 12) var roll_iframe_frames: int = 6

@export_group("Gun Mode")
## Real seconds for time to ease from normal speed down to gun_slow_time_scale
## after entering gun mode.
@export var gun_slowdown_time: float = 1.0
## How slow the world runs at the end of the slowdown (Engine.time_scale).
@export_range(0.0, 1.0) var gun_slow_time_scale: float = 0.05
## After the slowdown, pause the world entirely (only the player, camera and HUD
## keep running) so the shot can be planned. Off: stay at gun_slow_time_scale.
@export var gun_pause_after_slowdown: bool = true
## Real seconds of bullet time before stamina starts draining (queued shots
## still cost their weapon's shot_energy_cost). Long for testing; lower it later.
@export var gun_drain_delay: float = 10.0
## Stamina drained per real second after the delay. When it runs out, the shot
## queue executes on its own.
@export var gun_energy_drain: float = 20.0
## Mouse travel (pixels, sideways) that moves the gun-mode cursor to the next
## enemy on that side of the screen.
@export var gun_mouse_switch_distance: float = 60.0
## Most shots that can be queued in one bullet time.
@export_range(1, 8) var gun_max_queued_shots: int = 4
## Seconds between queued shots as they fire.
@export var gun_shot_interval: float = 0.3
## Real seconds holding the gun after the last shot before drawing the sword again.
@export var gun_fire_recovery: float = 0.35

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
## When the target is above the player, the lock-on camera tilts up (past
## lock_on_pitch_degrees) until the target is at least this far inside the top
## of the screen. It isn't centered, just kept in view.
@export var lock_on_view_margin_degrees: float = 12.0
