class_name EnemyLevelBadge
extends Control
## Colour-coded level number on an enemy's floating health readout: a WoW-style
## "can I beat this thing" indicator. Shows the enemy's level, the digits
## coloured (black outline kept) by gap = enemy level - player level: green at or below
## safe_threshold (trivial), red at or above danger_threshold (dangerous),
## yellow in between (a fair fight). Wires itself up: finds its Enemy by walking
## up the tree and the player through the "player" group, and recolours live on
## Player.level_changed, so badges already on screen update mid-fight.
## Lives in Canvas/Root of res://scenes/enemy_health_bar.tscn, with a child
## Label named LevelLabel (style it in the editor). Thresholds and colours are
## placeholders to tune in the inspector.

## Level gap (enemy - player) at or above which the badge goes red.
@export var danger_threshold: int = 3
## Level gap at or below which the badge goes green.
@export var safe_threshold: int = -3

@export_group("Colors")
@export var safe_color: Color = Color(0.25, 0.85, 0.25)
@export var even_color: Color = Color(0.95, 0.85, 0.15)
@export var danger_color: Color = Color(0.95, 0.22, 0.2)

var _enemy: Enemy = null
var _player: Player = null
## The colour currently shown.
var _fill: Color = even_color

@onready var level_label: Label = $LevelLabel


func _ready() -> void:
	var node := get_parent()
	while node != null and not node is Enemy:
		node = node.get_parent()
	_enemy = node as Enemy
	visible = _enemy != null
	refresh()
	# Once the whole level has loaded the player is in the tree.
	_find_player.call_deferred()


func _process(_delta: float) -> void:
	# Fallback for a player that joins the tree later than the level.
	if not _find_player():
		return
	set_process(false)


func _find_player() -> bool:
	if _player != null:
		return true
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return false
	_player.level_changed.connect(refresh.unbind(1))
	refresh()
	return true


## Re-reads both levels and redraws.
func refresh() -> void:
	if _enemy != null:
		update_badge(_enemy.level(), _player.level if _player != null else _enemy.level())


func update_badge(enemy_level: int, player_level: int) -> void:
	level_label.text = str(enemy_level)
	var gap := enemy_level - player_level
	if gap <= safe_threshold:
		_fill = safe_color
	elif gap >= danger_threshold:
		_fill = danger_color
	else:
		_fill = even_color
	# The digits are white, so modulate tints them; the black outline stays black.
	level_label.modulate = _fill
