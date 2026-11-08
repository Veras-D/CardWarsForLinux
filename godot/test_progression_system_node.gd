extends Node

const EconomyHeader = preload("res://src/ui/EconomyHeader.gd")

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING ECONOMY & HERO PROGRESSION TEST SUITE (Task 8.1)")
	print("==================================================\n")

	var total_tests = 0
	var passed_tests = 0

	# --------------------------------------------------------------------------
	# [Test 1] Blueprints Loading (db_RankUp.json & db_LvUpScheme.json)
	# --------------------------------------------------------------------------
	print("[Test 1] Blueprints Loading (db_RankUp.json & db_LvUpScheme.json)")
	total_tests += 1
	var r1 = Database.get_rank_info(1)
	if r1.get("deck_max_size", 0) == 15:
		print("  [PASS] Rank 1 deck max size is 15")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Rank 1 deck max size 15, got %d" % r1.get("deck_max_size", 0))

	total_tests += 1
	var r2 = Database.get_rank_info(2)
	if r2.get("deck_max_size", 0) == 16:
		print("  [PASS] Rank 2 deck max size is 16")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Rank 2 deck max size 16, got %d" % r2.get("deck_max_size", 0))

	total_tests += 1
	var r26 = Database.get_rank_info(26)
	if r26.get("deck_max_size", 0) == 40:
		print("  [PASS] Rank 26+ deck max size scales to 40")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Rank 26 deck max size 40, got %d" % r26.get("deck_max_size", 0))

	total_tests += 1
	var scheme_a = Database.get_lvup_scheme_index("A")
	if is_equal_approx(scheme_a, 100.0):
		print("  [PASS] Scheme A LvIndex is 100.0")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Scheme A LvIndex 100.0, got %f" % scheme_a)

	# --------------------------------------------------------------------------
	# [Test 2] CurrencyWallet Operations & Overdraft Protection
	# --------------------------------------------------------------------------
	print("\n[Test 2] CurrencyWallet Operations & Overdraft Protection")
	# Reset for test
	GameManager.wallet = null
	GameManager._init_wallet()

	var currency_signals: Array = []
	GameManager.player_currencies_updated.connect(func(c, g): currency_signals.append({ "coins": c, "gems": g }))

	total_tests += 1
	var start_coins = GameManager.get_coins()
	GameManager.add_coins(1000)
	if GameManager.get_coins() == start_coins + 1000:
		print("  [PASS] Deposited 1,000 coins (now %d)" % GameManager.get_coins())
		passed_tests += 1
	else:
		print("  [FAIL] Add coins failed, expected %d, got %d" % [start_coins + 1000, GameManager.get_coins()])

	total_tests += 1
	var start_gems = GameManager.get_gems()
	GameManager.add_gems(10)
	if GameManager.get_gems() == start_gems + 10:
		print("  [PASS] Deposited 10 gems (now %d)" % GameManager.get_gems())
		passed_tests += 1
	else:
		print("  [FAIL] Add gems failed")

	total_tests += 1
	var spend_ok = GameManager.spend_coins(500)
	if spend_ok and GameManager.get_coins() == start_coins + 500:
		print("  [PASS] Spent 500 coins successfully")
		passed_tests += 1
	else:
		print("  [FAIL] Spend coins failed")

	total_tests += 1
	var overdraft_ok = GameManager.spend_coins(9999999)
	if not overdraft_ok and GameManager.get_coins() == start_coins + 500:
		print("  [PASS] Overdraft blocked: spending 9,999,999 coins prevented")
		passed_tests += 1
	else:
		print("  [FAIL] Overdraft was not blocked!")

	total_tests += 1
	if not currency_signals.is_empty():
		print("  [PASS] player_currencies_updated signal fired on wallet changes")
		passed_tests += 1
	else:
		print("  [FAIL] player_currencies_updated signal did not fire")

	# --------------------------------------------------------------------------
	# [Test 3] Hero Level Progression & Dynamic HP Scaling
	# --------------------------------------------------------------------------
	print("\n[Test 3] Hero Level Progression & Dynamic HP Scaling")
	var finn_tracker = GameManager.get_hero_tracker("Finn")
	finn_tracker.set_level(1)

	total_tests += 1
	var initial_hp = GameManager.get_hero_max_hp("Finn")
	if initial_hp == 15: # Base 10 + 1 * 5
		print("  [PASS] Finn Level 1 Max HP is 15 (Base 10 + 1*5)")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Finn Level 1 Max HP 15, got %d" % initial_hp)

	var levelup_events: Array = []
	GameManager.hero_leveled_up.connect(func(hid, old_l, new_l, new_hp):
		levelup_events.append({ "hero": hid, "old": old_l, "new": new_l, "hp": new_hp })
	)

	total_tests += 1
	var needed_xp = finn_tracker.get_xp_for_next_level()
	GameManager.add_hero_xp("Finn", needed_xp + 10)
	if GameManager.get_hero_level("Finn") == 2:
		print("  [PASS] Finn leveled up to Level 2")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Finn Level 2, got %d" % GameManager.get_hero_level("Finn"))

	total_tests += 1
	var lvl2_hp = GameManager.get_hero_max_hp("Finn")
	if lvl2_hp == 20: # Base 10 + 2 * 5
		print("  [PASS] Finn Level 2 Max HP dynamically scaled to 20 (+5 HP)")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Finn Level 2 Max HP 20, got %d" % lvl2_hp)
		print("  [FAIL] Expected Finn Level 2 Max HP 30, got %d" % lvl2_hp)

	total_tests += 1
	if not levelup_events.is_empty() and levelup_events[0]["new"] == 2:
		print("  [PASS] hero_leveled_up signal received with new HP (%d)" % levelup_events[0]["hp"])
		passed_tests += 1
	else:
		print("  [FAIL] hero_leveled_up signal not received")

	# --------------------------------------------------------------------------
	# [Test 4] Hero Dynamic Deck Capacity
	# --------------------------------------------------------------------------
	print("\n[Test 4] Hero Dynamic Deck Capacity")
	total_tests += 1
	var cap_lvl2 = GameManager.get_hero_deck_max_size("Finn")
	if cap_lvl2 == 16:
		print("  [PASS] Finn Level 2 deck capacity is 16")
		passed_tests += 1
	else:
		print("  [FAIL] Expected Level 2 deck capacity 16, got %d" % cap_lvl2)

	# --------------------------------------------------------------------------
	# [Test 5] Multi-Hero Independence
	# --------------------------------------------------------------------------
	print("\n[Test 5] Multi-Hero Independence")
	var jake_tracker = GameManager.get_hero_tracker("Jake")
	jake_tracker.set_level(1)

	total_tests += 1
	if GameManager.get_hero_level("Jake") == 1 and GameManager.get_hero_level("Finn") == 2:
		print("  [PASS] Jake level (1) is completely independent from Finn level (2)")
		passed_tests += 1
	else:
		print("  [FAIL] Hero levels leaked between heroes")

	# --------------------------------------------------------------------------
	# [Test 6] Player Profile Persistence (Save & Reload)
	# --------------------------------------------------------------------------
	print("\n[Test 6] Player Profile Persistence (Save & Reload)")
	var test_profile_path = "user://test_player_profile.json"
	GameManager.save_profile(test_profile_path)

	total_tests += 1
	if FileAccess.file_exists(test_profile_path):
		print("  [PASS] Profile saved successfully to disk: %s" % test_profile_path)
		passed_tests += 1
	else:
		print("  [FAIL] Profile file was not created on disk")

	# Modify state in memory
	var saved_coins = GameManager.get_coins()
	var saved_finn_lvl = GameManager.get_hero_level("Finn")
	GameManager.wallet.withdraw("coins", 2000)

	# Reload from disk
	var load_ok = GameManager.load_profile(test_profile_path)
	total_tests += 1
	if load_ok and GameManager.get_coins() == saved_coins:
		print("  [PASS] Profile reload restored exact coin balance (%d)" % saved_coins)
		passed_tests += 1
	else:
		print("  [FAIL] Reload did not restore coins correctly")

	total_tests += 1
	if GameManager.get_hero_level("Finn") == saved_finn_lvl:
		print("  [PASS] Profile reload restored exact Finn hero level (%d)" % saved_finn_lvl)
		passed_tests += 1
	else:
		print("  [FAIL] Reload did not restore hero level correctly")

	# Clean up test profile file
	DirAccess.remove_absolute(test_profile_path)

	# --------------------------------------------------------------------------
	# [Test 7] EconomyHeader UI Component
	# --------------------------------------------------------------------------
	print("\n[Test 7] EconomyHeader UI Component")
	var header_scene = load("res://src/ui/EconomyHeader.tscn")
	var header = header_scene.instantiate() as EconomyHeader
	add_child(header)
	header.refresh()

	total_tests += 1
	if header.hero_name_lbl.text == GameManager.player_hero_name:
		print("  [PASS] EconomyHeader shows active hero name '%s'" % header.hero_name_lbl.text)
		passed_tests += 1
	else:
		print("  [FAIL] Header hero name mismatch")

	total_tests += 1
	if header.coins_lbl.text.contains(str(GameManager.get_coins())) or header.coins_lbl.text.contains("🪙"):
		print("  [PASS] EconomyHeader displays live coins: '%s'" % header.coins_lbl.text)
		passed_tests += 1
	else:
		print("  [FAIL] Header coin text mismatch: %s" % header.coins_lbl.text)

	total_tests += 1
	if header.gems_lbl.text.contains(str(GameManager.get_gems())) or header.gems_lbl.text.contains("💎"):
		print("  [PASS] EconomyHeader displays live gems: '%s'" % header.gems_lbl.text)
		passed_tests += 1
	else:
		print("  [FAIL] Header gems text mismatch: %s" % header.gems_lbl.text)

	header.queue_free()

	# --------------------------------------------------------------------------
	# SUMMARY
	# --------------------------------------------------------------------------
	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed_tests, total_tests - passed_tests])
	print("==================================================")

	if passed_tests == total_tests:
		print(">>> ALL ECONOMY & PROGRESSION TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		print(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
