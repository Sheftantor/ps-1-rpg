class_name Win95MessageLabel
extends Label
## A HUD label that sits in the theme's MessageLabel box (a small tooltip-style
## window) while it has text, and draws nothing when its text is empty; for
## labels a script blanks rather than hides (e.g. the HUD's flash messages).

func _process(_delta: float) -> void:
	var wanted := &"MessageLabel" if not text.is_empty() else &""
	if theme_type_variation != wanted:
		theme_type_variation = wanted
