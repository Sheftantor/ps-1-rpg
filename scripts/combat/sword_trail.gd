class_name SwordTrail
extends MeshInstance3D
## Purely visual swing streak. Child of a weapon: while `emitting`, it samples the
## blade's base and tip every frame and draws a glowing ribbon through the
## samples, each fading out over `lifetime`. No collision, and nothing to do with
## hit detection.

## Blade base and tip in the parent weapon's local space.
@export var blade_base: Vector3 = Vector3(0, 0.12, 0)
@export var blade_tip: Vector3 = Vector3(0, 0.47, 0)
## How long each sample of the streak stays visible.
@export var lifetime: float = 0.15
@export var color: Color = Color(1.0, 1.0, 0.95, 0.85)

var emitting: bool = false

## [base, tip, age] per sample, oldest first.
var _samples: Array[Array] = []
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	top_level = true  # Samples are world positions, so draw in world space.
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material_override = material


func _process(delta: float) -> void:
	for sample in _samples:
		sample[2] += delta
	while not _samples.is_empty() and _samples[0][2] >= lifetime:
		_samples.pop_front()
	if emitting:
		var weapon := get_parent() as Node3D
		_samples.append([weapon.global_transform * blade_base, weapon.global_transform * blade_tip, 0.0])

	_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for sample in _samples:
		var fade: float = 1.0 - sample[2] / lifetime
		# Brightest along the tip edge, fading toward the hilt.
		_mesh.surface_set_color(Color(color, color.a * fade * 0.2))
		_mesh.surface_add_vertex(sample[0])
		_mesh.surface_set_color(Color(color, color.a * fade))
		_mesh.surface_add_vertex(sample[1])
	_mesh.surface_end()
