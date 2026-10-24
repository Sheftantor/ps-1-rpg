class_name SuitState
extends EnemyState
## Base for Suit Guy's states. Uses EnemyState's ATTACK, STAGGER and DEAD names
## (Enemy sends hits to Stagger and Dead) plus its own Wander and Engage.

const WANDER: StringName = &"Wander"
const ENGAGE: StringName = &"Engage"

var suit: SuitGuy:
	get:
		return actor as SuitGuy


## In range and in sight: worth engaging (or staying engaged).
func can_see_target(max_range: float) -> bool:
	return suit.distance_to_target() <= max_range and suit.has_line_of_sight()
