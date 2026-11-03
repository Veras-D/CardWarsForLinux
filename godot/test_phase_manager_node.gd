extends Control

const BattlePhaseManager = preload("res://src/battle/BattlePhaseManager.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING BATTLE PHASE MANAGER UNIT TESTS")
	print("========================================")

	test_initialization()
	test_valid_transition_lifecycle()
	test_illegal_transition_rejection()
	test_action_permissions()
	test_turn_rotation_and_counter()
	test_match_over()
	test_battle_controller_combat_flow()

	print("\n🎉 ALL BATTLE PHASE MANAGER TESTS PASSED SUCCESSFULLY (100%)!")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)

func test_initialization() -> void:
	print("\n--- 1. Testing Initialization ---")
	var pm = BattlePhaseManager.new()
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.NONE, "Initial phase is NONE")
	assert_true(pm.get_active_player() == 0, "Default player is 0")
	assert_true(pm.get_turn_number() == 1, "Initial turn number is 1")
	assert_true(pm.get_current_combat_lane() == 0, "Initial combat lane is 0")

	pm.start_battle(0)
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.START_TURN, "Phase after start_battle() is START_TURN")
	assert_true(pm.is_player_turn() == true, "Active player is player 0")
	pm.free()

func test_valid_transition_lifecycle() -> void:
	print("\n--- 2. Testing Valid Transition Lifecycle ---")
	var pm = BattlePhaseManager.new()
	pm.start_battle(0)

	var transitions_recorded: Array = []
	pm.phase_changed.connect(func(n, o):
		transitions_recorded.append([o, n])
	)

	# START_TURN -> ACTION_PHASE
	assert_true(pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE), "Can transition to ACTION_PHASE")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.ACTION_PHASE, "Current phase is ACTION_PHASE")

	# ACTION_PHASE -> BATTLE_WHEEL_PHASE
	assert_true(pm.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE), "Can transition to BATTLE_WHEEL_PHASE")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE, "Current phase is BATTLE_WHEEL_PHASE")

	# BATTLE_WHEEL_PHASE -> COMBAT_RESOLUTION
	assert_true(pm.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION), "Can transition to COMBAT_RESOLUTION")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.COMBAT_RESOLUTION, "Current phase is COMBAT_RESOLUTION")

	# COMBAT_RESOLUTION -> END_TURN
	assert_true(pm.transition_to(BattlePhaseManager.Phase.END_TURN), "Can transition to END_TURN")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.END_TURN, "Current phase is END_TURN")

	# END_TURN -> START_TURN (Next turn begins)
	assert_true(pm.transition_to(BattlePhaseManager.Phase.START_TURN), "Can transition back to START_TURN for next player")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.START_TURN, "Current phase is START_TURN")
	assert_true(pm.get_active_player() == 1, "Active player transitioned to opponent (1)")

	assert_true(transitions_recorded.size() == 5, "All 5 phase changes emitted signal correctly")
	pm.free()

func test_illegal_transition_rejection() -> void:
	print("\n--- 3. Testing Illegal Transition Rejection ---")
	var pm = BattlePhaseManager.new()
	pm.start_battle(0)

	# START_TURN cannot jump directly to COMBAT_RESOLUTION
	assert_true(not pm.can_transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION), "can_transition_to(COMBAT_RESOLUTION) is false from START_TURN")
	var res = pm.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
	assert_true(not res, "Direct jump to COMBAT_RESOLUTION rejected")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.START_TURN, "Phase remained START_TURN")

	# START_TURN cannot jump to END_TURN
	assert_true(not pm.transition_to(BattlePhaseManager.Phase.END_TURN), "Direct jump to END_TURN rejected")

	pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)
	# ACTION_PHASE cannot jump back to START_TURN
	assert_true(not pm.transition_to(BattlePhaseManager.Phase.START_TURN), "Reverse jump to START_TURN rejected")
	pm.free()

