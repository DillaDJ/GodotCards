extends Node2D


func _ready() -> void:    
	reposition()
	show()


func reposition() -> void:
	position.x = get_viewport_rect().size.x / 2.0
	position.y = get_viewport_rect().size.y / 2.0
