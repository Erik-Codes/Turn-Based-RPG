extends Control

enum TargetMode {NONE, ENEMY, ALLY, SELF, CAPTURE}

var pending_attack: Global.Attack = -1
var target_mode: TargetMode = TargetMode.NONE
var selected_target_uid: int = -1

var timeline: BattleTimeline
var current_entry: Dictionary

var _uid_counter := 0
var _uid_to_handler: Dictionary = {}  #uid -> Control node (PlayerHandlerX / MonsterHandlerX)
var _uid_to_stats: Dictionary = {} #uid -> Stats node (PlayerStats or MonsterStats)
var rng = RandomNumberGenerator.new()

var enemy_roster: Array = []
var next_enemy_idx: int = 0
var enemy_handlers: Array[Control]
var _enemy_entries: Array = []
var visible_count

var _queue_row_by_uid: Dictionary = {}      #uid -> Control row node
var _queue_uid_by_row: Dictionary = {}      #Control row node -> uid
var _dying_uids: Dictionary = {} #uid -> true (use Dictionary as a set)
@export var queue_row_height := 55.0
@export var queue_row_spacing := 6.0
@export var queue_top_padding := 0.0

var _queue_hp_tweens: Dictionary = {} #uid -> Tween

var _busy_count: int = 0
signal battle_idle

#prevent certain actions (e.g. starting turns too early)
func _begin_busy() -> void:
	_busy_count += 1

func _end_busy() -> void:
	_busy_count = max(_busy_count-1, 0)
	if _busy_count == 0:
		battle_idle.emit()

func _wait_until_idle() -> void:
	while _busy_count > 0:
		await battle_idle

#func _notification(what):
	#if what == NOTIFICATION_RESIZED:
		#_layout_bottom_players()


func _new_uid() -> int:
	_uid_counter += 1
	return _uid_counter

func _ready():
	_uid_counter=0
	_uid_to_handler.clear()
	_uid_to_stats.clear()
	_enemy_entries.clear()
	$"battle menu".hide()
	$Turn_order.hide()
	player_setup()
	enemy_setup()
	await ScreenTransition.fade_in(0.5)
	await play_enemy_drop_in_sequence(visible_count)
	order_setup()
	await get_tree().process_frame
	_animate_turn_order_to_new_state(true)
	update_remaining()
	connect_swipes()
	start_next_turn()

func player_setup():
	#Reset all 4 slots to empty
	for slot in range(4):
		var plyr := "PlayerHandler%d" % (slot)
		var handler: Control = $Players/HB.get_node(plyr)
		#Empty placeholder
		handler.get_node("Player").texture = load("res://graphics/test/green_hatchling-resized-to-210x263-removebg-preview.png")
		handler.get_node("Player").modulate = Color(0, 0, 0, 0) # hidden
		handler.get_node("PlayerStats").hide()
		handler.get_node("Label").hide()
	#Fill slots 0..party.size-1 only (NO compressing)
	for slot in range(min(4, GameState.party.size())):
		var plyr := "PlayerHandler%d" % (slot)
		var handler: Control = $Players/HB.get_node(plyr)
		var monster_uid: int = GameState.party[slot]  # party stores instance uids
		var inst: Dictionary = GameState.roster.get(monster_uid, {})
		if inst.is_empty():
			#leave as empty placeholder
			continue
		var species_id: int = int(inst["species"])
		var hp := float(inst.get("hp", 0))
		#always display the correct sprite in that slot (alive or dead)
		handler.get_node("Player").texture = load(Global.monster_data[species_id]["texture"])
		handler.get_node("Player").modulate = Color(1, 1, 1, 1)
		# Dead=greyed, no stats, no label
		if hp <= 0.0:
			handler.get_node("Player").modulate = Color(0.6, 0.6, 0.6, 0)
			handler.get_node("PlayerStats").hide()
			handler.get_node("Label").hide()
			continue
		#Alive=create battle uid + stats
		var battle_uid := _new_uid()
		_uid_to_handler[battle_uid] = handler
		var stats = handler.get_node("PlayerStats")
		stats.show()
		stats.setup(species_id, true, battle_uid, -1, monster_uid)
		_uid_to_stats[battle_uid] = stats
		#HP label for alive only
		handler.get_node("Label").show()
		#handler.get_node("Label").text = "%d" % int(hp)
		if not stats.defeat.is_connected(_on_unit_defeat):
			stats.defeat.connect(_on_unit_defeat)
		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)

