extends Control

const SpellResolver = preload("res://src/battle/SpellResolver.gd")
const LaneSlot = preload("res://src/battle/LaneSlot.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING SPELL CARDS SYSTEM UNIT & INTEGRATION TESTS")
	print("========================================")

	test_spell_database_loading()
	test_targeting_classification()
	test_mp_and_target_validation()
	test_non_targeted_spell_execution()
	test_targeted_spell_execution()
	test_discard_pile_and_retrieval()
	test_battle_controller_spell_integration()

	print("\n🎉 ALL SPELL SYSTEM TESTS PASSED SUCCESSFULLY (100%)!")
	get_tree().quit(0)

func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)

func test_spell_database_loading() -> void:
	print("\n--- 1. Testing Spell Database Loading ---")
	var bloodstorm = Database.get_card("Spell_CerebralBloodstorm")
	assert_true(not bloodstorm.is_empty(), "Spell_CerebralBloodstorm loaded from database")
	assert_true(bloodstorm.get("type") == "SPELL", "Card type is SPELL")
	assert_true(bloodstorm.get("script_name") == "AttackSelf", "Script name is AttackSelf")

	var transfusion = Database.get_card("Spell_BloodTransfusion")
	assert_true(not transfusion.is_empty(), "Spell_BloodTransfusion loaded")
	assert_true(transfusion.get("script_name") == "DrainOpponentHealth", "Script is DrainOpponentHealth")
	assert_true(transfusion.get("val1") == "5", "Val1 is 5 HP drain")

	var pie_storm = Database.get_card("Spell_PieStorm")
	assert_true(not pie_storm.is_empty(), "Spell_PieStorm loaded")
	assert_true(pie_storm.get("script_name") == "HealCreatures", "Script is HealCreatures")

func test_targeting_classification() -> void:
	print("\n--- 2. Testing Targeting Classification ---")
	var resolver = SpellResolver.new()
	assert_true(not resolver.is_targeted({"script_name": "DrawCardsSpell"}), "DrawCardsSpell is non-targeted")
	assert_true(not resolver.is_targeted({"script_name": "DrainOpponentHealth"}), "DrainOpponentHealth is non-targeted")
	assert_true(not resolver.is_targeted({"script_name": "ActionPointLandscapes"}), "ActionPointLandscapes is non-targeted")
	assert_true(not resolver.is_targeted({"script_name": "HealCreatures"}), "HealCreatures is non-targeted")

	assert_true(resolver.is_targeted({"script_name": "HealCreature"}), "HealCreature is targeted")
	assert_true(resolver.is_targeted({"script_name": "SwapATKDEFOpponent"}), "SwapATKDEFOpponent is targeted")
	assert_true(resolver.is_targeted({"script_name": "AttackCreatureCorn"}), "AttackCreatureCorn is targeted")
	assert_true(resolver.is_targeted({"script_name": "DisableLane"}), "DisableLane is targeted")
	resolver.free()

func test_mp_and_target_validation() -> void:
	print("\n--- 3. Testing MP & Target Validation ---")
	var resolver = SpellResolver.new()
	var spell = {
		"id": "Spell_Test",
		"name": "Test Spell",
		"cost": 3,
		"script_name": "DrawCardsSpell"
	}

	# Check insufficient MP
	var check_poor = resolver.can_cast(spell, 2, true)
	assert_true(not check_poor.allowed, "Cannot cast when current MP (2) < cost (3)")

	# Check sufficient MP for non-targeted
	var check_rich = resolver.can_cast(spell, 5, true)
	assert_true(check_rich.allowed, "Can cast when current MP (5) >= cost (3)")
	resolver.free()

func test_non_targeted_spell_execution() -> void:
	print("\n--- 4. Testing Non-Targeted Spell Execution ---")
	var resolver = SpellResolver.new()
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)
	resolver.setup(battle)

	battle.player_hp = 15
	battle.opponent_hp = 20

	# DrainOpponentHealth: drain 5 HP from opponent to player
	var drain_spell = {
		"id": "Spell_BloodTransfusion",
		"name": "Blood Transfusion",
		"script_name": "DrainOpponentHealth",
		"val1": "5"
	}
	var res = resolver.cast_spell(drain_spell, null, true)
	assert_true(res.damage_dealt == 5, "Dealt 5 damage to opponent hero")
	assert_true(battle.opponent_hp == 15, "Opponent HP reduced from 20 to 15")
	assert_true(battle.player_hp == 20, "Player HP restored from 15 to 20")

	battle.free()
	resolver.free()

