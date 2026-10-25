class_name EnergyAbility
extends Resource
## One energy-mode ability or summon (Rush Attack, Line Shot, Back Stab, Strong
## Summon, Summon). Any class can use it once it's unlocked (ProgressionTable
## unlocks), so builds mix them. Data only for now: its behaviour isn't built
## yet. Its power comes from ProgressionTable.ability_power().

enum Kind { ABILITY, SUMMON }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ABILITY
## Attribute its power scales with, whoever uses it: strength, agility, focus
## or memes (Player.attributes).
@export var scaling_stat: StringName = &"strength"
## Only usable while dual wielding (two dual-wieldable melee weapons equipped;
## Player.is_dual_wielding()), even once unlocked.
@export var requires_dual_wield: bool = false

@export_group("Summons")
## Summons out at once = summon_count_base, plus one per memes_per_extra_summon
## points of memes above ProgressionTable.base_stat, up to summon_count_max.
## Leave summon_count_max at 0 for abilities that don't summon.
@export var summon_count_base: int = 0
@export var memes_per_extra_summon: int = 0
@export var summon_count_max: int = 0
## Memes needed for each upgrade tier, lowest first (tier = how many reached).
@export var summon_upgrade_thresholds: PackedInt32Array = PackedInt32Array()

## Free text for tuning: which numbers are placeholders, what's undecided.
@export_multiline var notes: String = ""
