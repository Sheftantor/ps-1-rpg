class_name State
extends Node
## Base class for StateMachine states. Override only the hooks a state needs.

## The character this machine drives. Subclasses expose it with a typed getter.
var actor: Node = null
var machine: StateMachine = null


## msg carries optional data from whoever requested the transition.
func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	machine.transition_to(state_name, msg)
