extends Panel

var big_winner_graphic  : Texture2D = preload("res://Tycoon/Standings/BigWinner.png")
var big_loser_graphic 	: Texture2D = preload("res://Tycoon/Standings/BigLoser.png")
var winner_graphic 		: Texture2D = preload("res://Tycoon/Standings/Winner.png")
var loser_graphic 		: Texture2D = preload("res://Tycoon/Standings/Loser.png")


func setup(num_players : int, place : int, player_name : String, points : int) -> void:
	$RightsideLayout/PlayerName.text = "%d. %s" % [place, player_name]
	$Score.text = "%d" % points
	
	if num_players < 4:
		if place == 1:
			$RightsideLayout/IconBG/Icon.texture = winner_graphic
		elif place == num_players:
			$RightsideLayout/IconBG/Icon.texture = loser_graphic
		else: return
		
	else:
		if place == 1:
			$RightsideLayout/IconBG/Icon.texture = big_winner_graphic
		elif place == 2:
			$RightsideLayout/IconBG/Icon.texture = winner_graphic
		elif place == num_players - 1:
			$RightsideLayout/IconBG/Icon.texture = loser_graphic
		elif place == num_players:
			$RightsideLayout/IconBG/Icon.texture = big_loser_graphic
		else: return
	
	$RightsideLayout/TextPad.hide()
	$RightsideLayout/IconBG.show()
