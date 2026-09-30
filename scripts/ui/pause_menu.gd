class_name PauseMenu
extends CanvasLayer
## Pause screen on the pause input (Esc / Start), dressed with the FREEPSXUI pack
## (Skin01, res://textures/ui/psx/): PAUSE title, resume/exit menu lines that
## brighten when selected, and text-block panels holding the controls list and a
## live status readout (player and enemy health/states, last hit), which used to
## sit on screen as the debug HUD. Pauses the tree; works over gun mode's own
## time stop and puts it back on close. Layout lives in res://scenes/pause_menu.tscn.

## True while the menu is up; the player ignores input and physics meanwhile
## (it keeps processing through pauses during gun mode).
static var is_open: bool = false

const CONTROLS: PackedStringArray = [
	"WASD  MOVE          SPACE  JUMP         SHIFT  DODGE ROLL",
	"LMB  LIGHT ATTACK   RMB  HEAVY ATTACK   Q  BLOCK",
	"TAB / MMB  LOCK-ON  WHEEL  SWITCH TARGET",
	"E  PICK UP          CTRL  GUN MODE      HOLD F  COMMAND MENU",
	"GUN MODE:  MOUSE / WHEEL SWITCH   LMB LOCK SHOT   R UNDO",
	"           RMB EXECUTE   CTRL CANCEL",
	"ESC  PAUSE          K  HURT SELF (DEBUG)",
]

var _was_paused: bool = false

@onready var _root: Control = $Root
@onready var _resume: BaseButton = $Root/Menu/Resume
@onready var _exit: BaseButton = $Root/Menu/Exit
@onready var _controls_text: Label = $Root/Panels/Controls/VBox/Text
@onready var _status_text: Label = $Root/Panels/Status/VBox/Text


func _ready() -> void:
	_root.visible = false
	_resume.pressed.connect(close)
	_exit.pressed.connect(func() -> void: get_tree().quit())
	_controls_text.text = "\n".join(CONTROLS)


func _exit_tree() -> void:
	is_open = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if is_open:
		_status_text.text = _status()


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
	var lines: PackedStringArray = [
		"PLAYER  HP %d/%d  STAMINA %d/%d" % [player.health.current, player.health.max_health,
				roundi(player.stamina.current), roundi(player.stamina.maximum)],
		"STATE  %s    WEAPON  %s" % [String(player.state_machine.current_name()).to_upper(),
				(player.gun.display_name if player.gun != null else "NO GUN").to_upper()],
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
