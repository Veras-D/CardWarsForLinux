extends Control

const AbilitySystem = preload("res://src/battle/AbilitySystem.gd")
const LaneSlot = preload("res://src/battle/LaneSlot.gd")

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING ABILITY SYSTEM & TRIGGER EVENT ARCHITECTURE TESTS")
	print("========================================")

	# 1. Test Setup & Architecture
	test_system_setup()

	# 2. Test ON_SUMMON Triggers
	test_on_summon()

	# 3. Test ON_FLOOP Ability Execution Matrix
	test_on_floop_matrix()

	# 4. Test ON_DEATH Triggers
	test_on_death()

	# 5. Test ON_TURN_START Triggers
	test_on_turn_start()

	# 6. Test ON_ATTACK Triggers
	test_on_attack()

	# 7. Test BattleController Full Integration
	test_battle_controller_integration()

	# 8. Test Extended Ability Scripts Matrix (Task 3.2)
	test_extended_scripts_matrix()

	# 9. Test Database-Wide Script Compatibility (341 Creatures)
	test_all_database_creatures_compatibility()

	print("\n🎉 ALL ABILITY SYSTEM TESTS PASSED SUCCESSFULLY (100%)!")
	get_tree().quit(0)


func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		printerr("❌ ASSERTION FAILED: " + msg)
		get_tree().quit(1)
	else:
		print("  ✅ " + msg)


func create_mock_lane(is_player: bool, lane_index: int, landscape: String = "Plains") -> LaneSlot:
	var lane_scene = load("res://scenes/components/LaneSlot.tscn")
	var lane = lane_scene.instantiate() as LaneSlot
	lane.is_player = is_player
	lane.lane_index = lane_index
	add_child(lane)
	lane.update_landscape(landscape)
	return lane


func test_system_setup() -> void:
	print("\n--- 1. Testing System Setup & Event Bus Architecture ---")
	var ability_sys = AbilitySystem.new()
	add_child(ability_sys)
	ability_sys.setup(self)

	assert_true(ability_sys.resolver != null, "AbilityResolver instantiated and child added")
	assert_true(ability_sys.event_bus != null, "SystemEventBus instantiated and child added")
	assert_true(ability_sys.battle_controller == self, "BattleController reference stored")

	ability_sys.free()


func test_on_summon() -> void:
	print("\n--- 2. Testing ON_SUMMON Triggers (Entry Effects) ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p_lane = battle.player_lanes[0]
	var o_lane = battle.opponent_lanes[0]

	# Opponent creature in opposing lane
	o_lane.place_creature({
		"id": "c_dummy",
		"name": "Target Dummy",
		"atk": 2,
		"def": 10,
		"faction": "Plains"
	})

	# Summon creature with CreatureDamageOnEntry (val1 = 3)
	p_lane.place_creature({
		"id": "c_entry_dmg",
		"name": "Shock Trooper",
		"atk": 3,
		"def": 5,
		"faction": "Plains",
		"script_name": "CreatureDamageOnEntry",
		"val1": "3"
	})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, p_lane)

	assert_true(o_lane.current_def == 7, "Opposing creature took 3 damage on entry (10 -> 7)")

	# Summon creature with HeroDamageOnEntry (val1 = 4)
	var prev_opp_hp = battle.opponent_hp
	var p_lane_2 = battle.player_lanes[1]
	p_lane_2.place_creature({
		"id": "c_hero_shock",
		"name": "Direct Striker",
		"atk": 1,
		"def": 4,
		"faction": "Plains",
		"script_name": "HeroDamageOnEntry",
		"val1": "4"
	})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_SUMMON, p_lane_2)

	assert_true(battle.opponent_hp == prev_opp_hp - 4, "Opponent Hero took 4 damage on entry (%d -> %d)" % [prev_opp_hp, battle.opponent_hp])

	battle.free()


