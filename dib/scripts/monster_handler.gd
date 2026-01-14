extends Control


func _on_monster_stats_defeat(_is_player):
	$Control/HoverRoot/AnimationPlayer.play('die')
