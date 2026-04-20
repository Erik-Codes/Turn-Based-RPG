extends Control
class_name BattleRewardsOverlay

signal closed

@onready var gold_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GoldLabel
@onready var rows_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/RowsScroll/Rows
@onready var continue_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	hide()

func show_rewards(summary: Dictionary) -> void:
	_clear_rows()
	var total_gold := int(summary.get("gold", 0))
	gold_label.text = "Gold gained: %d" % total_gold
	continue_button.hide()
	for reward in summary.get("summaries", []):
		rows_container.add_child(_build_row(reward))
	show()
	await get_tree().process_frame
	for row in rows_container.get_children():
		await _animate_row(row)
	continue_button.show()
	continue_button.grab_focus()

func _build_row(reward: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_meta("reward", reward)

	var top := HBoxContainer.new()
	top.name = "Top"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 14)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture_path := str(reward.get("texture", ""))
	if not texture_path.is_empty():
		portrait.texture = load(texture_path)
	top.add_child(portrait)

	var text_box := VBoxContainer.new()
	text_box.name = "TextBox"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "%s  Lv.%d" % [str(reward.get("display_name", "Monster")), int(reward.get("old_level", 1))]
	name_label.add_theme_font_size_override("font_size", 24)
	text_box.add_child(name_label)

	var xp_label := Label.new()
	xp_label.name = "XpLabel"
	xp_label.text = "XP +%d" % int(reward.get("exp_awarded", 0))
	xp_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(xp_label)

	top.add_child(text_box)
	row.add_child(top)

	var bar := TextureProgressBar.new()
	bar.name = "XpBar"
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 22)
	bar.max_value = max(int(reward.get("old_exp_to_next", 1)), 1)
	bar.value = int(reward.get("old_exp", 0))
	text_box.add_child(bar)
	row.set_meta("name_label", name_label)
	row.set_meta("xp_label", xp_label)
	row.set_meta("xp_bar", bar)

	return row

func _animate_row(row: VBoxContainer) -> void:
	var reward: Dictionary = row.get_meta("reward", {})
	var xp_label := row.get_meta("xp_label") as Label
	var name_label := row.get_meta("name_label") as Label
	var bar := row.get_meta("xp_bar") as TextureProgressBar
	if xp_label == null or name_label == null or bar == null:
		return
	var current_level := int(reward.get("old_level", 1))
	var current_exp := int(reward.get("old_exp", 0))
	var final_level := int(reward.get("new_level", current_level))
	var final_exp := int(reward.get("new_exp", current_exp))
	bar.max_value = max(GameState.exp_to_next_level(current_level), 1)
	bar.value = current_exp
	while current_level < final_level:
		var needed := GameState.exp_to_next_level(current_level)
		xp_label.text = "XP %d/%d" % [current_exp, needed]
		await _tween_bar(bar, current_exp, needed, 0.45)
		current_level += 1
		current_exp = 0
		name_label.text = "%s  Lv.%d" % [str(reward.get("display_name", "Monster")), current_level]
		bar.max_value = max(GameState.exp_to_next_level(current_level), 1)
		bar.value = 0
		xp_label.text = "Leveled up!"
		await get_tree().create_timer(0.18).timeout
	bar.max_value = max(GameState.exp_to_next_level(current_level), 1)
	xp_label.text = "XP %d/%d" % [final_exp, int(bar.max_value)]
	await _tween_bar(bar, current_exp, final_exp, 0.4)
	xp_label.text = "XP +%d" % int(reward.get("exp_awarded", 0))
	await get_tree().create_timer(0.1).timeout

func _tween_bar(bar: TextureProgressBar, from_value: float, to_value: float, duration: float) -> void:
	bar.value = from_value
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "value", to_value, duration)
	await tween.finished

func _clear_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

func _on_continue_button_pressed() -> void:
	hide()
	closed.emit()
