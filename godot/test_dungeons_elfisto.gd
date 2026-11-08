extends Node

func _ready() -> void:
	print("\n==================================================")
	print("  RUNNING DAILY DUNGEONS & EL FISTO ARENA TEST SUITE (Task 7.4)")
	print("==================================================\n")

	var passed = 0
	var failed = 0

	# -------------------------------------------------------------
	# Test 1: Daily Dungeons Database Catalog
	# -------------------------------------------------------------
	print("[Test 1] Daily Dungeons Database Catalog")
	var dungeons = Database.get_daily_dungeons()
	if dungeons.size() == 7:
		print("  [PASS] Exactly 7 daily dungeons loaded")
		passed += 1
	else:
		printerr("  [FAIL] Expected 7 dungeons, got %d" % dungeons.size())
		failed += 1

	# Verify Monday and Sunday dungeons
	var mon_dungeon = Database.get_dungeon_for_weekday(1) # Mon = 1
	if mon_dungeon.get("dungeon") == "Monday Dungeon":
		print("  [PASS] Weekday 1 maps to 'Monday Dungeon'")
		passed += 1
	else:
		printerr("  [FAIL] Weekday 1 mismatch: %s" % str(mon_dungeon))
		failed += 1

	var sun_dungeon = Database.get_dungeon_for_weekday(0) # Sun = 0
	if sun_dungeon.get("dungeon") == "Sunday Dungeon":
		print("  [PASS] Weekday 0 maps to 'Sunday Dungeon'")
		passed += 1
	else:
		printerr("  [FAIL] Weekday 0 mismatch: %s" % str(sun_dungeon))
		failed += 1

	# Verify 5 stages per dungeon
	var mon_stages = Database.get_dungeon_stages("Monday Dungeon")
	if mon_stages.size() == 5:
		print("  [PASS] Monday Dungeon contains 5 stages")
		passed += 1
	else:
		printerr("  [FAIL] Expected 5 stages, got %d" % mon_stages.size())
		failed += 1

	if int(mon_stages[0].get("heart_cost")) == 5 and int(mon_stages[4].get("heart_cost")) == 25:
		print("  [PASS] Stage stamina costs scale from 5 to 25")
		passed += 1
	else:
		printerr("  [FAIL] Stage costs mismatch")
		failed += 1

	# -------------------------------------------------------------
	# Test 2: Dungeon Stage Unlocking & Progression
	# -------------------------------------------------------------
	print("\n[Test 2] Dungeon Stage Unlocking & Progression")
	var dname = "Monday Dungeon"
	GameManager.dungeon_stage_clears.clear()

	if GameManager.is_dungeon_stage_unlocked(dname, 0):
		print("  [PASS] Stage 0 (first stage) is unlocked by default")
		passed += 1
	else:
		printerr("  [FAIL] Stage 0 should be unlocked by default")
		failed += 1

	if not GameManager.is_dungeon_stage_unlocked(dname, 1):
		print("  [PASS] Stage 1 is locked before Stage 0 is cleared")
		passed += 1
	else:
		printerr("  [FAIL] Stage 1 should be locked")
		failed += 1

	# Complete Stage 0
	GameManager.complete_dungeon_stage(dname, 0)
	if GameManager.is_dungeon_stage_unlocked(dname, 1):
		print("  [PASS] Stage 1 unlocked after Stage 0 cleared")
		passed += 1
	else:
		printerr("  [FAIL] Stage 1 failed to unlock")
		failed += 1

	# -------------------------------------------------------------
	# Test 3: El Fisto Survival Gauntlet Database
	# -------------------------------------------------------------
	print("\n[Test 3] El Fisto Survival Gauntlet Database")
	var ef_rounds = Database.get_elfisto_rounds()
	if ef_rounds.size() == 8:
		print("  [PASS] Exactly 8 rounds in El Fisto Gauntlet")
		passed += 1
	else:
		printerr("  [FAIL] Expected 8 rounds, got %d" % ef_rounds.size())
		failed += 1

	var r1 = Database.get_elfisto_round(1)
	if r1.get("reward_type") == "Card Creature_GL_BanshePrincess":
		print("  [PASS] Round 1 reward is Banshee Princess card")
		passed += 1
	else:
		printerr("  [FAIL] Round 1 reward mismatch: %s" % str(r1))
		failed += 1

	var r2 = Database.get_elfisto_round(2)
	if r2.get("reward_type") == "Gems" and r2.get("reward_quantity") == 3:
		print("  [PASS] Round 2 reward is 3 Gems")
		passed += 1
	else:
		printerr("  [FAIL] Round 2 reward mismatch: %s" % str(r2))
		failed += 1

	var r8 = Database.get_elfisto_round(8)
	if r8.get("reward_type") == "Card Creature_GL_Unicyclops":
		print("  [PASS] Round 8 grand prize is Unicyclops card")
		passed += 1
	else:
		printerr("  [FAIL] Round 8 reward mismatch: %s" % str(r8))
		failed += 1

	# -------------------------------------------------------------
	# Test 4: El Fisto Survival Mechanics & HP Carryover
	# -------------------------------------------------------------
	print("\n[Test 4] El Fisto Survival HP Carryover & Run Progression")
	GameManager.start_elfisto_run()
	if GameManager.elfisto_is_active_run and GameManager.elfisto_current_round == 1:
		print("  [PASS] El Fisto run started at Round 1")
		passed += 1
	else:
		printerr("  [FAIL] Failed to start El Fisto run")
		failed += 1

	# Win Round 1 with 18 HP remaining
	var inv_count_before = GameManager.player_inventory_cards.size()
	var res_r1 = GameManager.record_elfisto_battle_result(true, 18)
	if res_r1.get("won") == true and res_r1.get("next_round") == 2:
		print("  [PASS] Round 1 victory advanced to Round 2")
		passed += 1
	else:
		printerr("  [FAIL] Round 1 result mismatch: %s" % str(res_r1))
		failed += 1

	if GameManager.elfisto_hero_hp_current == 18:
		print("  [PASS] Hero survival HP preserved at 18")
		passed += 1
	else:
		printerr("  [FAIL] Expected 18 HP, got %d" % GameManager.elfisto_hero_hp_current)
		failed += 1

	if GameManager.player_inventory_cards.has("Creature_GL_BanshePrincess"):
		print("  [PASS] Banshee Princess added to player inventory")
		passed += 1
	else:
		printerr("  [FAIL] Banshee Princess card not awarded")
		failed += 1

	# Win Round 2 with 12 HP remaining
	var gems_before = GameManager.get_gems()
	var res_r2 = GameManager.record_elfisto_battle_result(true, 12)
	if GameManager.elfisto_current_round == 3 and GameManager.get_gems() == gems_before + 3:
		print("  [PASS] Round 2 victory awarded 3 Gems and advanced to Round 3")
		passed += 1
	else:
		printerr("  [FAIL] Round 2 gems or progression failed")
		failed += 1

	if GameManager.elfisto_consecutive_wins == 2:
		print("  [PASS] Consecutive wins streak matches 2")
		passed += 1
	else:
		printerr("  [FAIL] Streak mismatch: %d" % GameManager.elfisto_consecutive_wins)
		failed += 1

	# Simulate defeat on Round 3: should reset run
	var res_loss = GameManager.record_elfisto_battle_result(false, 0)
	if res_loss.get("reset") == true and GameManager.elfisto_current_round == 1 and not GameManager.elfisto_is_active_run:
		print("  [PASS] Defeat in gauntlet cleanly reset run to Round 1")
		passed += 1
	else:
		printerr("  [FAIL] Defeat failed to reset run: %s" % str(res_loss))
		failed += 1

	# -------------------------------------------------------------
	# Test 5: Profile Persistence for Dungeons & El Fisto
	# -------------------------------------------------------------
	print("\n[Test 5] Profile Persistence (Dungeons & El Fisto)")
	var test_profile_path = "user://test_dungeon_profile.json"
	GameManager.save_profile(test_profile_path)
	if FileAccess.file_exists(test_profile_path):
		print("  [PASS] Profile saved successfully")
		passed += 1
	else:
		printerr("  [FAIL] Save failed")
		failed += 1

	var file = FileAccess.open(test_profile_path, FileAccess.READ)
	var json = JSON.new()
	json.parse(file.get_as_text())
	file.close()
	DirAccess.remove_absolute(test_profile_path)

	var pdata = json.data
	if pdata.has("dungeon_stage_clears") and pdata.has("elfisto"):
		print("  [PASS] Profile contains 'dungeon_stage_clears' and 'elfisto'")
		passed += 1
	else:
		printerr("  [FAIL] Profile missing keys: %s" % str(pdata.keys()))
		failed += 1

	# -------------------------------------------------------------
	# Test 6: DungeonArenaModal UI Lifecycle & Tab Switching
	# -------------------------------------------------------------
	print("\n[Test 6] DungeonArenaModal UI Component")
	var modal_scene = load("res://scenes/dungeon_arena_modal.tscn").instantiate()
	add_child(modal_scene)

	modal_scene.open_modal()
	if modal_scene.visible and modal_scene.dungeons_container.visible:
		print("  [PASS] Modal opened on Dungeons tab")
		passed += 1
	else:
		printerr("  [FAIL] Modal failed to open on Dungeons tab")
		failed += 1

	modal_scene.show_tab(1)
	if modal_scene.elfisto_container.visible and not modal_scene.dungeons_container.visible:
		print("  [PASS] Switched to El Fisto Gauntlet tab")
		passed += 1
	else:
		printerr("  [FAIL] Failed to switch to El Fisto tab")
		failed += 1

	if modal_scene.elfisto_ladder_list.get_child_count() == 8:
		print("  [PASS] El Fisto ladder displays 8 rounds")
		passed += 1
	else:
		printerr("  [FAIL] Expected 8 ladder children, got %d" % modal_scene.elfisto_ladder_list.get_child_count())
		failed += 1

	modal_scene.close_btn.emit_signal("pressed")
	if not modal_scene.visible:
		print("  [PASS] Modal closed on close button")
		passed += 1
	else:
		printerr("  [FAIL] Modal should be hidden after close")
		failed += 1

	modal_scene.queue_free()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")

	if failed == 0:
		print(">>> ALL DAILY DUNGEONS & EL FISTO TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
