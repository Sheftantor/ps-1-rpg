class_name PlayerLoadout
extends Resource
## Starting skills, items and gear. Edit res://resources/player/player_loadout.tres.
## Inventory counts here are starting amounts; the player spends a copy.

@export var skills: Array[SkillData] = []
@export var inventory: Array[ItemStack] = []

@export_group("Equipment")
## Primary weapon, always equipped.
@export var melee_weapon: MeleeWeaponData
## Secondary weapon slot; usually empty until a gun is picked up.
@export var gun: WeaponData
@export var shirt: ArmorData
@export var neck: ArmorData
@export var arms: ArmorData
@export var belt: ArmorData
@export var pants: ArmorData
@export var shoes: ArmorData
@export_subgroup("Accessories")
@export var ring_1: ArmorData
@export var ring_2: ArmorData
@export var trinket_1: ArmorData
@export var trinket_2: ArmorData
@export var charm: ArmorData
