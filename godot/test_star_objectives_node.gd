extends Node

## Automated Test Suite for Task 7.2: 3-Star Quest Objectives & Post-Battle Audit Screen

const StarConditionEvaluator = preload("res://src/systems/node_map_system/StarConditionEvaluator.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING 3-STAR QUEST OBJECTIVES TEST SUITE (Task 7.2)")
	print("==================================================\n")

	_test_condition_descriptions()
	_test_audit_star_conditions()
	_test_battle_telemetry_tracking()
	_test_battle_result_modal_ui()
	_test_star_milestones_and_claim()
	_test_star_milestone_persistence()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL 3-STAR OBJECTIVES TESTS COMPLETED SUCCESSFULLY! <<<\n")
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


func _test_condition_descriptions() -> void:
	print("[Test 1] Quest Condition Descriptions & Localization")
	var desc_win = Database.get_condition_description("JustWin")
	var desc_creatures = Database.get_condition_description("OnlyLose2Creatures")
	var desc_turns = Database.get_condition_description("FastWin3")
	var desc_spells = Database.get_condition_description("Forbid_Spells")
	var desc_hp = Database.get_condition_description("Only25HP")

	_assert_test(desc_win == "Beat your opponent to win a star!", "JustWin description matches blueprint string")
	_assert_test(desc_creatures == "Don't lose more than 2 creatures.", "OnlyLose2Creatures description matches blueprint string")
	_assert_test(desc_turns == "Beat the opponent in 3 turns or less.", "FastWin3 description matches blueprint string")
	_assert_test(desc_spells == "Beat the opponent without using Spell cards.", "Forbid_Spells description matches blueprint string")
	_assert_test(desc_hp == "Don't lose more than 25 HP on your Hero.", "Only25HP description matches blueprint string")


func _test_audit_star_conditions() -> void:
	print("\n[Test 2] StarConditionEvaluator.audit_star_conditions Deep Telemetry")
	var conditions = [
		Database.get_quest_condition("JustWin"),
		Database.get_quest_condition("FastWin5"),
		Database.get_quest_condition("OnlyLose2Creatures")
	]

	# 1. Perfect Match (3/3 Stars)
	var perfect_stats = {
		"won": true,
		"turns": 4,
		"player_hp_lost": 5,
		"player_creatures_lost": 1,
		"enemy_creatures_defeated": 3,
		"card_types_played": ["CREATURE"]
	}
	var audit_3 = StarConditionEvaluator.audit_star_conditions(conditions, perfect_stats)
	_assert_test(audit_3.size() == 3, "Audit produced 3 reports for 3 conditions")
	_assert_test(audit_3[0].passed == true, "Star 1 (JustWin) passed")
	_assert_test(audit_3[0].detail == "Match Won", "Star 1 detail is 'Match Won'")
	_assert_test(audit_3[1].passed == true, "Star 2 (FastWin5) passed")
	_assert_test(audit_3[1].detail == "4 / 5 turns", "Star 2 detail reports '4 / 5 turns'")
	_assert_test(audit_3[2].passed == true, "Star 3 (OnlyLose2Creatures) passed")
	_assert_test(audit_3[2].detail == "1 / 2 creatures lost", "Star 3 detail reports '1 / 2 creatures lost'")

	# 2. Partial Match (2/3 Stars: exceeded turns)
	var slow_stats = {
		"won": true,
		"turns": 7,
		"player_hp_lost": 5,
		"player_creatures_lost": 0,
		"enemy_creatures_defeated": 4
	}
	var audit_slow = StarConditionEvaluator.audit_star_conditions(conditions, slow_stats)
	_assert_test(audit_slow[0].passed == true, "Star 1 passed on slow win")
	_assert_test(audit_slow[1].passed == false, "Star 2 (FastWin5) failed on 7 turns")
	_assert_test(audit_slow[1].detail == "7 / 5 turns", "Star 2 detail shows '7 / 5 turns'")
	_assert_test(audit_slow[2].passed == true, "Star 3 passed on slow win")

	# 3. Match Defeat (0/3 Stars)
	var lost_stats = {
		"won": false,
		"turns": 3,
		"player_hp_lost": 25,
		"player_creatures_lost": 4
	}
	var audit_defeat = StarConditionEvaluator.audit_star_conditions(conditions, lost_stats)
	_assert_test(audit_defeat[0].passed == false, "Star 1 failed on defeat")
	_assert_test(audit_defeat[1].passed == false, "Star 2 failed on defeat")
	_assert_test(audit_defeat[2].passed == false, "Star 3 failed on defeat")
	_assert_test(audit_defeat[0].detail == "Defeat", "Star 1 detail reports 'Defeat'")


func _test_battle_telemetry_tracking() -> void:
	print("\n[Test 3] Live Battle Telemetry Gathering in BattleController")
	var battle_scene = load("res://scenes/battle.tscn").instantiate()
	add_child(battle_scene)

	# Verify telemetry variables initialized
	_assert_test(battle_scene.match_turn_count == 0, "match_turn_count initialized to 0")
	_assert_test(battle_scene.match_player_hp_lost == 0, "match_player_hp_lost initialized to 0")
	_assert_test(battle_scene.match_player_creatures_lost == 0, "match_player_creatures_lost initialized to 0")
	_assert_test(battle_scene.match_enemy_creatures_defeated == 0, "match_enemy_creatures_defeated initialized to 0")

	# Simulate telemetry events
	battle_scene.start_player_turn()
	_assert_test(battle_scene.match_turn_count == 1, "match_turn_count incremented to 1 on player turn")

	# Simulate damage and card plays
	battle_scene.match_player_hp_lost += 8
	battle_scene.match_card_types_played.append("CREATURE")
	battle_scene.match_card_types_played.append("SPELL")
	battle_scene.match_enemy_creatures_defeated += 2

	var stats = battle_scene.get_match_stats(true)
	_assert_test(stats.won == true, "Telemetry won flag matches victory state")
	_assert_test(stats.turns == 1, "Telemetry turns count is 1")
	_assert_test(stats.player_hp_lost == 8, "Telemetry player_hp_lost matches 8")
	_assert_test(stats.enemy_creatures_defeated == 2, "Telemetry enemy_creatures_defeated matches 2")
	_assert_test(stats.card_types_played.has("CREATURE") and stats.card_types_played.has("SPELL"), "Telemetry card_types_played contains played types")

	battle_scene.queue_free()


