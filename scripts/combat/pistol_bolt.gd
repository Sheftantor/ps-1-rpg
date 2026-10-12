class_name PistolBolt
extends Node3D
## An enemy pistol round: a bright orange bolt flying in a straight line (no
## homing, no gravity). Each physics tick it raycasts from where it was to where
## it is going, so it can't tunnel through the player or walls at speed. A hit on
## the player goes through the player's Hurtbox like any other attack, so dodge
## i-frames, blocking, hit stun and damage numbers all apply. A dodged bolt
## flies on through.

@export var speed: float = 18.0
@export var damage: int = 10
## Seconds before an unspent bolt despawns.
@export var lifetime: float = 3.0
## Push on the player from a hit (m/s).
@export var knockback: float = 2.0
## What stops the bolt: layer 1 (world) and layer 4 (player hurtbox).
@export_flags_3d_physics var hit_mask: int = 1 | 8
@export var impact_scene: PackedScene = preload("res://scenes/impact_burst.tscn")
## Burst size on a wall, relative to the burst on the player.
@export var wall_impact_scale: float = 0.5
## The trail's full length (m). It grows out of the muzzle over this distance.
@export var trail_length: float = 0.9

var _direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _travelled: float = 0.0
var _attack: AttackData = null
var _exclude: Array[RID] = []

@onready var _trail: Node3D = $Trail


## Call after adding the bolt to the tree. source (the shooter) is never hit.
func launch(from: Vector3, direction: Vector3, source: CollisionObject3D = null) -> void:
	_direction = direction.normalized()
	global_position = from
	var up := Vector3.UP if absf(_direction.y) < 0.99 else Vector3.RIGHT
	look_at(from + _direction, up)
	_attack = AttackData.new()
	_attack.display_name = "Pistol Bolt"
	_attack.damage = damage
	_attack.knockback = knockback
	if source != null:
		_exclude.append(source.get_rid())
	_trail.scale = Vector3(1.0, 1.0, 0.001)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var from := global_position
	var to := from + _direction * speed * delta
	var space := get_world_3d().direct_space_state
	# A few tries: skip dodged hurtboxes and non-hurtbox areas on the same segment.
	for attempt in 4:
		var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask, _exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var hurtbox := hit.collider as Hurtbox
		if hurtbox != null:
			if hurtbox.receive_hit(_attack, self):
				_impact(hit.position, 1.0)
				return
			_exclude.append(hurtbox.get_rid())
		elif hit.collider is Area3D:
			_exclude.append((hit.collider as Area3D).get_rid())
		else:
			_impact(hit.position, wall_impact_scale)
			return
	global_position = to
	_travelled += speed * delta
	_trail.scale.z = clampf(_travelled / trail_length, 0.001, 1.0)


func _impact(at: Vector3, burst_scale: float) -> void:
	if impact_scene != null:
		var burst := impact_scene.instantiate() as ImpactBurst
		burst.burst_scale = burst_scale
		get_parent().add_child(burst)
		burst.global_position = at
	queue_free()
