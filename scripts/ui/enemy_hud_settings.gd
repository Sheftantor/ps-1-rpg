class_name EnemyHudSettings
extends Resource
## When enemy health bars / level badges show. One shared file for every enemy
## (res://resources/ui/enemy_hud_settings.tres), used by EnemyHudVisibility in
## res://scenes/enemy_health_bar.tscn.

## Camera distance (m) up to which the HUD is fully visible.
@export var full_opacity_distance: float = 12.0
## Camera distance (m) at which it has faded out completely; beyond, it's
## hidden outright (its texture stops rendering).
@export var hide_distance: float = 20.0
## Opacity change per second toward the target (6 = a 0.17 s fade).
@export var fade_speed: float = 6.0
## Seconds after the enemy takes damage during which its HUD shows fully,
## whatever the distance (within reveal_max_distance).
@export var hit_reveal_time: float = 3.0
## The lock-on target and recently hit enemies show fully up to this distance (m).
@export var reveal_max_distance: float = 35.0
## Line-of-sight checks per second per enemy (camera to the HUD anchor).
@export var los_check_rate: float = 10.0
## Physics layers that block the view: world geometry only (layer 1).
@export_flags_3d_physics var los_mask: int = 1
