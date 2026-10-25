class_name MeleeWeaponData
extends Resource
## A melee weapon: bats, swords, pipes... all melee weapons share this class,
## its swing combo and its guard (Block). Its model is held in the right hand
## (or the left, as the off-hand of a dual-wield pair), built in the grip
## convention of res://scenes/bat.tscn (grip at the origin, the weapon extending
## along +Y) so swings, trails and hitboxes fit.
##
## Slots: every melee weapon fits the main slot. A dual_wieldable one also fits
## the secondary slot (where the gun normally goes), but only next to another
## dual_wieldable main weapon: the two are then wielded together (Player.
## is_dual_wielding()), still attacking with the normal combo in action mode and
## enabling dual-wield energy abilities (EnergyAbility.requires_dual_wield).

@export var display_name: String = ""
## Flavour/help text shown under the gear on the status screen.
@export_multiline var description: String = ""
## Square picture for the HUD loadout row and status screen. Defaults to a placeholder.
@export var icon: Texture2D = preload("res://textures/ui/icons/placeholder_melee.png")
@export var model: PackedScene
## Weapon type for the small attribute bonus on its hits
## (ProgressionTable.weapon_stats): melee (strength), dual_melee (agility) or
## meme (memes).
@export var weapon_kind: StringName = &"melee"
## Can go in the secondary slot and pair with another dual-wieldable weapon.
@export var dual_wieldable: bool = false
## Blade tip along +Y in the model (m, before the player's scale): where the
## swing trail is drawn to.
@export var trail_tip: float = 0.47
