class_name EnemyState
extends State
## Base for enemy states. Flow:
## Idle (patrol) -> Aware -> Reposition -> (Approach) -> Telegraph -> Attack (the
## five-swing combo) -> Recover (vulnerable) -> Reposition. Rarely, Reposition
## goes to StepBack instead of starting a combo. Stagger and Dead can interrupt
## from any state that allows it.

const IDLE: StringName = &"Idle"
const AWARE: StringName = &"Aware"
const REPOSITION: StringName = &"Reposition"
const APPROACH: StringName = &"Approach"
const TELEGRAPH: StringName = &"Telegraph"
const ATTACK: StringName = &"Attack"
const RECOVER: StringName = &"Recover"
const STAGGER: StringName = &"Stagger"
const STEP_BACK: StringName = &"StepBack"
const DEAD: StringName = &"Dead"

var enemy: Enemy:
	get:
		return actor as Enemy


## Whether a hit in this state interrupts it with Stagger.
func can_be_staggered() -> bool:
	return true


## Helpless and open to punishment (stagger, the post-combo recovery).
func is_exposed() -> bool:
	return false


## True while this state plays its own model clip; otherwise Enemy picks
## walk/stand from the body's movement.
func drives_animation() -> bool:
	return false
