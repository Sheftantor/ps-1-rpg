@tool
class_name CityBuilding
extends Node3D
## Procedural low-poly NYC-style building for the city kit. Builds one mesh (a
## textured block plus cornice, entrance, fire escapes and water tower) and a box
## collider from a few exported settings, and rebuilds live in the editor.
## Origin is the front-left corner at street level. The facade faces +Z and the
## footprint extends along +X (width) and -Z (depth) in 4m grid cells, so with
## a 4m editor snap it lines up with the city GridMap.

enum Style { BROWNSTONE, RED_BRICK, OFFICE, GLASS_TOWER }

const CELL := 4.0
const FLOOR_HEIGHT := 3.0
const MATERIAL_DIR := "res://resources/materials/city/"
const FACADE_MATERIALS := {
	Style.BROWNSTONE: "facade_brownstone",
	Style.RED_BRICK: "facade_red_brick",
	Style.OFFICE: "facade_office",
	Style.GLASS_TOWER: "facade_glass",
}
## Towers at least this tall get a narrower upper tier (NYC zoning setback).
const SETBACK_MIN_FLOORS := 12

@export var style: Style = Style.BROWNSTONE:
	set(value):
		style = value
		_queue_rebuild()
@export_range(1, 8) var width_cells: int = 2:
	set(value):
		width_cells = value
		_queue_rebuild()
@export_range(1, 8) var depth_cells: int = 3:
	set(value):
		depth_cells = value
		_queue_rebuild()
@export_range(1, 40) var floors: int = 4:
	set(value):
		floors = value
		_queue_rebuild()
## Multiplies the facade color so neighbors sharing a style still differ.
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		_queue_rebuild()
## Zigzag fire escape on the front facade (brick styles only).
@export var fire_escape: bool = false:
	set(value):
		fire_escape = value
		_queue_rebuild()
@export var water_tower: bool = false:
	set(value):
		water_tower = value
		_queue_rebuild()

static var _material_cache: Dictionary[String, Material] = {}

var _generated: Array[Node] = []
var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if is_inside_tree() and not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for node in _generated:
		node.queue_free()
	_generated.clear()

	var builder := MeshBuilder.new()
	var width := width_cells * CELL
	var depth := depth_cells * CELL
	var height := floors * FLOOR_HEIGHT
	var facade := _material(FACADE_MATERIALS[style])
	var roof := _material("roof_tar")
	var trim := _material("stone_trim")
	var is_brick := style == Style.BROWNSTONE or style == Style.RED_BRICK
	var colliders: Array[AABB] = []

	# Main block, optionally with a setback upper tier on tall buildings.
	var roof_height := height
	var roof_rect := Rect2(0, -depth, width, depth)
	var setback := not is_brick and floors >= SETBACK_MIN_FLOORS and width >= 12.0 and depth >= 12.0
	if setback:
		var base_height := ceilf(floors * 0.6) * FLOOR_HEIGHT
		colliders.append(_block(builder, facade, roof, Rect2(0, -depth, width, depth), 0.0, base_height))
		roof_rect = Rect2(2, -depth + 2, width - 4, depth - 4)
		colliders.append(_block(builder, facade, roof, roof_rect, base_height, height))
	else:
		colliders.append(_block(builder, facade, roof, roof_rect, 0.0, height))

	if is_brick:
		# Projecting cornice along the front roofline.
		var cornice := _material("metal_fire_escape") if style == Style.BROWNSTONE else trim
		builder.box(cornice, Vector3(width * 0.5, height + 0.1, -0.15), Vector3(width + 0.3, 0.5, 1.0), roof)
		_brick_entrance(builder, trim)
		if fire_escape and floors >= 3:
			_fire_escape(builder, width)
	else:
		# Parapet cap and a rooftop mechanical penthouse.
		var r := roof_rect
		builder.box(trim, Vector3(r.get_center().x, roof_height + 0.2, r.get_center().y), Vector3(r.size.x + 0.2, 0.4, r.size.y + 0.2), roof)
		roof_height += 0.4
		builder.box(trim, Vector3(r.get_center().x - r.size.x * 0.2, roof_height + 1.0, r.get_center().y + r.size.y * 0.15), Vector3(3.0, 2.0, 3.0), roof)
		_office_entrance(builder, width, trim)

	if water_tower:
		var spot := Vector3(roof_rect.position.x + roof_rect.size.x * 0.65, roof_height, roof_rect.position.y + roof_rect.size.y * 0.45)
		_water_tower(builder, spot)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = builder.commit()
	mesh_instance.set_instance_shader_parameter(&"tint", tint)
	_add_generated(mesh_instance)

	var body := StaticBody3D.new()
	for box in colliders:
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = box.size
		shape.position = box.get_center()
		body.add_child(shape)
	_add_generated(body)


