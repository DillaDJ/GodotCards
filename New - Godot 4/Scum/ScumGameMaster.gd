class_name ScumGameMaster
extends Node

const center_card_spacing := 16

var player_standings := preload("res://Scum/Standings/PlayerStanding.tscn")

@export var base_colour 		:= Color.WHITE
@export var current_turn_colour := Color.WHITE
@export var eliminated_colour 	:= Color.WHITE

@onready var player_helper  : PlayerHelper  = %Players
@onready var dealer 		: Dealer 		= %Dealer
@onready var center_card 	: Card 			= %BaseCard
@onready var center_cards 	:= %Center/PlayedCards

var play_order  : Array[int] = []
var winners 	: Array[int] = []
var current_player_idx 	:= -1

var center_count 	:= -1
var consec_counter  := 0
var matching_start  := 1

var first_turn  := true
var revolution  := false
var match_over  := false
var trading 	:= false
var traded		:= false

signal started_prepare_match(player_turn_order : Array)
signal trade_finished()



# Game Prep
func _ready() -> void:
	%LobbyButton.connect("button_up", Callable(NetworkSession, "disconnect_from_server"))
	%LobbyButton.connect("button_up", Callable(self, "return_to_lobby"))
	
	%WinnerDisplay/Match/Layout/NextMatchButton.connect("button_up", Callable(self, "restart_match"))
	%PassRoundButton.connect("button_up", Callable(self, "announce_pass_turn"))
	
	NetworkSession.multiplayerAPI.connect("server_disconnected", Callable(self, "return_to_lobby"))
	GameSync.connect("loading_finished", Callable(self, "post_load"))
	
	if NetworkSession.my_player_info["id"] == 1:
		start_prepare_match()


func start_prepare_match() -> void:
	GameSync.initiate_load()
	
	match_over = false
	play_order = []
	
	for player in NetworkSession.player_info:
		play_order.append(player)
		
	rpc("prepare_match", play_order)


@rpc(call_local)
func prepare_match(player_turn_order : Array) -> void:
	for player in %WinnerDisplay/Match.get_node("Layout/PlayerStandings").get_children():
		player.queue_free()
	%WinnerDisplay/Match.hide()
	%WinnerDisplay.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	match_over = false
	
	randomize()
	
	emit_signal("started_prepare_match", player_turn_order)
	
	if NetworkSession.my_player_info["id"] == 1:
		GameSync.host_finished_loading()
	else:
		play_order = player_turn_order
		GameSync.rpc_id(1, "finished_loading")


func post_load() -> void :
	var id : int = NetworkSession.my_player_info["id"]
	
	if id == 1:
		for i in range(0, 54):
			var drawing_player : int = play_order[i % play_order.size()]
			
			if drawing_player == 1:
				dealer.request_card(play_order)
			else:
				dealer.rpc_id(drawing_player, "force_draw", play_order)
			await dealer.draw_finished
		
		if winners.size() > 0:
			rpc("start_trading_phase")
		else:
			rpc("find_first_player")


@rpc(call_local)
func start_trading_phase():
	var id : int = NetworkSession.my_player_info["id"]
	var player 	 := player_helper.get_player_from_owner_id(id)
	var tycoon 	 : int = winners[0]
	var bankrupt : int = winners[-1]
	
	var tycoon_msg 		 := ""
	var tycoon_sub_msg 	 := ""
	var bankrupt_msg 	 := ""
	var bankrupt_sub_msg := ""
	
	trading = true
	
	
	if winners.size() < 4:
		tycoon_msg 		 = "Choose one of your cards to give to %s" % NetworkSession.player_info[bankrupt]["name"]
		tycoon_sub_msg 	 = "They will automatically trade it for their best card"
		bankrupt_msg 	 = "%s is choosing a card to give you" % [NetworkSession.player_info[tycoon]["name"]]
		bankrupt_sub_msg = "You will automatically trade it for your best card"
	
	else:
		tycoon_msg 		 = "Choose two of your cards to give to %s" % NetworkSession.player_info[bankrupt]["name"]
		tycoon_sub_msg 	 = "They will automatically trade it for their two best cards"
		bankrupt_msg 	 = "%s is choosing two cards to give you" % [NetworkSession.player_info[tycoon]["name"]]
		bankrupt_sub_msg = "You will automatically trade it for two of your best cards"
		
		var rich : int = winners[1]
		var poor : int = winners[-2]
		
		if id == rich:
			%Message.set_message("Choose one of your cards to give to %s" % NetworkSession.player_info[poor]["name"],
			"They will automatically trade it for their best card")
		elif id == poor:
			%Message.set_message("%s is choosing a card to give you" % [NetworkSession.player_info[rich]["name"]], 
			"You will automatically trade it for your best card")
	
	if id == tycoon:
		%Message.set_message(tycoon_msg, tycoon_sub_msg, true)
		player.hand.undim_cards()
	elif id == bankrupt:
		%Message.set_message(bankrupt_msg, bankrupt_sub_msg, true)
	else:
		%Message.set_message("Players are trading...", "", true)


