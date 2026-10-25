class_name LevelRow
extends Resource
## One level's row in the ProgressionTable (levels 1-20).

@export_range(1, 99) var level: int = 1
## Stat points gained on reaching this level (level 1: the starting points).
@export var stat_points: int = 1
## Max health / max energy gained for each stat point spent at this level.
@export var health_per_point: float = 5.0
@export var energy_per_point: float = 3.0
## How fast the energy-mode meter (the ultimate) charges at this level: a
## multiplier on whatever fills it (hits landed, damage taken...). 1 = normal.
## Separate from the ENERGY bar (Player.stamina) that dodges and blocks spend.
@export var energy_fill_rate: float = 1.0
## Ability id -> power multiplier at this level, before the stat bonus
## (ProgressionTable.ability_power()). Ids: rush_attack, line_shot, back_stab,
## strong_summon, summon.
@export var ability_power: Dictionary[StringName, float] = {}
## Free text for tuning: which numbers are placeholders, what's undecided.
@export_multiline var notes: String = ""
