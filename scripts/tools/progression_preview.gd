@tool
extends Node
## Editor preview of the energy-mode scaling (ProgressionTable): open
## res://scenes/tools/progression_preview.tscn, select this node, and pick a
## class and level in the Inspector. Report shows the final numbers (and they
## print to the Output panel). Press Refresh after editing the table's .tres.
## By default the build puts every stat point earned into the class's main
## stat; tick Custom Attributes to type your own values.

# By path, so the preview runs before the editor has registered the class names.
const TableScript := preload("res://scripts/progression/progression_table.gd")

@export_enum("warrior", "gunner", "sneak", "memer") var class_id: String = "warrior":
	set(value):
		class_id = value
		_refresh()
@export_range(1, 20) var level: int = 1:
	set(value):
		level = value
		_refresh()
@export var custom_attributes: bool = false:
	set(value):
		custom_attributes = value
		_refresh()
@export var strength: int = 10:
	set(value):
		strength = value
		_refresh()
@export var agility: int = 10:
	set(value):
		agility = value
		_refresh()
@export var focus: int = 10:
	set(value):
		focus = value
		_refresh()
@export var memes: int = 10:
	set(value):
		memes = value
		_refresh()
@export_tool_button("Refresh") var refresh_button: Callable = _refresh
## The final numbers (read only: it's rewritten on every change).
@export_multiline var report: String = ""


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	# Reload so edits to the table's .tres show up without restarting.
	var table: TableScript = ResourceLoader.load(TableScript.PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if table == null:
		report = "Couldn't load %s" % TableScript.PATH
		return
	var data: Resource = table.class_by_id(StringName(class_id))
	if data == null:
		report = "No class %s in the table" % class_id
		return
	var attributes := {}
	if custom_attributes:
		attributes = {strength = strength, agility = agility, focus = focus, memes = memes}
	report = table.report(data, level, attributes)
	print(report)
	notify_property_list_changed()
