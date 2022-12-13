extends Control


func _ready() -> void:
	$ExitButton.connect("button_up", Callable(self, "exit_game"))


func exit_game() -> void:
	get_tree().quit()
