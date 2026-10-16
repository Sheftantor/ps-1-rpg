class_name PauseMenu
extends CanvasLayer
## Pause screen on the pause input (Esc / Start), in the Windows 95 theme:
## the PAUSED heading and a Menu window: RESUME, KEY BINDINGS, EXIT TO MENU,
## EXIT GAME. KEY BINDINGS swaps the Menu for the centered Key Bindings window
## (the Info node): one row per action, grouped, each with a KEYBOARD / MOUSE
## slot and a CONTROLLER slot showing the bound input's icon. Selecting a slot
## listens for its new binding (see _capture_input): any key or mouse button
## for the first slot, any pad button, trigger or stick direction for the
## second. Holding one input and then pressing another binds the pair as a
## combo ("hold LB, then press X"); movement only takes one input. An input
## another action already had is swapped onto that action's old binding.
## Waiting CAPTURE_TIME (or the other device's cancel button) cancels. RESET
## DEFAULTS puts every binding back (after a confirm). Bindings are saved by
## InputBindings. Scroll with the mouse wheel, right stick or Page Up/Down;
## focus also scrolls into view. BACK returns. The two exits ask first in a
## small Confirm message box (NO focused). Cancel or pause backs out one level
## (message box -> where it came from, Key Bindings -> Menu, Menu -> resume).
## Pauses the tree; works over gun mode's own time stop and puts it back on
## close. The combat debug readout (Status label) is kept but hidden. Layout
## lives in res://scenes/pause_menu.tscn.

## True while the menu is up; the player ignores input and physics meanwhile
## (it keeps processing through pauses during gun mode).
static var is_open: bool = false

## Key Bindings rows by section: [action, description].
const SECTIONS: Array = [
	["MOVEMENT", [
		[&"move_forward", "MOVE FORWARD"],
		[&"move_back", "MOVE BACK"],
		[&"move_left", "MOVE LEFT"],
		[&"move_right", "MOVE RIGHT"],
		[&"jump", "JUMP"],
		[&"dodge", "DODGE ROLL"],
		[&"block", "BLOCK"],
	]],
	["COMBAT", [
		[&"attack_light", "LIGHT ATTACK / LOCK A SHOT"],
		[&"attack_heavy", "HEAVY ATTACK / EXECUTE SHOTS"],
		[&"lock_on", "LOCK-ON"],
		[&"target_prev", "PREVIOUS TARGET"],
		[&"target_next", "NEXT TARGET"],
		[&"use_item", "USE ITEM"],
		[&"next_item", "NEXT ITEM"],
	]],
	["GUN MODE", [
		[&"gun_mode", "ENTER / CANCEL GUN MODE"],
		[&"gun_undo", "UNDO A SHOT"],
	]],
	["OTHER", [
		[&"interact", "INTERACT"],
		[&"status_menu", "STATUS & GEAR"],
		[&"inventory", "INVENTORY"],
		[&"pause", "PAUSE"],
		[&"debug_hurt", "HURT SELF (DEBUG)"],
		[&"debug_level_up", "LEVEL UP (DEBUG)"],
	]],
]
## Width of each binding slot (pixels).
const SLOT_WIDTH: float = 230.0
## Seconds a slot listens before giving up.
const CAPTURE_TIME: float = 5.0
const IDLE_HINT := "Select a slot to change it. Hold one button and press another for a combo."
const RESET_TEXT := "Put every key and button back to its default?"
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
## Which view the message box came from (NO goes back there).
var _confirm_from: View = View.MENU
## The slot listening for a new binding (null when not capturing), its action
## and device, the first input of the chord so far, and the time left.
var _capture_slot: Button = null
var _capture_action: StringName = &""
var _capture_gamepad: bool = false
var _capture_first: String = ""
var _capture_timer: float = 0.0
## Stick/trigger directions held during the capture, so each counts once.
var _capture_axes: Dictionary[String, bool] = {}