func trade(cards : Array[Card]) -> bool:
	var id : int = NetworkSession.my_player_info["id"]
	var tycoon 	 : int = winners[0]
	var rich 	 : int = winners[1]
	
	var cards_needed := 0
	var requestee 	 := 0
	
	if winners.size() < 4:
		if id == tycoon:
			requestee = winners[-1]
			cards_needed = 1
	else:
		if id == tycoon:
			requestee = winners[-1]
			cards_needed = 2
		elif id == rich:
			requestee = winners[-2]
			cards_needed = 1
	
	if requestee != 0 and cards.size() == cards_needed:
		player_helper.get_player_from_owner_id(id).hand.dim_cards()
		
		var card_raws : Array[int] = []
		for card in cards:
			card_raws.append(card.raw_value)
		
		var requestee_player : ScumPlayer = player_helper.get_player_from_owner_id(requestee)
		requestee_player.rpc_id(requestee, "request_best_cards", card_raws)
		
		await player_helper.get_player_from_owner_id(id).trade_finished
		
		%Message.set_message("Waiting for trade...", "", true)
		rpc_id(1, "finish_trade")
		
		return true
	
	return false


@rpc(any_peer, call_local)
func finish_trade():
	if !traded and winners.size() > 3:
		traded = true
	else:
		rpc("find_first_player")


@rpc(call_local) 
func find_first_player() -> void:
	var id : int = NetworkSession.my_player_info["id"]
	
	trading = false
	traded  = false
	winners = []
	%Message.hide()
	
	first_turn = true
	
	if player_helper.get_player_from_owner_id(id).hand.has_card(1):
		rpc("start_new_turn", play_order.find(id, 0))



# Game Flow
@rpc(any_peer, call_local) 
func start_new_turn(playing_idx : int) -> void:
	current_player_idx = playing_idx
	
	highlight_nameplate()
	dim_unplayable_cards()


func play_turn(cards : Array[Card]) -> bool:
	if trading and !traded:
		return await trade(cards)
	
	if !get_turn_validity(cards):
		return false
	
	
	var id 	 : int  = NetworkSession.my_player_info["id"]
	var hand : Hand = player_helper.get_player_from_owner_id(id).hand

	var card_value  : int = cards[0].card_value
	var play_size 	: int = cards.size()
	var raw_values  : Array = []
	
	var joker_in_play 		: bool = false
	var non_jokers_in_play  : bool = false
	var consec 				: bool = false
	
	# Check for Joker Substitution
	for card in cards:
		if card.card_value != 15:
			card_value = card.card_value
			non_jokers_in_play = true
		else:
			joker_in_play = true

	# Check for consec
	if revolution:
		consec = card_value == center_card.card_value - 1
	else:
		consec = card_value == center_card.card_value + 1
	
	for card in cards:
		raw_values.append(card.raw_value)
	
	rpc("broadcast_play", raw_values, play_size, consec, joker_in_play && non_jokers_in_play)
	
	# Remove winner from game
	if hand.get_card_count() - play_size == 0:
		find_winner()
		
	# Allow 8s to go again or end turn
	elif center_card.card_value == 8:
		rpc_id(1, "start_new_round", play_order[current_player_idx])
	
	else:
		end_turn()
	
	return true


