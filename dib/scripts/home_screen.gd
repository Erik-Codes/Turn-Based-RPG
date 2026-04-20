extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueGame
@onready var info_label: Label = $VBoxContainer/InfoLabel

func _ready() -> void:
	_refresh_continue_state()

func _refresh_continue_state() -> void:
	var has_save := GameState.has_save()
	continue_button.disabled = not has_save
	if has_save:
		info_label.text = "Continue from your last village, island, or cave save."
	else:
		info_label.text = "No save found yet. Start a new run to create one."

func _on_new_game_pressed() -> void:
	GameState.start_new_game()
	get_tree().change_scene_to_file(GameState.get_resume_scene())

func _on_continue_game_pressed() -> void:
	if not GameState.load_game():
		_refresh_continue_state()
		return
	get_tree().change_scene_to_file(GameState.get_resume_scene())

func _on_quit_pressed() -> void:
	get_tree().quit()
