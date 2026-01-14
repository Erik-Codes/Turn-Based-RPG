extends Control
class_name BattlerZoomRoot

func _ready() -> void:
	pivot_offset = size * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

func reset_pose() -> void:
	pivot_offset = size * 0.5
	scale = Vector2.ONE

func attack_zoom(zoom := 1.18, in_time := 0.20, out_time := 0.14) -> void:
	# Only scale; no position changes, so hover continues uninterrupted
	reset_pose()

	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE * zoom, in_time).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, out_time).set_ease(Tween.EASE_IN_OUT)
	await t.finished

	scale = Vector2.ONE
