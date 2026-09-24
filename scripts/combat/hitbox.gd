class_name Hitbox
extends Area3D
## The damaging region of an attack. Inactive until activate() is called; each
## Hurtbox is hit at most once per activation. Any child meshes are shown while
## active as a stand-in for attack animations.

signal hit_landed(hurtbox: Hurtbox)

@export var show_debug_mesh: bool = true

var _attack: AttackData = null
var _source: Node3D = null
var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false
	monitorable = false
	visible = false
	area_entered.connect(_on_area_entered)


func activate(attack: AttackData, source: Node3D) -> void:
	_attack = attack
	_source = source
	_already_hit.clear()
	visible = show_debug_mesh
	if monitoring:
		# Already live (back-to-back activation): area_entered won't re-fire for
		# overlaps that never left, so check them directly.
		for area: Area3D in get_overlapping_areas():
			_on_area_entered(area)
	else:
		set_deferred(&"monitoring", true)


func deactivate() -> void:
	_attack = null
	visible = false
	set_deferred(&"monitoring", false)


func is_active() -> bool:
	return _attack != null


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or _attack == null or hurtbox in _already_hit:
		return
	_already_hit.append(hurtbox)
	if hurtbox.receive_hit(_attack, _source):
		hit_landed.emit(hurtbox)
