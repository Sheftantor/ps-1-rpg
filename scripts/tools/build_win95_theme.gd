# Builds the Windows 95 Themes from their palettes:
#   godot --headless --path . -s res://scripts/tools/build_win95_theme.gd
#
#   res://resources/ui/win95/palette_dark.tres  -> win95_dark.tres  (project theme)
#   res://resources/ui/win95/palette_light.tres -> win95_light.tres
#
# Each also gets a small HUD overlay theme (win95_dark_hud.tres, ...) for text
# drawn over the 3D view: there every Label sits in a little tooltip-style box
# so it stays readable. Put it on HUD containers whose labels are made in code.
#
# Also writes the three font resources (font_title/body/mono.tres) the first
# time. Bevels, outlines and shadows are Win95StyleBox (custom draw, colors in
# the theme); the few icons (arrows, check boxes, slider grabber) are drawn here
# pixel by pixel at their final size and stored inside the theme. Rerunning
# overwrites the themes, so edits made to them in the editor are lost; change
# the palette instead (or edit the theme and stop using this tool).
extends SceneTree

const DIR := "res://resources/ui/win95/"
const PALETTES := {"palette_dark.tres": "win95_dark.tres", "palette_light.tres": "win95_light.tres"}
const HUD_SUFFIX := "_hud.tres"

const TITLE_TTF := "res://resources/ui/fonts/PixelifySans-Variable.ttf"
const BODY_TTF := "res://resources/ui/fonts/IBMPlexSans-Variable.ttf"
const MONO_TTF := "res://resources/ui/fonts/IBMPlexMono-Regular.ttf"

var p: Win95Palette

## Pixel art, one character per pixel (before scaling): X = ink.
const CLOSE_GLYPH := [
	"XX....XX",
	".XX..XX.",
	"..XXXX..",
	"...XX...",
	"..XXXX..",
	".XX..XX.",
	"XX....XX",
]
const MINIMIZE_GLYPH := [
	"........",
	"........",
	"........",
	"........",
	"........",
	".XXXXXX.",
	".XXXXXX.",
]
## The classic arrow: X = outline, . = fill, space = clear. Hotspot at its tip.
const CURSOR := [
	"X",
	"XX",
	"X.X",
	"X..X",
	"X...X",
	"X....X",
	"X.....X",
	"X......X",
	"X.......X",
	"X........X",
	"X.....XXXXX",
	"X..X..X",
	"X.X X..X",
	"XX  X..X",
	"X    X..X",
	"     X..X",
	"      X..X",
	"      X..X",
	"       XX",
]


func _initialize() -> void:
	var fonts := _fonts()
	for palette_file: String in PALETTES:
		p = load(DIR + palette_file)
		p.title_font = fonts.title
		p.body_font = fonts.body
		p.mono_font = fonts.mono
		ResourceSaver.save(p, DIR + palette_file)
		var theme := _theme()
		var err := ResourceSaver.save(theme, DIR + PALETTES[palette_file])
		print("saved %s (error %d)" % [DIR + PALETTES[palette_file], err])
		var cursor_path: String = DIR + "cursor_" + palette_file.trim_prefix("palette_").trim_suffix(".tres") + ".png"
		_cursor().save_png(ProjectSettings.globalize_path(cursor_path))
		print("saved %s" % cursor_path)
		var hud_path: String = DIR + PALETTES[palette_file].trim_suffix(".tres") + HUD_SUFFIX
		err = ResourceSaver.save(_hud_theme(), hud_path)
		print("saved %s (error %d)" % [hud_path, err])
	quit()


# --- Fonts -------------------------------------------------------------------------

func _fonts() -> Dictionary:
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	var specs := {
		title = [TITLE_TTF, 500, "font_title.tres"],
		body = [BODY_TTF, 400, "font_body.tres"],
		mono = [MONO_TTF, 0, "font_mono.tres"],
	}
	var out := {}
	for key: String in specs:
		var path: String = DIR + specs[key][2]
		var font := FontVariation.new()
		font.base_font = load(specs[key][0])
		if specs[key][1] > 0:
			font.variation_opentype = {wght: specs[key][1]}
		if key == "title":
			# Pixelify's "fi"/"fl" ligatures draw badly ("Confirm" read "ConArm").
			font.opentype_features = {ts.name_to_tag("liga"): 0}
		ResourceSaver.save(font, path)
		out[key] = load(path)
	return out


# --- Style boxes ----------------------------------------------------------------------