@onready var _root: Control = $Root
@onready var _menu: Control = $Root/Menu
@onready var _resume: BaseButton = $Root/Menu/Resume
@onready var _key_bindings: BaseButton = $Root/Menu/KeyBindings
@onready var _exit_to_menu: BaseButton = $Root/Menu/ExitToMenu
@onready var _exit: BaseButton = $Root/Menu/Exit
@onready var _bindings_window: Control = $Root/Info
@onready var _back: BaseButton = $Root/Info/Footer/Back
@onready var _reset: BaseButton = $Root/Info/Footer/Reset
@onready var _hint: Label = $Root/Info/Footer/Hint
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
	_reset.pressed.connect(_ask.bind(RESET_TEXT, _reset_bindings, _reset))
	_scroll.follow_focus = true
	_yes.pressed.connect(_on_yes)
	_no.pressed.connect(_close_confirm)
	# Keyboard / gamepad focus stays inside each window.
	_trap_focus([_yes, _no])


func _exit_tree() -> void:
	is_open = false


## While a slot listens, every input goes to it (before the buttons see it).
func _input(event: InputEvent) -> void:
	if _capture_slot != null:
		get_viewport().set_input_as_handled()
		_capture_input(event)


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
	if _capture_slot != null:
		_capture_timer -= delta
		if _capture_timer <= 0.0:
			_end_capture("Cancelled.")
		else:
			_show_capture_hint()
		return
	# Up/down move the focus between slots (which scrolls to follow it).
	var scroll := Input.get_axis(&"look_up", &"look_down")
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
	_end_capture("")
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


## The Key Bindings window in place of the Menu, with focus on focus_control
## (the first slot if null).
func _show_key_bindings(focus_control: Control = null) -> void:
	var rebuild := _view != View.CONFIRM or focus_control == null
	_view = View.KEY_BINDINGS
	_confirm.visible = false
	_modal.visible = false
	if rebuild:
		_build_controls()
		_scroll.scroll_vertical = 0
	_hint.text = IDLE_HINT
	_menu.visible = false
	_bindings_window.visible = true
	if focus_control == null:
		focus_control = _first_slot()
	focus_control.grab_focus()


func _first_slot() -> Control:
	for button: Node in _controls.find_children("*", "Button", true, false):
		return button as Control
	return _back


## The message box over the current window: YES runs on_yes, NO (focused)
## goes back to return_focus.
func _ask(message: String, on_yes: Callable, return_focus: Control) -> void:
	_confirm_from = _view
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
	if _confirm_from == View.KEY_BINDINGS:
		_show_key_bindings(_confirm_return)
	else:
		_show_menu(_confirm_return if _confirm_return != null else _resume)


## RESET DEFAULTS' YES.
func _reset_bindings() -> void:
	InputBindings.reset_to_defaults()
	_view = View.KEY_BINDINGS
	_show_key_bindings(null)
	_reset.grab_focus()
	_hint.text = "Every key and button is back to its default."


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


# --- Key Bindings -------------------------------------------------------------------

## Rebuilds the binding rows: per section a header with the two device
## columns, then per action its description and its two slots.
func _build_controls() -> void:
	for child in _controls.get_children():
		_controls.remove_child(child)
		child.queue_free()
	for section: Array in SECTIONS:
		var header := HBoxContainer.new()
		header.add_theme_constant_override(&"separation", 10)
		header.add_child(_section_label(section[0], true))
		header.add_child(_section_label("KEYBOARD / MOUSE", false))
		header.add_child(_section_label("CONTROLLER", false))
		_controls.add_child(header)
		for row_data: Array in section[1]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 10)
			var text := Label.new()
			text.text = row_data[1]
			text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Long descriptions wrap rather than widening the panel.
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(text)
			for gamepad: bool in [false, true]:
				row.add_child(_slot(row_data[0], gamepad, row_data[1]))
			_controls.add_child(row)


