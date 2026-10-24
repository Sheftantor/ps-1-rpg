class_name HitSpark
extends Node3D
## Kingdom Hearts style melee impact, spawned by Feel.on_hit() where a player's
## hit lands: a white-gold flash that blooms and fades, glowing gold orbs
## bursting out and hanging in the air as they fade, small gold flecks
## drifting down after them, and on heavy hits
## (the finishers) a wide glowing ring blasting outward. All additive, unshaded,
## billboarded, with nearest-neighbour textures drawn here in code (no image
## files), so it reads as PS1 sprite effects. Frees itself when done. Every
## size, count, time and colour is in FeelSettings' Hit Sparks group.

const TEXTURE_SIZE := 32
## The ring is drawn big, so it gets a finer texture.
const RING_TEXTURE_SIZE := 64

static var _orb_texture: Texture2D
static var _glow_texture: Texture2D
static var _ring_texture: Texture2D

var _settings: FeelSettings
var _heavy: bool = false
var _origin: Vector3 = Vector3.ZERO


## Call before adding it to the tree. The effect builds itself in _ready() at
## the world position `at`, so its particles are emitted from there.
func setup(settings: FeelSettings, heavy: bool, at: Vector3) -> void:
	_settings = settings
	_heavy = heavy
	_origin = at


func _ready() -> void:
	global_position = _origin
	var s := _settings
	_flash(s.spark_flash_size_heavy if _heavy else s.spark_flash_size, s.spark_flash_color, s.spark_flash_time)
	_orbs(s.spark_orb_count_heavy if _heavy else s.spark_orb_count)
	_flecks(s.spark_fleck_count_heavy if _heavy else s.spark_fleck_count)
	if _heavy and s.spark_ring_size > 0.0:
		_ring()
	var life := maxf(maxf(s.spark_flash_time, s.spark_orb_time), maxf(s.spark_fleck_time, s.spark_ring_time))
	get_tree().create_timer(life + 0.1, false).timeout.connect(queue_free)


