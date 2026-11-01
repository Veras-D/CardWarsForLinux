extends Node

signal match_state_changed(new_state)

enum MatchState {
	MENU,
	BATTLE,
	VICTORY,
	DEFEAT
}

var current_state: MatchState = MatchState.MENU

# Default Player Deck (Finn's deck)
var player_deck: Array[String] = [
	"Creature_Pig",
	"Creature_CoolDog",
	"Creature_AngelEye",
	"Creature_AncientScholar",
	"Creature_Pig",
	"Creature_CoolDog",
	"Creature_AngelEye",
	"Spell_CerebralBloodstorm",
	"Building_RedDome",
	"Creature_Axey"
]

# Default Opponent Deck (Jake's deck)
var opponent_deck: Array[String] = [
	"Creature_Cornball",
	"Creature_HuskerKnight",
	"Creature_ArcherDan",
	"Creature_CornRonin",
	"Creature_Cornball",
	"Creature_HuskerKnight",
	"Creature_ArcherDan",
	"Spell_GrainStorm",
	"Creature_MaizeWalker",
	"Creature_CornRonin"
]

var player_hero_name: String = "Finn"
var player_hero_max_hp: int = 25
var player_landscapes: Array[String] = ["Plains", "Plains", "Cotton", "Plains"]

var opponent_hero_name: String = "Jake"
var opponent_hero_max_hp: int = 25
var opponent_landscapes: Array[String] = ["Corn", "Corn", "Sand", "Corn"]

func start_battle() -> void:
	current_state = MatchState.BATTLE
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func return_to_menu() -> void:
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
