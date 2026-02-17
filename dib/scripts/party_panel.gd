extends Control
#WIP

var selected_roster_uid: int = -1
var selected_party_slot: int = -1
@export var entry_scene: PackedScene = preload("res://scenes/monster_entry_button.tscn")
@onready var roster_vbox: VBoxContainer = $MonsterList/ScrollContainer/VBoxContainer

func _ready() -> void:
	_connect_party_slots()
	fill_party()
	rebuild_roster_list()

func _connect_party_slots() -> void:
	for i in range(4): #probably MAX_PARTY_SIZE
		var slot_btn := $Lineup/VBoxContainer.get_node("LineupSlot%d" % (i)) as Button
		slot_btn.pressed.connect(func(): _on_party_slot_pressed(i))

func fill_party():
	var slot = 0
	for i in $Lineup/VBoxContainer.get_children():
		if slot>(len(GameState.party)-1):
			break
		i.get_node("Icon").texture = load(Global.monster_data[GameState.party[slot]]["texture"])
		i.get_node("Desc").text = Global.monster_data[GameState.party[slot]]["name"] + "\nLevel: 0"
		slot+=1
	selected_stats(GameState.party[0])


func rebuild_roster_list() -> void:
	#clear old
	for c in roster_vbox.get_children():
		c.queue_free()
	var party_set := {}
	for uid in GameState.party:
		party_set[uid] = true
	#sort uids for stable order
	var uids: Array[int] = []
	for uid in GameState.roster.keys():
		uids.append(int(uid))
	uids.sort()
	for uid in uids:
		if party_set.has(uid):
			continue
		var entry := entry_scene.instantiate() as MonsterEntryButton
		roster_vbox.add_child(entry)
		entry.setup(uid)
		entry.chosen.connect(_on_roster_chosen)

func _on_roster_chosen(uid: int) -> void:
	selected_roster_uid = uid
	selected_party_slot = -1
	selected_stats(uid)

func _on_party_slot_pressed(slot_idx: int) -> void:
	if selected_roster_uid == -1:
		if slot_idx < GameState.party.size():
			selected_stats(GameState.party[slot_idx])
		return
	#debugging
	print(slot_idx)
	_swap_into_party(slot_idx, selected_roster_uid)
	selected_roster_uid = -1
	fill_party()
	rebuild_roster_list()

func _swap_into_party(slot_idx: int, roster_uid: int) -> void:
	#if slot exists, swap out party monster to roster 
	if slot_idx < GameState.party.size():
		var old_party_uid := GameState.party[slot_idx]
		GameState.party[slot_idx] = roster_uid
		#old_party_uid automatically becomes "not in party" so it will appear in roster list
	else:
		#allow adding to empty slot if unlocked
		if GameState.party.size() < GameState.MAX_PARTY_SIZE:
			GameState.party.append(roster_uid)
	#ensure uniqueness
	_dedupe_party()

func _dedupe_party() -> void:
	var seen := {}
	var out: Array[int] = []
	for uid in GameState.party:
		if seen.has(uid): continue
		seen[uid] = true
		out.append(uid)
	GameState.party = out


func selected_stats(uid: int):
	var stats = GameState.compute_stats(uid)
	$SelectedInfo/Icon.texture = load(stats["texture"])
	$SelectedInfo/name.text = str(stats['name'])
	$"SelectedInfo/right stats".text = str(stats['lvl'])+"\n"+str(stats['atk'])+"\n"+str(stats['def'])+"\n"+str(stats['spd'])
	$SelectedInfo/left.text = "\nHP: "+str(stats['max_hp'])+"\nXP:\nItem Slots"
	pass
