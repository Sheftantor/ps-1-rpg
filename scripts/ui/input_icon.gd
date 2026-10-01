@tool
class_name InputIcon
extends Control
## Icon for whatever input is bound to `action` on the current device
## (InputBindings.event_for), so it stays right if the binding changes. Built
## from the 13x13 sprites in res://textures/ui/input_icons.png:
##   keys in the sheet (E, Esc, Shift, Z, X, C, S) use their sprite; other keys
##     get the sheet's keycap with the key name printed on it, stretched sideways
##     for long names (SPACE, CTRL, LMB...),
##   gamepad face buttons use the PlayStation (or Xbox, see pad_style) sprite for
##     their position (bottom/right/left/top), the D-pad sprite is turned to the
##     bound direction, and other pad inputs (L1, R2, START...) get a blank round
##     button stretched into a pill with the name on it.
## Scaled up by pixel_scale with no filtering. With animate_press it dips one
## sprite pixel and darkens briefly every press_interval, like a key being hit.

enum PadStyle { PLAYSTATION, XBOX }

const SHEET: Texture2D = preload("res://textures/ui/input_icons.png")
const CELL := 13
## Sheet cells, left to right.
const PS_TRIANGLE := 0
const PS_CROSS := 1
const PS_SQUARE := 2
const PS_CIRCLE := 3
const DPAD := 4
const XB_A := 5
const XB_B := 6
const XB_X := 7
const XB_Y := 8
const KEY_CELLS := {KEY_Z: 9, KEY_X: 10, KEY_C: 11, KEY_S: 12, KEY_SHIFT: 13, KEY_ESCAPE: 14, KEY_E: 15}
const FACE_CELLS := {
	PadStyle.PLAYSTATION: {JOY_BUTTON_A: PS_CROSS, JOY_BUTTON_B: PS_CIRCLE, JOY_BUTTON_X: PS_SQUARE, JOY_BUTTON_Y: PS_TRIANGLE},
	PadStyle.XBOX: {JOY_BUTTON_A: XB_A, JOY_BUTTON_B: XB_B, JOY_BUTTON_X: XB_X, JOY_BUTTON_Y: XB_Y},
}
const PAD_NAMES := {
	PadStyle.PLAYSTATION: {
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_START: "START",
	},
	PadStyle.XBOX: {
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_START: "MENU",
	},
}
## Sheet colours used to blank out a sprite's symbol.
const CAP_FACE := Color8(0x59, 0x56, 0x52)
const ROUND_SYMBOL_COLORS := [Color8(0x9e, 0xde, 0x73), Color8(0x6a, 0xbe, 0x30), Color8(0x35, 0x32, 0x36)]
const KEY_LETTER_COLORS := [Color8(0xd5, 0xd5, 0xd5), Color8(0xff, 0xff, 0xff), Color8(0x35, 0x32, 0x36)]
## Native sprite pixels per character of a printed name, and the printed text's
## font size per pixel_scale (sized to match the sheet's own key letters).
const CHAR_WIDTH := 6
const TEXT_SIZE_PER_SCALE := 13

@export var action: StringName = &"interact":
	set(value):
		if action != value:
			action = value
			refresh()
## Show the gamepad binding instead of the keyboard/mouse one.
@export var gamepad: bool = false:
	set(value):
		if gamepad != value:
			gamepad = value
			refresh()
@export var pad_style: PadStyle = PadStyle.PLAYSTATION:
	set(value):
		pad_style = value
		refresh()
## Screen pixels per sprite pixel.
@export_range(1, 8) var pixel_scale: int = 3:
	set(value):
		pixel_scale = value
		refresh()
## Text printed on blank caps and pills.
@export var label_settings: LabelSettings = preload("res://resources/ui/key_text.tres"):
	set(value):
		label_settings = value
		refresh()

@export_group("Press Animation")
@export var animate_press: bool = true
## Seconds between presses.
@export var press_interval: float = 1.2
## Seconds the icon stays down.
@export var press_duration: float = 0.16
## Offsets this icon's press cycle (seconds), to stagger several icons.
@export var press_phase: float = 0.0

static var _sheet_image: Image

var _art: Control
var _texture_rect: TextureRect
var _label: Label
var _time: float = 0.0
var _pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art, false, INTERNAL_MODE_FRONT)
	_texture_rect = TextureRect.new()
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_texture_rect)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_label)
	refresh()


func _process(delta: float) -> void:
	if not animate_press or Engine.is_editor_hint():
		_set_pressed(false)
		return
	_time += delta
	_set_pressed(fmod(_time + press_phase, press_interval) < press_duration)


