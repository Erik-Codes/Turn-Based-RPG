# IslandMap.gd
extends Control
@export var island_id: String = "hearthbay"
@onready var nodes_parent: Node = $MapRoot/Buttons
@onready var player_marker: Control = $MapRoot/player
@onready var map_root: Control = $MapRoot

var _move_tween: Tween
var _is_moving := false

var _traveling := false
var _zoom_tween: Tween

#adjacency uses node_ids now; change to more intuitive
@export var graph := {
	"town": ["node_3","fishing"],
	"node_2": ["node_4"],
	"node_3": ["node_4"],
	"node_4": ["node_3","node_2","node_6","node_5"],
	"node_5": ["node_4"],
	"node_6": ["node_4"],
	"fishing": []
}
var shown_nodes: Dictionary = {} #node_id -> true

#define types here if you don't already store them on the button
#(If your Button script has exported `node_type`, use that instead.)
@export var node_types := {
	"town": Global.LocationType.TOWN,
	#"node_5": Global.LocationType.CAVE,
	"fishing": Global.LocationType.FISHING,
}

#Scenes for special nodes
@export var town_scene := "res://scenes/town.tscn"
@export var cave_scene := "res://scenes/cave.tscn"
@export var fishing_scene := "res://scenes/fishing.tscn"

var node_controls: Dictionary = {} #node_id -> holder Control

#setup
func _ready() -> void:
	_reset_zoom()
	GameState.ensure_island(island_id)
	#connect all nodes
	for holder in nodes_parent.get_children():
		var btn := holder.get_node("Button") as TextureButton
		var id := (btn as Object).get("node_id") as String
		node_controls[id] = holder
		GameState.ensure_node(island_id, id)
		(btn as Object).connect("chosen", Callable(self, "_on_node_chosen"))
	var cur := GameState.get_current(island_id)
	if cur == "":
		cur = "town"
		GameState.set_current(island_id, cur)
		#discover first adj nodes
		GameState.set_status(island_id, cur, Global.LocationStatus.DISCOVERED)
	# town return hides everything.
	if GameState.from_town:
		reset_from_town()
		GameState.from_town= false
	else:
		#restore what was shown before leaving (battle/fishing/cave)
		shown_nodes = GameState.get_shown(island_id)
		#if empty (first run), fall back
		if shown_nodes.is_empty():
			_show_only([cur] + graph.get(cur, []))
		_reveal_neighbors(cur)
	#persist shown
	for id in shown_nodes.keys():
		GameState.discover(island_id, id)
	_place_player_immediately(cur)
	_refresh_nodes()
	GameState.set_shown(island_id, shown_nodes)

#reset all when from town
func reset_from_town():
	_show_only(["town"] + graph.get("town", []))
	for node_id in node_controls.keys():
		var st := GameState.get_status(island_id, node_id)
		if st == Global.LocationStatus.TEMP_FREED or st == Global.LocationStatus.BATTLING:
			GameState.set_status(island_id, node_id, Global.LocationStatus.DISCOVERED)
	#shown nodes are actually discoverable/clickable
	GameState.set_status(island_id, "town", Global.LocationStatus.DISCOVERED)
	for nb in graph.get("town", []):
		GameState.set_status(island_id, nb, Global.LocationStatus.DISCOVERED)