@rpc(any_peer, call_local)
func broadcast_play(raw_values : Array, play_size : int, consec : bool, joker_sub) -> void:
	if first_turn:
		first_turn = false
	
	if consec:
		consec_counter += 1
	else:
		consec_counter = 0
	
	if play_size == 4:
		revolution = !revolution
	
	center_count = play_size
		
	var center_cards_objs : Array = center_cards.get_children()
	
	if !center_cards.is_visible_in_tree():
		center_cards.show()
	
	for card in center_cards_objs:
		card.position.x = 0
	
	var joker_card_value : int
	if joker_sub:
		for value in raw_values:
			if value not in [52, 53]:
				joker_card_value = value
				break
	
	for i in range(raw_values.size()):
		var card : Card = center_cards_objs[center_cards_objs.size() - 1 - i]
		card.position.x = center_card_spacing * (raw_values.size() - 1 - i)
		
		if joker_sub:
			card.show_card(joker_card_value)
			card.show_joker()
		else:
			card.show_card(raw_values[i])
		
		card.undim()


func announce_pass_turn() -> void:
	if first_turn or play_order.size() == 1:
		return
	
	var id : int = NetworkSession.my_player_info["id"]
	
	if play_order[current_player_idx] == id:
		player_helper.get_player_from_owner_id(id).clear_selection()
		remove_player_from_round(id)
		
		if play_order.size() > 1:
			end_turn(true)
		else:
			rpc_id(1, "start_new_round", play_order[0])


func remove_player_from_round(id : int) -> void:
	play_order.remove_at(play_order.find(id, 0))
	rpc("set_play_order", play_order)


func end_turn(in_place : bool = false) -> void:
	var next_player_idx := current_player_idx
	
	if !in_place:
		next_player_idx += 1
		
	rpc("start_new_turn", (next_player_idx) % play_order.size())


@rpc(any_peer, call_local)
func start_new_round(last_winner : int) -> void:
	var player_turn_order : Array[int] = []
	
	for player in NetworkSession.player_info:
		if !(player in winners):
			player_turn_order.append(player)
	
	rpc("reset_round", player_turn_order)
	
	rpc("start_new_turn", play_order.find(last_winner))


func find_winner() -> void:
	var id : int = NetworkSession.my_player_info["id"]
	
	remove_player_from_round(id)
	
	rpc_id(1, "add_winner", id)


@rpc(any_peer, call_local)
func add_winner(id : int) -> void:
	winners.append(id)
	
	if winners.size() == NetworkSession.player_info.size() - 1:
		for player in NetworkSession.player_info:
			if !(player in winners):
				winners.append(player)
		
		rpc("end_match", winners)
	else:
		if center_card.card_value == 2:
			start_new_round(play_order[current_player_idx])
		else:
			end_turn(true)


@rpc(call_local)
func end_match(winner_array : Array) -> void:
	var match_standings = %WinnerDisplay/Match
	%WinnerDisplay.set_mouse_filter(Control.MOUSE_FILTER_STOP)
	
	match_over = true
	
	reset_round([])
	highlight_nameplate()
	
	winners = winner_array
	center_cards.hide()
	
	for i in range(winner_array.size()):
		var player_name : String = NetworkSession.player_info[winner_array[i]]["name"]
		var player_standings_panel = player_standings.instantiate()
		
		player_standings_panel.setup(winner_array.size(), i + 1, player_name)
		match_standings.get_node("Layout/PlayerStandings").add_child(player_standings_panel)
	
	match_standings.show()
	
	if NetworkSession.my_player_info["id"] == 1:
		match_standings.get_node("Layout/NextMatchButton").disabled = false


func restart_match() -> void:
	start_prepare_match()


func end_game():
	pass



# Other
@rpc(any_peer, call_local) 
func reset_round(turn_order : Array) -> void:
	play_order = turn_order
	
	consec_counter = 0
	center_count = -1
	
	# Reset Center Card
	center_card.card_value = 1
	
	for card in center_cards.get_children():
		card.dim()


@rpc(any_peer)
func set_play_order(new_play_order : Array) -> void:
	play_order = new_play_order


