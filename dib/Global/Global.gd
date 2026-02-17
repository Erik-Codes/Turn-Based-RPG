extends Node

enum State {MAIN, ATTACK, DEFEND, SWAP, ITEM, BATTLE_END}
enum Monster {Test1, Test2, Test3, Test4, Test5, Test6, Test7, Test8, Test9, Test10, Test11, Test12, Test13, Test14, Test15}
enum Attack {AT1, AT2, AT3, HT1, AT4, AT5}
enum TargetType { ENEMY, ALLY, SELF, ALL_ENEMIES, ALL_ALLIES }
enum Item {I1, I2, I3, I4}
enum LocationStatus {TEMP_FREED, DISCOVERED, BATTLING, UNDISCOVERED}
enum LocationType {WILD, CAVE, TOWN, FISHING, BATTLE}
#chance of encounter if freed

const monster_data: Dictionary[Monster, Dictionary] = {
	Monster.Test1: {
		'name': 't1',
		'texture': "res://graphics/sprites/test_sprite1.png",
		'attacks': [Attack.AT1,  Attack.HT1],
		'max health': 60,
		'speed' : 40,
		'atk': 10,
		'def':10,
	},
	Monster.Test2: {
		'name': 't2',
		'texture': "res://graphics/sprites/test_sprite2.png",
		'attacks': [Attack.AT1, Attack.AT5, Attack.AT2],
		'max health': 70,
		'speed' : 41,
		'atk': 10,
		'def':10,
	},
	Monster.Test3: {
		'name': 't3',
		'texture': "res://graphics/sprites/test_sprite3.png",
		'attacks': [Attack.AT1, Attack.AT3, Attack.AT2, Attack.AT5],
		'max health': 120,
		'speed' : 42,
		'atk': 10,
		'def':10,
	},
	Monster.Test4: {
		'name': 't4',
		'texture': "res://graphics/sprites/test_sprite4.png",
		'attacks': [Attack.AT1, Attack.AT3, Attack.AT2, Attack.HT1],
		'max health': 90,
		'speed' : 43,
		'atk': 10,
		'def':10,
	},
	Monster.Test5: {
		'name': 't5',
		'texture': "res://graphics/sprites/test_sprite5.png",
		'attacks': [Attack.AT1, Attack.AT3, Attack.AT2, Attack.HT1],
		'max health': 100,
		'speed' : 44,
		'atk': 10,
		'def':10,
	},
	Monster.Test6: {
		'name': 't6',
		'texture': "res://graphics/sprites/test_sprite6.png",
		'attacks': [Attack.AT1, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 120,
		'speed' : 45,
		'atk': 10,
		'def':10,
	},
	Monster.Test7: {
		'name': 't7',
		'texture': "res://graphics/sprites/test_sprite7.png",
		'attacks': [Attack.AT1, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 120,
		'speed' : 46,
		'atk': 10,
		'def':10,
	},
	Monster.Test8: {
		'name': 't8',
		'texture': "res://graphics/sprites/test_sprite8.png",
		'attacks': [Attack.AT1, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 120,
		'speed' : 47,
		'atk': 10,
		'def':10,
	},
	Monster.Test9: {
		'name': 't9',
		'texture': "res://graphics/sprites/test_sprite9.png",
		'attacks': [Attack.AT1, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 60,
		'speed' : 48,
		'atk': 10,
		'def':10,
	},
	Monster.Test10: {
		'name': 't10',
		'texture': "res://graphics/sprites/test_sprite10.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 70,
		'speed' : 49,
		'atk': 10,
		'def':10,
	},
	Monster.Test11: {
		'name': 't11',
		'texture': "res://graphics/sprites/test_sprite11.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 70,
		'speed' : 50,
		'atk': 10,
		'def':10,
	},
	Monster.Test12: {
		'name': 't12',
		'texture': "res://graphics/sprites/test_sprite12.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 40,
		'speed' : 51,
		'atk': 10,
		'def':10,
	},
	Monster.Test13: {
		'name': 't13',
		'texture': "res://graphics/sprites/test_sprite13.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 200,
		'speed' : 52,
		'atk': 10,
		'def':10,
	},
	Monster.Test14: {
		'name': 't14',
		'texture': "res://graphics/sprites/test_sprite14.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 30,
		'speed' : 53,
		'atk': 10,
		'def':10,
	},
	Monster.Test15: {
		'name': 't15',
		'texture': "res://graphics/sprites/test_sprite15.png",
		'attacks': [Attack.AT5, Attack.AT4, Attack.AT2, Attack.HT1],
		'max health': 250,
		'speed' : 55,
		'atk': 10,
		'def':10,
	},
}
#change from target 1/0 to TargetType
const attack_data: Dictionary[Attack, Dictionary] = {
	Attack.AT1: {'name': 'ATK1',     'amount': 220, 'animation': "res://graphics/attack effects/claw.png", 'target': 1, 'TU':40, 'button':'res://graphics/test/leftarr.png', 'dir':'left'},
	Attack.AT2: {'name': 'ATK2','amount': 20, 'animation': "res://graphics/attack effects/explosion.png", 'target': 1, 'TU':41, 'button':'res://graphics/test/uparr.png', 'dir':'up'},
	Attack.AT3: {'name': 'ATK3',     'amount': 20, 'animation': "res://graphics/attack effects/fire.png", 'target': 1, 'TU':42, 'button':'res://graphics/test/rightarr.png', 'dir':'right'},
	Attack.AT4: {'name': 'ATK4',      'amount': 20, 'animation': "res://graphics/attack effects/ice.png", 'target': 1, 'TU':43, 'button':'res://graphics/test/downarr.png', 'dir':'down'},
	Attack.AT5: {'name': 'ATK5',    'amount': 20, 'animation': "res://graphics/attack effects/water.png", 'target': 1, 'TU':44, 'button':'res://graphics/test/downarr.png', 'dir':'down'},
	Attack.HT1: {'name': 'HEAL1',     'amount': -20, 'animation': "res://graphics/attack effects/heal.png", 'target': 0, 'TU':45, 'button':'res://graphics/test/taparr.png', 'dir':'tap'},
}
const item_data: Dictionary[Item, Dictionary] = {
	Item.I2: {'name': 'I2', 'target': 0, 'attribute': 'health', 'amount': -20,  'icon': ""},
	Item.I3: {'name': 'I3', 'target': 0, 'attribute': 'health', 'amount': -50,  'icon': ""},
	Item.I1: {'name': 'I1', 'target': 1,  'attribute': 'health', 'amount': 20, 'icon': ""},
	Item.I4: {'name': 'I4', 'target': 1,  'attribute': 'health', 'amount': 50, 'icon': ""}
}

var current_monster: Monster
var current_enemy: Monster

var items = [Item.I2, Item.I3, Item.I1, Item.I4]
var current_attacks = [Attack.AT1,Attack.AT1,Attack.AT1,Attack.AT1]
#var encounter :Array = [Monster.Test6, Monster.Test10, Monster.Test4, Monster.Test6, Monster.Test6, Monster.Test6]
var encounter :Array = [Monster.Test6, Monster.Test10, Monster.Test4]
#var encounter :Array = [Monster.Test15, Monster.Test10]
#var encounter :Array = [Monster.Test15]

var currentLocation : int = 1
