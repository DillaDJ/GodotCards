extends Node

signal loading_finished()

var loaded_players : Array[int] = []


@rpc(call_local)
func change_scene(scene_path : String) -> void:
	var game_select_scene = load(scene_path).instantiate()
	var root = get_tree().root
	
	root.get_child(root.get_child_count() - 1).queue_free()
	root.add_child(game_select_scene)


# Sync Loading
func initiate_load() -> void:
	get_tree().paused = true
	loaded_players = []


func host_finished_loading() -> void:
	loaded_players.append(1)
	
	if loaded_players.size() == NetworkSession.player_info.size():
		rpc("post_load")


@rpc(any_peer) 
func finished_loading() -> void:
	var sender 	: int = NetworkSession.multiplayerAPI.get_remote_sender_id()
	var id 		: int = NetworkSession.my_player_info["id"]
	
	# Make sure the sender:
	assert(sender in NetworkSession.player_info) # Exists
	assert(not sender in loaded_players) 		 # Was not added yet
	
	loaded_players.append(sender)
	
	if loaded_players.size() == NetworkSession.player_info.size() and id == 1:
		rpc("post_load")


@rpc(call_local) 
func post_load() -> void:
	get_tree().paused = false
	emit_signal("loading_finished")


func get_node_in_current_scene(path : String) -> Node:
	return get_tree().root.get_child(get_tree().root.get_child_count() -1).get_node(path)
