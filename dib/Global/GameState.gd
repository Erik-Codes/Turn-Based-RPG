extends Node

const SAVE_PATH := "user://savegame.save"
const SAVE_VERSION := 1
const DEFAULT_SCENE := "res://scenes/island1.tscn"
const DEFAULT_ISLAND_ID := "hearthbay"
const STARTING_SCENE := "res://scenes/general_village.tscn"
const DEFAULT_GOLD := 120
const DAILY_FISHING_LIMIT := 4
const MAX_PARTY_SIZE := 3
const MAX_ACTIVE_QUESTS := 3
const DEBUG_STARTER_SPECIES: Array[int] = [
	Global.Monster.Test1,
	Global.Monster.Test2,
	Global.Monster.Test3,
	Global.Monster.Test4,
	Global.Monster.Test5,
	Global.Monster.Test6,
	Global.Monster.Test10,
	Global.Monster.Test11,
	Global.Monster.Test12,
	Global.Monster.Test13,
	Global.Monster.Test14,
	Global.Monster.Test15,
]

enum QuestStatus { ACTIVE, READY_TO_TURN_IN }

var islands: Dictionary = {}
var from_town := false
var pending_battle := {"island_id": "", "node_id": "", "return_scene": ""}
var next_uid := 1
var roster: Dictionary = {}
var party: Array[int] = []
var island_metrics: Dictionary = {}
var quest_state: Dictionary = {}
var gold := DEFAULT_GOLD
var capture_inventory := {
	"net": 0,
	"sigil": 0,
	"prism": 0,
}
var story_flags: Dictionary = {}
var save_meta := {
	"version": SAVE_VERSION,
	"last_scene": DEFAULT_SCENE,
	"saved_at_unix": 0,
}
var level_rng := RandomNumberGenerator.new()
var last_battle_rewards := {
	"exp": 0,
	"gold": 0,
	"summaries": [],
}

var quest_order := {
	"hearthbay": [
		"KILL_3",
		"VISIT_ALL_DAY1",
		"FISH_UNIQUE_3",
		"KILL_5",
	]
}

var encounter_tables := {
	"hearthbay": {
		"node_3": {"count_min": 1, "count_max": 2, "pool": [Global.Monster.Test1, Global.Monster.Test2, Global.Monster.Test7]},
		"node_4": {"count_min": 1, "count_max": 2, "pool": [Global.Monster.Test2, Global.Monster.Test3, Global.Monster.Test7, Global.Monster.Test8]},
		"node_2": {"count_min": 2, "count_max": 2, "pool": [Global.Monster.Test3, Global.Monster.Test4, Global.Monster.Test8, Global.Monster.Test9]},
		"node_5": {"count_min": 2, "count_max": 3, "pool": [Global.Monster.Test4, Global.Monster.Test5, Global.Monster.Test10, Global.Monster.Test11]},
		"node_6": {"count_min": 2, "count_max": 3, "pool": [Global.Monster.Test6, Global.Monster.Test10, Global.Monster.Test11, Global.Monster.Test12, Global.Monster.Test13]},
		"cave": {"count_min": 2, "count_max": 3, "pool": [Global.Monster.Test10, Global.Monster.Test11, Global.Monster.Test13, Global.Monster.Test14]},
		"fishing_rare_fight": {"count_min": 1, "count_max": 2, "pool": [Global.Monster.Test10, Global.Monster.Test11, Global.Monster.Test13]},
	}
}

var capture_option_defs := {
	"net": {"name": "Reed Net", "bonus": 0.99, "buy_price": 45},
	"sigil": {"name": "Binding Sigil", "bonus": 0.99, "buy_price": 85},
	"prism": {"name": "Royal Prism", "bonus": 0.99, "buy_price": 140},
}