func enemy_setup():
	_enemy_entries.clear()
	enemy_roster = Global.encounter.duplicate()
	enemy_handlers = [
	$Enemies/HB/MonsterHandler,
	$Enemies/HB/MonsterHandler2,
	$Enemies/HB/MonsterHandler3]
	next_enemy_idx = 0
	visible_count = min(enemy_roster.size(), 3)
	apply_enemy_layout(visible_count)
	for slot in range(3):
		var h: Control = enemy_handlers[slot]
		#h.visible = slot < visible_count
		h.visible = false
		h.get_node("MonsterStats").hide()
		h.get_node("Control/HoverRoot").stop_hover()
	#spawn up to 3 into slots (VISUALS ONLY)
	for slot in range(visible_count):
		var id: int = enemy_roster[next_enemy_idx]
		next_enemy_idx += 1
		_spawn_enemy_visual_only(slot, id)

func apply_enemy_layout(_visible_count: int) -> void:
	var h0: Control = enemy_handlers[0]
	var h1: Control = enemy_handlers[1]
	var h2: Control = enemy_handlers[2]
	match _visible_count:
		1:
			_set_enemy_slot(h0, 0.2, 0.7) #centered ~45%
			h1.visible = false
			h2.visible = false
		2:
			_set_enemy_slot(h0, 0.1, 0.5)   #left 45%
			_set_enemy_slot(h1, 0.5, 0.9)   #right 45%
			h2.visible = false
		_:
			_set_enemy_slot(h0, 0.1, 0.4)
			_set_enemy_slot(h1, 0.4, 0.7)
			_set_enemy_slot(h2, 0.7, 1.00)
			h1.visible = true
			h2.visible = true

func _set_enemy_slot(h: Control, left: float, right: float) -> void:
	h.anchor_left = left
	h.anchor_right = right
	h.anchor_top = 0.0
	h.anchor_bottom = 0.8
	h.offset_left = 0
	h.offset_right = 0
	h.offset_top = 0
	h.offset_bottom = 0

func _spawn_enemy_visual_only(slot_index: int, monster_id: int) -> void:
	var handler: Control = enemy_handlers[slot_index]
	var uid := _new_uid()
	_uid_to_handler[uid] = handler
	handler.get_node("Control/HoverRoot/ZoomRoot/Enemy").texture = load(Global.monster_data[monster_id]["texture"])
	var stats = handler.get_node("MonsterStats")
	stats.setup(monster_id, false, uid, slot_index)
	_uid_to_stats[uid] = stats
	var swipe: SwipeDetector = handler.get_node("Control5")
	swipe.set_uid(uid)
	if not swipe.tapped.is_connected(_on_target_tapped):
		swipe.tapped.connect(_on_target_tapped)
	if not stats.defeat.is_connected(_on_unit_defeat):
		stats.defeat.connect(_on_unit_defeat)
	if not stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.connect(_on_hp_changed)
	handler.show()
	_enemy_entries.append({
		"uid": uid,
		"id": monster_id,
		"is_enemy": true,
		"slot": slot_index,
		"speed": Global.monster_data[monster_id]['speed'] * randf_range(0.5,1.2),
		#"time_left": Global.monster_data[monster_id]['speed'] * randf_range(0.5,1.2)
		#set to 50 for testing
		"time_left":50
	})

func play_enemy_drop_in_sequence(_visible_count) -> void:
	for slot in range(_visible_count):
		var h: Control = enemy_handlers[slot]
		#if !h.visible:
			#continue
		var hover: HoverAnim = h.get_node("Control/HoverRoot") as HoverAnim
		h.get_node("MonsterStats").hide()
		if _visible_count == 1:
			hover.set_anim_speed(0.5)
		else:
			hover.set_anim_speed(0.67)
		await hover.play_drop_in()
		hover.set_anim_speed(0.67)
	for slot in range(_visible_count):
		var h: Control = enemy_handlers[slot]
		#if !h.visible:
			#continue
		var hover: HoverAnim = h.get_node("Control/HoverRoot") as HoverAnim
		h.get_node("MonsterStats").show()
		if _visible_count == 1:
			await get_tree().create_timer(0.3).timeout
		hover.start_hover()



