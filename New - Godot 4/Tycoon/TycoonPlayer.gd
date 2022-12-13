class_name TycoonPlayer
extends Node

var card_scn := preload("Card/Card.tscn")

@onready var game_master : TycoonGameMaster = GameSync.get_node_in_current_scene("%GameMaster")
@onready var hand : Hand = $Hand

var selected_cards 	 	: Array[Card] 	= []
var unplayable_cards 	: Array[int] 	= []

var player_owner := -1

signal trade_finished()


func set_player_name(id) -> void:
	$PlayerPanel/Name.text = NetworkSession.player_info[id]["name"]


func change_nameplate_colour(highlight_colour):
	var panel = $PlayerPanel

	if panel.theme == null:
		var ui_theme = load("res://UITheme.tres")
		
		var new_stylebox : StyleBoxFlat = ui_theme.get_stylebox("panel", "Panel").duplicate()

		panel.theme = Theme.new()
		panel.theme.set_stylebox("panel", "Panel", new_stylebox)
	
	panel.theme.get_stylebox("panel", "Panel").bg_color = highlight_colour



# Drawing and removing
@rpc 
func instantiate_drawn_card(value : int) -> void:
	rpc("draw_back_facing")
	draw_front_facing(value)


@rpc(any_peer)
func draw_back_facing() -> void:
	hand.add_card(card_scn.instantiate())


func draw_front_facing(value) -> void:
	var new_card = card_scn.instantiate()
	new_card.show_card(value)
	new_card.dim()
	
	new_card.connect("card_clicked", Callable(self, "find_playing_cards").bind(new_card))
	new_card.connect("card_selected", Callable(self, "select_card").bind(new_card))
	
	hand.add_card(new_card)


@rpc(any_peer)
func request_best_cards(card_raws : Array) -> void:
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
	var best_cards : Array = []
	for i in range(card_raws.size()):
		var cards : Array = hand.get_node("Cards").get_children()
		var max_size_idx : int = 0
		
		for j in range(1, cards.size()):
			var is_higher = (cards[j].card_value > cards[max_size_idx].card_value and cards[max_size_idx].card_value != 2) \
							or cards[j].card_value == 2 \
							or cards[j].card_value == 15
			
			if is_higher:
				max_size_idx = j
				
				if cards[max_size_idx].card_value == 15:
					break
		
		best_cards.append(cards[max_size_idx].raw_value)
		hand.cards_removed([cards[max_size_idx]])
	
	var sender = game_master.player_helper.get_player_from_owner_id(sender_id)
	sender.rpc_id(sender_id, "recieve_cards", best_cards)
	
	await sender.trade_finished
	
	for card_value in card_raws:
		draw_front_facing(card_value)
		rpc("draw_back_facing")
	rpc_id(sender_id, "signal_trade_finished")


@rpc(any_peer, call_local)
func recieve_cards(card_raws : Array) -> void:
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
	for card_value in card_raws:
		draw_front_facing(card_value)
		rpc("draw_back_facing")
	
	rpc_id(sender_id, "signal_trade_finished")


@rpc(any_peer, call_local)
func signal_trade_finished():
	emit_signal("trade_finished")


# Playing Cards
func find_playing_cards(clicked_card : Card) -> void:
	if clicked_card.unplayable:
		return

	var cards_to_play : Array[Card]
	if selected_cards.size() > 0:
		for card in selected_cards:
			if card.unplayable:
				return
		cards_to_play = selected_cards
	else:
		cards_to_play = [clicked_card]

	play_turn(cards_to_play)


func play_turn(cards_to_play : Array[Card]) -> void:
	var turn_played_successfully : bool = game_master.play_turn(cards_to_play)

	if turn_played_successfully:
		hand.cards_removed(cards_to_play)
		selected_cards = []


# Selection and dimming
func select_card(selecting, card_to_select : Card) -> void:
	if selecting:
		selected_cards.append(card_to_select)
	else:
		selected_cards.erase(card_to_select)
	
	# Trading selection
	if game_master.trading:
		var tycoon_two : bool = game_master.winners.size() > 3 and game_master.winners[0] == NetworkSession.my_player_info["id"]
		
		if (tycoon_two and selected_cards.size() == 2) or selected_cards.size() == 1:
			dim_unselectable_cards($Hand/Cards.get_children())
		else:
			hand.undim_cards()
		
		return
	
	# Normal Selection
	if selected_cards.size() == 0:
		hand.dim_cards(unplayable_cards)
	else:
		var cards_in_hand : Array = $Hand/Cards.get_children()
		var cards_to_dim := filter_unselectable_cards(card_to_select, cards_in_hand)
		hand.dim_cards(cards_to_dim)

		if selected_cards.size() == game_master.center_count or selected_cards.size() == 4:
			dim_unselectable_cards(cards_in_hand)


func filter_unselectable_cards(selected_card : Card, cards_in_hand : Array) -> Array[int]:
	var unselectable_cards : Array[int] = []
	var selected_card_value : int = selected_card.card_value
	
	# Handle jokers
	if selected_card_value == 15:
		if game_master.first_turn:
			selected_card_value = 3
		
		for card in selected_cards:
			if card.card_value != 15:
				selected_card_value = card.card_value
				break
		
		if selected_card_value == 15:
			return unplayable_cards
	else:
		var only_jokers := true
		for card in selected_cards:
			if card.card_value != 15:
				only_jokers = false
		
		if only_jokers:
			return unplayable_cards
	
	# Handle the rest
	for card in cards_in_hand:
		if card.card_value == selected_card_value or card.card_value == 15:
			continue
		unselectable_cards.append(card.card_value)
	
	return unselectable_cards


func clear_selection():
	for card in selected_cards:
		card.get_node("Select").hide()
	selected_cards.clear()


func dim_unplayable_cards(is_players_turn : bool) -> void:
	if !is_players_turn:
		hand.dim_cards()
		return
	
	hand.dim_cards(unplayable_cards)


func dim_unselectable_cards(cards_in_hand):
	for card in cards_in_hand:
		if !card.unplayable and !(card in selected_cards):
			card.dim()

# Debug
#func _process(delta):
#	if Input.is_action_just_pressed("space"):
##		randomize()
##		draw_front_facing(randi() % 54)
#		draw_front_facing(debug)
#		debug += 1