var quest_defs := {
	"KILL_3": {
		"island": "hearthbay",
		"title": "Thin the Wilds",
		"desc": "Defeat 3 monsters.",
		"type": "KILL",
		"goal": {"count": 3},
		"rewards": {"gold": 30},
	},
	"KILL_5": {
		"island": "hearthbay",
		"title": "Thin the Wilds",
		"desc": "Defeat 5 monsters.",
		"type": "KILL",
		"goal": {"count": 5},
		"rewards": {"gold": 30},
	},
	"VISIT_ALL_DAY1": {
		"island": "hearthbay",
		"title": "Scout the Island",
		"desc": "Visit every node in one day.",
		"type": "VISIT_ALL_DAY",
		"goal": {"nodes": ["town", "node_3", "node_4", "node_2", "node_5", "node_6", "fishing"]},
		"rewards": {"gold": 60},
	},
	"FISH_UNIQUE_3": {
		"island": "hearthbay",
		"title": "Strange Catches",
		"desc": "Fish up 3 unique monsters.",
		"type": "FISH_UNIQUE",
		"goal": {"count": 3},
		"rewards": {"gold": 50},
	},
}

func _ready() -> void:
	level_rng.randomize()
	if roster.is_empty():
		_seed_debug_roster()
		ensure_island(DEFAULT_ISLAND_ID)
		set_current(DEFAULT_ISLAND_ID, "town")
		set_status(DEFAULT_ISLAND_ID, "town", Global.LocationStatus.DISCOVERED)
		ensure_island_progress(DEFAULT_ISLAND_ID)

func reset_state() -> void:
	islands = {}
	from_town = false
	pending_battle = {"island_id": "", "node_id": "", "return_scene": ""}
	next_uid = 1
	roster = {}
	party = []
	island_metrics = {}
	quest_state = {}
	gold = DEFAULT_GOLD
	capture_inventory = {
		"net": 0,
		"sigil": 0,
		"prism": 0,
	}
	story_flags = {}
	save_meta = {
		"version": SAVE_VERSION,
		"last_scene": DEFAULT_SCENE,
		"saved_at_unix": 0,
	}
	last_battle_rewards = {
		"exp": 0,
		"gold": 0,
		"summaries": [],
	}

func start_new_game() -> void:
	reset_state()
	new_monster(Global.Monster.Test10, 1)
	ensure_island(DEFAULT_ISLAND_ID)
	set_current(DEFAULT_ISLAND_ID, "town")
	set_status(DEFAULT_ISLAND_ID, "town", Global.LocationStatus.DISCOVERED)
	record_node_visited(DEFAULT_ISLAND_ID, "town")
	ensure_island_progress(DEFAULT_ISLAND_ID)
	set_pending_battle(DEFAULT_ISLAND_ID, "town", DEFAULT_SCENE)
	set_story_flag("starter_dialog_pending", true)
	mark_resume_scene(STARTING_SCENE)
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	save_meta["version"] = SAVE_VERSION
	save_meta["saved_at_unix"] = Time.get_unix_time_from_system()
	file.store_var(_build_save_data())
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	_apply_save_data(data)
	return true

func mark_resume_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	save_meta["last_scene"] = scene_path

func get_resume_scene() -> String:
	return str(save_meta.get("last_scene", DEFAULT_SCENE))

func get_island_return_scene(fallback := DEFAULT_SCENE) -> String:
	var return_scene := str(pending_battle.get("return_scene", fallback))
	if return_scene.is_empty():
		return fallback
	if return_scene.ends_with("general_village.tscn") or return_scene.ends_with("general_fishing.tscn") or return_scene.ends_with("cave.tscn") or return_scene.ends_with("DIBBattle.tscn"):
		return fallback
	return return_scene

func get_capture_option_ids() -> Array[String]:
	return ["net", "sigil", "prism"]

func get_capture_option_def(option_id: String) -> Dictionary:
	return capture_option_defs.get(option_id, {})

func get_capture_count(option_id: String) -> int:
	return int(capture_inventory.get(option_id, 0))

func get_capture_button_text(option_id: String) -> String:
	var data: Dictionary = get_capture_option_def(option_id)
	if data.is_empty():
		return "Unknown"
	var owned := get_capture_count(option_id)
	if owned > 0:
		return "%s  x%d" % [str(data.get("name", option_id)), owned]
	return "%s  Buy %dg" % [str(data.get("name", option_id)), int(data.get("buy_price", 0))]

