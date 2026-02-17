#Currently working on
extends Button
class_name MonsterEntryButton

signal chosen(monster_uid: int)

@export var monster_uid: int = -1

@onready var ic: TextureRect = $Icon
@onready var desc: Label = $Desc

#load each monster into a slot
func setup(uid: int) -> void:
	monster_uid = uid
	var inst := GameState.get_monster(uid)
	if inst.is_empty():
		return
	var species_id := int(inst["species"])
	var lvl := int(inst.get("level", 1))
	ic.texture = load(Global.monster_data[species_id]["texture"])
	desc.text = inst['name'] +" "+ str(lvl)

func _pressed() -> void:
	if monster_uid != -1:
		chosen.emit(monster_uid)
