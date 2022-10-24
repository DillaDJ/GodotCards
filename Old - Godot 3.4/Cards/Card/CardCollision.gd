extends Area2D


signal collision_clicked(button_idx)


func _input_event(_viewport, event, _shape_idx):
	if event.is_action_released("left_click"):
		emit_signal("collision_clicked", 0)
	elif event.is_action_released("right_click"):
		emit_signal("collision_clicked", 1)
