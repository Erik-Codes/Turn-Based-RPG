extends Control

var grid_button_scene = preload("res://scenes/grid_button.tscn")


#track where menu currently is and choose what buttons to display
var _current_state: Global.State = Global.State.ATTACK
var current_state: Global.State:
	get: return _current_state
	set(value):
		_current_state = value
		refresh()
var current_monst : Global.Monster = Global.Monster.Test2

signal selected(state: Global.State, type)

func _ready():
	for i in range(1, 5):
		var cntrl_name = "Control" if i == 1 else "Control%d" % i
		var asp_name = "AspectRatioContainer" if i == 1 else "AspectRatioContainer%d" % i
		var cntrl = $GridContainer.get_node(asp_name+"/"+cntrl_name)
		if not cntrl.press.is_connected(button_handler):
			cntrl.press.connect(button_handler)

func refresh() -> void:
	match current_state:
		Global.State.ATTACK:
			var attacks: Array = Global.monster_data[Global.current_monster]["attacks"]
			create_grid_buttons(Global.State.ATTACK, attacks)
		_:
			#perhaps later: MAIN/ITEM/SWAP etc
			pass

func create_grid_buttons(state: Global.State, attacks: Array):
	for i in range(4):
		var cntrl_name = "Control" if i == 0 else "Control%d" % (i + 1)
		var asp_name = "AspectRatioContainer" if i == 0 else "AspectRatioContainer%d" % (i + 1)
		var cntrl = $GridContainer.get_node(asp_name+"/"+cntrl_name) as Control
		if i < attacks.size():
			var atk = attacks[i]
			var data = Global.attack_data[atk]
			cntrl.setup(state, atk, data["name"], data["TU"])
		else:
			cntrl.set_blank(state)
	#await get_tree().process_frame
	#$GridContainer/Control/Button.grab_focus()


func button_handler(state, type):
	if state == Global.State.MAIN:
		current_state = type
		if type == Global.State.DEFEND:
			selected.emit(Global.State.DEFEND, type)
	else:
		selected.emit(state, type)
