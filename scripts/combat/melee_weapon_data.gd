class_name MeleeWeaponData
extends Resource
## The primary (melee) weapon: a bat, sword, pipe... Its model is held in the
## right hand, built in the grip convention of res://scenes/bat.tscn (grip at the
## origin, the weapon extending ~0.47 along +Y) so swings, trails and hitboxes fit.

@export var display_name: String = ""
@export var model: PackedScene