## The bright core: blooms to size and fades over seconds. Drawn over the
## characters (no depth test), like the flare in KH's hits.
func _flash(size: float, color: Color, seconds: float) -> void:
	var quad := _quad(_glow(), color, false)
	quad.scale = Vector3.ONE * size * 0.4
	var tween := quad.create_tween().set_parallel()
	tween.tween_property(quad, ^"scale", Vector3.ONE * size, seconds * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(quad, ^"transparency", 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# A second, smaller white-hot centre that's gone in half the time.
	var core := _quad(_glow(), Color(1, 1, 1), false)
	core.scale = Vector3.ONE * size * 0.45
	core.create_tween().tween_property(core, ^"transparency", 1.0, seconds * 0.5)


func _orbs(count: int) -> void:
	if count <= 0:
		return
	var s := _settings
	var size: float = s.spark_orb_size_heavy if _heavy else s.spark_orb_size
	var orbs := _particles(count, _orb(), s.spark_orb_color, s.spark_orb_time, size)
	orbs.initial_velocity_min = s.spark_orb_speed * 0.5
	orbs.initial_velocity_max = s.spark_orb_speed * (1.4 if _heavy else 1.0)
	# Burst out fast, then slow right down and hang there, drifting up a touch.
	orbs.damping_min = s.spark_orb_speed * 1.6
	orbs.damping_max = s.spark_orb_speed * 2.2
	orbs.gravity = Vector3(0, 0.6, 0)
	orbs.scale_amount_min = 0.6
	orbs.scale_amount_max = 1.0
	# Pop in full size, hold, then shrink away.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.7, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	orbs.scale_amount_curve = curve
	orbs.emitting = true


func _flecks(count: int) -> void:
	if count <= 0:
		return
	var s := _settings
	var flecks := _particles(count, _glow(), s.spark_fleck_color, s.spark_fleck_time, s.spark_fleck_size)
	flecks.explosiveness = 0.85
	flecks.initial_velocity_min = 1.0
	flecks.initial_velocity_max = s.spark_orb_speed * 1.2
	flecks.damping_min = 2.0
	flecks.damping_max = 4.0
	flecks.gravity = Vector3(0, -1.2, 0)
	flecks.lifetime_randomness = 0.5
	flecks.emitting = true


## Finisher blast: a glowing ring that grows to spark_ring_size and fades.
func _ring() -> void:
	var s := _settings
	var ring := _quad(_ring_shape(), s.spark_ring_color, true)
	ring.scale = Vector3.ONE * s.spark_ring_size * 0.15
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, ^"scale", Vector3.ONE * s.spark_ring_size, s.spark_ring_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, ^"transparency", 1.0, s.spark_ring_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# --- Building blocks ------------------------------------------------------------

func _quad(texture: Texture2D, color: Color, depth_test: bool) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.material = _material(texture, color, depth_test, BaseMaterial3D.BILLBOARD_ENABLED)
	quad.mesh = mesh
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	return quad


func _particles(count: int, texture: Texture2D, color: Color, lifetime: float, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	# Off until the caller has set it up; it emits by default, which would fire
	# the burst before its speeds are set.
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 180.0
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	mesh.material = _material(texture, Color.WHITE, true, BaseMaterial3D.BILLBOARD_PARTICLES)
	particles.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


func _material(texture: Texture2D, color: Color, depth_test: bool, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = billboard
	material.billboard_keep_scale = true
	material.albedo_texture = texture
	material.albedo_color = color
	material.vertex_color_use_as_albedo = billboard == BaseMaterial3D.BILLBOARD_PARTICLES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.no_depth_test = not depth_test
	material.render_priority = 10
	return material


# --- Textures (drawn once, shared) -----------------------------------------------

## A shiny orb: a solid ball, brighter toward a highlight up and to the left,
## with a soft glow around it.
static func _orb() -> Texture2D:
	if _orb_texture == null:
		var center := Vector2.ONE * TEXTURE_SIZE * 0.5
		var radius := TEXTURE_SIZE * 0.32
		var highlight := center + Vector2(-0.35, -0.35) * radius
		_orb_texture = _draw_rgba(func(pixel: Vector2) -> Color:
			var r := pixel.distance_to(center) / radius
			if r <= 1.0:
				var shine := clampf(1.0 - pixel.distance_to(highlight) / (radius * 1.1), 0.0, 1.0)
				# Bright rim where the ball meets its glow, like light on glass.
				var rim := clampf((r - 0.75) / 0.25, 0.0, 1.0) * 0.25
				var light := minf(0.8 + 0.2 * shine * shine + rim, 1.0)
				return Color(light, light, light, 1.0)
			var glow := pow(clampf(1.0 - (r - 1.0) / 0.55, 0.0, 1.0), 2.0) * 0.5
			return Color(1, 1, 1, glow))
	return _orb_texture


## A round glow, hot in the middle.
static func _glow() -> Texture2D:
	if _glow_texture == null:
		var center := Vector2.ONE * TEXTURE_SIZE * 0.5
		_glow_texture = _draw(func(pixel: Vector2) -> float:
			return pow(maxf(0.0, 1.0 - pixel.distance_to(center) / (TEXTURE_SIZE * 0.5)), 1.6))
	return _glow_texture


## A thin bright band near the edge.
static func _ring_shape() -> Texture2D:
	if _ring_texture == null:
		var center := Vector2.ONE * RING_TEXTURE_SIZE * 0.5
		_ring_texture = _draw(func(pixel: Vector2) -> float:
			var r := pixel.distance_to(center) / (RING_TEXTURE_SIZE * 0.5)
			return clampf(1.0 - absf(r - 0.85) / 0.1, 0.0, 1.0), RING_TEXTURE_SIZE)
	return _ring_texture


## White size x size texture whose alpha at each pixel centre is alpha_at(pixel).
static func _draw(alpha_at: Callable, size: int = TEXTURE_SIZE) -> Texture2D:
	return _draw_rgba(func(pixel: Vector2) -> Color: return Color(1, 1, 1, alpha_at.call(pixel)), size)


## size x size texture with color_at(pixel) at each pixel centre.
static func _draw_rgba(color_at: Callable, size: int = TEXTURE_SIZE) -> Texture2D:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			image.set_pixel(x, y, color_at.call(Vector2(x + 0.5, y + 0.5)))
	return ImageTexture.create_from_image(image)
