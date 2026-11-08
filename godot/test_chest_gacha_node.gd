extends Node

const ChestOpeningModal = preload("res://src/ui/ChestOpeningModal.gd")

var _tests_passed: int = 0
var _tests_failed: int = 0


func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING CHEST OPENING & GACHA SYSTEM TEST SUITE (Task 8.2)")
	print("==================================================\n")

	_test_gacha_database_pools()
	_test_cool_chest_opening()
	_test_algebraic_chest_opening()
	_test_gacha_pity_system()
	_test_gacha_profile_persistence()
	_test_chest_opening_modal_ui()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [_tests_passed, _tests_failed])
	print("==================================================")

	if _tests_failed == 0:
		print(">>> ALL CHEST GACHA TESTS COMPLETED SUCCESSFULLY! <<<\n")
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


func _test_gacha_database_pools() -> void:
	print("[Test 1] Gacha Database Pools & Schedules Loading")
	var cool_pool = Database.get_gacha_pool("cool_chest")
	var algebraic_pool = Database.get_gacha_pool("algebraic_chest")

	_assert_test(cool_pool.size() >= 100, "Cool Chest pool loaded %d items (>= 100)" % cool_pool.size())
	_assert_test(algebraic_pool.size() >= 100, "Algebraic Chest pool loaded %d items (>= 100)" % algebraic_pool.size())

	var cool_def = Database.get_chest_def("cool_chest")
	var algebraic_def = Database.get_chest_def("algebraic_chest")

	_assert_test(cool_def.get("cost", 0) == 10000 and cool_def.get("currency", "") == "coins", "Cool Chest cost is 10,000 Coins")
	_assert_test(algebraic_def.get("cost", 0) == 3 and algebraic_def.get("currency", "") == "gems", "Algebraic Chest cost is 3 Gems")


func _test_cool_chest_opening() -> void:
	print("\n[Test 2] Cool Chest Opening & Currency Deduction")
	# Setup funds
	GameManager.wallet.set_balance("coins", 25000)
	var prev_inventory_size = GameManager.player_inventory_cards.size()

	var signal_fired = [false]
	var cb = func(_ctype, _rolls): signal_fired[0] = true
	GameManager.chest_opened.connect(cb, CONNECT_ONE_SHOT)

	var res = GameManager.open_chest("cool_chest", 1)
	_assert_test(res.get("ok", false) == true, "Single Cool Chest opened successfully")
	_assert_test(GameManager.get_coins() == 15000, "10,000 Coins deducted (Balance: 15,000)")
	_assert_test(res.get("rolls", []).size() == 1, "1 roll item returned")
	_assert_test(GameManager.player_inventory_cards.size() == prev_inventory_size + 1, "Rolled card added to player inventory")
	_assert_test(signal_fired[0] == true, "chest_opened signal emitted")

	# Test overdraft protection
	var failed_res = GameManager.open_chest("cool_chest", 5) # Needs 50,000, has 15,000
	_assert_test(failed_res.get("ok", true) == false, "Opening 5x Cool Chests without funds blocked")
	_assert_test(GameManager.get_coins() == 15000, "Coin balance untouched after overdraft block (15,000)")


func _test_algebraic_chest_opening() -> void:
	print("\n[Test 3] Algebraic Chest Opening & Gem Deduction")
	# Setup gems
	GameManager.wallet.set_balance("gems", 10)
	var prev_inventory_size = GameManager.player_inventory_cards.size()

	var res = GameManager.open_chest("algebraic_chest", 1)
	_assert_test(res.get("ok", false) == true, "Algebraic Chest opened successfully")
	_assert_test(GameManager.get_gems() == 7, "3 Gems deducted (Balance: 7)")
	_assert_test(res.get("rolls", []).size() == 1, "1 roll item returned")
	_assert_test(GameManager.player_inventory_cards.size() == prev_inventory_size + 1, "Rolled card added to player inventory")

	# Test 2x pull
	var res2 = GameManager.open_chest("algebraic_chest", 2)
	_assert_test(res2.get("ok", false) == true, "Multi-pull (2x) opened successfully")
	_assert_test(GameManager.get_gems() == 1, "6 Gems deducted for 2x pull (Balance: 1)")
	_assert_test(res2.get("rolls", []).size() == 2, "2 roll items returned")


