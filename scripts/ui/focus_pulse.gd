extends Node
## Autoload: makes the highlighted UI item blink like Smash Bros. Brawl's menu
## cursor. Hovering a button gives it focus (so the mouse and the controller
## highlight the same way), and the focused control is redrawn every frame so
## its pulsing focus style (Win95StyleBox.pulse_color, set by the theme
## builder from Win95Palette.focus_pulse) animates.

var _hovered: Control = null
var _focused: Control = null


func _ready() -> void:
	# Menus pause the game.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	var hovered := viewport.gui_get_hovered_control()
	if hovered != _hovered:
		_hovered = hovered
		var button := hovered as BaseButton
		if button != null and not button.disabled and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
	var focused := viewport.gui_get_focus_owner()
	if focused != _focused:
		# One last draw so the old one settles.
		if is_instance_valid(_focused):
			_focused.queue_redraw()
		_focused = focused
	if focused != null:
		focused.queue_redraw()
