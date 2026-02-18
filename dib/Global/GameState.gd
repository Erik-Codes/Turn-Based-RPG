extends Node

var MAX_PARTY_SIZE = 3
# islands[island_id] = {
#   "current_node": "node_a",
#   "nodes": { "node_a": Global.LocationStatus.DISCOVERED, ... }
# }

var islands: Dictionary = {}
var from_town = false

const MAX_ACTIVE_QUESTS := 3 
enum QuestStatus { ACTIVE, READY_TO_TURN_IN }
# For battle transitions
var pending_battle := {
	"island_id": "",
	"node_id": "",
	"return_scene": ""
}
var next_uid := 1
var roster: Dictionary = {}
var party: Array[int] = []

# quest_state[island_id] = {
#   "day_id": int,
#   "next_idx": int,            #next quest index in Global.quest_order[island]
#   "active": Array[Dictionary] #quest instances
# }
var quest_state: Dictionary = {}

#put in JSON l8er
var quest_order := {
	"hearthbay": [
		"HB_KILL_3",
		"HB_VISIT_ALL_DAY1",
		"HB_FISH_UNIQUE_3"
	]
}

var quest_defs := {
	"HB_KILL_3": {
		"island": "hearthbay",
		"title": "Thin the Wilds",
		"desc": "Defeat 3 monsters.",
		"type": "KILL",
		"goal": {"count": 3},
		"rewards": {"gold": 30}
	},
	"HB_VISIT_ALL_DAY1": {
		"island": "hearthbay",
		"title": "Scout the Island",
		"desc": "Visit every node in one day.",
		"type": "VISIT_ALL_DAY",
		"goal": {"nodes": ["town","node_3","node_4","node_2","node_5","node_6","fishing"]},
		"rewards": {"gold": 60}
	},
	"HB_FISH_UNIQUE_3": {
		"island": "hearthbay",
		"title": "Strange Catches",
		"desc": "Fish up 3 unique monsters.",
		"type": "FISH_UNIQUE",
		"goal": {"count": 3},
		"rewards": {"gold": 50}
	}
}



func _ready() -> void:
	#new_monster auto-adds to party if room
	if roster.is_empty():
		#debugging
		var _s1 := new_monster(Global.Monster.Test1, 0)
		var _s2 := new_monster(Global.Monster.Test2, 0)
		var _s3 := new_monster(Global.Monster.Test3, 0)
		var _s4 := new_monster(Global.Monster.Test4, 0)
		var _s5 := new_monster(Global.Monster.Test5, 0)
		var _s6 := new_monster(Global.Monster.Test6, 0)
		var _s10 := new_monster(Global.Monster.Test10, 0)
		var _s11 := new_monster(Global.Monster.Test11, 0)
		var _s12 := new_monster(Global.Monster.Test12, 0)
		var _s13 := new_monster(Global.Monster.Test13, 0)
		var _s14 := new_monster(Global.Monster.Test14, 0)
		var _s15 := new_monster(Global.Monster.Test15, 0)

#make sure it exists
func ensure_island(island_id: String) -> void:
	if not islands.has(island_id):
		islands[island_id] = {
			"current_node": "",
			"nodes": {}
		}

func ensure_node(island_id: String, node_id: String) -> void:
	ensure_island(island_id)
	if not islands[island_id]["nodes"].has(node_id):
		islands[island_id]["nodes"][node_id] = Global.LocationStatus.UNDISCOVERED

#getters and setters for traversing between scenes/islands
func get_status(island_id: String, node_id: String) -> int:
	ensure_node(island_id, node_id)
	return islands[island_id]["nodes"][node_id]

func set_status(island_id: String, node_id: String, status: int) -> void:
	ensure_node(island_id, node_id)
	islands[island_id]["nodes"][node_id] = status

func get_shown(island_id: String) -> Dictionary:
	ensure_island(island_id)
	return islands[island_id].get("shown_nodes", {}).duplicate(true)

func set_shown(island_id: String, shown: Dictionary) -> void:
	ensure_island(island_id)
	islands[island_id]["shown_nodes"] = shown.duplicate(true)