#move and handle node type
func _on_node_chosen(node_id: String) -> void:
	if ScreenTransition.is_busy():
		return
	if _is_moving:
		return
	var st := GameState.get_status(island_id, node_id)
	if st == Global.LocationStatus.UNDISCOVERED:
		return
	if st == Global.LocationStatus.BATTLING:
		return
	_hide_node_temporarily(node_id)
	# Move to node
	GameState.set_current(island_id, node_id)
	# Reveal this node + neighbors
	GameState.discover(island_id, node_id)
	_reveal_neighbors(node_id)
	# Re-read status AFTER discover (important)
	st = GameState.get_status(island_id, node_id)
	# Scene-change nodes
	var t := _get_node_type(node_id)
	match t:
		Global.LocationType.TOWN:
			GameState.pending_battle["island_id"] = island_id
			GameState.pending_battle["node_id"] = node_id
			GameState.pending_battle["return_scene"] = scene_file_path
			await _tween_player_to(node_id)
			_refresh_nodes()
			get_tree().change_scene_to_file("res://scenes/general_village.tscn")
			return
		Global.LocationType.CAVE:
			GameState.set_return_source(island_id, "cave")
			get_tree().change_scene_to_file("res://scenes/cave.tscn")
			return
		Global.LocationType.FISHING:
			GameState.pending_battle["island_id"] = island_id
			GameState.pending_battle["node_id"] = node_id
			GameState.pending_battle["return_scene"] = scene_file_path
			#maybe bigger zoom later, same w fishing
			await _tween_player_to(node_id)
			await get_tree().process_frame
			get_tree().change_scene_to_file("res://scenes/general_fishing.tscn")
			return
		_:
			
			pass
	# Battle rules:
	# - ONLY if DISCOVERED (TEMP_FREED never battles)
	if st == Global.LocationStatus.DISCOVERED:
		# decreasing chance with clears
		var clears := GameState.get_node_clears(island_id, node_id)
		var p = clamp(1.0 - 0.25 * float(clears), 0.15, 1.0)
		if randf() < p:
			GameState.set_status(island_id, node_id, Global.LocationStatus.BATTLING)
			_start_battle(node_id)
			return
		else:
			await _tween_player_to(node_id)
			# no battle -> mark safe until town reset
			GameState.set_status(island_id, node_id, Global.LocationStatus.TEMP_FREED)
	else:
		await _tween_player_to(node_id)
	_refresh_nodes()

#for now change color, but later change image
func _update_button_visual(btn: TextureButton, st: int) -> void:
	match st:
		Global.LocationStatus.DISCOVERED:
			btn.modulate = Color(0.85, 0.9, 1.0)
		Global.LocationStatus.TEMP_FREED:
			btn.modulate = Color(0.55, 1.0, 0.55)
		Global.LocationStatus.BATTLING:
			btn.modulate = Color(1.0, 0.6, 0.6)
		_:
			btn.modulate = Color(1, 1, 1)

#show neighbor nodes
func _reveal_neighbors(node_id: String) -> void:
	for nb in graph.get(node_id, []):
		_show_node(nb)
		GameState.discover(island_id, nb) # only changes UNDISCOVERED -> DISCOVERED

#auto snap (unused for now)
func _snap_player_to(node_id: String) -> void:
	var holder := node_controls.get(node_id, null) as Control
	if holder == null:
		return
	player_marker.anchor_top = holder.anchor_top
	player_marker.anchor_left = holder.anchor_left
	player_marker.anchor_right = holder.anchor_right
	player_marker.anchor_bottom = holder.anchor_bottom

#make sure everything is as it should based on state
func _refresh_nodes() -> void:
	for node_id in node_controls.keys():
		var holder := node_controls[node_id] as Control
		var btn := holder.get_node("Button") as TextureButton
		var st = GameState.get_status(island_id, node_id)
		holder.visible = shown_nodes.has(node_id)
		btn.disabled = (st == Global.LocationStatus.BATTLING) or not holder.visible
		_update_button_visual(btn, st)
	var cur = GameState.get_current(island_id)
	if node_controls.has(cur):
		(node_controls[cur] as Control).visible = false


#get type
func _get_node_type(node_id: String) -> int:
	var holder = node_controls.get(node_id, null)
	if holder:
		var btn = holder.get_node("Button")
		if btn and (btn as Object).has_method("get_node_type"):
			return btn.get_node_type()
		#if exported var:
		if btn and (btn as Object).get("node_type") != null:
			return int((btn as Object).get("node_type"))
	return int(node_types.get(node_id, Global.LocationType.BATTLE))

