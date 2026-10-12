class_name PauseMenu
extends CanvasLayer
## Pause screen on the pause input (Esc / Start), in the Windows 95 theme:
## the PAUSED heading and a Menu window: RESUME, KEY BINDINGS, EXIT TO MENU,
## EXIT GAME. KEY BINDINGS swaps the Menu for the centered Key Bindings window
## (the Info node): the controls, grouped, one row per action with the bound
## key/button icon (from the InputMap, for the device last used) and what it
## does; display only. Scroll it with the mouse wheel, arrows / D-pad, right
## stick or Page Up/Down; BACK returns. The two exits ask first in a small
## Confirm message box (NO focused). Cancel or pause backs out one level
## (message box -> Menu, Key Bindings -> Menu, Menu -> resume). Pauses the
## tree; works over gun mode's own time stop and puts it back on close. The
## combat debug readout (Status label) is kept but hidden. Layout lives in
## res://scenes/pause_menu.tscn.

## True while the menu is up; the player ignores input and physics meanwhile
## (it keeps processing through pauses during gun mode).
static var is_open: bool = false

## Control rows by section: [actions shown as icons, description]. Icons for
## actions that share a binding (e.g. the stick for all four moves) appear once.
const SECTIONS: Array = [
	["MOVEMENT", [
		[[&"move_forward", &"move_left", &"move_back", &"move_right"], "MOVE"],
		[[&"jump"], "JUMP"],
		[[&"dodge"], "DODGE ROLL"],
		[[&"block"], "BLOCK"],
	]],
	["COMBAT", [
		[[&"attack_light"], "LIGHT ATTACK"],
		[[&"attack_heavy"], "HEAVY ATTACK"],
		[[&"lock_on"], "LOCK-ON"],
		[[&"target_prev", &"target_next"], "SWITCH TARGET"],
		[[&"use_item"], "USE ITEM"],
		[[&"next_item"], "NEXT ITEM"],
	]],
	["GUN MODE", [
		[[&"gun_mode"], "ENTER / CANCEL"],
		[[&"attack_light"], "LOCK A SHOT"],
		[[&"target_prev", &"target_next"], "SWITCH TARGET (OR MOVE MOUSE)"],
		[[&"gun_undo"], "UNDO A SHOT"],
		[[&"attack_heavy"], "EXECUTE"],
	]],
	["OTHER", [
		[[&"interact"], "INTERACT"],
		[[&"status_menu"], "STATUS & GEAR"],
		[[&"inventory"], "INVENTORY"],
		[[&"pause"], "PAUSE"],
		[[&"debug_hurt"], "HURT SELF (DEBUG)"],
		[[&"debug_level_up"], "LEVEL UP (DEBUG)"],
	]],
]
## Scroll speed for the right stick and Page Up/Down (pixels per second).
const SCROLL_SPEED: float = 900.0
## Where EXIT TO MENU goes (through the SceneManager autoload).
const START_MENU_SCENE := "res://scenes/start_menu.tscn"
const EXIT_TO_MENU_TEXT := "Exit to the main menu? Unsaved progress will be lost."
const EXIT_GAME_TEXT := "Exit the game? Unsaved progress will be lost."

## Which part of the pause screen has the input.
enum View { MENU, KEY_BINDINGS, CONFIRM }

var _was_paused: bool = false
var _view: View = View.MENU
## What YES does in the message box, and where focus goes back to after it.
var _on_confirm: Callable = Callable()
var _confirm_return: Control = null
## True once EXIT TO MENU is on its way out; input is ignored meanwhile.
var _leaving: bool = false

@onready var _root: Control = $Root
@onready var _menu: Control = $Root/Menu
@onready var _resume: BaseButton = $Root/Menu/Resume
@onready var _key_bindings: BaseButton = $Root/Menu/KeyBindings
@onready var _exit_to_menu: BaseButton = $Root/Menu/ExitToMenu
@onready var _exit: BaseButton = $Root/Menu/Exit
@onready var _bindings_window: Control = $Root/Info
@onready var _back: BaseButton = $Root/Info/Back
@onready var _scroll: ScrollContainer = $Root/Info/Scroll
@onready var _controls: VBoxContainer = $Root/Info/Scroll/Content/Controls
@onready var _status_text: Label = $Root/Info/Scroll/Content/Status
@onready var _modal: Control = $Root/Modal
@onready var _confirm: Control = $Root/Confirm
@onready var _confirm_text: Label = $Root/Confirm/Message
@onready var _yes: BaseButton = $Root/Confirm/Buttons/Yes
@onready var _no: BaseButton = $Root/Confirm/Buttons/No


func _ready() -> void:
	_root.visible = false
	_resume.pressed.connect(close)
	_key_bindings.pressed.connect(_show_key_bindings)
	_exit_to_menu.pressed.connect(_ask.bind(EXIT_TO_MENU_TEXT, go_to_main_menu, _exit_to_menu))
	_exit.pressed.connect(_ask.bind(EXIT_GAME_TEXT, func() -> void: get_tree().quit(), _exit))
	_back.pressed.connect(_show_menu.bind(_key_bindings))
	_yes.pressed.connect(_on_yes)
	_no.pressed.connect(_close_confirm)
	# Keyboard / gamepad focus stays inside each window.
	_trap_focus([_back])
	_trap_focus([_yes, _no])


