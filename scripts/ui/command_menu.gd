class_name CommandMenu
extends CanvasLayer
## Kingdom Hearts-style command menu: hold command_menu to open it. It never
## pauses; the game keeps running underneath, so anything attacking you still
## can. Picks go out as signals, and the Player feeds them into the same input
## buffer the direct buttons use. Navigation is polled in _process so menu inputs
## don't need a focused Control.

signal attack_selected
signal skill_selected(skill: SkillData)
signal item_selected(stack: ItemStack)

enum Page { MAIN, SKILLS, ITEMS }

const MAIN_ENTRIES: Array[String] = ["Attack", "Skills", "Items"]
const ICON_SIZE: Vector2 = Vector2(20.0, 20.0)
const COLOR_NORMAL: Color = Color(0.9, 0.9, 0.9)
const COLOR_SELECTED: Color = Color(1.0, 0.85, 0.3)
const COLOR_DISABLED: Color = Color(0.45, 0.45, 0.45)

## How long command_menu must be held before the menu opens.
@export var hold_time: float = 0.2

## False keeps the menu shut (e.g. while dead).
var enabled: bool = true
var is_open: bool = false

var _skills: Array[SkillData] = []
var _inventory: Array[ItemStack] = []
## Given a SkillData or ItemStack, returns whether it can be picked right now.
var _can_use: Callable = Callable()

var _page: Page = Page.MAIN
var _cursor: int = 0
var _hold_timer: float = 0.0
## After opening or closing, the button must be released before it can open again.
var _wait_for_release: bool = false

var _panel: PanelContainer
var _title: Label
var _rows: VBoxContainer
var _row_labels: Array[Label] = []
var _row_texts: PackedStringArray = []
var _row_entries: Array[Resource] = []


func _ready() -> void:
	_build_panel()
	_panel.visible = false


func setup(skills: Array[SkillData], inventory: Array[ItemStack], can_use: Callable) -> void:
	_skills = skills
	_inventory = inventory
	_can_use = can_use


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	_wait_for_release = true
	_show_page(Page.MAIN, 0)
	_panel.visible = true


func close() -> void:
	# Also called on every hit, so a half-finished hold has to start over too.
	_wait_for_release = true
	if not is_open:
		return
	is_open = false
	_panel.visible = false


func _process(delta: float) -> void:
	_update_hold(delta)
	if not is_open:
		return
	if Input.is_action_just_pressed(&"menu_up"):
		_move_cursor(-1)
	elif Input.is_action_just_pressed(&"menu_down"):
		_move_cursor(1)
	if Input.is_action_just_pressed(&"menu_confirm"):
		_confirm()
	elif Input.is_action_just_pressed(&"menu_cancel"):
		_back()
	if is_open:
		_refresh_rows()


func _update_hold(delta: float) -> void:
	if not Input.is_action_pressed(&"command_menu"):
		_hold_timer = 0.0
		_wait_for_release = false
		return
	if is_open:
		if Input.is_action_just_pressed(&"command_menu"):
			close()
		return
	if _wait_for_release or not enabled:
		return
	_hold_timer += delta
	if _hold_timer >= hold_time:
		open()


func _move_cursor(step: int) -> void:
	if _row_entries.size() > 0:
		_cursor = posmod(_cursor + step, _row_entries.size())


func _confirm() -> void:
	match _page:
		Page.MAIN:
			match _cursor:
				0:
					close()
					attack_selected.emit()
				1:
					_show_page(Page.SKILLS, 0)
				2:
					_show_page(Page.ITEMS, 0)
		Page.SKILLS:
			if _row_entries.is_empty() or not _is_usable(_row_entries[_cursor]):
				return
			close()
			skill_selected.emit(_row_entries[_cursor] as SkillData)
		Page.ITEMS:
			if _row_entries.is_empty() or not _is_usable(_row_entries[_cursor]):
				return
			close()
			item_selected.emit(_row_entries[_cursor] as ItemStack)


func _back() -> void:
	match _page:
		Page.MAIN:
			close()
		Page.SKILLS:
			_show_page(Page.MAIN, 1)
		Page.ITEMS:
			_show_page(Page.MAIN, 2)


func _show_page(page: Page, cursor: int) -> void:
	_page = page
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_labels.clear()
	_row_texts.clear()
	_row_entries.clear()

	match page:
		Page.MAIN:
			_title.text = "Command"
			for entry: String in MAIN_ENTRIES:
				_add_row(entry, null, null)
		Page.SKILLS:
			_title.text = "Skills"
			for skill: SkillData in _skills:
				_add_row("%s  %d ST" % [skill.display_name, roundi(skill.stamina_cost)], skill.icon, skill)
		Page.ITEMS:
			_title.text = "Items"
			for stack: ItemStack in _inventory:
				_add_row("%s  x%d" % [stack.item.display_name, stack.count], stack.item.icon, stack)
	if _row_entries.is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		empty.modulate = COLOR_DISABLED
		_rows.add_child(empty)
	_cursor = clampi(cursor, 0, maxi(_row_entries.size() - 1, 0))
	_refresh_rows()


func _add_row(text: String, icon: Texture2D, entry: Resource) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon
		icon_rect.custom_minimum_size = ICON_SIZE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon_rect)
	var label := Label.new()
	row.add_child(label)
	_rows.add_child(row)
	_row_labels.append(label)
	_row_texts.append(text)
	_row_entries.append(entry)


## Re-run every frame while open: stamina changes what's affordable.
func _refresh_rows() -> void:
	for i: int in _row_labels.size():
		var label := _row_labels[i]
		label.text = ("> " if i == _cursor else "  ") + _row_texts[i]
		if not _is_usable(_row_entries[i]):
			label.modulate = COLOR_DISABLED
		elif i == _cursor:
			label.modulate = COLOR_SELECTED
		else:
			label.modulate = COLOR_NORMAL


func _is_usable(entry: Resource) -> bool:
	return entry == null or not _can_use.is_valid() or _can_use.call(entry)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bottom-left corner, growing upward as rows are added.
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24.0
	_panel.offset_top = -24.0
	_panel.offset_bottom = -24.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(220.0, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.14, 0.85)
	style.border_color = Color(0.55, 0.6, 0.85)
	style.set_border_width_all(2)
	style.set_content_margin_all(10.0)
	_panel.add_theme_stylebox_override(&"panel", style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title = Label.new()
	_title.modulate = Color(0.6, 0.7, 1.0)
	box.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_rows)
	add_child(_panel)
