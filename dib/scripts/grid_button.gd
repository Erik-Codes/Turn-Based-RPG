extends Control


var state
var type
var disabled : bool = false
signal press(state, type)


func setup(menu_state: Global.State, atk, atk_name:String, tu_text:int):
	$Label.text = atk_name
	$Label6.text = "TC: "+str(tu_text)
	state = menu_state
	type = atk
	$Button.texture_normal = load(Global.attack_data[atk]['button'])
	disabled = false

func set_blank(menu_state: Global.State) -> void:
	state = menu_state
	type = null
	$Label.text ="Unknown"
	$Label6.text = ""
	$Button.texture_normal = load("res://graphics/test/questarr.png")
	disabled = true

func _on_button_pressed():
	if disabled:
		return
	press.emit(state,type)
