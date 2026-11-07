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
	"Creature_CactusThug",
	"Creature_HuskerKnight",
	"Creature_ArcherDan",
	"Spell_PieStorm",
	"Creature_MaizeWalker",
	"Creature_Cornball"
]

var player_hero_name: String = "Finn"
var player_hero_max_hp: int = 25
var player_landscapes: Array[String] = ["Plains", "Plains", "Cotton", "Plains"]

var opponent_hero_name: String = "Jake"
var opponent_hero_max_hp: int = 25
var opponent_landscapes: Array[String] = ["Corn", "Corn", "Sand", "Corn"]

# Wheel mode: "NORMAL" (interactive roulette), "QUICK" (auto quick-resolve)
var wheel_mode: String = "NORMAL"

# Session & persistent rewards
var player_coins: int = 5000
var player_inventory_cards: Array[String] = []
var owned_card_counts: Dictionary = {}
var active_deck_name: String = "Finn Starter Deck"

func add_rewards(coins: int, cards: Array[String]) -> void:
	player_coins += coins
	for c in cards:
		player_inventory_cards.append(c)
		if not owned_card_counts.is_empty():
			owned_card_counts[c] = int(owned_card_counts.get(c, 0)) + 1

func get_owned_card_counts() -> Dictionary:
	if owned_card_counts.is_empty():
		for c in Database.all_cards_list:
			var cid = str(c.get("id", ""))
			if cid != "":
				owned_card_counts[cid] = 4
		for c in player_inventory_cards:
			owned_card_counts[c] = int(owned_card_counts.get(c, 0)) + 1
	return owned_card_counts

func craft_fusion_recipe(recipe: Dictionary) -> Dictionary:
	var counts = get_owned_card_counts()
	var FusionEngine = preload("res://src/cards/FusionEngine.gd")
	var res = FusionEngine.execute_fusion(recipe, counts, player_coins)
	if res.get("ok", false):
		player_coins = int(res.get("new_coins", player_coins))
		var out_id = str(res.get("output_card_id", ""))
		if out_id != "":
			player_inventory_cards.append(out_id)
	return res

func apply_custom_deck(deck_data: Dictionary) -> void:
	if deck_data.is_empty():
		return
	active_deck_name = str(deck_data.get("name", "Custom Deck"))
	var leader_id = str(deck_data.get("leader", player_hero_name))
	if leader_id != "":
		player_hero_name = leader_id
		var leader_info = Database.get_leader(leader_id)
		if not leader_info.is_empty():
			player_hero_max_hp = int(leader_info.get("base_hp", 25))
	var lands = deck_data.get("landscapes", [])
	if typeof(lands) == TYPE_ARRAY and lands.size() == 4:
		var typed_lands: Array[String] = []
		for l in lands:
			typed_lands.append(str(l))
		player_landscapes = typed_lands
	var cards_arr = deck_data.get("cards", [])
	if typeof(cards_arr) == TYPE_ARRAY and cards_arr.size() >= 10:
		var typed_cards: Array[String] = []
		for c in cards_arr:
			typed_cards.append(str(c))
		player_deck = typed_cards

func open_deck_builder() -> void:
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")

func start_battle() -> void:
	current_state = MatchState.BATTLE
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func return_to_menu() -> void:
	current_state = MatchState.MENU
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