func try_spend_capture_option(option_id: String) -> Dictionary:
	var data: Dictionary = get_capture_option_def(option_id)
	if data.is_empty():
		return {"success": false, "message": "That capture tool doesn't exist."}
	var owned := get_capture_count(option_id)
	if owned > 0:
		capture_inventory[option_id] = owned - 1
		return {"success": true, "spent_gold": 0, "purchased": false}
	var price := int(data.get("buy_price", 0))
	if gold < price:
		return {"success": false, "message": "Need %d gold for %s." % [price, str(data.get("name", option_id))]}
	gold -= price
	return {"success": true, "spent_gold": price, "purchased": true}

func capture_chance_for_monster(species_id: int, current_hp: float, max_hp: float, option_id: String) -> float:
	var option_data: Dictionary = get_capture_option_def(option_id)
	var hp_ratio = 1.0 if max_hp <= 0.0 else clamp(current_hp / max_hp, 0.0, 1.0)
	var base_data: Dictionary = Global.monster_data.get(species_id, {})
	var monster_power := float(base_data.get("max health", 60)) + float(base_data.get("exp_yield", 12)) * 4.0
	var base_chance = clamp(0.52 - (monster_power / 420.0), 0.10, 0.38)
	var hp_bonus = (1.0 - hp_ratio) * 0.42
	var option_bonus := float(option_data.get("bonus", 0.0))
	return clamp(base_chance + hp_bonus + option_bonus, 0.08, 0.95)

func get_capture_level_for_species(species_id: int) -> int:
	var base_data: Dictionary = Global.monster_data.get(species_id, {})
	return clamp(int(round(float(base_data.get("exp_yield", 12)) / 5.0)), 1, 8)

func clear_pending_battle() -> void:
	pending_battle = {"island_id": "", "node_id": "", "return_scene": ""}

func set_pending_battle(island_id: String, node_id: String, return_scene: String) -> void:
	pending_battle = {
		"island_id": island_id,
		"node_id": node_id,
		"return_scene": return_scene,
	}

func has_story_flag(flag_id: String) -> bool:
	return bool(story_flags.get(flag_id, false))

func set_story_flag(flag_id: String, value := true) -> void:
	story_flags[flag_id] = value

func has_island_special(island_id: String, flag_id: String) -> bool:
	ensure_island_progress(island_id)
	var special: Dictionary = island_metrics[island_id].get("special", {})
	return bool(special.get(flag_id, false))

func set_island_special(island_id: String, flag_id: String, value := true) -> void:
	ensure_island_progress(island_id)
	var special: Dictionary = island_metrics[island_id].get("special", {})
	special[flag_id] = value
	island_metrics[island_id]["special"] = special

func ensure_island(island_id: String) -> void:
	if not islands.has(island_id):
		islands[island_id] = {
			"current_node": "",
			"nodes": {},
			"shown_nodes": {},
			"return_source": "",
			"clears": {},
		}

func ensure_node(island_id: String, node_id: String) -> void:
	ensure_island(island_id)
	if not islands[island_id]["nodes"].has(node_id):
		islands[island_id]["nodes"][node_id] = Global.LocationStatus.UNDISCOVERED

func get_status(island_id: String, node_id: String) -> int:
	ensure_node(island_id, node_id)
	return int(islands[island_id]["nodes"][node_id])

func set_status(island_id: String, node_id: String, status: int) -> void:
	ensure_node(island_id, node_id)
	islands[island_id]["nodes"][node_id] = status

func get_shown(island_id: String) -> Dictionary:
	ensure_island(island_id)
	return (islands[island_id].get("shown_nodes", {}) as Dictionary).duplicate(true)

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
	return str(islands[island_id]["current_node"])

func set_return_source(island_id: String, src: String) -> void:
	ensure_island(island_id)
	islands[island_id]["return_source"] = src

func consume_return_source(island_id: String) -> String:
	ensure_island(island_id)
	var src := str(islands[island_id].get("return_source", ""))
	islands[island_id]["return_source"] = ""
	return src

func apply_rest_reset(island_id: String, required_nodes: Array[String]) -> void:
	ensure_island(island_id)
	var nodes: Dictionary = islands[island_id]["nodes"]
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
	ensure_island(island_id)
	var clears: Dictionary = islands[island_id].get("clears", {})
	return int(clears.get(node_id, 0))

