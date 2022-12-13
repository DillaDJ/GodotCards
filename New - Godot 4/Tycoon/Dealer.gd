class_name Dealer
extends Node


var finalized_draw_buffer := []

var private_decks := { }
var e_card_buffer := { }
var time := 0

signal draw_finished()



func _ready() -> void:
	GameSync.get_node_in_current_scene("%GameMaster").connect("started_prepare_match", Callable(self, "generate_deck"))



# Deck
# The decks in my implementation are based off of mental poker to make cheating really difficult
# using some ideas from this paper: https://www.researchgate.net/publication/221355307_Poker_Protocols
# I know I didn't have to do this for a small card minigame but it seemed fun and also pretty cool
# It works by generating a unique deck for each player and encrypting it with a private key
# The generated deck is then sent to every other player, when a player wants to draw, they
# request a card from the next player and that player sends a card
func generate_deck(_turn_order):
	var deck = []
	
	for i in range(0, 54):
		deck.append(i)
	
	# Encrypt deck
	
	deck.shuffle()
	
	private_decks[NetworkSession.my_player_info["id"]] = deck
	
	rpc("send_deck", deck)


@rpc(any_peer) 
func send_deck(deck):
	var sender_id : int = NetworkSession.multiplayerAPI.get_remote_sender_id()
	private_decks[sender_id] = deck



# Card
@rpc
func force_draw(turn_order):
	request_card(turn_order)


@rpc(any_peer)
func request_card(turn_order):
	var id = NetworkSession.my_player_info["id"]
	
	if private_decks[id].size() == 0:
		print("deck_empty")
		return
	
	var requestee_idx : int = (turn_order.find(id, 0) + 1) % turn_order.size()
		
	print("Requesting card from %d" % turn_order[requestee_idx])
	rpc_id(turn_order[requestee_idx], "send_card")


# Pick a random card from the sender's deck and send it
@rpc(any_peer) 
func send_card():
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	var selected_card_idx = randi() % private_decks[sender_id].size()
		
	print("Sending %d to %s" % [private_decks[sender_id][selected_card_idx], sender_id])
	rpc_id(sender_id, "recieve_card", private_decks[sender_id][selected_card_idx])


# Create card in hand and request encrypted version from each player
@rpc(any_peer) 
func recieve_card(card):
	var id = NetworkSession.my_player_info["id"]
	e_card_buffer[id] = card
	
	for player in %Players.get_players():
		if player.player_owner == id:
			player.instantiate_drawn_card(card)
			
			for i in range(0, private_decks[id].size()):
				if private_decks[id][i] == card:
					print("Removing %d from %d" % [card, id])
					private_decks[id].remove_at(i)
					break
			
			print("Broadcasting %d" % [card])
			rpc("send_e_card", card)
			break


# Encrypt card and send it back
@rpc(any_peer) 
func send_e_card(card):
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
	var e_card = card
	
	print("Sending Encrypted %d to %d" % [card, sender_id])
	rpc_id(sender_id, "store_e_cards", e_card)


# Recieve cards until buffer is full
@rpc(any_peer) 
func store_e_cards(card):
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
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
	
	if e_card_buffer.size() == NetworkSession.player_info.size():
		print("Broadcasting buffer")
		rpc("broadcast_e_cards", e_card_buffer)


# Send cards to everyone else so they can remove_at them
@rpc(any_peer) 
func broadcast_e_cards(card_buffer):
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
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
@rpc(any_peer) 
func finalize_draw():
	var sender_id = NetworkSession.multiplayerAPI.get_remote_sender_id()
	
	finalized_draw_buffer.append(sender_id)
	print("Received confirmation from %s" % sender_id)
	
	if finalized_draw_buffer.size() == %Players.get_players().size() - 1:
		rpc_id(1, "finished_drawing")
		finalized_draw_buffer.clear()
		
		print("Draw finished \n")


# Tell the server that we are done drawing
@rpc(any_peer, call_local) 
func finished_drawing():
	emit_signal("draw_finished")
