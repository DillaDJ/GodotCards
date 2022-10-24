extends Node2D



func _ready():    
	get_tree().get_root().connect("size_changed",Callable(self,"reposition"))
	
	reposition()
	show()


func reposition():
	position.x = get_viewport_rect().size.x / 2.0
	position.y = get_viewport_rect().size.y / 2.0
