#Currently working on
extends Button
class_name MonsterEntryButton

signal chosen(kind: String, index: int, uid: int)
signal dropped(src_kind: String, src_index: int, src_uid: int, dst_kind: String, dst_index: int, dst_uid: int)


var kind: String = ""
var index: int = -1 #party slot index or roster list index (or -1)
var is_empty := true
var is_locked := false

@export var monster_uid: int = -1

@onready var ic: TextureRect = $Icon
@onready var desc: Label = $Desc

#load each monster into a slot
func setup(_kind: String, _index: int, _monster_uid: int, _locked: bool = false) -> void:
	kind = _kind
	index = _index
	monster_uid = _monster_uid
	is_locked = _locked
	is_empty = (monster_uid == -1)
	if is_locked:
		ic.texture = load("res://graphics/ui/frame.png") #replace with locked art later
		ic.modulate = Color(1,1,1,0.15)
		desc.text = "LOCKED"
		disabled = true
		return
	if is_empty:
		ic.texture = load("res://graphics/ui/frame.png") #replace w empty
		ic.modulate = Color(1,1,1,0.25)
		desc.text = ""
		disabled = false
		return
	var inst := GameState.get_monster(monster_uid)
	if inst.is_empty():
		return
	var species := int(inst["species"])
	var lvl := int(inst.get("level", 1))
	var hp := float(inst.get("max_hp", 0))
	ic.texture = load(Global.monster_data[species]["texture"])
	ic.modulate = Color(1,1,1,1)
	desc.text = inst['name'] +" "+ str(lvl)

func _pressed() -> void:
	chosen.emit(kind, index, monster_uid)

func _get_drag_data(_at_position: Vector2):
	if monster_uid == -1:
		return null
	#preview icon
	var preview := TextureRect.new()
	preview.texture = ic.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(64, 64)
	preview.modulate = Color(1,1,1,0.85)
	set_drag_preview(preview)
	return {
		"kind": kind,
		"index": index,
		"uid": monster_uid
	}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("uid"):
		return false
	var src_uid := int(data["uid"])
	if src_uid == -1:
		return false
	#no roster<->roster (does nothing)
	if kind == "roster" and str(data.get("kind","")) == "roster":
		return false
	return true

func _drop_data(_at_position: Vector2, data) -> void:
	if is_locked:
		return
	var src_kind := str(data.get("kind", ""))
	var src_index := int(data.get("index", -1))
	var src_uid := int(data.get("uid", -1))

	dropped.emit(src_kind, src_index, src_uid, kind, index, monster_uid)
