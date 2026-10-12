class_name FeelSettings
extends Resource
## Every combat-feedback value (hit stop, shake, hit reactions, damage numbers,
## kill feedback, sounds). One instance at res://settings/feel_settings.tres,
## loaded by the Feel autoload; tune it in the Inspector or live with F9.
## Feedback only: none of this changes damage, AI, stats or attack timings.

## Master switch for everything below.
@export var enabled: bool = true

@export_group("Hit Stop")
## Freezes the attacker's and target's animation and movement on a hit (not the
## rest of the world, and never Engine.time_scale).
@export var hit_stop_enabled: bool = true
## Freeze for a light hit (real seconds).
@export_range(0.0, 0.3, 0.005) var hit_stop_light: float = 0.05
## Freeze for a heavy hit (real seconds).
@export_range(0.0, 0.3, 0.005) var hit_stop_heavy: float = 0.09
## Also freeze on gun shots.
@export var hit_stop_on_gun: bool = false

@export_group("Camera Shake")
@export var shake_enabled: bool = true
## Trauma added by a light hit the player lands (0-1).
@export_range(0.0, 1.0, 0.01) var shake_light: float = 0.15
## Trauma added by a heavy hit the player lands (0-1).
@export_range(0.0, 1.0, 0.01) var shake_heavy: float = 0.35
## Getting hit shakes this much more than hitting.
@export_range(1.0, 3.0, 0.05) var shake_player_hurt_multiplier: float = 1.5
## Trauma lost per second.
@export_range(0.1, 10.0, 0.1) var shake_decay: float = 1.2
## Camera offset at full trauma (m).
@export_range(0.0, 1.0, 0.01) var shake_max_offset: float = 0.25
## Offset = max_offset * trauma ^ exponent. 1 = linear (light hits read clearly),
## 2 = classic trauma curve (small hits barely move, big ones kick).
@export_range(1.0, 3.0, 0.1) var shake_exponent: float = 1.0
## How fast the shake wobbles (noise samples per second).
@export_range(1.0, 60.0, 0.5) var shake_frequency: float = 22.0

@export_group("Enemy Hit Reaction")
@export var hit_reaction_enabled: bool = true
## White flash on a hit (s).
@export_range(0.0, 0.5, 0.01) var flash_time: float = 0.06
@export var flash_color: Color = Color(1, 1, 1, 0.85)
## Push away from the attacker, on top of the hit's own knockback (m, over knockback_time).
@export_range(0.0, 2.0, 0.01) var knockback_distance: float = 0.35
@export_range(0.01, 0.5, 0.01) var knockback_time: float = 0.12

@export_group("Damage Numbers")
@export var damage_numbers_enabled: bool = true
@export_range(0.0, 3.0, 0.05) var damage_number_rise: float = 0.8
@export_range(0.1, 3.0, 0.05) var damage_number_time: float = 0.7
## Random sideways scatter so numbers don't stack (m).
@export_range(0.0, 1.0, 0.01) var damage_number_spread: float = 0.3
@export_range(8, 128) var damage_number_font_size: int = 32
## On-screen size of a number (Label3D pixel_size; numbers keep this size at any
## distance, so far hits stay readable).
@export_range(0.0002, 0.005, 0.0001) var damage_number_pixel_size: float = 0.0025
@export var color_normal: Color = Color(1, 0.95, 0.7)
@export var color_heavy: Color = Color(1, 0.6, 0.15)
@export var color_player_hurt: Color = Color(1, 0.3, 0.25)

@export_group("Heavy Hits")
## With no heavy flag on attacks, a hit is heavy when it takes at least this
## share of the target's max health.
@export_range(0.0, 1.0, 0.01) var heavy_damage_threshold: float = 0.15

@export_group("Kill Feedback")
@export var kill_feedback_enabled: bool = true
@export_range(0, 64) var death_puff_count: int = 14
@export var death_puff_color: Color = Color(0.75, 0.72, 0.68)
@export_range(0.1, 2.0, 0.05) var death_puff_time: float = 0.5
## Stronger flash on the killing blow (s).
@export_range(0.0, 0.5, 0.01) var kill_flash_time: float = 0.15
@export var kill_flash_color: Color = Color(1, 1, 1, 1)
@export var color_xp: Color = Color(0.55, 0.85, 1.0)
## Quick brighten of the HUD's XP bar (s).
@export_range(0.0, 1.0, 0.01) var xp_bar_pulse_time: float = 0.35

@export_group("Sound")
@export var sound_enabled: bool = true
@export var snd_swing: AudioStream
@export_range(-40.0, 12.0, 0.5) var snd_swing_db: float = 0.0
@export var snd_hit_light: AudioStream
@export_range(-40.0, 12.0, 0.5) var snd_hit_light_db: float = 0.0
@export var snd_hit_heavy: AudioStream
@export_range(-40.0, 12.0, 0.5) var snd_hit_heavy_db: float = 0.0
@export var snd_kill: AudioStream
@export_range(-40.0, 12.0, 0.5) var snd_kill_db: float = 0.0
@export var snd_player_hurt: AudioStream
@export_range(-40.0, 12.0, 0.5) var snd_player_hurt_db: float = 0.0
## Random pitch change per sound, either way (0.08 = +-8%).
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.08