func _add_generated(node: Node) -> void:
	# Internal, unowned children: rebuilt on load instead of saved into the scene.
	add_child(node, false, INTERNAL_MODE_BACK)
	_generated.append(node)


## Adds a facade block over a footprint rect (x, z) between two heights and returns its bounds.
func _block(builder: MeshBuilder, facade: Material, roof: Material, footprint: Rect2, bottom: float, top: float) -> AABB:
	var size := Vector3(footprint.size.x, top - bottom, footprint.size.y)
	var center := Vector3(footprint.get_center().x, (bottom + top) * 0.5, footprint.get_center().y)
	# Subdivide walls per 2m x one floor so street lights can light them per-vertex.
	builder.box(facade, center, size, roof, Basis.IDENTITY, Vector3(2.0, FLOOR_HEIGHT, 2.0))
	return AABB(center - size * 0.5, size)


## Raised stoop with a door in the middle of the first bay.
func _brick_entrance(builder: MeshBuilder, trim: Material) -> void:
	var door_x := CELL * 0.5
	var step_count := 3 if style == Style.BROWNSTONE else 1
	for i in step_count:
		var top := 0.15 * (step_count - i) + 0.15
		builder.box(trim, Vector3(door_x, top * 0.5, 0.2 + i * 0.35), Vector3(1.6, top, 0.4))
	var sill := 0.15 * step_count + 0.15
	builder.box(trim, Vector3(door_x, sill + 1.2, 0.02), Vector3(1.4, 2.5, 0.04))
	builder.box(_material("door_dark"), Vector3(door_x, sill + 1.15, 0.05), Vector3(1.1, 2.3, 0.04))


## Dark glass doors under a canopy, centered on the front.
func _office_entrance(builder: MeshBuilder, width: float, trim: Material) -> void:
	builder.box(_material("car_glass"), Vector3(width * 0.5, 1.3, 0.04), Vector3(2.4, 2.6, 0.08))
	builder.box(trim, Vector3(width * 0.5, 2.85, 0.6), Vector3(3.2, 0.15, 1.2))


## Classic zigzag fire escape: a railed landing at every upper floor, alternating
## stair flights between them, and a drop ladder under the lowest landing.
func _fire_escape(builder: MeshBuilder, width: float) -> void:
	var metal := _material("metal_fire_escape")
	var x0 := (CELL if width > CELL else 0.0) + 0.5
	var run := 3.0
	for level in range(1, floors):
		var y := level * FLOOR_HEIGHT
		builder.box(metal, Vector3(x0 + run * 0.5, y, 0.55), Vector3(run, 0.08, 1.0))
		# Railing: top rails on the three open sides plus posts.
		builder.box(metal, Vector3(x0 + run * 0.5, y + 1.0, 1.03), Vector3(run, 0.05, 0.05))
		builder.box(metal, Vector3(x0 + run * 0.5, y + 0.5, 1.03), Vector3(run, 0.04, 0.04))
		for x in [x0, x0 + run]:
			builder.box(metal, Vector3(x, y + 1.0, 0.55), Vector3(0.05, 0.05, 1.0))
		for x in [x0, x0 + run * 0.5, x0 + run]:
			builder.box(metal, Vector3(x, y + 0.5, 1.03), Vector3(0.05, 1.0, 0.05))
		# Stair flight up to the next landing, alternating direction each floor.
		if level < floors - 1:
			var from_x := x0 + 0.3 if level % 2 == 1 else x0 + run - 0.3
			var to_x := x0 + run - 0.3 if level % 2 == 1 else x0 + 0.3
			var delta := Vector2(to_x - from_x, FLOOR_HEIGHT)
			var flight := Basis(Vector3.BACK, delta.angle())
			builder.box(metal, Vector3((from_x + to_x) * 0.5, y + FLOOR_HEIGHT * 0.5, 0.35), Vector3(delta.length(), 0.06, 0.5), null, flight)
	# Drop ladder from the first landing.
	for x in [x0 + run - 0.5, x0 + run - 0.1]:
		builder.box(metal, Vector3(x, FLOOR_HEIGHT - 0.9, 0.9), Vector3(0.05, 1.8, 0.05))
	for i in 4:
		builder.box(metal, Vector3(x0 + run - 0.3, FLOOR_HEIGHT - 0.3 - i * 0.45, 0.9), Vector3(0.4, 0.04, 0.04))


