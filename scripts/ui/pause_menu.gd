class_name PauseMenu
extends CanvasLayer
## Pause screen on the pause input (Esc / Start), dressed with the FREEPSXUI pack
## (Skin01, res://textures/ui/psx/): PAUSE title, resume/exit menu lines that
## brighten when selected, and a scrollable text-block panel with the controls
## (grouped, one row per action: the bound key/button icon and what it does, for
## the device last used) and a live combat readout (enemy health/states, lock-on,
## last hit); player stats and gear are on the status screen (StatusMenu).
## Scroll with the mouse wheel, right stick or Page Up/Down. Pauses the tree;
## works over gun mode's own time stop and puts it back on close. Layout lives
## in res://scenes/pause_menu.tscn.

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
	]],
]
const SECTION_SETTINGS: LabelSettings = preload("res://resources/ui/menu_section.tres")
const ROW_SETTINGS: LabelSettings = preload("res://resources/ui/menu_label.tres")
## Scroll speed for the right stick and Page Up/Down (pixels per second).
const SCROLL_SPEED: float = 900.0

var _was_paused: bool = false

@onready var _root: Control = $Root
@onready var _resume: BaseButton = $Root/Menu/Resume
@onready var _exit: BaseButton = $Root/Menu/Exit
@onready var _scroll: ScrollContainer = $Root/Info/Scroll
@onready var _controls: VBoxContainer = $Root/Info/Scroll/Content/Controls
@onready var _status_text: Label = $Root/Info/Scroll/Content/Status


func _ready() -> void:
	_root.visible = false
	_resume.pressed.connect(close)
	_exit.pressed.connect(func() -> void: get_tree().quit())


func _exit_tree() -> void:
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	# Other menus take the pause input to close themselves.
	if not is_open and GameMenus.any_open():
		return
	if event.is_action_pressed(&"pause"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	_status_text.text = _status()
	var scroll := Input.get_axis(&"look_up", &"look_down")
	if Input.is_action_pressed(&"ui_page_down"):
		scroll = 1.0
	elif Input.is_action_pressed(&"ui_page_up"):
		scroll = -1.0
	if scroll != 0.0:
		_scroll.scroll_vertical += roundi(scroll * SCROLL_SPEED * delta)


func open() -> void:
	if is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_hud_visible(false)
	_build_controls()
	_scroll.scroll_vertical = 0
	_status_text.text = _status()
	_root.visible = true
	_resume.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_root.visible = false
	_set_hud_visible(true)


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
		header.label_settings = SECTION_SETTINGS
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
			text.label_settings = ROW_SETTINGS
			text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# Long descriptions wrap rather than widening the panel.
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(text)
			_controls.add_child(row)
