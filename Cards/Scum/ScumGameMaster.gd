extends Node


remotesync var play_order = []
remotesync var current_player_idx = 0

remotesync var winners = []

@onready var dealer = $PlayAreas


remotesync var first_turn = true

@onready var center_cards = $Center/PlayedCards
@onready var center_card = $Center/PlayedCards/BaseCard

remotesync var center_count = -1
remotesync var consec_counter = 0

var matching_start = 1


@export var base_colour : Color = Color.WHITE
@export var current_turn_colour : Color = Color.WHITE
@export var eliminated_colour : Color = Color.WHITE


func _ready():
	$UI/PassRound.connect("button_down",Callable(self,"announce_pass_round"))
	GameSession.connect("loading_finished",Callable(self,"post_load"))
	
	if GameSession.my_info["id"] == 1:
		GameSession.initiate_load()
		
		var player_turn_order = []
		
		for player in GameSession.player_info:
			player_turn_order.append(player)
			
		rset("play_order", player_turn_order)
		rpc("prepare_game")


func _process(_delta):
	if Input.is_action_just_pressed("space"):
		print("I am %d" % GameSession.my_info["id"])
		print(play_order)
		print(current_player_idx)


# Game Prep
@rpc(any_peer, call_local) func prepare_game():
	if get_tree().get_remote_sender_id() == 1:
		dealer.initialize_hands(play_order)
		
		dealer.generate_deck()
		
		if GameSession.my_info["id"] == 1:
			GameSession.host_finished_loading()
		else:
			GameSession.rpc_id(1, "finished_loading")

func post_load():
	var id = GameSession.my_info["id"]
	
	if id == 1:
		var draw_timer = Timer.new()
		draw_timer.wait_time = .08
		add_child(draw_timer)
		
		for i in range(0, 52):
			var drawing_player = play_order[i % play_order.size()]
			
			if drawing_player == 1:
				dealer.request_card(play_order)
			else:
				dealer.rpc_id(drawing_player, "force_draw", play_order)
			
			await dealer.draw_finished
			
			draw_timer.start()
			await draw_timer.timeout
			
		rpc("find_first_player")

@rpc(any_peer, call_local) func find_first_player():
	var id = GameSession.my_info["id"]
	var hand = dealer.get_tracker_hand(id)
	
	if hand.has_card(1):
		for i in range(0, play_order.size()):
			if play_order[i] == id:
				rset("current_player_idx", i)
				rpc("start_new_turn")
				return


# Game Flow
@rpc(any_peer, call_local) func attempt_to_play():
	var sender_id = get_tree().get_remote_sender_id()
	
	if play_order[current_player_idx] == sender_id:
		var hand = dealer.get_tracker_hand(sender_id)
		
		hand.rpc_id(sender_id, "play_cards")

func play_turn(cards):
	var id = GameSession.my_info["id"]
	var hand = dealer.get_tracker_hand(id)
	
	var card_value = cards[0].card_value
	var play_size = cards.size()
	
	# Allow multiple of the same card at round start
	if center_card.card_value == 1:
		if play_size > 1:
			for card in cards:
				if card.card_value != card_value:
					return
		rset("center_count", play_size)
	
	# Play 3 of clubs to begin
	if first_turn:
		for card in cards:
			if card.raw_value == 1:
				rset("first_turn", false)
			
		if first_turn:
			return false
		
	else:
		# Only allow plays of the same size as the center
		if play_size != center_count:
			return false
		
		# Only allow consecutive cards
		if consec_counter > 2 and (card_value != center_card.card_value + 1 and (center_card.card_value != 14 or card_value != 2)):
			return false
		
		# Only allow higher cards, 2 is the highest
		elif (card_value <= center_card.card_value and card_value != 2) or center_card.card_value == 2:
			return false
	
		# Check If card is consecutive
		if card_value == center_card.card_value + 1:
			rset("consec_counter", consec_counter + 1)
			print("consec")
		else:
			rset("consec_counter", 0)
			print("consec break")
	
	var card_values = []
	for card in cards:
		card_values.append(card.raw_value)
	rpc("change_center_card", card_values)
	
	# Allow 8s to go again
	if center_card.card_value != 8:
		end_turn()
	else:
		rpc("start_new_turn")
	
	# Remove winner from game
	if hand.get_card_count() - play_size == 0:
		find_winner()
	
	hand.rpc("call_remove_cards", play_size)
	return true

