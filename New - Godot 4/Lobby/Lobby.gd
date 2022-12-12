extends VBoxContainer

var lobby_player_scene := preload("res://Lobby/LobbyPlayer.tscn")

@onready var grid := $PlayerList/GridContainer


func _ready():
	NetworkSession.connect("player_registered", 	Callable(self, "create_lobby_player"))
	NetworkSession.connect("player_unregistered", 	Callable(self, "remove_lobby_player"))
	NetworkSession.connect("server_hosted", 		Callable(self, "show"))
	
	NetworkSession.multiplayerAPI.connect("server_disconnected", Callable(self, "clear_lobby"))
	NetworkSession.multiplayerAPI.connect("connected_to_server", Callable(self, "show"))


func create_lobby_player(id : int) -> void:
	var lobby_player : LobbyPlayer = lobby_player_scene.instantiate()
	var player_name  : String = NetworkSession.player_info[id]["name"]
	
	if id == 1:
		player_name += " (Host)"
	
	if id == NetworkSession.my_player_info["id"]:
		lobby_player.highlight()
	
	lobby_player.set_player_name(player_name)
	lobby_player.owner_id = id
	
	grid.add_child(lobby_player)


func remove_lobby_player(id : int) -> void:
	var lobby_players := get_node("PlayerList/GridContainer").get_children()
	
	for player in lobby_players:
		if player.owner_id == id:
			player.queue_free()


func clear_lobby() -> void:
	var lobby_players := get_node("PlayerList/GridContainer").get_children()
	
	for player in lobby_players:
		player.queue_free()
	
	hide()