func inc_node_clears(island_id: String, node_id: String, amount := 1) -> void:
	ensure_island(island_id)
	var clears: Dictionary = islands[island_id].get("clears", {})
	clears[node_id] = int(clears.get(node_id, 0)) + amount
	islands[island_id]["clears"] = clears

func battle_chance_for_node(clears: int) -> float:
	var base := 1.0
	var drop := 0.25 * clears
	return clamp(base - drop, 0.15, 1.0)

func new_monster(species: Global.Monster, level: int = 1) -> int:
	var uid := next_uid
	next_uid += 1
	var clamped_level = max(level, 1)
	var base: Dictionary = Global.monster_data[species]
	var max_hp := _compute_max_hp(base, clamped_level)
	var inst := {
		"uid": uid,
		"species": species,
		"level": clamped_level,
		"exp": 0,
		"hp": max_hp,
		"hp_bonus": 0,
		"atk_bonus": 0,
		"def_bonus": 0,
		"spd_bonus": 0,
		"attacks": (base.get("attacks", []) as Array).duplicate(),
		"name": str(base.get("name", "Unknown")),
	}
	roster[uid] = inst
	if party.size() < MAX_PARTY_SIZE:
		party.append(uid)
	return uid

func get_monster(uid: int) -> Dictionary:
	return roster.get(uid, {})

func set_party(uids: Array[int]) -> void:
	party = uids.duplicate()

func exp_to_next_level(level: int) -> int:
	var clamped_level = max(level, 1)
	return 30 + (clamped_level - 1) * 20

func can_evolve(monster_uid: int) -> bool:
	var inst: Dictionary = roster.get(monster_uid, {})
	if inst.is_empty():
		return false
	var species := int(inst.get("species", -1))
	var evo: Dictionary = Global.monster_data.get(species, {}).get("evolution", {})
	if evo.is_empty():
		return false
	return int(inst.get("level", 1)) >= int(evo.get("level", 999))

func try_evolve_monster(monster_uid: int) -> int:
	if not roster.has(monster_uid):
		return -1
	var inst: Dictionary = roster[monster_uid]
	var species := int(inst.get("species", -1))
	var evo: Dictionary = Global.monster_data.get(species, {}).get("evolution", {})
	if evo.is_empty():
		return -1
	var required_level := int(evo.get("level", 999))
	if int(inst.get("level", 1)) < required_level:
		return -1
	var next_species := int(evo.get("species", -1))
	if next_species == -1 or next_species == species:
		return -1
	inst["species"] = next_species
	inst["name"] = str(Global.monster_data[next_species].get("name", inst.get("name", "Unknown")))
	inst["attacks"] = (Global.monster_data[next_species].get("attacks", []) as Array).duplicate()
	roster[monster_uid] = inst
	_heal_monster_to_full(monster_uid)
	return next_species