func _section_label(text: String, expand: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		label.custom_minimum_size.x = SLOT_WIDTH
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## A button showing the binding's icon; pressing it listens for a new one.
func _slot(action: StringName, gamepad: bool, description: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(SLOT_WIDTH, 52)
	button.set_meta(&"action", action)
	button.set_meta(&"gamepad", gamepad)
	button.set_meta(&"description", description)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(center)
	var icon := InputIcon.new()
	icon.gamepad = gamepad
	icon.action = action
	# Only the slot being looked at pumps, so the list doesn't flicker.
	icon.animate_press = false
	center.add_child(icon)
	button.pressed.connect(_start_capture.bind(button))
	button.focus_entered.connect(func() -> void: icon.animate_press = true)
	button.focus_exited.connect(func() -> void: icon.animate_press = false)
	return button


func _start_capture(slot: Button) -> void:
	if _capture_slot != null:
		return
	_capture_slot = slot
	_capture_action = slot.get_meta(&"action")
	_capture_gamepad = slot.get_meta(&"gamepad")
	_capture_first = ""
	_capture_timer = CAPTURE_TIME
	_capture_axes.clear()
	InputCombos.capturing = true
	slot.get_child(0).visible = false
	slot.text = "PRESS..."
	_show_capture_hint()


## Listening for the slot's new binding: the first input pressed is held as
## the start of the chord. Letting go of it alone binds it by itself; pressing
## a second input while it's held binds the pair as a combo. Movement binds
## on the first press. The other device's cancel/pause button cancels.
func _capture_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventAction or event.is_echo():
		return
	var pad_event := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad_event != _capture_gamepad:
		if event.is_pressed() and (event.is_action(&"pause") or event.is_action(&"ui_cancel")):
			_end_capture("Cancelled.")
		return
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		for sign: String in ["+", "-"]:
			var id := "axis:%d:%s" % [motion.axis, sign]
			var amount := motion.axis_value * (1.0 if sign == "+" else -1.0)
			if amount >= 0.6 and not _capture_axes.has(id):
				_capture_axes[id] = true
				_capture_press(id)
			elif amount < 0.3 and _capture_axes.has(id):
				_capture_axes.erase(id)
				_capture_release(id)
			if _capture_slot == null:
				return
		return
	var id := InputBindings.event_id(event)
	if id.is_empty():
		return
	if event.is_pressed():
		_capture_press(id)
	else:
		_capture_release(id)


func _capture_press(id: String) -> void:
	if _capture_first.is_empty():
		if _capture_action in InputBindings.SINGLE_ONLY:
			_finish_capture(PackedStringArray([id]))
			return
		_capture_first = id
		_capture_timer = CAPTURE_TIME
		_show_capture_hint()
	elif id != _capture_first:
		_finish_capture(PackedStringArray([_capture_first, id]))


func _capture_release(id: String) -> void:
	if id == _capture_first:
		_finish_capture(PackedStringArray([id]))


func _finish_capture(chord: PackedStringArray) -> void:
	var swapped := InputBindings.rebind(_capture_action, _capture_gamepad, chord)
	var message := "%s: %s" % [_capture_slot.get_meta(&"description"), InputBindings.label(_capture_action, _capture_gamepad)]
	if swapped != &"":
		message += "  (swapped with %s)" % _description(swapped)
	_end_capture(message)


## Stops listening; message goes in the hint (empty for the idle hint).
func _end_capture(message: String) -> void:
	if _capture_slot == null:
		return
	var slot := _capture_slot
	_capture_slot = null
	InputCombos.capturing = false
	slot.text = ""
	slot.get_child(0).visible = true
	slot.grab_focus()
	_hint.text = message if not message.is_empty() else IDLE_HINT


func _show_capture_hint() -> void:
	var device := "a pad button, trigger or stick" if _capture_gamepad else "a key or mouse button"
	var cancel := "Esc" if _capture_gamepad else "B / Start"
	var seconds := ceili(_capture_timer)
	if _capture_action in InputBindings.SINGLE_ONLY:
		_hint.text = "%s: press %s.  (%s or wait %d s to cancel)" % [_capture_slot.get_meta(&"description"), device, cancel, seconds]
	elif _capture_first.is_empty():
		_hint.text = "%s: press %s. For a combo, hold it and then press a second one.  (%s or wait %d s to cancel)" \
				% [_capture_slot.get_meta(&"description"), device, cancel, seconds]
	else:
		var held := InputBindings.event_label(InputBindings.event_from_id(_capture_first))
		_hint.text = "Holding %s: press a second input for a combo, or let go to use %s alone.  (%d s)" % [held, held, seconds]


func _description(action: StringName) -> String:
	for section: Array in SECTIONS:
		for row_data: Array in section[1]:
			if row_data[0] == action:
				return row_data[1]
	return String(action).to_upper()
