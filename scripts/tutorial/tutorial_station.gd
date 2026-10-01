class_name TutorialStation
extends Node3D
## One stop in the tutorial room: a sign over the spot (the Sign child, a
## Label3D) and the goal that completes it. The Tutorial node (the parent of all
## stations) runs them in child order, shows the current one's `instruction` on
## screen and checks its goal every tick.

enum Goal {
	MOVE,
	JUMP,
	DODGE,
	## Roll through a TrainingHazard child's strike while invulnerable.
	IFRAME_DODGE,
	LIGHT_ATTACK,
	STRONG_ATTACK,
	AIR_ATTACK,
	AIR_STRONG_ATTACK,
	PICK_UP_WEAPON,
	GUN_MODE,
	## Queue at least one shot on a target in gun mode.
	GUN_LOCK,
	PICK_UP_ITEM,
	USE_ITEM,
}

const COLOR_WAITING: Color = Color(0.6, 0.6, 0.6)
const COLOR_CURRENT: Color = Color(1.0, 0.85, 0.3)
const COLOR_DONE: Color = Color(0.45, 0.9, 0.5)

@export var goal: Goal = Goal.MOVE
## Short name shown on the sign and as the on-screen heading.
@export var title: String = ""
## On-screen text while this is the current station. {action} placeholders
## (e.g. {dodge}, {attack_light}) become that action's key on the device in
## use; {move} becomes WASD / L STICK.
@export_multiline var instruction: String = ""

var done: bool = false
## Set when a TrainingHazard child's strike is rolled through.
var hazard_dodged: bool = false

@onready var _sign: Label3D = $Sign


func _ready() -> void:
	for child: Node in get_children():
		if child is TrainingHazard:
			(child as TrainingHazard).dodged.connect(func() -> void: hazard_dodged = true)
	set_current(false)


func set_current(current: bool) -> void:
	_sign.text = title.to_upper() + ("\nOK" if done else "")
	if done:
		_sign.modulate = COLOR_DONE
	elif current:
		_sign.modulate = COLOR_CURRENT
	else:
		_sign.modulate = COLOR_WAITING
