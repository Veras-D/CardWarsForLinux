extends Node

## Automated Test Suite for Task 6.1: Deck Builder Interface & DeckValidator

const DeckValidator = preload("res://src/cards/DeckValidator.gd")
const DeckBuilder = preload("res://src/ui/DeckBuilder.gd")
const TEST_DECKS_DIR = "user://test_decks_suite"

var passed_count: int = 0
var failed_count: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING DECK BUILDER TEST SUITE (Task 6.1)")
	print("==================================================")

	_cleanup_test_dir()

	test_database_all_cards_and_presets()
	test_deck_validator_rules()
	test_mana_curve_and_type_breakdown()
	test_card_filtering_engine()
	test_deck_persistence_save_load_delete()
	test_deck_builder_scene_integration()

	_cleanup_test_dir()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==================================================")

	if failed_count == 0:
		print(">>> ALL DECK BUILDER TESTS COMPLETED SUCCESSFULLY! <<<")
		get_tree().quit(0)
	else:
		push_error("Deck Builder tests failed!")
		get_tree().quit(1)


func assert_true(condition: bool, msg: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % msg)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % msg)


func _cleanup_test_dir() -> void:
	if DirAccess.dir_exists_absolute(TEST_DECKS_DIR):
		var dir = DirAccess.open(TEST_DECKS_DIR)
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(TEST_DECKS_DIR.path_join(f))
				f = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(TEST_DECKS_DIR)


func test_database_all_cards_and_presets() -> void:
	print("\n[Test 1] Database All Cards & Preset Decks Loading")
	assert_true(Database.all_cards_list.size() == 416, "Database.all_cards_list contains all 416 cards (got %d)" % Database.all_cards_list.size())
	assert_true(Database.creatures_list.size() == 341, "Database.creatures_list contains 341 creatures")
	assert_true(Database.spells_list.size() == 48, "Database.spells_list contains 48 spells")
	assert_true(Database.buildings_list.size() == 27, "Database.buildings_list contains 27 buildings")
	assert_true(Database.preset_decks_db.size() > 100, "Database.preset_decks_db loaded from db_Decks.json (%d decks)" % Database.preset_decks_db.size())


func test_deck_validator_rules() -> void:
	print("\n[Test 2] Legal Deck Validator (10-25 Cards, Max 4 Copies)")

	# 1. Under 10 cards -> illegal
	var small_deck = ["Creature_Pig", "Creature_CoolDog", "Creature_Axey"]
	var res_small = DeckValidator.validate_deck(small_deck)
	assert_true(res_small["valid"] == false, "Deck with 3 cards (< 10) is rejected")
	assert_true(res_small["errors"].size() > 0, "Under-minimum deck reports validation error")

	# 2. Valid 10-card deck -> legal
	var valid_10 = [
		"Creature_Pig", "Creature_Pig", "Creature_Pig", "Creature_Pig",
		"Creature_CoolDog", "Creature_CoolDog", "Creature_CoolDog",
		"Creature_AngelEye", "Spell_CerebralBloodstorm", "Building_RedDome"
	]
	var res_valid = DeckValidator.validate_deck(valid_10)
	assert_true(res_valid["valid"] == true, "10-card deck with <= 4 copies per card is legal")
	assert_true(res_valid["counts_by_id"].get("Creature_Pig", 0) == 4, "Correctly counts 4 copies of Creature_Pig")

	# 3. 5 copies of a card -> illegal
	var five_copies = valid_10.duplicate()
	five_copies.append("Creature_Pig")
	var res_five = DeckValidator.validate_deck(five_copies)
	assert_true(res_five["valid"] == false, "Deck with 5 copies of Creature_Pig (> 4 max) is rejected")

	# 4. can_add_card prevents adding 5th copy
	var can_add_pig = DeckValidator.can_add_card(valid_10, "Creature_Pig")
	assert_true(can_add_pig["can_add"] == false, "can_add_card blocks 5th copy of Creature_Pig")

	var can_add_axey = DeckValidator.can_add_card(valid_10, "Creature_Axey")
	assert_true(can_add_axey["can_add"] == true, "can_add_card allows adding Creature_Axey (0/4)")

	# 5. Over 25 cards -> illegal
	var over_25: Array = []
	var pool = ["Creature_Pig", "Creature_CoolDog", "Creature_AngelEye", "Creature_Axey", "Creature_Cornball", "Creature_HuskerKnight", "Creature_ArcherDan"]
	for cid in pool:
		for _i in range(4):
			over_25.append(cid) # 28 cards
	var res_over = DeckValidator.validate_deck(over_25)
	assert_true(res_over["valid"] == false, "Deck with 28 cards (> 25 max) is rejected")

	var full_25 = over_25.slice(0, 25)
	var res_25 = DeckValidator.validate_deck(full_25)
	assert_true(res_25["valid"] == true, "Deck with 25 cards and <= 4 copies per card is legal")
	var can_add_to_full = DeckValidator.can_add_card(full_25, "Spell_PieStorm")
	assert_true(can_add_to_full["can_add"] == false, "can_add_card blocks adding to a full 25-card deck")


