extends Control


@onready var rule_pages = $HowToPlayUI/Layout/ScrollContainer/RuleLayout.get_children() 
@onready var buttons 	= $HowToPlayUI/Layout/RuleButtonLayout.get_children() 


func _ready():
	$HowToPlayUI/Close.connect("button_up", Callable(self, "hide_how_to_play_ui"))
	$HowToPlayButton.connect("button_up", 	Callable(self, "show_how_to_play_ui"))
	
	for i in range(buttons.size()):
		buttons[i].connect("pressed", Callable(self, "show_rules").bind(i))


func show_how_to_play_ui() -> void:
	$HowToPlayUI.show()


func hide_how_to_play_ui() -> void:
	$HowToPlayUI.hide()


func show_rules(page_num : int) -> void:
	for i in range(rule_pages.size()):
		if i == page_num:
			buttons[i].button_pressed = true
			rule_pages[i].show()
			continue
		
		buttons[i].button_pressed = false
		rule_pages[i].hide()
