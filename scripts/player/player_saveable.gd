class_name PlayerSaveable
extends Node
## Saves and restores its parent Player for SaveManager ("saveable" group).
## Built on Player.save_state()/load_state() (what AreaTravel carries between
## areas), plus position, facing, camera yaw, the melee weapon and armour.
## Resources are saved by path; an item or gear piece whose file has gone
## missing is skipped with a warning.

@onready var player: Player = get_parent() as Player


func _ready() -> void:
	add_to_group(&"saveable")
	# AreaTravel holds the save-orb checkpoint and the emptied loot sacks. It's
	# made on first use; make it now so it's saved and loaded with the player.
	AreaTravel.service.call_deferred()


func get_save_summary() -> Dictionary:
	return {level = player.level}


func get_save_data() -> Dictionary:
	var state := player.save_state()
	var inventory := []
	for stack: ItemStack in state.inventory:
		if stack.item != null:
			inventory.append([stack.item.resource_path, stack.count])
	var armor := {}
	for slot: ArmorData.Slot in player.armor:
		armor[str(slot)] = _path(player.armor[slot])
	var position := player.global_position
	return {
		position = [position.x, position.y, position.z],
		facing_yaw = player.get_node(^"Facing").rotation.y,
		camera_yaw = player.get_node(^"CameraRig").rotation.y,
		level = state.level,
		xp = state.xp,
		stat_points = state.stat_points,
		attributes = state.attributes,
		max_health = state.max_health,
		health = state.health,
		max_energy = state.max_stamina,
		energy = state.stamina,
		inventory = inventory,
		selected_item = state.selected_item,
		gun = _path(state.gun),
		melee_weapon = _path(player.melee_weapon),
		armor = armor,
	}


func apply_save_data(data: Dictionary) -> void:
	var current := player.save_state()
	var attributes: Dictionary[StringName, int] = {}
	for key: StringName in current.attributes:
		attributes[key] = current.attributes[key]
	var saved_attributes = data.get("attributes", {})
	if saved_attributes is Dictionary:
		for key in saved_attributes:
			attributes[StringName(key)] = int(saved_attributes[key])

	var inventory: Array[ItemStack] = []
	var saved_inventory = data.get("inventory", [])
	if saved_inventory is Array:
		for entry in saved_inventory:
			var item := _load(entry[0] if entry is Array and entry.size() == 2 else null) as ItemData
			if item != null:
				var stack := ItemStack.new()
				stack.item = item
				stack.count = int(entry[1])
				inventory.append(stack)

	var max_health := int(data.get("max_health", current.max_health))
	var max_energy := float(data.get("max_energy", current.max_stamina))
	player.load_state({
		level = int(data.get("level", current.level)),
		xp = int(data.get("xp", current.xp)),
		stat_points = int(data.get("stat_points", current.stat_points)),
		attributes = attributes,
		max_health = max_health,
		health = clampi(int(data.get("health", max_health)), 1, max_health),
		max_stamina = max_energy,
		stamina = clampf(float(data.get("energy", max_energy)), 0.0, max_energy),
		gun = _load(data.get("gun", "")) as WeaponData,
		inventory = inventory,
		selected_item = clampi(int(data.get("selected_item", 0)), 0, maxi(0, inventory.size() - 1)),
	})

	# Gear. Only the gun can change in play today; the melee weapon and armour
	# come from the loadout, so these restore the same pieces (the melee
	# weapon's hand model isn't rebuilt here).
	var melee := _load(data.get("melee_weapon", "")) as MeleeWeaponData
	if melee != null:
		player.melee_weapon = melee
	var saved_armor = data.get("armor")
	if saved_armor is Dictionary:
		player.armor.clear()
		for key in saved_armor:
			var piece := _load(saved_armor[key]) as ArmorData
			if piece != null:
				player.armor[int(key) as ArmorData.Slot] = piece

	var saved_position = data.get("position")
	if saved_position is Array and saved_position.size() == 3:
		player.global_position = Vector3(saved_position[0], saved_position[1], saved_position[2])
		player.velocity = Vector3.ZERO
	var facing := player.get_node(^"Facing") as Node3D
	var camera_rig := player.get_node(^"CameraRig") as Node3D
	facing.rotation.y = float(data.get("facing_yaw", facing.rotation.y))
	camera_rig.rotation.y = float(data.get("camera_yaw", camera_rig.rotation.y))


static func _path(resource: Resource) -> String:
	return resource.resource_path if resource != null else ""


static func _load(path: Variant) -> Resource:
	if not path is String or path == "":
		return null
	if not ResourceLoader.exists(path):
		push_warning("PlayerSaveable: saved resource %s no longer exists" % path)
		return null
	return load(path)
