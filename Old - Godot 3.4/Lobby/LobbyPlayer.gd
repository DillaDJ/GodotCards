extends Panel


@export var highlight_colour = Color(70, 70, 80)

var id


func set_player_name(new_name):
	get_node("Label").text = new_name


func highlight():
	theme = Theme.new()
	var new_stylebox := StyleBoxFlat.new()
	
	new_stylebox.bg_color = highlight_colour
	
	theme.set_stylebox("panel", "Panel", new_stylebox)
