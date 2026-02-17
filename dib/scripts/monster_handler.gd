extends Control

#when enemy dies
func _on_monster_stats_defeat(_is_player):
	$Control/HoverRoot/AnimationPlayer.speed_scale=1
	$Control/HoverRoot/AnimationPlayer.play('die')
	await $Control/HoverRoot/AnimationPlayer.animation_finished
	$Control/HoverRoot/AnimationPlayer.speed_scale=0.67
