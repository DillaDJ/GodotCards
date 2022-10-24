extends Node2D


var player_owner = -1

var card_scn = preload("res://Cards/Card/Card.tscn")

const non_full_spacing = 45
const side_padding = 140

var base_card_positions = []
const card_hold_distance = 2.2 # Amount of space checked the card that doesn't move when hovered
const card_x_push_fade_distance = 22
const card_y_push_fade_distance = 70

@onready var left_anchor = $LeftAnchor
@onready var right_anchor = $RightAnchor

var unplayable_cards = []
var selected_cards = []

signal play_card(card)
var playing_cards = []
var card_count = 0


func _process(_delta):
	if GameSession.my_info["id"] == player_owner:
		adjust_card_positions()
	
	#if Input.is_action_just_pressed("space"):
	#	randomize()
	#	draw_front_facing(randi() % 52)


# Drawing and removing
The master and mastersync rpc behavior is not officially supported anymore. Try using another keyword or making custom logic using get_multiplayer().get_remote_sender_id()
@rpc func spawn_drawn_card(value):
	rpc("draw_back_facing")
	draw_front_facing(value)

@rpc func draw_back_facing():
	var new_card = card_scn.instantiate()
	
	$Cards.add_child(new_card)
	
	card_count += 1

	update_base_positions()

func draw_front_facing(value):
	var new_card = card_scn.instantiate()
	
	new_card.show_card(value)
	
	$Cards.add_child(new_card)
	
	new_card.connect("card_clicked",Callable(self,"attempt_to_play").bind(new_card))
	new_card.connect("card_selected",Callable(self,"select_card").bind(new_card))
	
	card_count += 1

	update_base_positions()

The master and mastersync rpc behavior is not officially supported anymore. Try using another keyword or making custom logic using get_multiplayer().get_remote_sender_id()
@rpc func call_remove_cards(play_size):
	rpc("remove_cards", play_size)

@rpc func remove_cards(play_size):
	var cards = $Cards.get_children()
	
	for i in range(play_size - 1, -1, -1):
		cards[i].queue_free()
	
	card_count -= play_size

	update_base_positions()


# Hand positioning
func adjust_card_positions():
	apply_card_positions(base_card_positions)
	apply_card_positions(get_mouse_push_positions())

func update_base_positions():
	get_base_card_positions()
	apply_card_positions(base_card_positions)

func get_base_card_positions():	
	var path = $Path3D.curve
	var path_length = path.get_baked_length()
	
	var initial_card
	
	var positions = []
	
	
	if card_count == 1:
		return[.5 * path_length]
	
	if card_count <= 6:
		
		if card_count % 2 == 0:
			initial_card = (.5 * (path_length + non_full_spacing)) - (.5 * card_count * non_full_spacing)
		else:
			initial_card = (.5 * path_length) - (.5 * (card_count - 1) * non_full_spacing)
		
		for i in range(card_count):
			positions.append(initial_card + i * non_full_spacing)
	
	elif card_count > 6:
		
		var spacing = (path_length - side_padding) / float(card_count - 1)
		
		for i in range(card_count):
			positions.append(.5 * side_padding + i * spacing)
	
	base_card_positions = positions