func _exit_tree() -> void:
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	# Other menus take the pause input to close themselves.
	if not is_open and GameMenus.any_open():
		return
	if not is_open:
		if event.is_action_pressed(&"pause"):
			open()
			get_viewport().set_input_as_handled()
		return
	if _leaving:
		get_viewport().set_input_as_handled()
		return
	# Cancel (Esc / B) or pause (Esc / Start) backs out one level.
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		match _view:
			View.CONFIRM:
				_close_confirm()
			View.KEY_BINDINGS:
				_show_menu(_key_bindings)
			_:
				close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	_status_text.text = _status()
	if _view != View.KEY_BINDINGS:
		return
	var scroll := Input.get_axis(&"look_up", &"look_down") + Input.get_axis(&"ui_up", &"ui_down")
	if Input.is_action_pressed(&"ui_page_down"):
		scroll = 1.0
	elif Input.is_action_pressed(&"ui_page_up"):
		scroll = -1.0
	if scroll != 0.0:
		_scroll.scroll_vertical += roundi(clampf(scroll, -1.0, 1.0) * SCROLL_SPEED * delta)


func open() -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_hud_visible(false)
	_status_text.text = _status()
	_root.visible = true
	_show_menu(_resume)


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root.visible = false
	_set_hud_visible(true)


## EXIT TO MENU's YES: off to the start menu through the SceneManager autoload
## (its fade unpauses the game once the menu is in). Warns and stays put if
## either is missing.
func go_to_main_menu() -> void:
	var scene_manager := get_node_or_null(^"/root/SceneManager")
	if scene_manager == null or not ResourceLoader.exists(START_MENU_SCENE):
		push_warning("PauseMenu: no SceneManager or start menu (%s); staying in the game." % START_MENU_SCENE)
		_show_menu(_exit_to_menu)
		return
	_leaving = true
	_set_buttons_enabled(false)
	scene_manager.transition_scene(START_MENU_SCENE)


# --- Views -------------------------------------------------------------------------

## The Menu window, with focus on focus_button.
func _show_menu(focus_button: Control) -> void:
	_view = View.MENU
	_bindings_window.visible = false
	_confirm.visible = false
	_modal.visible = false
	_menu.visible = true
	_set_buttons_enabled(true)
	focus_button.grab_focus()


## The Key Bindings window in place of the Menu.
func _show_key_bindings() -> void:
	_view = View.KEY_BINDINGS
	_build_controls()
	_scroll.scroll_vertical = 0
	_menu.visible = false
	_bindings_window.visible = true
	_back.grab_focus()


## The message box over the Menu: YES runs on_yes, NO (focused) goes back to
## return_focus.
func _ask(message: String, on_yes: Callable, return_focus: Control) -> void:
	_view = View.CONFIRM
	_on_confirm = on_yes
	_confirm_return = return_focus
	_confirm_text.text = message
	# The Menu stays visible behind it but can't be clicked or focused.
	_set_buttons_enabled(false)
	_modal.visible = true
	_confirm.visible = true
	_no.grab_focus()


func _close_confirm() -> void:
	_show_menu(_confirm_return if _confirm_return != null else _resume)


func _on_yes() -> void:
	var action := _on_confirm
	_confirm.visible = false
	_on_confirm = Callable()
	action.call()


## Menu buttons on or off for focus and clicks (off while the message box is up).
func _set_buttons_enabled(enabled: bool) -> void:
	for button: BaseButton in [_resume, _key_bindings, _exit_to_menu, _exit]:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


## Up/down/left/right and Tab cycle only through these buttons.
static func _trap_focus(buttons: Array) -> void:
	for i in buttons.size():
		var button: BaseButton = buttons[i]
		var previous := button.get_path_to(buttons[i - 1])
		var next := button.get_path_to(buttons[(i + 1) % buttons.size()])
		var self_path := NodePath(".")
		button.focus_neighbor_top = self_path
		button.focus_neighbor_bottom = self_path
		button.focus_neighbor_left = previous
		button.focus_neighbor_right = next
		button.focus_previous = previous
		button.focus_next = next


## The in-game HUD would otherwise show through behind the menu.
func _set_hud_visible(shown: bool) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.hud.visible = shown


func _status() -> String:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return ""
	# Player stats and gear moved to the status screen (StatusMenu); this keeps
	# the combat debug readout.
	var lines: PackedStringArray = [
		"LOCK-ON  %s" % (String(player.lock_target.name).to_upper() if player.lock_target != null else "-"),
		"LAST HIT  %s" % player.last_hit_result.to_upper(),
		"",
	]
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var turn := "  ATTACK TURN" if EnemyAttackCoordinator.is_holder(enemy) else ""
		lines.append("%s  HP %d/%d  %s%s" % [String(enemy.name).to_upper(), enemy.health.current,
				enemy.health.max_health, String(enemy.state_machine.current_name()).to_upper(), turn])
	return "\n".join(lines)


## Rebuilds the control rows for the device the player last used.
func _build_controls() -> void:
	for child in _controls.get_children():
		child.queue_free()
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var gamepad := player != null and player.hud.using_gamepad
	for section: Array in SECTIONS:
		var header := Label.new()
		header.text = section[0]
		header.theme_type_variation = &"SectionLabel"
		_controls.add_child(header)
		for row_data: Array in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 10)
			var icons := HBoxContainer.new()
			icons.add_theme_constant_override(&"separation", 4)
			icons.custom_minimum_size.x = 200
			var shown := PackedStringArray()
			for action: StringName in row_data[0]:
				# Wheel up/down share one "WHEEL" icon.
				var label := InputBindings.label(action, gamepad).trim_suffix(" UP").trim_suffix(" DOWN")
				if label in shown:
					continue
				shown.append(label)
				var icon := InputIcon.new()
				icon.gamepad = gamepad
				# Staggered so the rows ripple instead of all pressing at once.
				icon.press_phase = -0.12 * _controls.get_child_count()
				icon.action = action
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				icons.add_child(icon)
			row.add_child(icons)
			var text := Label.new()
			text.text = row_data[1]
			text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Long descriptions wrap rather than widening the panel.
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(text)
			_controls.add_child(row)
