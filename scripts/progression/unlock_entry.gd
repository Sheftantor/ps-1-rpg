class_name UnlockEntry
extends Resource
## One row of the ProgressionTable's unlock table: when an ability or summon
## becomes available. The classes in start_classes have it from the start;
## everyone else gets it once they reach min_level AND have min_memes memes
## (0 = no requirement of that kind).

@export var ability: EnergyAbility
@export var start_classes: Array[StringName] = []
@export_range(0, 99) var min_level: int = 0
@export var min_memes: int = 0
## Free text for tuning: which numbers are placeholders, what's undecided.
@export_multiline var notes: String = ""
