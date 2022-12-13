extends Area2D


func _ready():
	connect("area_entered", Callable(self, "check_for_card"))


func _process(delta):
	position = get_local_mouse_position()


func check_for_card(area : Area2D):
	pass