func order_setup():
	var entries: Array = []
	#Players
	for handler in $Players/HB.get_children():
		if handler.name == "Control" or handler.name == "Control2":
			continue
		var stats = handler.get_node("PlayerStats")
		if stats.get_hp()>0.0:
			entries.append({
				"uid": stats.uid,
				"id": stats.monster_id,
				"monster_uid": stats.monster_uid,
				"is_enemy": false,
				"speed": 10,
				"time_left": 10
				})
	for e in _enemy_entries:
		entries.append(e)
	timeline = BattleTimeline.new()
	add_child(timeline)
	timeline.init(entries)
	_animate_turn_order_to_new_state()




func connect_swipes():
	for handler in $Enemies/HB.get_children():
		var swipe: SwipeDetector = handler.get_node("Control5")
		if not swipe.swiped.is_connected(handle_swipe):
			swipe.swiped.connect(handle_swipe)

func _queue_target_pos(index: int) -> Vector2:
	return Vector2(0.0, queue_top_padding + index * (queue_row_height + queue_row_spacing))



func _on_target_tapped(target_uid: int) -> void:
	#Only allow tapping while targeting an enemy
	if target_mode != TargetMode.ENEMY:
		return
	if pending_attack == -1:
		return
	if not _uid_to_handler.has(target_uid):
		return
	if not (_uid_to_handler[target_uid] as Control).visible:
		return
	#Apply attack to that exact enemy
	perform_attack_on_uid(target_uid, pending_attack)
	$TapOverlayLabel.hide()
	_end_player_action(pending_attack)

func _on_hp_changed(uid: int, hp: float, max_hp: float) -> void:
	_animate_queue_hp(uid, hp, max_hp)


func _animate_queue_hp(uid: int, hp: float, max_hp: float) -> void:
	#Row mapping must exist (uid is currently displayed)
	if not _queue_row_by_uid.has(uid):
		return
	var row: Control = _queue_row_by_uid[uid]
	var hp_bar := row.get_node("VBoxContainer/ColorRect") as TextureProgressBar
	hp_bar.max_value = max_hp
	#Kill existing tween for this uid
	if _queue_hp_tweens.has(uid):
		var old: Tween = _queue_hp_tweens[uid]
		if old and old.is_running():
			old.kill()
		_queue_hp_tweens.erase(uid)
	#Tween to new hp
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(hp_bar, "value", hp, 0.20)
	_queue_hp_tweens[uid] = t



func start_next_turn():
	await _wait_until_idle()
	if not _has_alive_enemies():
		return
	$PlayerAttack.hide()
	#Get next (remove from queue)
	while true:
		if timeline.queue.is_empty():
			return
		current_entry = timeline.pop_next()
		var uid := int(current_entry.get("uid", -1))
		if _is_uid_alive(uid):
			break
		current_entry = {}
	_animate_turn_order_to_new_state()
	await get_tree().create_timer(0.3).timeout
	if current_entry["is_enemy"]:
		#delay before enemy acts
		await get_tree().create_timer(0.5).timeout
		var atk: Global.Attack = Global.Attack.AT2 
		var target_uid := choose_random_alive_player_uid()
		if target_uid != -1:
			perform_attack_on_uid(target_uid, atk)
		timeline.commit(current_entry, action_cost(current_entry, atk))
		await do_enemy_attack_with_anim(current_entry, atk)
		_animate_turn_order_to_new_state()
		await _wait_until_idle()
		call_deferred("start_next_turn")
		return
	#Player turn
	Global.current_monster = current_entry.get("monster_uid", -1); 
	$PlayerAttack/Control/TextureRect.texture = load(Global.monster_data[Global.current_monster]['texture'])
	show_current_player_box()
	$"battle menu".current_state = Global.State.ATTACK
	$"battle menu".refresh()
	$"battle menu".current_monst = int(current_entry.get("monster_uid", -1))
	$"battle menu".current_state = Global.State.ATTACK

func order_update():
	for i in range(len(Global.encounter)):
		var cntrl_name = "Control" if i==0 else "Control%d" %(i+1)
		var cntrl = $Turn_order.get_node("%s" % cntrl_name) as Control
		var label = cntrl.get_node("VBoxContainer/HBoxContainer/Label") as Label
		label.text = "%d" %Global.monster_data[Global.encounter[i]]['max health']
		var txtr = cntrl.get_node("VBoxContainer/HBoxContainer/ColorRect") as TextureRect
		txtr.texture = load(Global.monster_data[Global.encounter[i]]['texture'])

