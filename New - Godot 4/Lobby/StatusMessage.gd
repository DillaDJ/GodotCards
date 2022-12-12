extends Panel


func _ready() -> void:
	$Close.connect("button_up", Callable(self, "hide"))
	
	NetworkSession.connect("player_registered", Callable(self, "player_connect_message"))
	NetworkSession.connect("server_hosted", 	Callable(self, "set_message").bind("Server hosted"))
	
	NetworkSession.multiplayerAPI.connect("server_disconnected", Callable(self, "set_message").bind("Disconnected from server"))
	NetworkSession.multiplayerAPI.connect("connection_failed", 	 Callable(self, "set_message").bind("Could not connect to server"))
	NetworkSession.multiplayerAPI.connect("peer_disconnected", 	 Callable(self, "player_disconnect_message"))


func player_connect_message(id : int) -> void:
	if NetworkSession.my_player_info["id"] == id:
		set_message("Connected to server")
		return
	
	set_message("%s has joined the lobby" % NetworkSession.player_info[id]["name"])


func player_disconnect_message(_id) -> void:
	set_message("A player has left the lobby")


func set_message(message : String, details := "", hide_close_button : bool = false) -> void:
	$TextContainer/Message.text = message
	$TextContainer/Details.text = details
	
	if hide_close_button:
		$Close.hide()
	
	show()
