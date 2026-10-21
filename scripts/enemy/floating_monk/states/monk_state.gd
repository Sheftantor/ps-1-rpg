class_name MonkState
extends EnemyState
## Base for the Floating Monk's states. Uses EnemyState's ATTACK (the combo),
## RECOVER, STAGGER and DEAD names (Enemy sends hits to Stagger and Dead) plus
## its own Hover, Engage, Volley and Rush. By default a hit only staggers him
## once his poise is broken (FloatingMonk.poise_hits quick hits in a row).

const HOVER: StringName = &"Hover"
const ENGAGE: StringName = &"Engage"
const VOLLEY: StringName = &"Volley"
const RUSH: StringName = &"Rush"

## The arms the combo strikes with, wound back in the rush's tell.
const COMBO_ARMS: PackedStringArray = ["Yellow Right Arm", "Red Left Arm", "Green Right Arm", "Purple Left Arm"]

var monk: FloatingMonk:
	get:
		return actor as FloatingMonk


func can_be_staggered() -> bool:
	return monk.poise_broken()


## In range and in sight: worth engaging (or staying engaged).
func can_see_target(max_range: float) -> bool:
	return monk.distance_to_target() <= max_range and monk.has_line_of_sight()