func action_cost(_entry: Dictionary, attack_type: Global.Attack) -> float:
	var base_tu = float(Global.attack_data[attack_type]["TU"])
	#will be multiplied by and haste/slow effects
	return base_tu

func _on_battle_menu_selected(state, type):
	if state != Global.State.ATTACK:
		return
	var atk: Global.Attack = type
	pending_attack = atk
	#If this attack does NOT need a target (self/status), resolve immediately
	#attack_data['target'] == 0 for self-type actions; change to TargetType
	if int(Global.attack_data[atk]["target"]) == 0:
		#Apply to self (current actor)
		toggle_players_vis()
		await perform_attack_on_uid(int(current_entry["uid"]), atk)
		_end_player_action(atk)
		return
	#Else= enter enemy targeting mode; adding ally targeting later
	target_mode = TargetMode.ENEMY
	$"battle menu".hide()
	$TapOverlayLabel.show()

func _end_player_action(atk: Global.Attack) -> void:
	timeline.commit(current_entry, action_cost(current_entry, atk))
	current_entry = {}
	target_mode = TargetMode.NONE
	_animate_turn_order_to_new_state()
	await get_tree().create_timer(0.7).timeout
	await _wait_until_idle()
	call_deferred("start_next_turn")



func handle_swipe(dir: String, uid) -> void:
	if $"battle menu".visible == false:
		return
	if $"battle menu".current_state != Global.State.ATTACK:
		return
	var idx 
	var attacks = Global.monster_data[Global.current_monster]["attacks"]
	for a in range(len(Global.monster_data[Global.current_monster]["attacks"])):
		if dir == Global.attack_data[attacks[a]]['dir']:
			idx = a
	if idx==null:
		return
	await perform_attack_on_uid(uid,attacks[idx])
	_end_player_action(attacks[idx])



func start_targeting_enemies() -> void:
	#show a UI hint
	$TapOverlayLabel.text = "Select a target"
	$TapOverlayLabel.show()

func _get_player_handler_by_uid(uid: int) -> Control:
	for h in $Players/HB.get_children():
		if h.name == "Control" or h.name == "Control2" or !h.get_node("PlayerStats").visible:
			continue
		if h.has_node("PlayerStats") and int(h.get_node("PlayerStats").uid) == uid:
			return h
	return null

func show_current_player_box() -> void:
	#Clear old display
	for c in $CurrentPlayer.get_children():
		$CurrentPlayer.remove_child(c)
		c.free()
	var src: Control = _get_player_handler_by_uid(int(current_entry["uid"]))
	if src == null:
		return
	var copy: Control = src.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	copy.name = "CurrentPlayerDisplay"
	$CurrentPlayer.add_child(copy)
	#Make the copy fill the CurrentPlayer box
	copy.set_anchors_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = 0
	copy.offset_top = 0
	copy.offset_right = 0
	copy.offset_bottom = 0
	#Ensure PlayerStats is visible and positioned inside the box
	toggle_players_vis()
	$CurrentPlayer.show()
	if copy.has_node("PlayerStats"):
		var stats := copy.get_node("PlayerStats") as Control
		stats.show()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_unit_defeat(uid: int) -> void:
	_begin_busy()
	#figure out slot before erasing
	var slot_index := -1
	if _uid_to_stats.has(uid):
		slot_index = int(_uid_to_stats[uid].slot_index)
	if current_entry and int(current_entry.get("uid", -1)) == uid:
		current_entry = {}
	#remove dead from timeline + maps
	timeline.remove_uid(uid)
	_uid_to_handler.erase(uid)
	_uid_to_stats.erase(uid)
	#animate queue death 
	if slot_index == -1 and get_alive_player_handlers() == 0:
		_end_busy()
		finish_battle(false)
		return
	await get_tree().create_timer(0.4).timeout
	await animate_queue_death(uid)
	#hide the handler content 
	if slot_index != -1:
		var handler: Control = enemy_handlers[slot_index]
		handler.visible = false
		#If there are more enemies to spawn, spawn immediately into that slot
		if _has_enemies_remaining_to_spawn():
			await get_tree().create_timer(0.2).timeout
			var next_id: int = enemy_roster[next_enemy_idx]
			next_enemy_idx += 1
			update_remaining()
			await spawn_enemy_into_slot(slot_index, next_id)
			_animate_turn_order_to_new_state()
			_end_busy()
			return
		#No more enemies to spawn: if none alive, win
		if not _has_alive_enemies():
			_end_busy()
			finish_battle(true)
			return
	_end_busy()

