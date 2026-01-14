extends Control

signal defeat(uid: int)
signal hp_changed(uid: int, hp: float, max_hp: float)

var is_player: bool
var monster_id: int
var uid: int
var slot_index: int = -1 #0, 1, or 2 for enemies

@onready var label = $PanelContainer/MarginContainer/VBoxContainer/Label
@onready var bar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var hp_fill: TextureProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar2
@onready var hp_chip: TextureProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var _hp: float
var _max_hp: float
var _fill_tween: Tween
var _chip_tween: Tween

func setup(monster: Global.Monster, player = true, _uid = 0, _slot_index = -1) -> void:
	uid = _uid
	slot_index = _slot_index
	var monster_data = Global.monster_data[monster]
	label.text = monster_data["name"]
	bar.max_value = monster_data["max health"]
	bar.value = monster_data["max health"]
	monster_id = monster
	_max_hp = float(Global.monster_data[monster]["max health"])
	_hp = _max_hp
	bar.max_value = _max_hp
	bar.value = _hp
	hp_fill.max_value = _max_hp
	hp_chip.max_value = _max_hp
	hp_fill.value = _hp
	hp_chip.value = _hp
	_apply_name_color(player)

func _apply_name_color(player: bool) -> void:
	if player:
		label.add_theme_color_override("font_color", Color(1,1,1))
		return
	match slot_index:
		0: label.add_theme_color_override("font_color", Color(1,0,0))
		1: label.add_theme_color_override("font_color", Color(0,1,0))
		2: label.add_theme_color_override("font_color", Color(0,0,1))
		_: label.add_theme_color_override("font_color", Color(1,1,1))

func update(attack_data: Dictionary) -> void:
	#Apply to REAL HP instantly
	_hp = clamp(_hp - float(attack_data["amount"]), 0.0, _max_hp)
	#Animate the bar to match
	_animate_hp(_hp)


func _animate_hp(target: float) -> void:
	#kill old tweens
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.kill()
	if _chip_tween and _chip_tween.is_running():
		_chip_tween.kill()
	#fill moves first
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_QUAD)
	_fill_tween.set_ease(Tween.EASE_OUT)
	_fill_tween.tween_property(hp_fill, "value", target, 0.16)
	#chip follows
	_chip_tween = create_tween()
	_chip_tween.set_trans(Tween.TRANS_QUAD)
	_chip_tween.set_ease(Tween.EASE_OUT)
	_chip_tween.tween_interval(0.3)
	_chip_tween.tween_property(hp_chip, "value", target, 0.3)

func get_hp() -> float: return _hp
func get_max_hp() -> float: return _max_hp

func _on_progress_bar_value_changed(value):
	hp_changed.emit(uid, _hp, _max_hp)
	if value <= 0.0:
		defeat.emit(uid)
