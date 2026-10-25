# Prints the final energy-mode numbers from the ProgressionTable
# (res://resources/progression/progression_table.tres):
#   godot --headless --path . -s res://scripts/tools/print_progression.gd
#   godot --headless --path . -s res://scripts/tools/print_progression.gd -- warrior 10
#   godot --headless --path . -s res://scripts/tools/print_progression.gd -- gunner 10 agi=18 foc=14
# No arguments: every class at levels 1, 5, 10, 15 and 20. With a starting
# class id (warrior, gunner, sneak, memer) and/or a level: just those. Without
# attributes the build puts every stat point earned so far into the class's
# main stat; str= agi= foc= mem= set your own (unset ones stay at base).
extends SceneTree

const STAT_KEYS := {"str": &"strength", "agi": &"agility", "foc": &"focus", "mem": &"memes"}


func _initialize() -> void:
	var table := ProgressionTable.load_default()
	var only_class := &""
	var levels: Array[int] = [1, 5, 10, 15, 20]
	var attributes := {}
	for arg: String in OS.get_cmdline_user_args():
		if "=" in arg:
			var key := arg.get_slice("=", 0)
			if STAT_KEYS.has(key):
				if attributes.is_empty():
					attributes = {strength = table.base_stat, agility = table.base_stat,
							focus = table.base_stat, memes = table.base_stat}
				attributes[STAT_KEYS[key]] = int(arg.get_slice("=", 1))
		elif arg.is_valid_int():
			levels = [int(arg)]
		else:
			only_class = StringName(arg)
	for data: ClassData in table.classes:
		if only_class != &"" and data.id != only_class:
			continue
		for level in levels:
			print(table.report(data, level, attributes))
			print("")
	quit()