func _test_gacha_pity_system() -> void:
	print("\n[Test 4] Pity System & Guaranteed High Rarity")
	# Setup mock roller with controlled pity
	var mock_roller = load("res://src/systems/progression_engine/GachaRoller.gd").new()
	var test_pool = [
		{"id": "Card_Common", "weight": 999, "rarity": "Standard"},
		{"id": "Card_UltraGold", "weight": 1, "rarity": "Gold"}
	]
	mock_roller.register_pool("test_pity_pool", test_pool)
	mock_roller.set_pity_rule("test_pity_pool", 5, "Gold")

	# Roll 4 times with fixed seed that only rolls common
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	for i in range(4):
		mock_roller.roll("test_pity_pool", rng)

	_assert_test(mock_roller.get_pity_count("test_pity_pool") == 4, "Pity counter reached 4 / 5")

	# 5th roll must force Gold due to pity
	var pity_roll = mock_roller.roll("test_pity_pool", rng)
	_assert_test(pity_roll.get("is_pity", false) == true, "5th roll triggered pity guarantee")
	_assert_test(pity_roll.get("rarity", "") == "Gold", "5th roll awarded guaranteed 'Gold' rarity")
	_assert_test(mock_roller.get_pity_count("test_pity_pool") == 0, "Pity counter reset to 0 after guarantee")


func _test_gacha_profile_persistence() -> void:
	print("\n[Test 5] Gacha Profile Persistence (Save & Reload)")
	var test_save_path = "user://test_gacha_profile.json"

	# Open chests to set balances, inventory, and pity
	GameManager.wallet.set_balance("coins", 50000)
	GameManager.wallet.set_balance("gems", 30)
	GameManager.open_chest("algebraic_chest", 1)

	var saved_pity = GameManager.get_chest_pity("algebraic_chest")
	var saved_coins = GameManager.get_coins()
	var saved_gems = GameManager.get_gems()
	var saved_inv_count = GameManager.player_inventory_cards.size()

	var ok_save = GameManager.save_profile(test_save_path)
	_assert_test(ok_save == true, "Profile saved to %s" % test_save_path)

	# Mutate local state
	GameManager.wallet.set_balance("coins", 0)
	GameManager.wallet.set_balance("gems", 0)
	GameManager.gacha_roller.reset_pity("algebraic_chest")

	# Reload
	var ok_load = GameManager.load_profile(test_save_path)
	_assert_test(ok_load == true, "Profile loaded successfully")
	_assert_test(GameManager.get_coins() == saved_coins, "Coins restored correctly (%d)" % saved_coins)
	_assert_test(GameManager.get_gems() == saved_gems, "Gems restored correctly (%d)" % saved_gems)
	_assert_test(GameManager.get_chest_pity("algebraic_chest") == saved_pity, "Gacha pity counter restored correctly (%d)" % saved_pity)
	_assert_test(GameManager.player_inventory_cards.size() == saved_inv_count, "Inventory card count preserved (%d)" % saved_inv_count)

	# Clean up test profile
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))


func _test_chest_opening_modal_ui() -> void:
	print("\n[Test 6] ChestOpeningModal UI Lifecycle")
	var modal_scene = load("res://src/ui/ChestOpeningModal.tscn")
	var modal = modal_scene.instantiate()
	modal.skip_animations = true
	add_child(modal)

	GameManager.wallet.set_balance("coins", 20000)
	modal.refresh_display()

	_assert_test(modal.selection_container.visible == true, "Modal starts in selection view")
	_assert_test(modal.reveal_container.visible == false, "Modal reveal container hidden initially")

	var card_revealed_fired = [false]
	modal.card_revealed.connect(func(_cid, _rarity): card_revealed_fired[0] = true)

	# Simulate pressing Cool Chest 1x
	modal._on_open_chest_pressed("cool_chest", 1)

	_assert_test(modal.reveal_container.visible == true, "Reveal view active after opening chest")
	_assert_test(modal.cards_grid.get_child_count() == 1, "1 Card slot displayed in reveal grid")
	_assert_test(card_revealed_fired[0] == true, "card_revealed signal fired by modal")

	# Simulate pressing Collect
	modal._on_collect_pressed()
	_assert_test(modal.selection_container.visible == true, "Returned to selection view after Collect All")

	modal.queue_free()