func grant_exp(monster_uid: int, amount: int) -> Dictionary:
	if not roster.has(monster_uid):
		return {}
	var exp_amount = max(amount, 0)
	var inst: Dictionary = roster[monster_uid]
	var old_level := int(inst.get("level", 1))
	var old_species := int(inst.get("species", -1))
	var old_exp := int(inst.get("exp", 0))
	inst["exp"] = int(inst.get("exp", 0)) + exp_amount
	roster[monster_uid] = inst
	var levels_gained := 0
	var evolved_to := -1
	var level_ups: Array = []
	var total_stat_gains := {"hp": 0, "atk": 0, "def": 0, "spd": 0}
	while true:
		inst = roster[monster_uid]
		var level := int(inst.get("level", 1))
		var needed := exp_to_next_level(level)
		if int(inst.get("exp", 0)) < needed:
			break
		inst["exp"] = int(inst.get("exp", 0)) - needed
		inst["level"] = level + 1
		var gains := _roll_level_up_gains()
		inst["hp_bonus"] = int(inst.get("hp_bonus", 0)) + int(gains["hp"])
		inst["atk_bonus"] = int(inst.get("atk_bonus", 0)) + int(gains["atk"])
		inst["def_bonus"] = int(inst.get("def_bonus", 0)) + int(gains["def"])
		inst["spd_bonus"] = int(inst.get("spd_bonus", 0)) + int(gains["spd"])
		roster[monster_uid] = inst
		_heal_monster_to_full(monster_uid)
		levels_gained += 1
		var evolved_species := try_evolve_monster(monster_uid)
		if evolved_species != -1:
			evolved_to = evolved_species
		total_stat_gains["hp"] += int(gains["hp"])
		total_stat_gains["atk"] += int(gains["atk"])
		total_stat_gains["def"] += int(gains["def"])
		total_stat_gains["spd"] += int(gains["spd"])
		level_ups.append({
			"from_level": level,
			"to_level": level + 1,
			"stat_gains": gains.duplicate(),
			"evolved_to": evolved_species,
			"evolved_name": Global.get_monster_name(evolved_species),
		})
	var final_monster: Dictionary = roster[monster_uid]
	return {
		"uid": monster_uid,
		"exp_awarded": exp_amount,
		"old_level": old_level,
		"new_level": int(final_monster.get("level", old_level)),
		"levels_gained": levels_gained,
		"old_species": old_species,
		"new_species": int(final_monster.get("species", old_species)),
		"evolved_to": evolved_to,
		"old_exp": old_exp,
		"new_exp": int(final_monster.get("exp", old_exp)),
		"old_exp_to_next": exp_to_next_level(old_level),
		"new_exp_to_next": exp_to_next_level(int(final_monster.get("level", old_level))),
		"level_ups": level_ups,
		"total_stat_gains": total_stat_gains,
		"display_name": str(final_monster.get("name", "Unknown")),
		"texture": str(Global.monster_data.get(int(final_monster.get("species", old_species)), {}).get("texture", "")),
	}

func award_exp_to_party(amount: int) -> Dictionary:
	var summaries: Array = []
	for monster_uid in party:
		if not roster.has(monster_uid):
			continue
		if float(roster[monster_uid].get("hp", 0.0)) <= 0.0:
			continue
		summaries.append(grant_exp(monster_uid, amount))
	last_battle_rewards = {
		"exp": amount,
		"gold": 0,
		"summaries": summaries,
	}
	return last_battle_rewards.duplicate(true)

func award_battle_rewards(enemy_species: Array) -> Dictionary:
	var total_exp := 0
	for species in enemy_species:
		total_exp += int(Global.monster_data.get(int(species), {}).get("exp_yield", 12))
	total_exp = max(total_exp, 1)
	var summary := award_exp_to_party(total_exp)
	var gold_gain := int(round(float(total_exp) * 0.75))
	gold += gold_gain
	summary["gold"] = gold_gain
	last_battle_rewards = summary.duplicate(true)
	return summary

func compute_stats(uid: int) -> Dictionary:
	var inst: Dictionary = roster.get(uid, {})
	if inst.is_empty():
		return {}
	var species := int(inst.get("species", -1))
	if not Global.monster_data.has(species):
		return {}
	var level = max(int(inst.get("level", 1)), 1)
	var base: Dictionary = Global.monster_data[species]
	var max_hp := _compute_max_hp(base, level)
	max_hp += int(inst.get("hp_bonus", 0))
	var atk = int(base.get("atk", 5)) + level * 2
	var def = int(base.get("def", 5)) + level
	var spd = int(base.get("speed", 5)) + int(level * 0.5)
	atk += int(inst.get("atk_bonus", 0))
	def += int(inst.get("def_bonus", 0))
	spd += int(inst.get("spd_bonus", 0))
	var exp_current := int(inst.get("exp", 0))
	var exp_needed := exp_to_next_level(level)
	var evo: Dictionary = base.get("evolution", {})
	return {
		"max_hp": max_hp,
		"current_hp": float(inst.get("hp", max_hp)),
		"atk": atk,
		"def": def,
		"spd": spd,
		"lvl": level,
		"name": str(inst.get("name", base.get("name", "Unknown"))),
		"texture": str(base.get("texture", "")),
		"exp": exp_current,
		"exp_to_next": exp_needed,
		"exp_remaining": max(exp_needed - exp_current, 0),
		"can_evolve": can_evolve(uid),
		"evolution_level": int(evo.get("level", -1)),
		"evolution_species": int(evo.get("species", -1)),
		"evolution_name": Global.get_monster_name(int(evo.get("species", -1))),
	}

