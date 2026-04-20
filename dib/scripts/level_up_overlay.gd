extends Control
class_name LevelUpOverlay

signal closed

@onready var rows_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/RowsScroll/Rows
@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	hide()

func show_level_ups(reward_summaries: Array) -> bool:
	_clear_rows()
	var found_any := false
	for reward in reward_summaries:
		if int(reward.get("levels_gained", 0)) <= 0:
			continue
		found_any = true
		rows_container.add_child(_build_row(reward))
	if not found_any:
		return false
	show()
	continue_button.grab_focus()
	return true

func _build_row(reward: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := str(reward.get("texture", ""))
	if not texture_path.is_empty():
		portrait.texture = load(texture_path)
	root.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "%s  Lv.%d -> Lv.%d" % [
		str(reward.get("display_name", "Monster")),
		int(reward.get("old_level", 1)),
		int(reward.get("new_level", 1)),
	]
	title.add_theme_font_size_override("font_size", 24)
	text_box.add_child(title)

	var gains: Dictionary = reward.get("total_stat_gains", {})
	var gain_label := Label.new()
	gain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gain_label.text = "HP +%d   ATK +%d   DEF +%d   SPD +%d" % [
		int(gains.get("hp", 0)),
		int(gains.get("atk", 0)),
		int(gains.get("def", 0)),
		int(gains.get("spd", 0)),
	]
	gain_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(gain_label)

	var evolution_label := Label.new()
	var evolved_to := int(reward.get("evolved_to", -1))
	if evolved_to != -1:
		evolution_label.text = "Evolved into %s" % str(Global.get_monster_name(evolved_to))
	else:
		evolution_label.text = "Power surged after leveling."
	evolution_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(evolution_label)

	root.add_child(text_box)
	return panel

func _clear_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

func _on_continue_button_pressed() -> void:
	hide()
	closed.emit()