func get_alive_player_handlers() -> int:
	var count := 0
	for uid in _uid_to_stats.keys():
		var stats = _uid_to_stats[uid]
		if stats.is_player and stats.get_hp() > 0:
			count += 1
	return count

func _has_alive_enemies() -> bool:
	for uid in _uid_to_stats.keys():
		var stats = _uid_to_stats[uid]
		if not stats.is_player and stats.get_hp() > 0:
			return true
	return false

func _has_enemies_remaining_to_spawn() -> bool:
	return next_enemy_idx < enemy_roster.size()


func _is_uid_alive(uid: int) -> bool:
	if uid <= 0:
		return false
	if not _uid_to_stats.has(uid):
		return false
	var stats = _uid_to_stats[uid]
	if stats.get_hp() <= 0:
		return false
	if _uid_to_handler.has(uid) and not (_uid_to_handler[uid] as Control).visible:
		return false
	return true


func do_enemy_attack_with_anim(entry: Dictionary, _atk: Global.Attack) -> void:
	#Animate enemy zoom
	var handler: Control = _uid_to_handler[int(entry["uid"])]
	var zoom: BattlerZoomRoot = handler.get_node("Control/HoverRoot/ZoomRoot")
	await zoom.attack_zoom()
	await get_tree().create_timer(0.15).timeout

func do_player_attack_with_anim(enemy:Control) -> void:
	toggle_players_vis()
	$PlayerAttack.show()
	$PlayerAttack/AnimationPlayer.play('attack')
	await get_tree().create_timer(0.1).timeout
	enemy.get_node("Control/HoverRoot/ZoomRoot/AnimationPlayer").play('atk')

func perform_attack_on_uid(target_uid: int, attack_type: Global.Attack) -> void:
	var data: Dictionary = Global.attack_data[attack_type]
	#Find the correct stats node and apply
	if not _uid_to_handler.has(target_uid):
		return
	var handler: Control = _uid_to_handler[target_uid]
	if handler.has_node("MonsterStats"):
		do_player_attack_with_anim(handler)
		await get_tree().create_timer(0.2).timeout
		handler.get_node("MonsterStats").update(data)
		await get_tree().create_timer(0.5).timeout
	elif handler.has_node("PlayerStats"):
		#await do_player_attack_with_anim(), modify for ally targets
		handler.get_node("PlayerStats").update(data)

func toggle_players_vis():
	var ele = [$Players,$"battle menu",$CurrentPlayer,$UiFrame/Control/ui9]
	for e in ele:
		e.visible = true if !e.visible else false

func choose_random_alive_player_uid() -> int:
	var alive: Array = []
	for h in $Players/HB.get_children():
		if h.name == "Control" or h.name == "Control2" or !h.get_node("PlayerStats").visible:
			continue
		if h.visible:
			var stats = h.get_node("PlayerStats")
			alive.append(int(stats.uid))
	return -1 if alive.is_empty() else alive.pick_random()


func spawn_enemy_into_slot(slot_index: int, monster_id: int) -> void:
	var handler: Control = enemy_handlers[slot_index]
	#hide while we configure + set start pose
	handler.visible = false
	var uid = _new_uid()
	_uid_to_handler[uid] = handler
	#sprite + stats setup
	handler.get_node("Control/HoverRoot/ZoomRoot/Enemy").texture = load(Global.monster_data[monster_id]["texture"])
	var stats = handler.get_node("MonsterStats")
	stats.setup(monster_id, false, uid, slot_index)
	_uid_to_stats[uid] = stats
	stats.hide()
	var swipe: SwipeDetector = handler.get_node("Control5")
	swipe.set_uid(uid)
	if not swipe.tapped.is_connected(_on_target_tapped):
		swipe.tapped.connect(_on_target_tapped)
	if not stats.defeat.is_connected(_on_unit_defeat):
		stats.defeat.connect(_on_unit_defeat)
	if not stats.hp_changed.is_connected(_on_hp_changed):
		stats.hp_changed.connect(_on_hp_changed)
	#Set drop-in
	var hover: HoverAnim = handler.get_node("Control/HoverRoot") as HoverAnim
	hover.stop_hover()
	handler.visible = false
	hover.set_drop_in_start_pose()
	#Now show and play
	handler.visible = true
	await get_tree().process_frame  #ensures start pose is rendered first
	await hover.play_drop_in()
	stats.show()
	await get_tree().create_timer(0.2).timeout
	stats.modulate = Color(1,1,1,1)
	hover.start_hover()
	#timeline entry
	timeline.add_entry({
		"uid": uid,
		"id": monster_id,
		"is_enemy": true,
		"slot": slot_index,
		"time_left": 80.0,
		"speed":80
	})
	_animate_turn_order_to_new_state()

