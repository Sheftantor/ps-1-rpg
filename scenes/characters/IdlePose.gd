class_name IdlePose
extends Resource
## The floating idle pose of FloatingFigure, as data. Every number lives here,
## none in code. Default: res://resources/idle_pose_default.tres, tuned live with
## the F8 panel (FloatingFigureTuner) in res://prototypes/floating_idle/.
##
## parts: part name (the model's node name, e.g. "Main Blue Right Arm") ->
##   pos_offset: Vector3  metres, added to the part's joint pivot rest position
##   rot_deg:    Vector3  degrees (Godot's YXZ euler), rotation about that pivot
##   drift:      float    0..1, how much of the underwater limb drift it gets
##                        (0 = locked, e.g. the prayer hands)
##   phase:      float    0..1 cycles, offsets its drift from the other parts
##   speed:      float    multiplies limb_drift_hz, so no two parts move in step
## The figure faces +Z; the character's right side is -X (screen-left in front view).

## Part name -> { pos_offset, rot_deg, drift, phase, speed }.
@export var parts: Dictionary = {}

@export_group("Whole figure")
## Up/down bob of the whole figure, metres.
@export_range(0.0, 0.2, 0.005) var bob_amplitude: float = 0.04
@export_range(0.0, 2.0, 0.01) var bob_hz: float = 0.4
## Slow left/right yaw sway of the whole figure, degrees.
@export_range(0.0, 20.0, 0.1) var yaw_sway_deg: float = 3.0
@export_range(0.0, 1.0, 0.01) var yaw_sway_hz: float = 0.1

@export_group("Limb drift")
## Each limb's own bob, metres (scaled by its drift).
@export_range(0.0, 0.05, 0.001) var limb_bob_amplitude: float = 0.015
## Each limb's own rotation sway, degrees (scaled by its drift).
@export_range(0.0, 10.0, 0.1) var limb_sway_deg: float = 2.0
@export_range(0.0, 2.0, 0.01) var limb_drift_hz: float = 0.25


func get_part(part_name: String) -> Dictionary:
	if not parts.has(part_name):
		parts[part_name] = { "pos_offset": Vector3.ZERO, "rot_deg": Vector3.ZERO, "drift": 1.0, "phase": 0.0, "speed": 1.0 }
	return parts[part_name]