func _box(bevel: Win95StyleBox.Bevel, face: Color, margin_x := -1, margin_y := -1) -> Win95StyleBox:
	var box := Win95StyleBox.new()
	box.bevel = bevel
	box.bevel_width = p.px(p.bevel)
	box.face_color = face
	box.light_color = p.highlight
	box.dark_color = p.shadow
	box.outline_color = p.shadow
	box.shadow_color = p.shadow
	box.accent_color = p.accent
	var mx := p.px(p.bevel) if margin_x < 0 else margin_x
	var my := mx if margin_y < 0 else margin_y
	_margins(box, mx, my, mx, my)
	return box


static func _margins(box: StyleBox, left: float, top: float, right: float, bottom: float) -> void:
	box.content_margin_left = left
	box.content_margin_top = top
	box.content_margin_right = right
	box.content_margin_bottom = bottom


func _raised(face := Color(), margin_x := -1, margin_y := -1) -> Win95StyleBox:
	return _box(Win95StyleBox.Bevel.RAISED, p.face if face == Color() else face, margin_x, margin_y)


func _sunken(face := Color(), margin_x := -1, margin_y := -1) -> Win95StyleBox:
	return _box(Win95StyleBox.Bevel.SUNKEN, p.field if face == Color() else face, margin_x, margin_y)


## A 2 px accent outline with no face: keyboard focus. With dots_inset >= 0,
## also the classic dotted rectangle that far inside the edge.
func _focus(dots_inset := -1) -> Win95StyleBox:
	var box := _box(Win95StyleBox.Bevel.NONE, Color(0, 0, 0, 0), 0, 0)
	box.outline_color = p.accent
	box.outline_width = p.px(p.focus_outline)
	if dots_inset >= 0:
		box.dotted_color = p.text
		box.dotted_width = p.px(p.focus_dots)
		box.dotted_inset = dots_inset
	return box


## Selected row: a lifted face with the accent bar on the left.
func _selected(face: Color) -> Win95StyleBox:
	var box := _box(Win95StyleBox.Bevel.NONE, face, p.px(p.field_padding))
	box.accent_width = p.px(p.selection_bar)
	box.content_margin_left = p.px(p.selection_bar + p.field_padding)
	return box


func _flat(face: Color, margin := 0) -> Win95StyleBox:
	return _box(Win95StyleBox.Bevel.NONE, face, margin)


# --- Icons ---------------------------------------------------------------------------

func _image(w: int, h: int, fill := Color(0, 0, 0, 0)) -> Image:
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	return image


func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)


## Two-tone bevel baked into an image (for icons that are whole buttons).
func _bevel(image: Image, raised: bool) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var light := p.highlight if raised else p.shadow
	var dark := p.shadow if raised else p.highlight
	for i in p.px(p.bevel):
		var t := 0.0 if i < p.scale else 0.5
		var a := light.lerp(p.face, t)
		var b := dark.lerp(p.face, t)
		_rect(image, i, i, w - 2 * i, 1, a)
		_rect(image, i, i, 1, h - 2 * i, a)
		_rect(image, i, h - 1 - i, w - 2 * i, 1, b)
		_rect(image, w - 1 - i, i, 1, h - 2 * i, b)


## A solid pixel triangle pointing dir, `size` rows deep, centred on (cx, cy)
## in unscaled pixels.
func _arrow(image: Image, cx: int, cy: int, size: int, dir: Vector2i, color: Color) -> void:
	var u := p.scale
	for i in size:
		var along := size / 2 - i
		for k in range(-i, i + 1):
			var x := cx + along * dir.x + k * absi(dir.y)
			var y := cy + along * dir.y + k * absi(dir.x)
			_rect(image, x * u, y * u, u, u, color)


## A whole scrollbar end button: bevelled square with an arrow.
func _scroll_button(dir: Vector2i, pressed: bool, hover: bool) -> ImageTexture:
	var s := p.px(p.scrollbar_width)
	var face := p.face.lightened(p.hover_lighten) if hover else p.face
	var image := _image(s, s, face)
	_bevel(image, not pressed)
	var shift := 1 if pressed else 0
	_arrow(image, p.scrollbar_width / 2 - 1 + shift, p.scrollbar_width / 2 - 1 + shift, 4, dir, p.text)
	return ImageTexture.create_from_image(image)


func _glyph_arrow(dir: Vector2i, color: Color) -> ImageTexture:
	var image := _image(p.px(9), p.px(9))
	_arrow(image, 4, 4, 4, dir, color)
	return ImageTexture.create_from_image(image)