func update_remaining():
	if next_enemy_idx<enemy_roster.size():
		$EnemiesRemaining.text = str(enemy_roster.size()-next_enemy_idx)
		$EnemiesRemaining.show()
	else:
		$EnemiesRemaining.hide()

func _get_ordered_uids_for_display() -> Array[int]:
	var ordered: Array = []
	if current_entry and current_entry.size() > 0:
		ordered.append(current_entry)
	var rest := timeline.queue.duplicate()
	rest.sort_custom(func(a, b): return float(a["time_left"]) < float(b["time_left"]))
	for e in rest:
		ordered.append(e)
	var uids: Array[int] = []
	for i in range(min(6, ordered.size())):
		uids.append(int(ordered[i]["uid"]))
	return uids

func _get_entry_for_uid(uid: int) -> Dictionary:
	if current_entry and int(current_entry.get("uid", -1)) == uid:
		return current_entry
	for e in timeline.queue:
		if int(e["uid"]) == uid:
			return e
	return {}

func _get_free_row() -> Control:
	for i in range(6):
		var slot_name := "Control" if i == 0 else "Control%d" % (i + 1)
		var row := $Turn_order.get_node(slot_name) as Control
		if not _queue_uid_by_row.has(row):
			return row
	return $Turn_order.get_node("Control6") as Control


func _update_row_visuals(row: Control, uid: int, index: int) -> void:
	var entry := _get_entry_for_uid(uid)
	if entry.is_empty():
		row.visible = false
		return
	row.visible = true
	var monster_id := int(entry["id"])
	var tu_remaining := 0.0
	if index != 0:
		tu_remaining = max(float(entry["time_left"]) - float(timeline.time), 0.0)
	var portrait := row.get_node("VBoxContainer/HBoxContainer/ColorRect") as TextureRect
	var tu_label := row.get_node("VBoxContainer/HBoxContainer/Label") as Label
	var hp_bar := row.get_node("VBoxContainer/ColorRect") as TextureProgressBar
	portrait.texture = load(Global.monster_data[monster_id]["texture"])
	tu_label.text = "%0.0f" % tu_remaining
	if entry.get("is_enemy", false):
		match int(entry.get("slot", -1)):
			0: tu_label.add_theme_color_override("font_color", Color(1, 0, 0))
			1: tu_label.add_theme_color_override("font_color", Color(0, 1, 0))
			2: tu_label.add_theme_color_override("font_color", Color(0, 0, 1))
			_: tu_label.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		tu_label.add_theme_color_override("font_color", Color(1, 1, 1))
	if _uid_to_stats.has(uid):
		var stats = _uid_to_stats[uid]
		hp_bar.max_value = stats.get_max_hp()
		hp_bar.value = stats.get_hp()
	else:
		hp_bar.max_value = 1
		hp_bar.value = 0

func _animate_turn_order_to_new_state(snap := false) -> void:
	$Turn_order.show()
	var desired_uids := _get_ordered_uids_for_display()
	desired_uids = _filter_not_dying(desired_uids)
	desired_uids = desired_uids.filter(func(u): return not _dying_uids.has(u))
	_prune_queue_rows(desired_uids)
	#Assign initial mapping if empty
	if _queue_row_by_uid.is_empty():
		for i in range(6):
			var slot_name := "Control" if i == 0 else "Control%d" % (i + 1)
			var row := $Turn_order.get_node(slot_name) as Control
			if i >= desired_uids.size():
				row.visible = false
				continue
			var uid := desired_uids[i]
			if _dying_uids.has(uid):
				continue
			_queue_row_by_uid[uid] = row
			_queue_uid_by_row[row] = uid
			row.position = _queue_target_pos(i)
			_update_row_visuals(row, uid, i)
		return
	#Ensure each desired uid has a row
	for uid in desired_uids:
		if not _queue_row_by_uid.has(uid):
			var row := _get_free_row()
			_queue_row_by_uid[uid] = row
			_queue_uid_by_row[row] = uid
			row.visible = true
			row.modulate.a = 0.0
			row.scale = Vector2(0.85, 0.85)
	var t: Tween = null
	if not snap:
		t = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(desired_uids.size()):
		var uid := desired_uids[i]
		var row: Control = _queue_row_by_uid[uid]
		var target_pos := _queue_target_pos(i)
		_update_row_visuals(row, uid, i)
		if snap:
			row.position = target_pos
			row.modulate.a = 1.0
			row.scale = Vector2.ONE
		else:
			t.tween_property(row, "position", target_pos, 0.18)
			if row.modulate.a < 1.0:
				t.tween_property(row, "modulate:a", 1.0, 0.18)
				t.tween_property(row, "scale", Vector2.ONE, 0.18)
	#Hide rows not in top 6
	for uid in _queue_row_by_uid.keys():
		if uid in desired_uids:
			continue
		var row: Control = _queue_row_by_uid[uid]
		_queue_row_by_uid.erase(uid)
		_queue_uid_by_row.erase(row)
		row.visible = false