func test_action_permissions() -> void:
	print("\n--- 4. Testing Action Permissions ---")
	var pm = BattlePhaseManager.new()
	pm.start_battle(0)

	# In START_TURN, actions should be forbidden
	assert_true(not pm.is_action_allowed(0), "Player cannot act in START_TURN")
	assert_true(not pm.is_action_allowed(1), "Opponent cannot act in START_TURN")

	# Move to ACTION_PHASE
	pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)
	assert_true(pm.is_action_allowed(0), "Player can act during player ACTION_PHASE")
	assert_true(not pm.is_action_allowed(1), "Opponent cannot act during player ACTION_PHASE")

	# Move to BATTLE_WHEEL_PHASE
	pm.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	assert_true(not pm.is_action_allowed(0), "Player cannot act during BATTLE_WHEEL_PHASE")

	# Move to COMBAT_RESOLUTION
	pm.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
	assert_true(not pm.is_action_allowed(0), "Player cannot act during COMBAT_RESOLUTION")
	pm.free()

func test_turn_rotation_and_counter() -> void:
	print("\n--- 5. Testing Turn Rotation and Counter ---")
	var pm = BattlePhaseManager.new()
	pm.start_battle(0)

	var turn_started_events: Array = []
	var turn_ended_events: Array = []
	pm.turn_started.connect(func(p, t): turn_started_events.append([p, t]))
	pm.turn_ended.connect(func(p, t): turn_ended_events.append([p, t]))

	assert_true(pm.get_active_player() == 0, "Round 1 Player turn")
	assert_true(pm.get_turn_number() == 1, "Turn number is 1")

	# Finish player 0's turn
	pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)
	pm.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	pm.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
	pm.transition_to(BattlePhaseManager.Phase.END_TURN)

	assert_true(pm.get_active_player() == 1, "Active player switched to 1 after END_TURN")
	assert_true(pm.get_turn_number() == 1, "Turn number is still 1 during opponent phase of round 1")

	# Opponent turn starts
	pm.transition_to(BattlePhaseManager.Phase.START_TURN)
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.START_TURN, "Opponent turn started")
	assert_true(not pm.is_player_turn(), "is_player_turn is false during opponent turn")

	# Finish opponent's turn
	pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)
	pm.transition_to(BattlePhaseManager.Phase.BATTLE_WHEEL_PHASE)
	pm.transition_to(BattlePhaseManager.Phase.COMBAT_RESOLUTION)
	pm.transition_to(BattlePhaseManager.Phase.END_TURN)

	assert_true(pm.get_active_player() == 0, "Active player switched back to 0")
	assert_true(pm.get_turn_number() == 2, "Turn number incremented to 2 for next round")
	pm.free()

func test_match_over() -> void:
	print("\n--- 6. Testing Match Over ---")
	var pm = BattlePhaseManager.new()
	pm.start_battle(0)
	pm.transition_to(BattlePhaseManager.Phase.ACTION_PHASE)

	var result = {"called": false, "victory": false}
	pm.match_ended.connect(func(v: bool):
		result["called"] = true
		result["victory"] = v
	)

	pm.end_match(true)
	assert_true(result["called"], "match_ended signal emitted")
	assert_true(result["victory"] == true, "Victory result is true")
	assert_true(pm.get_current_phase() == BattlePhaseManager.Phase.MATCH_OVER, "Current phase is MATCH_OVER")
	assert_true(not pm.can_transition_to(BattlePhaseManager.Phase.START_TURN), "No transitions allowed after MATCH_OVER")
	pm.free()

func test_battle_controller_combat_flow() -> void:
	print("\n--- 7. Testing Battle Controller & Wheel Clash Regression ---")
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)

	assert_true(GameManager.wheel_mode == "NORMAL", "GameManager.wheel_mode is initialized")
	assert_true(battle.wheel_modal != null, "Battle has wheel_modal")

	# Setup a creature on player lane 0 and opponent lane 0
	battle.player_lanes[0].place_creature({
		"name": "Test Pig",
		"atk": 5,
		"def": 2
	})
	battle.opponent_lanes[0].place_creature({
		"name": "Test Cornball",
		"atk": 1,
		"def": 3
	})

	# Test destroying creature through apply_damage (regression check for creature_data.name)
	var opp_lane = battle.opponent_lanes[0]
	var opp_name = opp_lane.creature_data.get("name", "Creature")
	var destroyed = opp_lane.apply_damage(10)
	assert_true(destroyed, "Opponent creature destroyed by lethal damage")
	assert_true(opp_lane.has_creature == false, "Opponent lane is now empty")

	# Test wheel modal clash invocation doesn't crash on wheel_mode
	battle.wheel_modal.start_attack_clash("Test Pig", "Jake", 5, true, 0.8, 0.05, true)
	assert_true(battle.wheel_modal.visible == true, "Wheel modal is displayed for clash")

	battle.free()
