class_name PlayerLoadout
extends Resource
## What the command menu offers. Edit res://resources/player/player_loadout.tres.
## Inventory counts here are starting amounts; the player spends a copy.

@export var skills: Array[SkillData] = []
@export var inventory: Array[ItemStack] = []
