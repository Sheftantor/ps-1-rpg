class_name EnemyState
extends State
## Base for enemy states. Flow:
## Idle -> Aware -> Reposition -> (Approach) -> Telegraph -> Attack -> Recover -> Reposition
## Stagger and Dead can interrupt from any state that allows it.

const IDLE: StringName = &"Idle"
const AWARE: StringName = &"Aware"
const REPOSITION: StringName = &"Reposition"
const APPROACH: StringName = &"Approach"
const TELEGRAPH: StringName = &"Telegraph"
const ATTACK: StringName = &"Attack"
const RECOVER: StringName = &"Recover"
const STAGGER: StringName = &"Stagger"
const DEAD: StringName = &"Dead"

var enemy: Enemy:
	get:
		return actor as Enemy


## Whether a hit in this state interrupts it with Stagger.
func can_be_staggered() -> bool:
	return true
