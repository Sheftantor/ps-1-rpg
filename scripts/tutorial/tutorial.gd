class_name Tutorial
extends Node
## Runs the tutorial room's stations (TutorialStation children) one at a time,
## in child order: shows the current one's instruction in the Prompt overlay,
## checks its goal every tick, and moves on once it's met. Keeps processing
## through gun mode's time stop so the gun stations can complete.

@export var finished_title: String = "Tutorial complete"
@export_multiline var finished_text: String = "Walk through the exit at the end of the room."

var _stations: Array[TutorialStation] = []
var _index: int = 0
## Where the player stood / how many items they held when the station began.
var _start_position: Vector3 = Vector3.ZERO
var _start_item_count: int = 0

@onready var _prompt_layer: CanvasLayer = $Prompt
@onready var _step_label: Label = $Prompt/Root/Panel/VBox/Step
@onready var _text_label: Label = $Prompt/Root/Panel/VBox/Text


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child: Node in get_children():
		if child is TutorialStation:
			_stations.append(child as TutorialStation)
	# Stations and the player are siblings of ours, so wait for them to be ready.
	_begin_station.call_deferred(0)


func _physics_process(_delta: float) -> void:
	_prompt_layer.visible = not PauseMenu.is_open
	var player := _player()
	if player == null or _index >= _stations.size():
		return
	var station := _stations[_index]
	if _goal_met(station, player):
		station.done = true
		station.set_current(false)
		_begin_station(_index + 1)
	else:
		_show(station)


func _begin_station(index: int) -> void:
	_index = index
	var player := _player()
	if player != null:
		_start_position = player.global_position
		_start_item_count = _item_count(player)
	if _index < _stations.size():
		_stations[_index].set_current(true)
		_show(_stations[_index])
	else:
		_step_label.text = finished_title.to_upper()
		_text_label.text = finished_text


func _show(station: TutorialStation) -> void:
	_step_label.text = "%d/%d  %s" % [_index + 1, _stations.size(), station.title.to_upper()]
	_text_label.text = _format(station.instruction)


func _goal_met(station: TutorialStation, player: Player) -> bool:
	var state := player.state_machine.current_name()
	var grounded := player.is_on_floor()
	match station.goal:
		TutorialStation.Goal.MOVE:
			return player.global_position.distance_to(_start_position) > 3.0
		TutorialStation.Goal.JUMP:
			return not grounded and player.velocity.y > 1.0
		TutorialStation.Goal.DODGE:
			return state == PlayerState.DODGE
		TutorialStation.Goal.IFRAME_DODGE:
			return station.hazard_dodged
		TutorialStation.Goal.LIGHT_ATTACK:
			return state == PlayerState.LIGHT_ATTACK and grounded
		TutorialStation.Goal.STRONG_ATTACK:
			return state == PlayerState.HEAVY_ATTACK and grounded
		TutorialStation.Goal.AIR_ATTACK:
			return state == PlayerState.LIGHT_ATTACK and not grounded
		TutorialStation.Goal.AIR_STRONG_ATTACK:
			return state == PlayerState.HEAVY_ATTACK and not grounded
		TutorialStation.Goal.PICK_UP_WEAPON:
			return player.gun != null
		TutorialStation.Goal.GUN_MODE:
			return state == PlayerState.GUN_AIM
		TutorialStation.Goal.GUN_LOCK:
			var queue: Variant = player.state_machine.current.get("queue")
			return state == PlayerState.GUN_AIM and queue is Array and not (queue as Array).is_empty()
		TutorialStation.Goal.PICK_UP_ITEM:
			return _item_count(player) > _start_item_count
		TutorialStation.Goal.USE_ITEM:
			return _item_count(player) < _start_item_count
	return false


## Replaces {action} placeholders with the key/button for the device in use.
func _format(text: String) -> String:
	var player := _player()
	if player == null:
		return text
	var result := text.replace("{move}", "L STICK" if player.hud.using_gamepad else "WASD")
	var regex := RegEx.create_from_string("\\{(\\w+)\\}")
	for found: RegExMatch in regex.search_all(result):
		result = result.replace(found.get_string(), player.hud.key_label(StringName(found.get_string(1))))
	return result


func _item_count(player: Player) -> int:
	var total := 0
	for stack: ItemStack in player.inventory:
		total += stack.count
	return total


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player
