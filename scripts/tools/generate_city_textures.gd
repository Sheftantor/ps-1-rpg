# Generates the city kit's low-res, PS1-style tiling textures into res://textures/city/.
# Re-run after tweaking colors or patterns:
#   godot --headless --path . -s res://scripts/tools/generate_city_textures.gd
# Scale is 16 px per meter. Facades are one floor bay (4m x 3m = 64x48 px); window
# glass has alpha 0, which ps1.gdshaderinc uses as the mask for lit windows.
extends SceneTree

const OUTPUT_DIR := "res://textures/city/"

const MORTAR := Color(0.42, 0.4, 0.37)
const GLASS := Color(0.1, 0.12, 0.15)
const STONE_TRIM := Color(0.5, 0.47, 0.41)

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_save(_brownstone_facade(), "facade_brownstone")
	_save(_red_brick_facade(), "facade_red_brick")
	_save(_office_facade(), "facade_office")
	_save(_glass_facade(), "facade_glass")
	_save(_brick_wall(), "brick_wall")
	_save(_asphalt(true), "asphalt_lane")
	_save(_asphalt(false), "asphalt_plain")
	_save(_sidewalk(), "sidewalk")
	_save(_roof_tar(), "roof_tar")
	_save(_stone_trim(), "stone_trim")
	_save(_wood_planks(), "wood_planks")
	quit()


func _save(image: Image, file_name: String) -> void:
	var path := OUTPUT_DIR + file_name + ".png"
	image.save_png(path)
	print("Wrote ", path)


# --- Facades ---------------------------------------------------------------

func _brownstone_facade() -> Image:
	_rng.seed = 101
	var image := _blank(64, 48)
	# Brown sandstone blocks: large, low-contrast ashlar courses.
	_fill_blocks(image, Color(0.34, 0.24, 0.19), Color(0.27, 0.19, 0.15), 16, 6, 0.04)
	for x in [10, 42]:
		_window(image, x, 12, 12, 24, Color(0.22, 0.16, 0.13), true)
	# Horizontal band course at the floor line.
	_rect(image, 0, 46, 64, 2, Color(0.4, 0.3, 0.24), 0.02)
	return image


func _red_brick_facade() -> Image:
	_rng.seed = 202
	var image := _blank(64, 48)
	_fill_blocks(image, Color(0.4, 0.19, 0.15), MORTAR, 8, 3, 0.06)
	for x in [10, 42]:
		_window(image, x, 12, 12, 22, Color(0.3, 0.29, 0.27), true)
	return image


func _office_facade() -> Image:
	_rng.seed = 303
	var image := _blank(64, 48)
	_rect(image, 0, 0, 64, 48, Color(0.45, 0.45, 0.44), 0.03)
	# Four narrow windows per bay between limestone piers.
	for i in 4:
		_window(image, 2 + i * 16, 10, 12, 26, Color(0.28, 0.29, 0.3), false)
	# Spandrel band and a few grime streaks running down from the sills.
	_rect(image, 0, 42, 64, 3, Color(0.38, 0.38, 0.38), 0.02)
	for i in 6:
		var x := _rng.randi_range(0, 63)
		_rect(image, x, 36, 1, _rng.randi_range(3, 8), Color(0.36, 0.36, 0.35), 0.02)
	return image


func _glass_facade() -> Image:
	_rng.seed = 404
	var image := _blank(64, 48)
	var mullion := Color(0.24, 0.26, 0.29)
	for y in 48:
		for x in 64:
			var tint := GLASS.lightened(0.08 * float(y) / 48.0)
			image.set_pixel(x, y, Color(tint, 0.0))
	# Curtain wall: 8 panes per bay, dark floor-slab spandrel at the bottom.
	for x in range(0, 64, 8):
		_rect(image, x, 0, 1, 48, mullion, 0.01)
	_rect(image, 0, 38, 64, 10, Color(0.17, 0.19, 0.22), 0.02)
	_rect(image, 0, 38, 64, 1, mullion, 0.0)
	return image


func _brick_wall() -> Image:
	_rng.seed = 505
	var image := _blank(64, 48)
	_fill_blocks(image, Color(0.33, 0.2, 0.16), MORTAR.darkened(0.1), 8, 3, 0.07)
	return image


# --- Ground ----------------------------------------------------------------

func _asphalt(lane_markings: bool) -> Image:
	_rng.seed = 606
	var image := _blank(64, 64)
	_rect(image, 0, 0, 64, 64, Color(0.17, 0.17, 0.18), 0.025)
	# Lighter aggregate specks and darker tar-sealed cracks.
	for i in 90:
		image.set_pixel(_rng.randi_range(0, 63), _rng.randi_range(0, 63), Color(0.24, 0.24, 0.24))
	for i in 3:
		_crack(image, Color(0.1, 0.1, 0.11), 18)
	if lane_markings:
		# Gutters along both curb edges (intersections have no curbs).
		_rect(image, 0, 0, 2, 64, Color(0.14, 0.14, 0.15), 0.01)
		_rect(image, 62, 0, 2, 64, Color(0.14, 0.14, 0.15), 0.01)
		# Faded dashed center line (along the tile's Z axis), worn away in patches.
		for y in range(8, 24) + range(40, 56):
			for x in [31, 32]:
				if _rng.randf() < 0.75:
					image.set_pixel(x, y, Color(0.5, 0.48, 0.4))
	return image


