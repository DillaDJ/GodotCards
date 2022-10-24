extends PanelContainer


signal get_form_details(hosting, ip, port, player_name)


func _ready():
	$Layout/Connect.connect("button_down", Callable(self, "submit"))
	$Layout/Host.connect("button_down", Callable(self, "submit").bind(true))


func get_ip():
	var ip = $Layout/IP/LineEdit.text
	
	if ip.is_valid_ip_address():
		return ip
	else:
		return "127.0.0.1"

func get_port():
	var port = $Layout/Port/LineEdit.text
	
	if port.is_valid_int():
		return port.to_int()
	else:
		return 7777

func get_player_name():
	return $Layout/Name/LineEdit.text


func submit(hosting = false):
	emit_signal("get_form_details", hosting, get_ip(), get_port(), get_player_name())