func _set_pressed(pressed: bool) -> void:
	if pressed == _pressed:
		return
	_pressed = pressed
	_art.position.y = pixel_scale if pressed else 0
	_art.modulate = Color(0.78, 0.78, 0.8) if pressed else Color.WHITE


func refresh() -> void:
	if not is_node_ready():
		return
	var event := InputBindings.event_for(action, gamepad)
	var image: Image
	var text := ""
	var is_round := false
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		if FACE_CELLS[pad_style].has(button):
			image = _cell(FACE_CELLS[pad_style][button])
		elif button >= JOY_BUTTON_DPAD_UP and button <= JOY_BUTTON_DPAD_RIGHT:
			image = _cell(DPAD)
			match button:
				JOY_BUTTON_DPAD_DOWN:
					image.rotate_180()
				JOY_BUTTON_DPAD_LEFT:
					image.rotate_90(COUNTERCLOCKWISE)
				JOY_BUTTON_DPAD_RIGHT:
					image.rotate_90(CLOCKWISE)
		else:
			text = PAD_NAMES[pad_style].get(button, "?")
			is_round = true
	elif event is InputEventJoypadMotion:
		var axis := (event as InputEventJoypadMotion).axis
		var triggers := {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"} if pad_style == PadStyle.PLAYSTATION \
				else {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
		text = triggers.get(axis, InputBindings.event_label(event))
		is_round = true
	elif event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if KEY_CELLS.has(code):
			image = _cell(KEY_CELLS[code])
		else:
			text = InputBindings.event_label(event)
	elif event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		text = "WHEEL" if button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] else InputBindings.event_label(event)
	else:
		text = "?"

	var face := Rect2i()
	if image == null:
		var width := maxi(CELL, 6 + CHAR_WIDTH * text.length())
		image = _stretched(_blank_round() if is_round else _blank_key(), width)
		face = Rect2i(2, 3, width - 4, 5) if is_round else Rect2i(2, 2, width - 4, 7)

	var art_size := image.get_size() * pixel_scale
	_texture_rect.texture = ImageTexture.create_from_image(image)
	_texture_rect.size = art_size
	_art.size = art_size
	# One extra sprite pixel of height so the press dip doesn't shift the layout.
	custom_minimum_size = art_size + Vector2i(0, pixel_scale)
	size = custom_minimum_size
	_label.visible = not text.is_empty()
	_label.text = text
	var settings := label_settings.duplicate() as LabelSettings
	settings.font_size = TEXT_SIZE_PER_SCALE * pixel_scale
	settings.shadow_offset = Vector2.ONE * (pixel_scale / 2.0)
	_label.label_settings = settings
	# A line box taller than the cap face, centred on it, so the text sits in the
	# middle of the key instead of overflowing from its top edge.
	var line_height := settings.font.get_height(settings.font_size)
	var face_center := (Vector2(face.position) + Vector2(face.size) * 0.5) * pixel_scale
	_label.size = Vector2(face.size.x * pixel_scale, line_height)
	_label.position = face_center - _label.size * 0.5 + Vector2(0, pixel_scale * 0.5)


## A copy of one 13x13 sheet cell.
func _cell(index: int) -> Image:
	if _sheet_image == null:
		_sheet_image = SHEET.get_image()
		_sheet_image.convert(Image.FORMAT_RGBA8)
	return _sheet_image.get_region(Rect2i(index * CELL, 0, CELL, CELL))


## The E keycap with its letter painted over in the face colour.
func _blank_key() -> Image:
	var image := _cell(KEY_CELLS[KEY_E])
	_paint_over(image, Rect2i(2, 2, 9, 7), KEY_LETTER_COLORS)
	return image


## The triangle button with its symbol painted over in the body colour.
func _blank_round() -> Image:
	var image := _cell(PS_TRIANGLE)
	_paint_over(image, Rect2i(2, 2, 9, 6), ROUND_SYMBOL_COLORS)
	return image


func _paint_over(image: Image, area: Rect2i, colors: Array) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := image.get_pixel(x, y)
			for target: Color in colors:
				if c.is_equal_approx(target):
					image.set_pixel(x, y, CAP_FACE)
					break


## Widens a 13px sprite to `width` by repeating its middle column (3-slice), so
## caps and pills keep their ends and height.
func _stretched(image: Image, width: int) -> Image:
	if width <= CELL:
		return image
	var out := Image.create(width, CELL, false, Image.FORMAT_RGBA8)
	var middle := CELL / 2
	var right_start := width - (CELL - middle - 1)
	for x in width:
		var source := x
		if x >= right_start:
			source = CELL - (width - x)
		elif x >= middle:
			source = middle
		for y in CELL:
			out.set_pixel(x, y, image.get_pixel(source, y))
	return out