func heal_party_to_full() -> void:
	for monster_uid in party:
		if not roster.has(monster_uid):
			continue
		_heal_monster_to_full(monster_uid)

func build_random_encounter(island_id: String, node_id: String, event_key := "") -> Array:
	var island_tables: Dictionary = encounter_tables.get(island_id, {})
	var encounter_key := node_id if event_key.is_empty() else event_key
	var data: Dictionary = island_tables.get(encounter_key, {})
	if data.is_empty():
		return [Global.Monster.Test1]
	var count_min := int(data.get("count_min", 1))
	var count_max := int(data.get("count_max", count_min))
	var pool: Array = data.get("pool", [Global.Monster.Test1])
	var enemy_count := randi_range(count_min, count_max)
	var encounter: Array = []
	for _i in range(enemy_count):
		encounter.append(pool[randi_range(0, pool.size() - 1)])
	return encounter

func ensure_island_progress(island_id: String) -> void:
	if not island_metrics.has(island_id):
		island_metrics[island_id] = {
			"day_id": 0,
			"kills_total": 0,
			"fish_attempts_today": 0,
			"fish_unique_species": {},
			"nodes_visited_today": {},
			"nodes_visited_ever": {},
			"special": {},
		}
	var metrics: Dictionary = island_metrics[island_id]
	if not metrics.has("fish_attempts_today"):
		metrics["fish_attempts_today"] = 0
	if not metrics.has("special"):
		metrics["special"] = {}
	if not metrics.has("fish_unique_species"):
		metrics["fish_unique_species"] = {}
	if not metrics.has("nodes_visited_today"):
		metrics["nodes_visited_today"] = {}
	if not metrics.has("nodes_visited_ever"):
		metrics["nodes_visited_ever"] = {}
	island_metrics[island_id] = metrics
	if not quest_state.has(island_id):
		quest_state[island_id] = {
			"next_idx": 0,
			"turned_in": {},
		}

func advance_day(island_id: String) -> void:
	ensure_island_progress(island_id)
	island_metrics[island_id]["day_id"] = int(island_metrics[island_id]["day_id"]) + 1
	island_metrics[island_id]["nodes_visited_today"] = {}
	island_metrics[island_id]["fish_attempts_today"] = 0

func get_fishing_attempts_today(island_id: String) -> int:
	ensure_island_progress(island_id)
	return int(island_metrics[island_id].get("fish_attempts_today", 0))

func get_remaining_fishing_attempts(island_id: String) -> int:
	return max(DAILY_FISHING_LIMIT - get_fishing_attempts_today(island_id), 0)

func can_fish_today(island_id: String) -> bool:
	return get_fishing_attempts_today(island_id) < DAILY_FISHING_LIMIT

func consume_fishing_attempt(island_id: String) -> int:
	ensure_island_progress(island_id)
	var attempts := get_fishing_attempts_today(island_id) + 1
	island_metrics[island_id]["fish_attempts_today"] = attempts
	return attempts

func record_node_visited(island_id: String, node_id: String) -> Array:
	var before := _capture_quest_states(island_id, ["VISIT_ALL_DAY"])
	ensure_island_progress(island_id)
	(island_metrics[island_id]["nodes_visited_today"] as Dictionary)[node_id] = true
	(island_metrics[island_id]["nodes_visited_ever"] as Dictionary)[node_id] = true
	return _build_quest_notices(island_id, before, ["VISIT_ALL_DAY"])

func record_kills(island_id: String, amount: int = 1) -> Array:
	var before := _capture_quest_states(island_id, ["KILL"])
	ensure_island_progress(island_id)
	island_metrics[island_id]["kills_total"] = int(island_metrics[island_id]["kills_total"]) + amount
	return _build_quest_notices(island_id, before, ["KILL"])

