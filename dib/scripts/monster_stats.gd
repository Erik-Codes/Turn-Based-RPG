extends Control

signal defeat(uid: int)
signal hp_changed(uid: int, hp: float, max_hp: float)

var is_player: bool
var monster_id: int
var uid: int
var monster_uid: int = -1 #persistent instance uid (players only)
var slot_index: int = -1 #0, 1, or 2 for enemies
var _defeated := false

@onready var label = $PanelContainer/MarginContainer/VBoxContainer/Label
@onready var bar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var hp_fill: TextureProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar2
@onready var hp_chip: TextureProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var _hp: float
var _max_hp: float
var _fill_tween: Tween
var _chip_tween: Tween

func setup(monster: int, player := true, _uid := 0, _slot_index := -1, _monster_uid := -1,) -> void:
	uid = _uid
	slot_index = _slot_index
	is_player = player
	monster_id = monster
	monster_uid = _monster_uid
	_defeated = false
	var base := Global.monster_data[monster]
	label.text = base["name"]
	_apply_name_color(player)
	#Compute stats
	if player and monster_uid != -1:
		#pull computed stats from GameState
		var s := GameState.compute_stats(monster_uid)
		_max_hp = float(s.get("max_hp", base["max health"]))
		#persistent hp:
		var saved_hp = GameState.roster.get(monster_uid, {}).get("hp", 1)
		_hp = float(saved_hp) if saved_hp != null else _max_hp
		_hp = clamp(_hp, 0.0, _max_hp)
	else:
		#enemies;
		_max_hp = float(base["max health"])
		_hp = _max_hp
	#Bars setup
	bar.max_value = _max_hp
	bar.value = _hp
	hp_fill.max_value = _max_hp
	hp_chip.max_value = _max_hp
	hp_fill.value = _hp
	hp_chip.value = _hp
	if player and $"..".get_node("Label"):
		$"../Label".text = str(_hp) +"/"+str(_max_hp)
		$"../Label".show()

#enemies will have different colored names (easier to tell them apart in the queue)
func _apply_name_color(player: bool) -> void:
	if player:
		label.add_theme_color_override("font_color", Color(1,1,1))
		return
	match slot_index:
		0: label.add_theme_color_override("font_color", Color(1,0,0))
		1: label.add_theme_color_override("font_color", Color(0,1,0))
		2: label.add_theme_color_override("font_color", Color(0,0,1))
		_: label.add_theme_color_override("font_color", Color(1,1,1))

#damage/heal the monster
func update(attack_data: Dictionary) -> void:
	_hp = clamp(_hp - float(attack_data["amount"]), 0.0, _max_hp)
	#persist injuries
	if is_player and monster_uid != -1:
		GameState.roster[monster_uid]["hp"] = _hp
	_animate_hp(_hp)
	hp_changed.emit(uid, _hp, _max_hp)
	#update the hp label
	if is_player and $"..".get_node("Label"):
		$"../Label".text = str(_hp) +"/"+str(_max_hp)
	if _hp <= 0.0 and not _defeated:
		_defeated = true
		defeat.emit(uid)

#get the speed easily from stats
func get_speed():
	return GameState.get_monster(monster_uid).get(['speed'],10)

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
