class_name MeleeWeaponData
extends Resource
## A melee weapon (the primary slot): bats, swords, pipes... all melee weapons
## share this class, its swing combo and its guard (Block). Its model is held in the
## right hand, built in the grip convention of res://scenes/bat.tscn (grip at the
## origin, the weapon extending ~0.47 along +Y) so swings, trails and hitboxes fit.

@export var display_name: String = ""
## Flavour/help text shown under the gear on the status screen.
@export_multiline var description: String = ""
## Square picture for the HUD loadout row and status screen. Defaults to a placeholder.
@export var icon: Texture2D = preload("res://textures/ui/icons/placeholder_melee.png")
@export var model: PackedScene
