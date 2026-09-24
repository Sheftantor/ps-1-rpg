class_name SkillData
extends Resource
## A command-menu skill. Picking it spends stamina and sends the player into
## `state` with {"attack": attack} as the transition message (HeavyAttack uses
## that attack in place of the regular heavy).

@export var display_name: String = ""
@export var icon: Texture2D
@export var stamina_cost: float = 0.0
## Name of the player state to enter (a child of the player's StateMachine).
@export var state: StringName = &"HeavyAttack"
@export var attack: AttackData
