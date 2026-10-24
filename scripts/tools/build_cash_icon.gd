# Draws the loot window's cash icon (res://textures/ui/icons/item_cash.png):
#   godot --headless --path . -s res://scripts/tools/build_cash_icon.gd
#
# Two green banknotes and a gold coin as 16x16 pixel art on a transparent
# background, scaled x4 with no smoothing like the other 64x64 item icons.
extends SceneTree

const OUT := "res://textures/ui/icons/item_cash.png"
const ART := 16
const SCALE := 4

const OUTLINE := Color8(22, 58, 30)
const BILL_BACK := Color8(58, 122, 64)
const BILL := Color8(122, 186, 104)
const BILL_TRIM := Color8(78, 146, 74)
const COIN_EDGE := Color8(120, 74, 12)
const COIN := Color8(236, 178, 46)
const COIN_SHINE := Color8(255, 236, 140)


func _initialize() -> void:
	var image := Image.create_empty(ART, ART, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Back note, up and to the right.
	_note(image, Rect2i(4, 2, 11, 7), BILL_BACK, BILL_BACK)
	# Front note: lighter, with a trim line and a dark oval in the middle.
	_note(image, Rect2i(1, 5, 11, 7), BILL, BILL_TRIM)
	for p: Vector2i in [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(6, 7), Vector2i(6, 9)]:
		image.set_pixelv(p, OUTLINE)
	# Coin over the front note's corner.
	var center := Vector2(11.5, 11.5)
	for y in ART:
		for x in ART:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d <= 3.6:
				image.set_pixel(x, y, COIN_EDGE if d > 2.7 else COIN)
	image.set_pixel(10, 10, COIN_SHINE)
	image.set_pixel(11, 10, COIN_SHINE)
	image.set_pixel(10, 11, COIN_SHINE)
	image.resize(ART * SCALE, ART * SCALE, Image.INTERPOLATE_NEAREST)
	var err := image.save_png(OUT)
	print("saved %s (error %d)" % [OUT, err])
	quit()


## A banknote: outlined rectangle filled with fill, a trim line one pixel inside.
static func _note(image: Image, rect: Rect2i, fill: Color, trim: Color) -> void:
	image.fill_rect(rect, OUTLINE)
	image.fill_rect(rect.grow(-1), trim)
	image.fill_rect(rect.grow(-2), fill)
