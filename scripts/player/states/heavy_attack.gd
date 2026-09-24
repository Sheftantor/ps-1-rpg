extends AttackState
## Slow, heavy swing with no cancels: it plays out through recovery. Skills reuse
## this state with their own AttackData passed as msg["attack"].

const WINDUP_COLOR: Color = Color(1.0, 0.55, 0.1, 0.6)


func enter(msg: Dictionary) -> void:
	var skill_attack := msg.get("attack") as AttackData
	begin(skill_attack if skill_attack != null else player.stats.heavy_attack)


func physics_update(delta: float) -> void:
	var finished := advance(delta)
	if elapsed < attack.startup_time:
		player.state_flash = Color(WINDUP_COLOR, WINDUP_COLOR.a * elapsed / attack.startup_time)
	if finished:
		transition_to(neutral_state())
