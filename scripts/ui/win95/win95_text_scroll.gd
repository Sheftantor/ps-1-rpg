class_name Win95TextScroll
extends ScrollContainer
## A fixed-size box for text that changes (item descriptions): long text
## scrolls inside it instead of resizing the box, so the window around it
## stays still. Jumps back to the top whenever its content changes size, so
## each new text starts from its first line.


func _ready() -> void:
	for child: Node in get_children():
		if child is Control:
			(child as Control).resized.connect(_to_top)


func _to_top() -> void:
	scroll_vertical = 0