#trigger battle
func _start_battle(node_id: String) -> void:
	GameState.pending_battle["island_id"] = island_id
	GameState.pending_battle["node_id"] = node_id
	GameState.pending_battle["return_scene"] = scene_file_path
	await travel_and_transition(node_id, "res://scenes/DIBBattle.tscn", 0.2, 1.6, 0.3, 0.14, 0.14)


#only show x nodes
func _show_only(nodes: Array) -> void:
	shown_nodes.clear()
	for id in nodes:
		shown_nodes[id] = true
	GameState.set_shown(island_id, shown_nodes)


func _show_node(id: String) -> void:
	shown_nodes[id] = true
	GameState.set_shown(island_id, shown_nodes)


func _hide_node_temporarily(id: String) -> void:
	if node_controls.has(id):
		(node_controls[id] as Control).visible = false

#make visible right away
func _place_player_immediately(node_id: String) -> void:
	player_marker.position = _node_center_local(node_id) - player_marker.size*0.5
#move player to chosen node
func _tween_player_to(node_id: String, duration := 0.18) -> void:
	_is_moving = true
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	var target := _node_center_local(node_id) - player_marker.size * 0.5
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(player_marker, "position", target, duration)
	await get_tree().create_timer(0.05).timeout
	_refresh_nodes()
	await _move_tween.finished
	_hide_node_temporarily(node_id)
	_is_moving = false

#reset map zoom (moving to a place zooms in if a battle ensues)
func _reset_zoom() -> void:
	map_root.scale = Vector2.ONE
	map_root.pivot_offset = Vector2.ZERO


func _player_center_in_maproot() -> Vector2:
	#player is a direct child of MapRoot, so this is in MapRoot local space
	return player_marker.position + player_marker.size*0.5


func _zoom_in_on_player(scale := 1.12, duration := 0.14) -> void:
	map_root.pivot_offset = _player_center_in_maproot()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(map_root, "scale", Vector2(scale, scale), duration)
	await tw.finished

#change scene after moving/zooming (unsued)
func transition_to_scene(scene_path: String, zoom_scale := 1.12, zoom_time := 0.14, fade_time := 0.18) -> void:
	if ScreenTransition.is_busy():
		return
	await _zoom_in_on_player(zoom_scale, zoom_time)
	await ScreenTransition.fade_out(fade_time)
	get_tree().change_scene_to_file(scene_path)

#move and zoom then change
func travel_and_transition(target_node_id: String, scene_path: String,
	move_time := 0.22, zoom_scale := 1.12, zoom_time := 0.22, fade_out := 0.16, fade_in := 0.16) -> void:
	if _traveling or ScreenTransition.is_busy():
		return
	_traveling = true
	#hide the chosen node immediately
	if node_controls.has(target_node_id):
		(node_controls[target_node_id] as Control).visible = false
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	var target_center := _node_center_local(target_node_id)
	var target_pos := target_center - player_marker.size * 0.5
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_SINE)
	_move_tween.set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(player_marker, "position", target_pos, move_time)
	await get_tree().create_timer(0.15).timeout
	_refresh_nodes()
	map_root.pivot_offset = _player_center_in_maproot()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(map_root, "scale", Vector2(zoom_scale, zoom_scale), zoom_time)
	#while moving/zooming: keep pivot locked to the moving marker each frame
	while (_move_tween and _move_tween.is_running()) or (_zoom_tween and _zoom_tween.is_running()):
		map_root.pivot_offset = _player_center_in_maproot()
		await get_tree().process_frame
	#now do the fade + scene change + fade
	await ScreenTransition.fade_to_scene(scene_path, fade_out, fade_in)
	_traveling = false

#get center for placement
func _node_center_local(node_id: String) -> Vector2:
	var holder := node_controls.get(node_id, null) as Control
	if holder == null:
		return player_marker.position
	# convert holder center (global) -> MapRoot local
	return holder.get_global_rect().get_center() - map_root.get_global_rect().position
