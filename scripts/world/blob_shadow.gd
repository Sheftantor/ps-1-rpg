class_name BlobShadow
extends MeshInstance3D
## PS1-style blob shadow: a soft dark disc kept on the ground under the parent
## character. Raycasts straight down against world geometry each physics tick,
## lies flat on whatever it hits, and shrinks and fades with height so jumps and
## ledges read clearly.

## Disc radius on the ground when the parent is standing (m).
@export var radius: float = 0.6
## Darkness at the centre when grounded (0-1).
@export_range(0.0, 1.0) var opacity: float = 0.8
## Height above the ground at which the shadow has fully faded (m).
@export var fade_height: float = 6.0
## Smallest size the disc shrinks to at fade_height, as a fraction of radius.
@export_range(0.0, 1.0) var min_scale: float = 0.45
## Physics layers the shadow lands on (1 = world).
@export_flags_3d_physics var ground_mask: int = 1

## Lift off the surface so the disc doesn't z-fight with it.
const SURFACE_OFFSET := 0.03
const SIDES := 10

static var _shared_mesh: Mesh

var _material: StandardMaterial3D


func _ready() -> void:
	# Follows the parent's position only, not its rotation.
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shared_mesh == null:
		_shared_mesh = _build_mesh()
	mesh = _shared_mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.disable_receive_shadows = true
	_material.disable_fog = true
	material_override = _material
	_update()


func _physics_process(_delta: float) -> void:
	_update()


func _update() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	var from := parent.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (fade_height + 0.3), ground_mask)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	var height := maxf(0.0, parent.global_position.y - hit.position.y)
	var t := clampf(height / fade_height, 0.0, 1.0)
	visible = t < 1.0
	var normal: Vector3 = hit.normal
	var basis := Basis(Quaternion(Vector3.UP, normal))
	var size := radius * lerpf(1.0, min_scale, t)
	global_transform = Transform3D(basis.scaled(Vector3(size, 1.0, size)), hit.position + normal * SURFACE_OFFSET)
	_material.albedo_color = Color(1, 1, 1, opacity * (1.0 - t))


## Flat unit disc: dark centre fading to a transparent rim via vertex colours,
## with few sides so it stays chunky.
static func _build_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Color(0, 0, 0, 1)
	var mid := Color(0, 0, 0, 0.9)
	var rim := Color(0, 0, 0, 0)
	for i in SIDES:
		var a0 := TAU * i / SIDES
		var a1 := TAU * (i + 1) / SIDES
		var in0 := Vector3(cos(a0), 0, sin(a0)) * 0.6
		var in1 := Vector3(cos(a1), 0, sin(a1)) * 0.6
		var out0 := in0 / 0.6
		var out1 := in1 / 0.6
		_tri(st, [Vector3.ZERO, in1, in0], [centre, mid, mid])
		_tri(st, [in0, in1, out1], [mid, mid, rim])
		_tri(st, [in0, out1, out0], [mid, rim, rim])
	return st.commit()


static func _tri(st: SurfaceTool, points: Array[Vector3], colors: Array[Color]) -> void:
	for i in 3:
		st.set_color(colors[i])
		st.add_vertex(points[i])
