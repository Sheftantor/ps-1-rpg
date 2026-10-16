@tool
class_name InputIcon
extends Control
## Icon for whatever input is bound to `action` on the current device
## (InputBindings.chord_for), redrawn whenever a binding changes. Built from
## the 13x13 sprites in res://textures/ui/input_icons.png and pixel art drawn
## here in the sheet's palette, so every input has one:
##   keys in the sheet (E, Esc, Shift, Z, X, C, S) use their sprite; every other
##     key gets the sheet's keycap with the key name printed on it, stretched
##     sideways for long names (SPACE, CTRL, F12...),
##   mouse buttons get a mouse with the bound button lit (the wheel and an arrow
##     for wheel up/down); side buttons get a keycap (M4, M5),
##   gamepad face buttons use the PlayStation (or Xbox, see pad_style) sprite for
##     their position (bottom/right/left/top), the D-pad sprite is turned to the
##     bound direction, sticks show a round button with the cap pushed the bound
##     way plus L/R, and other pad inputs (L1, R2, START...) get a blank round
##     button stretched into a pill with the name on it,
##   a two-input combo shows both icons with a plus between them.
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
## Shorter printed names for keys whose own name would make a very long cap.
const KEY_NAMES := {
	KEY_BACKSPACE: "BKSP", KEY_CAPSLOCK: "CAPS", KEY_PAGEUP: "PGUP", KEY_PAGEDOWN: "PGDN",
	KEY_INSERT: "INS", KEY_DELETE: "DEL", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER",
	KEY_PRINT: "PRTSC", KEY_SCROLLLOCK: "SCRLK", KEY_NUMLOCK: "NUMLK", KEY_UP: "UP",
	KEY_DOWN: "DOWN", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_META: "WIN", KEY_MENU: "MENU",
	KEY_QUOTELEFT: "`", KEY_KP_0: "NUM0", KEY_KP_1: "NUM1", KEY_KP_2: "NUM2", KEY_KP_3: "NUM3",
	KEY_KP_4: "NUM4", KEY_KP_5: "NUM5", KEY_KP_6: "NUM6", KEY_KP_7: "NUM7", KEY_KP_8: "NUM8",
	KEY_KP_9: "NUM9", KEY_KP_ADD: "NUM+", KEY_KP_SUBTRACT: "NUM-", KEY_KP_MULTIPLY: "NUM*",
	KEY_KP_DIVIDE: "NUM/", KEY_KP_PERIOD: "NUM.",
}
## Drawn sprites: letters map to ART_PALETTE (the sheet's own colours).
const BLACK := Color8(0x00, 0x00, 0x00)
const TOP := Color8(0x9c, 0x9a, 0x94)
const EDGE := Color8(0x78, 0x77, 0x76)
const SHADOW := Color8(0x46, 0x43, 0x44)
const BOTTOM := Color8(0x35, 0x32, 0x36)
const WHITE := Color8(0xff, 0xff, 0xff)
const ART_PALETTE := {"o": BLACK, "h": TOP, "e": EDGE, "f": CAP_FACE, "s": SHADOW, "b": BOTTOM, "w": WHITE}
## Mouse body; L, R and M (the wheel) are coloured by _mouse().
const MOUSE_ART := [
	"....ooooo....",
	"...oLLoRRo...",
	"..oLLLoRRRo..",
	"..oLLLMRRRo..",
	"..oLLLMRRRo..",
	"..oLLLoRRRo..",
	"..ooooooooo..",
	"..ohhhhhhho..",
	"..offfffffo..",
	"..offfffffo..",
	"..osfffffso..",
	"...obbbbbo...",
	"....ooooo....",
]
const MOUSE_ART_BUTTONS := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE,
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
## Thumbstick: its well (with the centre marked) on a blank round button, and
## the cap drawn pushed toward the bound direction.
const STICK_WELL_ART := [
	"..bbb..",
	".b...b.",
	"b.....b",
	"b..s..b",
	"b.....b",
	".b...b.",
	"..bbb..",
]
const STICK_CAP_ART := [
	".w.",
	"www",
	".w.",
]
## Stick sprite width: the button plus room for L/R.
const STICK_WIDTH := 21
## Between the two inputs of a combo.
const PLUS_ART := [
	".......",
	".......",
	".......",
	"..ooo..",
	"..owo..",
	"ooowooo",
	"owwwwwo",
	"ooowooo",
	"..owo..",
	"..ooo..",
	".......",
	".......",
	".......",
]

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
## Keep `gamepad` on whichever device the player is using (ActiveDevice,
## the InputDevice autoload), switching as they change.
@export var follow_device: bool = false:
	set(value):
		follow_device = value
		if is_inside_tree():
			_sync_device()
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
var _time: float = 0.0
var _pressed: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art, false, INTERNAL_MODE_FRONT)
	refresh()


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		InputBindings.connect_changed(refresh)
		_sync_device()


func _exit_tree() -> void:
	InputBindings.disconnect_changed(refresh)
	ActiveDevice.disconnect_changed(_on_device_changed)


## Hooks follow_device up to ActiveDevice (or unhooks it). Not in the editor.
func _sync_device() -> void:
	if Engine.is_editor_hint():
		return
	if follow_device:
		ActiveDevice.connect_changed(_on_device_changed)
		gamepad = ActiveDevice.using_gamepad
	else:
		ActiveDevice.disconnect_changed(_on_device_changed)


