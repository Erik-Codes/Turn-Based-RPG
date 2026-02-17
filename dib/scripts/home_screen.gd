extends Control



#barebones start screen
func _on_new_game_pressed():
	GameState.party.append(Global.Monster.Test2)
	get_tree().change_scene_to_file("res://scenes/island1.tscn")
