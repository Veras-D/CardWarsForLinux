extends Node

func _ready() -> void:
	GameManager.suppress_profile_save = true
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
	# Test 6: DungeonArenaModal UI Lifecycle & Strict Level Gate
	# -------------------------------------------------------------
	print("\n[Test 6] DungeonArenaModal UI Component")
	var modal_scene = load("res://scenes/dungeon_arena_modal.tscn").instantiate()
	add_child(modal_scene)

	modal_scene.open_modal(false)
	var gate = GameManager.validate_dungeon_entry()
	var expect_locked = not bool(gate.get("ok", false))
	if modal_scene.visible and modal_scene.locked_gate_panel.visible == expect_locked:
		print("  [PASS] Modal opened with strict level gate respected (locked=%s)" % str(expect_locked))
		passed += 1
	else:
		printerr("  [FAIL] Modal failed strict gate check")
		failed += 1

	modal_scene.open_modal(true)
	if modal_scene.stages_panel.visible and modal_scene.stages_list.get_child_count() == 5:
		print("  [PASS] Stages panel displays 5 dungeon stages")
		passed += 1
	else:
		printerr("  [FAIL] Expected 5 stage rows, got %d" % modal_scene.stages_list.get_child_count())
		failed += 1

	modal_scene.close_btn.emit_signal("pressed")
	await get_tree().create_timer(0.45).timeout
	if not modal_scene.visible:
		print("  [PASS] Modal closed cleanly on close button")
		passed += 1
	else:
		printerr("  [FAIL] Modal should be hidden after close")
		failed += 1

	modal_scene.queue_free()

	# -------------------------------------------------------------
	# Test 7: Daily Gift Blueprints, Spin & UI Modal
	# -------------------------------------------------------------
	print("\n[Test 7] Daily Gift Blueprints & UI")
	var gift_entries = Database.get_daily_gift_entries()
	var has_hearts = false
	for ge in gift_entries:
		if str(ge.get("type", "")) == "Hearts":
			has_hearts = true
	if gift_entries.size() == 12 and not has_hearts:
		print("  [PASS] Exactly 12 Daily Gift slots loaded from db_DailyGift.json (no Hearts)")
		passed += 1
	else:
		printerr("  [FAIL] Daily gift slot check failed (size=%d, has_hearts=%s)" % [gift_entries.size(), str(has_hearts)])
		failed += 1

	var prev_ts = GameManager.last_daily_gift_timestamp
	var prev_coins = GameManager.get_coins()
	var prev_gems = GameManager.get_gems()
	GameManager.last_daily_gift_timestamp = 0
	var spin_res = GameManager.start_daily_gift_spin(false)
	if bool(spin_res.get("ok", false)) and bool(spin_res.get("used_free", false)):
		print("  [PASS] Free Daily Gift spin succeeded")
		passed += 1
	else:
		printerr("  [FAIL] Free Daily Gift spin failed: %s" % str(spin_res))
		failed += 1

	# Second immediate spin without retry flag should reject due to 24h cooldown
	var cooldown_res = GameManager.start_daily_gift_spin(false)
	if not bool(cooldown_res.get("ok", false)) and int(cooldown_res.get("cooldown", 0)) > 0:
		print("  [PASS] 24h Daily Gift cooldown enforced")
		passed += 1
	else:
		printerr("  [FAIL] Cooldown was not enforced")
		failed += 1

	# Restore timestamp/wallet state so test leaves profile untouched
	GameManager.last_daily_gift_timestamp = prev_ts
	GameManager.player_coins = prev_coins
	var gem_diff = GameManager.get_gems() - prev_gems
	if gem_diff > 0:
		GameManager.spend_gems(gem_diff)

	var gift_modal = load("res://scenes/daily_gift_modal.tscn").instantiate()
	add_child(gift_modal)
	gift_modal.open_modal(0)
	if gift_modal.visible and gift_modal._cell_panels.size() == 12:
		print("  [PASS] DailyGiftModal opened with 12 prize cells")
		passed += 1
	else:
		printerr("  [FAIL] DailyGiftModal cell count mismatch")
		failed += 1
	gift_modal.queue_free()

	print("\n==================================================")
	print("  TEST SUMMARY: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")

	if failed == 0:
		print(">>> ALL DAILY DUNGEONS & EL FISTO TESTS COMPLETED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
