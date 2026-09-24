extends CanvasLayer
## Temporary on-screen readout of player/enemy HP and states for combat testing.

const CONTROLS: String = "WASD move  Space jump  Shift dash  LMB light  RMB heavy  Tab/MMB lock-on  Esc free mouse"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var lines: PackedStringArray = [CONTROLS, ""]
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		var locked := player.lock_target.name if player.lock_target != null else "-"
		lines.append("Player  HP %d/%d  %s  lock: %s" % [
			player.health.current, player.health.max_health,
			Player.ActionState.find_key(player.action_state), locked,
		])
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var token := "  [attack turn]" if EnemyAttackCoordinator.is_holder(enemy) else ""
		lines.append("%s  HP %d/%d  %s%s" % [
			enemy.name, enemy.health.current, enemy.health.max_health,
			enemy.state_machine.current_name(), token,
		])
	_label.text = "\n".join(lines)
