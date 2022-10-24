extends Sprite2D


signal card_clicked()
signal card_selected(selected_state)


var card_front = preload("res://Cards/Card/CardFront.png")

enum suits { HIDDDEN = -1, CLUBS, SPADES, DIAMONDS, HEARTS }

var club_graphic = preload("res://Cards/Card/Club.png")
var spade_graphic = preload("res://Cards/Card/Spade.png")
var diamond_graphic = preload("res://Cards/Card/Diamond.png")
var heart_graphic = preload("res://Cards/Card/Heart.png")


var suit = suits.HIDDDEN
var card_value = 1

var raw_value = -1

@export var static_card = false
var unplayable = false


func _ready():
	if !static_card:
		$CollisionObject3D.connect("collision_clicked",Callable(self,"click_card"))


func show_card(new_value):
	raw_value = new_value
	
	suit = int(new_value / 13)
	card_value = (new_value % 13) + 2
	
	var text_value
	
	texture = card_front
	
	match suit:
		suits.CLUBS:
			$CardFace/SuitGraphic.texture = club_graphic
			
		suits.SPADES:
			$CardFace/SuitGraphic.texture = spade_graphic
			
		suits.DIAMONDS:
			$CardFace/SuitGraphic.texture = diamond_graphic
			
		suits.HEARTS:
			$CardFace/SuitGraphic.texture = heart_graphic
	
	match card_value:
		11:
			text_value = "J"
		
		12:
			text_value = "Q"
		
		13:
			text_value = "K"
			
		14:
			text_value = "A"
		
		_:
			text_value = str(card_value)
	
	$CardFace/TLValue.text = text_value
	$CardFace/BRValue.text = text_value
	
	$CardFace.show()


func click_card(button_idx):
	if button_idx == 0:
		emit_signal("card_clicked")
	else:
		toggle_select()


func dim():
	if !static_card:
		unplayable = true
	
	$Dim.show()


func undim():
	if !static_card:
		unplayable = false
	
	$Dim.hide()


func toggle_select():
	if !unplayable and !static_card:
		var select = $Select
		
		if select.is_visible_in_tree():
			emit_signal("card_selected", false)
			select.hide()
		
		else:
			emit_signal("card_selected", true)
			select.show()


func is_selected():
	return $Select.is_visible_in_tree()
