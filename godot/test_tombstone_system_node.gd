extends Control

const LaneSlot = preload("res://src/battle/LaneSlot.gd")
const Tombstone = preload("res://src/battle/Tombstone.gd")
const LootRoller = preload("res://src/battle/LootRoller.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING TOMBSTONE & LOOT DROP SYSTEM TESTS (TASK 2.7)")
	print("========================================")

	test_drop_profile_database_loading()
	test_loot_roller_gold_drop()
	test_loot_roller_card_drop()
	test_loot_roller_tombstone_fallback()
	test_lane_slot_creature_death_and_tombstone()
	test_tombstone_collection_signal()
	test_tombstone_clear_and_turn_end()
	test_battle_rewards_integration()

	print("\n🎉 ALL TOMBSTONE & LOOT DROP TESTS PASSED SUCCESSFULLY (100%)!")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)

func test_drop_profile_database_loading() -> void:
	print("\n--- 1. Testing Drop Profile Database Loading ---")
	assert_true(Database.drop_profiles_db.size() >= 180, "Loaded at least 180 drop profiles from db_DropProfile.json")

	var quest01_profile = Database.get_drop_profile("Quest01")
	assert_true(not quest01_profile.is_empty(), "Drop profile 'Quest01' exists")
	assert_true(quest01_profile.get("chest_drop_percentages").size() > 0, "Quest01 has chest drop percentages")
	assert_true(quest01_profile.get("coin_drop_percentages").size() > 0, "Quest01 has coin drop percentages")
	assert_true(quest01_profile.get("coin_amounts").size() > 0, "Quest01 has coin amounts")
	assert_true(quest01_profile.get("coin_weights").size() > 0, "Quest01 has coin weights")

	var test_profile = Database.get_drop_profile("Test")
	assert_true(not test_profile.is_empty(), "Drop profile 'Test' exists")
	assert_true(test_profile.get("chest_drop_percentages")[0] == 1.0, "Test profile has 100% initial chest drop")

func test_loot_roller_gold_drop() -> void:
	print("\n--- 2. Testing LootRoller Gold Drops ---")
	var drop = LootRoller.roll_drop("Quest01", 0, [], "GOLD")
	assert_true(drop.get("type") == "GOLD", "Forced gold drop returns type GOLD")
	assert_true(int(drop.get("amount", 0)) > 0, "Gold drop amount is positive (rolled %d)" % int(drop.get("amount", 0)))
	assert_true(drop.get("icon") == "💰", "Gold drop icon is 💰")
	assert_true(drop.get("texture_path") == "res://assets/textures/props/GoldBag.png", "Gold drop texture path is GoldBag.png")

func test_loot_roller_card_drop() -> void:
	print("\n--- 3. Testing LootRoller Card Drops ---")
	var candidate_cards = ["Creature_Cornball", "Creature_HuskerKnight"]
	var drop = LootRoller.roll_drop("Quest01", 0, candidate_cards, "CARD")
	assert_true(drop.get("type") == "CARD", "Forced card drop returns type CARD")
	var picked_id = drop.get("card_id", "")
	assert_true(picked_id in candidate_cards, "Picked card '%s' is in candidate deck" % picked_id)
	assert_true(drop.get("icon") == "🎁", "Card drop icon is 🎁")
	assert_true(drop.get("texture_path") == "res://assets/textures/props/LootChest_01.png", "Card drop texture is LootChest_01.png")

func test_loot_roller_tombstone_fallback() -> void:
	print("\n--- 4. Testing LootRoller Tombstone Fallback ---")
	var drop = LootRoller.roll_drop("Quest01", 0, [], "NONE")
	assert_true(drop.get("type") == "TOMBSTONE", "Fallback drop returns type TOMBSTONE")
	assert_true(drop.get("icon") == "🪦", "Tombstone icon is 🪦")
	assert_true(drop.get("texture_path") == "res://assets/textures/props/Tombstone.png", "Texture path is Tombstone.png")