func record_fished_monster(island_id: String, species_id: int) -> Array:
	var before := _capture_quest_states(island_id, ["FISH_UNIQUE"])
	ensure_island_progress(island_id)
	(island_metrics[island_id]["fish_unique_species"] as Dictionary)[species_id] = true
	return _build_quest_notices(island_id, before, ["FISH_UNIQUE"])

func get_visible_quests(island_id: String) -> Array:
	ensure_island_progress(island_id)
	var order: Array = quest_order.get(island_id, [])
	var idx := int(quest_state[island_id]["next_idx"])
	var turned: Dictionary = quest_state[island_id]["turned_in"]
	var out: Array = []
	var i := idx
	while i < order.size() and out.size() < MAX_ACTIVE_QUESTS:
		var qid := str(order[i])
		if not turned.has(qid):
			out.append(qid)
		i += 1
	return out

func is_quest_turned_in(island_id: String, qid: String) -> bool:
	ensure_island_progress(island_id)
	return (quest_state[island_id]["turned_in"] as Dictionary).has(qid)

func is_quest_ready(island_id: String, qid: String) -> bool:
	ensure_island_progress(island_id)
	if is_quest_turned_in(island_id, qid):
		return false
	var def: Dictionary = quest_defs.get(qid, {})
	var t := str(def.get("type", ""))
	var goal: Dictionary = def.get("goal", {})
	var m: Dictionary = island_metrics[island_id]
	match t:
		"KILL":
			return int(m.get("kills_total", 0)) >= int(goal.get("count", 0))
		"VISIT_ALL_DAY":
			var visited: Dictionary = m.get("nodes_visited_today", {})
			for n in goal.get("nodes", []):
				if not visited.has(str(n)):
					return false
			return true
		"FISH_UNIQUE":
			var uniq: Dictionary = m.get("fish_unique_species", {})
			return uniq.size() >= int(goal.get("count", 0))
		_:
			return false

func turn_in_quest(island_id: String, qid: String) -> bool:
	ensure_island_progress(island_id)
	if not is_quest_ready(island_id, qid):
		return false
	_grant_quest_rewards(qid)
	(quest_state[island_id]["turned_in"] as Dictionary)[qid] = true
	_advance_quest_pointer(island_id)
	return true

func _advance_quest_pointer(island_id: String) -> void:
	var order: Array = quest_order.get(island_id, [])
	var idx := int(quest_state[island_id]["next_idx"])
	var turned: Dictionary = quest_state[island_id]["turned_in"]
	while idx < order.size() and turned.has(str(order[idx])):
		idx += 1
	quest_state[island_id]["next_idx"] = idx

func _grant_quest_rewards(qid: String) -> void:
	var def: Dictionary = quest_defs.get(qid, {})
	var rewards: Dictionary = def.get("rewards", {})
	gold += int(rewards.get("gold", 0))

func _capture_quest_states(island_id: String, quest_types: Array[String]) -> Dictionary:
	ensure_island_progress(island_id)
	var snapshot: Dictionary = {}
	for qid in get_visible_quests(island_id):
		var def: Dictionary = quest_defs.get(str(qid), {})
		var quest_type := str(def.get("type", ""))
		if not quest_types.has(quest_type):
			continue
		snapshot[qid] = {
			"ready": is_quest_ready(island_id, str(qid)),
			"progress": _quest_progress_text(island_id, str(qid)),
		}
	return snapshot

func _build_quest_notices(island_id: String, before: Dictionary, quest_types: Array[String]) -> Array:
	var notices: Array = []
	for qid in get_visible_quests(island_id):
		var quest_id := str(qid)
		var def: Dictionary = quest_defs.get(quest_id, {})
		var quest_type := str(def.get("type", ""))
		if not quest_types.has(quest_type):
			continue
		var before_state: Dictionary = before.get(quest_id, {})
		var before_ready := bool(before_state.get("ready", false))
		var before_progress := str(before_state.get("progress", ""))
		var after_ready := is_quest_ready(island_id, quest_id)
		var after_progress := _quest_progress_text(island_id, quest_id)
		if after_ready and not before_ready:
			notices.append({
				"title": "Quest Complete",
				"text": "%s ready to turn in." % str(def.get("title", quest_id)),
				"is_complete": true,
			})
		elif after_progress != before_progress and not after_progress.is_empty():
			notices.append({
				"title": "Quest Progress",
				"text": "%s: %s" % [str(def.get("title", quest_id)), after_progress],
				"is_complete": false,
			})
	return notices

