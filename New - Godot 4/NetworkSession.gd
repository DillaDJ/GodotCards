extends Node

@onready var multiplayerAPI := get_tree().get_multiplayer()
var player_info 	:= {}
var my_player_info  := {}

signal player_registered(id : int)
signal player_unregistered(id : int)

signal server_hosted()


func _ready() -> void:
	multiplayerAPI.connect("peer_connected", 		Callable(self, "peer_connected"))
	multiplayerAPI.connect("peer_disconnected", 	Callable(self, "peer_disconnected"))
	multiplayerAPI.connect("connected_to_server", 	Callable(self, "connection_successful"))
	multiplayerAPI.connect("server_disconnected", 	Callable(self, "disconnected_from_server"))


func post_connect(player_name : String) -> void:
	var id := multiplayerAPI.get_unique_id()
	
	if player_name == "Guest":
		player_name += " " + str(id)
	
	my_player_info["id"] = id
	my_player_info["name"] = player_name


func host_server(port : int, player_name : String) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	
	multiplayerAPI.set_multiplayer_peer(peer)
	
	# Creates player_info
	post_connect(player_name)
	
	# Server has to register its own info
	broadcast_register(my_player_info)
	
	emit_signal("server_hosted")


func peer_connected(id : int) -> void:	
	if multiplayerAPI.is_server():
		rpc_id(id, "send_player_info", player_info)
		
		print("Sending connected player info to Player id: %d" % [id])


func peer_disconnected(id : int) -> void:
	emit_signal("player_unregistered", id)
	player_info.erase(id)


func connect_to_server(ip : String, port : int, player_name : String) -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	
	multiplayerAPI.set_multiplayer_peer(peer)
	
	post_connect(player_name)


func connection_successful() -> void:
	rpc_id(1, "request_register", my_player_info)


func disconnected_from_server() -> void:
	my_player_info.clear()
	player_info.clear()


@rpc(any_peer)
func request_register(player : Dictionary) -> void:
	if multiplayerAPI.is_server():
		rpc("broadcast_register", player)


@rpc(call_local)
func broadcast_register(new_player_info : Dictionary) -> void:
	player_info[new_player_info["id"]] = new_player_info
	emit_signal("player_registered", new_player_info["id"])


@rpc
func send_player_info(players : Dictionary) -> void:
	player_info = players
	
	for id in player_info:
		print("%s registered" % player_info[id]["name"])
		emit_signal("player_registered", id)


func disconnect_from_server() -> void:
	multiplayerAPI.multiplayer_peer.close()
