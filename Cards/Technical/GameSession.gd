extends Node


var player_info = {}
var my_info = { "id" : -1, "name" : "" }

signal player_registered(id)


signal loading_finished()
var loaded_players = []


func _ready():
	var tree = get_tree()
	var _connection
	
	_connection = tree.connect("peer_disconnected",Callable(self,"unregister_player"))


@rpc(any_peer, call_local) func register_player(info):
	var id = info["id"]
	var new_player_info = info.duplicate()
	
	new_player_info.erase("id")
	
	player_info[id] = new_player_info
	
	emit_signal("player_registered", id)


func unregister_player(id):
	player_info.erase(id)



@rpc(any_peer, call_local) func change_scene_to_file(path):	
	var game_select_scene = load(path).instantiate()
	
	var root = get_tree().root
	
	root.get_child(root.get_child_count() - 1).queue_free()
	
	root.add_child(game_select_scene)


func initiate_load():
	get_tree().paused = true
	loaded_players = []


func host_finished_loading():
	loaded_players.append(1)
	
	if loaded_players.size() == player_info.size():
		rpc("post_load")


@rpc(any_peer) func finished_loading():
	var sender = get_tree().get_remote_sender_id()
	
	assert(sender in player_info) # Exists
	assert(not sender in loaded_players) # Was not added yet

	loaded_players.append(sender)
	
	if loaded_players.size() == player_info.size():
		rpc("post_load")


@rpc(any_peer, call_local) func post_load():
	if get_tree().get_remote_sender_id() == 1:
		get_tree().paused = false
	
	emit_signal("loading_finished")
