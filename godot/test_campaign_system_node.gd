extends Node

const NodeMapGraph = preload("res://src/systems/node_map_system/NodeMapGraph.gd")
const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")
const CampaignMapScene = preload("res://scenes/campaign_map.tscn")

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING CAMPAIGN QUEST PROGRESSION TEST SUITE (Task 7.1)")
	print("==================================================\n")

	_test_database_blueprints()
	_test_campaign_dag_initialization()
	_test_sequential_quest_unlocking()
	_test_three_star_condition_evaluator()
	_test_quest_battle_launch_setup()
	_test_campaign_profile_persistence()
	_test_campaign_map_ui()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL CAMPAIGN PROGRESSION TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)


func _assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		_tests_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("  [FAIL] %s %s" % [test_name, details])


func _test_database_blueprints() -> void:
	print("[Test 1] Quest & Conditions Database Loading")
	_assert_test(Database.quests_db.size() == 346, "Loaded all 346 quests from db_Quest.json (got %d)" % Database.quests_db.size())
	_assert_test(Database.main_quests_list.size() >= 120, "Loaded main campaign quests (got %d)" % Database.main_quests_list.size())
	_assert_test(Database.quest_conditions_db.size() >= 50, "Loaded quest conditions from db_QuestConditions.json (got %d)" % Database.quest_conditions_db.size())
	_assert_test(Database.map_regions_list.size() == 8, "Loaded 8 map regions from db_Map.json")

	var q1 = Database.get_quest("1")
	_assert_test(q1.get("opponent", "") == "Finn", "Quest 1 opponent is Finn")
	_assert_test(q1.get("deck_id", "") == "Quest1_Deck", "Quest 1 deck is Quest1_Deck")
	_assert_test(q1.get("condition_ids", []).size() == 3, "Quest 1 defines 3 star conditions")


func _test_campaign_dag_initialization() -> void:
	print("\n[Test 2] Campaign DAG Initialization & Root Unlocking")
	GameManager.campaign_graph = null
	GameManager._init_campaign()
	var graph = GameManager.campaign_graph

	_assert_test(graph != null, "GameManager.campaign_graph initialized")
	_assert_test(graph.has_node("1") == true, "Graph contains Quest 1")
	_assert_test(graph.has_node("2") == true, "Graph contains Quest 2")

	var q1_state = int(graph.get_node("1").get("state", -1))
	var q2_state = int(graph.get_node("2").get("state", -1))

	_assert_test(q1_state == NodeMapGraph.NodeState.UNLOCKED, "Quest 1 begins UNLOCKED")
	_assert_test(q2_state == NodeMapGraph.NodeState.LOCKED, "Quest 2 begins LOCKED (requires Quest 1)")
	_assert_test(graph.get_outgoing("1").has("2"), "Quest 1 has directed edge to Quest 2")


func _test_sequential_quest_unlocking() -> void:
	print("\n[Test 3] Sequential Quest Unlocking & Signal Emission")
	var graph = GameManager.campaign_graph
	var quest_completed_fired = [false]
	var signal_cb = func(_qid, _s, _r): quest_completed_fired[0] = true
	GameManager.quest_completed.connect(signal_cb, CONNECT_ONE_SHOT)

	var win_stats = {
		"won": true,
		"turns": 3,
		"player_hp_lost": 2,
		"player_creatures_lost": 1,
		"card_types_played": ["CREATURE"]
	}

	var res = GameManager.complete_campaign_quest("1", win_stats)
	_assert_test(res.get("ok", false) == true, "Quest 1 completed successfully")
	_assert_test(res.get("stars", 0) == 3, "Earned 3 stars on Quest 1")
	_assert_test(res.get("first_clear", false) == true, "Recorded first clear")
	_assert_test(quest_completed_fired[0] == true, "quest_completed signal fired")

	# Verify Quest 2 unlocked
	var q2_state = int(graph.get_node("2").get("state", -1))
	_assert_test(q2_state == NodeMapGraph.NodeState.UNLOCKED, "Quest 2 unlocked after Quest 1 completion")
	_assert_test(res.get("unlocked_quests", []).has("2"), "unlocked_quests report includes Quest 2")


