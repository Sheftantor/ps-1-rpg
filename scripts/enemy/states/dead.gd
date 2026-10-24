extends EnemyState
## Terminal state: stops taking hits and goes limp (Ragdoll), carried along by
## the killing blow. The body lies there for corpse_time, then dithers away
## (ps1_fade.gdshader) over fade_time and the enemy is freed.

const FADE_SHADER: Shader = preload("res://shaders/ps1_fade.gdshader")
const PS1_SHADER: Shader = preload("res://shaders/ps1.gdshader")

## Seconds the body lies there before it starts to fade.
@export var corpse_time: float = 10.0
@export var fade_time: float = 1.0
## Lift added to the killing blow's knockback (m/s), so the body leaves the ground.
@export var death_lift: float = 2.0

## Meshes the fade drives through the shader, and the rest (plain materials).
var _shaded: Array[GeometryInstance3D] = []
var _plain: Array[GeometryInstance3D] = []


func enter(msg: Dictionary) -> void:
	enemy.release_attack_token(0.0)
	enemy.hurtbox.invulnerable = true
	enemy.hurtbox.set_deferred(&"monitorable", false)
	enemy.set_deferred(&"collision_layer", 0)
	enemy.set_horizontal_velocity(msg.get("knockback", Vector3.ZERO))
	enemy.model.freeze()
	var shadow := enemy.get_node_or_null(^"BlobShadow") as Node3D
	if shadow != null:
		# It shows itself again every tick unless it stops updating.
		shadow.process_mode = Node.PROCESS_MODE_DISABLED
		shadow.visible = false
	Ragdoll.start(enemy.model, enemy.velocity + Vector3.UP * death_lift,
			enemy.get_node_or_null(^"CollisionShape3D") as CollisionShape3D)
	var tween := enemy.create_tween()
	tween.tween_interval(corpse_time)
	tween.tween_callback(_prepare_fade)
	tween.tween_method(_set_fade, 1.0, 0.0, fade_time)
	tween.tween_callback(enemy.queue_free)


func can_be_staggered() -> bool:
	return false


func drives_animation() -> bool:
	return true


func physics_update(delta: float) -> void:
	enemy.move_horizontal(Vector3.ZERO, enemy.stats.stagger_friction, delta)


## Puts the fade shader on the model's PS1 surfaces (a copy of each material,
## so living enemies sharing it are untouched).
func _prepare_fade() -> void:
	for node: Node in enemy.model.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		var faded := false
		if mesh is MeshInstance3D:
			faded = _swap_shader(mesh as MeshInstance3D)
		if faded:
			_shaded.append(mesh)
		else:
			_plain.append(mesh)


func _swap_shader(mesh: MeshInstance3D) -> bool:
	var swapped := false
	var surfaces := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
	for surface in surfaces:
		var material := mesh.get_active_material(surface) as ShaderMaterial
		if material == null or material.shader != PS1_SHADER:
			continue
		var copy := material.duplicate() as ShaderMaterial
		copy.shader = FADE_SHADER
		mesh.set_surface_override_material(surface, copy)
		swapped = true
	return swapped


func _set_fade(value: float) -> void:
	for mesh: GeometryInstance3D in _shaded:
		if is_instance_valid(mesh):
			mesh.set_instance_shader_parameter(&"fade", value)
	for mesh: GeometryInstance3D in _plain:
		if is_instance_valid(mesh):
			mesh.transparency = 1.0 - value