func _on_device_changed(using_gamepad: bool) -> void:
	gamepad = using_gamepad


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
	for child in _art.get_children():
		_art.remove_child(child)
		child.queue_free()
	var chord := InputBindings.chord_for(action, gamepad)
	var parts: Array[Dictionary] = []
	if chord.is_empty():
		parts.append(_part(null))
	for i in chord.size():
		if i > 0:
			parts.append({"image": _from_art(PLUS_ART), "text": "", "face": Rect2i()})
		parts.append(_part(InputBindings.event_from_id(chord[i])))

	var x := 0
	var height := 0
	for part: Dictionary in parts:
		var image: Image = part["image"]
		var art_size := image.get_size() * pixel_scale
		var rect := TextureRect.new()
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture = ImageTexture.create_from_image(image)
		rect.position = Vector2(x, 0)
		rect.size = art_size
		_art.add_child(rect)
		if not (part["text"] as String).is_empty():
			_art.add_child(_printed(part["text"], part["face"], x))
		x += art_size.x + (pixel_scale if parts.size() > 1 else 0)
		height = maxi(height, art_size.y)
	var total := Vector2i(x - (pixel_scale if parts.size() > 1 else 0), height)
	_art.size = total
	# One extra sprite pixel of height so the press dip doesn't shift the layout.
	custom_minimum_size = total + Vector2i(0, pixel_scale)
	size = custom_minimum_size


## Sprite (and printed name, on `face`) for one input.
func _part(event: InputEvent) -> Dictionary:
	var image: Image
	var text := ""
	var is_round := false
	var face := Rect2i()
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
			text = PAD_NAMES[pad_style].get(button, InputBindings.event_label(event))
			is_round = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var triggers := {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"} if pad_style == PadStyle.PLAYSTATION \
				else {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
		if triggers.has(motion.axis):
			text = triggers[motion.axis]
			is_round = true
		else:
			return _stick(motion)
	elif event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if KEY_CELLS.has(code):
			image = _cell(KEY_CELLS[code])
		else:
			text = KEY_NAMES.get(code, InputBindings.event_label(event))
	elif event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		if MOUSE_ART_BUTTONS.has(button):
			return {"image": _mouse(button), "text": "", "face": Rect2i()}
		text = InputBindings.event_label(event).replace("MOUSE ", "M")
	else:
		text = "?"
	if image == null:
		var width := maxi(CELL, 6 + CHAR_WIDTH * text.length())
		image = _stretched(_blank_round() if is_round else _blank_key(), width)
		face = Rect2i(2, 3, width - 4, 5) if is_round else Rect2i(2, 2, width - 4, 7)
	return {"image": image, "text": text, "face": face}


## A label printing `text` centred on `face` (sprite pixels) of the part at x.
func _printed(text: String, face: Rect2i, x: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	var settings := label_settings.duplicate() as LabelSettings
	settings.font_size = TEXT_SIZE_PER_SCALE * pixel_scale
	settings.shadow_offset = Vector2.ONE * (pixel_scale / 2.0)
	label.label_settings = settings
	# A line box taller than the cap face, centred on it, so the text sits in the
	# middle of the key instead of overflowing from its top edge.
	var line_height := settings.font.get_height(settings.font_size)
	var face_center := (Vector2(face.position) + Vector2(face.size) * 0.5) * pixel_scale
	label.size = Vector2(face.size.x * pixel_scale, line_height)
	label.position = Vector2(x, 0) + face_center - label.size * 0.5 + Vector2(0, pixel_scale * 0.5)
	return label


## A mouse with the bound button lit (wheel up/down: the wheel and an arrow).
func _mouse(button: MouseButton) -> Image:
	var lit := {"L": button == MOUSE_BUTTON_LEFT, "R": button == MOUSE_BUTTON_RIGHT,
			"M": button in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]}
	var palette := ART_PALETTE.duplicate()
	for region: String in lit:
		palette[region] = WHITE if lit[region] else (BOTTOM if region == "M" else EDGE)
	var image := _from_art(MOUSE_ART, palette)
	var arrow: Array = []
	if button == MOUSE_BUTTON_WHEEL_UP:
		arrow = [Vector2i(6, 8), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9)]
	elif button == MOUSE_BUTTON_WHEEL_DOWN:
		arrow = [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8), Vector2i(6, 9)]
	for pixel: Vector2i in arrow:
		image.set_pixel(pixel.x, pixel.y, WHITE)
	return image


## A stick (round button with its cap pushed the bound way) and "L"/"R".
func _stick(motion: InputEventJoypadMotion) -> Dictionary:
	var left := motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	var image := _stretched(_blank_round(), STICK_WIDTH)
	var well := _from_art(STICK_WELL_ART)
	image.blend_rect(well, Rect2i(Vector2i.ZERO, well.get_size()), Vector2i(3, 2))
	var push := Vector2i.ZERO
	var direction := 2 if motion.axis_value >= 0.0 else -2
	if motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]:
		push.x = direction
	else:
		push.y = direction
	var cap := _from_art(STICK_CAP_ART)
	image.blend_rect(cap, Rect2i(Vector2i.ZERO, cap.get_size()), Vector2i(5, 4) + push)
	return {"image": image, "text": "L" if left else "R", "face": Rect2i(12, 3, STICK_WIDTH - 14, 5)}


## Builds a 13px-tall sprite from rows of palette letters ("." is clear).
static func _from_art(rows: Array, palette: Dictionary = ART_PALETTE) -> Image:
	var image := Image.create((rows[0] as String).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			image.set_pixel(x, y, palette.get(row[x], Color(0, 0, 0, 0)))
	return image


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