func animate_queue_death(uid: int) -> void:
	if not _queue_row_by_uid.has(uid):
		return
	#Grab the real row currently representing this uid
	var row: Control = _queue_row_by_uid[uid]
	#Create a ghost copy that will animate independently
	var ghost := row.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as Control
	ghost.name = "QueueDeathGhost_%d" % uid
	ghost.position = row.position
	ghost.visible = true
	ghost.z_as_relative = false
	#ghost.z_index = 1000
	$Turn_order_deaths.add_child(ghost)
	row.visible = false
	var t1 := create_tween()
	t1.set_trans(Tween.TRANS_SINE)
	t1.set_ease(Tween.EASE_IN_OUT)
	var p1 := ghost.position + Vector2(-20.0, 25.0)
	t1.tween_property(ghost, "position", p1, 0.4)
	await t1.finished
	#Remove mapping so queue rows can be reassigned/moved
	_queue_row_by_uid.erase(uid)
	_queue_uid_by_row.erase(row)
	#Kill any HP tween tied to this uid
	if _queue_hp_tweens.has(uid):
		var old: Tween = _queue_hp_tweens[uid]
		if old and old.is_running():
			old.kill()
		_queue_hp_tweens.erase(uid)
	#Reflow the queue now
	_animate_turn_order_to_new_state()
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.set_trans(Tween.TRANS_SINE)
	t2.set_ease(Tween.EASE_IN)
	var p2 := ghost.position + Vector2(-25.0, 400.0)
	t2.tween_property(ghost, "position", p2, 0.5)
	t2.tween_property(ghost, "scale", Vector2(0.35, 0.35), 0.5)
	t2.tween_property(ghost, "modulate:a", 0.0, 0.5)
	await t2.finished
	ghost.queue_free()

func _prune_queue_rows(desired_uids: Array[int]) -> void:
	#make a set for fast lookup
	var desired_set := {}
	for u in desired_uids:
		desired_set[u] = true
	#remove any uid->row mapping not in desired
	for uid in _queue_row_by_uid.keys():
		if _queue_hp_tweens.has(uid):
			var tw: Tween = _queue_hp_tweens[uid]
			if tw and tw.is_running():
				tw.kill()
			_queue_hp_tweens.erase(uid)
		if not desired_set.has(uid):
			var row: Control = _queue_row_by_uid[uid]
			_queue_row_by_uid.erase(uid)
			_queue_uid_by_row.erase(row)
			row.visible = false
			row.modulate.a = 1.0
			row.scale = Vector2.ONE

func _filter_not_dying(arr: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for u in arr:
		if not _dying_uids.has(u):
			out.append(u)
	return out


func finish_battle(player_won: bool) -> void:
	var island_id = GameState.pending_battle["island_id"]
	var node_id = GameState.pending_battle["node_id"]
	var return_scene = GameState.pending_battle["return_scene"]

	if player_won:
		#GameState.inc_node_clears(island_id, node_id) # add this back later
		GameState.set_status(
			island_id,
			node_id,
			Global.LocationStatus.TEMP_FREED
		)
		#clear pending battle
		GameState.pending_battle.clear()
		get_tree().change_scene_to_file(return_scene)
	else:
		#put it back to DISCOVERED so it can be fought again
		GameState.set_status(island_id, node_id, Global.LocationStatus.DISCOVERED)
		GameState.set_current(island_id, "town")
		get_tree().change_scene_to_file("res://scenes/general_village.tscn")
