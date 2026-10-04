class_name EnemyState
extends State
## Base for enemy states. Flow:
## Idle (patrol) -> Aware -> Reposition -> (Approach) -> Telegraph -> Attack -> Recover -> Reposition
## The last attack of an unbroken escalation chain goes Attack -> BalanceLoss instead.
## Stagger and Dead can interrupt from any state that allows it.

const IDLE: StringName = &"Idle"
const AWARE: StringName = &"Aware"
const REPOSITION: StringName = &"Reposition"
const APPROACH: StringName = &"Approach"
const TELEGRAPH: StringName = &"Telegraph"
const ATTACK: StringName = &"Attack"
const RECOVER: StringName = &"Recover"
const STAGGER: StringName = &"Stagger"
const BALANCE_LOSS: StringName = &"BalanceLoss"
const DEAD: StringName = &"Dead"

var enemy: Enemy:
	get:
		return actor as Enemy


## Whether a hit in this state interrupts it with Stagger.
func can_be_staggered() -> bool:
	return true


## Helpless and open to punishment (stagger, balance loss).
func is_exposed() -> bool:
	return false


## True while this state plays its own model clip; otherwise Enemy picks
## walk/stand from the body's movement.
func drives_animation() -> bool:
	return false
