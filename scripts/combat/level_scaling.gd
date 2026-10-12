class_name LevelScaling
## Level-gap maths for enemy health and damage (gap = enemy level - player
## level), tuned in res://resources/combat_tuning.tres.

const TUNING: CombatTuning = preload("res://resources/combat_tuning.tres")


static func health_multiplier(gap: int) -> float:
	if gap > 0:
		return 1.0 + TUNING.health_gain_per_level_above * gap
	return maxf(TUNING.health_multiplier_floor, 1.0 + TUNING.health_loss_per_level_below * gap)


static func damage_multiplier(gap: int) -> float:
	if gap > 0:
		return 1.0 + TUNING.damage_gain_per_level_above * gap
	return maxf(TUNING.damage_multiplier_floor, 1.0 + TUNING.damage_loss_per_level_below * gap)


## Max health of a base-stat, ungeared player at `level` (Player._level_up adds
## health_per_level each level from the starting level).
static func player_max_health_at(level: int, stats: PlayerStats) -> int:
	return stats.max_health + stats.health_per_level * (level - stats.level)


## Damage of one basic bat swing (the BatSwing state uses stats.light_combo[0]).
static func bat_damage(stats: PlayerStats) -> int:
	return stats.light_combo[0].damage if not stats.light_combo.is_empty() else 1
