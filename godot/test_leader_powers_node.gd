extends Control

const LeaderPowerButton = preload("res://src/battle/LeaderPowerButton.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING LEADER POWERS UNIT & INTEGRATION TESTS")
	print("========================================")

	# 1. Test Database Leader Loading
	test_database_leaders()

	# 2. Test LeaderPowerButton Component
	test_leader_power_button()

	# 3. Test Battle Leader Power Execution
	test_leader_power_execution()

	print("\n🎉 ALL LEADER POWER TESTS PASSED SUCCESSFULLY!")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)

func test_database_leaders() -> void:
	print("\n--- 1. Testing Database Leader Blueprints ---")
	var finn = Database.get_leader("Finn")
	assert_true(not finn.is_empty(), "Finn leader blueprint loaded")
	assert_true(finn.get("cooldown") == 5, "Finn cooldown is 5 turns")
	assert_true(finn.get("script_name") == "GainActionPointsLeader", "Finn script is GainActionPointsLeader")
	assert_true(finn.get("val1") == "2", "Finn Val1 is 2")

	var jake = Database.get_leader("Jake")
	assert_true(not jake.is_empty(), "Jake leader blueprint loaded")
	assert_true(jake.get("cooldown") == 3, "Jake cooldown is 3 turns")
	assert_true(jake.get("script_name") == "ATKBonusFactionCreaturesLeader", "Jake script is ATKBonusFactionCreaturesLeader")
	assert_true(jake.get("for_faction") == "Corn", "Jake faction target is Corn")
	assert_true(jake.get("val1") == "3", "Jake Val1 is 3")

	var pbg = Database.get_leader("PrincessBubblegum")
	assert_true(not pbg.is_empty(), "PrincessBubblegum leader blueprint loaded")
	assert_true(pbg.get("cooldown") == 4, "PBG cooldown is 4 turns")
	assert_true(pbg.get("script_name") == "HealAllCreaturesLeader", "PBG script is HealAllCreaturesLeader")

	var marceline = Database.get_leader("Marceline")
	assert_true(not marceline.is_empty(), "Marceline leader blueprint loaded")
	assert_true(marceline.get("cooldown") == 3, "Marceline cooldown is 3 turns")
	assert_true(marceline.get("script_name") == "ATKBonusAllCreaturesLeader", "Marceline script is ATKBonusAllCreaturesLeader")

func test_leader_power_button() -> void:
	print("\n--- 2. Testing LeaderPowerButton Component ---")
	var btn_scene = load("res://scenes/components/LeaderPowerButton.tscn")
	var btn = btn_scene.instantiate() as LeaderPowerButton
	add_child(btn)

	btn.setup("Finn", true)
	assert_true(btn.character_id == "Finn", "Button character_id set to Finn")
	assert_true(btn.max_cooldown == 5, "Button max_cooldown is 5")
	assert_true(btn.current_cooldown == 5, "Button initial cooldown is 5")
	assert_true(btn.main_button.disabled == true, "Button is disabled when on cooldown")
	assert_true("5 Turns" in btn.status_label.text, "Status label displays 5 turns")

	# Decrement cooldown to 1
	btn.update_cooldown(1)
	assert_true(btn.main_button.disabled == true, "Button still disabled at 1 turn")
	assert_true("1 Turn" in btn.status_label.text, "Status label displays 1 turn")

	# Ready state at cooldown 0
	btn.update_cooldown(0)
	assert_true(btn.main_button.disabled == false, "Button enabled when cooldown reaches 0")
	assert_true("READY" in btn.status_label.text, "Status label displays READY")
	assert_true(btn.is_ready_pulse_active == true, "Ready pulse animation is active")

	# Signal emission on activation
	var box = {"activated_hero": ""}
	btn.power_activated.connect(func(h_id): box["activated_hero"] = h_id)
	btn._on_button_pressed()
	assert_true(box["activated_hero"] == "Finn", "Clicking ready button emits power_activated signal with 'Finn'")

	btn.free()

func test_leader_power_execution() -> void:
	print("\n--- 3. Testing Battle Controller Leader Power Integration ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	# Verify battle initialization
	assert_true(battle.player_leader_id == "Finn", "Battle player leader initialized to Finn")
	assert_true(battle.player_leader_cooldown == 5, "Player leader cooldown initialized to 5")
	assert_true(battle.opponent_leader_id == "Jake", "Battle opponent leader initialized to Jake")
	assert_true(battle.opponent_leader_cooldown == 3, "Opponent leader cooldown initialized to 3")

	# Simulate turn cooldown decrements
	battle.player_leader_cooldown = 1
	battle.start_player_turn()
	assert_true(battle.player_leader_cooldown == 0, "Player cooldown decremented to 0 at turn start")
	assert_true(battle.player_leader_btn.main_button.disabled == false, "Player button enabled when cooldown reaches 0")

	# Test Finn Power: Gain 2 MP
	var initial_mp = battle.player_mp
	battle._execute_leader_power(true, "Finn")
	assert_true(battle.player_mp == initial_mp + 2, "Finn power added +2 MP (from %d to %d)" % [initial_mp, battle.player_mp])
	assert_true(battle.player_leader_cooldown == 5, "Finn cooldown reset to 5 after execution")

	# Test Jake Power: +3 ATK to Corn creatures
	var corn_card = {
		"id": "Creature_Cornball",
		"name": "Cornball",
		"type": "CREATURE",
		"faction": "Corn",
		"atk": 2,
		"def": 5,
		"cost": 1
	}
	var plains_card = {
		"id": "Creature_Pig",
		"name": "The Pig",
		"type": "CREATURE",
		"faction": "Plains",
		"atk": 2,
		"def": 4,
		"cost": 1
	}
	# Place creatures in opponent lanes
	battle.opponent_lanes[0].place_creature(corn_card)
	battle.opponent_lanes[1].place_creature(plains_card)

	var orig_corn_atk = battle.opponent_lanes[0].current_atk
	var orig_plains_atk = battle.opponent_lanes[1].current_atk

	battle._execute_leader_power(false, "Jake")
	assert_true(battle.opponent_lanes[0].current_atk == orig_corn_atk + 3, "Jake power buffed Corn creature ATK by +3")
	assert_true(battle.opponent_lanes[1].current_atk == orig_plains_atk, "Jake power did NOT buff non-Corn creature")
	assert_true(battle.opponent_leader_cooldown == 3, "Jake cooldown reset to 3 after execution")

	# Test Princess Bubblegum Power: Heal all friendly creatures to full
	battle.opponent_lanes[0].current_def = 1
	battle._execute_leader_power(false, "PrincessBubblegum")
	assert_true(battle.opponent_lanes[0].current_def == 5, "PBG power healed damaged creature to full DEF (5)")

	# Test Marceline Power: +2 ATK to all friendly creatures
	var marce_atk_corn = battle.opponent_lanes[0].current_atk
	var marce_atk_plains = battle.opponent_lanes[1].current_atk
	battle._execute_leader_power(false, "Marceline")
	assert_true(battle.opponent_lanes[0].current_atk == marce_atk_corn + 2, "Marceline buffed lane 0 by +2 ATK")
	assert_true(battle.opponent_lanes[1].current_atk == marce_atk_plains + 2, "Marceline buffed lane 1 by +2 ATK")

	battle.free()
