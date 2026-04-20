extends Control

const QuestBannerScene = preload("res://scenes/quest_banner.tscn")
const VERY_RARE_CATCHES: Array[int] = [
	Global.Monster.Test12,
	Global.Monster.Test14,
	Global.Monster.Test15,
]

@onready var status_label: Label = $StatusLabel
@onready var dialogue_box: DialogueBox = $DialogueBox

var rng := RandomNumberGenerator.new()
var _busy := false
var _quest_banner: QuestBanner

func _ready() -> void:
	rng.randomize()
	_ensure_quest_banner()
	GameState.mark_resume_scene(scene_file_path)
	_update_status("Cast a line and see what drifts up from the channel. %d casts left today." % GameState.get_remaining_fishing_attempts(_current_island_id()))
	if not GameState.has_story_flag("fishing_intro_seen"):
		GameState.set_story_flag("fishing_intro_seen")
		GameState.save_game()
		await _show_dialog("Fishing Dock", [
			"Fishing now rolls between no bite, gold, a very rare monster, or a rare fight.",
			"You only get a few real casts per day, and unique catches still count toward the village fishing quest.",
		])

func _current_island_id() -> String:
	return str(GameState.pending_battle.get("island_id", GameState.DEFAULT_ISLAND_ID))

func _update_status(text: String) -> void:
	status_label.text = text

func _show_dialog(title: String, pages: Array[String]) -> void:
	dialogue_box.play_dialog(title, pages)
	await dialogue_box.closed

func _ensure_quest_banner() -> void:
	if _quest_banner == null:
		_quest_banner = QuestBannerScene.instantiate() as QuestBanner
		add_child(_quest_banner)

func _show_quest_notices(notices: Array) -> void:
	_ensure_quest_banner()
	_quest_banner.enqueue_many(notices)

func _on_cast_button_pressed() -> void:
	if _busy:
		return
	_busy = true
	var island_id := _current_island_id()
	if not GameState.can_fish_today(island_id):
		_update_status("The water is dead quiet. You've already used every good cast for today.")
		await _show_dialog("No Bite", [
			"You have already fished out the best window for today.",
			"Come back after resting in the village for another set of casts.",
		])
		_busy = false
		return
	GameState.consume_fishing_attempt(island_id)
	var roll := rng.randi_range(0, 99)
	if roll < 45:
		await _handle_no_bite()
	elif roll < 78:
		await _handle_treasure()
	elif roll < 92:
		await _handle_battle_hook()
	else:
		await _handle_monster_catch()
	GameState.save_game()
	_update_status("The line settles. %d casts left today." % GameState.get_remaining_fishing_attempts(island_id))
	_busy = false

func _handle_no_bite() -> void:
	_update_status("No bite. The water stays calm.")
	await _show_dialog("No Bite", [
		"The bobber barely trembles before the ripples flatten out.",
		"Maybe the next cast will turn up something better.",
	])

func _handle_monster_catch() -> void:
	var species := VERY_RARE_CATCHES[rng.randi_range(0, VERY_RARE_CATCHES.size() - 1)]
	var level := rng.randi_range(4, 6)
	var uid := GameState.new_monster(species, level)
	var quest_notices := GameState.record_fished_monster(_current_island_id(), species)
	var monster: Dictionary = GameState.get_monster(uid)
	var catch_name := str(monster.get("name", Global.get_monster_name(species)))
	_update_status("A very rare catch surfaced: %s Lv.%d." % [catch_name, level])
	await _show_dialog("Good Catch", [
		"You reeled in a very rare %s at level %d." % [catch_name, level],
		"It has been added to your roster and counted toward unique fishing progress.",
	])
	_show_quest_notices(quest_notices)

func _handle_treasure() -> void:
	var gold_found := rng.randi_range(10, 24)
	GameState.gold += gold_found
	_update_status("Pulled up a salvage pouch worth %d gold." % gold_found)
	await _show_dialog("Sunken Cache", [
		"A weathered pouch surfaced with the line.",
		"You pocketed %d gold." % gold_found,
	])

func _handle_battle_hook() -> void:
	Global.encounter = GameState.build_random_encounter(_current_island_id(), "fishing", "fishing_rare_fight")
	GameState.set_pending_battle(_current_island_id(), "fishing", scene_file_path)
	_update_status("A rare fight snaps onto the line.")
	await _show_dialog("Rare Fight", [
		"The rod jerks hard and the water turns restless.",
		"This catch wants a fight.",
	])
	get_tree().change_scene_to_file("res://scenes/DIBBattle.tscn")

func _on_return_button_pressed() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.get_island_return_scene())
