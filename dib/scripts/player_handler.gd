extends Control


#hide and gray-out the player when they die (hide all stats)
func _on_player_stats_defeat(_is_player):
	#hide()
	$PlayerStats.hide()
	$Label.hide()
	modulate = Color(0.6, 0.6, 0.6, 0)
	pass
