class_name EnemyModel
extends Node3D
## What Enemy and its states call on the model at $Facing/Model. MincerModel and
## SuitModel implement it; the clip names the shared states ask for are
## MincerModel's CLIP_* constants, which other models map to their own clips.


## Plays clip at speed. Keeps an already-playing clip going unless restart is set.
func play(_clip: StringName, _speed: float = 1.0, _restart: bool = false) -> void:
	pass


## Walk cycle with its playback speed matched to ground_speed (m/s).
func walk(_ground_speed: float) -> void:
	pass


## Whether a non-looping clip is still running.
func is_playing_one_shot() -> bool:
	return false


func freeze() -> void:
	pass


## Random arm shake layered on the animated pose, in degrees (0 = off).
func set_jitter(_degrees: float) -> void:
	pass


func set_flash(_color: Color) -> void:
	pass


## Multiplies the skin colour (the PS1 shader's per-instance tint).
func set_tint(_color: Color) -> void:
	pass


func set_pulse(_amount: float) -> void:
	pass