func get_mouse_push_positions():
	var mouse_pos = get_viewport().get_mouse_position()
	var position_setter = $Path3D/PositionSetter
	var positions = []
	
	# Cards are pushed more when more cards are in the hand because space between cards is less
	# Distance from card for pushing is also less to compensate
	var card_push_amount = 25 + 11 * log(max(1, base_card_positions.size() - 6))
	var card_x_push_distance = 10 / (1.0 + 0.16 * max(0, base_card_positions.size() - 6))
	
	# Set anchor positions to first and last card so they aren't pushed
	if base_card_positions.size() > 0:
		position_setter.offset = base_card_positions[0]
		left_anchor.position.x = position_setter.position.x
		position_setter.offset = base_card_positions[base_card_positions.size() - 1]
		right_anchor.position.x = position_setter.position.x
	
	# Push cards
	for i in range(base_card_positions.size()):
		position_setter.offset = base_card_positions[i] # Gets card positions
		
		var dist = Vector2(position_setter.global_position.x - mouse_pos.x, position_setter.global_position.y - mouse_pos.y)
		
		# Limit pushing outside x and y boudaries of hand
		var x_push_limit = clamp(
		(
			1 - (left_anchor.global_position.x - mouse_pos.x) / card_x_push_fade_distance
			if mouse_pos.x <= left_anchor.global_position.x 
			else 1 - (mouse_pos.x - right_anchor.global_position.x) / card_x_push_fade_distance
		), 0, 1)
		
		var y_push_limit = 1 - clamp(abs(dist.y) / card_y_push_fade_distance - 1, 0, 1)
		
		# x value for push function, determined by distance 
		var manipulated_x = sign(dist.x) * max(0, abs(dist.x / card_x_push_distance) - card_hold_distance)
		var push_factor = sin(clamp(manipulated_x, -card_hold_distance, card_hold_distance))
		push_factor = lerp(0, push_factor, x_push_limit * y_push_limit)
		
		var new_pos = base_card_positions[i]
		new_pos += card_push_amount * sign(push_factor) * sin((abs(push_factor) * PI) / 2)
		positions.append(new_pos)
	
	return positions

func apply_card_positions(positions):
	var cards = $Cards.get_children()
	var position_setter = $Path3D/PositionSetter

	for i in range(0, positions.size()):
		position_setter.offset = positions[i]
		
		if i < cards.size():
			cards[i].position = position_setter.position
			cards[i].rotation = position_setter.rotation


# Getting and checking
func get_card_count():
	return card_count

func has_card(raw_value):
	for card in $Cards.get_children():
		if card.raw_value == -1:
			print("Checking hidden hand?")
			return
		
		if card.raw_value == raw_value:
			return true
	
	return false

func get_same_value_count(card_value):
	var count = 0
	
	for card in $Cards.get_children():
		if card.card_value == card_value:
			count += 1
	
	return count
 

func dim_cards(dimmed_values = [-1]):
	undim_cards()
	
	if dimmed_values.size() != 0:
		if dimmed_values[0] == -1:
			for card in $Cards.get_children():
				card.dim()
			return
	
		for card in $Cards.get_children():
			if card.card_value in dimmed_values:
				card.dim()

func undim_cards():
	for card in $Cards.get_children():
		card.undim()

func select_card(selecting, card):
	var game_master = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	if selecting:
		selected_cards.append(card)
	else:
		selected_cards.erase(card)
	
	if selected_cards.size() == 0:
		dim_cards(unplayable_cards)
	else:
		var cards = $Cards.get_children()
		var cards_to_dim = game_master.filter_unselectable_cards(card, cards)
		dim_cards(cards_to_dim)
		
		if selected_cards.size() == game_master.center_count:
			for card in cards:
				if !card.unplayable and !(card in selected_cards):
					card.dim()


func attempt_to_play(card):
	if selected_cards.size() > 0:
		for card in selected_cards:
			if card.unplayable == true:
				return
		playing_cards = selected_cards
	else:
		playing_cards = [card]
	
	var game_master = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	
	game_master.rpc_id(1, "attempt_to_play")

@rpc(any_peer, call_local) func play_cards():
	var game_master = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	var play_validity = game_master.play_turn(playing_cards)
	
	if play_validity:
		card_count -= playing_cards.size()
		
		for card in playing_cards:
			card.queue_free()
		playing_cards = []
		selected_cards = []
		
		update_base_positions()


func set_player_name(id):
	$PlayerPanel/Name.text = GameSession.player_info[id]["name"]

func change_nameplate_colour(highlight_colour):
	var theme = $PlayerPanel.theme
	
	if theme == null:
		theme = Theme.new()
		var stylebox = StyleBoxFlat.new()
		
		theme.set_stylebox("panel", "Panel", stylebox)
		
		$PlayerPanel.theme = theme
		
	theme.get_stylebox("panel", "Panel").bg_color = highlight_colour

