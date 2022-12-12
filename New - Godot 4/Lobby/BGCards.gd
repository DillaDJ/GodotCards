extends Node2D


var card_scn := preload("res://Scum/Card/Card.tscn")

const max_cards := 200


# Called when the node enters the scene tree for the first time.
func _ready():
	var screen_width  := int(get_viewport_rect().size.x)
	var screen_height := int(get_viewport_rect().size.y)
	var card_num : int = randi() % max_cards
	
	for i in range(card_num):
		var card = card_scn.instantiate()
		
		card.position = Vector2(randi() % screen_width, randi() % screen_height)
		card.rotation = randi() % 360
		
		card.show_card(randi() % 53)
		
		add_child(card)
