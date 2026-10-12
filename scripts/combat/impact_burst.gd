class_name ImpactBurst
extends Node3D
## A short PS1-style impact: a few flat, unshaded shards fly out from the hit
## point and shrink away, then the node frees itself.

@export var shard_mesh: Mesh
@export var shard_count: int = 6
## Seconds the burst lasts.
@export var duration: float = 0.2
## How far the shards fly at burst_scale 1 (m).
@export var spread: float = 0.45
## Overall size; set before adding to the tree (walls use a smaller burst).
@export var burst_scale: float = 1.0


func _ready() -> void:
	for i in shard_count:
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		shard.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
		shard.scale = Vector3.ONE * burst_scale
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 1.0), randf_range(-1.0, 1.0)).normalized()
		var tween := shard.create_tween().set_parallel()
		tween.tween_property(shard, ^"position", direction * spread * burst_scale, duration) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(shard, ^"scale", Vector3.ONE * 0.01, duration).set_ease(Tween.EASE_IN)
	get_tree().create_timer(duration, false).timeout.connect(queue_free)
