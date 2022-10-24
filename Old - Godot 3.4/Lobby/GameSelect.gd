extends Node


var selected_game = 0


func _ready():
	var _connection
	
	if GameSession.my_info["id"] == 1:
		$Node3D/Next.disabled = false
		$Node3D/Previous.disabled = false
		$Node3D/Play.disabled = false
		
	_connection = $Node3D/Next.connect("button_down",Callable(self,"navigate").bind(true))
	_connection = $Node3D/Previous.connect("button_down",Callable(self,"navigate").bind(false))
	_connection = $Node3D/Play.connect("button_down",Callable(self,"start_game"))


func navigate(forward):
	
	if forward:
		rpc("next_game")
	else:
		rpc("previous_game")


@rpc(any_peer, call_local) func next_game():
	if selected_game + 1 >= $Games.get_child_count():
		return
	
	selected_game += 1
	$Games.position.x -= 306


@rpc(any_peer, call_local) func previous_game():
	if selected_game == 0:
		return
	
	selected_game -= 1
	$Games.position.x += 306


func start_game():
	match selected_game:
		0:
			GameSession.rpc("change_scene_to_file", "res://Scum/Scum.tscn")