func discover(island_id: String, node_id: String) -> void:
	var st := get_status(island_id, node_id)
	if st == Global.LocationStatus.UNDISCOVERED:
		set_status(island_id, node_id, Global.LocationStatus.DISCOVERED)

func set_current(island_id: String, node_id: String) -> void:
	ensure_node(island_id, node_id)
	islands[island_id]["current_node"] = node_id

func get_current(island_id: String) -> String:
	ensure_island(island_id)
	return islands[island_id]["current_node"]

func set_return_source(island_id: String, src: String) -> void:
	ensure_island(island_id)
	islands[island_id]["return_source"] = src

func consume_return_source(island_id: String) -> String:
	ensure_island(island_id)
	var src := str(islands[island_id].get("return_source", ""))
	islands[island_id]["return_source"] = ""
	return src


#player rests in town
func apply_rest_reset(island_id: String, required_nodes: Array[String]) -> void:
	ensure_island(island_id)
	var nodes = islands[island_id]["nodes"]
	var cleared := true
	for id in required_nodes:
		if not nodes.has(id):
			cleared = false
			break
		var st = nodes[id]
		if st != Global.LocationStatus.TEMP_FREED:
			cleared = false
			break
	if cleared:
		return
	for id in nodes.keys():
		if nodes[id] == Global.LocationStatus.TEMP_FREED:
			nodes[id] = Global.LocationStatus.DISCOVERED

func get_node_clears(island_id: String, node_id: String) -> int:
	var n = islands[island_id]["nodes"].get(node_id, null)
	if typeof(n) == TYPE_DICTIONARY:
		return int(n.get("clears", 0))
	return 0

#later: repeated clears drop chance so player isn't hardstuck
func battle_chance_for_node(clears: int) -> float:
	var base := 1.0
	var drop := 0.25 * clears #-25% per clear
	return clamp(base - drop, 0, 1.0)


func new_monster(species: Global.Monster, level: int = 1) -> int:
	var uid := next_uid
	next_uid += 1
	var base := Global.monster_data[species] 
	var inst := {
		"uid": uid,
		"species": species,
		"level": level,
		"exp": 0, 
		"hp": int(base.get("max health", 10)), #compute later for scaling
		"attacks": (base.get("attacks", []) as Array).duplicate(),
		#later
		#"stats": {"hp":0,"def":0,"atk":0,"speed":0},
		#"pwr":x,
		"name": base["name"],
	}
	roster[uid] = inst
	if party.size() < MAX_PARTY_SIZE:
		party.append(uid)
	return uid

func get_monster(uid: int) -> Dictionary:
	return roster.get(uid, {})

func set_party(uids: Array[int]) -> void:
	party = uids.duplicate() 

#on the fly ez stats retrieval
func compute_stats(uid: int) -> Dictionary:
	var inst = roster.get(uid, null)
	if inst == null:
		return {}
	var species := int(inst["species"])
	var level := int(inst.get("level", 1))
	var base := Global.monster_data[species]
	var name = base["name"]
	var max_hp := int(base.get("max health", 10)) + level * 2
	var atk := int(base.get("attack", 5)) + level
	var def := int(base.get("defense", 5)) + int(level * 0.75)
	var spd := int(base.get("speed", 5)) + int(level * 0.5)
	#per-instance bonus fields (future)
	atk += int(inst.get("atk_bonus", 0))
	def += int(inst.get("def_bonus", 0))
	spd += int(inst.get("spd_bonus", 0))
	return {
		"max_hp": max_hp,
		"atk": atk,
		"def": def,
		"spd": spd,
		"lvl": level,
		"name":name,
		"texture":Global.monster_data[species]["texture"]
	}
#level up = full heal
func heal_party_to_full() -> void:
	for monster_uid in party:
		if not roster.has(monster_uid):
			continue
		var s := compute_stats(monster_uid)
		roster[monster_uid]["hp"] = float(s["max_hp"])


#func player_defeated()
#go to town
