class_name PlayerState
extends State
## Base for player states. Idle and Move are the neutral states that act on the
## input buffer; Dodge, the attacks and HitStun commit until they hand back.
## Block lasts while its input is held. HitStun and Dead can interrupt anything.

const IDLE: StringName = &"Idle"
const MOVE: StringName = &"Move"
const DODGE: StringName = &"Dodge"
const LIGHT_ATTACK: StringName = &"LightAttack"
const HEAVY_ATTACK: StringName = &"HeavyAttack"
const BLOCK: StringName = &"Block"
const HIT_STUN: StringName = &"HitStun"
const DEAD: StringName = &"Dead"

var player: Player:
	get:
		return actor as Player


## Whether the hurtbox ignores hits right now.
func is_invulnerable() -> bool:
	return false


## Whether an incoming hit is guarded instead of landing.
func is_blocking() -> bool:
	return false


func stamina_regen_scale() -> float:
	return 1.0


## Idle/Move: start whatever is waiting in the input buffer, or Block while its
## input is held. Returns true if this changed state.
func try_neutral_action() -> bool:
	match player.peek_buffer():
		Player.ACTION_LIGHT:
			player.consume_buffer()
			transition_to(LIGHT_ATTACK, {"combo_index": 0})
			return true
		Player.ACTION_HEAVY:
			player.consume_buffer()
			transition_to(HEAVY_ATTACK)
			return true
		Player.ACTION_DODGE:
			# Not enough stamina: leave it buffered in case it regenerates in time.
			if player.can_dodge():
				player.consume_buffer()
				transition_to(DODGE)
				return true
		Player.ACTION_JUMP:
			# Kept buffered while airborne so a press just before landing still jumps.
			if player.is_on_floor():
				player.consume_buffer()
				player.velocity.y = player.stats.jump_velocity
		Player.ACTION_SKILL:
			if player.start_skill(player.consume_buffer() as SkillData):
				return true
		Player.ACTION_ITEM:
			player.use_item(player.consume_buffer() as ItemStack)
	if player.wants_block():
		transition_to(BLOCK)
		return true
	return false


## Where committed states hand back to: Move while a direction is held, else Idle.
func neutral_state() -> StringName:
	return MOVE if player.get_move_direction() != Vector3.ZERO else IDLE