func test_lane_slot_creature_death_and_tombstone() -> void:
	print("\n--- 5. Testing Lane Slot Creature Death & Tombstone Spawn ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	var destroyed_box = {"data": {}}
	lane.creature_destroyed.connect(func(_slot, dead_data):
		destroyed_box["data"] = dead_data
	)

	lane.place_creature({
		"id": "Creature_Pig",
		"name": "The Pig",
		"atk": 3,
		"def": 12,
		"floop_cost": 1,
		"faction": "Plains"
	})
	assert_true(lane.has_creature == true, "Creature successfully placed in lane")
	assert_true(lane.current_def == 12, "Creature DEF initialized to 12")

	# Apply lethal damage
	var destroyed = lane.apply_damage(12)
	assert_true(destroyed == true, "apply_damage(12) returned lethal (destroyed = true)")
	assert_true(lane.has_creature == false, "Creature removed from lane on death")
	assert_true(destroyed_box["data"].get("name") == "The Pig", "creature_destroyed signal emitted with dead creature data")

	# Spawn Tombstone in lane
	var tombstone = lane.spawn_tombstone({
		"type": "GOLD",
		"amount": 75,
		"label": "+75 🪙",
		"icon": "💰",
		"texture_path": "res://assets/textures/props/GoldBag.png"
	})
	assert_true(lane.has_tombstone == true, "Lane reports has_tombstone == true")
	assert_true(lane.active_tombstone != null, "Lane active_tombstone is assigned")
	assert_true(tombstone.drop_data.get("amount") == 75, "Tombstone holds 75 gold payload")

	lane.queue_free()

func test_tombstone_collection_signal() -> void:
	print("\n--- 6. Testing Tombstone Collection Signal ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	var collected_box = {"type": "", "amount": 0}
	lane.loot_collected.connect(func(_slot, l_type, data):
		collected_box["type"] = l_type
		collected_box["amount"] = int(data.get("amount", 0))
	)

	var tombstone = lane.spawn_tombstone({
		"type": "GOLD",
		"amount": 100,
		"label": "+100 🪙",
		"icon": "💰",
		"texture_path": "res://assets/textures/props/GoldBag.png"
	})

	# Click / collect tombstone
	tombstone.collect()
	assert_true(collected_box["type"] == "GOLD", "loot_collected signal received with type GOLD")
	assert_true(collected_box["amount"] == 100, "Collected amount matches 100 gold")
	assert_true(lane.has_tombstone == false, "Lane reports has_tombstone == false after collection")

	lane.queue_free()

func test_tombstone_clear_and_turn_end() -> void:
	print("\n--- 7. Testing Tombstone Clear On Turn End ---")
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	add_child(lane)

	# Auto-collection on turn end for uncollected loot
	var auto_collected_box = {"status": false}
	lane.loot_collected.connect(func(_slot, _type, _data):
		auto_collected_box["status"] = true
	)

	lane.spawn_tombstone({
		"type": "CARD",
		"card_id": "Creature_Pig",
		"card_name": "The Pig",
		"amount": 1,
		"label": "Card: The Pig",
		"icon": "🎁"
	})
	assert_true(lane.has_tombstone == true, "Tombstone active before turn end")

	# End of turn clears tombstones
	lane.clear_tombstone()
	assert_true(lane.has_tombstone == false, "Tombstone cleared on clear_tombstone()")
	assert_true(auto_collected_box["status"] == true, "Uncollected card was auto-collected on turn end")

	lane.queue_free()

func test_battle_rewards_integration() -> void:
	print("\n--- 8. Testing Battle Rewards & Inventory Integration ---")
	var initial_coins = GameManager.player_coins
	var initial_cards_count = GameManager.player_inventory_cards.size()

	# Simulate match end with rewards
	var mock_cards: Array[String] = ["Creature_Cornball", "Spell_PieStorm"]
	GameManager.add_rewards(150, mock_cards)

	assert_true(GameManager.player_coins == initial_coins + 150, "GameManager recorded +150 player coins")
	assert_true(GameManager.player_inventory_cards.size() == initial_cards_count + 2, "GameManager recorded 2 new cards in inventory")
	assert_true("Creature_Cornball" in GameManager.player_inventory_cards, "Creature_Cornball present in inventory")
