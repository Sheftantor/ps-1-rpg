class_name Leveling
## WoW-style progression maths, tuned by the Leveling group of PlayerStats:
## the XP each level needs, and the XP a kill is worth given the level gap.


## XP needed to go from `level` to the next one (0 at max_level).
static func xp_to_next(level: int, stats: PlayerStats) -> int:
	if level >= stats.max_level:
		return 0
	return stats.xp_first + stats.xp_growth * (level - 1)


## XP for killing an enemy of enemy_level: WoW's 45 + 5 x level, +5% per level
## the enemy is above you (up to max_bonus_levels), falling off linearly for
## weaker enemies to nothing at grey_gap levels below.
static func kill_xp(enemy_level: int, player_level: int, stats: PlayerStats) -> int:
	var base := float(stats.kill_xp_base + stats.kill_xp_per_level * enemy_level)
	var gap := enemy_level - player_level
	if gap >= 0:
		return roundi(base * (1.0 + stats.xp_bonus_per_level * mini(gap, stats.max_bonus_levels)))
	if -gap >= stats.grey_gap:
		return 0
	return roundi(base * (1.0 - float(-gap) / stats.grey_gap))
