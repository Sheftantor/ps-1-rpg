# Draws the melee weapon icons (res://textures/ui/icons/weapon_*.png):
#   godot --headless --path . -s res://scripts/tools/build_weapon_icons.gd
#
# 16x16 pixel art on a transparent background, scaled x4 with no smoothing like
# the other 64x64 item icons. Each weapon lies on the diagonal, grip bottom-left,
# tip top-right.
extends SceneTree

const DIR := "res://textures/ui/icons/"
const ART := 16
const SCALE := 4
const OUTLINE := Color8(20, 18, 22)
const STEEL := Color8(196, 202, 212)
const STEEL_DARK := Color8(120, 126, 138)


func _initialize() -> void:
	# Switchblade: short red grip, slim blade.
	var knife := _blank()
	_bar(knife, Vector2i(2, 13), Vector2i(6, 9), Color8(150, 26, 30), 2)
	_bar(knife, Vector2i(7, 8), Vector2i(7, 8), STEEL_DARK, 2)
	_bar(knife, Vector2i(8, 7), Vector2i(12, 3), STEEL, 1)
	_save(knife, "weapon_switchblade.png")

	# Machete: wooden grip, long wide blade.
	var machete := _blank()
	_bar(machete, Vector2i(1, 14), Vector2i(4, 11), Color8(92, 56, 32), 2)
	_bar(machete, Vector2i(5, 10), Vector2i(5, 10), STEEL_DARK, 3)
	_bar(machete, Vector2i(6, 9), Vector2i(13, 2), STEEL, 3)
	_bar(machete, Vector2i(7, 10), Vector2i(14, 3), STEEL_DARK, 1)
	_save(machete, "weapon_machete.png")

	# Selfie stick: black grip, chrome pole, pink phone with a glowing screen.
	var stick := _blank()
	_bar(stick, Vector2i(1, 14), Vector2i(3, 12), Color8(30, 30, 34), 2)
	_bar(stick, Vector2i(4, 11), Vector2i(9, 6), STEEL, 1)
	for y in range(1, 8):
		for x in range(9, 15):
			stick.set_pixel(x, y, OUTLINE if x == 9 or x == 14 or y == 1 or y == 7 else Color8(216, 64, 158))
	for y in range(2, 7):
		for x in range(10, 14):
			stick.set_pixel(x, y, Color8(90, 220, 255))
	_save(stick, "weapon_selfie_stick.png")
	quit()


static func _blank() -> Image:
	var image := Image.create_empty(ART, ART, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


## A diagonal bar from a to b (inclusive) `width` pixels thick, outlined.
static func _bar(image: Image, a: Vector2i, b: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	var points: Array[Vector2i] = []
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1)
		var p := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		for k in width:
			points.append(p + Vector2i(k, k) / 2 + Vector2i(k % 2, 0))
	for p in points:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := p + d
			if q.x >= 0 and q.y >= 0 and q.x < ART and q.y < ART and image.get_pixelv(q).a == 0.0:
				image.set_pixelv(q, OUTLINE)
	for p in points:
		if p.x >= 0 and p.y >= 0 and p.x < ART and p.y < ART:
			image.set_pixelv(p, color)


static func _save(image: Image, file: String) -> void:
	image.resize(ART * SCALE, ART * SCALE, Image.INTERPOLATE_NEAREST)
	var err := image.save_png(DIR + file)
	print("saved %s (error %d)" % [DIR + file, err])