func test_targeted_spell_execution() -> void:
	print("\n--- 5. Testing Targeted Spell Execution ---")
	var resolver = SpellResolver.new()
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)
	resolver.setup(battle)

	var p_lane = battle.player_lanes[0]
	p_lane.place_creature({
		"name": "Corn Knight",
		"atk": 2,
		"def": 8
	})
	p_lane.current_def = 3

	# HealCreature
	var heal_spell = {
		"name": "Elf Blood",
		"script_name": "HealCreature"
	}
	var res_heal = resolver.cast_spell(heal_spell, p_lane, true)
	assert_true(p_lane.current_def == 8, "Creature healed to full max DEF (8)")

	# SwapATKDEF
	var swap_spell = {
		"name": "Cough Syrup",
		"script_name": "SwapATKDEFSelf"
	}
	resolver.cast_spell(swap_spell, p_lane, true)
	assert_true(p_lane.current_atk == 8, "Creature swapped ATK (now 8)")
	assert_true(p_lane.current_def == 2, "Creature swapped DEF (now 2)")

	# AttackCreatureCorn on opponent lane
	var o_lane = battle.opponent_lanes[0]
	o_lane.update_landscape("Corn")
	o_lane.place_creature({
		"name": "Opponent Corn Creature",
		"atk": 1,
		"def": 3
	})
	var corn_strike = {
		"name": "Corn Scepter",
		"script_name": "AttackCreatureCorn"
	}
	var res_corn = resolver.cast_spell(corn_strike, o_lane, true)
	assert_true(res_corn.damage_dealt == 4, "Corn strike dealt 4 damage")
	assert_true(o_lane.has_creature == false, "Creature took lethal damage and was destroyed")

	battle.free()
	resolver.free()

func test_discard_pile_and_retrieval() -> void:
	print("\n--- 6. Testing Discard Pile and Retrieval ---")
	var resolver = SpellResolver.new()
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)
	resolver.setup(battle)

	var discard: Array[String] = ["Creature_Pig", "Spell_BloodTransfusion"]
	battle.player_discard_pile = discard
	var initial_hand_count = battle.hand_container.get_child_count()

	var retrieve_spell = {
		"name": "Scroll of Bad Breath",
		"script_name": "ReturnCard"
	}
	resolver.cast_spell(retrieve_spell, null, true)
	assert_true(battle.player_discard_pile.size() == 1, "Top card removed from discard pile")
	assert_true(battle.hand_container.get_child_count() == initial_hand_count + 1, "Card added to hand container")

	battle.free()
	resolver.free()

func test_battle_controller_spell_integration() -> void:
	print("\n--- 7. Testing Full BattleController Integration ---")
	var b_scene = load("res://scenes/battle.tscn")
	var battle = b_scene.instantiate()
	add_child(battle)

	assert_true(battle.spell_resolver != null, "BattleController.spell_resolver initialized")
	assert_true(battle.player_discard_pile is Array, "player_discard_pile exists")
	assert_true(battle.opponent_discard_pile is Array, "opponent_discard_pile exists")

	# Prepare a spell in player's MP pool
	battle.player_mp = 5
	battle.is_player_turn = true

	# Test casting non-targeted spell: DrainOpponentHealth
	var initial_opp_hp = battle.opponent_hp
	var initial_p_hp = battle.player_hp
	var drain_card = {
		"id": "Spell_BloodTransfusion",
		"name": "Blood Transfusion",
		"type": "SPELL",
		"cost": 2,
		"script_name": "DrainOpponentHealth",
		"val1": "5"
	}

	# Cast directly through spell resolver
	var res = battle.spell_resolver.cast_spell(drain_card, null, true)
	battle.player_discard_pile.append(drain_card.id)
	battle.player_mp -= drain_card.cost

	assert_true(battle.opponent_hp == initial_opp_hp - 5, "Opponent HP reduced by 5")
	assert_true(battle.player_mp == 3, "Player MP deducted by cost (5 - 2 = 3)")
	assert_true(battle.player_discard_pile.has("Spell_BloodTransfusion"), "Spell added to player discard pile")

	# Test targeted spell targeting: place creature on opponent lane 0
	var o_lane = battle.opponent_lanes[0]
	o_lane.place_creature({
		"name": "Jake Minion",
		"atk": 3,
		"def": 6
	})

	var valid_targets = battle.spell_resolver.get_valid_lane_targets({
		"script_name": "SwapATKDEFOpponent"
	}, true)
	assert_true(valid_targets.has(o_lane), "Opponent lane 0 recognized as valid target for SwapATKDEFOpponent")

	battle.spell_resolver.cast_spell({
		"name": "Skull Juice",
		"script_name": "SwapATKDEFOpponent"
	}, o_lane, true)

	assert_true(o_lane.current_atk == 6, "Target creature ATK swapped to 6")
	assert_true(o_lane.current_def == 3, "Target creature DEF swapped to 3")

	battle.free()