func announce_pass_round():
	if first_turn or play_order.size() == 1:
		return
	
	var id = GameSession.my_info["id"]
	
	if play_order[current_player_idx] == id:
		remove_player_from_round(id)
		
		if play_order.size() == 1:
			start_new_round(play_order[0])
		else:
			end_turn()

func remove_player_from_round(id):
	for i in range(0, play_order.size()):
		if play_order[i] == id:
			current_player_idx -= 1
			play_order.remove_at(i)
			break
	
	rset("play_order", play_order)

func end_turn():	
	rset("current_player_idx", (current_player_idx + 1) % play_order.size())
	
	rpc("start_new_turn")

@rpc(any_peer, call_local) func start_new_turn():
	# Highlight nameplates
	for hand in dealer.hands:
		if hand.player_owner == play_order[current_player_idx]:
			hand.change_nameplate_colour(current_turn_colour)
		elif hand.player_owner in play_order:
			hand.change_nameplate_colour(base_colour)
		else:
			hand.change_nameplate_colour(eliminated_colour)
	
	# Dim cards
	var id = GameSession.my_info["id"]
	var hand = dealer.get_tracker_hand(id)
	
	if play_order[current_player_idx] == id:
		hand.unplayable_cards = []
		
		# All but 3 if first
		if first_turn:
			for i in range(2, 15):
				if i == 3:
					continue
				hand.unplayable_cards.append(i)
		
		# None checked new round
		elif center_card.card_value == 1:
			hand.undim_cards()
			return
		
		# All but consecutive
		elif consec_counter > 2:
			for i in range(2, 15):
				if (i == center_card.card_value + 1 and i != 3) or (center_card.card_value == 14 and i == 2):
					continue
				hand.unplayable_cards.append(i)
		
		# Everything below center card
		elif center_card.card_value != 2:
			for i in range(3, center_card.card_value + 1):
				hand.unplayable_cards.append(i)
		
		# Everything
		elif center_card.card_value == 2:
			hand.unplayable_cards = [-1]
		
		# Cards that can't match play size
		if center_count > 1:
			for i in range(center_card.card_value, 15):
				var card_count = hand.get_same_value_count(i)
				
				if card_count < center_count:
					hand.unplayable_cards.append(i)
			
			if hand.get_same_value_count(2) < center_count:
				hand.unplayable_cards.append(2)
		
		hand.dim_cards(hand.unplayable_cards)
		
	else:
		hand.dim_cards()

func find_winner():
	var id = GameSession.my_info["id"]
	
	remove_player_from_round(id)
	winners.append(id)
	
	rset("winners", winners)
	
	if winners.size() == GameSession.player_info.size() - 1:
		rpc("end_game")

func start_new_round(last_winner):
	var player_turn_order = []
	
	for player in GameSession.player_info:
		if !(player in winners):
			player_turn_order.append(player)
	
	rset("play_order", player_turn_order)
	
	for i in range(0, play_order.size()):
		if play_order[i] == last_winner:
			rset("current_player_idx", i)
			break
	
	rset("consec_counter", 0)
	rset("center_count", -1)
	rpc("reset_center_cards")
	rpc("start_new_turn")

@rpc(any_peer, call_local) func end_game():
	print("Standings:")
	print(winners)


# Helper Functions
@rpc(any_peer, call_local) func change_center_card(values):
	var center_cards_objs = center_cards.get_children()
	
	if !center_cards.is_visible_in_tree():
		center_cards.show()
	
	for card in center_cards_objs:
		card.position.x = 0
	
	for i in range(values.size()):
		var card = center_cards_objs[center_cards_objs.size() - 1 - i]
		card.show_card(values[i])
		card.undim()
		
		card.position.x = 16 * (values.size() - 1 - i)

@rpc(any_peer, call_local) func reset_center_cards():
	center_card.card_value = 1
	
	for card in center_cards.get_children():
		card.dim()

func filter_unselectable_cards(selected_card, cards_in_hand):
	var unselectable_cards = []
	
	for card in cards_in_hand:
		if card.card_value == selected_card.card_value:
			continue
		unselectable_cards.append(card.card_value)
	
	return unselectable_cards
