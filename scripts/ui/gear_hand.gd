class_name GearHand
extends RefCounted
## The thing held on the cursor while the inventory and character screens are
## open, and the moves it makes between their slots. Click a filled slot to pick
## up what's in it; click a slot it fits to put it there, picking up whatever
## was there (so a swap leaves the old piece on the cursor); click a bag square
## to put it in that square (swapping the same way if it's taken). Each pick-up or swap can be undone one step at a time (undo():
## Esc / Cancel, or clicking off the slots): the swapped piece goes back and the
## held one returns to the cursor, then the held one goes back where it came
## from. Putting the held piece down with the cursor left empty finishes the
## move (nothing left to undo).
##
## Slots: MAIN, SECONDARY, QUICK[i] (quick-access items), or an ArmorData.Slot
## (int) for worn gear. The bag is the player's weapon_bag (weapons, armour)
## plus the carried stacks that aren't quick slotted.

signal changed

const MAIN := &"main"
const SECONDARY := &"secondary"
const QUICK: Array[StringName] = [&"quick_0", &"quick_1"]
## Squares in the bag (more appear if it ever holds more than this).
const BAG_SLOTS := 24

## A MeleeWeaponData, WeaponData, ArmorData or ItemStack, or null.
var held: Resource = null

var _player: Player
## Snapshots of the gear before each step of the current move, newest last.
var _undo: Array[Dictionary] = []


func _init(player: Player) -> void:
	_player = player


## What's in a slot (null = empty).
func content(slot: Variant) -> Resource:
	if slot is int:
		return _player.armor.get(slot)
	match slot:
		MAIN:
			return _player.melee_weapon
		SECONDARY:
			return _player.secondary_weapon()
	return _player.quick_items[QUICK.find(slot)]


## Whether `piece` can go in `slot`. Rings and trinkets fit either of their pair.
func fits(slot: Variant, piece: Resource) -> bool:
	if slot is int:
		var armor := piece as ArmorData
		return armor != null and _armor_group(armor.slot) == _armor_group(slot)
	match slot:
		MAIN:
			return _player.can_equip_main(piece)
		SECONDARY:
			if piece is WeaponData:
				return true
			# A second blade needs a dual-wieldable main weapon to pair with.
			var blade := piece as MeleeWeaponData
			var main := _player.melee_weapon
			return blade != null and blade.dual_wieldable and main != null and main.dual_wieldable
	return piece is ItemStack


## Why `piece` can't go in `slot` (fits() is false), for a HUD message.
func why_not(slot: Variant, piece: Resource) -> String:
	var piece_name := (piece as ItemStack).item.display_name if piece is ItemStack \
			else String(piece.get(&"display_name"))
	piece_name = piece_name.to_upper()
	if slot is int:
		if piece is ArmorData:
			return "%s GOES IN THE %s SLOT" % [piece_name, _slot_name((piece as ArmorData).slot)]
		return "ONLY CLOTHES AND ACCESSORIES GO THERE"
	match slot:
		MAIN:
			return "GUNS GO IN THE SECONDARY SLOT" if piece is WeaponData else "ONLY MELEE WEAPONS GO IN MAIN"
		SECONDARY:
			var blade := piece as MeleeWeaponData
			if blade == null:
				return "ONLY A GUN OR A SECOND BLADE GOES IN SECONDARY"
			if not blade.dual_wieldable:
				return "%s CAN'T BE DUAL WIELDED" % piece_name
			var main := _player.melee_weapon
			if main == null:
				return "EQUIP A MAIN WEAPON FIRST TO DUAL WIELD"
			return "%s CAN'T BE DUAL WIELDED: PUT %s IN MAIN" % [main.display_name.to_upper(), piece_name]
	return "ONLY ITEMS GO IN QUICK SLOTS"