## Check box (or radio, drawn square since nothing here is round): sunken
## field, with a check mark or a dot.
func _check(checked: bool, radio: bool, disabled: bool) -> ImageTexture:
	var s := p.px(p.checkbox_size)
	var image := _image(s, s, p.face if disabled else p.field)
	var light := p.shadow
	var dark := p.highlight
	for i in p.px(p.bevel):
		var t := 0.0 if i < p.scale else 0.5
		_rect(image, i, i, s - 2 * i, 1, light.lerp(p.field, t))
		_rect(image, i, i, 1, s - 2 * i, light.lerp(p.field, t))
		_rect(image, i, s - 1 - i, s - 2 * i, 1, dark.lerp(p.field, t))
		_rect(image, s - 1 - i, i, 1, s - 2 * i, dark.lerp(p.field, t))
	if checked:
		var mark := p.muted if disabled else p.text
		var u := p.scale
		if radio:
			_rect(image, 5 * u, 5 * u, 3 * u, 3 * u, mark)
		else:
			# Classic 7x7 check mark, 3 px thick.
			var cells := [[3, 5], [4, 6], [5, 7], [6, 6], [7, 5], [8, 4], [9, 3]]
			for c: Array in cells:
				_rect(image, c[0] * u, c[1] * u, u, 3 * u, mark)
	return ImageTexture.create_from_image(image)


## Pixel art rows (see CLOSE_GLYPH) in color, scaled.
func _glyph(rows: Array, color: Color) -> ImageTexture:
	var u := p.scale
	var image := _image(rows[0].length() * u, rows.size() * u)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "X":
				_rect(image, x * u, y * u, u, u, color)
	return ImageTexture.create_from_image(image)


## The mouse cursor image, scaled like everything else.
func _cursor() -> Image:
	var u := p.scale
	var width := 0
	for row: String in CURSOR:
		width = maxi(width, row.length())
	var image := _image(width * u, CURSOR.size() * u)
	for y in CURSOR.size():
		var row: String = CURSOR[y]
		for x in row.length():
			match row[x]:
				"X":
					_rect(image, x * u, y * u, u, u, p.cursor_outline)
				".":
					_rect(image, x * u, y * u, u, u, p.cursor_fill)
	return image


func _slider_grabber(hover: bool) -> ImageTexture:
	var image := _image(p.px(10), p.px(20), p.face.lightened(p.hover_lighten) if hover else p.face)
	_bevel(image, true)
	return ImageTexture.create_from_image(image)


# --- Theme -----------------------------------------------------------------------------

