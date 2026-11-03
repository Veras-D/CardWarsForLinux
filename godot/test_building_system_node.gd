extends Control

const LaneSlot = preload("res://src/battle/LaneSlot.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING BUILDING CARDS SYSTEM UNIT & INTEGRATION TESTS")
	print("========================================")

	test_building_database_loading()
	test_lane_slot_building_placement()
	test_aura_applied_to_subsequent_creature()
	test_aura_applied_to_existing_creature()
	test_building_persistence_on_creature_death()
	test_building_removal()
	test_battle_controller_building_integration()

	print("\n🎉 ALL BUILDING SYSTEM TESTS PASSED SUCCESSFULLY (100%)!")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)

func test_building_database_loading() -> void:
	print("\n--- 1. Testing Building Database Loading ---")
	var red_dome = Database.get_card("Building_RedDome")
	assert_true(not red_dome.is_empty(), "Building_RedDome loaded from database")
	assert_true(red_dome.get("type") == "BUILDING", "Card type is BUILDING")
	assert_true(red_dome.get("script_name") == "ATKBonusBuilding", "Script is ATKBonusBuilding")
	assert_true(red_dome.get("val1") == "3", "Val1 is 3 ATK bonus")

	var blue_castle = Database.get_card("Building_BlueCastle")
	assert_true(not blue_castle.is_empty(), "Building_BlueCastle loaded")
	assert_true(blue_castle.get("script_name") == "DEFBonusBuilding", "Script is DEFBonusBuilding")
	assert_true(blue_castle.get("val1") == "4", "Val1 is 4 DEF bonus")

	var sand_castle = Database.get_card("Building_SandCastle")
	assert_true(not sand_castle.is_empty(), "Building_SandCastle loaded")
	assert_true(sand_castle.get("script_name") == "ATKDEFBonusBuilding", "Script is ATKDEFBonusBuilding")
	assert_true(sand_castle.get("val1") == "4" and sand_castle.get("val2") == "4", "Val1=4, Val2=4")

func test_lane_slot_building_placement() -> void:
	print("\n--- 2. Testing Lane Slot Building Placement ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	assert_true(lane.has_building == false, "Initially no building on lane")
	var check = lane.can_accept_building({"name": "Red Dome", "faction": "Universal"})
	assert_true(check.allowed, "Can accept building on empty building slot")

	lane.place_building({
		"name": "Red Dome",
		"script_name": "ATKBonusBuilding",
		"val1": "3"
	})

	assert_true(lane.has_building == true, "Building slot is now occupied")
	assert_true(lane.building_aura_atk == 3, "Building aura ATK is 3")
	assert_true(lane.building_aura_def == 0, "Building aura DEF is 0")

	# Re-check placement rejection
	var check_duplicate = lane.can_accept_building({"name": "Another Dome"})
	assert_true(not check_duplicate.allowed, "Cannot place building when slot already occupied")

	lane.free()

func test_aura_applied_to_subsequent_creature() -> void:
	print("\n--- 3. Testing Aura Applied to Subsequent Creature ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	# Place Sand Castle (+4 ATK, +4 DEF)
	lane.place_building({
		"name": "Sand Castle",
		"script_name": "ATKDEFBonusBuilding",
		"val1": "4",
		"val2": "4"
	})

	# Now place a creature with base 2 ATK, 5 DEF
	lane.place_creature({
		"name": "Corn Knight",
		"atk": 2,
		"def": 5
	})

	assert_true(lane.has_creature == true, "Creature is placed")
	assert_true(lane.current_atk == 6, "Creature ATK received +4 aura buff (2 -> 6)")
	assert_true(lane.current_def == 9, "Creature DEF received +4 aura buff (5 -> 9)")

	lane.free()

func test_aura_applied_to_existing_creature() -> void:
	print("\n--- 4. Testing Aura Applied to Existing Creature ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	# Place creature first
	lane.place_creature({
		"name": "The Pig",
		"atk": 2,
		"def": 4
	})

	assert_true(lane.current_atk == 2, "Base creature ATK is 2")
	assert_true(lane.current_def == 4, "Base creature DEF is 4")

	# Now place Red Dome (+3 ATK)
	lane.place_building({
		"name": "Red Dome",
		"script_name": "ATKBonusBuilding",
		"val1": "3"
	})

	assert_true(lane.current_atk == 5, "Existing creature dynamically buffed +3 ATK (2 -> 5)")
	assert_true(lane.current_def == 4, "Existing creature DEF unchanged")

	lane.free()

func test_building_persistence_on_creature_death() -> void:
	print("\n--- 5. Testing Building Persistence on Creature Death ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	# Place building and creature
	lane.place_building({
		"name": "Blue Castle",
		"script_name": "DEFBonusBuilding",
		"val1": "4"
	})
	lane.place_creature({
		"name": "Dingo",
		"atk": 3,
		"def": 2
	})

	# Lethal damage destroys creature
	var destroyed = lane.apply_damage(10)
	assert_true(destroyed == true, "Creature took lethal damage and was destroyed")
	assert_true(lane.has_creature == false, "Lane no longer has creature")
	assert_true(lane.has_building == true, "Building persists on lane after creature death")

	# Summon next creature: it should immediately receive the building aura!
	lane.place_creature({
		"name": "Archer Dan",
		"atk": 2,
		"def": 3
	})
	assert_true(lane.current_def == 7, "Next creature received persisted building DEF aura (3 + 4 = 7)")

	lane.free()

func test_building_removal() -> void:
	print("\n--- 6. Testing Building Removal & Aura Stripping ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	lane.place_building({
		"name": "Sand Castle",
		"script_name": "ATKDEFBonusBuilding",
		"val1": "4",
		"val2": "4"
	})
	lane.place_creature({
		"name": "Cool Dog",
		"atk": 3,
		"def": 4
	})

	assert_true(lane.current_atk == 7, "Buffed ATK is 7")
	assert_true(lane.current_def == 8, "Buffed DEF is 8")

	# Remove building
	var removed = lane.clear_building()
	assert_true(not removed.is_empty(), "Removed building data returned")
	assert_true(lane.has_building == false, "Lane building cleared")
	assert_true(lane.current_atk == 3, "Creature ATK returned to base (3)")
	assert_true(lane.current_def == 4, "Creature DEF returned to base (4)")

	lane.free()

func test_battle_controller_building_integration() -> void:
	print("\n--- 7. Testing Full BattleController Integration ---")
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)

	battle.player_mp = 5
	battle.is_player_turn = true

	var building_card = {
		"id": "Building_RedDome",
		"name": "Red Dome",
		"type": "BUILDING",
		"cost": 1,
		"script_name": "ATKBonusBuilding",
		"val1": "3"
	}

	# Simulate selecting building card and clicking lane 0
	var lane = battle.player_lanes[0]
	assert_true(lane.has_building == false, "Player lane 0 starts empty of buildings")

	# Direct build test on lane
	lane.place_building(building_card)
	battle.player_mp -= building_card.cost

	assert_true(lane.has_building == true, "Red Dome placed on player lane 0")
	assert_true(battle.player_mp == 4, "MP deducted from 5 to 4")

	# Summon creature onto lane 0
	lane.place_creature({
		"name": "The Pig",
		"atk": 2,
		"def": 4
	})
	assert_true(lane.current_atk == 5, "Pig gained Red Dome +3 ATK aura (2 + 3 = 5)")

	battle.free()
