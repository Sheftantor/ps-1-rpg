extends Control
## Every control type in the Windows 95 theme, for checking the look
## (res://scenes/win95_demo.tscn). The palette button swaps the dark and light
## themes (and cursors). Run with `-- light` to start light, `-- open` to open
## the dropdown, `-- focus` to focus the OK button (for screenshots).

const DARK: Theme = preload("res://resources/ui/win95/win95_dark.tres")
const LIGHT: Theme = preload("res://resources/ui/win95/win95_light.tres")
const DARK_CURSOR := "res://resources/ui/win95/cursor_dark.png"
const LIGHT_CURSOR := "res://resources/ui/win95/cursor_light.png"

@onready var _items: ItemList = %Items
@onready var _choice: OptionButton = %Choice
@onready var _notes: TextEdit = %Notes
@onready var _log: VBoxContainer = %LogList
@onready var _palette_button: Button = %PaletteButton


func _ready() -> void:
	for entry: String in ["Potion  x3", "Tonic  x2", "Bat", "Suppressed pistol", "Wool sweater", "Jeans", "Leather shoes"]:
		_items.add_item(entry)
	_items.select(1)
	for entry: String in ["Windowed", "Fullscreen", "Borderless"]:
		_choice.add_item(entry)
	_notes.text = "\n".join(PackedStringArray(range(1, 31).map(func(i: int) -> String:
		return "Line %d of a long text area, so the scrollbar shows." % i)))
	for i in 24:
		var label := Label.new()
		label.text = "%02d:%02d  Grunt hit you for %d" % [i / 6, (i * 7) % 60, 10 + i]
		_log.add_child(label)
	_palette_button.pressed.connect(_toggle_palette)
	var args := OS.get_cmdline_user_args()
	if args.has("light"):
		_toggle_palette()
	if args.has("focus"):
		(%OkButton as Control).grab_focus()
	if args.has("open"):
		await get_tree().create_timer(0.3).timeout
		var tooltip_target: Control = %OkButton
		Input.warp_mouse(tooltip_target.global_position + tooltip_target.size * 0.5)
		_choice.show_popup()


func _toggle_palette() -> void:
	theme = LIGHT if theme != LIGHT else DARK
	Win95Cursor.set_cursor(LIGHT_CURSOR if theme == LIGHT else DARK_CURSOR)
	_palette_button.text = "Dark palette" if theme == LIGHT else "Light palette"
