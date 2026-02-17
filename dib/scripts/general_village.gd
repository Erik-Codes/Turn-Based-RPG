extends Control
#currently working on
enum Showing {MAIN,PARTY,SHOP,UPGRADES,QUEST}

var active = Showing.MAIN

func _ready():
	GameState.heal_party_to_full()
	$PartyPanel.hide()

func _on_button_pressed():
	if active == Showing.MAIN:
		GameState.from_town = true
		var return_scene = GameState.pending_battle["return_scene"]
		get_tree().change_scene_to_file(return_scene)
	elif active == Showing.PARTY:
		$PartyPanel.hide()
		active = Showing.MAIN
		$BackButton.text = "return to island"


func _on_party_pressed():
	active = Showing.PARTY
	for i in GameState.party:
		$PartyPanel.fill_party()
	$PartyPanel.show()
	$BackButton.text = "back to town"


func _on_shop_pressed():
	pass # Replace with function body.


func _on_upgrades_pressed():
	pass # Replace with function body.


func _on_quests_pressed():
	pass # Replace with function body.
