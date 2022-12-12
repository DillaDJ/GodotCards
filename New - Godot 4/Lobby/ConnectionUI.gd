extends PanelContainer


func _ready() -> void:
	$Layout/Connect.connect("button_down", Callable(self, "submit"))
	$Layout/Host.connect("button_down", Callable(self, "submit").bind(true))

	NetworkSession.multiplayerAPI.connect("connection_failed", 	 Callable(self, "enable_controls"))
	NetworkSession.multiplayerAPI.connect("server_disconnected", Callable(self, "enable_controls"))
	NetworkSession.multiplayerAPI.connect("connected_to_server", Callable(self, "hide"))
	NetworkSession.connect("server_hosted", Callable(self, "hide"))


func get_ip() -> String:
	var ip = $Layout/IP/LineEdit.text
	
	if ip.is_valid_ip_address():
		return ip
	elif ip != "":
		%StatusMessage.set_message("Invalid IP Address")
		return ""
	
	return "127.0.0.1"


func get_port() -> int:
	var port_text : String = $Layout/Port/LineEdit.text
	
	if port_text.is_valid_int():
		var port : int = port_text.to_int()
		
		if port > 0 and port < 65535:
			return port
		else:
			%StatusMessage.set_message("Invalid port", "Select a port between 1 and 65535")
			return -1
			
	elif port_text != "":
		%StatusMessage.set_message("Invalid port", "Only numbers are allowed")
		return -1
	
	return 7777


func get_player_name() -> String:
	var player_name : String = $Layout/Name/LineEdit.text
	
	if player_name == "":
		return "Guest"
	
	return player_name


func submit(hosting = false) -> void:
	var port := get_port()
	var ip   := get_ip()
	
	if port == -1 or ip == "":
		return
	
	if hosting:
		%StatusMessage.set_message("Starting server...")
		NetworkSession.host_server(port, get_player_name())
	else:
		%StatusMessage.set_message("Connecting to server...")
		NetworkSession.connect_to_server(ip, port, get_player_name())
	
	$Layout/Connect.disabled = true;
	$Layout/Host.disabled 	 = true;


func enable_controls():
	$Layout/Connect.disabled = false
	$Layout/Host.disabled 	 = false
	
	show()
