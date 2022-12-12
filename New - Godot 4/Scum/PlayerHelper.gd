class_name PlayerHelper
extends Node2D


const ui_screen_edge_pad := 100

var player_scn := preload("ScumPlayer.tscn")

var players : Array[ScumPlayer] = []


func _ready():
	GameSync.get_node_in_current_scene("%GameMaster").connect("started_prepare_match", Callable(self, "initialize_players"))


func initialize_players(turn_order) -> void:
	var id : int = NetworkSession.my_player_info["id"]
	var corrected_turn_order := [] # For current player hand positioning
	
	for i in range(0, turn_order.size()):
		if turn_order[i] == id:
			for j in range(i, i + turn_order.size()):
				corrected_turn_order.append(turn_order[j % turn_order.size()])
			break
	
	for player_id in corrected_turn_order:
		var new_player := player_scn.instantiate()
		
		new_player.set_name("player_%s" % player_id)
		new_player.set_player_name(player_id)
		new_player.set_multiplayer_authority(player_id)
		new_player.player_owner = player_id
		
		%Players/Container.add_child(new_player)
		players.append(new_player)
	
	reposition()
	
	# Don't initialize more that once
	var game_master := GameSync.get_node_in_current_scene("%GameMaster")
	game_master.disconnect("started_prepare_match", Callable(self, "initialize_players"))
	game_master.connect("started_prepare_match", Callable(self, "reset_players"))



# Player Positioning
func reposition() -> void:
	var screen_width  := get_viewport_rect().size.x
	var screen_height := get_viewport_rect().size.y
	
	var positions := get_hand_positions()
	
	for i in players.size():
		players[i].position = positions[i] # Position hands around screen and rotate to face middle of the screen
		players[i].rotation = Vector2.UP.angle_to(Vector2(screen_width * 0.5, screen_height * 0.5) - positions[i])


func get_hand_positions() -> Array[Vector2]:
	var screen_width  := get_viewport_rect().size.x
	var screen_height := get_viewport_rect().size.y
	
	var path := Curve2D.new()
	%Players/FollowPath.curve = path
	
	var x_corner_size := screen_width / 2.0
	var y_corner_size := screen_height / 2.0
	
	# Constructs a curve that travels around the screen
	path.add_point(Vector2(screen_width / 2.0, screen_height - 0.5 * ui_screen_edge_pad), Vector2(x_corner_size, 0), Vector2(-x_corner_size, 0))
	path.add_point(Vector2(ui_screen_edge_pad, screen_height / 2.0), Vector2(0, y_corner_size), Vector2(0, -y_corner_size))
	path.add_point(Vector2(screen_width / 2.0, 0.5 * ui_screen_edge_pad), Vector2(-x_corner_size, 0), Vector2(x_corner_size, 0))
	path.add_point(Vector2(screen_width - ui_screen_edge_pad, screen_height / 2.0), Vector2(0, -y_corner_size), Vector2(0, y_corner_size))
	path.add_point(Vector2(screen_width / 2.0, screen_height - 0.5 * ui_screen_edge_pad), Vector2(x_corner_size, 0), Vector2(-x_corner_size, 0))
	
	var path_length := path.get_baked_length()
	var positions 	: Array[Vector2] = []
	
	for i in range(0, players.size()):
		var offset := i * (path_length / players.size())
		positions.append(path.sample_baked(offset, true))
	
	return positions



# Helpers
func get_player_from_owner_id(id) -> ScumPlayer:
	for player in players:
		if player.player_owner == id:
			return player
	
	return null


func get_players() -> Array[ScumPlayer]:
	return players


func reset_players(_player_turn_order : Array) -> void:
	for player in players:
		player.hand.empty_hand()
		player.selected_cards.clear()
