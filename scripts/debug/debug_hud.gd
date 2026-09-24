extends CanvasLayer
## Temporary on-screen readout of player/enemy HP and states for combat testing.

const CONTROLS: String = "WASD move  Space jump  Shift dodge  LMB light  RMB heavy  Q block  Tab/MMB lock-on  Esc free mouse\n" \
		+ "Hold F: command menu (W/S or arrows, Enter/Space pick, Backspace back)  K: hurt self"

@onready var _label: Label = $Label


func _process(_delta: float) -> void:
	var lines: PackedStringArray = [CONTROLS, ""]
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		var locked: String = String(player.lock_target.name) if player.lock_target != null else "-"
		lines.append("Player  HP %d/%d  ST %d/%d  %s%s  lock: %s" % [
			player.health.current, player.health.max_health,
			roundi(player.stamina.current), roundi(player.stamina.maximum),
			player.state_machine.current_name(), "  [menu]" if player.command_menu.is_open else "",
			locked,
		])
		lines.append("Last hit: %s" % player.last_hit_result)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		var token := "  [attack turn]" if EnemyAttackCoordinator.is_holder(enemy) else ""
		lines.append("%s  HP %d/%d  %s%s" % [
			enemy.name, enemy.health.current, enemy.health.max_health,
			enemy.state_machine.current_name(), token,
		])
	_label.text = "\n".join(lines)
