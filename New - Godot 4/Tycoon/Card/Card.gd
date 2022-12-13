class_name Card
extends Sprite2D


@export var static_card = false

var card_front 		= preload("res://Tycoon/Card/CardFront.png")
var club_graphic 	= preload("res://Tycoon/Card/Club.png")
var spade_graphic 	= preload("res://Tycoon/Card/Spade.png")
var diamond_graphic = preload("res://Tycoon/Card/Diamond.png")
var heart_graphic 	= preload("res://Tycoon/Card/Heart.png")
var joker_graphic 	= preload("res://Tycoon/Card/Joker.png")

enum Suit { HIDDDEN = -1, CLUBS, SPADES, DIAMONDS, HEARTS, JOKER }
var suit := Suit.HIDDDEN

var card_value := 1
var raw_value  := -1 # Value from 0-51 of what card this is (Clubs is first starting at 0-12)

var unplayable := false

signal card_selected(selected_state : bool)
signal card_clicked()


func _ready() -> void:
	if !static_card:
		$Collision.connect("collision_clicked", Callable(self, "click_card"))


func show_card(new_value) -> void:
	var tl_text 	:= $CardFace/Text/TLValue
	var br_text 	:= $CardFace/Text/BRValue
	var suit_sprite : Texture2D
	var text_value  : String
	
	raw_value = new_value
	
	# There are only 2 Jokers in the deck
	if new_value < 52:
		suit = int(new_value / 13) as Suit
		card_value = (new_value % 13) + 2
	else:
		suit = Suit.JOKER
		card_value = 15
	
	
	match suit:
		Suit.CLUBS:
			suit_sprite = club_graphic
			
		Suit.SPADES:
			suit_sprite = spade_graphic
			
		Suit.DIAMONDS:
			suit_sprite = diamond_graphic
			
		Suit.HEARTS:
			suit_sprite = heart_graphic
		
		Suit.JOKER:
			suit_sprite = joker_graphic
	
	match card_value:
		11:
			text_value = "J"
		
		12:
			text_value = "Q"
		
		13:
			text_value = "K"
			
		14:
			text_value = "A"
		
		15:
			text_value = "JOKER"
		
		_:
			text_value = str(card_value)
	
	texture = card_front
	
	$CardFace/SuitGraphic.texture = suit_sprite
	
	tl_text.text = text_value
	br_text.text = text_value
	
	$CardFace.show()


func show_joker():
	$CardFace/SuitGraphic.texture = joker_graphic


func click_card(button_idx) -> void:
	if button_idx == 0:
		emit_signal("card_clicked")
	else:
		toggle_select()


func dim() -> void:
	if !static_card:
		unplayable = true
	
	$Dim.show()


func undim() -> void:
	if !static_card:
		unplayable = false
	
	$Dim.hide()


func toggle_select() -> void:
	if !unplayable and !static_card:
		var select := $Select
		
		if select.is_visible_in_tree():
			emit_signal("card_selected", false)
			select.hide()
		
		else:
			emit_signal("card_selected", true)
			select.show()


func is_selected() -> bool:
	return $Select.is_visible_in_tree()



# Debug
#func _process(delta):
#	if Input.is_action_just_pressed("space") and raw_value == 53:
#		show_card(3)
#	elif Input.is_action_just_pressed("space"):
#		show_card(53)
