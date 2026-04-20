extends Control
class_name QuestBanner

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Title
@onready var body_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Body

var _queue: Array = []
var _showing := false

func _ready() -> void:
	hide()

func enqueue_many(notices: Array) -> void:
	for notice in notices:
		if typeof(notice) == TYPE_DICTIONARY and not notice.is_empty():
			_queue.append(notice.duplicate(true))
	if _showing or _queue.is_empty():
		return
	_play_queue()

func _play_queue() -> void:
	_showing = true
	while not _queue.is_empty():
		var notice: Dictionary = _queue.pop_front()
		title_label.text = str(notice.get("title", "Quest Progress"))
		body_label.text = str(notice.get("text", ""))
		if bool(notice.get("is_complete", false)):
			panel.modulate = Color(1.0, 0.96, 0.72, 1.0)
		else:
			panel.modulate = Color(0.82, 0.95, 1.0, 1.0)
		position.y = -120.0
		show()
		var in_tween := create_tween()
		in_tween.set_trans(Tween.TRANS_BACK)
		in_tween.set_ease(Tween.EASE_OUT)
		in_tween.tween_property(self, "position:y", 18.0, 0.28)
		await in_tween.finished
		await get_tree().create_timer(1.9).timeout
		var out_tween := create_tween()
		out_tween.set_trans(Tween.TRANS_SINE)
		out_tween.set_ease(Tween.EASE_IN)
		out_tween.tween_property(self, "position:y", -120.0, 0.22)
		await out_tween.finished
		hide()
	_showing = false