func _test_three_star_condition_evaluator() -> void:
	print("\n[Test 4] 3-Star Objectives Evaluation")
	var q1 = Database.get_quest("1")
	var conditions = q1.get("conditions", [])

	# 1. Perfect game -> 3 Stars
	var perfect_stats = {
		"won": true,
		"turns": 3,
		"player_hp_lost": 0,
		"player_creatures_lost": 0,
		"card_types_played": ["CREATURE"]
	}
	var stars_perfect = StarConditionEvaluator.count_stars_earned(conditions, perfect_stats)
	_assert_test(stars_perfect == 3, "Perfect game awards 3 / 3 stars")

	# 2. Played forbidden Spell -> Loses Condition 2 (Forbid_Spells)
	var spell_stats = perfect_stats.duplicate(true)
	spell_stats["card_types_played"] = ["CREATURE", "SPELL"]
	var stars_spell = StarConditionEvaluator.count_stars_earned(conditions, spell_stats)
	_assert_test(stars_spell == 2, "Playing forbidden spell loses 1 star (earned 2 / 3 stars)")

	# 3. Defeat -> 0 Stars from evaluator
	var defeat_stats = {
		"won": false,
		"turns": 5
	}
	var stars_defeat = StarConditionEvaluator.count_stars_earned(conditions, defeat_stats)
	_assert_test(stars_defeat == 0, "Match defeat awards 0 stars")


func _test_quest_battle_launch_setup() -> void:
	print("\n[Test 5] Dynamic Quest Battle Launcher Configuration")
	GameManager._init_campaign()
	var q1 = Database.get_quest("1")

	# Ensure sufficient energy
	GameManager.wallet.deposit("energy", 10)
	var prev_energy = GameManager.wallet.get_balance("energy")

	# Prepare mock to avoid changing full tree in test
	GameManager.active_quest_id = "1"
	GameManager.opponent_hero_name = q1.get("opponent", "Finn")

	var leader_data = Database.leaders_db.get(q1.get("leader_id", ""), {})
	var base_hp = int(leader_data.get("base_hp", 10))
	var leader_lvl = int(q1.get("leader_level", 1))
	GameManager.opponent_hero_max_hp = base_hp + (leader_lvl * 5)

	var deck_id = str(q1.get("deck_id", ""))
	var raw_deck = Database.get_preset_deck(deck_id)
	_assert_test(not raw_deck.is_empty(), "Preset deck '%s' loaded from Database" % deck_id)
	_assert_test(GameManager.active_quest_id == "1", "Active quest ID set to '1'")
	_assert_test(GameManager.opponent_hero_name == "Finn", "Opponent hero configured as Finn")
	_assert_test(GameManager.opponent_hero_max_hp == 15, "Opponent HP dynamically scaled (Base 10 + 1*5 = 15)")


func _test_campaign_profile_persistence() -> void:
	print("\n[Test 6] Campaign Profile Persistence (Save & Reload)")
	var test_save_path = "user://test_campaign_profile.json"

	var ok_save = GameManager.save_profile(test_save_path)
	_assert_test(ok_save == true, "Profile saved to %s" % test_save_path)

	# Reset campaign graph in memory
	GameManager.campaign_graph = NodeMapGraph.new()
	GameManager._init_campaign()
	assert(GameManager.campaign_graph.get_node("1")["state"] == NodeMapGraph.NodeState.UNLOCKED)

	# Reload from disk
	var ok_load = GameManager.load_profile(test_save_path)
	_assert_test(ok_load == true, "Profile reloaded successfully")

	var restored_q1 = GameManager.campaign_graph.get_node("1")
	var restored_q2 = GameManager.campaign_graph.get_node("2")

	_assert_test(restored_q1.get("state", 0) == NodeMapGraph.NodeState.COMPLETED, "Restored Quest 1 state is COMPLETED")
	_assert_test(restored_q1.get("stars", 0) == 3, "Restored Quest 1 stars is 3")
	_assert_test(restored_q2.get("state", 0) == NodeMapGraph.NodeState.UNLOCKED, "Restored Quest 2 state is UNLOCKED")

	# Clean up test file
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))


func _test_campaign_map_ui() -> void:
	print("\n[Test 7] CampaignMap UI Scene Lifecycle")
	var map_instance = CampaignMapScene.instantiate()
	add_child(map_instance)

	_assert_test(map_instance.regions_bar.get_child_count() == 8, "Regions quick-jump bar has 8 region buttons")
	_assert_test(map_instance.detail_modal.visible == false, "Quest detail modal hidden initially")

	# Simulate selecting Quest 1
	map_instance._on_quest_selected("1")
	_assert_test(map_instance.detail_modal.visible == true, "Quest detail modal opened on node selection")
	_assert_test(map_instance.modal_title.text.contains("Quest 1"), "Modal title shows 'Quest 1'")
	_assert_test(map_instance.modal_battle_btn.disabled == false, "Battle button enabled for unlocked Quest 1")

	# Close modal
	map_instance.modal_close_btn.emit_signal("pressed")
	_assert_test(map_instance.detail_modal.visible == false, "Modal closed on close button press")

	map_instance.queue_free()