func test_on_floop_matrix() -> void:
	print("\n--- 3. Testing ON_FLOOP Ability Execution Matrix ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var lane0 = battle.player_lanes[0]
	var lane1 = battle.player_lanes[1]
	var opp0 = battle.opponent_lanes[0]
	var opp1 = battle.opponent_lanes[1]

	# A. ATKBonus
	lane0.place_creature({"name": "Warrior", "atk": 2, "def": 5, "script_name": "ATKBonus", "val1": "3"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(lane0.current_atk == 5, "ATKBonus: +3 ATK (2 -> 5)")

	# B. ATKDEFBonus
	lane0.place_creature({"name": "Paladin", "atk": 2, "def": 5, "script_name": "ATKDEFBonus", "val1": "2", "val2": "4"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(lane0.current_atk == 4 and lane0.current_def == 9, "ATKDEFBonus: +2 ATK, +4 DEF (ATK: 4, DEF: 9)")

	# C. SwapATKDEF
	lane0.place_creature({"name": "Shapeshifter", "atk": 1, "def": 8, "script_name": "SwapATKDEF"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(lane0.current_atk == 8 and lane0.current_def == 1, "SwapATKDEF: stats swapped (1/8 -> 8/1)")

	# D. LowerATKOpponent
	opp0.place_creature({"name": "Enemy Brute", "atk": 6, "def": 6})
	lane0.place_creature({"name": "Intimidator", "atk": 1, "def": 4, "script_name": "LowerATKOpponent", "val1": "3"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(opp0.current_atk == 3, "LowerATKOpponent: opposing creature ATK reduced by 3 (6 -> 3)")

	# E. ATKPenaltyFaction (The Pig)
	opp0.place_creature({"name": "Corn Knight", "atk": 5, "def": 5, "faction": "Corn"})
	opp1.place_creature({"name": "Plains Bird", "atk": 4, "def": 4, "faction": "Plains"})
	lane0.place_creature({"name": "The Pig", "atk": 1, "def": 5, "script_name": "ATKPenaltyFaction", "val1": "2", "val2": "2", "for_faction": "Corn"})
	battle.ability_system.execute_card_script("ATKPenaltyFaction", lane0, "2", "2", "Corn")
	assert_true(opp0.current_atk == 3, "ATKPenaltyFaction: Corn target weakened by 2 (5 -> 3)")
	assert_true(opp1.current_atk == 4, "ATKPenaltyFaction: Plains creature unaffected (remains 4)")

	# F. SelfAndAdjacentATKBonus
	lane0.place_creature({"name": "Banner Bearer", "atk": 1, "def": 4, "script_name": "SelfAndAdjacentATKBonus", "val1": "2"})
	lane1.place_creature({"name": "Infantry", "atk": 3, "def": 4})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(lane0.current_atk == 3, "SelfAndAdjacentATKBonus: self buffed +2 (1 -> 3)")
	assert_true(lane1.current_atk == 5, "SelfAndAdjacentATKBonus: adjacent lane buffed +2 (3 -> 5)")

	# G. HealHero
	battle.player_hp = 10
	lane0.place_creature({"name": "Healer", "atk": 1, "def": 3, "script_name": "HealHero", "val1": "5"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(battle.player_hp == 15, "HealHero: Player restored 5 HP (10 -> 15)")

	# H. DamageAll
	opp0.place_creature({"name": "Enemy 1", "atk": 2, "def": 6})
	opp1.place_creature({"name": "Enemy 2", "atk": 2, "def": 6})
	lane0.place_creature({"name": "Pyromancer", "atk": 2, "def": 4, "script_name": "DamageAll", "val1": "3"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(opp0.current_def == 3 and opp1.current_def == 3, "DamageAll: All enemy creatures took 3 damage (6 -> 3)")

	# I. BlockFloop
	opp0.place_creature({"name": "Opponent Caster", "atk": 2, "def": 5, "floop_cost": 1})
	opp0.set_flooped(false)
	lane0.place_creature({"name": "Freezer", "atk": 1, "def": 4, "script_name": "BlockFloop"})
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_FLOOP, lane0)
	assert_true(opp0.is_flooped == true, "BlockFloop: Opposing creature is now flooped/frozen")

	battle.free()


func test_on_death() -> void:
	print("\n--- 4. Testing ON_DEATH Triggers ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p_lane = battle.player_lanes[0]
	var opp_lane = battle.opponent_lanes[0]

	# A. DamageHeroOnDeath (player creature dying damages opponent hero)
	var prev_opp_hp = battle.opponent_hp
	p_lane.place_creature({
		"name": "Bomb Goblin",
		"atk": 2,
		"def": 3,
		"script_name": "DamageHeroOnDeath",
		"val1": "4"
	})

	# Fatal damage -> triggers creature_destroyed -> ON_DEATH
	p_lane.apply_damage(5)
	assert_true(not p_lane.has_creature, "Bomb Goblin slot cleared after death")
	assert_true(battle.opponent_hp == prev_opp_hp - 4, "DamageHeroOnDeath: Opponent took 4 damage on goblin death (%d -> %d)" % [prev_opp_hp, battle.opponent_hp])

	# B. HealHeroOnDeath (opponent creature with HealHeroOnDeath heals opponent on death)
	battle.opponent_hp = 10
	opp_lane.place_creature({
		"name": "Spirit of Light",
		"atk": 1,
		"def": 2,
		"script_name": "HealHeroOnDeath",
		"val1": "5"
	})
	opp_lane.apply_damage(3)
	assert_true(not opp_lane.has_creature, "Spirit slot cleared after death")
	assert_true(battle.opponent_hp == 15, "HealHeroOnDeath: Opponent hero healed 5 HP on death (10 -> 15)")

	battle.free()


func test_on_turn_start() -> void:
	print("\n--- 5. Testing ON_TURN_START Triggers ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p_lane = battle.player_lanes[0]
	p_lane.place_creature({
		"name": "Troll",
		"atk": 2,
		"def": 10,
		"script_name": "StartTurnHealCreatures",
		"val1": "2"
	})
	p_lane.current_def = 5
	p_lane._update_card_display()

	battle.is_player_turn = true
	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_TURN_START)
	assert_true(p_lane.current_def == 7, "StartTurnHealCreatures: Troll healed 2 DEF at start of turn (5 -> 7)")

	battle.free()


func test_on_attack() -> void:
	print("\n--- 6. Testing ON_ATTACK Triggers ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p_lane = battle.player_lanes[0]
	p_lane.place_creature({
		"name": "Berserker",
		"atk": 4,
		"def": 6,
		"script_name": "DoubleDamage"
	})

	battle.ability_system.dispatch_trigger(AbilitySystem.Trigger.ON_ATTACK, p_lane)
	assert_true(p_lane.current_atk == 8, "DoubleDamage: Berserker doubled ATK before clash (4 -> 8)")

	battle.free()


func test_battle_controller_integration() -> void:
	print("\n--- 7. Testing Full BattleController Integration ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	assert_true(battle.ability_system != null, "BattleController.ability_system exists")
	assert_true(battle.ability_system.battle_controller == battle, "AbilitySystem correctly wired to BattleController")

	# Simulate Floop invocation through BattleController._on_floop_requested()
	var p_lane = battle.player_lanes[0]
	p_lane.place_creature({
		"name": "Dingo",
		"atk": 3,
		"def": 4,
		"floop_cost": 1,
		"script_name": "ATKBonus",
		"val1": "2"
	})

	battle.is_player_turn = true
	battle.player_mp = 5
	battle._on_floop_requested(p_lane)

	assert_true(battle.player_mp == 4, "Flooping Dingo deducted 1 MP (5 -> 4)")
	assert_true(p_lane.is_flooped == true, "Dingo marked as flooped")
	assert_true(p_lane.current_atk == 5, "Dingo ATK buffed +2 via AbilitySystem (3 -> 5)")

	battle.free()


func test_extended_scripts_matrix() -> void:
	print("\n--- 8. Testing Extended Ability Scripts Matrix (Task 3.2) ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var p0 = battle.player_lanes[0]
	var p1 = battle.player_lanes[1]
	var p2 = battle.player_lanes[2]
	var o0 = battle.opponent_lanes[0]
	var o1 = battle.opponent_lanes[1]

	# 1. DamageOpponentHealSelf
	p0.place_creature({"name": "Vampire", "atk": 3, "def": 10, "script_name": "DamageOpponentHealSelf", "val1": "4", "val2": "3"})
	p0.current_def = 5
	o0.place_creature({"name": "Target Dummy", "atk": 2, "def": 8})
	battle.ability_system.execute_card_script("DamageOpponentHealSelf", p0, "4", "3")
	assert_true(o0.current_def == 4, "DamageOpponentHealSelf: Opponent took 4 damage (8 -> 4)")
	assert_true(p0.current_def == 8, "DamageOpponentHealSelf: Self healed 3 DEF (5 -> 8)")

	# 2. AdjacentATKBonus & AdjacentDEFBonus
	p1.place_creature({"name": "Buffer", "atk": 2, "def": 5, "script_name": "AdjacentATKBonus", "val1": "2"})
	p0.place_creature({"name": "Flank Left", "atk": 3, "def": 4})
	p2.place_creature({"name": "Flank Right", "atk": 4, "def": 6})
	battle.ability_system.execute_card_script("AdjacentATKBonus", p1, "2", "0")
	assert_true(p0.current_atk == 5, "AdjacentATKBonus: Flank Left gained +2 ATK (3 -> 5)")
	assert_true(p2.current_atk == 6, "AdjacentATKBonus: Flank Right gained +2 ATK (4 -> 6)")

	# 3. ATKBonusAdjacentEmpty
	p0.clear_slot()
	p2.clear_slot()
	p1.place_creature({"name": "Lone Wolf", "atk": 2, "def": 5, "script_name": "ATKBonusAdjacentEmpty", "val1": "3"})
	battle.ability_system.execute_card_script("ATKBonusAdjacentEmpty", p1, "3", "0")
	assert_true(p1.current_atk == 8, "ATKBonusAdjacentEmpty: 2 empty adjacent lanes = +6 ATK (2 -> 8)")

	# 4. SacrificeForMP
	battle.player_mp = 2
	p0.place_creature({"name": "Mana Battery", "atk": 1, "def": 2, "script_name": "SacrificeForMP", "val1": "3"})
	battle.ability_system.execute_card_script("SacrificeForMP", p0, "3", "0")
	assert_true(battle.player_mp == 5, "SacrificeForMP: Gained +3 MP (2 -> 5)")
	assert_true(not p0.has_creature, "SacrificeForMP: Creature was sacrificed and cleared from lane")

	# 5. ReturnOppnentToHand
	o0.place_creature({"name": "Pesky Rogue", "atk": 4, "def": 5, "script_name": "ReturnOppnentToHand"})
	p0.place_creature({"name": "Bouncer", "atk": 2, "def": 4})
	battle.ability_system.execute_card_script("ReturnOppnentToHand", p0)
	assert_true(not o0.has_creature, "ReturnOppnentToHand: Opponent creature was returned from lane")

	# 6. EqualizeATK
	o1.place_creature({"name": "Colossus", "atk": 9, "def": 12})
	p1.place_creature({"name": "Mirror Knight", "atk": 1, "def": 6, "script_name": "EqualizeATK"})
	battle.ability_system.execute_card_script("EqualizeATK", p1)
	assert_true(p1.current_atk == 9, "EqualizeATK: Copied opposing Colossus's ATK (1 -> 9)")

	# 7. HelplessOpponent
	battle.ability_system.execute_card_script("HelplessOpponent", p1)
	assert_true(o1.current_atk == 0, "HelplessOpponent: Opposing Colossus ATK set to 0")

	# 8. ResetSelf
	p1.current_atk = 15
	p1.current_def = 2
	battle.ability_system.execute_card_script("ResetSelf", p1)
	assert_true(p1.current_atk == 1 and p1.current_def == 6, "ResetSelf: Restored original card blueprint stats (1/6)")

	# 9. DrainAdjacentDEFAddATKBonus
	p0.place_creature({"name": "Minion L", "atk": 1, "def": 5})
	p2.place_creature({"name": "Minion R", "atk": 1, "def": 5})
	p1.place_creature({"name": "Soul Eater", "atk": 2, "def": 6, "script_name": "DrainAdjacentDEFAddATKBonus", "val1": "2", "val2": "3"})
	battle.ability_system.execute_card_script("DrainAdjacentDEFAddATKBonus", p1, "2", "3")
	assert_true(p0.current_def == 3, "Minion L drained 2 DEF (5 -> 3)")
	assert_true(p2.current_def == 3, "Minion R drained 2 DEF (5 -> 3)")
	assert_true(p1.current_atk == 8, "Soul Eater gained +6 ATK from 2 drained allies (2 -> 8)")

	# 10. DamageAllDamageOne
	o0.place_creature({"name": "Target 1", "atk": 1, "def": 10})
	o1.place_creature({"name": "Target 2", "atk": 1, "def": 10})
	p0.place_creature({"name": "Meteorite", "atk": 2, "def": 4, "script_name": "DamageAllDamageOne", "val1": "3", "val2": "4"})
	battle.ability_system.execute_card_script("DamageAllDamageOne", p0, "3", "4")
	assert_true(o0.current_def == 3, "Primary target o0 took 3 AoE + 4 direct = 7 damage (10 -> 3)")
	assert_true(o1.current_def == 7, "Secondary target o1 took 3 AoE damage (10 -> 7)")

	battle.free()


func test_all_database_creatures_compatibility() -> void:
	print("\n--- 9. Testing Database-Wide Script Compatibility (341 Creatures) ---")
	var battle_scene = load("res://scenes/battle.tscn")
	var battle = battle_scene.instantiate()
	add_child(battle)

	var lane = battle.player_lanes[0]
	var opp_lane = battle.opponent_lanes[0]
	opp_lane.place_creature({"id": "dummy", "name": "Dummy", "atk": 2, "def": 20, "faction": "Plains"})

	var tested_scripts = {}
	var success_count = 0
	for card in Database.creatures_list:
		var script_name = card.get("script_name", "")
		if script_name == "":
			continue
		tested_scripts[script_name] = true

		lane.place_creature(card)
		var val1 = str(card.get("val1", "1"))
		var val2 = str(card.get("val2", "1"))
		var fac = str(card.get("faction", ""))
		var ok = battle.ability_system.execute_card_script(script_name, lane, val1, val2, fac)
		if ok:
			success_count += 1

	print("  📊 Resolved %d card abilities across %d unique script blueprints!" % [success_count, tested_scripts.size()])
	assert_true(success_count == Database.creatures_list.size(), "All %d creatures successfully executed without errors" % Database.creatures_list.size())
	assert_true(tested_scripts.size() >= 110, "Covered over 110 distinct card ability scripts from db_Creatures.json")

	battle.free()