func get_card_validity(cards : Array[int]) -> bool:
	var card_value : int = cards[0]
	
	# Allow Joker substituation
	if card_value == 15:
		for card in cards:
			if card != 15:
				card_value = card 
	
	if first_turn:
		if card_value == 3: #|| card_value == 15:
			return true
		else:
			return false
	
	# None on new round
	if center_card.card_value == 1:
		return true
	
	# Cards that can't match amount of cards in the center
	if cards.size() < center_count:
		return false
	
	# Always allow Jokers
	elif card_value == 15:
		return true
	
	# Consecutive to center
	elif consec_counter > 2:
		var next_card : int
		
		if revolution:
			next_card = 14 if center_card.card_value == 2 else center_card.card_value - 1
		elif center_card.card_value != 2:
			next_card = 2 if center_card.card_value == 14 else center_card.card_value + 1
		
		return card_value == next_card
	
	# Everything above center card if it's not 3 during a revolution
	elif revolution:
		if card_value == 2 or center_card.card_value == 15:
			return false
		
		if center_card.card_value == 2:
			return true
		
		return card_value < center_card.card_value
	
	# Everything below center card if it's not 2
	elif center_card.card_value != 2 and center_card.card_value != 15:
		if card_value == 2:
			return true
		
		return card_value > center_card.card_value
	
	return false


func get_turn_validity(cards : Array[Card]) -> bool:
	if play_order[current_player_idx] != NetworkSession.my_player_info["id"] or match_over or play_order.size() == 0:
		return false

	var values : Array[int] = []
	for i in range(cards.size()):
		values.append(cards[i].card_value)
		
	if !get_card_validity(values):
		return false
	
	# 3 of clubs check
	if first_turn:
		var invalid_first_turn := true
		
		for card in cards:
			if card.raw_value == 1:
				invalid_first_turn = false
		
		if invalid_first_turn:
			return false
	
	return true


func dim_unplayable_cards() -> void:
	var id : int = NetworkSession.my_player_info["id"]
	var is_player_turn : bool = play_order[current_player_idx] == id
	var player = player_helper.get_player_from_owner_id(id)
	
	if is_player_turn:
		player.unplayable_cards.clear()
		
		# New round, none dimmed
		if center_card.card_value == 1 and !first_turn:
			pass
		else:
			var num_jokers : int = player.hand.get_same_value_count(15)
			
			# Find Cards to Dim, ignore jokers for now
			for i in range(2, 15):
				var num_in_hand : int = player.hand.get_same_value_count(i)
				var cards_to_check : Array[int] = [i]
				
				for j in range(min(num_in_hand - 1 + num_jokers, 3)):
					cards_to_check.append(i)
				
				if !get_card_validity(cards_to_check) or num_in_hand == 0:
					player.unplayable_cards.append(i)
			
			# Dim Jokers if nothing else can be played
			if player.unplayable_cards.size() == 13 and num_jokers < center_count:
				player.unplayable_cards.append(15)
	
	player.dim_unplayable_cards(is_player_turn)


func highlight_nameplate() -> void:
	for player in player_helper.players:
		if play_order.size() == 0:
			player.change_nameplate_colour(base_colour)
			continue
		
		if player.player_owner == play_order[current_player_idx]:
			player.change_nameplate_colour(current_turn_colour)
		elif player.player_owner in play_order:
			player.change_nameplate_colour(base_colour)
		else:
			player.change_nameplate_colour(eliminated_colour)


func return_to_lobby() -> void:
	GameSync.change_scene("res://Lobby/LobbyScene.tscn")
	GameSync.get_node_in_current_scene("%StatusMessage").set_message("Disconnected from server")



# Debug
#func _process(_delta) -> void:
#	if Input.is_action_just_pressed("space"):
#		print("I am %d" % NetworkSession.my_player_info["id"])
#		print("It is Player id: %d (%s)'s turn" % \
#			[NetworkSession.player_info[play_order[current_player_idx]]["id"], 
#			NetworkSession.player_info[play_order[current_player_idx]]["name"]])
#
#		print("This is the turn order: " + str(play_order))
