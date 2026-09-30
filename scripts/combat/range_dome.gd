class_name RangeDome
extends MeshInstance3D
## Gun mode's effective-range indicator: a dashed, triangulated wireframe dome
## around the player's feet with radius = the gun's effective range, so a target
## standing inside it takes full damage. Purely visual (no collision). Colors,
## density and dash length are exports for styling.

@export var line_color: Color = Color(0.85, 0.9, 1.0, 0.55)
@export var ground_color: Color = Color(0.35, 0.45, 1.0, 0.7)
## Points around each ring of the dome.
@export_range(4, 32) var ring_points: int = 8
## Elevation (degrees) of each ring above the ground ring; the apex closes it.
@export var ring_elevations: PackedFloat32Array = [0.0, 32.0, 62.0]
## Each edge is split into this many pieces and every other one is drawn.
@export_range(1, 16) var dashes_per_edge: int = 2
## Width of each dash strip (m). Wider than a pixel block of the PS1 post effect,
## so the lines survive the pixelation instead of breaking into specks.
@export var line_width: float = 0.05
## Lines closer to the camera than camera_fade_start are invisible, fading in
## fully by camera_fade_end (m).
@export var camera_fade_start: float = 2.0
@export var camera_fade_end: float = 5.0

var _radius: float = -1.0


func _ready() -> void:
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The follow camera sits inside the dome; fade the lines right around it so
	# they don't scatter across the screen.
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = camera_fade_start
	material.distance_fade_max_distance = camera_fade_end
	material_override = material


func show_range(radius: float) -> void:
	if not is_equal_approx(radius, _radius):
		_radius = radius
		mesh = _build(radius)
	visible = true


func hide_range() -> void:
	visible = false


func _build(radius: float) -> ArrayMesh:
	# Rings are offset by half a step each level so the bands triangulate.
	var rings: Array[PackedVector3Array] = []
	for level in ring_elevations.size():
		var elevation := deg_to_rad(ring_elevations[level])
		var ring := PackedVector3Array()
		for i in ring_points:
			var angle := TAU * (i + 0.5 * level) / ring_points
			ring.append(Vector3(cos(angle) * cos(elevation), sin(elevation), sin(angle) * cos(elevation)) * radius)
		rings.append(ring)
	var apex := Vector3.UP * radius

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in rings.size():
		var ring := rings[level]
		var color := ground_color if level == 0 else line_color
		for i in ring_points:
			_dashed(tool, ring[i], ring[(i + 1) % ring_points], color)
			if level + 1 < rings.size():
				var above := rings[level + 1]
				_dashed(tool, ring[i], above[i], line_color)
				_dashed(tool, ring[i], above[(i - 1 + ring_points) % ring_points], line_color)
			else:
				_dashed(tool, ring[i], apex, line_color)
	return tool.commit()


## Adds the edge a-b as dashes following the dome's curve (points pushed out to
## the sphere). Each dash is a thin strip lying in the dome's surface, so it faces
## a camera inside the dome.
func _dashed(tool: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	var pieces := dashes_per_edge * 2 - 1
	for piece in range(0, pieces, 2):
		var p0 := _on_dome(a.lerp(b, float(piece) / pieces))
		var p1 := _on_dome(a.lerp(b, float(piece + 1) / pieces))
		var normal := (p0 + p1).normalized()
		var side := normal.cross((p1 - p0).normalized()) * line_width * 0.5
		for point in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
			tool.set_color(color)
			tool.add_vertex(point)


func _on_dome(point: Vector3) -> Vector3:
	return point.normalized() * _radius if point.length() > 0.001 else point