func test_mana_curve_and_type_breakdown() -> void:
	print("\n[Test 3] Live Mana Curve & Card Type Breakdown")
	var sample_deck = [
		"Creature_Pig", # Cost 1
		"Creature_CoolDog", # Cost 2
		"Spell_CerebralBloodstorm", # Spell
		"Building_RedDome" # Building, Cost 1
	]
	var curve = DeckValidator.compute_mana_curve(sample_deck)
	var total_in_curve = 0
	for k in curve.keys():
		total_in_curve += int(curve[k])
	assert_true(total_in_curve == sample_deck.size(), "Mana curve sum matches total deck size (4)")

	var breakdown = DeckValidator.compute_type_breakdown(sample_deck)
	assert_true(breakdown.get("CREATURE", 0) == 2, "Breakdown counts 2 creatures")
	assert_true(breakdown.get("SPELL", 0) == 1, "Breakdown counts 1 spell")
	assert_true(breakdown.get("BUILDING", 0) == 1, "Breakdown counts 1 building")


func test_card_filtering_engine() -> void:
	print("\n[Test 4] Faction, Type, Cost, and Search Filtering")
	var all_cards = Database.all_cards_list

	var spells_only = DeckValidator.filter_cards(all_cards, "ALL", "SPELL", -1, "")
	assert_true(spells_only.size() == 48, "Filtering by Type=SPELL returns 48 spells (got %d)" % spells_only.size())

	var buildings_only = DeckValidator.filter_cards(all_cards, "ALL", "BUILDING", -1, "")
	assert_true(buildings_only.size() == 27, "Filtering by Type=BUILDING returns 27 buildings (got %d)" % buildings_only.size())

	var corn_creatures = DeckValidator.filter_cards(all_cards, "Corn", "CREATURE", -1, "")
	assert_true(corn_creatures.size() > 40, "Filtering by Faction=Corn, Type=CREATURE returns %d Corn creatures" % corn_creatures.size())

	var cost_zero = DeckValidator.filter_cards(all_cards, "ALL", "ALL", 0, "")
	assert_true(cost_zero.size() > 0, "Filtering by Cost=0 MP returns %d 0-cost cards" % cost_zero.size())

	var search_pig = DeckValidator.filter_cards(all_cards, "ALL", "ALL", -1, "Pig")
	assert_true(search_pig.size() >= 1, "Searching 'Pig' finds The Pig")


