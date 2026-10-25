class_name ProgressionTable
extends Resource
## Energy mode is the ultimate: a meter that charges as fights get crazier,
## then an energy ability or summon is unleashed. Classes are starting points,
## not locks: abilities and summons unlock in play (the unlock table) and mix
## with stats into builds (a stealth ranged build: a Gunner with Back Stab and
## agility). Its level, stat and unlock scaling, all as data:
## res://resources/progression/progression_table.tres (edit in the Inspector).
## The player reads it for stat points, health / energy per point, the small
## weapon bonus on every hit, and unlocks (Player); enemy damage scaling reads
## expected_max_health() (LevelScaling). The abilities' behaviour isn't built.
## Preview any class / level: res://scenes/tools/progression_preview.tscn, or
##   godot --headless --path . -s res://scripts/tools/print_progression.gd

const PATH := "res://resources/progression/progression_table.tres"

## Index 0 = level 1. Levels past the last row use the last row.
@export var levels: Array[LevelRow] = []
@export var classes: Array[ClassData] = []
## Every ability and summon, in display order.
@export var abilities: Array[EnergyAbility] = []
@export var unlocks: Array[UnlockEntry] = []

@export_group("Stat Rules")
## Attribute value that gives no bonus (every attribute starts at 10).
@export var base_stat: int = 10
## Abilities: power x (1 + this x points of the ability's stat above base_stat). Strong.
@export var ability_power_per_stat_point: float = 0.06
## Weapon type -> attribute its small damage bonus comes from.
@export var weapon_stats: Dictionary[StringName, StringName] = {
	&"melee": &"strength", &"gun": &"focus", &"dual_melee": &"agility", &"meme": &"memes",
}
## Weapons: damage x (1 + this x points above base_stat), capped at
## 1 + weapon_bonus_cap. Small; base weapon damage itself is never changed.
@export var weapon_bonus_per_stat_point: float = 0.01
@export var weapon_bonus_cap: float = 0.25
## Free text for tuning: which numbers are placeholders, what's undecided.
@export_multiline var notes: String = ""


static func load_default() -> ProgressionTable:
	return load(PATH) as ProgressionTable


func row(level: int) -> LevelRow:
	if levels.is_empty():
		return null
	return levels[clampi(level - 1, 0, levels.size() - 1)]


func max_level() -> int:
	return levels.size()


func class_by_id(id: StringName) -> ClassData:
	for data: ClassData in classes:
		if data.id == id:
			return data
	return null


func ability_by_id(id: StringName) -> EnergyAbility:
	for ability: EnergyAbility in abilities:
		if ability.id == id:
			return ability
	return null


# --- Levels and stats -----------------------------------------------------------

## Stat points gained from level 1 up to and including `level`.
func total_stat_points(level: int) -> int:
	var total := 0
	for i in mini(level, levels.size()):
		total += levels[i].stat_points
	return total


## Max health at `level` for a character with base_health at from_level who
## spent every later level's stat points as they came (Player.spend_stat_point
## rounds each point's gain).
func expected_max_health(base_health: int, from_level: int, level: int) -> int:
	var total := base_health
	for at in range(from_level + 1, level + 1):
		total += row(at).stat_points * roundi(health_per_point(at))
	return total


func health_per_point(level: int) -> float:
	return row(level).health_per_point


func energy_per_point(level: int) -> float:
	return row(level).energy_per_point


## Energy-mode meter charge multiplier at `level` (1 = normal).
func energy_fill_rate(level: int) -> float:
	return row(level).energy_fill_rate


## Bonus from an attribute above base_stat at `per_point` per point (never below 1).
func stat_bonus(value: int, per_point: float) -> float:
	return 1.0 + per_point * maxi(0, value - base_stat)


## Final power multiplier of `ability` at `level` with the player's attributes
## ({strength = 12, ...}): the level row's multiplier times the bonus from the
## ability's own stat, whichever class uses it.
func ability_power(ability: EnergyAbility, level: int, attributes: Dictionary) -> float:
	var level_power: float = row(level).ability_power.get(ability.id, 1.0)
	return level_power * stat_bonus(int(attributes.get(ability.scaling_stat, base_stat)), ability_power_per_stat_point)


## Small damage multiplier for a weapon type (melee, gun, dual_melee) from its
## attribute. Apply it on top of a weapon's damage; the weapon's own number
## stays as it is.
func weapon_multiplier(weapon_kind: StringName, attributes: Dictionary) -> float:
	var stat: StringName = weapon_stats.get(weapon_kind, &"")
	if stat == &"":
		return 1.0
	var bonus := stat_bonus(int(attributes.get(stat, base_stat)), weapon_bonus_per_stat_point)
	return minf(bonus, 1.0 + weapon_bonus_cap)


func weapon_damage(base_damage: int, weapon_kind: StringName, attributes: Dictionary) -> int:
	return maxi(1, roundi(base_damage * weapon_multiplier(weapon_kind, attributes)))


