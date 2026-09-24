class_name StateMachine
extends Node
## Generic finite state machine. States are child nodes extending State, addressed
## by node name. The owner drives it: start() once when ready, then
## physics_update() every physics tick (before move_and_slide()).

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: State
@export var debug_log: bool = false

var current: State = null

var _states: Dictionary[StringName, State] = {}


func start(actor: Node) -> void:
	for child: Node in get_children():
		var state := child as State
		if state == null:
			continue
		state.actor = actor
		state.machine = self
		_states[StringName(state.name)] = state
	assert(initial_state != null, "StateMachine on %s has no initial_state." % actor.name)
	current = initial_state
	current.enter({})


func physics_update(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: State = _states.get(state_name)
	if next == null:
		push_error("StateMachine: no state named '%s'." % state_name)
		return
	var previous := current
	previous.exit()
	current = next
	if debug_log:
		print("[%s] %s -> %s" % [owner.name if owner else name, previous.name, current.name])
	current.enter(msg)
	state_changed.emit(previous.name, current.name)


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func current_name() -> StringName:
	return current.name if current != null else &""
