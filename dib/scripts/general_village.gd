extends Control

enum Showing {MAIN, PARTY, SHOP, UPGRADES, QUEST}

@onready var party_panel: Control = $PartyPanel
@onready var quest_panel: Control = $QuestPanel
@onready var back_button: Button = $BackButton
@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var info_label: Label = $VillageInfo

var active = Showing.MAIN

func _ready() -> void:
	GameState.mark_resume_scene(scene_file_path)
	GameState.heal_party_to_full()
	GameState.save_game()
	party_panel.hide()
	quest_panel.hide()
	_refresh_info()
	if GameState.has_story_flag("starter_dialog_pending"):
		GameState.set_story_flag("starter_dialog_pending", false)
		GameState.set_story_flag("village_intro_seen", true)
		GameState.save_game()
		await _show_dialog("Hearthbay", [
			"You wake in Hearthbay with a single partner and a lot of ocean between you and the rest of the island.",
			"%s has joined your party as your starter creature." % Global.get_monster_name(Global.Monster.Test10),
		])
		return
	if not GameState.has_story_flag("village_intro_seen"):
		GameState.set_story_flag("village_intro_seen")
		GameState.save_game()
		await _show_dialog("Hearthbay", [
			"The village is your safe room. Resting here heals the party and saves the run.",
			"The elders are still placeholders for now, but the core loop is finally connected: rest, manage party, fish, and head into the cave.",
		])

func _refresh_info() -> void:
	var reward_text := ""
	var last_gold := int(GameState.last_battle_rewards.get("gold", 0))
	if last_gold > 0:
		reward_text = "  Last haul: +%d gold" % last_gold
	info_label.text = "Gold: %d%s" % [GameState.gold, reward_text]

func _show_dialog(title: String, pages: Array[String]) -> void:
	dialogue_box.play_dialog(title, pages)
	await dialogue_box.closed
	_refresh_info()

func _on_button_pressed() -> void:
	if active == Showing.MAIN:
		GameState.from_town = true
		GameState.advance_day("hearthbay")
		GameState.save_game()
		var return_scene := _resolve_island_return_scene()
		get_tree().change_scene_to_file(return_scene)
		return
	if active == Showing.PARTY:
		party_panel.hide()
	elif active == Showing.QUEST:
		quest_panel.hide()
	active = Showing.MAIN
	back_button.text = "Return to island"

func _on_party_pressed() -> void:
	active = Showing.PARTY
	party_panel.show()
	if party_panel.has_method("rebuild_lineup"):
		party_panel.rebuild_lineup()
	if party_panel.has_method("rebuild_roster"):
		party_panel.rebuild_roster()
	back_button.text = "Back to town"

func _on_shop_pressed() -> void:
	active = Showing.SHOP
	await _show_dialog("Dock Merchant", [
		"The shop UI is still to come, but the village loop now keeps your gold and save data between sessions.",
		"You can use fishing and cave runs to build up gold first, then we can hang a real inventory/shop system off this later.",
	])
	active = Showing.MAIN

func _on_upgrades_pressed() -> void:
	active = Showing.UPGRADES
	GameState.save_game()
	await _show_dialog("Shrine Keeper", [
		"Your journey has been recorded.",
		"Monster leveling and evolution are live now. Win battles or fish up rare creatures to grow the roster.",
	])
	active = Showing.MAIN

func _on_quests_pressed() -> void:
	active = Showing.QUEST
	quest_panel.show()
	if quest_panel.has_method("rebuild_quests"):
		quest_panel.rebuild_quests()
	back_button.text = "Back to town"

func _resolve_island_return_scene() -> String:
	return GameState.get_island_return_scene()
