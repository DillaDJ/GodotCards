extends Node2D


var time = 0

var hand_scn = preload("res://Cards/Hand.tscn")

signal draw_finished()

var private_decks = { }

var e_card_buffer = { }

var finalize_draw_buffer = []

var hands = []

const hand_pad = 100


func _ready():
	var _connection
	
	_connection = get_tree().connect("screen_resized",Callable(self,"reposition_hands"))


func initialize_hands(turn_order):
	var id = GameSession.my_info["id"]
	var corrected_turn_order = []
	
	for i in range(0, turn_order.size()):
		if turn_order[i] == id:
			for j in range(i, turn_order.size()):
				corrected_turn_order.append(turn_order[j])
			
			for j in range(0, i):
				corrected_turn_order.append(turn_order[j])
			break
	
	for player_id in corrected_turn_order:
		var new_hand = hand_scn.instantiate()
		
		new_hand.set_name("%s_hand" % player_id)
		new_hand.set_player_name(player_id)
		new_hand.set_multiplayer_authority(player_id)
		new_hand.player_owner = player_id
		
		$Hands.add_child(new_hand)
		hands.append(new_hand)
	
	reposition_hands()

func get_tracker_hand(id):
	for hand in hands:
		if hand.player_owner == id:
			return hand

func reposition_hands():
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	
	var positions = get_hand_positions()
	
	hands = $Hands.get_children()
	
	for i in hands.size():
		hands[i].position = positions[i]
		hands[i].rotation = Vector2.UP.angle_to(Vector2(screen_width * 0.5, screen_height * 0.5) - positions[i])

func get_hand_positions():
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	
	var path = Curve2D.new()
	$PlayerPath.curve = path
	
	var x_corner_size = screen_width / 2.0
	var y_corner_size = screen_height / 2.0
	
	path.add_point(Vector2(screen_width / 2.0, screen_height - 0.5 * hand_pad), Vector2(x_corner_size, 0), Vector2(-x_corner_size, 0))
	path.add_point(Vector2(hand_pad, screen_height / 2.0), Vector2(0, y_corner_size), Vector2(0, -y_corner_size))
	path.add_point(Vector2(screen_width / 2.0, 0.5 * hand_pad), Vector2(-x_corner_size, 0), Vector2(x_corner_size, 0))
	path.add_point(Vector2(screen_width - hand_pad, screen_height / 2.0), Vector2(0, -y_corner_size), Vector2(0, y_corner_size))
	path.add_point(Vector2(screen_width / 2.0, screen_height - 0.5 * hand_pad), Vector2(x_corner_size, 0), Vector2(-x_corner_size, 0))
	
	var path_length = path.get_baked_length()
	
	var positions = []
	
	for i in range(0, hands.size()):
		var offset = i * (path_length / hands.size())
		positions.append(path.interpolate_baked(offset))
	
	return positions


func generate_deck():
	var deck = []
	
	for i in range(0, 52):
		deck.append(i)
	
	randomize()
	deck.shuffle()
	
	private_decks[GameSession.my_info["id"]] = deck
	
	rpc("send_deck", deck)

@rpc(any_peer) func send_deck(deck):
	var sender_id = get_tree().get_remote_sender_id()
	
	private_decks[sender_id] = deck


@rpc(any_peer) func force_draw(turn_order):
	request_card(turn_order)

# Request a card from the next player
func request_card(turn_order):
	var id = GameSession.my_info["id"]
	
	if private_decks[id].size() == 0:
		print("deck_empty")
		return false
	
	var request_from
	
	for i in range(0, turn_order.size()):
		if turn_order[i] == id:
			if i + 1 == turn_order.size():
				request_from = turn_order[0]
			else:
				request_from = turn_order[i + 1]
	
	print("Requesting card from %d" % request_from)
	rpc_id(request_from, "send_card")

# Pick a random card from the sender's deck and send it
@rpc(any_peer) func send_card():
	var sender_id = get_tree().get_remote_sender_id()
	
	randomize()
	var selected_card_idx = randi() % private_decks[sender_id].size()
	
	print("Sending %d to %s" % [private_decks[sender_id][selected_card_idx], sender_id])
	rpc_id(sender_id, "recieve_card", private_decks[sender_id][selected_card_idx])

# Create card in hand and request encrypted version from each player
@rpc(any_peer) func recieve_card(card):
	var id = GameSession.my_info["id"]
	
	e_card_buffer[id] = card
	
	
	for hand in hands:
		if hand.player_owner == id:
			hand.spawn_drawn_card(card)
			
			for i in range(0, private_decks[id].size()):
				if private_decks[id][i] == card:
					print("Removing %d from %d" % [card, id])
					private_decks[id].remove_at(i)
					break
			
			print("Broadcasting %d" % [card])
			rpc("send_e_card", card)
			break

# Encrypt card and send it back
@rpc(any_peer) func send_e_card(card):
	var sender_id = get_tree().get_remote_sender_id()
	
	var e_card = card
	
	print("Sending Encrypted %d to %d" % [card, sender_id])
	rpc_id(sender_id, "store_e_cards", e_card)

# Recieve cards until buffer is full
@rpc(any_peer) func store_e_cards(card):
	var sender_id = get_tree().get_remote_sender_id()
	
	var e_card = card
	e_card_buffer[sender_id] = e_card
	print("Buffer:")
	print(e_card_buffer)
	
	
	for i in range(0, private_decks[sender_id].size()):
		var e_player_card = private_decks[sender_id][i]
		
		if e_card == e_player_card:
			
			print("Removing %d from %d" % [card, sender_id])
			private_decks[sender_id].remove_at(i)
			break
	
	
	if e_card_buffer.size() == GameSession.player_info.size():
		print("Broadcasting buffer")
		rpc("broadcast_e_cards", e_card_buffer)

# Send cards to everyone else so they can remove_at them
@rpc(any_peer) func broadcast_e_cards(card_buffer):
	var sender_id = get_tree().get_remote_sender_id()
	print("Buffer recieved")
	
	for id in card_buffer:
		var e_card = card_buffer[id]
		
		for i in range(0, private_decks[id].size()):
			var e_player_card = private_decks[id][i]
			
			if e_card == e_player_card:
				print("Removing %d from %d" % [e_card, id])
				private_decks[id].remove_at(i)
				break
	
	e_card_buffer.clear()
	
	print("Sending confirmation to %s" % sender_id)
	rpc_id(sender_id, "finalize_draw")
	
	print("Draw finished")
	print("")

# Recieve confirmation from everyone
@rpc(any_peer) func finalize_draw():
	var sender_id = get_tree().get_remote_sender_id()
	
	finalize_draw_buffer.append(sender_id)
	print("Received confirmation from %s" % sender_id)
	
	if finalize_draw_buffer.size() == hands.size() - 1:
		rpc_id(1, "draw_finished")
		finalize_draw_buffer.clear()
		
		print("Draw finished")
		print("")

# Tell the server that we are done drawing
@rpc(any_peer, call_local) func draw_finished():
	emit_signal("draw_finished")



func highlight_player(player_id):
	var _hand = get_tracker_hand(player_id)