## Wooden tank on steel legs with a conical roof.
func _water_tower(builder: MeshBuilder, base: Vector3) -> void:
	var metal := _material("metal_fire_escape")
	for offset in [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)]:
		builder.box(metal, base + Vector3(offset.x, 1.1, offset.y), Vector3(0.15, 2.2, 0.15))
	builder.box(metal, base + Vector3(0, 2.2, 0), Vector3(2.4, 0.12, 2.4))
	builder.prism(_material("wood_water_tower"), base + Vector3(0, 2.26, 0), 1.35, 1.35, 2.6, 8)
	builder.prism(metal, base + Vector3(0, 4.86, 0), 1.5, 0.08, 1.0, 8)


func _material(material_name: String) -> Material:
	if not _material_cache.has(material_name):
		_material_cache[material_name] = load(MATERIAL_DIR + material_name + ".tres")
	return _material_cache[material_name]


## Accumulates flat-shaded boxes and prisms into one surface per material.
class MeshBuilder:
	var _tools: Dictionary[Material, SurfaceTool] = {}

	## Axis-aligned (or basis-rotated) box. `top_material` overrides the +Y face.
	## `step` subdivides faces so no quad is larger than step along each axis.
	func box(material: Material, center: Vector3, size: Vector3, top_material: Material = null,
			basis := Basis.IDENTITY, step := Vector3.ZERO) -> void:
		var half := size * 0.5
		for axis in 3:
			for side in [-1.0, 1.0]:
				var normal := Vector3.ZERO
				normal[axis] = side
				var u_axis := (axis + 1) % 3
				var v_axis := (axis + 2) % 3
				var face_material := top_material if axis == 1 and side > 0.0 and top_material != null else material
				var u_count := maxi(1, ceili(size[u_axis] / step[u_axis])) if step[u_axis] > 0.0 else 1
				var v_count := maxi(1, ceili(size[v_axis] / step[v_axis])) if step[v_axis] > 0.0 else 1
				for i in u_count:
					for j in v_count:
						var corners: Array[Vector3] = []
						for k in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
							var p := normal * half
							p[u_axis] = lerpf(-half[u_axis], half[u_axis], float(k.x) / u_count)
							p[v_axis] = lerpf(-half[v_axis], half[v_axis], float(k.y) / v_count)
							corners.append(center + basis * p)
						_quad(face_material, corners, basis * normal)

	## Vertical n-sided prism (or frustum/cone when radii differ), flat shaded.
	func prism(material: Material, base: Vector3, bottom_radius: float, top_radius: float, height: float, sides: int) -> void:
		var top := base + Vector3.UP * height
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var b0 := base + Vector3(cos(a0), 0, sin(a0)) * bottom_radius
			var b1 := base + Vector3(cos(a1), 0, sin(a1)) * bottom_radius
			var t0 := top + Vector3(cos(a0), 0, sin(a0)) * top_radius
			var t1 := top + Vector3(cos(a1), 0, sin(a1)) * top_radius
			var outward := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
			var side_normal := (t0 - b0).cross(b1 - b0).normalized()
			if side_normal.dot(outward) < 0.0:
				side_normal = -side_normal
			_quad(material, [b0, b1, t1, t0], side_normal)
			_triangle(material, [top, t0, t1], Vector3.UP)
			_triangle(material, [base, b1, b0], Vector3.DOWN)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for material in _tools:
			_tools[material].commit(mesh)
		return mesh

	func _quad(material: Material, corners: Array, normal: Vector3) -> void:
		_triangle(material, [corners[0], corners[1], corners[2]], normal)
		_triangle(material, [corners[0], corners[2], corners[3]], normal)

	## Emits one triangle, flipping it if needed so it faces `normal`
	## (Godot treats clockwise winding as the front face).
	func _triangle(material: Material, points: Array, normal: Vector3) -> void:
		if not _tools.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			_tools[material] = tool
		var tool := _tools[material]
		var order := [0, 1, 2]
		if (points[2] - points[0]).cross(points[1] - points[0]).dot(normal) < 0.0:
			order = [0, 2, 1]
		for index in order:
			tool.set_normal(normal)
			tool.add_vertex(points[index])
