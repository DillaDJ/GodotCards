extends Node


var lobby_player_scene = preload("res://Lobby/LobbyPlayer.tscn")



func _ready():
	var _connection
	var tree = get_tree()

	_connection = tree.connect("connected_to_server",Callable(self,"connection_successful"))
	_connection = tree.connect("connection_failed",Callable(self,"connection_failed"))
	_connection = tree.connect("server_disconnected",Callable(self,"server_disconnected"))
	_connection = tree.connect("peer_connected",Callable(self,"peer_connected"))
	_connection = tree.connect("peer_disconnected",Callable(self,"peer_disconnected"))
	
	_connection = $ConnectionUI/Connect.connect("button_down",Callable(self,"initialize_player"))
	
	_connection = $ConnectionUI/Host.connect("button_down",Callable(self,"initialize_player").bind(true))
	
	_connection = GameSession.connect("player_registered",Callable(self,"create_lobby_item"))
	
	_connection = $Start.connect("button_down",Callable(self,"select_game"))


func get_ip():
	var ip = $ConnectionUI/IP/LineEdit.text
	
	if ip.is_valid_ip_address():
		return ip
	else:
		return "127.0.0.1"

func get_port():
	var port = $ConnectionUI/Port/LineEdit.text
	
	if port.is_valid_int():
		return int(port)
	else:
		return 7777


func connect_to_server():
	var ip = get_ip()
	var port = get_port()
	
	if ip == "":
		print("Invalid IP address")
		return
	
	if port == -1:
		print("Invalid Port")
		return
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	get_tree().network_peer = peer

func host_server():
	var port = get_port()
	
	if port == -1:
		print("Invalid Port")
		return
	
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, 8)
	get_tree().network_peer = peer


func connection_successful():
	GameSession.rpc_id(GameSession.my_info["id"], "register_player", GameSession.my_info)

func connection_failed():
	print("Connection failed")


func server_disconnected():
	print("Disconnected from server")


func peer_connected(id):
	GameSession.rpc_id(id, "register_player", GameSession.my_info)

func peer_disconnected(id):
	var players = $PlayerList.get_children()
	
	for player in players:
		if player.id == id:
			player.queue_free()


func initialize_player(is_hosting = false):
	if is_hosting:
		host_server()
	else:
		connect_to_server()

	GameSession.my_info["id"] = get_tree().get_unique_id()
	GameSession.my_info["name"] = $ConnectionUI/Name/LineEdit.text
	
	$ConnectionUI.hide()
	$Start.show()
	
	if is_hosting:
		connection_successful()


func create_lobby_item(id):
	var lobby_player = lobby_player_scene.instantiate()
	
	lobby_player.id = id
	
	if GameSession.player_info[id]["name"] == "":
		GameSession.player_info[id]["name"] = "Player %d" % id

	if id == 1:
		lobby_player.set_player_name("%s (Host)" % GameSession.player_info[id]["name"])
		
		if GameSession.my_info["id"] == 1:
			$Start.disabled = false
	
	else:
		lobby_player.set_player_name("%s" % GameSession.player_info[id]["name"])
	
	$PlayerList.add_child(lobby_player)
	
	if GameSession.my_info["id"] == id:
		lobby_player.highlight()


func select_game():
	GameSession.rpc("change_scene_to_file", "res://Lobby/GameSelect.tscn")
