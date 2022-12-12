class_name LobbyPlayer
extends Panel


@export var highlight_colour := Color(70, 70, 80)

var owner_id


func highlight() -> void:
	var new_stylebox : StyleBoxFlat = theme.get_stylebox("panel", "Panel").duplicate()
	new_stylebox.bg_color = highlight_colour
	
	theme = Theme.new()
	theme.set_stylebox("panel", "Panel", new_stylebox)


func set_player_name(new_player_name : String) -> void:
	$Label.text = new_player_name
