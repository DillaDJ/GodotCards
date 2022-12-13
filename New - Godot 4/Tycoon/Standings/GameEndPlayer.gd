extends HBoxContainer


func setup(standing : int, player_name : String):
	$PlayerStanding.text = "%d. " % standing
	$PlayerName.text = player_name