## Summons out at once from `ability` with this many memes (0 if it doesn't summon).
func summon_count(ability: EnergyAbility, memes: int) -> int:
	if ability.summon_count_max <= 0:
		return 0
	var extra := 0
	if ability.memes_per_extra_summon > 0:
		extra = maxi(0, memes - base_stat) / ability.memes_per_extra_summon
	return mini(ability.summon_count_base + extra, ability.summon_count_max)


## Upgrade tier of a summon: how many of its thresholds `memes` reaches.
func summon_upgrade_tier(ability: EnergyAbility, memes: int) -> int:
	var tier := 0
	for threshold in ability.summon_upgrade_thresholds:
		if memes >= threshold:
			tier += 1
	return tier


# --- Unlocks --------------------------------------------------------------------

func unlock_for(ability: EnergyAbility) -> UnlockEntry:
	for entry: UnlockEntry in unlocks:
		if entry.ability == ability:
			return entry
	return null


## Whether `ability` is available to a character who started as `data`, at
## `level`, with these attributes. Abilities with no unlock row are never available.
func is_unlocked(ability: EnergyAbility, data: ClassData, level: int, attributes: Dictionary) -> bool:
	var entry := unlock_for(ability)
	if entry == null:
		return false
	if data != null and entry.start_classes.has(data.id):
		return true
	return level >= entry.min_level and int(attributes.get(&"memes", base_stat)) >= entry.min_memes


func unlocked_abilities(data: ClassData, level: int, attributes: Dictionary) -> Array[EnergyAbility]:
	var out: Array[EnergyAbility] = []
	for ability: EnergyAbility in abilities:
		if is_unlocked(ability, data, level, attributes):
			out.append(ability)
	return out


## What unlocks `ability` for a character who didn't start with it, as text.
func unlock_requirement(ability: EnergyAbility) -> String:
	var entry := unlock_for(ability)
	if entry == null:
		return "no unlock row"
	var parts := PackedStringArray()
	if entry.min_level > 0:
		parts.append("level %d" % entry.min_level)
	if entry.min_memes > 0:
		parts.append("%d memes" % entry.min_memes)
	return " + ".join(parts) if not parts.is_empty() else "always"


# --- Preview ------------------------------------------------------------------

## A build for previews: every stat at base_stat, with all the stat points
## earned by `level` put into the class's main stat.
func preview_attributes(data: ClassData, level: int) -> Dictionary:
	var attributes := {strength = base_stat, agility = base_stat, focus = base_stat, memes = base_stat}
	attributes[data.main_stat] = base_stat + total_stat_points(level)
	return attributes


## The final numbers for a character who started as `data`, at `level`, as text
## for the preview panel and the print tool: every ability and summon (unlocked
## or not, and what unlocks it). `attributes` defaults to preview_attributes().
func report(data: ClassData, level: int, attributes: Dictionary = {}) -> String:
	if attributes.is_empty():
		attributes = preview_attributes(data, level)
	var r := row(level)
	var lines := PackedStringArray()
	lines.append("Started as %s, level %d  (main stat %s)" % [data.display_name, level, data.main_stat])
	lines.append("  attributes: str %d  agi %d  foc %d  mem %d" % [attributes.strength, attributes.agility, attributes.focus, attributes.memes])
	lines.append("  stat points: +%d this level, %d total" % [r.stat_points, total_stat_points(level)])
	lines.append("  per stat point: +%.1f health  +%.1f energy" % [r.health_per_point, r.energy_per_point])
	lines.append("  energy-mode meter fill: x%.2f" % r.energy_fill_rate)
	for ability: EnergyAbility in abilities:
		var unlocked := is_unlocked(ability, data, level, attributes)
		var stat := ability.scaling_stat
		var line := "  %s %s: x%.2f  (level x%.2f, %s %d -> x%.2f)" % [
				"[x]" if unlocked else "[ ]", ability.display_name, ability_power(ability, level, attributes),
				r.ability_power.get(ability.id, 1.0), stat, attributes.get(stat, base_stat),
				stat_bonus(int(attributes.get(stat, base_stat)), ability_power_per_stat_point)]
		if ability.summon_count_max > 0:
			line += "  %d out, tier %d" % [summon_count(ability, attributes.memes), summon_upgrade_tier(ability, attributes.memes)]
		if ability.requires_dual_wield:
			line += "  (needs dual wield)"
		if not unlocked:
			line += "  -- unlocks at " + unlock_requirement(ability)
		lines.append(line)
	lines.append("  weapon damage (%s): x%.2f  (e.g. 15 -> %d)" % [data.weapon_kind,
			weapon_multiplier(data.weapon_kind, attributes), weapon_damage(15, data.weapon_kind, attributes)])
	if r.notes != "":
		lines.append("  notes: " + r.notes)
	return "\n".join(lines)
