extends Control
class_name CaptureOverlay

signal option_selected(option_id: String)
signal canceled

@onready var status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var option_buttons := {
	"net": $PanelContainer/MarginContainer/VBoxContainer/Options/NetButton,
	"sigil": $PanelContainer/MarginContainer/VBoxContainer/Options/SigilButton,
	"prism": $PanelContainer/MarginContainer/VBoxContainer/Options/PrismButton,
}

func _ready() -> void:
	hide()

func open_for_target(monster_name: String, species_id: int, current_hp: float, max_hp: float) -> void:
	show()
	status_label.text = "Choose a capture tool for %s." % monster_name
	for option_id in GameState.get_capture_option_ids():
		var button: Button = option_buttons.get(option_id)
		if button == null:
			continue
		var chance := int(round(GameState.capture_chance_for_monster(species_id, current_hp, max_hp, option_id) * 100.0))
		button.text = "%s  %d%%" % [GameState.get_capture_button_text(option_id), chance]
	option_buttons["net"].grab_focus()

func close_overlay() -> void:
	hide()

func set_status(message: String) -> void:
	status_label.text = message

func _on_net_button_pressed() -> void:
	hide()
	option_selected.emit("net")

func _on_sigil_button_pressed() -> void:
	hide()
	option_selected.emit("sigil")

func _on_prism_button_pressed() -> void:
	hide()
	option_selected.emit("prism")

func _on_cancel_button_pressed() -> void:
	hide()
	canceled.emit()
