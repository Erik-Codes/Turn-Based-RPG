extends Control
#WIP


@export var entry_scene: PackedScene = preload("res://scenes/monster_entry_button.tscn")
@onready var roster_vbox: VBoxContainer = $MonsterList/ScrollContainer/VBoxContainer
@onready var lineup_parent: Control = $Lineup/VBoxContainer

var selected_kind := ""
var selected_index := -1
var selected_uid := -1

func _ready() -> void:
	selected_stats(GameState.party[0])
	rebuild_lineup()
	rebuild_roster()


func rebuild_lineup() -> void:
	for c in lineup_parent.get_children():
		c.queue_free()
	var unlocked := int(GameState.MAX_PARTY_SIZE)
	for slot in range(4):
		var locked := slot >= unlocked
		var uid := -1
		#4th slot unlockable later
		if not locked and slot < GameState.party.size():
			uid = GameState.party[slot]
		var entry := entry_scene.instantiate() as MonsterEntryButton
		lineup_parent.add_child(entry)
		entry.setup("party", slot, uid)
		entry.chosen.connect(_on_entry_chosen)
		entry.dropped.connect(_on_entry_dropped)


func rebuild_roster() -> void:
	for c in roster_vbox.get_children():
		c.queue_free()
	var party_set := {}
	for uid in GameState.party:
		party_set[uid] = true
	var uids: Array[int] = []
	for k in GameState.roster.keys():
		uids.append(int(k))
	uids.sort()
	for uid in uids:
		if party_set.has(uid):
			continue
		var entry := entry_scene.instantiate() as MonsterEntryButton
		roster_vbox.add_child(entry)
		entry.setup("roster", -1, uid)
		entry.chosen.connect(_on_entry_chosen)
		entry.dropped.connect(_on_entry_dropped)


func _on_entry_chosen(kind: String, index: int, uid: int) -> void:
	#first click selects; maybe make it so they have to drag to swap instead, bc just clicking thru to see stats will cause swaps
	if selected_uid == -1 and uid != -1:
		selected_kind = kind
		selected_index = index
		selected_uid = uid
		selected_stats(uid)
		_clear_selection()
		return


func _execute_swap(k1: String, i1: int, u1: int, k2: String, i2: int, u2: int) -> void:
	if k2 == "party" and i2 >= int(GameState.MAX_PARTY_SIZE):
		return
	if k1 == "party" and i1 >= int(GameState.MAX_PARTY_SIZE):
		return
	#party <-> roster
	if k1 == "party" and k2 == "roster":
		GameState.party[i1] = u2
		return
	if k1 == "roster" and k2 == "party":
		GameState.party[i2] = u1
		return
	#party <-> party reorder; doesn't matter for ordering or anything but people may want to have their specific ordering
	if k1 == "party" and k2 == "party":
		var tmp := GameState.party[i1]
		GameState.party[i1] = GameState.party[i2]
		GameState.party[i2] = tmp
		return

func _clear_selection() -> void:
	selected_kind = ""
	selected_index = -1
	selected_uid = -1

func _on_entry_dropped(sk: String, si: int, su: int, dk: String, di: int, du: int) -> void:
	_execute_swap(sk, si, su, dk, di, du)
	_clear_selection()
	rebuild_lineup()
	rebuild_roster()


func selected_stats(uid: int):
	var stats = GameState.compute_stats(uid)
	$SelectedInfo/Icon.texture = load(stats["texture"])
	$SelectedInfo/name.text = str(stats['name'])
	$"SelectedInfo/right stats".text = str(stats['lvl'])+"\n"+str(stats['atk'])+"\n"+str(stats['def'])+"\n"+str(stats['spd'])
	$SelectedInfo/left.text = "\nHP: "+str(stats['max_hp'])+"\nXP:\nItem Slots"
	pass
