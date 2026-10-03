class_name WeaponData
extends Resource
## A gun the player can carry in the secondary weapon slot (the sword is always
## the primary). Fired from gun mode's time-stop targeting (GunAim state).

@export var display_name: String = ""
## Flavour/help text shown under the gear on the status screen.
@export_multiline var description: String = ""
## Square picture for the HUD loadout row and status screen. Defaults to a placeholder.
@export var icon: Texture2D = preload("res://textures/ui/icons/placeholder_gun.png")
## Model shown in the hand while drawn and spinning on the ground as a pickup.
@export var model: PackedScene
## Damage and knockback of one shot, delivered through the target's Hurtbox
## like a sword hit.
@export var shot: AttackData
## Enemies within this distance (m) can be targeted.
@export var lock_range: float = 20.0
## Shots within this distance (m) deal full damage; the reticle shows "in range"
## and gun mode's wire dome is drawn at this radius.
@export var effective_range: float = 8.0
## Damage multiplier for shots beyond effective_range.
@export_range(0.0, 1.0) var out_of_range_damage_scale: float = 0.25
## Stamina each queued shot costs in gun mode (refunded if the shot is undone).
@export var shot_energy_cost: float = 15.0