func test_deck_persistence_save_load_delete() -> void:
	print("\n[Test 5] Saving, Renaming, Listing & Loading Decks (user://)")
	var illegal_deck = ["Creature_Pig", "Creature_CoolDog"]
	var fail_save = DeckValidator.save_deck_to_file("Illegal Short Deck", "Finn", ["Plains", "Plains", "Plains", "Plains"], illegal_deck, TEST_DECKS_DIR)
	assert_true(fail_save["ok"] == false, "Saving an illegal (<10 cards) deck is prevented")

	var legal_deck = [
		"Creature_Pig", "Creature_Pig",
		"Creature_CoolDog", "Creature_CoolDog",
		"Creature_AngelEye", "Creature_AngelEye",
		"Creature_AncientScholar", "Creature_Axey",
		"Spell_CerebralBloodstorm", "Building_RedDome"
	]
	var ok_save = DeckValidator.save_deck_to_file("Algebraic Corn & Plains", "Jake", ["Corn", "Plains", "Swamp", "Sand"], legal_deck, TEST_DECKS_DIR)
	assert_true(ok_save["ok"] == true, "Saving legal 10-card deck succeeds")
	assert_true(FileAccess.file_exists(ok_save["path"]), "Saved JSON file exists on disk: %s" % ok_save["path"])

	var listed = DeckValidator.list_saved_decks(TEST_DECKS_DIR)
	assert_true(listed.size() == 1, "list_saved_decks returns 1 saved deck")

	var loaded = DeckValidator.load_deck_from_file("algebraic_corn__plains", TEST_DECKS_DIR)
	assert_true(loaded.get("name", "") == "Algebraic Corn & Plains", "Loaded deck preserves custom deck name")
	assert_true(loaded.get("leader", "") == "Jake", "Loaded deck preserves leader 'Jake'")
	assert_true(loaded.get("cards", []).size() == 10, "Loaded deck preserves 10 cards")
	assert_true(loaded.get("landscapes", []) == ["Corn", "Plains", "Swamp", "Sand"], "Loaded deck preserves 4 custom landscapes")

	var deleted = DeckValidator.delete_saved_deck("algebraic_corn__plains", TEST_DECKS_DIR)
	assert_true(deleted == true, "delete_saved_deck removes the deck JSON file")


func test_deck_builder_scene_integration() -> void:
	print("\n[Test 6] DeckBuilder Scene UI & GameManager Integration")
	var scene = preload("res://scenes/deck_builder.tscn")
	var builder = scene.instantiate() as DeckBuilder
	add_child(builder)

	assert_true(builder != null, "DeckBuilder scene instantiated")
	assert_true(builder.current_deck_cards.size() == 10, "DeckBuilder initialized with 10 starter cards")
	assert_true(builder.save_btn.disabled == false, "Save button enabled for legal 10-card starter deck")

	# Add a card via UI controller
	var added = builder.add_card_to_deck("Creature_HuskerKnight")
	assert_true(added == true, "Added Creature_HuskerKnight to deck (now 11 cards)")
	assert_true(builder.current_deck_cards.size() == 11, "Deck count updated to 11")

	# Rename and save to test directory
	builder.deck_name_edit.text = "Finn Custom Tournament"
	builder.current_leader_id = "Marceline"
	var typed_lands: Array[String] = ["Swamp", "Swamp", "Corn", "Plains"]
	builder.current_landscapes = typed_lands
	var save_res = builder.save_current_deck(TEST_DECKS_DIR)
	assert_true(save_res.get("ok", false) == true, "DeckBuilder saved 'Finn Custom Tournament' to disk")
	assert_true(GameManager.active_deck_name == "Finn Custom Tournament", "GameManager.active_deck_name updated")
	assert_true(GameManager.player_hero_name == "Marceline", "GameManager.player_hero_name updated to Marceline")
	assert_true(GameManager.player_deck.size() == 11, "GameManager.player_deck updated to 11 cards")

	# Clear deck -> should disable save button
	builder.clear_deck()
	assert_true(builder.current_deck_cards.size() == 0, "clear_deck empties current_deck_cards")
	assert_true(builder.save_btn.disabled == true, "Save button disabled when deck is empty/illegal")

	# Reload saved deck via UI controller
	var reload_ok = builder.load_saved_deck("finn_custom_tournament", TEST_DECKS_DIR)
	assert_true(reload_ok == true, "Reloaded 'finn_custom_tournament' into DeckBuilder")
	assert_true(builder.current_deck_cards.size() == 11, "Reloaded deck restored all 11 cards")
	assert_true(builder.save_btn.disabled == false, "Save button re-enabled after loading legal deck")

	# Restore default Finn state on GameManager
	GameManager.player_hero_name = "Finn"
	builder.queue_free()