func _test_battle_result_modal_ui() -> void:
	print("\n[Test 4] BattleResultModal UI & Sequential Star Reveal")
	var modal_scene = load("res://scenes/battle_result_modal.tscn").instantiate()
	add_child(modal_scene)

	_assert_test(modal_scene.visible == false, "BattleResultModal starts hidden")

	var sample_audit = [
		{"index": 0, "passed": true, "description": "Beat your opponent to win a star!", "detail": "Match Won"},
		{"index": 1, "passed": true, "description": "Beat opponent in 5 turns or less", "detail": "3 / 5 turns"},
		{"index": 2, "passed": false, "description": "Don't lose more than 10 HP", "detail": "15 / 10 HP lost"}
	]
	var sample_rewards = {
		"coins": 1250,
		"xp": 450,
		"cards": ["Creature_Pig"],
		"leveled_up": true
	}

	modal_scene.display_result(true, "1", {"won": true}, sample_rewards, sample_audit)
	_assert_test(modal_scene.visible == true, "BattleResultModal visible after display_result")
	_assert_test(modal_scene.title_label.text.contains("VICTORY"), "Title displays 'VICTORY'")
	_assert_test(modal_scene.objectives_section.visible == true, "Objectives section is visible")
	_assert_test(modal_scene.objectives_list.get_child_count() == 3, "Objectives list contains 3 rows")
	_assert_test(modal_scene.stars_earned_count == 2, "Calculated 2 stars earned from audit report")
	_assert_test(modal_scene.coins_label.text.contains("1250"), "Coins label shows '+1250 Coins'")
	_assert_test(modal_scene.xp_label.text.contains("450"), "XP label shows '+450 XP'")
	_assert_test(modal_scene.levelup_banner.visible == true, "Level Up banner visible on hero levelup")
	_assert_test(modal_scene.continue_btn.text.contains("Map"), "Continue button configured for Campaign Map navigation")

	modal_scene.queue_free()


func _test_star_milestones_and_claim() -> void:
	print("\n[Test 5] Campaign Star Milestones & Claim Workflow")
	GameManager.campaign_graph = null
	GameManager.fc_campaign_graph = null
	GameManager._init_campaign()
	GameManager.claimed_star_milestones.clear()

	# Give player 20 stars across campaign nodes
	GameManager.campaign_graph.complete_node("1", 3)
	GameManager.campaign_graph.complete_node("2", 3)
	GameManager.campaign_graph.complete_node("3", 3)
	GameManager.campaign_graph.complete_node("4", 3)
	GameManager.campaign_graph.complete_node("5", 3)
	GameManager.campaign_graph.complete_node("6", 3)
	GameManager.campaign_graph.complete_node("7", 2) # Total: 20 stars

	_assert_test(GameManager.get_total_campaign_stars() == 20, "Total campaign stars calculated as 20")
	_assert_test(GameManager.can_claim_milestone(5) == true, "5-star milestone is available to claim")
	_assert_test(GameManager.can_claim_milestone(15) == true, "15-star milestone is available to claim")
	_assert_test(GameManager.can_claim_milestone(30) == false, "30-star milestone is locked (needs 30, has 20)")

	var prev_coins = GameManager.get_coins()
	var prev_gems = GameManager.get_gems()

	# Claim 5-star milestone (5,000 Coins)
	var claim_5 = GameManager.claim_star_milestone(5)
	_assert_test(claim_5.ok == true, "Claim 5-star milestone succeeded")
	_assert_test(GameManager.get_coins() == prev_coins + 5000, "Awarded 5,000 Coins from milestone")
	_assert_test(GameManager.can_claim_milestone(5) == false, "5-star milestone marked claimed")

	# Claim 15-star milestone (5 Gems)
	var claim_15 = GameManager.claim_star_milestone(15)
	_assert_test(claim_15.ok == true, "Claim 15-star milestone succeeded")
	_assert_test(GameManager.get_gems() == prev_gems + 5, "Awarded 5 Gems from milestone")


func _test_star_milestone_persistence() -> void:
	print("\n[Test 6] Star Milestones Profile Persistence (Save & Reload)")
	var test_save_path = "user://test_star_profile.json"

	_assert_test(GameManager.save_profile(test_save_path) == true, "Profile with claimed star milestones saved")

	# Clear runtime claimed milestones
	GameManager.claimed_star_milestones.clear()
	_assert_test(GameManager.claimed_star_milestones.is_empty(), "Cleared in-memory milestones")

	# Reload
	_assert_test(GameManager.load_profile(test_save_path) == true, "Profile reloaded successfully")
	_assert_test(GameManager.claimed_star_milestones.has(5), "Reloaded profile preserves 5-star milestone claimed")
	_assert_test(GameManager.claimed_star_milestones.has(15), "Reloaded profile preserves 15-star milestone claimed")
	_assert_test(not GameManager.claimed_star_milestones.has(30), "Unclaimed 30-star milestone remains unclaimed")