## The bag by square (null = empty), at least BAG_SLOTS long: pieces stay in
## the square they were put in (Player.bag_layout). Brings the layout up to
## date first: pieces no longer in the bag (equipped, used up, held) leave
## their squares, and new ones (loot) take the first empty square.
func bag() -> Array[Resource]:
	# What belongs in the bag: unequipped weapons and armour, and the carried
	# stacks that aren't quick slotted. Duplicates (two of the same weapon) count.
	var loose: Array[Resource] = _player.weapon_bag.duplicate()
	for stack: ItemStack in _player.inventory:
		if stack != held and not _player.quick_items.has(stack):
			loose.append(stack)
	var layout := _player.bag_layout
	if layout.size() < BAG_SLOTS:
		layout.resize(BAG_SLOTS)
	for i in layout.size():
		if layout[i] != null and loose.has(layout[i]):
			loose.erase(layout[i])
		else:
			layout[i] = null
	for piece: Resource in loose:
		var empty := layout.find(null)
		if empty < 0:
			layout.append(piece)
		else:
			layout[empty] = piece
	return layout


## Picks up from, or puts the held piece into, a slot. False when the held
## piece doesn't fit there.
func click_slot(slot: Variant) -> bool:
	var there := content(slot)
	if held == null:
		if there != null:
			_snapshot()
			_put(slot, null)
			held = there
			changed.emit()
		return true
	if not fits(slot, held):
		return false
	_snapshot()
	var placing := held
	held = there
	_put(slot, placing)
	if held == null:
		_undo.clear()
	changed.emit()
	return true


## Clicks bag square `index`: puts the held piece in that square (picking up
## what was there, if anything; an empty square finishes the move), or with
## nothing held picks up what's in it.
func click_bag(index: int) -> void:
	var layout := bag()
	var there := layout[index]
	if held == null and there == null:
		return
	_snapshot()
	if there != null and not there is ItemStack:
		_player.weapon_bag.erase(there)
	if held != null and not held is ItemStack:
		_player.weapon_bag.append(held)
	layout[index] = held
	held = there
	if held == null:
		_undo.clear()
	_player.progress_changed.emit()
	changed.emit()


## Takes back the last step. False when nothing is held (nothing to undo).
func undo() -> bool:
	if _undo.is_empty():
		return false
	_restore(_undo.pop_back())
	changed.emit()
	return true


## Takes back every step of the move in progress (closing the screens).
func undo_all() -> void:
	if _undo.is_empty():
		return
	_restore(_undo[0])
	_undo.clear()
	changed.emit()


func _put(slot: Variant, piece: Resource) -> void:
	if slot is int:
		_player.set_armor(slot, piece as ArmorData)
		return
	match slot:
		MAIN:
			_player.set_weapon_slots(piece as MeleeWeaponData, _player.secondary_weapon())
		SECONDARY:
			_player.set_weapon_slots(_player.melee_weapon, piece)
		_:
			_player.set_quick_item(QUICK.find(slot), piece as ItemStack)


func _snapshot() -> void:
	_undo.append({
		melee = _player.melee_weapon,
		secondary = _player.secondary_weapon(),
		bag = _player.weapon_bag.duplicate(),
		layout = _player.bag_layout.duplicate(),
		armor = _player.armor.duplicate(),
		quick = _player.quick_items.duplicate(),
		quick_kinds = _player.quick_item_kinds.duplicate(),
		held = held,
	})


func _restore(snapshot: Dictionary) -> void:
	_player.weapon_bag.assign(snapshot.bag)
	_player.bag_layout.assign(snapshot.layout)
	_player.armor.assign(snapshot.armor)
	_player.quick_items.assign(snapshot.quick)
	_player.quick_item_kinds.assign(snapshot.quick_kinds)
	held = snapshot.held
	# Last: it redraws the HUD and models from everything above.
	_player.set_weapon_slots(snapshot.melee, snapshot.secondary)


static func _slot_name(slot: ArmorData.Slot) -> String:
	return ArmorData.Slot.find_key(_armor_group(slot)).trim_suffix("_1")


## Ring and trinket slots come in pairs that take the same pieces.
static func _armor_group(slot: ArmorData.Slot) -> int:
	match slot:
		ArmorData.Slot.RING_2:
			return ArmorData.Slot.RING_1
		ArmorData.Slot.TRINKET_2:
			return ArmorData.Slot.TRINKET_1
	return slot
