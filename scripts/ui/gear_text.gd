class_name GearText
## Description-panel text for weapons and items, shared by the status screen,
## the inventory and the loot window: the item's own description plus its
## real numbers on a second line.


static func melee(player: Player) -> String:
	var attack := melee_damage(player)
	return join(player.melee_weapon.description, "ATTACK %d" % attack if attack > 0 else "")


static func gun(weapon: WeaponData) -> String:
	var damage := weapon.shot.damage if weapon.shot != null else 0
	return join(weapon.description, "DAMAGE %d   RANGE %dM" % [damage, roundi(weapon.effective_range)])


## carried: append how many the player holds (inventory) rather than the stack size.
static func item(stack: ItemStack, carried := true) -> String:
	var effects := PackedStringArray()
	if stack.item.heal_amount > 0:
		effects.append("RESTORES %d HP" % stack.item.heal_amount)
	if stack.item.stamina_restore > 0.0:
		effects.append("RESTORES %d ENERGY" % roundi(stack.item.stamina_restore))
	effects.append(("CARRYING %d" if carried else "X%d") % stack.count)
	return join(stack.item.description, "   ".join(effects))


static func melee_damage(player: Player) -> int:
	return player.stats.light_combo[0].damage if not player.stats.light_combo.is_empty() else 0


static func join(text: String, extra: String) -> String:
	if text == "":
		return extra
	return text if extra == "" else text + "\n" + extra
