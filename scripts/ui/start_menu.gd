extends CanvasLayer
## The first screen (res://scenes/start_menu.tscn), ported from
## metroidvania-proto's title screen: New Game (pick one of SaveManager's
## slots, "Replace" if it's taken), Continue (the most recent save; greyed out
## if there's none), Load Game (each slot's level, location, play time and
## date; empty or damaged slots greyed out) and Quit. Cancel (Esc / B) goes
## back to the main list.

@onready var main_menu: VBoxContainer = %MainMenu
@onready var new_game_menu: Control = %NewGameMenu
@onready var load_game_menu: Control = %LoadGameMenu

@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var load_game_button: Button = %LoadGameButton
@onready var quit_button: Button = %QuitButton

@onready var new_slots: Array[Button] = [%NewSlot1, %NewSlot2, %NewSlot3]
@onready var load_slots: Array[Button] = [%LoadSlot1, %LoadSlot2, %LoadSlot3]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	new_game_button.pressed.connect(show_new_game_menu)
	continue_button.pressed.connect(_on_continue_pressed)
	load_game_button.pressed.connect(show_load_game_menu)
	quit_button.pressed.connect(get_tree().quit)
	for slot in new_slots.size():
		new_slots[slot].pressed.connect(_on_new_game_pressed.bind(slot))
		load_slots[slot].pressed.connect(_on_load_game_pressed.bind(slot))
	# Hovering with the mouse moves the highlight, so only one line is lit.
	for button: Button in find_children("*", "Button", true, false):
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				button.grab_focus())
	show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not main_menu.visible:
		show_main_menu()
		get_viewport().set_input_as_handled()


func show_main_menu() -> void:
	main_menu.visible = true
	new_game_menu.visible = false
	load_game_menu.visible = false
	continue_button.disabled = SaveManager.most_recent_slot() < 0
	continue_button.focus_mode = Control.FOCUS_NONE if continue_button.disabled else Control.FOCUS_ALL
	(new_game_button if continue_button.disabled else continue_button).grab_focus()


func show_new_game_menu() -> void:
	main_menu.visible = false
	new_game_menu.visible = true
	load_game_menu.visible = false
	for slot in new_slots.size():
		var verb := "REPLACE" if SaveManager.save_file_exists(slot) else "BEGIN"
		new_slots[slot].text = "%s SLOT %d" % [verb, slot + 1]
	new_slots[0].grab_focus()


func show_load_game_menu() -> void:
	main_menu.visible = false
	new_game_menu.visible = false
	load_game_menu.visible = true
	var first_enabled: Button = null
	for slot in load_slots.size():
		var info := SaveManager.get_slot_info(slot)
		var button := load_slots[slot]
		match info.state:
			"ok":
				button.text = "SLOT %d     LV %d     %s\n%s     %s" % [slot + 1, info.level,
						String(info.location).to_upper(), SaveManager.format_play_time(info.play_time),
						SaveManager.format_date(info.timestamp)]
			"damaged":
				button.text = "SLOT %d\nDAMAGED SAVE" % (slot + 1)
			_:
				button.text = "SLOT %d\nEMPTY" % (slot + 1)
		button.disabled = info.state != "ok"
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if first_enabled == null and not button.disabled:
			first_enabled = button
	if first_enabled != null:
		first_enabled.grab_focus()


func _on_new_game_pressed(slot: int) -> void:
	SaveManager.create_new_save_game(slot)


func _on_continue_pressed() -> void:
	var slot := SaveManager.most_recent_slot()
	if slot >= 0:
		SaveManager.load_game(slot)


func _on_load_game_pressed(slot: int) -> void:
	SaveManager.load_game(slot)
