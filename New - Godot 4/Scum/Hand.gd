class_name Hand
extends Node2D

const max_space_between_cards 	:= 45.0
const hover_push_distance 		:= 18
const side_padding 				:= 140
const lerp_speed 				:= 12

var base_card_positions 	: Array[float] = []
var current_card_positions 	: Array[float] = []
var target_card_positions 	: Array[float] = []

var hovered_cards : Array[Card]

var space_between_cards : float = 0.0
var lerp_progress : float = 0.0


func _process(delta) -> void:
	move_cards_towards_target(delta)


# Adding and Removing Cards
func add_card(card : Node) -> void:
	$Cards.add_child(card)
	
	if NetworkSession.my_player_info["id"] == get_multiplayer_authority():
		card.get_node("Collision").connect("mouse_entered", Callable(self, "card_hovered").bind(card))
		card.get_node("Collision").connect("mouse_exited", Callable(self, "card_unhovered").bind(card))
	
	update_base_positions()
	current_card_positions = base_card_positions.duplicate()
	target_card_positions = base_card_positions.duplicate()
	lerp_progress = 0


func cards_removed(cards_to_remove : Array) -> void:
	for card in cards_to_remove:
		card.get_node("Collision").disconnect("mouse_entered", Callable(self, "card_hovered"))
		card.get_node("Collision").disconnect("mouse_exited", Callable(self, "card_unhovered"))
		
		$Cards.remove_child(card)
		card.queue_free()

	hovered_cards.clear()
	
	update_base_positions()
	target_card_positions = base_card_positions
	lerp_progress = 0;
	
	rpc("remove_hidden_cards", cards_to_remove.size())


func empty_hand():
	var cards =  $Cards.get_children()
	base_card_positions 	= []
	current_card_positions 	= []
	target_card_positions 	= []
	hovered_cards = []
	
	for card in cards:
		card.queue_free()


@rpc(any_peer)
func remove_hidden_cards(play_size : int) -> void:
	var cards := $Cards.get_children()
	if play_size > cards.size():
		play_size = cards.size()
	
	# Loop backwards
	for i in range(play_size - 1, -1, -1):
		
		$Cards.remove_child(cards[i])
		cards[i].queue_free()
	
	update_base_positions()
	target_card_positions = base_card_positions
	lerp_progress = 0;



# Hand positioning
func update_base_positions() -> void:
	var path : Curve2D = $CardPath.curve
	var path_length : float = path.get_baked_length()
	
	var card_count : int = $Cards.get_child_count()
	var initial_card_offset : float = 0
	var positions : Array[float] = []
	
	
	if card_count == 1:
		base_card_positions = [.5 * path_length]
		return
	
	if card_count < 7:
		# Makes sure the cards are actually centered insead of the first card starting alla the way to the left
		if card_count % 2 == 0:
			initial_card_offset = (.5 * (path_length + max_space_between_cards)) - (.5 * card_count * max_space_between_cards)
		else:
			initial_card_offset = (.5 * path_length) - (.5 * (card_count - 1) * max_space_between_cards)
		
		for i in range(card_count):
			positions.append(initial_card_offset + i * max_space_between_cards)
	
	else:
		# Fans every card out from the start to the end
		space_between_cards = (path_length - side_padding) / float(card_count - 1)
		
		for i in range(card_count):
			positions.append(.5 * side_padding + i * space_between_cards)
	
	base_card_positions = positions


func move_cards_towards_target(delta : float):
	if lerp_progress < 1.0:
		for i in range(base_card_positions.size()):
			current_card_positions[i] = lerp(current_card_positions[i], target_card_positions[i], lerp_progress)
		set_card_positions(current_card_positions)
		
		lerp_progress += lerp_speed * delta


func set_card_positions(positions_on_curve : Array[float]) -> void:
	var cards = $Cards.get_children()
	var position_setter = $CardPath/PositionSetter

	for i in range(0, positions_on_curve.size()):
		position_setter.progress = positions_on_curve[i]
		
		if i < cards.size():
			cards[i].position = position_setter.position
			cards[i].rotation = position_setter.rotation


func card_hovered(hovered_card : Card) -> void:
	hovered_cards.append(hovered_card)
	
	if hovered_cards.size() > 0:
		hovered_cards[0].z_index = 1
		push_neighbouring_cards(hovered_cards[0])


func card_unhovered(unhovered_card : Card) -> void:
	hovered_cards.erase(unhovered_card)
	unhovered_card.z_index = 0
	
	if hovered_cards.size() > 0:
		hovered_cards[0].z_index = 1
		push_neighbouring_cards(hovered_cards[0])
	else:
		target_card_positions = base_card_positions
	lerp_progress = 0


func push_neighbouring_cards(target_card : Card):
	var spacing : float = max_space_between_cards
	
	var cards = $Cards.get_children()
	var hovered_idx := cards.find(target_card, 0)
	
	var pushed_postitions = base_card_positions.duplicate()
	
	
	if cards.size() > 7:
		spacing = space_between_cards

	# Push immediate cards left and right by hover_push_distance
	if hovered_idx - 1 >= 0:
		pushed_postitions[hovered_idx - 1] = base_card_positions[hovered_idx] - hover_push_distance - max_space_between_cards
	
	if hovered_idx + 1 < pushed_postitions.size():
		pushed_postitions[hovered_idx + 1] = base_card_positions[hovered_idx] + hover_push_distance + max_space_between_cards

	# Push the rest only max_space_between_cards from immediate cards
	for i in range(pushed_postitions.size()):
		if i < hovered_idx:
			pushed_postitions[i] = pushed_postitions[hovered_idx - 1] - ((hovered_idx - i - 1) * spacing)
			
		elif i > hovered_idx:
			pushed_postitions[i] = pushed_postitions[hovered_idx + 1] + ((i - hovered_idx - 1) * spacing)
	
	target_card_positions = pushed_postitions
	lerp_progress = 0



# Getting and checking
func has_card(raw_value) -> bool:
	for card in $Cards.get_children():
		if card.raw_value == -1:
			push_error("Cannot check hidden hand")
			return false
		
		if card.raw_value == raw_value:
			return true
	
	return false


func get_card_count() -> int:
	return $Cards.get_child_count()


func get_same_value_count(card_value) -> int:
	var count := 0
	
	for card in $Cards.get_children():
		if card.card_value == card_value:
			count += 1
	
	return count



# Dimming
func dim_cards(dimmed_values = [-1]) -> void:
	undim_cards()
	
	if dimmed_values.size() != 0:
		if dimmed_values[0] == -1:
			for card in $Cards.get_children():
				card.dim()
			return
		
		for card in $Cards.get_children():
			if card.card_value in dimmed_values:
				card.dim()


func undim_cards() -> void:
	for card in $Cards.get_children():
		card.undim()
