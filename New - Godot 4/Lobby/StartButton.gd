extends Button

const tycoon_scene_path := "res://Scum/TycoonScene.tscn"


func _ready() -> void:
	connect("button_down", Callable(self, "change_scene"))
	NetworkSession.connect("player_registered", Callable(self, "enable"))


func enable(_id) -> void:
	if NetworkSession.my_player_info["id"] == 1 and NetworkSession.player_info.size() > 1:
		disabled = false


func change_scene():
	GameSync.rpc("change_scene", tycoon_scene_path)