func _quest_progress_text(island_id: String, qid: String) -> String:
	var def: Dictionary = quest_defs.get(qid, {})
	var quest_type := str(def.get("type", ""))
	var goal: Dictionary = def.get("goal", {})
	var metrics: Dictionary = island_metrics.get(island_id, {})
	match quest_type:
		"KILL":
			var current_kills := int(metrics.get("kills_total", 0))
			var kill_goal := int(goal.get("count", 0))
			return "%d/%d defeated" % [min(current_kills, kill_goal), kill_goal]
		"VISIT_ALL_DAY":
			var visited: Dictionary = metrics.get("nodes_visited_today", {})
			var nodes: Array = goal.get("nodes", [])
			var current_nodes := 0
			for node in nodes:
				if visited.has(str(node)):
					current_nodes += 1
			return "%d/%d nodes" % [current_nodes, nodes.size()]
		"FISH_UNIQUE":
			var unique_species: Dictionary = metrics.get("fish_unique_species", {})
			var current_unique := unique_species.size()
			var unique_goal := int(goal.get("count", 0))
			return "%d/%d unique catches" % [min(current_unique, unique_goal), unique_goal]
		_:
			return ""

func _seed_debug_roster() -> void:
	for species in DEBUG_STARTER_SPECIES:
		new_monster(int(species), 1)

func _heal_monster_to_full(monster_uid: int) -> void:
	if not roster.has(monster_uid):
		return
	var stats := compute_stats(monster_uid)
	if stats.is_empty():
		return
	roster[monster_uid]["hp"] = float(stats["max_hp"])

func _compute_max_hp(base: Dictionary, level: int) -> int:
	return int(base.get("max health", 10)) + max(level - 1, 0) * 6

func _roll_level_up_gains() -> Dictionary:
	return {
		"hp": level_rng.randi_range(4, 8),
		"atk": level_rng.randi_range(1, 3),
		"def": level_rng.randi_range(1, 3),
		"spd": level_rng.randi_range(1, 2),
	}

func _build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"islands": islands.duplicate(true),
		"from_town": from_town,
		"pending_battle": pending_battle.duplicate(true),
		"next_uid": next_uid,
		"roster": roster.duplicate(true),
		"party": party.duplicate(),
		"island_metrics": island_metrics.duplicate(true),
		"quest_state": quest_state.duplicate(true),
		"gold": gold,
		"capture_inventory": capture_inventory.duplicate(true),
		"story_flags": story_flags.duplicate(true),
		"save_meta": save_meta.duplicate(true),
		"last_battle_rewards": last_battle_rewards.duplicate(true),
	}

func _apply_save_data(data: Dictionary) -> void:
	reset_state()
	islands = (data.get("islands", {}) as Dictionary).duplicate(true)
	from_town = bool(data.get("from_town", false))
	pending_battle = (data.get("pending_battle", {"island_id": "", "node_id": "", "return_scene": ""}) as Dictionary).duplicate(true)
	next_uid = max(int(data.get("next_uid", 1)), 1)
	roster = (data.get("roster", {}) as Dictionary).duplicate(true)
	party = []
	for uid in data.get("party", []):
		party.append(int(uid))
	island_metrics = (data.get("island_metrics", {}) as Dictionary).duplicate(true)
	quest_state = (data.get("quest_state", {}) as Dictionary).duplicate(true)
	gold = int(data.get("gold", DEFAULT_GOLD))
	capture_inventory = (data.get("capture_inventory", capture_inventory) as Dictionary).duplicate(true)
	story_flags = (data.get("story_flags", {}) as Dictionary).duplicate(true)
	save_meta = (data.get("save_meta", save_meta) as Dictionary).duplicate(true)
	last_battle_rewards = (data.get("last_battle_rewards", last_battle_rewards) as Dictionary).duplicate(true)
	ensure_island_progress(DEFAULT_ISLAND_ID)
