extends Control


@onready var rule_pages = $HowToPlayUI/Layout/ScrollContainer/RuleLayout.get_children() 
@onready var buttons 	= $HowToPlayUI/Layout/RuleButtonLayout.get_children() 


func _ready():
	$HowToPlayUI/Close.connect("button_up", Callable(self, "hide_how_to_play_ui"))
	$HowToPlayButton.connect("button_up", 	Callable(self, "show_how_to_play_ui"))
	
	$HowToPlayUI/Layout/RuleButtonLayout/GeneralButton.connect("pressed", 		Callable(self, "show_rules").bind(0))
	$HowToPlayUI/Layout/RuleButtonLayout/MultiplesButton.connect("pressed", 	Callable(self, "show_rules").bind(1))
	$HowToPlayUI/Layout/RuleButtonLayout/ConsecutivesButton.connect("pressed", 	Callable(self, "show_rules").bind(2))
	$HowToPlayUI/Layout/RuleButtonLayout/EightsButton.connect("pressed", 		Callable(self, "show_rules").bind(3))
	$HowToPlayUI/Layout/RuleButtonLayout/RevolutionButton.connect("pressed", 	Callable(self, "show_rules").bind(4))
	$HowToPlayUI/Layout/RuleButtonLayout/JokerButton.connect("pressed", 		Callable(self, "show_rules").bind(5))
	$HowToPlayUI/Layout/RuleButtonLayout/NewGameButton.connect("pressed", 		Callable(self, "show_rules").bind(6))
	$HowToPlayUI/Layout/RuleButtonLayout/EndOfMatchButton.connect("pressed",	Callable(self, "show_rules").bind(7))


func show_how_to_play_ui() -> void:
	$HowToPlayUI.show()


func hide_how_to_play_ui() -> void:
	$HowToPlayUI.hide()


func show_rules(page_num : int) -> void:
	for i in range(rule_pages.size()):
		if i == page_num:
			rule_pages[i].show()
			continue
		
		buttons[i].button_pressed = false