func _theme() -> Theme:
	var t := Theme.new()
	var hover_face := p.face.lightened(p.hover_lighten)
	var row_face := p.face.lightened(p.hover_lighten)
	var bevel := p.px(p.bevel)
	var pad := p.px(p.field_padding)
	t.default_font = p.body_font
	t.default_font_size = p.px(p.body_font_size)

	# Palette values, for scripts that draw their own UI (HUD bars, badges).
	for color_name: String in ["desktop", "face", "field", "text", "muted", "highlight", "shadow",
			"title_left", "title_right", "title_text", "accent", "health_fill", "energy_fill",
			"xp_fill", "enemy_health_fill", "under_fill"]:
		t.set_color(color_name, &"Win95", p.get(color_name))
	for size_name: String in ["bevel", "drop_shadow", "focus_outline", "bar_outline", "title_height",
			"title_padding", "body_padding", "body_separation", "selection_bar", "scrollbar_width"]:
		t.set_constant(size_name, &"Win95", p.px(p.get(size_name)))

	# Text.
	t.set_color(&"font_color", &"Label", p.text)
	t.set_constant(&"outline_size", &"Label", 0)
	_variation(t, &"TitleLabel", &"Label")
	t.set_font(&"font", &"TitleLabel", p.title_font)
	t.set_font_size(&"font_size", &"TitleLabel", p.px(p.title_font_size))
	t.set_color(&"font_color", &"TitleLabel", p.title_text)
	_variation(t, &"HeadingLabel", &"Label")
	t.set_font(&"font", &"HeadingLabel", p.title_font)
	t.set_font_size(&"font_size", &"HeadingLabel", p.px(p.heading_font_size))
	_variation(t, &"HintLabel", &"Label")
	t.set_font_size(&"font_size", &"HintLabel", p.px(p.small_font_size))
	t.set_color(&"font_color", &"HintLabel", p.muted)
	_variation(t, &"MonoLabel", &"Label")
	t.set_font(&"font", &"MonoLabel", p.mono_font)
	_variation(t, &"TagLabel", &"Label")
	t.set_font_size(&"font_size", &"TagLabel", p.px(p.tag_font_size))
	var tag := _flat(p.face)
	tag.outline_width = p.scale
	_margins(tag, p.px(4), p.px(1), p.px(4), p.px(1))
	t.set_stylebox(&"normal", &"TagLabel", tag)
	# Section headings inside windows ("WEAPONS", "CONTROLS").
	_variation(t, &"SectionLabel", &"Label")
	t.set_font(&"font", &"SectionLabel", p.title_font)
	t.set_font_size(&"font_size", &"SectionLabel", p.px(p.title_font_size))
	# Dims the game behind a full-screen menu.
	_variation(t, &"ScreenDim", &"Panel")
	t.set_stylebox(&"panel", &"ScreenDim", _flat(Color(p.shadow, 0.65)))
	# Spend-a-point "+" buttons: a normal button with accent text.
	_variation(t, &"PointButton", &"Button")
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(key, &"PointButton", p.accent)
	_variation(t, &"SmallLabel", &"Label")
	t.set_font_size(&"font_size", &"SmallLabel", p.px(p.small_font_size))
	_variation(t, &"SlotCount", &"Label")
	t.set_font(&"font", &"SlotCount", p.mono_font)
	t.set_font_size(&"font_size", &"SlotCount", p.px(p.small_font_size))
	t.set_color(&"font_outline_color", &"SlotCount", p.shadow)
	t.set_constant(&"outline_size", &"SlotCount", p.px(2))
	# Big announcement (level up): heading text in a raised panel with a shadow.
	_variation(t, &"BannerLabel", &"Label")
	t.set_font(&"font", &"BannerLabel", p.title_font)
	t.set_font_size(&"font_size", &"BannerLabel", p.px(p.heading_font_size))
	var banner := _raised(Color(), p.px(p.bevel + p.body_padding), p.px(p.bevel + 6))
	banner.shadow_size = p.px(p.drop_shadow)
	t.set_stylebox(&"normal", &"BannerLabel", banner)
	# Text over the 3D view, in a small box (see _hud_theme for code-made labels).
	_variation(t, &"MessageLabel", &"Label")
	t.set_font(&"font", &"MessageLabel", p.title_font)
	t.set_font_size(&"font_size", &"MessageLabel", p.px(p.title_font_size))
	t.set_stylebox(&"normal", &"MessageLabel", _message_box())
	t.set_color(&"default_color", &"RichTextLabel", p.text)
	t.set_font(&"mono_font", &"RichTextLabel", p.mono_font)

	# Panels and windows.
	t.set_stylebox(&"panel", &"Panel", _raised())
	t.set_stylebox(&"panel", &"PanelContainer", _raised())
	_variation(t, &"WindowPanel", &"PanelContainer")
	var window := _raised()
	window.shadow_size = p.px(p.drop_shadow)
	t.set_stylebox(&"panel", &"WindowPanel", window)
	_variation(t, &"FieldPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"FieldPanel", _sunken(Color(), bevel + pad))
	# A sunken field that scrolls its content (fixed-height description boxes).
	_variation(t, &"FieldScroll", &"ScrollContainer")
	t.set_stylebox(&"panel", &"FieldScroll", _sunken(Color(), bevel + pad))
	t.set_stylebox(&"focus", &"FieldScroll", _sunken(Color(), bevel + pad))
	_variation(t, &"TitleBar", &"PanelContainer")
	var title_bar := _flat(p.title_left)
	title_bar.gradient_end_color = p.title_right
	_margins(title_bar, p.px(p.title_padding), 0, p.px(4), 0)
	t.set_stylebox(&"panel", &"TitleBar", title_bar)
	_variation(t, &"DesktopPanel", &"Panel")
	t.set_stylebox(&"panel", &"DesktopPanel", _flat(p.desktop))
	for key: String in ["title_height", "title_padding", "body_padding", "body_separation"]:
		t.set_constant(key, &"Win95Window", p.px(p.get(key)))
	t.set_constant(&"title_button_width", &"Win95Window", p.px(p.title_button_size.x))
	t.set_constant(&"title_button_height", &"Win95Window", p.px(p.title_button_size.y))
	t.set_constant(&"title_button_separation", &"Win95Window", p.px(2))
	t.set_icon(&"close", &"Win95Window", _glyph(CLOSE_GLYPH, p.text))
	t.set_icon(&"minimize", &"Win95Window", _glyph(MINIMIZE_GLYPH, p.text))

	# Tooltip: a small window without a title bar.
	var tooltip := _raised(Color(), bevel + p.px(4), bevel + p.px(3))
	tooltip.shadow_size = p.px(p.drop_shadow)
	t.set_stylebox(&"panel", &"TooltipPanel", tooltip)
	t.set_color(&"font_color", &"TooltipLabel", p.text)
	t.set_font_size(&"font_size", &"TooltipLabel", p.px(p.small_font_size))

	# Buttons.
	var bx := bevel + p.px(p.button_padding_x)
	var by := bevel + p.px(p.button_padding_y)
	var pressed := _sunken(p.face, bx, by)
	_margins(pressed, bx + p.scale, by + p.scale, bx - p.scale, by - p.scale)
	var disabled := _raised(Color(), bx, by)
	for type: StringName in [&"Button", &"MenuButton"]:
		t.set_stylebox(&"normal", type, _raised(Color(), bx, by))
		t.set_stylebox(&"hover", type, _raised(hover_face, bx, by))
		t.set_stylebox(&"pressed", type, pressed)
		t.set_stylebox(&"hover_pressed", type, pressed)
		t.set_stylebox(&"disabled", type, disabled)
		t.set_stylebox(&"focus", type, _focus(p.px(p.focus_dots_inset)))
		t.set_font(&"font", type, p.title_font)
		_button_colors(t, type)
	_variation(t, &"TitleButton", &"Button")
	var tb := _raised(Color(), 0, 0)
	var tb_pressed := _sunken(p.face, 0, 0)
	_margins(tb_pressed, p.scale, p.scale, 0, 0)
	t.set_stylebox(&"normal", &"TitleButton", tb)
	t.set_stylebox(&"hover", &"TitleButton", _raised(hover_face, 0, 0))
	t.set_stylebox(&"pressed", &"TitleButton", tb_pressed)
	t.set_stylebox(&"hover_pressed", &"TitleButton", tb_pressed)
	t.set_stylebox(&"focus", &"TitleButton", StyleBoxEmpty.new())
	t.set_font_size(&"font_size", &"TitleButton", p.px(p.small_font_size))

	# Check boxes.
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			t.set_stylebox(state, type, _flat(Color(0, 0, 0, 0), p.px(p.focus_outline + p.focus_dots + 2)))
		t.set_stylebox(&"focus", type, _focus(p.px(p.focus_outline + 1)))
		t.set_font(&"font", type, p.body_font)
		_button_colors(t, type)
		t.set_constant(&"h_separation", type, p.px(6))
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		t.set_icon(&"checked", type, _check(true, false, false))
		t.set_icon(&"unchecked", type, _check(false, false, false))
		t.set_icon(&"checked_disabled", type, _check(true, false, true))
		t.set_icon(&"unchecked_disabled", type, _check(false, false, true))
	t.set_icon(&"radio_checked", &"CheckBox", _check(true, true, false))
	t.set_icon(&"radio_unchecked", &"CheckBox", _check(false, true, false))
	t.set_icon(&"radio_checked_disabled", &"CheckBox", _check(true, true, true))
	t.set_icon(&"radio_unchecked_disabled", &"CheckBox", _check(false, true, true))

	# Fields: text inputs and dropdowns are sunken.
	for type: StringName in [&"LineEdit", &"TextEdit"]:
		t.set_stylebox(&"normal", type, _sunken(Color(), bevel + pad))
		t.set_stylebox(&"focus", type, _focus())
		t.set_stylebox(&"read_only", type, _sunken(p.face, bevel + pad))
		t.set_color(&"font_color", type, p.text)
		t.set_color(&"font_placeholder_color", type, p.muted)
		t.set_color(&"font_readonly_color", type, p.muted)
		t.set_color(&"font_selected_color", type, p.text)
		t.set_color(&"selection_color", type, Color(p.accent, 0.45))
		t.set_color(&"caret_color", type, p.text)
	t.set_color(&"background_color", &"TextEdit", Color(0, 0, 0, 0))
	var option_margin := bevel + pad
	t.set_stylebox(&"normal", &"OptionButton", _sunken(Color(), option_margin))
	t.set_stylebox(&"hover", &"OptionButton", _sunken(p.field.lightened(p.hover_lighten * 0.6), option_margin))
	t.set_stylebox(&"pressed", &"OptionButton", _sunken(Color(), option_margin))
	t.set_stylebox(&"hover_pressed", &"OptionButton", _sunken(Color(), option_margin))
	t.set_stylebox(&"disabled", &"OptionButton", _sunken(p.face, option_margin))
	t.set_stylebox(&"focus", &"OptionButton", _focus())
	t.set_font(&"font", &"OptionButton", p.body_font)
	t.set_icon(&"arrow", &"OptionButton", _glyph_arrow(Vector2i.DOWN, p.text))
	t.set_constant(&"arrow_margin", &"OptionButton", p.px(6))
	_button_colors(t, &"OptionButton")

	# Spin boxes: a sunken field with two small raised arrow buttons.
	for dir: String in ["up", "down"]:
		var glyph := _glyph_arrow(Vector2i.UP if dir == "up" else Vector2i.DOWN, p.text)
		for suffix: String in ["", "_hover", "_pressed"]:
			t.set_icon(StringName(dir + suffix), &"SpinBox", glyph)
		t.set_icon(StringName(dir + "_disabled"), &"SpinBox", _glyph_arrow(Vector2i.UP if dir == "up" else Vector2i.DOWN, p.muted))
		t.set_stylebox(StringName(dir + "_background"), &"SpinBox", _raised(Color(), 0, 0))
		t.set_stylebox(StringName(dir + "_background_hovered"), &"SpinBox", _raised(hover_face, 0, 0))
		var spin_pressed := _sunken(p.face, 0, 0)
		_margins(spin_pressed, p.scale, p.scale, 0, 0)
		t.set_stylebox(StringName(dir + "_background_pressed"), &"SpinBox", spin_pressed)
		t.set_stylebox(StringName(dir + "_background_disabled"), &"SpinBox", _raised(Color(), 0, 0))
	t.set_constant(&"buttons_width", &"SpinBox", p.px(p.scrollbar_width))
	t.set_constant(&"buttons_vertical_separation", &"SpinBox", 0)
	t.set_constant(&"field_and_buttons_separation", &"SpinBox", p.px(2))
	t.set_constant(&"set_min_buttons_width_from_icons", &"SpinBox", 0)
	t.set_stylebox(&"field_and_buttons_separator", &"SpinBox", StyleBoxEmpty.new())
	t.set_stylebox(&"up_down_buttons_separator", &"SpinBox", StyleBoxEmpty.new())

	# Menus (dropdown lists, context menus).
	var popup := _raised(Color(), bevel + p.px(2))
	popup.shadow_size = p.px(p.drop_shadow)
	t.set_stylebox(&"panel", &"PopupMenu", popup)
	t.set_stylebox(&"panel", &"PopupPanel", popup)
	t.set_stylebox(&"hover", &"PopupMenu", _selected(row_face))
	t.set_stylebox(&"separator", &"PopupMenu", _separator(true))
	t.set_stylebox(&"labeled_separator_left", &"PopupMenu", _separator(true))
	t.set_stylebox(&"labeled_separator_right", &"PopupMenu", _separator(true))
	t.set_color(&"font_color", &"PopupMenu", p.text)
	t.set_color(&"font_hover_color", &"PopupMenu", p.text)
	t.set_color(&"font_disabled_color", &"PopupMenu", p.muted)
	t.set_color(&"font_separator_color", &"PopupMenu", p.muted)
	t.set_constant(&"v_separation", &"PopupMenu", p.px(6))
	t.set_constant(&"item_start_padding", &"PopupMenu", p.px(p.selection_bar + 6))
	t.set_icon(&"submenu", &"PopupMenu", _glyph_arrow(Vector2i.RIGHT, p.text))
	t.set_icon(&"checked", &"PopupMenu", _check(true, false, false))
	t.set_icon(&"unchecked", &"PopupMenu", _check(false, false, false))
	t.set_icon(&"radio_checked", &"PopupMenu", _check(true, true, false))
	t.set_icon(&"radio_unchecked", &"PopupMenu", _check(false, true, false))

	# Lists.
	for type: StringName in [&"ItemList", &"Tree"]:
		t.set_stylebox(&"panel", type, _sunken(Color(), bevel + p.px(2)))
		t.set_stylebox(&"focus", type, _focus())
		t.set_stylebox(&"selected", type, _selected(row_face))
		t.set_stylebox(&"selected_focus", type, _selected(row_face))
		t.set_stylebox(&"cursor", type, StyleBoxEmpty.new())
		t.set_stylebox(&"cursor_unfocused", type, StyleBoxEmpty.new())
		t.set_color(&"font_color", type, p.text)
		t.set_color(&"font_selected_color", type, p.text)
		t.set_color(&"font_hovered_color", type, p.text)
		t.set_color(&"guide_color", type, Color(0, 0, 0, 0))
	t.set_stylebox(&"hovered", &"ItemList", _flat(p.field.lightened(p.hover_lighten * 0.6), pad))
	t.set_stylebox(&"hovered_selected", &"ItemList", _selected(row_face))
	t.set_stylebox(&"hovered_selected_focus", &"ItemList", _selected(row_face))
	t.set_constant(&"v_separation", &"ItemList", p.px(2))
	t.set_constant(&"h_separation", &"ItemList", p.px(6))
	t.set_icon(&"arrow", &"Tree", _glyph_arrow(Vector2i.DOWN, p.text))
	t.set_icon(&"arrow_collapsed", &"Tree", _glyph_arrow(Vector2i.RIGHT, p.text))
	_variation(t, &"ListRow", &"PanelContainer")
	t.set_stylebox(&"panel", &"ListRow", _flat(Color(0, 0, 0, 0), pad))
	_variation(t, &"ListRowSelected", &"PanelContainer")
	t.set_stylebox(&"panel", &"ListRowSelected", _selected(row_face))
	# A list row that is a button (e.g. save slots): flat, lighter on hover,
	# the accent bar when focused or pressed. Text never shifts.
	_variation(t, &"ListButton", &"Button")
	var row_margin := p.px(p.selection_bar + p.field_padding)
	var row_normal := _flat(Color(0, 0, 0, 0), pad)
	row_normal.content_margin_left = row_margin
	var row_hover := _flat(row_face, pad)
	row_hover.content_margin_left = row_margin
	var row_focus := _flat(Color(0, 0, 0, 0), 0)
	row_focus.accent_width = p.px(p.selection_bar)
	for state: StringName in [&"normal", &"disabled"]:
		t.set_stylebox(state, &"ListButton", row_normal)
	t.set_stylebox(&"hover", &"ListButton", row_hover)
	t.set_stylebox(&"pressed", &"ListButton", _selected(row_face))
	t.set_stylebox(&"hover_pressed", &"ListButton", _selected(row_face))
	t.set_stylebox(&"focus", &"ListButton", row_focus)
	t.set_font(&"font", &"ListButton", p.body_font)
	_variation(t, &"WindowBody", &"VBoxContainer")
	t.set_constant(&"separation", &"WindowBody", p.px(p.body_separation))
	_variation(t, &"FieldList", &"VBoxContainer")
	t.set_constant(&"separation", &"FieldList", 0)
	_variation(t, &"ItemSlot", &"PanelContainer")
	t.set_stylebox(&"panel", &"ItemSlot", _sunken(Color(), bevel + p.px(2)))

	# Bars: sunken trough, flat fill, 1 px dark outline.
	var outline := p.px(p.bar_outline)
	var trough := _sunken(Color(), 0, 0)
	trough.bevel_width = outline
	trough.outline_width = outline
	t.set_stylebox(&"background", &"ProgressBar", trough)
	t.set_color(&"font_color", &"ProgressBar", p.text)
	t.set_font_size(&"font_size", &"ProgressBar", p.px(p.small_font_size))
	var fills := {&"ProgressBar": p.accent, &"HealthBar": p.health_fill, &"EnergyBar": p.energy_fill,
			&"XpBar": p.xp_fill, &"EnemyHealthBar": p.enemy_health_fill}
	for type: StringName in fills:
		if type != &"ProgressBar":
			_variation(t, type, &"ProgressBar")
		var fill := _flat(fills[type])
		fill.draw_inset = outline * 2
		t.set_stylebox(&"fill", type, fill)

	# Scrollbars: 16 px, bevelled grabber and end buttons.
	var half := p.px(p.scrollbar_width) / 2
	for vertical: bool in [true, false]:
		var type: StringName = &"VScrollBar" if vertical else &"HScrollBar"
		var track := _flat(p.field)
		if vertical:
			_margins(track, half, 0, half, 0)
		else:
			_margins(track, 0, half, 0, half)
		t.set_stylebox(&"scroll", type, track)
		t.set_stylebox(&"scroll_focus", type, track)
		var grab_m := half - bevel
		t.set_stylebox(&"grabber", type, _raised(Color(), grab_m))
		t.set_stylebox(&"grabber_highlight", type, _raised(hover_face, grab_m))
		t.set_stylebox(&"grabber_pressed", type, _raised(hover_face, grab_m))
		var dec := Vector2i.UP if vertical else Vector2i.LEFT
		var inc := Vector2i.DOWN if vertical else Vector2i.RIGHT
		t.set_icon(&"decrement", type, _scroll_button(dec, false, false))
		t.set_icon(&"decrement_highlight", type, _scroll_button(dec, false, true))
		t.set_icon(&"decrement_pressed", type, _scroll_button(dec, true, false))
		t.set_icon(&"increment", type, _scroll_button(inc, false, false))
		t.set_icon(&"increment_highlight", type, _scroll_button(inc, false, true))
		t.set_icon(&"increment_pressed", type, _scroll_button(inc, true, false))

	# Sliders.
	for type: StringName in [&"HSlider", &"VSlider"]:
		var rail := _sunken(Color(), p.px(3), p.px(3))
		t.set_stylebox(&"slider", type, rail)
		t.set_stylebox(&"grabber_area", type, StyleBoxEmpty.new())
		t.set_stylebox(&"grabber_area_highlight", type, StyleBoxEmpty.new())
		t.set_stylebox(&"focus", type, _focus())
		t.set_icon(&"grabber", type, _slider_grabber(false))
		t.set_icon(&"grabber_highlight", type, _slider_grabber(true))
		t.set_icon(&"grabber_disabled", type, _slider_grabber(false))

	# Tabs.
	for type: StringName in [&"TabContainer", &"TabBar"]:
		t.set_stylebox(&"tab_selected", type, _raised(Color(), bx, by))
		t.set_stylebox(&"tab_unselected", type, _raised(p.field.lerp(p.face, 0.5), bx, by))
		t.set_stylebox(&"tab_hovered", type, _raised(hover_face, bx, by))
		t.set_stylebox(&"tab_disabled", type, _raised(Color(), bx, by))
		t.set_stylebox(&"tab_focus", type, _focus())
		t.set_font(&"font", type, p.title_font)
		t.set_color(&"font_selected_color", type, p.text)
		t.set_color(&"font_unselected_color", type, p.muted)
		t.set_color(&"font_hovered_color", type, p.text)
		t.set_color(&"font_disabled_color", type, p.muted)
	t.set_stylebox(&"panel", &"TabContainer", _raised(Color(), bevel + p.px(p.body_padding)))

	# Separators: an etched line (dark over light).
	t.set_stylebox(&"separator", &"HSeparator", _separator(true))
	t.set_stylebox(&"separator", &"VSeparator", _separator(false))
	t.set_constant(&"separation", &"HSeparator", p.px(p.body_separation))
	t.set_constant(&"separation", &"VSeparator", p.px(p.body_separation))

	# Godot's own popup windows (AcceptDialog etc.).
	var embedded := _raised()
	embedded.shadow_size = p.px(p.drop_shadow)
	embedded.content_margin_top = p.px(p.title_height)
	embedded.expand_margin_top = p.px(p.title_height)
	t.set_stylebox(&"embedded_border", &"Window", embedded)
	t.set_stylebox(&"embedded_unfocused_border", &"Window", embedded)
	t.set_font(&"title_font", &"Window", p.title_font)
	t.set_font_size(&"title_font_size", &"Window", p.px(p.title_font_size))
	t.set_color(&"title_color", &"Window", p.text)
	t.set_constant(&"title_height", &"Window", p.px(p.title_height))
	t.set_stylebox(&"panel", &"AcceptDialog", _flat(p.face, p.px(p.body_padding)))

	# The circular enemy level badge keeps its circle; it gets this outline.
	t.set_color(&"outline_color", &"LevelBadge", p.shadow)
	t.set_constant(&"outline_size", &"LevelBadge", p.px(2))
	return t


## The tooltip-style box behind HUD text.
func _message_box() -> Win95StyleBox:
	var box := _raised(Color(), p.px(p.bevel + 6), p.px(p.bevel + 2))
	box.shadow_size = p.px(p.drop_shadow)
	return box


## Overlay theme for HUD containers: every Label in a message box, except the
## small labels inside slots.
func _hud_theme() -> Theme:
	var t := Theme.new()
	t.set_font(&"font", &"Label", p.title_font)
	t.set_font_size(&"font_size", &"Label", p.px(p.title_font_size))
	t.set_color(&"font_color", &"Label", p.text)
	t.set_constant(&"outline_size", &"Label", 0)
	t.set_stylebox(&"normal", &"Label", _message_box())
	for type: StringName in [&"SmallLabel", &"SlotCount", &"HintLabel"]:
		t.set_stylebox(&"normal", type, StyleBoxEmpty.new())
		t.set_font(&"font", type, p.body_font)
	t.set_font_size(&"font_size", &"SmallLabel", p.px(p.small_font_size))
	return t


func _variation(t: Theme, type: StringName, base: StringName) -> void:
	t.set_type_variation(type, base)


func _button_colors(t: Theme, type: StringName) -> void:
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		t.set_color(key, type, p.text)
	t.set_color(&"font_disabled_color", type, p.muted)
	t.set_color(&"icon_normal_color", type, p.text)


func _separator(horizontal: bool) -> Win95StyleBox:
	var line := _box(Win95StyleBox.Bevel.SUNKEN, Color(0, 0, 0, 0), 0, 0)
	line.bevel_width = p.scale
	if horizontal:
		_margins(line, 0, p.scale, 0, p.scale)
	else:
		_margins(line, p.scale, 0, p.scale, 0)
	return line
