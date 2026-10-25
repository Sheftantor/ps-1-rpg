class_name ClassData
extends Resource
## A player class: a starting point, not a lock. It sets the main attribute the
## starting build leans on, the weapons it starts with and its signature
## ability; everything else is unlocked in play (ProgressionTable unlocks) and
## mixed into the build. Files live in res://resources/progression/classes/.

@export var id: StringName = &""
@export var display_name: String = ""
## Attribute the starting build puts its points into (the preview assumes all
## of them go here): strength, agility, focus or memes.
@export var main_stat: StringName = &"strength"
## Weapon type it starts with, for ProgressionTable.weapon_multiplier(): melee,
## gun, dual_melee or meme.
@export var weapon_kind: StringName = &"melee"
## What it fights with, for the status screen and for whoever builds the abilities.
@export var weapons: String = ""
## Signature ability, unlocked from the start (see the unlock table).
@export var ability: EnergyAbility
## Starting kit, replacing PlayerLoadout's weapons when set: the main-slot
## melee weapon, and the secondary (a gun, or a dual-wieldable melee weapon
## to dual wield with a dual-wieldable main).
@export var starting_main: MeleeWeaponData
@export var starting_secondary: Resource
## Free text for tuning: which numbers are placeholders, what's undecided.
@export_multiline var notes: String = ""
