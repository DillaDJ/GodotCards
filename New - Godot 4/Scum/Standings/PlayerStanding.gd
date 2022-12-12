extends Panel

var big_winner_graphic  : Texture2D = preload("res://Scum/Standings/BigWinner.png")
var big_loser_graphic 	: Texture2D = preload("res://Scum/Standings/BigLoser.png")
var winner_graphic 		: Texture2D = preload("res://Scum/Standings/Winner.png")
var loser_graphic 		: Texture2D = preload("res://Scum/Standings/Loser.png")


func setup(num_players : int, place : int, player_name : String):
	$PlayerName.text = "%d. %s" % [place, player_name]
	
	if num_players < 4:
		if place == num_players:
			$IconBG/Icon.texture = loser_graphic
			$IconBG.show()
		
		elif place == 1:
			$IconBG/Icon.texture = winner_graphic
			$IconBG.show()

	else:
		pass
