extends Control

@export var island_id: String = "hearthbay"
@export var slots_to_show := 3

@onready var vbox:VBoxContainer = $QuestControl/VBoxContainer

func _ready() -> void:
	GameState.ensure_island_progress(island_id)
	rebuild_quests()

#grab quests and display
func rebuild_quests() -> void:
	GameState.ensure_island_progress(island_id)
	var qids: Array = GameState.get_visible_quests(island_id)
	qids = qids.slice(0, min(slots_to_show, qids.size()))
	var children := $QuestControl/VBoxContainer.get_children()
	for i in range(children.size()):
		var btn := children[i] as Button
		if i<qids.size():
			print(btn)
			_fill_slot_button(btn, str(qids[i]))
			btn.visible = true
			btn.modulate.a = 1.0
		else:
			_set_slot_empty(btn)


func _fill_slot_button(slot_btn: Button, qid: String) -> void:
	var def: Dictionary = GameState.quest_defs.get(qid, {})
	var title := str(def.get("title", qid))
	var desc := str(def.get("desc", ""))
	var ready := GameState.is_quest_ready(island_id, qid)
	var name_desc: Label = slot_btn.get_node("name_desc") as Label
	var progress: Label = slot_btn.get_node("Label") as Label
	name_desc.text = "%s\n%s" % [title, desc]
	progress.text = _format_progress(qid)
	if ready:
		slot_btn.disabled = false
		slot_btn.modulate = Color(0.85, 1.0, 0.85)
	else:
		slot_btn.disabled = true
		slot_btn.modulate = Color(1, 1, 1)
	#rebind pressed to avoid multiple connections after rebuild
	_rebind_pressed(slot_btn, func(): 
		if GameState.turn_in_quest(island_id, qid): 
			rebuild_quests())

func _set_slot_empty(slot_btn: Button) -> void:
	print("empt")
	var name_desc: Label = slot_btn.get_node("name_desc") as Label
	var progress: Label = slot_btn.get_node("Label") as Label
	name_desc.text = ""
	progress.text = ""
	slot_btn.disabled = true
	slot_btn.modulate = Color(1, 1, 1, 0.25)

func _format_progress(qid: String) -> String:
	var def: Dictionary = GameState.quest_defs.get(qid)
	var t := str(def.get("type", ""))
	var goal: Dictionary = def.get("goal")
	var m: Dictionary = GameState.island_metrics.get(island_id)
	match t:
		"KILL":
			var cur := int(m.get("kills_total", 0))
			var need := int(goal.get("count", 0))
			return "Progress: %d/%d defeated" % [min(cur,need), need]
		"VISIT_ALL_DAY":
			var visited: Dictionary = m.get("nodes_visited_today")
			var nodes: Array = goal.get("nodes")
			var cur := 0
			for n in nodes:
				if visited.has(str(n)):
					cur += 1
			#change to display max
			return "Progress: %d/%d nodes (max)" % [cur, nodes.size()]
		"FISH_UNIQUE":
			var uniq: Dictionary = m.get("fish_unique_species")
			var cur := uniq.size()
			var need := int(goal.get("count"))
			return "Progress: %d/%d unique fished" % [min(cur,need), need]
		_:
			return ""

#remove prior connections so rebuild_quests() doesn't stack signals
func _rebind_pressed(btn: Button, cb: Callable) -> void:
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c["callable"])
	btn.pressed.connect(cb)