func _sidewalk() -> Image:
	_rng.seed = 707
	var image := _blank(64, 64)
	_rect(image, 0, 0, 64, 64, Color(0.5, 0.48, 0.44), 0.03)
	# 2m slabs with darker joints.
	var joint := Color(0.36, 0.35, 0.32)
	for i in [0, 32]:
		_rect(image, i, 0, 1, 64, joint, 0.01)
		_rect(image, 0, i, 64, 1, joint, 0.01)
	for i in 4:
		_crack(image, Color(0.33, 0.32, 0.3), 14)
	# Stains and old gum spots.
	for i in 5:
		var cx := _rng.randi_range(0, 63)
		var cy := _rng.randi_range(0, 63)
		for j in 12:
			var p := Vector2i(cx + _rng.randi_range(-3, 3), cy + _rng.randi_range(-2, 2))
			_set_wrapped(image, p, Color(0.43, 0.41, 0.38))
	for i in 14:
		image.set_pixel(_rng.randi_range(0, 63), _rng.randi_range(0, 63), Color(0.3, 0.3, 0.29))
	return image


func _roof_tar() -> Image:
	_rng.seed = 808
	var image := _blank(32, 32)
	_rect(image, 0, 0, 32, 32, Color(0.2, 0.2, 0.21), 0.04)
	return image


func _stone_trim() -> Image:
	_rng.seed = 909
	var image := _blank(32, 32)
	_fill_blocks(image, STONE_TRIM, STONE_TRIM.darkened(0.2), 16, 8, 0.03)
	return image


func _wood_planks() -> Image:
	_rng.seed = 1010
	var image := _blank(32, 32)
	for x in 32:
		var plank := x / 4
		var base := Color(0.31, 0.24, 0.18).lerp(Color(0.33, 0.31, 0.28), _hash01(plank, 0) * 0.6)
		for y in 32:
			var c := base.darkened(0.35) if x % 4 == 3 else _jitter(base, 0.03)
			image.set_pixel(x, y, c)
	# Steel hoops around the tank.
	for y in [7, 23]:
		_rect(image, 0, y, 32, 1, Color(0.16, 0.15, 0.15), 0.01)
	return image


# --- Helpers ---------------------------------------------------------------

func _blank(width: int, height: int) -> Image:
	return Image.create(width, height, false, Image.FORMAT_RGBA8)


## Running-bond masonry. Tiles as long as the image size is a multiple of the block size.
func _fill_blocks(image: Image, block: Color, mortar: Color, block_w: int, course_h: int, noise: float) -> void:
	for y in image.get_height():
		var course := y / course_h
		var offset := (course % 2) * block_w / 2
		for x in image.get_width():
			var column := (x + offset) / block_w
			if y % course_h == course_h - 1 or (x + offset) % block_w == block_w - 1:
				image.set_pixel(x, y, _jitter(mortar, noise * 0.5))
			else:
				var tone := block.darkened(0.12 * _hash01(column, course)) if _hash01(course, column) > 0.2 else block.lightened(0.06)
				image.set_pixel(x, y, _jitter(tone, noise))


## Window with a frame, sash bar and optional stone lintel/sill. Glass pixels get alpha 0.
func _window(image: Image, x: int, y: int, w: int, h: int, frame: Color, stone_surround: bool) -> void:
	if stone_surround:
		_rect(image, x - 1, y - 2, w + 2, 2, STONE_TRIM, 0.02)
		_rect(image, x - 1, y + h, w + 2, 1, STONE_TRIM, 0.02)
	for py in range(y, y + h):
		for px in range(x, x + w):
			var edge := px == x or px == x + w - 1 or py == y or py == y + h - 1
			var sash := py == y + h / 2
			if edge or sash:
				image.set_pixel(px, py, _jitter(frame, 0.01))
			else:
				# Faint sky reflection toward the top of each pane.
				var glass := GLASS.lightened(0.1 if (py - y) % (h / 2) < 2 else 0.0)
				image.set_pixel(px, py, Color(glass, 0.0))


func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color, noise: float) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			image.set_pixel(posmod(px, image.get_width()), posmod(py, image.get_height()), _jitter(color, noise))


## Random-walk crack that wraps around the tile edges.
func _crack(image: Image, color: Color, length: int) -> void:
	var p := Vector2i(_rng.randi_range(0, image.get_width() - 1), _rng.randi_range(0, image.get_height() - 1))
	var dir := Vector2i(1 if _rng.randf() < 0.5 else -1, 1 if _rng.randf() < 0.5 else -1)
	for i in length:
		_set_wrapped(image, p, color)
		p += Vector2i(dir.x if _rng.randf() < 0.6 else 0, dir.y if _rng.randf() < 0.6 else 0)


func _jitter(color: Color, amount: float) -> Color:
	var n := _rng.randf_range(-amount, amount)
	return Color(color.r + n, color.g + n, color.b + n, color.a)


func _hash01(a: int, b: int) -> float:
	return float(hash(Vector2i(a, b)) % 1000) / 1000.0


func _set_wrapped(image: Image, p: Vector2i, color: Color) -> void:
	image.set_pixel(posmod(p.x, image.get_width()), posmod(p.y, image.get_height()), color)
