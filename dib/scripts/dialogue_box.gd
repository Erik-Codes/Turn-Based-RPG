extends Control
class_name DialogueBox

signal closed

@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Title
@onready var body_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Body
@onready var advance_button: Button = $PanelContainer/MarginContainer/VBoxContainer/AdvanceButton

var _pages: Array[String] = []
var _page_index := 0

func _ready() -> void:
	hide()

func play_dialog(title: String, pages: Array[String]) -> void:
	var cleaned: Array[String] = []
	for page in pages:
		var text := page.strip_edges()
		if not text.is_empty():
			cleaned.append(text)
	if cleaned.is_empty():
		cleaned.append("...")
	_pages = cleaned
	_page_index = 0
	title_label.text = title
	_update_page()
	show()
	advance_button.grab_focus()

func _update_page() -> void:
	body_label.text = _pages[_page_index]
	if _page_index >= _pages.size() - 1:
		advance_button.text = "Close"
	else:
		advance_button.text = "Next"

func _on_advance_button_pressed() -> void:
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_update_page()
		return
	hide()
	closed.emit()
